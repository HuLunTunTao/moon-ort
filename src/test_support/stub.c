#include "../../native/support/test_compile.c"
#include "../../native/ort_lifecycle.h"

/* Test-only visibility into the runtime payload after a close/finalize path. */
int32_t moon_ort_test_env_handles_released(EnvPayload *payload) {
  return payload != NULL && payload->env == NULL && payload->lib == NULL && payload->api == NULL;
}

/* Invoke the shared callback body directly; tests must not depend on GC timing. */
void moon_ort_test_finalize_env(EnvPayload *payload) {
  if (payload != NULL) {
    moon_ort_finalize_env_payload(payload);
  }
}
