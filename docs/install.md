# 安装与外部 ONNX Runtime

`moon-ort` 在运行时动态加载调用方提供的 ONNX Runtime **1.30.0** 共享库。包内不链接 `-lonnxruntime`，也不下载、缓存或分发该二进制。

本文描述已在仓库中的加载方式。模块还没有发布到 MoonCakes；发布前要核对的事项见 [mooncakes.md](mooncakes.md)。

## 拿到源码之后

在已提交的源码树里使用 MoonBit。记录过官方运行时结果的工具链是 `moon 0.1.20260915 (2e1a46d 2026-09-15)`。`moon.mod` 没有另写编译器版本。

安装入口是 <https://www.moonbitlang.com/download/>。2026-09-22 读取该页时，Unix 安装命令是：

```sh
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
```

同一脚本接受一个版本参数。与上面记录的工具链对齐时使用：

```sh
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash -s -- 0.1.20260915
```

`Darwin arm64` 会安装 `darwin-aarch64` 目标。不带参数则安装脚本当时的最新版。

```sh
moon fmt --check
moon check --deny-warn
moon test --deny-warn
```

`moon test` 会编译 `src/raw` 的 C stub。stub 只使用随包头文件和 `stub-cc-flags`。`src/raw/moon.pkg` 没有 `cc-link-flags`，也没有 `-lonnxruntime`。不需要安装 ONNX Runtime 开发头文件。

未设置 `MOON_ORT_LIBRARY` 时，官方比较测试会跳过并仍然退出 0。跳过只说明本进程没有加载官方 `libonnxruntime` 1.30.0，不是官方推理通过。

## 调用方提供的共享库

正式平台是 macOS arm64。调用方用自己的系统包、容器或官方 ONNX Runtime 1.30.0 发布包提供共享库，文件名通常是 `libonnxruntime.dylib` 或带版本号的 `libonnxruntime.1.30.0.dylib`。库必须报告版本字符串 `1.30.0`，并且 C API 版本为 30。

加载入口是 `Runtime::load(path)`，位于包 `HuLunTunTao/moon-ort/src/raw`。`path` 是唯一尝试的位置。成功时会 `dlopen`、协商 `OrtGetApiBase` 并创建 `OrtEnv`。`src/session` 的 `configured_library` 读取环境变量 `MOON_ORT_LIBRARY`，供官方比较测试使用；普通调用仍然把路径交给 `Runtime::load`。

加载失败返回 `OrtError`，不留下已打开的环境：

| 结果 | 含义 |
|---|---|
| `MissingLibrary` | 路径打不开，带有尝试路径和加载器原文 |
| `SymbolNotFound` | 库里没有所需符号 |
| `ApiMismatch` | 期望 API 与实际 API 不一致 |
| `Status` | ORT 返回了状态码、消息和 API 名 |

关闭规则、句柄所有权和三个场景的命令见 [architecture.md](architecture.md)、[limits.md](limits.md) 和 [scenarios.md](scenarios.md)。
