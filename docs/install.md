# 安装 ONNX Runtime

`moon-ort` 在运行时使用 `Runtime::load(path)` 加载调用方提供的 ONNX Runtime **1.30.0**
共享库。它不静态链接、不下载，也不在包中分发该二进制。

## 前置条件

- MoonBit native 工具链
- macOS arm64
- 官方 ONNX Runtime 1.30.0 的 macOS arm64 共享库

从 [MoonBit 下载页](https://www.moonbitlang.com/download/) 安装 MoonBit。随后从 ONNX Runtime
官方发布页取得与平台匹配的 1.30.0 归档，并将共享库保存在调用方管理的位置。

```sh
export MOON_ORT_LIBRARY=/path/to/libonnxruntime.1.30.0.dylib
```

在源码仓库中运行下列命令即可确认动态加载、ORT 版本和 C API 版本：

```sh
moon run src/raw/cmd
```

成功时会打印 ORT 版本、实际 API 版本与包头文件期望的 API 版本。

## 常见加载错误

| 错误 | 含义与处理方式 |
|---|---|
| `MissingLibrary` | 路径不存在、不可读或动态加载器无法解析依赖；检查 `MOON_ORT_LIBRARY` 或传给 `Runtime::load` 的路径。 |
| `SymbolNotFound` | 指向的共享库不是兼容的 ONNX Runtime C API。 |
| `ApiMismatch` | 共享库 API 版本与本包固定的 API 30 不一致；改用 ONNX Runtime 1.30.0。 |
| `Status` | ONNX Runtime 在创建环境、会话或执行推理时返回错误；错误中包含 API 名、状态码和原始消息。 |

包在编译时使用随源码分发的 MIT 许可证 C API 头文件，因此调用方不需要另行安装 ONNX Runtime
开发头文件。头文件来源见 [第三方声明](../THIRD_PARTY_NOTICES.md)。
