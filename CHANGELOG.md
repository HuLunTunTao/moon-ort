# Changelog

本项目遵循 Keep a Changelog 的格式，版本号遵循语义化版本。

## [0.1.1] - 2026-09-28

### Added

- 为 `Tensor` 增加 `from_f32_bytes`、`from_i64_bytes` 和 `from_bool_bytes`，支持从字节缓冲区创建拥有数据的 CPU 张量。

### Changed

- `Session::run` 复用张量字节接口，减少输入输出转换和中间数组分配。
- 将数值张量字节序明确为固定 little-endian；当前支持的平台均为 little-endian，big-endian 主机不受支持。
- Linux amd64 / CPU 从“待验证”更新为“已验证”。

### Fixed

- 将不可用的 ORT 类型信息映射为结构化错误，避免依赖错误消息文本判断。
- 元数据 shape rank 不一致时返回结构化错误，不再触发进程级 abort。
- 拒绝超长输入/输出名称，避免名称缓冲区截断导致错误匹配；区分空名称与未知名称。
- 修复失败路径中的张量形状信息清理，并在关闭运行时后清除失效的 API 表指针。

### Tests

- 扩展低 ORT API 版本、多输入/多输出失败清理、标量推理及资源生命周期回归。
- 增加 Python ONNX Runtime 参考验证与夹具再生成的 CI job。
