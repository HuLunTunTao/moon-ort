#include "../ort_shared.h"

#include <ctype.h>
#include <spawn.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>

extern char **environ;

static int fake_name_is_safe(const char *name) {
  const unsigned char *cursor = (const unsigned char *)name;
  if (*cursor == '\0') {
    return 0;
  }
  while (*cursor != '\0') {
    if (!isalnum(*cursor) && *cursor != '_') {
      return 0;
    }
    cursor++;
  }
  return 1;
}

static int output_path_is_safe(const char *path) {
  return strncmp(path, "/tmp/moon-ort-", 14) == 0 && strstr(path, "..") == NULL;
}

static int32_t run_test_script(const char *script) {
  char *argv[3];
  pid_t pid;
  int spawn_code;
  int status;

  argv[0] = "sh";
  argv[1] = (char *)script;
  argv[2] = NULL;
  spawn_code = posix_spawnp(&pid, "sh", NULL, NULL, argv, environ);
  if (spawn_code != 0) {
    return -1;
  }
  if (waitpid(pid, &status, 0) < 0 || !WIFEXITED(status)) {
    return -1;
  }
  return (int32_t)WEXITSTATUS(status);
}

int32_t moon_ort_test_compile_fake(
  moonbit_string_t name,
  moonbit_string_t output
) {
  char fake_name[128];
  char output_path[1024];
  char source_path[256];
  char *argv[5];
  pid_t pid;
  int spawn_code;
  int status;

  if (name == NULL || output == NULL) {
    return -1;
  }
  if (utf16_to_utf8(name, Moonbit_array_length(name), fake_name, sizeof(fake_name)) < 0 ||
      utf16_to_utf8(output, Moonbit_array_length(output), output_path, sizeof(output_path)) < 0 ||
      !fake_name_is_safe(fake_name) || !output_path_is_safe(output_path)) {
    return -1;
  }
  if (snprintf(source_path, sizeof(source_path), "native/support/%s.c", fake_name) >=
      (int)sizeof(source_path)) {
    return -1;
  }

  argv[0] = "sh";
  argv[1] = "native/support/cc_compile.sh";
  argv[2] = output_path;
  argv[3] = source_path;
  argv[4] = NULL;
  spawn_code = posix_spawnp(&pid, "sh", NULL, NULL, argv, environ);
  if (spawn_code != 0) {
    return -1;
  }
  if (waitpid(pid, &status, 0) < 0 || !WIFEXITED(status)) {
    return -1;
  }
  return (int32_t)WEXITSTATUS(status);
}

int32_t moon_ort_test_verify_cc_select(void) {
  return run_test_script("native/support/cc_select_test.sh");
}

int32_t moon_ort_test_write_file(moonbit_string_t path, moonbit_string_t contents) {
  char output_path[1024];
  char buffer[1024];
  FILE *file;
  size_t length;

  if (path == NULL || contents == NULL ||
      utf16_to_utf8(path, Moonbit_array_length(path), output_path, sizeof(output_path)) < 0 ||
      utf16_to_utf8(contents, Moonbit_array_length(contents), buffer, sizeof(buffer)) < 0 ||
      !output_path_is_safe(output_path)) {
    return -1;
  }
  file = fopen(output_path, "wb");
  if (file == NULL) {
    return -1;
  }
  length = strlen(buffer);
  if (fwrite(buffer, 1, length, file) != length) {
    fclose(file);
    return -1;
  }
  if (fclose(file) != 0) {
    return -1;
  }
  return 0;
}
