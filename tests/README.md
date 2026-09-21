# 失败用例契约

本目录目前只有数据和说明，没有 MoonBit 源文件。

`agent/test/m1-fixtures` 从基线 `63c082c` 拉出时，仓库只有 `moon.mod`，没有 FFI 包，也没有
Session、Tensor 或 Run 的 SDK 包。失败用例因此不能导入尚未合并的 API。可在官方 ONNX
Runtime 上观察的四条负例放在 `failure_cases.json`，由 `tools/reference/ort_diff.py verify`
执行。环境句柄的构造、重复关闭、关闭后使用、空句柄和 `OrtStatus` 清理仍是草案，等 FFI
实现合并后再写成 MoonBit 测试。

因为本分支没有 `.mbt` 文件，`moon fmt --check`、`moon check --deny-warn` 和
`moon test --deny-warn` 不作为本任务的通过证据。
