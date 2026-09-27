# 官方 ONNX Runtime 对照

`ort_diff.py` 只服务于测试。它不进入 MoonBit SDK 的运行时依赖，也不被 `moon.mod` 引用。

对照运行时固定为官方 `onnxruntime==1.30.0` 的 CPU Execution Provider，图优化级别为
`ORT_ENABLE_ALL`，intra-op 与 inter-op 线程数均为 1。`numpy==2.4.6` 只用于张量排列和比较。

浮点容差记录在 `tolerances.json`。当前每个 `f32` 输出的 `rtol` 和 `atol` 都是 `0.0`：
这些图只做可精确表示数值上的 Identity、Add 和 Greater，非零容差会放过真实元素错误。
`i64` 与 `bool` 必须完全相同，条目里不允许出现浮点容差。工具另外拒绝高于 `1e-6` 的
浮点上限，避免以后把容差放宽到能掩盖错误的程度。

正例的参考值来自 `testdata/cases/manifest.json` 里的解析结果，再与同一次官方 ORT 运行比较。
负例覆盖无效模型、错类型、错 shape 和缺输入。缺输入在 Python 绑定里会在进入 `Run` 之前
报错；MoonBit 将来走 C API 时，错误文本可以不同，但必须表达同一分类。

从仓库根目录，用干净临时环境运行：

```sh
ref_venv="$(mktemp -d)/moon-ort-reference"
mlpython3119 -m venv "$ref_venv"
"$ref_venv/bin/python" -m pip install -r tools/reference/requirements.txt
"$ref_venv/bin/python" tools/reference/ort_diff.py verify
```

`compare` 接收一份覆盖全部正例的 JSON 转储。每个条目包含 `id` 和 `outputs`，输出元素使用
与清单相同的 `dtype`、`shape` 和行优先 `data`。工具会同时对照官方 ORT 实跑结果和清单中的
参考值。

```sh
"$ref_venv/bin/python" tools/reference/ort_diff.py compare path/to/dump.json
```

`tests/failure_cases.json` 将官方 ORT 参考脚本的可执行状态与 MoonBit 回归测试覆盖分别记录。
参考脚本只验证其明确声明的 Python ORT 场景；SDK 行为以 `moonbit_coverage` 指向的 MoonBit
测试为准。未列出覆盖的契约仍是待补测试项，不应推断为已验证。
