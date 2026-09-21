#include <stdlib.h>
#include <string.h>

#include "onnxruntime_c_api.h"

static int live_status = 0;
static int released_status = 0;
static int status_token = 0;

static OrtStatus *fake_create_env(OrtLoggingLevel level, const char *logid, OrtEnv **out) {
  (void)level;
  (void)logid;
  *out = NULL;
  live_status++;
  return (OrtStatus *)&status_token;
}

static OrtErrorCode fake_get_error_code(const OrtStatus *status) {
  (void)status;
  return ORT_FAIL;
}

static const char *fake_get_error_message(const OrtStatus *status) {
  (void)status;
  return "fake create env failed";
}

static void fake_release_status(OrtStatus *status) {
  (void)status;
  released_status++;
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
    api.GetErrorCode = fake_get_error_code;
    api.GetErrorMessage = fake_get_error_message;
    api.ReleaseStatus = fake_release_status;
    ready = 1;
  }
  return &api;
}

static const char *fake_version_string(void) {
  return "fake-create-fail";
}

static const OrtApiBase k_base = {fake_get_api, fake_version_string};

const OrtApiBase *ORT_API_CALL OrtGetApiBase(void) {
  return &k_base;
}

__attribute__((destructor)) static void moon_ort_fake_check_status_released(void) {
  if (live_status != released_status) {
    abort();
  }
}
