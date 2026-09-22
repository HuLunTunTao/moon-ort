# 远程复验

维护者用 [scripts/remote-verify.sh](../scripts/remote-verify.sh) 把一个已提交 SHA 解到验证机的隔离目录，再跑官方比较测试。脚本不读取工作区里未提交的改动。

验证者提供 SSH 目标。主机名、端口、身份文件和口令留在验证者自己的 SSH 配置里，不写入本仓库。

```sh
MOON_ORT_REMOTE_ROOT=<remote-root> \
  scripts/remote-verify.sh <ssh-destination> [commit]
```

`MOON_ORT_REMOTE_ROOT` 是验证者拥有的远程目录；它不能是 `/`。省略 commit 时使用 `HEAD`。脚本只接受 `git rev-parse` 得到的提交对象。默认情况下，脚本从该目录下读取 `.moon/bin/moon`、`.moon/bin/moonc` 与 ORT 1.30.0 共享库；若验证机采用其他布局，可在本机设置 `MOON_ORT_MOON_BIN`、`MOON_ORT_MOONC_BIN` 与 `MOON_ORT_LIBRARY` 覆盖对应的远程路径。

快照写到 `<remote-root>/runs/<sha>/`，不带 `.git`。脚本不覆盖远程根目录下的工具链或共享库，也不在远程提交源码。`tar` 与 `shasum` 在 `LC_ALL=C` 和 `LANG=C` 下执行。

官方测试使用该树里已有的 MoonBit 与 `libonnxruntime` 1.30.0。默认命令与 [scenarios.md](scenarios.md) 相同：`moon test --deny-warn -f 'official*' src/session/run_official_test.mbt`。输出里如果出现 `skip:`，或缺少场景文档中的 `reference=` 文本，脚本以非零退出，即使 `moon test` 本身退出 0。

脚本不运行 Laya，不下载权重、tokenizer 或 ONNX Runtime 二进制。
