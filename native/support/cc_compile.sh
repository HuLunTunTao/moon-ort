#!/bin/sh
# Compile one native/support fake with the compiler from cc_select.sh.
# Arguments: <output> <source>. Include paths are relative to the module root.
set -eu
if [ "$#" -ne 2 ]; then
  echo "usage: cc_compile.sh <output> <source>" >&2
  exit 2
fi
output=$1
source=$2
compiler=$(/bin/sh native/support/cc_select.sh)
exec "$compiler" -Wall -Wextra -Werror -shared -fPIC \
  -I native/vendor/onnxruntime/v1.30.0 \
  -o "$output" "$source"
