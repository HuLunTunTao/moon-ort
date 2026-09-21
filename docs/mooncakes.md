# MoonCakes 发布准备

这里只列出发布者必须亲自核对的事实。本文不执行 `moon publish`，不创建 Git 远程，也不填写 `moon.mod` 的 `repository`。

| 项 | 当前值 |
|---|---|
| 模块名 | `HuLunTunTao/moon-ort` |
| 版本 | `0.1.0` |
| 许可证 | MIT（根目录 `LICENSE`） |
| `readme` | `README.md` |
| `repository` | 空。公开 Git 远程还不存在，不能填一个尚未创建的 URL |

## 发布者要核对

- `moon.mod` 的名称、版本和许可证与上表一致，且依赖里没有 Laya tokenizer。
- 根 `LICENSE` 为 MIT。随包头文件的 URL 与 SHA-256 与 `native/vendor/onnxruntime/v1.30.0/SOURCE.md` 以及 [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) 一致。可用该目录里的 `shasum -a 256` 命令复测。
- 发布包不包含模型权重、tokenizer、ONNX Runtime 共享库或压缩包、构建缓存、凭据、SSH 密钥和主机名。调用方自行提供匹配的 1.30.0 共享库，见 [install.md](install.md)。
- 三个公开场景的命令和预期值仍与 [scenarios.md](scenarios.md) 里的 SHA `150990da2b3ff2db8a7324aa018b46d15aa5e6e4` 一致。Laya 不写入发布说明。
- Ubuntu 工作流只做静态检查。没有已登记的 macOS arm64 self-hosted runner，因此还不能把包标成完整发布就绪。见 [support.md](support.md)。
- 发布之后，在干净项目里声明该依赖，显式提供官方 `libonnxruntime` 1.30.0，再运行场景文档中的官方测试。页面上的版本、README、许可证和仓库链接要与 tag、`moon.mod` 版本一致。
- 在公开远程存在之前，不要补写 `repository`。远程由项目负责人创建；本文件不给出仓库 URL。
