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

## 本地打包演练

下面的步骤只核对未发布的 zip。它不执行 `moon publish`，也不把包放进 MoonCakes。

在模块目录执行 `moon package`。`repository` 为空时工具会警告，仍可退出 0。产物是被 git 忽略的 `_build/publish/HuLunTunTao-moon-ort-0.1.0.zip`。

`moon add` 只查找已发布版本。未发布时：

```sh
moon add --no-update HuLunTunTao/moon-ort
```

退出码 255。错误原文：

```text
Could not find the latest published version of `HuLunTunTao/moon-ort` in the registry. Please consider running `moon update` to update the index.
```

本地演练不刷新注册表索引，改为把解压后的 zip 放进工作区。

在仓库外的临时目录：

```sh
unzip -q _build/publish/HuLunTunTao-moon-ort-0.1.0.zip -d "$base/pkg"
moon new --user prep --name downstream "$base/downstream"
```

把消费者的 `preferred_target` 和 `supported_targets` 都写成 `native`，与本模块一致。在 `$base` 执行 `moon work init downstream pkg`。消费者的 `moon.mod` 声明：

```moon
import {
  "HuLunTunTao/moon-ort@0.1.0",
}
```

可执行包再导入 `HuLunTunTao/moon-ort/src/raw`、`src/session` 和 `src/tensor`。然后在 `$base` 执行 `moon check --deny-warn`。调用方把 `MOON_ORT_LIBRARY` 指到自己的 `libonnxruntime` 1.30.0，把模型路径交给 `Session::create`，即可调用 `Runtime::load` 和 `Session::run`。这次演练只跑了 `add_f32.onnx`，不是发布后的 `moon add`，也不是三个场景的官方测试文件。
