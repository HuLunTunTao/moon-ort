# 三个公开场景

三个场景都使用仓库里的微型夹具，不依赖 Laya，也不使用私有权重或 tokenizer。Laya 不是公开场景。

它们由同一次官方测试覆盖。已提交 SHA：

```text
150990da2b3ff2db8a7324aa018b46d15aa5e6e4
```

在该提交的检出目录中，调用方提供官方 `libonnxruntime` 1.30.0 后执行：

```sh
MOON_ORT_LIBRARY=<libonnxruntime 1.30.0 共享库> \
  moon test --deny-warn -f 'official*' src/session/run_official_test.mbt
```

记录中的那次执行使用 `moon 0.1.20260915 (2e1a46d 2026-09-15)`，平台是 macOS arm64，库版本字符串为 `1.30.0`。退出码 0，`Total tests: 1, passed: 1, failed: 0.` 该次 `moon test` 进程的峰值 RSS 是 129122304 字节，不是单次 `Run` 的占用。测试源在 `src/session/run_official_test.mbt`，断言为精确相等。MoonBit 打印 `f32` 时会把 `2.0` 印成 `2`；断言对照的仍是 `[2.0, -3.5]`。

未设置 `MOON_ORT_LIBRARY`，或库不是官方 1.30.0 / API 30 时，该测试打印 `skip:` 并退出 0。那不是下面任何一个场景的通过记录。

夹具由 `testdata/generate_models.py` 生成，opset 13。下表 SHA-256 来自已提交的 `testdata/SHA256SUMS`。

## 场景一：数值特征变换

`testdata/add_f32.onnx` 对单路 `f32` 向量做固定偏置。SHA-256：`7e1d718adc9faee1a389550e17b038ad0827ebb20dd1d6c632f6542bdb050468`。

| 项 | 值 |
|---|---|
| 输入 `input` | `[0.5, -1.5]`，形状 `[2]` |
| 输出 `output` | `[2.0, -3.5]`，形状 `[2]` |

## 场景二：双离散特征或 Token 融合

`testdata/two_inputs_i64.onnx` 把两路 `i64` 输入相加。SHA-256：`299e6cf24dac9b43b1961bb33f1534a5452be02f0a499fab3f9b206ad6c3f7e0`。

| 项 | 值 |
|---|---|
| 输入 `left` | `[-5, -3]` |
| 输入 `right` | `[-3, -1]` |
| 输出 `sum` | `[-8, -4]` |

## 场景三：动态 batch 的分数与布尔门控

这一场景用两个夹具。`testdata/two_outputs_f32_bool.onnx` 的 SHA-256 是 `12dd7649d945656fe225134932461a9c4ca412887ac3b03ceda8ad368c39523b`。`testdata/dynamic_identity_f32.onnx` 的 SHA-256 是 `794dd006c106b82a851b34d219527489a59c43fe7020d7621a93956e3ebdf432`。

分数与门控：

| 项 | 值 |
|---|---|
| 输入 `scores` | `[-1.5, 0.25]` |
| 输出 `shifted` | `[-0.5, 1.25]` |
| 输出 `positive` | `[false, true]` |

动态 batch 的恒等映射：

| 项 | 值 |
|---|---|
| batch 1 输入 `input` | `[[1.0, -2.0]]`，形状 `[1, 2]` |
| batch 1 输出 `output` | `[1.0, -2.0]`，形状 `[1, 2]` |
| batch 3 输入 `input` | `[[2.0, 0.0], [-0.5, 2.0], [2.0, -1.5]]`，形状 `[3, 2]` |
| batch 3 输出 `output` | `[2.0, 0.0, -0.5, 2.0, 2.0, -1.5]`，形状 `[3, 2]` |

复现同一次归档运行的步骤见 [remote-verify.md](remote-verify.md)。
