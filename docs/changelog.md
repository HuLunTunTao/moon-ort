# 变更记录

`moon.mod` 中的版本是 `0.1.0`。这个版本还没有 MoonCakes 发布、tag 或干净项目安装记录，核对项见 [mooncakes.md](mooncakes.md)。

当前源码包含：

- 动态加载官方 ONNX Runtime 1.30.0 C API，并创建可关闭的环境
- CPU `SessionOptions`、从文件创建的 `Session`，以及输入输出和模型元数据
- `f32`、`i64`、`bool` 稠密 CPU 张量
- 多输入、多输出的同步 `Run`
- 可再生成的微型夹具，以及 [scenarios.md](scenarios.md) 中的三个公开场景
- Ubuntu 上的格式与类型检查，见 `.github/workflows/static.yml`
- 已定义、尚未在 GitHub 执行的 macOS arm64 native 测试，见 `.github/workflows/macos-arm64.yml`

发布门槛里尚未勾选的项写在 [architecture.md](architecture.md) 第 12 节。Laya 不在本记录中。
