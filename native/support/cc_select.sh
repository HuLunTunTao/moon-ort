#!/bin/sh
# Compiler for native/support fake libraries.
# A set CC is used as-is, including an empty value.
# Otherwise gcc-15 when it is on PATH, so local development keeps that preference.
# Otherwise cc. Do not hard-code a vendor compiler.
if [ -n "${CC+x}" ]; then
  printf '%s\n' "$CC"
elif command -v gcc-15 >/dev/null 2>&1; then
  printf '%s\n' gcc-15
else
  printf '%s\n' cc
fi
