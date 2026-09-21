///|
fn run_shell(label : String, command : String) -> Unit raise Failure {
  let code = host_system(command)
  if code != 0 {
    fail("\{label}: \{code}")
  }
}

///|
/// Locks the lookup without removing gcc-15 from the machine. Each probe uses a
/// private PATH, so the cc branch does not depend on gcc-15 being absent.
test "c compiler selection prefers a set CC then gcc-15 otherwise cc" {
  let root = "/tmp/moon-ort-cc-select"
  let cc_only = "\{root}-cc-only"
  let with_gcc = "\{root}-with-gcc"
  run_shell(
    "prepare probe directories",
    "rm -rf \{root} \{cc_only} \{with_gcc} && mkdir -p \{cc_only} \{with_gcc}",
  )
  run_shell(
    "plant cc",
    "ln -s /usr/bin/cc \{cc_only}/cc && ln -s /usr/bin/cc \{with_gcc}/cc",
  )
  run_shell(
    "plant gcc-15",
    "printf '%s\\n' '#!/bin/sh' 'exit 0' > \{with_gcc}/gcc-15 && chmod +x \{with_gcc}/gcc-15",
  )
  run_shell(
    "unset CC falls back to cc",
    "env -u CC PATH=\{cc_only} /bin/sh native/support/cc_select.sh > \{root}.fallback",
  )
  run_shell(
    "fallback text",
    "printf '%s\\n' cc > \{root}.fallback.expected && cmp -s \{root}.fallback \{root}.fallback.expected",
  )
  run_shell(
    "gcc-15 on PATH is preferred",
    "env -u CC PATH=\{with_gcc} /bin/sh native/support/cc_select.sh > \{root}.gcc",
  )
  run_shell(
    "gcc-15 text",
    "printf '%s\\n' gcc-15 > \{root}.gcc.expected && cmp -s \{root}.gcc \{root}.gcc.expected",
  )
  run_shell(
    "set CC wins over gcc-15",
    "CC=/usr/bin/cc PATH=\{with_gcc} /bin/sh native/support/cc_select.sh > \{root}.from-cc",
  )
  run_shell(
    "CC text",
    "printf '%s\\n' /usr/bin/cc > \{root}.from-cc.expected && cmp -s \{root}.from-cc \{root}.from-cc.expected",
  )
  run_shell(
    "empty CC stays set",
    "CC= PATH=\{with_gcc} /bin/sh native/support/cc_select.sh > \{root}.empty",
  )
  run_shell(
    "empty CC text",
    "printf '%s\\n' '' > \{root}.empty.expected && cmp -s \{root}.empty \{root}.empty.expected",
  )
  let names = [
    "fake_api_mismatch", "fake_create_fail", "fake_env", "fake_no_symbol", "fake_run",
    "fake_session", "fake_tensor",
  ]
  for name in names {
    run_shell(
      "cc builds \{name}",
      "env -u CC PATH=\{cc_only} /bin/sh native/support/cc_compile.sh \{root}-\{name}.dylib native/support/\{name}.c",
    )
  }
}
