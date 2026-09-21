#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "onnxruntime_c_api.h"

static int creates = 0;
static int releases = 0;
static OrtEnv *const k_env = (OrtEnv *)(uintptr_t)0x11;

static OrtStatus *fake_create_env(OrtLoggingLevel level, const char *logid, OrtEnv **out) {
  (void)level;
  (void)logid;
  creates++;
  *out = k_env;
  return NULL;
}

static void fake_release_env(OrtEnv *input) {
  (void)input;
  releases++;
  if (releases > creates) {
    abort();
  }
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
    ready = 1;
  }
  return &api;
}

static const char *fake_version_string(void) {
  return "fake-env-1.30.0";
}

static const OrtApiBase k_base = {fake_get_api, fake_version_string};

const OrtApiBase *ORT_API_CALL OrtGetApiBase(void) {
  return &k_base;
}
