#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "onnxruntime_c_api.h"

typedef struct FakeTensor {
  int magic;
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

enum { FAKE_TENSOR = 0x54454E53, FAKE_INFO = 0x494E464F, FAKE_STATUS = 0x53544154 };

static int env_creates = 0;
static int env_releases = 0;
static int status_live = 0;
static int info_live = 0;
static OrtEnv *const k_env = (OrtEnv *)(uintptr_t)0x31;

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
  memcpy(status->message, message, strlen(message) + 1 > 159 ? 159 : strlen(message) + 1);
  status->message[159] = '\0';
  status_live++;
  return (OrtStatus *)status;
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

static void *fake_alloc(OrtAllocator *this_, size_t size) {
  (void)this_;
  if (size == 0) {
    return NULL;
  }
  return calloc(1, size);
}

static void fake_free(OrtAllocator *this_, void *ptr) {
  (void)this_;
  free(ptr);
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

static OrtStatus *fake_create_tensor(
  OrtAllocator *allocator,
  const int64_t *shape,
  size_t shape_len,
  ONNXTensorElementDataType type,
  OrtValue **out
) {
  FakeTensor *tensor;
  size_t width;
  size_t i;
  int64_t count = 1;
  (void)allocator;
  *out = NULL;
  if (shape_len == 1 && shape != NULL && shape[0] == 13) {
    return make_status(ORT_FAIL, "fake tensor create failed");
  }
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
  tensor = calloc(1, sizeof(*tensor));
  if (tensor == NULL) {
    abort();
  }
  tensor->magic = FAKE_TENSOR;
  tensor->element = (int)type;
  tensor->rank = (int)shape_len;
  tensor->nbytes = (size_t)count * width;
  if (shape_len > 0) {
    tensor->dims = calloc(shape_len, sizeof(int64_t));
    if (tensor->dims == NULL) {
      abort();
    }
    memcpy(tensor->dims, shape, shape_len * sizeof(int64_t));
  }
  if (tensor->nbytes > 0) {
    tensor->data = calloc(1, tensor->nbytes);
    if (tensor->data == NULL) {
      abort();
    }
  }
  *out = (OrtValue *)tensor;
  return NULL;
}

static void fake_release_value(OrtValue *input) {
  FakeTensor *tensor = (FakeTensor *)input;
  if (tensor == NULL || tensor->magic != FAKE_TENSOR) {
    abort();
  }
  tensor->magic = 0;
  free(tensor->dims);
  free(tensor->data);
  free(tensor);
}

static OrtStatus *fake_mutable_data(OrtValue *value, void **out) {
  FakeTensor *tensor = (FakeTensor *)value;
  if (tensor == NULL || tensor->magic != FAKE_TENSOR) {
    abort();
  }
  *out = tensor->data;
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

static const OrtApi *fake_get_api(uint32_t version) {
  static OrtApi api;
  static int ready = 0;
  if (version > ORT_API_VERSION) {
    return NULL;
  }
  if (!ready) {
    memset(&api, 0, sizeof(api));
    api.CreateEnv = fake_create_env;
    api.ReleaseEnv = fake_release_env;
    api.GetAllocatorWithDefaultOptions = fake_get_allocator;
    api.CreateTensorAsOrtValue = fake_create_tensor;
    api.GetTensorMutableData = fake_mutable_data;
    api.ReleaseValue = fake_release_value;
    api.GetTensorTypeAndShape = fake_type_and_shape;
    api.ReleaseTensorTypeAndShapeInfo = fake_release_info;
    api.GetTensorElementType = fake_element;
    api.GetDimensionsCount = fake_rank;
    api.GetDimensions = fake_dims;
    api.GetErrorCode = fake_error_code;
    api.GetErrorMessage = fake_error_message;
    api.ReleaseStatus = fake_release_status;
    ready = 1;
  }
  return &api;
}

static const char *fake_version_string(void) {
  return "fake-tensor-1.30.0";
}

static const OrtApiBase k_base = {fake_get_api, fake_version_string};

const OrtApiBase *ORT_API_CALL OrtGetApiBase(void) {
  return &k_base;
}

__attribute__((destructor)) static void moon_ort_fake_tensor_check(void) {
  if (status_live != 0 || info_live != 0) {
    abort();
  }
}
