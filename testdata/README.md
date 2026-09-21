# 微型 ONNX 测试夹具

这些文件由本目录的 `generate_models.py` 自行生成，不含任何第三方模型权重或数据。
它们仅用于 `moon-ort` 的自动化测试，许可证与本项目一致，为 MIT。

生成环境固定为 `onnx==1.17.0`，ONNX opset 为 13，IR version 为 9。

| 文件 | 覆盖能力 |
|---|---|
| `add_f32.onnx` | 单输入单输出 `f32` 张量 |
| `two_inputs_i64.onnx` | 两个 `i64` 输入 |
| `two_outputs_f32_bool.onnx` | `f32` 与 `bool` 两个输出 |
| `dynamic_identity_f32.onnx` | 动态 batch shape |

从项目根目录使用一个干净的临时环境重新生成并核验：

```sh
fixture_venv="$(mktemp -d)/moon-ort-fixtures"
mlpython3119 -m venv "$fixture_venv"
"$fixture_venv/bin/python" -m pip install -r testdata/requirements.txt
"$fixture_venv/bin/python" testdata/generate_models.py
(cd testdata && shasum -a 256 -c SHA256SUMS)
```

`SHA256SUMS` 中的哈希是受版本控制的完整性基线。修改生成器、ONNX 版本或模型格式后，必须
重新生成、人工审查模型图，再更新哈希、`requirements.txt` 和本说明。临时环境不进入仓库。
