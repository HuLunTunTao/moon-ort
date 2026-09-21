# 支持矩阵

只把 macOS arm64 上的 CPU 执行提供程序记为已验证。其余平台保持未验证或不支持。

| 平台 / 执行提供程序 | 状态 | v0.1 承诺 |
|---|---|---|
| macOS arm64 / CPU | 已在提交 `150990da2b3ff2db8a7324aa018b46d15aa5e6e4` 上，用官方 ONNX Runtime 1.30.0 跑通 `src/session/run_official_test.mbt`。命令和数值见 [scenarios.md](scenarios.md) | 唯一正式支持平台 |
| Linux（任意架构） | 未验证 | 不支持 |
| Windows | 不做 | 不支持 |
| CoreML、CUDA、TensorRT、DirectML、NNAPI、QNN、WebGPU | 不在 v0.1 | 不支持 |

Ubuntu 上的 GitHub Actions 只运行 `moon fmt --check` 和 `moon check --deny-warn`。该 job 不运行 `moon test`，不加载 ONNX Runtime，也不表示 Linux native 支持。

没有已登记的 macOS arm64 self-hosted runner。工作流里因此没有 macOS job，避免一条未执行的 native 检查显示为绿色。macOS 证据目前是人工远程复验，步骤见 [remote-verify.md](remote-verify.md)。在该 runner 实际跑过 native 格式、检查、构建和测试之前，本仓库不是完整发布就绪。
