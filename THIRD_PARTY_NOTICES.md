# 第三方组件与资产声明

本文件记录 `moon-ort` 引用或随源码分发的第三方组件。ONNX Runtime v1.30.0 的 C API 头文件已放入 `native/vendor/onnxruntime/v1.30.0/`。共享库仍由调用方自行提供，不进入仓库。

| 组件 | 用途 | 许可证 | 分发策略 | 当前状态 |
|---|---|---|---|---|
| ONNX Runtime C API 头文件 v1.30.0 | 编译包内 C shim | MIT | 随源码分发头文件，不分发共享库 | 已纳入。来源与 SHA-256 见下表，与 `SOURCE.md` 一致 |
| ONNX Runtime 共享库 | 运行时动态加载 | MIT | 调用方提供匹配的 1.30.0 共享库 | 不分发。先前记录的 macOS arm64 运行时归档 SHA-256 为 `6ebb5062a934537c352937821f9fe9718e7de1a2db1122a93dd363ffd53a7012`；该值不是头文件哈希 |
| Laya multilingual | 端到端集成验证模型 | 待按选定模型卡核实 | 不分发权重 | 待固定来源、版本和校验值 |
| Laya tokenizer | Laya 文本预处理验证资产 | 待按选定模型卡核实 | 不在 SDK 包中分发；本地验证目录保存 | 待固定来源、版本和校验值 |
| tokenizers-moonbit | MoonBit tokenizer 实现 | Apache-2.0 | 未写入 `moon.mod` | 候选 `howtomakeaname/tokenizers-moonbit@0.4.0` 仅在 Laya 资产合规后才考虑；不是本 SDK 的公开依赖 |

随包头文件来自 tag `v1.30.0`，上游仓库为 <https://github.com/microsoft/onnxruntime>。`onnxruntime_c_api.h` 以引号路径包含另外两份头文件，因此这三份一起放入仓库。

| 文件 | URL | SHA-256 |
|---|---|---|
| `onnxruntime_c_api.h` | https://raw.githubusercontent.com/microsoft/onnxruntime/v1.30.0/include/onnxruntime/core/session/onnxruntime_c_api.h | `e035e30c27e74c8c00e0f483e576e12b4067d17f12e9237fd6eff8b346c9b381` |
| `onnxruntime_error_code.h` | https://raw.githubusercontent.com/microsoft/onnxruntime/v1.30.0/include/onnxruntime/core/session/onnxruntime_error_code.h | `5ce3b054e798eced8d14f5b86e98692fd33470463f96194ce0700a2d53dd8721` |
| `onnxruntime_ep_c_api.h` | https://raw.githubusercontent.com/microsoft/onnxruntime/v1.30.0/include/onnxruntime/core/session/onnxruntime_ep_c_api.h | `e6c986c9e98583f8113b2c6bc3864814883b806d501cf24da4d239c45753e235` |

同目录 `LICENSE` 的上游 URL 是 https://raw.githubusercontent.com/microsoft/onnxruntime/v1.30.0/LICENSE ，SHA-256 为 `2f07c72751aed99790b8a4869cf2311df85a860b22ded05fa22803587a48922c`。复测命令写在 `native/vendor/onnxruntime/v1.30.0/SOURCE.md`。

任何新资产进入仓库前，必须在本文件补充来源、许可证、再分发权限和 SHA-256。微型 ONNX 测试模型是例外：仅当其可再生成、体积很小且来源/许可证明确时，才允许放入 `testdata/`。

## 只在开发机上使用的 Python 工具

这些包不写入 `moon.mod`，不放进源码树，也不进入 MoonCakes 包。

| 项目 | 版本 | 链接 | 许可证 | 参考范围 |
|---|---|---|---|---|
| ONNX | `1.17.0`，由 `testdata/requirements.txt` 固定 | https://github.com/onnx/onnx | Apache-2.0。本次干净 venv 里该 wheel 的许可证文本为 Apache License Version 2.0 | `testdata/generate_models.py` 生成微型夹具 |
| NumPy | 本次 venv 装入 `2.4.6`；`tools/reference/requirements.txt` 另固定同一版本 | https://numpy.org | BSD-3-Clause。依据是该 wheel 的 `licenses/LICENSE.txt` | `onnx==1.17.0` 的安装依赖，也供 `tools/reference/ort_diff.py` 排列张量 |
| protobuf | 本次 venv 解析为 `7.36.2`。仓库没有单独固定这个版本 | https://github.com/protocolbuffers/protobuf | BSD-3-Clause。依据是该 wheel 的许可证文本 | `onnx==1.17.0` 的安装依赖 |
| ONNX Runtime Python | `1.30.0`，由 `tools/reference/requirements.txt` 固定 | https://github.com/microsoft/onnxruntime | MIT，与随包头文件同一上游 | 只给 `tools/reference/ort_diff.py` 做官方对照。本次夹具再生没有安装这个 wheel |
