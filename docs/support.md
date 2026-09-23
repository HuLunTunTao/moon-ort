# 支持范围

## 平台

| 平台 | 状态 |
|---|---|
| macOS arm64 / CPU | 已验证 |
| Linux amd64 / CPU | 原生 CI 已配置，待首次远程运行确认 |
| Windows | 未支持 |

`moon-ort` 使用官方 ONNX Runtime 1.30.0 C API，并以动态库方式加载。
它不提供静态链接、也不包含ONNX运行时。使用需要提前在目标设备上自行部署ONNX运行时。

## 已支持的能力

- 从本地 ONNX 文件创建 CPU `Session`
- 读取输入输出名称、元素类型、静态或动态维度及基本模型元数据
- 创建和读取 `f32`、`i64`、`bool` 稠密 CPU 张量
- 多输入、多输出同步 `Session::run`
- 图优化等级、顺序/并行执行、intra-op 与 inter-op 线程配置

## 未支持的能力

- CUDA、CoreML、TensorRT、DirectML、NNAPI、QNN、WebGPU、WASM 或 JavaScript 后端
- 字符串、`f16`、`bf16`、稀疏、Sequence、Map、Optional 张量
- I/O Binding、设备指针、零拷贝 GPU 张量、异步取消和训练
- ONNX 模型转换、量化、生成式 AI API 与纯 MoonBit ONNX 解释器

如果模型的输入或输出使用未支持的张量类型，仍可读取其元数据；尝试将其转换为 v0.1 张量时会
返回结构化错误。
