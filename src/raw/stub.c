#include "../../native/ort_shim.c"
#include "../../native/ort_session.c"
#include "../../native/ort_value.c"

/* Test-only visibility into the private payload after the normal close path. */
int32_t moon_ort_test_env_handles_released(EnvPayload *payload) {
  return payload != NULL && payload->env == NULL && payload->lib == NULL && payload->api == NULL;
}
