#include "onnxruntime_c_api.h"

static const OrtApi *fake_get_api(uint32_t version) {
  (void)version;
  return NULL;
}

static const char *fake_version_string(void) {
  return "fake-mismatch";
}

static const OrtApiBase k_base = {fake_get_api, fake_version_string};

const OrtApiBase *ORT_API_CALL OrtGetApiBase(void) {
  return &k_base;
}
