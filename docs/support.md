# 支持矩阵

状态只用三类：已验证、预计可用、未支持。当前没有预计可用的平台或执行提供程序。

| 平台 / 执行提供程序 | 状态 | v0.1 承诺 |
|---|---|---|
| macOS arm64 / CPU | 已验证。提交 `150990da2b3ff2db8a7324aa018b46d15aa5e6e4` 上用官方 ONNX Runtime 1.30.0 跑通 `src/session/run_official_test.mbt`。命令和数值见 [scenarios.md](scenarios.md) | 唯一正式支持平台 |
| Linux（任意架构） | 未支持。没有 Linux native 验收记录 | 不承诺 |
| Windows | 未支持 | 不承诺 |
| CoreML、CUDA、TensorRT、DirectML、NNAPI、QNN、WebGPU | 未支持 | 不在 v0.1 |

Ubuntu 上的 GitHub Actions 只运行 `moon fmt --check` 和 `moon check --deny-warn`。该 job 不运行 `moon test`，不加载 ONNX Runtime，也不表示 Linux native 支持。

`.github/workflows/macos-arm64.yml` 定义了 GitHub 托管的 macOS arm64 job，`runs-on` 为 `macos-15`。该标签在 GitHub 托管 runner 表里是 arm64，不是 `macos-15-intel`。job 会在执行时下载官方 ONNX Runtime 1.30.0 osx-arm64，并运行 `moon fmt --check`、`moon check --deny-warn` 和 `moon test --deny-warn`。这个 job 还没有在 GitHub 上执行，不是绿色。macOS 上已有的证据仍是人工远程复验，步骤见 [remote-verify.md](remote-verify.md)。在该 job 实际跑过之前，本仓库不是完整发布就绪。
