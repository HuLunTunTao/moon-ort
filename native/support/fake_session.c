#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "onnxruntime_c_api.h"

typedef struct FakeOptions {
  int magic;
  int intra;
  int inter;
  int opt;
  int mode;
} FakeOptions;

typedef struct FakeSession {
  int magic;
} FakeSession;

typedef struct FakeStatus {
  int magic;
  int code;
  char message[160];
} FakeStatus;

typedef struct FakeTypeInfo {
  int magic;
  int element;
  int rank;
  int64_t dims[4];
  const char *symbols[4];
} FakeTypeInfo;

typedef struct FakeMetadata {
  int magic;
} FakeMetadata;

enum {
  FAKE_OPTIONS = 0x4F505453,
  FAKE_SESSION = 0x53455353,
  FAKE_STATUS = 0x53544154,
  FAKE_TYPE = 0x54595045,
  FAKE_META = 0x4D455441
};

static int env_creates = 0;
static int env_releases = 0;
static int status_live = 0;
static int alloc_live = 0;
static int type_live = 0;
static int meta_live = 0;
static OrtEnv *const k_env = (OrtEnv *)(uintptr_t)0x21;
static const char *k_empty = "";
static const char *k_batch = "batch";

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

static OrtAllocator *fake_default_allocator(void) {
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
  *out = fake_default_allocator();
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
  created->intra = 0;
  created->inter = 0;
  created->opt = ORT_ENABLE_ALL;
  created->mode = ORT_SEQUENTIAL;
  *options = (OrtSessionOptions *)created;
  return NULL;
}

static void fake_release_options(OrtSessionOptions *input) {
  FakeOptions *options = (FakeOptions *)input;
  if (options == NULL || options->magic != FAKE_OPTIONS) {
    abort();
  }
  options->magic = 0;
  free(options);
}

static FakeOptions *as_options(OrtSessionOptions *options) {
  FakeOptions *parsed = (FakeOptions *)options;
  if (parsed == NULL || parsed->magic != FAKE_OPTIONS) {
    abort();
  }
  return parsed;
}

static OrtStatus *fake_set_intra(OrtSessionOptions *options, int intra_op_num_threads) {
  as_options(options)->intra = intra_op_num_threads;
  return NULL;
}

static OrtStatus *fake_set_inter(OrtSessionOptions *options, int inter_op_num_threads) {
  as_options(options)->inter = inter_op_num_threads;
  return NULL;
}

static OrtStatus *fake_set_opt(OrtSessionOptions *options, GraphOptimizationLevel level) {
  as_options(options)->opt = (int)level;
  return NULL;
}

static OrtStatus *fake_set_mode(OrtSessionOptions *options, ExecutionMode mode) {
  as_options(options)->mode = (int)mode;
  return NULL;
}

static OrtStatus *fake_get_mode(const OrtSessionOptions *options, ExecutionMode *out) {
  *out = (ExecutionMode)as_options((OrtSessionOptions *)options)->mode;
  return NULL;
}

static OrtStatus *fake_create_session(
  const OrtEnv *env,
  const char *model_path,
  const OrtSessionOptions *options,
  OrtSession **out
) {
  FakeOptions *parsed = as_options((OrtSessionOptions *)options);
  FakeSession *session;
  char message[160];
  (void)env;
  *out = NULL;
  if (model_path != NULL && strcmp(model_path, "options-probe.onnx") == 0) {
    snprintf(
      message,
      sizeof(message),
      "intra=%d;inter=%d;opt=%d;mode=%d",
      parsed->intra,
      parsed->inter,
      parsed->opt,
      parsed->mode
    );
    return make_status(ORT_FAIL, message);
  }
  if (model_path == NULL || strcmp(model_path, "ok.onnx") != 0) {
    return make_status(ORT_NO_SUCHFILE, "model file not found");
  }
  session = calloc(1, sizeof(*session));
  if (session == NULL) {
    abort();
  }
  session->magic = FAKE_SESSION;
  *out = (OrtSession *)session;
  return NULL;
}

static void fake_release_session(OrtSession *input) {
  FakeSession *session = (FakeSession *)input;
  if (session == NULL || session->magic != FAKE_SESSION) {
    abort();
  }
  session->magic = 0;
  free(session);
}

static OrtErrorCode fake_get_error_code(const OrtStatus *status) {
  const FakeStatus *parsed = (const FakeStatus *)status;
  if (parsed == NULL || parsed->magic != FAKE_STATUS) {
    abort();
  }
  return (OrtErrorCode)parsed->code;
}

static const char *fake_get_error_message(const OrtStatus *status) {
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
  *out = 2;
  return NULL;
}

static OrtStatus *fake_output_count(const OrtSession *session, size_t *out) {
  (void)session;
  *out = 1;
  return NULL;
}

static OrtStatus *fake_input_name(const OrtSession *session, size_t index, OrtAllocator *allocator, char **value) {
  const char *name = index == 0 ? "features" : "batch_id";
  (void)session;
  if (index > 1) {
    return make_status(ORT_INVALID_ARGUMENT, "input index");
  }
  *value = alloc_dup(allocator, name);
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
  *value = alloc_dup(allocator, "scores");
  if (*value == NULL) {
    return make_status(ORT_FAIL, "out of memory");
  }
  return NULL;
}

static FakeTypeInfo *make_type(int element, int rank, const int64_t *dims, const char **symbols) {
  FakeTypeInfo *info = calloc(1, sizeof(*info));
  int i;
  if (info == NULL) {
    abort();
  }
  info->magic = FAKE_TYPE;
  info->element = element;
  info->rank = rank;
  for (i = 0; i < rank; i++) {
    info->dims[i] = dims[i];
    info->symbols[i] = symbols[i];
  }
  type_live++;
  return info;
}

static OrtStatus *fake_input_type(const OrtSession *session, size_t index, OrtTypeInfo **type_info) {
  static const int64_t dims0[2] = {2, 3};
  static const int64_t dims1[1] = {-1};
  const char *symbols0[2];
  const char *symbols1[1];
  (void)session;
  symbols0[0] = k_empty;
  symbols0[1] = k_empty;
  symbols1[0] = k_batch;
  if (index == 0) {
    *type_info = (OrtTypeInfo *)make_type(ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, 2, dims0, symbols0);
    return NULL;
  }
  if (index == 1) {
    *type_info = (OrtTypeInfo *)make_type(ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, 1, dims1, symbols1);
    return NULL;
  }
  return make_status(ORT_INVALID_ARGUMENT, "input index");
}

static OrtStatus *fake_output_type(const OrtSession *session, size_t index, OrtTypeInfo **type_info) {
  static const int64_t dims[1] = {2};
  const char *symbols[1];
  (void)session;
  symbols[0] = k_empty;
  if (index != 0) {
    return make_status(ORT_INVALID_ARGUMENT, "output index");
  }
  *type_info = (OrtTypeInfo *)make_type(ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL, 1, dims, symbols);
  return NULL;
}

static OrtStatus *fake_cast_tensor(const OrtTypeInfo *type_info, const OrtTensorTypeAndShapeInfo **out) {
  const FakeTypeInfo *info = (const FakeTypeInfo *)type_info;
  if (info == NULL || info->magic != FAKE_TYPE) {
    abort();
  }
  *out = (const OrtTensorTypeAndShapeInfo *)info;
  return NULL;
}

static void fake_release_type(OrtTypeInfo *input) {
  FakeTypeInfo *info = (FakeTypeInfo *)input;
  if (info == NULL || info->magic != FAKE_TYPE) {
    abort();
  }
  info->magic = 0;
  type_live--;
  if (type_live < 0) {
    abort();
  }
  free(info);
}

static OrtStatus *fake_element_type(const OrtTensorTypeAndShapeInfo *info, enum ONNXTensorElementDataType *out) {
  const FakeTypeInfo *parsed = (const FakeTypeInfo *)info;
  if (parsed == NULL || parsed->magic != FAKE_TYPE) {
    abort();
  }
  *out = (enum ONNXTensorElementDataType)parsed->element;
  return NULL;
}

static OrtStatus *fake_rank(const OrtTensorTypeAndShapeInfo *info, size_t *out) {
  const FakeTypeInfo *parsed = (const FakeTypeInfo *)info;
  if (parsed == NULL || parsed->magic != FAKE_TYPE) {
    abort();
  }
  *out = (size_t)parsed->rank;
  return NULL;
}

static OrtStatus *fake_dims(const OrtTensorTypeAndShapeInfo *info, int64_t *dim_values, size_t dim_values_length) {
  const FakeTypeInfo *parsed = (const FakeTypeInfo *)info;
  size_t i;
  if (parsed == NULL || parsed->magic != FAKE_TYPE) {
    abort();
  }
  if (dim_values_length != (size_t)parsed->rank) {
    return make_status(ORT_INVALID_ARGUMENT, "rank mismatch");
  }
  for (i = 0; i < dim_values_length; i++) {
    dim_values[i] = parsed->dims[i];
  }
  return NULL;
}

static OrtStatus *fake_symbols(
  const OrtTensorTypeAndShapeInfo *info,
  const char *dim_params[],
  size_t dim_params_length
) {
  const FakeTypeInfo *parsed = (const FakeTypeInfo *)info;
  size_t i;
  if (parsed == NULL || parsed->magic != FAKE_TYPE) {
    abort();
  }
  if (dim_params_length != (size_t)parsed->rank) {
    return make_status(ORT_INVALID_ARGUMENT, "rank mismatch");
  }
  for (i = 0; i < dim_params_length; i++) {
    dim_params[i] = parsed->symbols[i];
  }
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

static int metadata_ok(const OrtModelMetadata *metadata) {
  const FakeMetadata *parsed = (const FakeMetadata *)metadata;
  if (parsed == NULL || parsed->magic != FAKE_META) {
    abort();
  }
  return 1;
}

static OrtStatus *fake_producer(const OrtModelMetadata *metadata, OrtAllocator *allocator, char **value) {
  metadata_ok(metadata);
  *value = alloc_dup(allocator, "moon-ort-fake");
  return *value == NULL ? make_status(ORT_FAIL, "out of memory") : NULL;
}

static OrtStatus *fake_graph(const OrtModelMetadata *metadata, OrtAllocator *allocator, char **value) {
  metadata_ok(metadata);
  *value = alloc_dup(allocator, "fake-graph");
  return *value == NULL ? make_status(ORT_FAIL, "out of memory") : NULL;
}

static OrtStatus *fake_domain(const OrtModelMetadata *metadata, OrtAllocator *allocator, char **value) {
  metadata_ok(metadata);
  *value = alloc_dup(allocator, "ai.moonort");
  return *value == NULL ? make_status(ORT_FAIL, "out of memory") : NULL;
}

static OrtStatus *fake_description(const OrtModelMetadata *metadata, OrtAllocator *allocator, char **value) {
  metadata_ok(metadata);
  *value = alloc_dup(allocator, "fake session");
  return *value == NULL ? make_status(ORT_FAIL, "out of memory") : NULL;
}

static OrtStatus *fake_meta_version(const OrtModelMetadata *metadata, int64_t *value) {
  metadata_ok(metadata);
  *value = 7;
  return NULL;
}

static OrtStatus *fake_keys(const OrtModelMetadata *metadata, OrtAllocator *allocator, char ***keys, int64_t *num_keys) {
  char **table;
  metadata_ok(metadata);
  table = allocator->Alloc(allocator, sizeof(char *));
  if (table == NULL) {
    return make_status(ORT_FAIL, "out of memory");
  }
  table[0] = alloc_dup(allocator, "purpose");
  if (table[0] == NULL) {
    fake_free(allocator, table);
    return make_status(ORT_FAIL, "out of memory");
  }
  *keys = table;
  *num_keys = 1;
  return NULL;
}

static OrtStatus *fake_lookup(
  const OrtModelMetadata *metadata,
  OrtAllocator *allocator,
  const char *key,
  char **value
) {
  metadata_ok(metadata);
  if (key != NULL && strcmp(key, "purpose") == 0) {
    *value = alloc_dup(allocator, "test");
    return *value == NULL ? make_status(ORT_FAIL, "out of memory") : NULL;
  }
  *value = NULL;
  return NULL;
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
    api.CreateSessionOptions = fake_create_options;
    api.ReleaseSessionOptions = fake_release_options;
    api.SetIntraOpNumThreads = fake_set_intra;
    api.SetInterOpNumThreads = fake_set_inter;
    api.SetSessionGraphOptimizationLevel = fake_set_opt;
    api.SetSessionExecutionMode = fake_set_mode;
    api.GetSessionExecutionMode = fake_get_mode;
    api.CreateSession = fake_create_session;
    api.ReleaseSession = fake_release_session;
    api.GetErrorCode = fake_get_error_code;
    api.GetErrorMessage = fake_get_error_message;
    api.ReleaseStatus = fake_release_status;
    api.SessionGetInputCount = fake_input_count;
    api.SessionGetOutputCount = fake_output_count;
    api.SessionGetInputName = fake_input_name;
    api.SessionGetOutputName = fake_output_name;
    api.SessionGetInputTypeInfo = fake_input_type;
    api.SessionGetOutputTypeInfo = fake_output_type;
    api.CastTypeInfoToTensorInfo = fake_cast_tensor;
    api.ReleaseTypeInfo = fake_release_type;
    api.GetTensorElementType = fake_element_type;
    api.GetDimensionsCount = fake_rank;
    api.GetDimensions = fake_dims;
    api.GetSymbolicDimensions = fake_symbols;
    api.SessionGetModelMetadata = fake_metadata;
    api.ReleaseModelMetadata = fake_release_metadata;
    api.ModelMetadataGetProducerName = fake_producer;
    api.ModelMetadataGetGraphName = fake_graph;
    api.ModelMetadataGetDomain = fake_domain;
    api.ModelMetadataGetDescription = fake_description;
    api.ModelMetadataGetVersion = fake_meta_version;
    api.ModelMetadataGetCustomMetadataMapKeys = fake_keys;
    api.ModelMetadataLookupCustomMetadataMap = fake_lookup;
    api.GetAllocatorWithDefaultOptions = fake_get_allocator;
    api.AllocatorFree = fake_allocator_free;
    ready = 1;
  }
  return &api;
}

static const char *fake_version_string(void) {
  return "fake-session-1.30.0";
}

static const OrtApiBase k_base = {fake_get_api, fake_version_string};

const OrtApiBase *ORT_API_CALL OrtGetApiBase(void) {
  return &k_base;
}

__attribute__((destructor)) static void moon_ort_fake_session_check(void) {
  if (status_live != 0 || alloc_live != 0 || type_live != 0 || meta_live != 0) {
    abort();
  }
}
