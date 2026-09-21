#!/usr/bin/env bash
# Copy one committed tree to runs/<sha>/ and run the official ORT test.
# The verifier supplies the SSH destination. This file has no host name,
# password, or key.

set -euo pipefail

export LC_ALL=C
export LANG=C

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: scripts/remote-verify.sh <ssh-destination> [commit]" >&2
  exit 2
fi

dest=$1
requested=${2:-HEAD}
remote_root=<remote-root>
libonnx="${remote_root}/.deps/onnxruntime/v1.30.0/onnxruntime-osx-arm64-1.30.0/lib/libonnxruntime.1.30.0.dylib"
moon_bin="${remote_root}/.moon/bin/moon"
moonc_bin="${remote_root}/.moon/bin/moonc"

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
sha=$(git -C "$repo_root" rev-parse --verify "${requested}^{commit}")
case "$sha" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])
    ;;
  *)
    echo "refusing commit that is not 40 hex digits: ${sha}" >&2
    exit 2
    ;;
esac

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
git -C "$repo_root" archive --format=tar "$sha" >"$tmp"
local_sum=$(shasum -a 256 "$tmp" | awk 'NR==1 { print $1 }')

extract_script=$(
  cat <<'EOF'
set -euo pipefail
export LC_ALL=C LANG=C
d="${REMOTE_ROOT}/runs/${SHA}"
t="${REMOTE_ROOT}/runs/${SHA}.tar"
rm -rf "$d"
mkdir -p "$d"
tee "$t" | tar -C "$d" -xf -
shasum -a 256 "$t"
rm -f "$t"
test ! -e "$d/.git"
EOF
)

set +e
extract_out=$(
  ssh -o BatchMode=yes "$dest" \
    "SHA=$(printf '%q' "$sha") REMOTE_ROOT=$(printf '%q' "$remote_root") bash --noprofile --norc -c $(printf '%q' "$extract_script")" <"$tmp"
)
extract_status=$?
set -e
if [ "$extract_status" -ne 0 ]; then
  printf '%s\n' "$extract_out" >&2
  exit "$extract_status"
fi
remote_sum=$(printf '%s\n' "$extract_out" | awk 'NR==1 { print $1 }')
if [ "$local_sum" != "$remote_sum" ]; then
  echo "archive checksum mismatch: local=${local_sum} remote=${remote_sum}" >&2
  exit 1
fi

test_script=$(
  cat <<'EOF'
set -euo pipefail
export LC_ALL=C LANG=C
cd "${REMOTE_ROOT}/runs/${SHA}"
/usr/bin/time -l env \
  MOON_ORT_LIBRARY="${LIBONNX}" \
  MOONC_OVERRIDE="${MOONC_BIN}" \
  "${MOON_BIN}" test --deny-warn -f 'official*' src/session/run_official_test.mbt
EOF
)

set +e
output=$(
  ssh -o BatchMode=yes "$dest" \
    "SHA=$(printf '%q' "$sha") REMOTE_ROOT=$(printf '%q' "$remote_root") LIBONNX=$(printf '%q' "$libonnx") MOONC_BIN=$(printf '%q' "$moonc_bin") MOON_BIN=$(printf '%q' "$moon_bin") bash --noprofile --norc -c $(printf '%q' "$test_script")"
)
status=$?
set -e
printf '%s\n' "$output"
if [ "$status" -ne 0 ]; then
  exit "$status"
fi

case "$output" in
  *skip:*)
    echo "official libonnxruntime 1.30.0 was skipped" >&2
    exit 1
    ;;
esac

needles=(
  "add_f32 input=[0.5, -1.5]"
  "reference=[2.0, -3.5]"
  "two_inputs_i64 input=[-5, -3]+[-3, -1]"
  "reference=[-8, -4]"
  "two_outputs_f32_bool input=[-1.5, 0.25]"
  "reference=[-0.5, 1.25]"
  "reference=[false, true]"
  "dynamic_identity_f32 batch1 input=[[1.0, -2.0]]"
  "reference=[1.0, -2.0]"
  "dynamic_identity_f32 batch3 input=[[2.0, 0.0], [-0.5, 2.0], [2.0, -1.5]]"
  "reference=[2.0, 0.0, -0.5, 2.0, 2.0, -1.5]"
)

for needle in "${needles[@]}"; do
  case "$output" in
    *"$needle"*) ;;
    *)
      echo "missing expected output: ${needle}" >&2
      exit 1
      ;;
  esac
done
