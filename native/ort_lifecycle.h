#pragma once

#include <dlfcn.h>
#include <stdio.h>

#include "ort_shared.h"

static inline void moon_ort_release_open_env(EnvPayload *payload) {
  if (payload->state == MOON_ORT_STATE_OPEN && payload->env != NULL && payload->api != NULL &&
      payload->api->ReleaseEnv != NULL) {
    payload->api->ReleaseEnv(payload->env);
    payload->env = NULL;
  }
  payload->state = MOON_ORT_STATE_CLOSED;
  payload->api = NULL;
  if (payload->lib != NULL) {
    dlclose(payload->lib);
    payload->lib = NULL;
  }
}

static inline void moon_ort_finalize_env_payload(EnvPayload *payload) {
  if (atomic_load_explicit(&payload->children, memory_order_relaxed) > 0) {
    fputs("moon-ort: leaking runtime with open handles during finalization\n", stderr);
    return;
  }
  moon_ort_release_open_env(payload);
}
