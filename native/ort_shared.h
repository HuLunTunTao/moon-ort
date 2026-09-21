#pragma once

#include <stddef.h>
#include <stdint.h>

#include "moonbit.h"
#include "vendor/onnxruntime/v1.30.0/onnxruntime_c_api.h"

enum {
  MOON_ORT_OK = 0,
  MOON_ORT_MISSING_LIBRARY = 1,
  MOON_ORT_SYMBOL_NOT_FOUND = 2,
  MOON_ORT_API_MISMATCH = 3,
  MOON_ORT_STATUS = 4,
  MOON_ORT_ALREADY_CLOSED = 5,
  MOON_ORT_USE_AFTER_CLOSE = 6,
  MOON_ORT_INVALID_ARGUMENT = 7,
  MOON_ORT_BUSY = 8
};

enum {
  MOON_ORT_STATE_OPEN = 0,
  MOON_ORT_STATE_CLOSED = 1,
  MOON_ORT_STATE_FAILED = 2
};

typedef struct EnvPayload {
  int32_t code;
  int32_t state;
  int32_t expected_api;
  int32_t actual_api;
  int32_t status_code;
  int32_t api_version;
  int32_t children;
  void *lib;
  const OrtApi *api;
  OrtEnv *env;
  char version[160];
  char message[768];
  char path[1024];
  char api_name[64];
} EnvPayload;

void copy_cstr(char *dst, size_t cap, const char *src);
int32_t utf16_to_utf8(const uint16_t *src, int32_t n, char *dst, size_t cap);
moonbit_string_t utf8_to_moonbit(const char *src);
void moon_ort_pin_env(EnvPayload *env);
void moon_ort_unpin_env(EnvPayload *env);
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
);

typedef struct ValuePayload ValuePayload;

int32_t moon_ort_value_code(ValuePayload *payload);
int moon_ort_value_export_input(ValuePayload *payload, EnvPayload **env_out, OrtValue **value_out);
ValuePayload *moon_ort_value_adopt(EnvPayload *env, OrtValue *value);
void moon_ort_value_read_error(
  const ValuePayload *payload,
  int32_t *code,
  int32_t *status_code,
  char *message,
  size_t message_cap,
  char *api_name,
  size_t api_name_cap
);
