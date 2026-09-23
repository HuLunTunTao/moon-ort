# moon-ort

`moon-ort` 是 MoonBit 的 ONNX Runtime CPU 推理绑定。它通过官方 C API 在运行时加载
ONNX Runtime 1.30.0；包本身不携带、下载或链接 ONNX Runtime 二进制。


## 快速开始

准备官方 ONNX Runtime 1.30.0 的共享库后，设置其路径：

```sh
export MOON_ORT_LIBRARY=/path/to/libonnxruntime.1.30.0.dylib
```

在源码仓库中先确认运行时可被加载：

```sh
moon run src/raw/cmd
```

再用仓库自带的微型模型查看输入输出契约：

```sh
moon run src/session/cmd -- testdata/add_f32.onnx
```

完整的推理示例位于 [examples/add_f32](examples/add_f32)，运行方式为：

```sh
moon run examples/add_f32 -- "$MOON_ORT_LIBRARY" testdata/add_f32.onnx
```

## 文档

- [安装 ONNX Runtime 与排查加载错误](docs/install.md)
- [编写一次推理调用](docs/usage.md)
- [支持的平台与能力边界](docs/support.md)
- [架构与资源所有权](docs/architecture.md)
- [贡献与测试](CONTRIBUTING.md)
- [第三方组件与许可证](THIRD_PARTY_NOTICES.md)

## 当前限制

首个版本不支持 Windows、GPU 执行提供程序、训练、I/O Binding、字符串张量或
ONNX Runtime 二进制分发。详见 [支持说明](docs/support.md)。

## 许可证

本项目采用 [MIT](LICENSE) 许可证。ONNX Runtime C API 头文件的来源与许可证见
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
