#!/bin/sh
# Test-only probe for cc_select.sh. It receives no external input.
set -eu

root=$(mktemp -d /tmp/moon-ort-cc-select.XXXXXX)
cc_only="${root}/cc-only"
with_gcc="${root}/with-gcc"
no_compiler="${root}/no-compiler"
cleanup() {
  rm -rf "$root"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

mkdir -p "$cc_only" "$with_gcc" "$no_compiler"
ln -s /usr/bin/cc "$cc_only/cc"
ln -s /usr/bin/cc "$with_gcc/cc"
assembler=$(command -v as)
ln -s "$assembler" "$cc_only/as"
linker=$(command -v ld)
ln -s "$linker" "$cc_only/ld"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$with_gcc/gcc-15"
chmod +x "$with_gcc/gcc-15"

env -u CC PATH="$cc_only" /bin/sh native/support/cc_select.sh > "${root}/fallback"
printf '%s\n' cc > "${root}/fallback.expected"
cmp -s "${root}/fallback" "${root}/fallback.expected"

env -u CC PATH="$with_gcc" /bin/sh native/support/cc_select.sh > "${root}/gcc"
printf '%s\n' gcc-15 > "${root}/gcc.expected"
cmp -s "${root}/gcc" "${root}/gcc.expected"

CC=/usr/bin/cc PATH="$with_gcc" /bin/sh native/support/cc_select.sh > "${root}/from-cc"
printf '%s\n' /usr/bin/cc > "${root}/from-cc.expected"
cmp -s "${root}/from-cc" "${root}/from-cc.expected"

CC= PATH="$with_gcc" /bin/sh native/support/cc_select.sh > "${root}/empty"
printf '%s\n' '' > "${root}/empty.expected"
cmp -s "${root}/empty" "${root}/empty.expected"

if env -u CC PATH="$no_compiler" /bin/sh native/support/cc_compile.sh \
  "${root}/unexpected.dylib" native/support/fake_env.c >/dev/null 2>&1; then
  echo "expected cc_compile.sh to fail when no compiler is available" >&2
  exit 1
fi

for name in fake_api_mismatch fake_create_fail fake_env fake_no_symbol fake_run fake_session fake_tensor; do
  env -u CC PATH="$cc_only" /bin/sh native/support/cc_compile.sh \
    "${root}/${name}.dylib" "native/support/${name}.c"
done
