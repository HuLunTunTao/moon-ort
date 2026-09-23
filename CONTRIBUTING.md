# 贡献指南

感谢参与 `moon-ort`。请先阅读 [支持范围](docs/support.md)，避免把未支持的平台或执行提供程序
误当成已有能力。

## 本地检查

修改 MoonBit 源码、原生 shim 或包配置后，在仓库根目录运行：

```sh
moon fmt --check
moon check --deny-warn
moon test --deny-warn
```

测试会编译原生 C stub。可通过 `CC` 指定编译器；未指定时，测试依次尝试 `gcc-15` 和系统
`cc`。设置 `MOON_ORT_LIBRARY` 后，测试还会使用该共享库运行官方夹具比较。

## 测试资产与提交

`testdata/` 的微型 ONNX 模型可按 [说明](testdata/README.md) 重新生成。请勿提交 ONNX Runtime
共享库、模型权重、依赖缓存、凭据或本机配置。

提交信息采用 Conventional Commit 英文前缀与简体中文说明，例如：

```text
feat(session): 支持批量输出
```

新增第三方代码、模型或测试资产时，请同时更新
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)，说明来源、许可证和再分发条件。
