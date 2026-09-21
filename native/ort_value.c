#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "ort_shared.h"

typedef struct ValuePayload {
  int32_t code;
  int32_t state;
  int32_t status_code;
  int32_t element_type;
  int32_t rank;
  int32_t byte_count;
  int64_t element_count;
  int64_t *shape;
  char message[768];
  char api_name[64];
  EnvPayload *env;
  OrtValue *value;
} ValuePayload;

#define MOON_ORT_VALUE_ACCESSORS(prefix, Type)                                 \
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

static void value_invalid(ValuePayload *payload, const char *api, const char *text) {
  payload->code = MOON_ORT_INVALID_ARGUMENT;
  copy_cstr(payload->api_name, sizeof(payload->api_name), api);
  copy_cstr(payload->message, sizeof(payload->message), text);
}

static void release_value(ValuePayload *payload) {
  EnvPayload *env;
  if (payload->state != MOON_ORT_STATE_OPEN) {
    free(payload->shape);
    payload->shape = NULL;
    return;
  }
  payload->state = MOON_ORT_STATE_CLOSED;
  env = payload->env;
  if (payload->value != NULL && env != NULL && env->api != NULL && env->api->ReleaseValue != NULL) {
    env->api->ReleaseValue(payload->value);
  }
  payload->value = NULL;
  payload->env = NULL;
  free(payload->shape);
  payload->shape = NULL;
  if (env != NULL) {
    moon_ort_unpin_env(env);
  }
}

static void value_finalize(void *self) {
  release_value((ValuePayload *)self);
}

static ValuePayload *new_value_payload(void) {
  ValuePayload *payload = moonbit_make_external_object(value_finalize, (uint32_t)sizeof(ValuePayload));
  memset(payload, 0, sizeof(*payload));
  payload->state = MOON_ORT_STATE_FAILED;
  payload->status_code = -1;
  payload->element_type = -1;
  return payload;
}

static int value_ready(ValuePayload *payload, const char *api) {
  if (payload == NULL) {
    return -1;
  }
  payload->status_code = -1;
  payload->message[0] = '\0';
  copy_cstr(payload->api_name, sizeof(payload->api_name), api);
  if (payload->state != MOON_ORT_STATE_OPEN || payload->value == NULL || payload->env == NULL ||
      payload->env->api == NULL || payload->env->state != MOON_ORT_STATE_OPEN) {
    payload->code = MOON_ORT_USE_AFTER_CLOSE;
    copy_cstr(payload->message, sizeof(payload->message), "tensor value is closed");
    return -1;
  }
  payload->code = MOON_ORT_OK;
  return 0;
}

static int element_width(int32_t element_type, size_t *width) {
  if (element_type == ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT) {
    *width = 4;
    return 0;
  }
  if (element_type == ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64) {
    *width = 8;
    return 0;
  }
  if (element_type == ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL) {
    *width = 1;
    return 0;
  }
  return -1;
}

static int shape_product(const int64_t *shape, int32_t rank, int64_t *count) {
  int64_t acc = 1;
  int32_t i;
  for (i = 0; i < rank; i++) {
    int64_t dim = shape[i];
    if (dim < 0) {
      return -1;
    }
    if (dim != 0 && acc > INT64_MAX / dim) {
      return -2;
    }
    acc *= dim;
  }
  *count = acc;
  return 0;
}

static void drop_created(const OrtApi *api, OrtValue *value, OrtTensorTypeAndShapeInfo *info) {
  if (info != NULL && api != NULL && api->ReleaseTensorTypeAndShapeInfo != NULL) {
    api->ReleaseTensorTypeAndShapeInfo(info);
  }
  if (value != NULL && api != NULL && api->ReleaseValue != NULL) {
    api->ReleaseValue(value);
  }
}

MOON_ORT_VALUE_ACCESSORS(value, ValuePayload)

ValuePayload *moon_ort_value_create(
  EnvPayload *env,
  int32_t element_type,
  int64_t *shape,
  moonbit_bytes_t data
) {
  ValuePayload *payload = new_value_payload();
  const OrtApi *api;
  OrtAllocator *allocator = NULL;
  OrtValue *value = NULL;
  OrtTensorTypeAndShapeInfo *info = NULL;
  OrtStatus *status;
  int32_t rank;
  int32_t i;
  int64_t count = 0;
  size_t width = 0;
  int32_t data_len;
  int32_t byte_count;
  int product;
  void *buffer = NULL;
  ONNXTensorElementDataType actual = ONNX_TENSOR_ELEMENT_DATA_TYPE_UNDEFINED;
  size_t actual_rank = 0;
  int64_t *actual_dims = NULL;
  copy_cstr(payload->api_name, sizeof(payload->api_name), "CreateTensorAsOrtValue");
  if (env == NULL || env->state != MOON_ORT_STATE_OPEN || env->api == NULL) {
    payload->code = MOON_ORT_USE_AFTER_CLOSE;
    copy_cstr(payload->message, sizeof(payload->message), "runtime is closed");
    return payload;
  }
  if (shape == NULL) {
    value_invalid(payload, "CreateTensorAsOrtValue", "tensor shape is null");
    return payload;
  }
  rank = Moonbit_array_length(shape);
  if (rank < 0 || rank > 64) {
    value_invalid(payload, "CreateTensorAsOrtValue", "tensor rank exceeds 64");
    return payload;
  }
  if (element_width(element_type, &width) != 0) {
    value_invalid(payload, "CreateTensorAsOrtValue", "tensor element type is not f32, i64, or bool");
    return payload;
  }
  product = shape_product(shape, rank, &count);
  if (product == -1) {
    value_invalid(payload, "CreateTensorAsOrtValue", "tensor dimension is negative");
    return payload;
  }
  if (product == -2) {
    value_invalid(payload, "CreateTensorAsOrtValue", "tensor shape product overflows");
    return payload;
  }
  if (count > (int64_t)(INT32_MAX / width)) {
    value_invalid(payload, "CreateTensorAsOrtValue", "tensor byte count overflows");
    return payload;
  }
  byte_count = (int32_t)(count * (int64_t)width);
  data_len = data == NULL ? 0 : Moonbit_array_length(data);
  if (data == NULL && data_len != 0) {
    value_invalid(payload, "CreateTensorAsOrtValue", "tensor data is null");
    return payload;
  }
  if (data_len != byte_count) {
    value_invalid(payload, "CreateTensorAsOrtValue", "tensor byte count does not match data");
    return payload;
  }
  if (element_type == ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL) {
    for (i = 0; i < data_len; i++) {
      if (data[i] > 1) {
        value_invalid(payload, "CreateTensorAsOrtValue", "bool tensor byte is not 0 or 1");
        return payload;
      }
    }
  }
  api = env->api;
  if (api->GetAllocatorWithDefaultOptions == NULL || api->CreateTensorAsOrtValue == NULL ||
      api->GetTensorMutableData == NULL || api->ReleaseValue == NULL || api->GetTensorTypeAndShape == NULL ||
      api->GetTensorElementType == NULL || api->GetDimensionsCount == NULL || api->GetDimensions == NULL ||
      api->ReleaseTensorTypeAndShapeInfo == NULL) {
    value_invalid(payload, "CreateTensorAsOrtValue", "tensor API is unavailable");
    return payload;
  }
  status = api->GetAllocatorWithDefaultOptions(&allocator);
  if (status != NULL) {
    moon_ort_write_status(
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
    return payload;
  }
  if (allocator == NULL) {
    value_invalid(payload, "GetAllocatorWithDefaultOptions", "default allocator is null");
    return payload;
  }
  status = api->CreateTensorAsOrtValue(
    allocator,
    rank == 0 ? NULL : shape,
    (size_t)rank,
    (ONNXTensorElementDataType)element_type,
    &value
  );
  if (status != NULL) {
    drop_created(api, value, NULL);
    moon_ort_write_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "CreateTensorAsOrtValue"
    );
    return payload;
  }
  if (value == NULL) {
    value_invalid(payload, "CreateTensorAsOrtValue", "CreateTensorAsOrtValue returned NULL");
    return payload;
  }
  status = api->GetTensorMutableData(value, &buffer);
  if (status != NULL) {
    drop_created(api, value, NULL);
    moon_ort_write_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "GetTensorMutableData"
    );
    return payload;
  }
  if (byte_count > 0 && buffer == NULL) {
    drop_created(api, value, NULL);
    value_invalid(payload, "GetTensorMutableData", "tensor buffer is null");
    return payload;
  }
  if (byte_count > 0) {
    memcpy(buffer, data, (size_t)byte_count);
  }
  status = api->GetTensorTypeAndShape(value, &info);
  if (status != NULL) {
    drop_created(api, value, NULL);
    moon_ort_write_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "GetTensorTypeAndShape"
    );
    return payload;
  }
  status = api->GetTensorElementType(info, &actual);
  if (status == NULL) {
    status = api->GetDimensionsCount(info, &actual_rank);
  }
  if (status == NULL && actual_rank != (size_t)rank) {
    drop_created(api, value, info);
    value_invalid(payload, "GetDimensionsCount", "tensor rank does not match OrtValue");
    return payload;
  }
  if (status == NULL && rank > 0) {
    actual_dims = calloc((size_t)rank, sizeof(*actual_dims));
    if (actual_dims == NULL) {
      drop_created(api, value, info);
      value_invalid(payload, "GetDimensions", "out of memory");
      return payload;
    }
    status = api->GetDimensions(info, actual_dims, (size_t)rank);
  }
  if (status != NULL) {
    free(actual_dims);
    drop_created(api, value, info);
    moon_ort_write_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "GetTensorTypeAndShape"
    );
    return payload;
  }
  if ((int32_t)actual != element_type) {
    free(actual_dims);
    drop_created(api, value, info);
    value_invalid(payload, "GetTensorElementType", "tensor element type does not match OrtValue");
    return payload;
  }
  for (i = 0; i < rank; i++) {
    if (actual_dims[i] != shape[i]) {
      free(actual_dims);
      drop_created(api, value, info);
      value_invalid(payload, "GetDimensions", "tensor shape does not match OrtValue");
      return payload;
    }
  }
  free(actual_dims);
  api->ReleaseTensorTypeAndShapeInfo(info);
  if (rank > 0) {
    payload->shape = malloc(sizeof(int64_t) * (size_t)rank);
    if (payload->shape == NULL) {
      drop_created(api, value, NULL);
      value_invalid(payload, "CreateTensorAsOrtValue", "out of memory");
      return payload;
    }
    memcpy(payload->shape, shape, sizeof(int64_t) * (size_t)rank);
  }
  payload->env = env;
  payload->value = value;
  payload->element_type = element_type;
  payload->rank = rank;
  payload->element_count = count;
  payload->byte_count = byte_count;
  payload->state = MOON_ORT_STATE_OPEN;
  payload->code = MOON_ORT_OK;
  moon_ort_pin_env(env);
  return payload;
}

int32_t moon_ort_value_close(ValuePayload *payload) {
  if (payload == NULL || payload->state == MOON_ORT_STATE_FAILED) {
    return MOON_ORT_INVALID_ARGUMENT;
  }
  if (payload->state != MOON_ORT_STATE_OPEN) {
    return MOON_ORT_ALREADY_CLOSED;
  }
  release_value(payload);
  return MOON_ORT_OK;
}

int32_t moon_ort_value_element_type(ValuePayload *payload) {
  if (value_ready(payload, "Value::element_type") != 0) {
    return -1;
  }
  return payload->element_type;
}

int64_t *moon_ort_value_shape(ValuePayload *payload) {
  int64_t *shape;
  if (payload == NULL || value_ready(payload, "Value::shape") != 0) {
    return moonbit_empty_int64_array;
  }
  shape = moonbit_make_int64_array_raw(payload->rank);
  if (payload->rank > 0) {
    memcpy(shape, payload->shape, sizeof(int64_t) * (size_t)payload->rank);
  }
  return shape;
}

int64_t moon_ort_value_element_count(ValuePayload *payload) {
  if (value_ready(payload, "Value::element_count") != 0) {
    return 0;
  }
  return payload->element_count;
}

int32_t moon_ort_value_byte_count(ValuePayload *payload) {
  if (value_ready(payload, "Value::byte_count") != 0) {
    return -1;
  }
  return payload->byte_count;
}

moonbit_bytes_t moon_ort_value_copy_bytes(ValuePayload *payload) {
  const OrtApi *api;
  OrtStatus *status;
  void *buffer = NULL;
  moonbit_bytes_t out;
  if (payload == NULL || value_ready(payload, "GetTensorMutableData") != 0) {
    return moonbit_make_bytes_raw(0);
  }
  api = payload->env->api;
  if (api->GetTensorMutableData == NULL) {
    value_invalid(payload, "GetTensorMutableData", "GetTensorMutableData is unavailable");
    return moonbit_make_bytes_raw(0);
  }
  status = api->GetTensorMutableData(payload->value, &buffer);
  if (status != NULL) {
    moon_ort_write_status(
      &payload->code,
      &payload->status_code,
      payload->message,
      sizeof(payload->message),
      payload->api_name,
      sizeof(payload->api_name),
      api,
      status,
      "GetTensorMutableData"
    );
    return moonbit_make_bytes_raw(0);
  }
  if (payload->byte_count == 0) {
    return moonbit_make_bytes_raw(0);
  }
  if (buffer == NULL) {
    value_invalid(payload, "GetTensorMutableData", "tensor buffer is null");
    return moonbit_make_bytes_raw(0);
  }
  out = moonbit_make_bytes_raw(payload->byte_count);
  memcpy(out, buffer, (size_t)payload->byte_count);
  return out;
}
