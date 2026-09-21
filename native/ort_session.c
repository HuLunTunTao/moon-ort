#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "ort_shared.h"

typedef struct OptionsPayload {
  int32_t code;
  int32_t state;
  int32_t status_code;
  char message[768];
  char api_name[64];
  EnvPayload *env;
  OrtSessionOptions *options;
} OptionsPayload;

typedef struct SessionPayload {
  int32_t code;
  int32_t state;
  int32_t status_code;
  char message[768];
  char api_name[64];
  EnvPayload *env;
  OrtSession *session;
} SessionPayload;

#define MOON_ORT_HANDLE_ACCESSORS(prefix, Type)                                \
  int32_t moon_ort_##prefix##_code(Type *payload) {                            \
    if (payload == NULL) {                                                     \
      return MOON_ORT_INVALID_ARGUMENT;                                        \
    }                                                                          \
    return payload->code;                                                      \
  }                                                                            \
  int32_t moon_ort_##prefix##_state(Type *payload) {                           \
    if (payload == NULL) {                                                     \
      return MOON_ORT_STATE_FAILED;                                            \
    }                                                                          \
    return payload->state;                                                     \
  }                                                                            \
  int32_t moon_ort_##prefix##_status_code(Type *payload) {                     \
    if (payload == NULL) {                                                     \
      return -1;                                                               \
    }                                                                          \
    return payload->status_code;                                               \
  }                                                                            \
  moonbit_string_t moon_ort_##prefix##_message(Type *payload) {                \
    if (payload == NULL) {                                                     \
      return utf8_to_moonbit("");                                              \
    }                                                                          \
    return utf8_to_moonbit(payload->message);                                  \
  }                                                                            \
  moonbit_string_t moon_ort_##prefix##_api_name(Type *payload) {               \
    if (payload == NULL) {                                                     \
      return utf8_to_moonbit("");                                              \
    }                                                                          \
    return utf8_to_moonbit(payload->api_name);                                 \
  }

static void fail_invalid_fields(
  int32_t *code,
  char *message,
  size_t message_cap,
  char *api_name,
  size_t api_cap,
  const char *api,
  const char *text
) {
  *code = MOON_ORT_INVALID_ARGUMENT;
  copy_cstr(api_name, api_cap, api);
  copy_cstr(message, message_cap, text);
}

static void options_invalid(OptionsPayload *payload, const char *api, const char *text) {
  fail_invalid_fields(
    &payload->code,
    payload->message,
    sizeof(payload->message),
    payload->api_name,
    sizeof(payload->api_name),
    api,
    text
  );
}

static void session_invalid(SessionPayload *payload, const char *api, const char *text) {
  fail_invalid_fields(
    &payload->code,
    payload->message,
    sizeof(payload->message),
    payload->api_name,
    sizeof(payload->api_name),
    api,
    text
  );
}

static void release_options(OptionsPayload *payload) {
  EnvPayload *env;
  if (payload->state != MOON_ORT_STATE_OPEN) {
    return;
  }
  payload->state = MOON_ORT_STATE_CLOSED;
  env = payload->env;
  if (payload->options != NULL && env != NULL && env->api != NULL && env->api->ReleaseSessionOptions != NULL) {
    env->api->ReleaseSessionOptions(payload->options);
  }
  payload->options = NULL;
  payload->env = NULL;
  if (env != NULL) {
    moon_ort_unpin_env(env);
  }
}

static void options_finalize(void *self) {
  release_options((OptionsPayload *)self);
}

static OptionsPayload *new_options_payload(void) {
  OptionsPayload *payload =
    moonbit_make_external_object(options_finalize, (uint32_t)sizeof(OptionsPayload));
  memset(payload, 0, sizeof(*payload));
  payload->state = MOON_ORT_STATE_FAILED;
  payload->status_code = -1;
  return payload;
}

static int options_ready(OptionsPayload *payload, const char *api) {
  if (payload == NULL) {
    return -1;
  }
  payload->status_code = -1;
  payload->message[0] = '\0';
  copy_cstr(payload->api_name, sizeof(payload->api_name), api);
  if (payload->state != MOON_ORT_STATE_OPEN || payload->options == NULL || payload->env == NULL ||
      payload->env->api == NULL || payload->env->state != MOON_ORT_STATE_OPEN) {
    payload->code = MOON_ORT_USE_AFTER_CLOSE;
    copy_cstr(payload->message, sizeof(payload->message), "session options are closed");
    return -1;
  }
  payload->code = MOON_ORT_OK;
  return 0;
}

static void release_session(SessionPayload *payload) {
  EnvPayload *env;
  if (payload->state != MOON_ORT_STATE_OPEN) {
    return;
  }
  payload->state = MOON_ORT_STATE_CLOSED;
  env = payload->env;
  if (payload->session != NULL && env != NULL && env->api != NULL && env->api->ReleaseSession != NULL) {
    env->api->ReleaseSession(payload->session);
  }
  payload->session = NULL;
  payload->env = NULL;
  if (env != NULL) {
    moon_ort_unpin_env(env);
  }
}

static void session_finalize(void *self) {
  release_session((SessionPayload *)self);
}

static SessionPayload *new_session_payload(void) {
  SessionPayload *payload =
    moonbit_make_external_object(session_finalize, (uint32_t)sizeof(SessionPayload));
  memset(payload, 0, sizeof(*payload));
  payload->state = MOON_ORT_STATE_FAILED;
  payload->status_code = -1;
  return payload;
}

static int session_ready(SessionPayload *payload, const char *api) {
  if (payload == NULL) {
    return -1;
  }
  payload->status_code = -1;
  payload->message[0] = '\0';
  copy_cstr(payload->api_name, sizeof(payload->api_name), api);
  if (payload->state != MOON_ORT_STATE_OPEN || payload->session == NULL || payload->env == NULL ||
      payload->env->api == NULL || payload->env->state != MOON_ORT_STATE_OPEN) {
    payload->code = MOON_ORT_USE_AFTER_CLOSE;
    copy_cstr(payload->message, sizeof(payload->message), "session is closed");
    return -1;
  }
  payload->code = MOON_ORT_OK;
  return 0;
}

static void write_payload_status(
  int32_t *code,
  int32_t *status_code,
  char *message,
  size_t message_cap,
  char *api_name,
  size_t api_cap,
  const OrtApi *api,
  OrtStatus *status,
  const char *api_called
) {
  moon_ort_write_status(code, status_code, message, message_cap, api_name, api_cap, api, status, api_called);
}

static int free_alloc(const OrtApi *api, OrtAllocator *allocator, void *ptr, SessionPayload *payload, const char *api_name) {
  OrtStatus *status;
  if (ptr == NULL) {
    return 0;
  }
  if (api == NULL || api->AllocatorFree == NULL) {
    if (allocator != NULL && allocator->Free != NULL) {
      allocator->Free(allocator, ptr);
    }
    return 0;
  }
  status = api->AllocatorFree(allocator, ptr);
  if (status == NULL) {
    return 0;
  }
  if (payload->code == MOON_ORT_OK) {
    write_payload_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      api_name
    );
    return -1;
  }
  if (api->ReleaseStatus != NULL) {
    api->ReleaseStatus(status);
  }
  return -1;
}

MOON_ORT_HANDLE_ACCESSORS(options, OptionsPayload)
MOON_ORT_HANDLE_ACCESSORS(session, SessionPayload)

OptionsPayload *moon_ort_options_create(EnvPayload *env) {
  OptionsPayload *payload = new_options_payload();
  const OrtApi *api;
  OrtSessionOptions *options = NULL;
  OrtStatus *status;
  copy_cstr(payload->api_name, sizeof(payload->api_name), "CreateSessionOptions");
  if (env == NULL || env->state != MOON_ORT_STATE_OPEN || env->api == NULL) {
    payload->code = MOON_ORT_USE_AFTER_CLOSE;
    copy_cstr(payload->message, sizeof(payload->message), "runtime is closed");
    return payload;
  }
  api = env->api;
  if (api->CreateSessionOptions == NULL || api->ReleaseSessionOptions == NULL) {
    options_invalid(payload, "CreateSessionOptions", "CreateSessionOptions is unavailable");
    return payload;
  }
  status = api->CreateSessionOptions(&options);
  if (status != NULL) {
    if (options != NULL) {
      api->ReleaseSessionOptions(options);
    }
    write_payload_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "CreateSessionOptions"
    );
    return payload;
  }
  if (options == NULL) {
    options_invalid(payload, "CreateSessionOptions", "CreateSessionOptions returned NULL");
    return payload;
  }
  payload->env = env;
  payload->options = options;
  payload->state = MOON_ORT_STATE_OPEN;
  payload->code = MOON_ORT_OK;
  moon_ort_pin_env(env);
  return payload;
}

int32_t moon_ort_options_close(OptionsPayload *payload) {
  if (payload == NULL || payload->state == MOON_ORT_STATE_FAILED) {
    return MOON_ORT_INVALID_ARGUMENT;
  }
  if (payload->state != MOON_ORT_STATE_OPEN) {
    return MOON_ORT_ALREADY_CLOSED;
  }
  release_options(payload);
  return MOON_ORT_OK;
}

static int32_t set_threads(OptionsPayload *payload, int32_t threads, int intra) {
  const char *api_name = intra ? "SetIntraOpNumThreads" : "SetInterOpNumThreads";
  const char *negative = intra ? "intra-op thread count is negative" : "inter-op thread count is negative";
  const OrtApi *api;
  OrtStatus *status;
  if (options_ready(payload, api_name) != 0) {
    return payload->code;
  }
  if (threads < 0) {
    options_invalid(payload, api_name, negative);
    return payload->code;
  }
  api = payload->env->api;
  if (intra) {
    if (api->SetIntraOpNumThreads == NULL) {
      options_invalid(payload, api_name, "SetIntraOpNumThreads is unavailable");
      return payload->code;
    }
    status = api->SetIntraOpNumThreads(payload->options, (int)threads);
  } else {
    if (api->SetInterOpNumThreads == NULL) {
      options_invalid(payload, api_name, "SetInterOpNumThreads is unavailable");
      return payload->code;
    }
    status = api->SetInterOpNumThreads(payload->options, (int)threads);
  }
  if (status != NULL) {
    write_payload_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      api_name
    );
  }
  return payload->code;
}

int32_t moon_ort_options_set_intra(OptionsPayload *payload, int32_t threads) {
  return set_threads(payload, threads, 1);
}

int32_t moon_ort_options_set_inter(OptionsPayload *payload, int32_t threads) {
  return set_threads(payload, threads, 0);
}

int32_t moon_ort_options_set_graph_optimization(OptionsPayload *payload, int32_t level) {
  const OrtApi *api;
  OrtStatus *status;
  if (options_ready(payload, "SetSessionGraphOptimizationLevel") != 0) {
    return payload->code;
  }
  if (level != ORT_DISABLE_ALL && level != ORT_ENABLE_BASIC && level != ORT_ENABLE_EXTENDED &&
      level != ORT_ENABLE_LAYOUT && level != ORT_ENABLE_ALL) {
    options_invalid(payload, "SetSessionGraphOptimizationLevel", "graph optimization level is invalid");
    return payload->code;
  }
  api = payload->env->api;
  if (api->SetSessionGraphOptimizationLevel == NULL) {
    options_invalid(payload, "SetSessionGraphOptimizationLevel", "SetSessionGraphOptimizationLevel is unavailable");
    return payload->code;
  }
  status = api->SetSessionGraphOptimizationLevel(payload->options, (GraphOptimizationLevel)level);
  if (status != NULL) {
    write_payload_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "SetSessionGraphOptimizationLevel"
    );
  }
  return payload->code;
}

int32_t moon_ort_options_set_execution_mode(OptionsPayload *payload, int32_t mode) {
  const OrtApi *api;
  OrtStatus *status;
  if (options_ready(payload, "SetSessionExecutionMode") != 0) {
    return payload->code;
  }
  if (mode != ORT_SEQUENTIAL && mode != ORT_PARALLEL) {
    options_invalid(payload, "SetSessionExecutionMode", "execution mode is invalid");
    return payload->code;
  }
  api = payload->env->api;
  if (api->SetSessionExecutionMode == NULL) {
    options_invalid(payload, "SetSessionExecutionMode", "SetSessionExecutionMode is unavailable");
    return payload->code;
  }
  status = api->SetSessionExecutionMode(payload->options, (ExecutionMode)mode);
  if (status != NULL) {
    write_payload_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "SetSessionExecutionMode"
    );
  }
  return payload->code;
}

int32_t moon_ort_options_execution_mode(OptionsPayload *payload) {
  const OrtApi *api;
  ExecutionMode mode = ORT_SEQUENTIAL;
  OrtStatus *status;
  if (options_ready(payload, "GetSessionExecutionMode") != 0) {
    return -1;
  }
  api = payload->env->api;
  if (api->GetSessionExecutionMode == NULL) {
    options_invalid(payload, "GetSessionExecutionMode", "GetSessionExecutionMode is unavailable");
    return -1;
  }
  status = api->GetSessionExecutionMode(payload->options, &mode);
  if (status != NULL) {
    write_payload_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "GetSessionExecutionMode"
    );
    return -1;
  }
  return (int32_t)mode;
}

SessionPayload *moon_ort_session_create(EnvPayload *env, OptionsPayload *options, moonbit_string_t path) {
  SessionPayload *payload = new_session_payload();
  char cpath[4096];
  const OrtApi *api;
  OrtSession *session = NULL;
  OrtStatus *status;
  copy_cstr(payload->api_name, sizeof(payload->api_name), "CreateSession");
  if (env == NULL || env->state != MOON_ORT_STATE_OPEN || env->api == NULL || env->env == NULL) {
    payload->code = MOON_ORT_USE_AFTER_CLOSE;
    copy_cstr(payload->message, sizeof(payload->message), "runtime is closed");
    return payload;
  }
  if (options == NULL || options->state != MOON_ORT_STATE_OPEN || options->options == NULL) {
    payload->code = MOON_ORT_USE_AFTER_CLOSE;
    copy_cstr(payload->message, sizeof(payload->message), "session options are closed");
    return payload;
  }
  if (options->env != env) {
    session_invalid(payload, "CreateSession", "session options belong to a different runtime");
    return payload;
  }
  if (path == NULL || Moonbit_array_length(path) == 0) {
    session_invalid(payload, "CreateSession", "model path is empty");
    return payload;
  }
  if (utf16_to_utf8(path, Moonbit_array_length(path), cpath, sizeof(cpath)) < 0) {
    session_invalid(payload, "CreateSession", "model path is too long");
    return payload;
  }
  api = env->api;
  if (api->CreateSession == NULL || api->ReleaseSession == NULL) {
    session_invalid(payload, "CreateSession", "CreateSession is unavailable");
    return payload;
  }
  status = api->CreateSession(env->env, cpath, options->options, &session);
  if (status != NULL) {
    if (session != NULL) {
      api->ReleaseSession(session);
    }
    write_payload_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "CreateSession"
    );
    return payload;
  }
  if (session == NULL) {
    session_invalid(payload, "CreateSession", "CreateSession returned NULL");
    return payload;
  }
  payload->env = env;
  payload->session = session;
  payload->state = MOON_ORT_STATE_OPEN;
  payload->code = MOON_ORT_OK;
  moon_ort_pin_env(env);
  return payload;
}

int32_t moon_ort_session_close(SessionPayload *payload) {
  if (payload == NULL || payload->state == MOON_ORT_STATE_FAILED) {
    return MOON_ORT_INVALID_ARGUMENT;
  }
  if (payload->state != MOON_ORT_STATE_OPEN) {
    return MOON_ORT_ALREADY_CLOSED;
  }
  release_session(payload);
  return MOON_ORT_OK;
}

static int32_t io_count(SessionPayload *payload, int is_output) {
  const char *api_name = is_output ? "SessionGetOutputCount" : "SessionGetInputCount";
  const OrtApi *api;
  OrtStatus *status;
  size_t count = 0;
  if (session_ready(payload, api_name) != 0) {
    return -1;
  }
  api = payload->env->api;
  if (is_output) {
    if (api->SessionGetOutputCount == NULL) {
      session_invalid(payload, api_name, "SessionGetOutputCount is unavailable");
      return -1;
    }
    status = api->SessionGetOutputCount(payload->session, &count);
  } else {
    if (api->SessionGetInputCount == NULL) {
      session_invalid(payload, api_name, "SessionGetInputCount is unavailable");
      return -1;
    }
    status = api->SessionGetInputCount(payload->session, &count);
  }
  if (status != NULL) {
    write_payload_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      api_name
    );
    return -1;
  }
  if (count > (size_t)INT32_MAX) {
    session_invalid(payload, api_name, is_output ? "output count does not fit" : "input count does not fit");
    return -1;
  }
  return (int32_t)count;
}

int32_t moon_ort_session_input_count(SessionPayload *payload) {
  return io_count(payload, 0);
}

int32_t moon_ort_session_output_count(SessionPayload *payload) {
  return io_count(payload, 1);
}

static int check_index(SessionPayload *payload, int32_t index, int is_output) {
  int32_t count;
  if (index < 0) {
    session_invalid(payload, is_output ? "SessionGetOutputName" : "SessionGetInputName", is_output ? "output index is negative" : "input index is negative");
    return -1;
  }
  count = io_count(payload, is_output);
  if (count < 0) {
    return -1;
  }
  if (index >= count) {
    session_invalid(
      payload,
      is_output ? "SessionGetOutputName" : "SessionGetInputName",
      is_output ? "output index is out of range" : "input index is out of range"
    );
    return -1;
  }
  return 0;
}

static int load_allocator(SessionPayload *payload, OrtAllocator **allocator) {
  const OrtApi *api = payload->env->api;
  OrtStatus *status;
  *allocator = NULL;
  if (api->GetAllocatorWithDefaultOptions == NULL) {
    session_invalid(payload, "GetAllocatorWithDefaultOptions", "GetAllocatorWithDefaultOptions is unavailable");
    return -1;
  }
  status = api->GetAllocatorWithDefaultOptions(allocator);
  if (status != NULL) {
    write_payload_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "GetAllocatorWithDefaultOptions"
    );
    return -1;
  }
  if (*allocator == NULL) {
    session_invalid(payload, "GetAllocatorWithDefaultOptions", "default allocator is null");
    return -1;
  }
  return 0;
}

static moonbit_string_t io_name(SessionPayload *payload, int32_t index, int is_output) {
  const char *api_name = is_output ? "SessionGetOutputName" : "SessionGetInputName";
  const OrtApi *api;
  OrtAllocator *allocator = NULL;
  OrtStatus *status;
  char *tmp = NULL;
  moonbit_string_t result;
  if (payload == NULL) {
    return utf8_to_moonbit("");
  }
  if (session_ready(payload, api_name) != 0 || check_index(payload, index, is_output) != 0) {
    return utf8_to_moonbit("");
  }
  if (load_allocator(payload, &allocator) != 0) {
    return utf8_to_moonbit("");
  }
  api = payload->env->api;
  if (is_output) {
    if (api->SessionGetOutputName == NULL) {
      session_invalid(payload, api_name, "SessionGetOutputName is unavailable");
      return utf8_to_moonbit("");
    }
    status = api->SessionGetOutputName(payload->session, (size_t)index, allocator, &tmp);
  } else {
    if (api->SessionGetInputName == NULL) {
      session_invalid(payload, api_name, "SessionGetInputName is unavailable");
      return utf8_to_moonbit("");
    }
    status = api->SessionGetInputName(payload->session, (size_t)index, allocator, &tmp);
  }
  if (status != NULL) {
    free_alloc(api, allocator, tmp, payload, "AllocatorFree");
    if (payload->code == MOON_ORT_OK) {
      write_payload_status(
        &payload->code,
        &payload->status_code,
        payload->message,
        sizeof(payload->message),
        payload->api_name,
        sizeof(payload->api_name),
        api,
        status,
        api_name
      );
    } else if (api->ReleaseStatus != NULL) {
      api->ReleaseStatus(status);
    }
    return utf8_to_moonbit("");
  }
  if (tmp == NULL) {
    session_invalid(payload, api_name, "name is null");
    return utf8_to_moonbit("");
  }
  result = utf8_to_moonbit(tmp);
  free_alloc(api, allocator, tmp, payload, "AllocatorFree");
  if (payload->code != MOON_ORT_OK) {
    moonbit_decref(result);
    return utf8_to_moonbit("");
  }
  return result;
}

moonbit_string_t moon_ort_session_input_name(SessionPayload *payload, int32_t index) {
  return io_name(payload, index, 0);
}

moonbit_string_t moon_ort_session_output_name(SessionPayload *payload, int32_t index) {
  return io_name(payload, index, 1);
}

static int open_tensor_info(
  SessionPayload *payload,
  int32_t index,
  int is_output,
  OrtTypeInfo **info,
  const OrtTensorTypeAndShapeInfo **tensor
) {
  const char *api_name = is_output ? "SessionGetOutputTypeInfo" : "SessionGetInputTypeInfo";
  const OrtApi *api;
  OrtStatus *status;
  *info = NULL;
  *tensor = NULL;
  if (check_index(payload, index, is_output) != 0) {
    return -1;
  }
  api = payload->env->api;
  if (is_output) {
    if (api->SessionGetOutputTypeInfo == NULL) {
      session_invalid(payload, api_name, "SessionGetOutputTypeInfo is unavailable");
      return -1;
    }
    status = api->SessionGetOutputTypeInfo(payload->session, (size_t)index, info);
  } else {
    if (api->SessionGetInputTypeInfo == NULL) {
      session_invalid(payload, api_name, "SessionGetInputTypeInfo is unavailable");
      return -1;
    }
    status = api->SessionGetInputTypeInfo(payload->session, (size_t)index, info);
  }
  if (status != NULL) {
    if (*info != NULL && api->ReleaseTypeInfo != NULL) {
      api->ReleaseTypeInfo(*info);
      *info = NULL;
    }
    write_payload_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      api_name
    );
    return -1;
  }
  if (*info == NULL || api->CastTypeInfoToTensorInfo == NULL || api->ReleaseTypeInfo == NULL) {
    if (*info != NULL && api->ReleaseTypeInfo != NULL) {
      api->ReleaseTypeInfo(*info);
      *info = NULL;
    }
    session_invalid(payload, api_name, "type info is unavailable");
    return -1;
  }
  status = api->CastTypeInfoToTensorInfo(*info, tensor);
  if (status != NULL) {
    api->ReleaseTypeInfo(*info);
    *info = NULL;
    write_payload_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "CastTypeInfoToTensorInfo"
    );
    return -1;
  }
  if (*tensor == NULL) {
    api->ReleaseTypeInfo(*info);
    *info = NULL;
    session_invalid(payload, api_name, "value is not a tensor");
    return -1;
  }
  return 0;
}

static int32_t io_element_type(SessionPayload *payload, int32_t index, int is_output) {
  const char *api_name = is_output ? "SessionGetOutputTypeInfo" : "SessionGetInputTypeInfo";
  OrtTypeInfo *info = NULL;
  const OrtTensorTypeAndShapeInfo *tensor = NULL;
  const OrtApi *api;
  OrtStatus *status;
  ONNXTensorElementDataType element = ONNX_TENSOR_ELEMENT_DATA_TYPE_UNDEFINED;
  if (payload == NULL || session_ready(payload, api_name) != 0) {
    return -1;
  }
  if (open_tensor_info(payload, index, is_output, &info, &tensor) != 0) {
    return -1;
  }
  api = payload->env->api;
  if (api->GetTensorElementType == NULL) {
    api->ReleaseTypeInfo(info);
    session_invalid(payload, "GetTensorElementType", "GetTensorElementType is unavailable");
    return -1;
  }
  status = api->GetTensorElementType(tensor, &element);
  api->ReleaseTypeInfo(info);
  if (status != NULL) {
    write_payload_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "GetTensorElementType"
    );
    return -1;
  }
  return (int32_t)element;
}

int32_t moon_ort_session_input_element_type(SessionPayload *payload, int32_t index) {
  return io_element_type(payload, index, 0);
}

int32_t moon_ort_session_output_element_type(SessionPayload *payload, int32_t index) {
  return io_element_type(payload, index, 1);
}

static int64_t *io_shape(SessionPayload *payload, int32_t index, int is_output) {
  const char *api_name = is_output ? "SessionGetOutputTypeInfo" : "SessionGetInputTypeInfo";
  OrtTypeInfo *info = NULL;
  const OrtTensorTypeAndShapeInfo *tensor = NULL;
  const OrtApi *api;
  OrtStatus *status;
  size_t rank = 0;
  int64_t *shape;
  if (payload == NULL || session_ready(payload, api_name) != 0) {
    return moonbit_empty_int64_array;
  }
  if (open_tensor_info(payload, index, is_output, &info, &tensor) != 0) {
    return moonbit_empty_int64_array;
  }
  api = payload->env->api;
  if (api->GetDimensionsCount == NULL || api->GetDimensions == NULL) {
    api->ReleaseTypeInfo(info);
    session_invalid(payload, "GetDimensions", "GetDimensions is unavailable");
    return moonbit_empty_int64_array;
  }
  status = api->GetDimensionsCount(tensor, &rank);
  if (status != NULL) {
    api->ReleaseTypeInfo(info);
    write_payload_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "GetDimensionsCount"
    );
    return moonbit_empty_int64_array;
  }
  if (rank > 64) {
    api->ReleaseTypeInfo(info);
    session_invalid(payload, "GetDimensionsCount", "tensor rank exceeds 64");
    return moonbit_empty_int64_array;
  }
  shape = moonbit_make_int64_array_raw((int32_t)rank);
  if (rank > 0) {
    status = api->GetDimensions(tensor, shape, rank);
    if (status != NULL) {
      moonbit_decref(shape);
      api->ReleaseTypeInfo(info);
      write_payload_status(
        &payload->code,
        &payload->status_code,
        payload->message,
        sizeof(payload->message),
        payload->api_name,
        sizeof(payload->api_name),
        api,
        status,
        "GetDimensions"
      );
      return moonbit_empty_int64_array;
    }
  }
  api->ReleaseTypeInfo(info);
  return shape;
}

int64_t *moon_ort_session_input_shape(SessionPayload *payload, int32_t index) {
  return io_shape(payload, index, 0);
}

int64_t *moon_ort_session_output_shape(SessionPayload *payload, int32_t index) {
  return io_shape(payload, index, 1);
}

static moonbit_string_t *io_params(SessionPayload *payload, int32_t index, int is_output) {
  const char *api_name = is_output ? "SessionGetOutputTypeInfo" : "SessionGetInputTypeInfo";
  OrtTypeInfo *info = NULL;
  const OrtTensorTypeAndShapeInfo *tensor = NULL;
  const OrtApi *api;
  OrtStatus *status;
  size_t rank = 0;
  const char **symbols = NULL;
  moonbit_string_t *result;
  size_t i;
  if (payload == NULL || session_ready(payload, api_name) != 0) {
    return (moonbit_string_t *)moonbit_empty_ref_array;
  }
  if (open_tensor_info(payload, index, is_output, &info, &tensor) != 0) {
    return (moonbit_string_t *)moonbit_empty_ref_array;
  }
  api = payload->env->api;
  if (api->GetDimensionsCount == NULL || api->GetSymbolicDimensions == NULL) {
    api->ReleaseTypeInfo(info);
    session_invalid(payload, "GetSymbolicDimensions", "GetSymbolicDimensions is unavailable");
    return (moonbit_string_t *)moonbit_empty_ref_array;
  }
  status = api->GetDimensionsCount(tensor, &rank);
  if (status != NULL || rank > 64) {
    api->ReleaseTypeInfo(info);
    if (status != NULL) {
      write_payload_status(
        &payload->code,
        &payload->status_code,
        payload->message,
        sizeof(payload->message),
        payload->api_name,
        sizeof(payload->api_name),
        api,
        status,
        "GetDimensionsCount"
      );
    } else {
      session_invalid(payload, "GetSymbolicDimensions", "tensor rank exceeds 64");
    }
    return (moonbit_string_t *)moonbit_empty_ref_array;
  }
  if (rank == 0) {
    api->ReleaseTypeInfo(info);
    return (moonbit_string_t *)moonbit_make_ref_array(0, NULL);
  }
  symbols = calloc(rank, sizeof(*symbols));
  if (symbols == NULL) {
    api->ReleaseTypeInfo(info);
    session_invalid(payload, "GetSymbolicDimensions", "out of memory");
    return (moonbit_string_t *)moonbit_empty_ref_array;
  }
  status = api->GetSymbolicDimensions(tensor, symbols, rank);
  if (status != NULL) {
    free(symbols);
    api->ReleaseTypeInfo(info);
    write_payload_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "GetSymbolicDimensions"
    );
    return (moonbit_string_t *)moonbit_empty_ref_array;
  }
  result = (moonbit_string_t *)moonbit_make_ref_array((int32_t)rank, NULL);
  for (i = 0; i < rank; i++) {
    result[i] = utf8_to_moonbit(symbols[i] != NULL ? symbols[i] : "");
  }
  free(symbols);
  api->ReleaseTypeInfo(info);
  return result;
}

moonbit_string_t *moon_ort_session_input_dimension_params(SessionPayload *payload, int32_t index) {
  return io_params(payload, index, 0);
}

moonbit_string_t *moon_ort_session_output_dimension_params(SessionPayload *payload, int32_t index) {
  return io_params(payload, index, 1);
}

static int open_metadata(SessionPayload *payload, OrtAllocator **allocator, OrtModelMetadata **metadata, const char *api_name) {
  const OrtApi *api;
  OrtStatus *status;
  *allocator = NULL;
  *metadata = NULL;
  if (session_ready(payload, api_name) != 0) {
    return -1;
  }
  api = payload->env->api;
  if (api->SessionGetModelMetadata == NULL || api->ReleaseModelMetadata == NULL) {
    session_invalid(payload, "SessionGetModelMetadata", "SessionGetModelMetadata is unavailable");
    return -1;
  }
  status = api->SessionGetModelMetadata(payload->session, metadata);
  if (status != NULL) {
    write_payload_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "SessionGetModelMetadata"
    );
    return -1;
  }
  if (*metadata == NULL) {
    session_invalid(payload, "SessionGetModelMetadata", "model metadata is null");
    return -1;
  }
  if (load_allocator(payload, allocator) != 0) {
    api->ReleaseModelMetadata(*metadata);
    *metadata = NULL;
    return -1;
  }
  return 0;
}

static moonbit_string_t metadata_string(SessionPayload *payload, int kind) {
  const char *api_name = "ModelMetadataGetProducerName";
  OrtAllocator *allocator = NULL;
  OrtModelMetadata *metadata = NULL;
  const OrtApi *api;
  OrtStatus *status = NULL;
  char *tmp = NULL;
  moonbit_string_t result;
  if (payload == NULL) {
    return utf8_to_moonbit("");
  }
  if (kind == 1) {
    api_name = "ModelMetadataGetGraphName";
  } else if (kind == 2) {
    api_name = "ModelMetadataGetDomain";
  } else if (kind == 3) {
    api_name = "ModelMetadataGetDescription";
  }
  if (open_metadata(payload, &allocator, &metadata, api_name) != 0) {
    return utf8_to_moonbit("");
  }
  api = payload->env->api;
  if (kind == 0) {
    if (api->ModelMetadataGetProducerName == NULL) {
      api->ReleaseModelMetadata(metadata);
      session_invalid(payload, api_name, "ModelMetadataGetProducerName is unavailable");
      return utf8_to_moonbit("");
    }
    status = api->ModelMetadataGetProducerName(metadata, allocator, &tmp);
  } else if (kind == 1) {
    if (api->ModelMetadataGetGraphName == NULL) {
      api->ReleaseModelMetadata(metadata);
      session_invalid(payload, api_name, "ModelMetadataGetGraphName is unavailable");
      return utf8_to_moonbit("");
    }
    status = api->ModelMetadataGetGraphName(metadata, allocator, &tmp);
  } else if (kind == 2) {
    if (api->ModelMetadataGetDomain == NULL) {
      api->ReleaseModelMetadata(metadata);
      session_invalid(payload, api_name, "ModelMetadataGetDomain is unavailable");
      return utf8_to_moonbit("");
    }
    status = api->ModelMetadataGetDomain(metadata, allocator, &tmp);
  } else {
    if (api->ModelMetadataGetDescription == NULL) {
      api->ReleaseModelMetadata(metadata);
      session_invalid(payload, api_name, "ModelMetadataGetDescription is unavailable");
      return utf8_to_moonbit("");
    }
    status = api->ModelMetadataGetDescription(metadata, allocator, &tmp);
  }
  if (status != NULL) {
    free_alloc(api, allocator, tmp, payload, "AllocatorFree");
    api->ReleaseModelMetadata(metadata);
    if (payload->code == MOON_ORT_OK) {
      write_payload_status(
        &payload->code,
        &payload->status_code,
        payload->message,
        sizeof(payload->message),
        payload->api_name,
        sizeof(payload->api_name),
        api,
        status,
        api_name
      );
    } else if (api->ReleaseStatus != NULL) {
      api->ReleaseStatus(status);
    }
    return utf8_to_moonbit("");
  }
  result = utf8_to_moonbit(tmp != NULL ? tmp : "");
  free_alloc(api, allocator, tmp, payload, "AllocatorFree");
  api->ReleaseModelMetadata(metadata);
  if (payload->code != MOON_ORT_OK) {
    moonbit_decref(result);
    return utf8_to_moonbit("");
  }
  return result;
}

moonbit_string_t moon_ort_session_producer_name(SessionPayload *payload) {
  return metadata_string(payload, 0);
}

moonbit_string_t moon_ort_session_graph_name(SessionPayload *payload) {
  return metadata_string(payload, 1);
}

moonbit_string_t moon_ort_session_domain(SessionPayload *payload) {
  return metadata_string(payload, 2);
}

moonbit_string_t moon_ort_session_description(SessionPayload *payload) {
  return metadata_string(payload, 3);
}

int64_t moon_ort_session_model_version(SessionPayload *payload) {
  OrtAllocator *allocator = NULL;
  OrtModelMetadata *metadata = NULL;
  const OrtApi *api;
  OrtStatus *status;
  int64_t version = 0;
  if (payload == NULL || open_metadata(payload, &allocator, &metadata, "ModelMetadataGetVersion") != 0) {
    return 0;
  }
  api = payload->env->api;
  if (api->ModelMetadataGetVersion == NULL) {
    api->ReleaseModelMetadata(metadata);
    session_invalid(payload, "ModelMetadataGetVersion", "ModelMetadataGetVersion is unavailable");
    return 0;
  }
  status = api->ModelMetadataGetVersion(metadata, &version);
  api->ReleaseModelMetadata(metadata);
  if (status != NULL) {
    write_payload_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "ModelMetadataGetVersion"
    );
    return 0;
  }
  return version;
}

moonbit_string_t *moon_ort_session_custom_metadata_keys(SessionPayload *payload) {
  OrtAllocator *allocator = NULL;
  OrtModelMetadata *metadata = NULL;
  const OrtApi *api;
  OrtStatus *status;
  char **keys = NULL;
  int64_t count = 0;
  moonbit_string_t *result;
  int64_t i;
  if (payload == NULL || open_metadata(payload, &allocator, &metadata, "ModelMetadataGetCustomMetadataMapKeys") != 0) {
    return (moonbit_string_t *)moonbit_empty_ref_array;
  }
  api = payload->env->api;
  if (api->ModelMetadataGetCustomMetadataMapKeys == NULL) {
    api->ReleaseModelMetadata(metadata);
    session_invalid(payload, "ModelMetadataGetCustomMetadataMapKeys", "ModelMetadataGetCustomMetadataMapKeys is unavailable");
    return (moonbit_string_t *)moonbit_empty_ref_array;
  }
  status = api->ModelMetadataGetCustomMetadataMapKeys(metadata, allocator, &keys, &count);
  if (status != NULL) {
    api->ReleaseModelMetadata(metadata);
    write_payload_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "ModelMetadataGetCustomMetadataMapKeys"
    );
    return (moonbit_string_t *)moonbit_empty_ref_array;
  }
  if (count < 0 || count > 4096) {
    free_alloc(api, allocator, keys, payload, "AllocatorFree");
    api->ReleaseModelMetadata(metadata);
    session_invalid(payload, "ModelMetadataGetCustomMetadataMapKeys", "custom metadata key count is invalid");
    return (moonbit_string_t *)moonbit_empty_ref_array;
  }
  if (count == 0 || keys == NULL) {
    free_alloc(api, allocator, keys, payload, "AllocatorFree");
    api->ReleaseModelMetadata(metadata);
    return (moonbit_string_t *)moonbit_make_ref_array(0, NULL);
  }
  result = (moonbit_string_t *)moonbit_make_ref_array((int32_t)count, NULL);
  for (i = 0; i < count; i++) {
    result[i] = utf8_to_moonbit(keys[i] != NULL ? keys[i] : "");
    free_alloc(api, allocator, keys[i], payload, "AllocatorFree");
    keys[i] = NULL;
  }
  free_alloc(api, allocator, keys, payload, "AllocatorFree");
  api->ReleaseModelMetadata(metadata);
  if (payload->code != MOON_ORT_OK) {
    moonbit_decref(result);
    return (moonbit_string_t *)moonbit_empty_ref_array;
  }
  return result;
}

moonbit_string_t moon_ort_session_custom_metadata(SessionPayload *payload, moonbit_string_t key) {
  OrtAllocator *allocator = NULL;
  OrtModelMetadata *metadata = NULL;
  const OrtApi *api;
  OrtStatus *status;
  char ckey[1024];
  char *value = NULL;
  moonbit_string_t result;
  if (payload == NULL) {
    return utf8_to_moonbit("");
  }
  if (session_ready(payload, "ModelMetadataLookupCustomMetadataMap") != 0) {
    return utf8_to_moonbit("");
  }
  if (key == NULL || Moonbit_array_length(key) == 0) {
    session_invalid(payload, "ModelMetadataLookupCustomMetadataMap", "custom metadata key is empty");
    return utf8_to_moonbit("");
  }
  if (utf16_to_utf8(key, Moonbit_array_length(key), ckey, sizeof(ckey)) < 0) {
    session_invalid(payload, "ModelMetadataLookupCustomMetadataMap", "custom metadata key is too long");
    return utf8_to_moonbit("");
  }
  if (open_metadata(payload, &allocator, &metadata, "ModelMetadataLookupCustomMetadataMap") != 0) {
    return utf8_to_moonbit("");
  }
  api = payload->env->api;
  if (api->ModelMetadataLookupCustomMetadataMap == NULL) {
    api->ReleaseModelMetadata(metadata);
    session_invalid(payload, "ModelMetadataLookupCustomMetadataMap", "ModelMetadataLookupCustomMetadataMap is unavailable");
    return utf8_to_moonbit("");
  }
  status = api->ModelMetadataLookupCustomMetadataMap(metadata, allocator, ckey, &value);
  if (status != NULL) {
    api->ReleaseModelMetadata(metadata);
    write_payload_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "ModelMetadataLookupCustomMetadataMap"
    );
    return utf8_to_moonbit("");
  }
  if (value == NULL) {
    api->ReleaseModelMetadata(metadata);
    session_invalid(payload, "ModelMetadataLookupCustomMetadataMap", "custom metadata key not found");
    return utf8_to_moonbit("");
  }
  result = utf8_to_moonbit(value);
  free_alloc(api, allocator, value, payload, "AllocatorFree");
  api->ReleaseModelMetadata(metadata);
  if (payload->code != MOON_ORT_OK) {
    moonbit_decref(result);
    return utf8_to_moonbit("");
  }
  return result;
}
