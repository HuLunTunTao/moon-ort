#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "onnxruntime_c_api.h"

/* gcc-15 stand-in for ONNX Runtime 1.30.0. The vector [2.0, -3.5] is the
 * add_f32 fixture echo, not an official ORT differential result. */

typedef struct FakeOptions {
  int magic;
} FakeOptions;

typedef struct FakeSession {
  int magic;
  int fail;
} FakeSession;

typedef struct FakeTensor {
  int magic;
  int orphan;
  int element;
  int rank;
  int64_t *dims;
  uint8_t *data;
  size_t nbytes;
} FakeTensor;

typedef struct FakeInfo {
  int magic;
  int element;
  int rank;
  int64_t *dims;
} FakeInfo;

typedef struct FakeStatus {
  int magic;
  int code;
  char message[160];
} FakeStatus;

typedef struct FakeMetadata {
  int magic;
} FakeMetadata;

enum {
  FAKE_OPTIONS = 0x4F505453,
  FAKE_SESSION = 0x53455353,
  FAKE_TENSOR = 0x54454E53,
  FAKE_INFO = 0x494E464F,
  FAKE_STATUS = 0x53544154,
  FAKE_META = 0x4D455441
};

static int env_creates = 0;
static int env_releases = 0;
static int status_live = 0;
static int alloc_live = 0;
static int info_live = 0;
static int tensor_live = 0;
static int orphan_live = 0;
static int meta_live = 0;
static int options_live = 0;
static int session_live = 0;
static OrtEnv *const k_env = (OrtEnv *)(uintptr_t)0x41;

static const uint8_t k_add_input[8] = {0x00, 0x00, 0x00, 0x3f, 0x00, 0x00, 0xc0, 0xbf};
static const uint8_t k_add_output[8] = {0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x60, 0xc0};

static OrtStatus *make_status(int code, const char *message) {
  FakeStatus *status = calloc(1, sizeof(*status));
  if (status == NULL) {
    abort();
  }
  status->magic = FAKE_STATUS;
  status->code = code;
  if (message == NULL) {
    message = "";
  }
  snprintf(status->message, sizeof(status->message), "%s", message);
  status_live++;
  return (OrtStatus *)status;
}

static void *fake_alloc(OrtAllocator *this_, size_t size) {
  void *ptr;
  (void)this_;
  if (size == 0) {
    return NULL;
  }
  ptr = calloc(1, size);
  if (ptr == NULL) {
    abort();
  }
  alloc_live++;
  return ptr;
}

static void fake_free(OrtAllocator *this_, void *ptr) {
  (void)this_;
  if (ptr == NULL) {
    return;
  }
  alloc_live--;
  if (alloc_live < 0) {
    abort();
  }
  free(ptr);
}

static OrtStatus *fake_allocator_free(OrtAllocator *allocator, void *ptr) {
  fake_free(allocator, ptr);
  return NULL;
}

static char *alloc_dup(OrtAllocator *allocator, const char *text) {
  size_t n = strlen(text) + 1;
  char *buf = (char *)allocator->Alloc(allocator, n);
  if (buf == NULL) {
    return NULL;
  }
  memcpy(buf, text, n);
  return buf;
}

static OrtAllocator *default_allocator(void) {
  static OrtAllocator allocator;
  static int ready = 0;
  if (!ready) {
    memset(&allocator, 0, sizeof(allocator));
    allocator.version = ORT_API_VERSION;
    allocator.Alloc = fake_alloc;
    allocator.Free = fake_free;
    ready = 1;
  }
  return &allocator;
}

static OrtStatus *fake_get_allocator(OrtAllocator **out) {
  *out = default_allocator();
  return NULL;
}

static OrtStatus *fake_create_env(OrtLoggingLevel level, const char *logid, OrtEnv **out) {
  (void)level;
  (void)logid;
  env_creates++;
  *out = k_env;
  return NULL;
}

static void fake_release_env(OrtEnv *input) {
  (void)input;
  env_releases++;
  if (env_releases > env_creates) {
    abort();
  }
}

static OrtStatus *fake_create_options(OrtSessionOptions **options) {
  FakeOptions *created = calloc(1, sizeof(*created));
  if (created == NULL) {
    abort();
  }
  created->magic = FAKE_OPTIONS;
  options_live++;
  *options = (OrtSessionOptions *)created;
  return NULL;
}

static void fake_release_options(OrtSessionOptions *input) {
  FakeOptions *options = (FakeOptions *)input;
  if (options == NULL || options->magic != FAKE_OPTIONS) {
    abort();
  }
  options->magic = 0;
  options_live--;
  if (options_live < 0) {
    abort();
  }
  free(options);
}

static OrtStatus *fake_create_session(
  const OrtEnv *env,
  const char *model_path,
  const OrtSessionOptions *options,
  OrtSession **out
) {
  FakeOptions *parsed = (FakeOptions *)options;
  FakeSession *session;
  (void)env;
  *out = NULL;
  if (parsed == NULL || parsed->magic != FAKE_OPTIONS) {
    abort();
  }
  if (model_path == NULL || (strcmp(model_path, "ok.onnx") != 0 && strcmp(model_path, "fail-run.onnx") != 0)) {
    return make_status(ORT_NO_SUCHFILE, "model file not found");
  }
  session = calloc(1, sizeof(*session));
  if (session == NULL) {
    abort();
  }
  session->magic = FAKE_SESSION;
  session->fail = strcmp(model_path, "fail-run.onnx") == 0;
  session_live++;
  *out = (OrtSession *)session;
  return NULL;
}

static void fake_release_session(OrtSession *input) {
  FakeSession *session = (FakeSession *)input;
  if (session == NULL || session->magic != FAKE_SESSION) {
    abort();
  }
  session->magic = 0;
  session_live--;
  if (session_live < 0) {
    abort();
  }
  free(session);
}

static OrtErrorCode fake_error_code(const OrtStatus *status) {
  const FakeStatus *parsed = (const FakeStatus *)status;
  if (parsed == NULL || parsed->magic != FAKE_STATUS) {
    abort();
  }
  return (OrtErrorCode)parsed->code;
}

static const char *fake_error_message(const OrtStatus *status) {
  const FakeStatus *parsed = (const FakeStatus *)status;
  if (parsed == NULL || parsed->magic != FAKE_STATUS) {
    abort();
  }
  return parsed->message;
}

static void fake_release_status(OrtStatus *status) {
  FakeStatus *parsed = (FakeStatus *)status;
  if (parsed == NULL || parsed->magic != FAKE_STATUS) {
    abort();
  }
  parsed->magic = 0;
  status_live--;
  if (status_live < 0) {
    abort();
  }
  free(parsed);
}

static OrtStatus *fake_input_count(const OrtSession *session, size_t *out) {
  (void)session;
  *out = 1;
  return NULL;
}

static OrtStatus *fake_output_count(const OrtSession *session, size_t *out) {
  (void)session;
  *out = 1;
  return NULL;
}

static OrtStatus *fake_input_name(const OrtSession *session, size_t index, OrtAllocator *allocator, char **value) {
  (void)session;
  if (index != 0) {
    return make_status(ORT_INVALID_ARGUMENT, "input index");
  }
  *value = alloc_dup(allocator, "input");
  if (*value == NULL) {
    return make_status(ORT_FAIL, "out of memory");
  }
  return NULL;
}

static OrtStatus *fake_output_name(const OrtSession *session, size_t index, OrtAllocator *allocator, char **value) {
  (void)session;
  if (index != 0) {
    return make_status(ORT_INVALID_ARGUMENT, "output index");
  }
  *value = alloc_dup(allocator, "output");
  if (*value == NULL) {
    return make_status(ORT_FAIL, "out of memory");
  }
  return NULL;
}

static FakeTensor *as_tensor(OrtValue *value) {
  FakeTensor *tensor = (FakeTensor *)value;
  if (tensor == NULL || tensor->magic != FAKE_TENSOR) {
    abort();
  }
  return tensor;
}

static FakeTensor *make_tensor(int element, int rank, const int64_t *dims, const uint8_t *data, size_t nbytes) {
  FakeTensor *tensor = calloc(1, sizeof(*tensor));
  if (tensor == NULL) {
    abort();
  }
  tensor->magic = FAKE_TENSOR;
  tensor->element = element;
  tensor->rank = rank;
  tensor->nbytes = nbytes;
  if (rank > 0) {
    tensor->dims = calloc((size_t)rank, sizeof(int64_t));
    if (tensor->dims == NULL) {
      abort();
    }
    memcpy(tensor->dims, dims, (size_t)rank * sizeof(int64_t));
  }
  if (nbytes > 0) {
    tensor->data = calloc(1, nbytes);
    if (tensor->data == NULL) {
      abort();
    }
    if (data != NULL) {
      memcpy(tensor->data, data, nbytes);
    }
  }
  tensor_live++;
  return tensor;
}

static size_t element_width(int element) {
  if (element == ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT) {
    return 4;
  }
  if (element == ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64) {
    return 8;
  }
  if (element == ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL) {
    return 1;
  }
  return 0;
}

static OrtStatus *fake_create_tensor(
  OrtAllocator *allocator,
  const int64_t *shape,
  size_t shape_len,
  ONNXTensorElementDataType type,
  OrtValue **out
) {
  size_t width;
  size_t i;
  int64_t count = 1;
  (void)allocator;
  *out = NULL;
  width = element_width((int)type);
  if (width == 0) {
    return make_status(ORT_INVALID_ARGUMENT, "unsupported dtype");
  }
  for (i = 0; i < shape_len; i++) {
    if (shape == NULL || shape[i] < 0) {
      return make_status(ORT_INVALID_ARGUMENT, "bad shape");
    }
    count *= shape[i];
  }
  *out = (OrtValue *)make_tensor((int)type, (int)shape_len, shape, NULL, (size_t)count * width);
  return NULL;
}

static void fake_release_value(OrtValue *input) {
  FakeTensor *tensor = as_tensor(input);
  if (tensor->orphan) {
    orphan_live--;
    if (orphan_live < 0) {
      abort();
    }
  }
  tensor->magic = 0;
  free(tensor->dims);
  free(tensor->data);
  free(tensor);
  tensor_live--;
  if (tensor_live < 0) {
    abort();
  }
}

static OrtStatus *fake_mutable_data(OrtValue *value, void **out) {
  *out = as_tensor(value)->data;
  return NULL;
}

static OrtStatus *fake_type_and_shape(const OrtValue *value, OrtTensorTypeAndShapeInfo **out) {
  const FakeTensor *tensor = (const FakeTensor *)value;
  FakeInfo *info;
  if (tensor == NULL || tensor->magic != FAKE_TENSOR) {
    abort();
  }
  info = calloc(1, sizeof(*info));
  if (info == NULL) {
    abort();
  }
  info->magic = FAKE_INFO;
  info->element = tensor->element;
  info->rank = tensor->rank;
  if (tensor->rank > 0) {
    info->dims = calloc((size_t)tensor->rank, sizeof(int64_t));
    if (info->dims == NULL) {
      abort();
    }
    memcpy(info->dims, tensor->dims, (size_t)tensor->rank * sizeof(int64_t));
  }
  info_live++;
  *out = (OrtTensorTypeAndShapeInfo *)info;
  return NULL;
}

static void fake_release_info(OrtTensorTypeAndShapeInfo *input) {
  FakeInfo *info = (FakeInfo *)input;
  if (info == NULL || info->magic != FAKE_INFO) {
    abort();
  }
  info->magic = 0;
  free(info->dims);
  free(info);
  info_live--;
  if (info_live < 0) {
    abort();
  }
}

static OrtStatus *fake_element(const OrtTensorTypeAndShapeInfo *info, enum ONNXTensorElementDataType *out) {
  const FakeInfo *parsed = (const FakeInfo *)info;
  if (parsed == NULL || parsed->magic != FAKE_INFO) {
    abort();
  }
  *out = (enum ONNXTensorElementDataType)parsed->element;
  return NULL;
}

static OrtStatus *fake_rank(const OrtTensorTypeAndShapeInfo *info, size_t *out) {
  const FakeInfo *parsed = (const FakeInfo *)info;
  if (parsed == NULL || parsed->magic != FAKE_INFO) {
    abort();
  }
  *out = (size_t)parsed->rank;
  return NULL;
}

static OrtStatus *fake_dims(const OrtTensorTypeAndShapeInfo *info, int64_t *dim_values, size_t dim_values_length) {
  const FakeInfo *parsed = (const FakeInfo *)info;
  if (parsed == NULL || parsed->magic != FAKE_INFO) {
    abort();
  }
  if (dim_values_length != (size_t)parsed->rank) {
    return make_status(ORT_INVALID_ARGUMENT, "rank mismatch");
  }
  if (dim_values_length > 0) {
    memcpy(dim_values, parsed->dims, dim_values_length * sizeof(int64_t));
  }
  return NULL;
}

static int matches_add_input(OrtValue *value) {
  FakeTensor *tensor = as_tensor(value);
  if (tensor->element != ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT || tensor->rank != 1) {
    return 0;
  }
  if (tensor->dims == NULL || tensor->dims[0] != 2 || tensor->nbytes != sizeof(k_add_input)) {
    return 0;
  }
  return tensor->data != NULL && memcmp(tensor->data, k_add_input, sizeof(k_add_input)) == 0;
}

static OrtStatus *fake_run(
  OrtSession *session,
  const OrtRunOptions *run_options,
  const char *const *input_names,
  const OrtValue *const *inputs,
  size_t input_len,
  const char *const *output_names,
  size_t output_names_len,
  OrtValue **outputs
) {
  FakeSession *parsed = (FakeSession *)session;
  static const int64_t dims[1] = {2};
  FakeTensor *output;
  (void)run_options;
  if (parsed == NULL || parsed->magic != FAKE_SESSION) {
    abort();
  }
  if (input_len != 1 || output_names_len != 1 || input_names == NULL || inputs == NULL || output_names == NULL ||
      outputs == NULL) {
    return make_status(ORT_INVALID_ARGUMENT, "run arity");
  }
  if (strcmp(input_names[0], "input") != 0 || strcmp(output_names[0], "output") != 0) {
    return make_status(ORT_INVALID_ARGUMENT, "run name");
  }
  outputs[0] = NULL;
  if (parsed->fail) {
    output = make_tensor(ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, 1, dims, k_add_output, sizeof(k_add_output));
    output->orphan = 1;
    orphan_live++;
    outputs[0] = (OrtValue *)output;
    return make_status(ORT_FAIL, "run failed after output");
  }
  if (!matches_add_input((OrtValue *)inputs[0])) {
    return make_status(ORT_INVALID_ARGUMENT, "input does not match add_f32 fixture");
  }
  output = make_tensor(ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, 1, dims, k_add_output, sizeof(k_add_output));
  outputs[0] = (OrtValue *)output;
  return NULL;
}

static OrtStatus *fake_metadata(const OrtSession *session, OrtModelMetadata **out) {
  FakeMetadata *metadata = calloc(1, sizeof(*metadata));
  (void)session;
  if (metadata == NULL) {
    abort();
  }
  metadata->magic = FAKE_META;
  meta_live++;
  *out = (OrtModelMetadata *)metadata;
  return NULL;
}

static void fake_release_metadata(OrtModelMetadata *input) {
  FakeMetadata *metadata = (FakeMetadata *)input;
  if (metadata == NULL || metadata->magic != FAKE_META) {
    abort();
  }
  metadata->magic = 0;
  meta_live--;
  if (meta_live < 0) {
    abort();
  }
  free(metadata);
}

static OrtStatus *fake_lookup(
  const OrtModelMetadata *metadata,
  OrtAllocator *allocator,
  const char *key,
  char **value
) {
  char text[32];
  const FakeMetadata *parsed = (const FakeMetadata *)metadata;
  if (parsed == NULL || parsed->magic != FAKE_META) {
    abort();
  }
  if (key != NULL && strcmp(key, "status_live") == 0) {
    snprintf(text, sizeof(text), "%d", status_live);
    *value = alloc_dup(allocator, text);
    return *value == NULL ? make_status(ORT_FAIL, "out of memory") : NULL;
  }
  if (key != NULL && strcmp(key, "orphan_live") == 0) {
    snprintf(text, sizeof(text), "%d", orphan_live);
    *value = alloc_dup(allocator, text);
    return *value == NULL ? make_status(ORT_FAIL, "out of memory") : NULL;
  }
  *value = NULL;
  return NULL;
}

static const OrtApi *fake_get_api(uint32_t version) {
  static OrtApi api;
  static int ready = 0;
  if (version == 0 || version > ORT_API_VERSION) {
    return NULL;
  }
  if (!ready) {
    memset(&api, 0, sizeof(api));
    api.CreateEnv = fake_create_env;
    api.ReleaseEnv = fake_release_env;
    api.CreateSessionOptions = fake_create_options;
    api.ReleaseSessionOptions = fake_release_options;
    api.CreateSession = fake_create_session;
    api.ReleaseSession = fake_release_session;
    api.Run = fake_run;
    api.GetErrorCode = fake_error_code;
    api.GetErrorMessage = fake_error_message;
    api.ReleaseStatus = fake_release_status;
    api.SessionGetInputCount = fake_input_count;
    api.SessionGetOutputCount = fake_output_count;
    api.SessionGetInputName = fake_input_name;
    api.SessionGetOutputName = fake_output_name;
    api.GetAllocatorWithDefaultOptions = fake_get_allocator;
    api.AllocatorFree = fake_allocator_free;
    api.CreateTensorAsOrtValue = fake_create_tensor;
    api.GetTensorMutableData = fake_mutable_data;
    api.ReleaseValue = fake_release_value;
    api.GetTensorTypeAndShape = fake_type_and_shape;
    api.ReleaseTensorTypeAndShapeInfo = fake_release_info;
    api.GetTensorElementType = fake_element;
    api.GetDimensionsCount = fake_rank;
    api.GetDimensions = fake_dims;
    api.SessionGetModelMetadata = fake_metadata;
    api.ReleaseModelMetadata = fake_release_metadata;
    api.ModelMetadataLookupCustomMetadataMap = fake_lookup;
    ready = 1;
  }
  return &api;
}

static const char *fake_version_string(void) {
  return "fake-run-1.30.0";
}

static const OrtApiBase k_base = {fake_get_api, fake_version_string};

const OrtApiBase *ORT_API_CALL OrtGetApiBase(void) {
  return &k_base;
}

__attribute__((destructor)) static void moon_ort_fake_run_check(void) {
  if (status_live != 0 || alloc_live != 0 || info_live != 0 || tensor_live != 0 || orphan_live != 0 ||
      meta_live != 0 || options_live != 0 || session_live != 0 || env_releases != env_creates) {
    abort();
  }
}
