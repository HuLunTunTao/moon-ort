# 微型 ONNX 测试夹具

这些文件由本目录的 `generate_models.py` 自行生成，不含第三方模型权重或数据。测试输入由固定种子
`20260922` 从脚本里的可精确表示数值池抽出；模型图本身是字面量，不使用随机权重。夹具与仓库
根目录 `LICENSE` 一样，按 MIT 再分发。`onnx` 与 `onnxruntime` 只作为生成和对照工具，不放进
SDK 运行时，也不提交它们的安装包。

| 项目 | 固定值 |
|---|---|
| 生成器 | `onnx==1.17.0` |
| 解释器 | `mlpython3119`（CPython 3.11.9） |
| ONNX opset | 13 |
| IR version | 9 |
| 随机种子 | `20260922` |
| 参考运行时 | 官方 ONNX Runtime `1.30.0` CPU，仅由 `tools/reference/ort_diff.py` 调用 |

| 文件 | 覆盖能力 |
|---|---|
| `add_f32.onnx` | 单输入单输出 `f32` |
| `two_inputs_i64.onnx` | 两个 `i64` 输入 |
| `two_outputs_f32_bool.onnx` | `f32` 与 `bool` 两个输出 |
| `dynamic_identity_f32.onnx` | 动态 batch；清单中有 batch 1 和 batch 3 |
| `negative/invalid_model.onnx` | 固定的非 protobuf 字节，不是有效模型 |
| `cases/manifest.json` | 种子抽出的输入、解析参考输出和负例规格 |

错类型、错 shape 和缺输入不是额外的模型文件。它们在清单里对上述有效模型提交错误输入。
官方 ORT 的通过标准和逐输出容差见 `tools/reference/tolerances.json`：`f32` 为 `rtol=0`、
`atol=0`，`i64` 与 `bool` 必须精确相等。

两个 `i64` 向量若被种子抽成相同，生成器会把 `right` 沿整数池旋转一格，避免“把 left 加两次”
这种错误碰巧得到相同的和。

从项目根目录用干净临时环境重新生成并核验。生成器不会改写 `SHA256SUMS`；字节漂移会使校验失败。

```sh
fixture_venv="$(mktemp -d)/moon-ort-fixtures"
mlpython3119 -m venv "$fixture_venv"
"$fixture_venv/bin/python" -m pip install -r testdata/requirements.txt
"$fixture_venv/bin/python" testdata/generate_models.py
(cd testdata && shasum -a 256 -c SHA256SUMS)
```

仓库忽略通用 `*.onnx`，但允许 `testdata/**/*.onnx`。临时环境、缓存、权重和 ORT 二进制不进入仓库。
修改生成器、ONNX 版本或模型图之后，必须重新生成、检查图，再更新 `SHA256SUMS` 和本说明。
