#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ort_shared.h"

typedef const OrtApiBase *(*OrtGetApiBaseFn)(void);

void copy_cstr(char *dst, size_t cap, const char *src) {
  size_t i = 0;
  if (src == NULL) {
    src = "";
  }
  if (cap == 0) {
    return;
  }
  while (i + 1 < cap && src[i] != '\0') {
    dst[i] = src[i];
    i++;
  }
  dst[i] = '\0';
}

int32_t utf16_to_utf8(const uint16_t *src, int32_t n, char *dst, size_t cap) {
  size_t w = 0;
  int32_t i;
  if (cap == 0) {
    return -1;
  }
  for (i = 0; i < n; i++) {
    uint32_t cp = src[i];
    if (cp >= 0xD800 && cp <= 0xDBFF && i + 1 < n) {
      uint32_t lo = src[i + 1];
      if (lo >= 0xDC00 && lo <= 0xDFFF) {
        cp = 0x10000u + (((cp - 0xD800u) << 10) | (lo - 0xDC00u));
        i++;
      }
    }
    if (cp < 0x80u) {
      if (w + 1 >= cap) {
        return -1;
      }
      dst[w++] = (char)cp;
    } else if (cp < 0x800u) {
      if (w + 2 >= cap) {
        return -1;
      }
      dst[w++] = (char)(0xC0u | (cp >> 6));
      dst[w++] = (char)(0x80u | (cp & 0x3Fu));
    } else if (cp < 0x10000u) {
      if (w + 3 >= cap) {
        return -1;
      }
      dst[w++] = (char)(0xE0u | (cp >> 12));
      dst[w++] = (char)(0x80u | ((cp >> 6) & 0x3Fu));
      dst[w++] = (char)(0x80u | (cp & 0x3Fu));
    } else {
      if (w + 4 >= cap) {
        return -1;
      }
      dst[w++] = (char)(0xF0u | (cp >> 18));
      dst[w++] = (char)(0x80u | ((cp >> 12) & 0x3Fu));
      dst[w++] = (char)(0x80u | ((cp >> 6) & 0x3Fu));
      dst[w++] = (char)(0x80u | (cp & 0x3Fu));
    }
  }
  if (w >= cap) {
    return -1;
  }
  dst[w] = '\0';
  return (int32_t)w;
}

moonbit_string_t utf8_to_moonbit(const char *src) {
  const unsigned char *bytes;
  int32_t units = 0;
  int32_t out_i = 0;
  moonbit_string_t out;
  size_t i = 0;
  if (src == NULL) {
    src = "";
  }
  bytes = (const unsigned char *)src;
  while (bytes[i] != 0) {
    unsigned char b = bytes[i];
    if (b < 0x80u) {
      units++;
      i += 1;
    } else if ((b & 0xE0u) == 0xC0u && bytes[i + 1] != 0) {
      units++;
      i += 2;
    } else if ((b & 0xF0u) == 0xE0u && bytes[i + 1] != 0 && bytes[i + 2] != 0) {
      units++;
      i += 3;
    } else if ((b & 0xF8u) == 0xF0u && bytes[i + 1] != 0 && bytes[i + 2] != 0 && bytes[i + 3] != 0) {
      units += 2;
      i += 4;
    } else {
      units++;
      i += 1;
    }
  }
  out = moonbit_make_string_raw(units);
  i = 0;
  while (bytes[i] != 0) {
    unsigned char b = bytes[i];
    uint32_t cp;
    if (b < 0x80u) {
      cp = b;
      i += 1;
    } else if ((b & 0xE0u) == 0xC0u && bytes[i + 1] != 0) {
      cp = ((uint32_t)(b & 0x1Fu) << 6) | (uint32_t)(bytes[i + 1] & 0x3Fu);
      i += 2;
    } else if ((b & 0xF0u) == 0xE0u && bytes[i + 1] != 0 && bytes[i + 2] != 0) {
      cp = ((uint32_t)(b & 0x0Fu) << 12) | ((uint32_t)(bytes[i + 1] & 0x3Fu) << 6) |
        (uint32_t)(bytes[i + 2] & 0x3Fu);
      i += 3;
    } else if ((b & 0xF8u) == 0xF0u && bytes[i + 1] != 0 && bytes[i + 2] != 0 && bytes[i + 3] != 0) {
      cp = ((uint32_t)(b & 0x07u) << 18) | ((uint32_t)(bytes[i + 1] & 0x3Fu) << 12) |
        ((uint32_t)(bytes[i + 2] & 0x3Fu) << 6) | (uint32_t)(bytes[i + 3] & 0x3Fu);
      i += 4;
    } else {
      cp = b;
      i += 1;
    }
    if (cp < 0x10000u) {
      out[out_i++] = (uint16_t)cp;
    } else {
      uint32_t adj = cp - 0x10000u;
      out[out_i++] = (uint16_t)(0xD800u + (adj >> 10));
      out[out_i++] = (uint16_t)(0xDC00u + (adj & 0x3FFu));
    }
  }
  return out;
}

static void release_open_env(EnvPayload *payload) {
  if (payload->state == MOON_ORT_STATE_OPEN && payload->env != NULL && payload->api != NULL &&
      payload->api->ReleaseEnv != NULL) {
    payload->api->ReleaseEnv(payload->env);
    payload->env = NULL;
  }
  payload->state = MOON_ORT_STATE_CLOSED;
  if (payload->lib != NULL) {
    dlclose(payload->lib);
    payload->lib = NULL;
  }
}

static void env_finalize(void *self) {
  EnvPayload *payload = (EnvPayload *)self;
  if (atomic_load_explicit(&payload->children, memory_order_relaxed) > 0) {
    fputs("moon-ort: leaking runtime with open handles during finalization\n", stderr);
    return;
  }
  release_open_env(payload);
}

void moon_ort_pin_env(EnvPayload *env) {
  atomic_fetch_add_explicit(&env->children, 1, memory_order_relaxed);
  moonbit_incref(env);
}

void moon_ort_unpin_env(EnvPayload *env) {
  int_least32_t children = atomic_load_explicit(&env->children, memory_order_relaxed);
  while (children > 0 &&
         !atomic_compare_exchange_weak_explicit(
           &env->children,
           &children,
           children - 1,
           memory_order_relaxed,
           memory_order_relaxed
         )) {
  }
  moonbit_decref(env);
}

void moon_ort_write_status(
  int32_t *code,
  int32_t *status_code,
  char *message,
  size_t message_cap,
  char *api_name,
  size_t api_name_cap,
  const OrtApi *api,
  OrtStatus *status,
  const char *api_called
) {
  const char *text = NULL;
  *code = MOON_ORT_STATUS;
  if (status_code != NULL) {
    *status_code = -1;
  }
  copy_cstr(api_name, api_name_cap, api_called);
  if (api != NULL && status != NULL && api->GetErrorCode != NULL && status_code != NULL) {
    *status_code = (int32_t)api->GetErrorCode(status);
  }
  if (api != NULL && status != NULL && api->GetErrorMessage != NULL) {
    text = api->GetErrorMessage(status);
  }
  copy_cstr(message, message_cap, text != NULL ? text : "OrtStatus");
  if (api != NULL && status != NULL && api->ReleaseStatus != NULL) {
    api->ReleaseStatus(status);
  }
}

static EnvPayload *new_payload(void) {
  EnvPayload *payload = moonbit_make_external_object(env_finalize, (uint32_t)sizeof(EnvPayload));
  memset(payload, 0, sizeof(*payload));
  atomic_init(&payload->children, 0);
  payload->code = MOON_ORT_OK;
  payload->state = MOON_ORT_STATE_FAILED;
  payload->expected_api = ORT_API_VERSION;
  payload->actual_api = -1;
  payload->status_code = -1;
  payload->api_version = ORT_API_VERSION;
  return payload;
}

static void close_lib(void *lib) {
  if (lib != NULL) {
    dlclose(lib);
  }
}

static int32_t probe_actual_api(const OrtApiBase *base) {
  int32_t actual = -1;
  uint32_t version;
  if (base == NULL || base->GetApi == NULL) {
    return -1;
  }
  for (version = 1; version <= 64; version++) {
    if (base->GetApi(version) != NULL) {
      actual = (int32_t)version;
    }
  }
  return actual;
}

static void fill_status(EnvPayload *payload, const OrtApi *api, OrtStatus *status, const char *api_name) {
  payload->state = MOON_ORT_STATE_FAILED;
  moon_ort_write_status(
    &payload->code,
    &payload->status_code,
    payload->message,
    sizeof(payload->message),
    payload->api_name,
    sizeof(payload->api_name),
    api,
    status,
    api_name
  );
}

EnvPayload *moon_ort_load(moonbit_string_t path) {
  EnvPayload *payload = new_payload();
  char cpath[1024];
  void *lib = NULL;
  OrtGetApiBaseFn get_base = NULL;
  const OrtApiBase *base = NULL;
  const OrtApi *api = NULL;
  OrtEnv *env = NULL;
  OrtStatus *status = NULL;
  const char *version = NULL;
  int32_t path_len;
  if (path == NULL || Moonbit_array_length(path) == 0) {
    payload->code = MOON_ORT_INVALID_ARGUMENT;
    copy_cstr(payload->message, sizeof(payload->message), "runtime path is empty");
    return payload;
  }
  path_len = Moonbit_array_length(path);
  if (utf16_to_utf8(path, path_len, cpath, sizeof(cpath)) < 0) {
    payload->code = MOON_ORT_INVALID_ARGUMENT;
    copy_cstr(payload->message, sizeof(payload->message), "runtime path is too long");
    return payload;
  }
  copy_cstr(payload->path, sizeof(payload->path), cpath);
  dlerror();
  lib = dlopen(cpath, RTLD_NOW | RTLD_LOCAL);
  if (lib == NULL) {
    const char *err = dlerror();
    payload->code = MOON_ORT_MISSING_LIBRARY;
    copy_cstr(payload->message, sizeof(payload->message), err != NULL ? err : "dlopen failed");
    return payload;
  }
  dlerror();
  *(void **)(&get_base) = dlsym(lib, "OrtGetApiBase");
  if (get_base == NULL) {
    const char *err = dlerror();
    payload->code = MOON_ORT_SYMBOL_NOT_FOUND;
    copy_cstr(payload->message, sizeof(payload->message), err != NULL ? err : "OrtGetApiBase not found");
    close_lib(lib);
    return payload;
  }
  base = get_base();
  if (base == NULL || base->GetApi == NULL) {
    payload->code = MOON_ORT_API_MISMATCH;
    payload->actual_api = -1;
    copy_cstr(payload->message, sizeof(payload->message), "OrtGetApiBase returned NULL");
    close_lib(lib);
    return payload;
  }
  if (base->GetVersionString != NULL) {
    version = base->GetVersionString();
  }
  copy_cstr(payload->version, sizeof(payload->version), version != NULL ? version : "");
  payload->actual_api = probe_actual_api(base);
  api = base->GetApi(ORT_API_VERSION);
  if (api == NULL || api->CreateEnv == NULL) {
    payload->code = MOON_ORT_API_MISMATCH;
    snprintf(
      payload->message,
      sizeof(payload->message),
      "GetApi(%d) returned NULL; library API version %d; ort_version=%s",
      ORT_API_VERSION,
      payload->actual_api,
      payload->version
    );
    close_lib(lib);
    return payload;
  }
  status = api->CreateEnv(ORT_LOGGING_LEVEL_WARNING, "moon-ort", &env);
  if (status != NULL) {
    if (env != NULL && api->ReleaseEnv != NULL) {
      api->ReleaseEnv(env);
      env = NULL;
    }
    fill_status(payload, api, status, "CreateEnv");
    close_lib(lib);
    return payload;
  }
  if (env == NULL) {
    payload->code = MOON_ORT_STATUS;
    payload->status_code = (int32_t)ORT_FAIL;
    copy_cstr(payload->api_name, sizeof(payload->api_name), "CreateEnv");
    copy_cstr(payload->message, sizeof(payload->message), "CreateEnv returned NULL environment");
    close_lib(lib);
    return payload;
  }
  payload->lib = lib;
  payload->api = api;
  payload->env = env;
  payload->api_version = ORT_API_VERSION;
  payload->state = MOON_ORT_STATE_OPEN;
  payload->code = MOON_ORT_OK;
  copy_cstr(payload->api_name, sizeof(payload->api_name), "CreateEnv");
  return payload;
}

int32_t moon_ort_code(EnvPayload *payload) {
  if (payload == NULL) {
    return MOON_ORT_INVALID_ARGUMENT;
  }
  return payload->code;
}

int32_t moon_ort_state(EnvPayload *payload) {
  if (payload == NULL) {
    return MOON_ORT_STATE_FAILED;
  }
  return payload->state;
}

int32_t moon_ort_expected_api(EnvPayload *payload) {
  if (payload == NULL) {
    return ORT_API_VERSION;
  }
  return payload->expected_api;
}

int32_t moon_ort_actual_api(EnvPayload *payload) {
  if (payload == NULL) {
    return -1;
  }
  return payload->actual_api;
}

int32_t moon_ort_status_code(EnvPayload *payload) {
  if (payload == NULL) {
    return -1;
  }
  return payload->status_code;
}

int32_t moon_ort_api_version(EnvPayload *payload) {
  if (payload == NULL) {
    return -1;
  }
  return payload->api_version;
}

int32_t moon_ort_header_api_version(void) {
  return ORT_API_VERSION;
}

moonbit_string_t moon_ort_message(EnvPayload *payload) {
  if (payload == NULL) {
    return utf8_to_moonbit("");
  }
  return utf8_to_moonbit(payload->message);
}

moonbit_string_t moon_ort_path(EnvPayload *payload) {
  if (payload == NULL) {
    return utf8_to_moonbit("");
  }
  return utf8_to_moonbit(payload->path);
}

moonbit_string_t moon_ort_api_name(EnvPayload *payload) {
  if (payload == NULL) {
    return utf8_to_moonbit("");
  }
  return utf8_to_moonbit(payload->api_name);
}

moonbit_string_t moon_ort_version(EnvPayload *payload) {
  if (payload == NULL) {
    return utf8_to_moonbit("");
  }
  return utf8_to_moonbit(payload->version);
}

int32_t moon_ort_close(EnvPayload *payload) {
  if (payload == NULL || payload->state == MOON_ORT_STATE_FAILED) {
    return MOON_ORT_INVALID_ARGUMENT;
  }
  if (payload->state != MOON_ORT_STATE_OPEN || payload->env == NULL) {
    return MOON_ORT_ALREADY_CLOSED;
  }
  if (atomic_load_explicit(&payload->children, memory_order_relaxed) > 0) {
    copy_cstr(payload->message, sizeof(payload->message), "runtime has open handles");
    return MOON_ORT_BUSY;
  }
  release_open_env(payload);
  return MOON_ORT_OK;
}
