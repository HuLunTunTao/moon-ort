# 第三方组件与资产声明

本文件记录 `moon-ort` 引用、分发或用于测试的第三方组件。当前项目尚未纳入任何第三方
源码或模型资产；以下内容为已确定的计划依赖，实际引入时必须补充精确版本、下载 URL、
SHA-256 和引用范围。

| 组件 | 用途 | 许可证 | 分发策略 | 当前状态 |
|---|---|---|---|---|
| ONNX Runtime | 原生推理运行时与 C API 头文件 | MIT | MoonCakes 不分发共享库；用户提供匹配共享库。项目将随源码分发固定 v1.30.0 的 `onnxruntime_c_api.h`，并记录其来源与 SHA-256 | 已验证 v1.30.0 macOS arm64 CPU；运行时归档 SHA-256：`6ebb5062a934537c352937821f9fe9718e7de1a2db1122a93dd363ffd53a7012`；头文件尚未纳入，属于 M0 阻塞项 |
| Laya multilingual | 端到端集成验证模型 | 待按选定模型卡核实 | 不分发权重 | 待固定来源、版本和校验值 |
| Laya tokenizer | Laya 文本预处理验证资产 | 待按选定模型卡核实 | 不在 SDK 包中分发；本地验证目录保存 | 待固定来源、版本和校验值 |
| tokenizers-moonbit | MoonBit tokenizer 实现 | Apache-2.0 | MoonCakes 依赖 | 已核实候选：`howtomakeaname/tokenizers-moonbit@0.4.0`；只有 Laya 上游资产合规后才引入 |

任何新资产进入仓库前，必须在本文件补充来源、许可证、再分发权限和 SHA-256。微型 ONNX
测试模型是例外：仅当其可再生成、体积很小且来源/许可证明确时，才允许放入 `testdata/`。
