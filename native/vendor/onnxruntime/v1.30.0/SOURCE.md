# ONNX Runtime v1.30.0 C API headers

These files are the official ONNX Runtime C API headers from tag `v1.30.0`.
They are compiled into the MoonBit native stub. This directory does not contain
ONNX Runtime shared libraries, archives, or other binaries. Downstream users
supply a matching shared library at runtime.

| Item | Value |
|---|---|
| Project | ONNX Runtime |
| Upstream | https://github.com/microsoft/onnxruntime |
| Tag | `v1.30.0` |
| Commit | `f2c39fe2f838cf35ce7da92824f5a5e3ee6e88a7` |
| License | MIT (`LICENSE` in this directory) |
| C API version | `ORT_API_VERSION` 30 |

`onnxruntime_c_api.h` includes `onnxruntime_error_code.h` and
`onnxruntime_ep_c_api.h` by quoted path. Those two headers are vendored beside
it so the stub can compile without an ONNX Runtime development package.

| File | Upstream path | SHA-256 |
|---|---|---|
| `onnxruntime_c_api.h` | `include/onnxruntime/core/session/onnxruntime_c_api.h` | `e035e30c27e74c8c00e0f483e576e12b4067d17f12e9237fd6eff8b346c9b381` |
| `onnxruntime_error_code.h` | `include/onnxruntime/core/session/onnxruntime_error_code.h` | `5ce3b054e798eced8d14f5b86e98692fd33470463f96194ce0700a2d53dd8721` |
| `onnxruntime_ep_c_api.h` | `include/onnxruntime/core/session/onnxruntime_ep_c_api.h` | `e6c986c9e98583f8113b2c6bc3864814883b806d501cf24da4d239c45753e235` |
| `LICENSE` | `LICENSE` | `2f07c72751aed99790b8a4869cf2311df85a860b22ded05fa22803587a48922c` |

Raw URLs:

- https://raw.githubusercontent.com/microsoft/onnxruntime/v1.30.0/include/onnxruntime/core/session/onnxruntime_c_api.h
- https://raw.githubusercontent.com/microsoft/onnxruntime/v1.30.0/include/onnxruntime/core/session/onnxruntime_error_code.h
- https://raw.githubusercontent.com/microsoft/onnxruntime/v1.30.0/include/onnxruntime/core/session/onnxruntime_ep_c_api.h
- https://raw.githubusercontent.com/microsoft/onnxruntime/v1.30.0/LICENSE

Re-check the checksums from this directory:

```sh
shasum -a 256 -c << 'EOF'
e035e30c27e74c8c00e0f483e576e12b4067d17f12e9237fd6eff8b346c9b381  onnxruntime_c_api.h
5ce3b054e798eced8d14f5b86e98692fd33470463f96194ce0700a2d53dd8721  onnxruntime_error_code.h
e6c986c9e98583f8113b2c6bc3864814883b806d501cf24da4d239c45753e235  onnxruntime_ep_c_api.h
2f07c72751aed99790b8a4869cf2311df85a860b22ded05fa22803587a48922c  LICENSE
EOF
```
