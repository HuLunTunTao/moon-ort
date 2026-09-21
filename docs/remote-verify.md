# 远程复验

维护者用 [scripts/remote-verify.sh](../scripts/remote-verify.sh) 把一个已提交 SHA 解到验证机的隔离目录，再跑官方比较测试。脚本不读取工作区里未提交的改动。

验证者提供 SSH 目标。主机名、端口、身份文件和口令留在验证者自己的 SSH 配置里，不写入本仓库。

```sh
scripts/remote-verify.sh <ssh-destination> [commit]
```

省略 commit 时使用 `HEAD`。脚本只接受 `git rev-parse` 得到的提交对象。

远程根目录是 `<remote-root>`。快照写到 `runs/<sha>/`，不带 `.git`。脚本不覆盖该根目录下的 `.moon` 工具链或 `.deps` 共享库，也不在远程提交源码。`tar` 与 `shasum` 在 `LC_ALL=C` 和 `LANG=C` 下执行。

官方测试使用该树里已有的 MoonBit 与 `libonnxruntime` 1.30.0。默认命令与 [scenarios.md](scenarios.md) 相同：`moon test --deny-warn -f 'official*' src/session/run_official_test.mbt`。输出里如果出现 `skip:`，或缺少场景文档中的 `reference=` 文本，脚本以非零退出，即使 `moon test` 本身退出 0。

脚本不运行 Laya，不下载权重、tokenizer 或 ONNX Runtime 二进制。

`150990da2b3ff2db8a7324aa018b46d15aa5e6e4` 的快照目录已经存在，其中没有 `.git`。该目录里的 `src/session/run_official_test.mbt` 与这个提交的同名文件 SHA-256 相同：`c1f8cfeeaece48251550c07726dfb0fa487f800a8f1818d6555c7e06dea76ace`。目录内没有单独的 stdout 日志；数值以测试源码中的断言和 [scenarios.md](scenarios.md) 的记录为准。
