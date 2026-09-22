# 贡献与本地测试

从已有源码树开始。

改动 MoonBit 源码或包配置后，在仓库根目录运行：

```sh
moon fmt --check
moon check --deny-warn
moon test --deny-warn
```

`moon test` 会编译 `src/raw` 的 C stub。测试优先采用环境变量 `CC` 指定的编译器，未指定时依次尝试 `gcc-15` 与系统 `cc`。未设置 `MOON_ORT_LIBRARY` 时，官方比较测试打印 `skip:` 并退出 0；那不是官方 ONNX Runtime 通过。

微型夹具的再生命令在 [testdata/README.md](../testdata/README.md)。生成器不改写 `SHA256SUMS`；字节变化会使 `shasum -a 256 -c SHA256SUMS` 失败。

提交说明使用英文 Conventional Commit 前缀和简体中文动宾短语，例如 `docs(docs): 补充安装说明`。不要提交空提交。

不要提交 ONNX Runtime 共享库、模型权重、tokenizer、依赖缓存、凭据或主机名。Laya 不进入公开场景、CI 或发布说明。`.github/workflows/static.yml` 只在 Ubuntu 上做 `moon fmt --check` 和 `moon check --deny-warn`。没有已登记并实际执行 native 测试的 macOS arm64 runner 时，不要添加一条显示为绿色的 macOS job。
