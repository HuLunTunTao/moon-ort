# 失败用例契约

本目录保存失败用例契约；MoonBit 实现测试位于 `src/`。早期 `agent/test/m1-fixtures`
分支创建时，仓库尚无 FFI、Session、Tensor 或 Run SDK 包，因此当时不能直接导入这些 API；
这只是历史状态，不代表当前测试覆盖。

当前 MoonBit 回归测试覆盖：

- `src/raw/load_test.mbt`：缺失库、API 版本不匹配、缺少 ORT 符号、环境构造失败及状态清理、环境句柄关闭/关闭后使用。
- `src/raw/handle_fail_test.mbt`：Session、SessionOptions、Tensor 句柄的重复关闭、关闭后使用和参数校验。
- `src/raw/run_test.mbt`、`src/session/run_test.mbt`：输入/输出名称、输入数量、缺失输入、类型和 shape 校验，以及失败时资源清理。
- `src/session/failure_test.mbt`、`src/session/metadata_test.mbt`、`src/session/session_test.mbt`：模型路径、元数据、选项及公开 API 错误行为。
- `src/tensor/tensor_test.mbt`、`src/tensor/tensor_wbtest.mbt`、`src/raw/value_test.mbt`：Tensor 构造、关闭、固定 i64/bool 字节布局、标量/零维 shape 与 f32/i64/bool 数据。
- `src/session/run_official_test.mbt`：配置错误的官方库会失败；配置官方 ONNX Runtime 1.30.0 时运行夹具比较。未配置库时仅此官方集成测试按约定跳过。

`failure_cases.json` 中 `runner` 与 `executable_now` 描述参考 ORT 脚本可否直接执行；
`moonbit_coverage` 描述对应契约是否有 MoonBit 回归测试，不应把二者混为一谈。项目的
MoonBit 质量门及其证据要求见仓库根目录 `CONTRIBUTING.md`。对于参考脚本不可执行的草案，
契约校验要求提供 `blocked_on` 或 `moonbit_coverage`；覆盖指引不代表参考脚本会运行 SDK 测试。
