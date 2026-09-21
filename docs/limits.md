# 限制

v0.1 只做 CPU 同步推理。下面各项都不是当前能力。

- 不静态链接 ONNX Runtime，不使用 `-lonnxruntime`，不把共享库放进仓库或 MoonCakes 包。
- 不支持 Linux 与 Windows。Ubuntu 静态检查不是 native 支持，见 [support.md](support.md)。
- 不支持 CoreML、CUDA、TensorRT、DirectML、NNAPI、QNN、WebGPU，以及 WASM / JavaScript 后端。
- 不支持字符串、`f16`、`bf16`、稀疏张量、Sequence、Map、Optional、设备指针和零拷贝 GPU 张量。
- 不支持 I/O Binding、异步取消、RunOptions 高级配置，或从网络 URL / 设备 buffer 加载模型。
- 不提供纯 MoonBit ONNX 解释器，也不提供独立 `doctor` 命令。加载失败只返回 [install.md](install.md) 里的结构化错误。
- 不在运行中切换执行提供程序。图优化等级、intra-op / inter-op 线程数可以设置；v1.30.0 原始 API 能读回的是执行模式。
- 官方夹具比较使用精确相等：`f32` 的 `rtol=0`、`atol=0`，`i64` 与 `bool` 逐项相同。这不是放宽后的阈值。
- Laya 不是公开场景，不进入 CI，也不是 v0.1 的完成条件。
- 还没有公开 Git 远程，没有已登记的 macOS arm64 runner，也还没有 MoonCakes 发布。这些缺口见 [mooncakes.md](mooncakes.md)。

与相邻项目的边界：`tch-mbt` 走 libtorch；`mizchi/webnn` 走 WebNN / TFLite。`moon-ort` 只动态加载官方 ONNX Runtime C API。
