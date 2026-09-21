# v0.1 能力边界

本文冻结 `HuLunTunTao/moon-ort` v0.1 的书面契约，相对基线 `63c082c`。契约是后续实现必须遵守的边界。基线没有 SDK 源码、没有 Session、没有 `Run`，因此下文各项能力都是目标，不是已经支持的功能。

本文不发布 MoonCakes，不创建 GitHub remote，也不代替根 `README.md`。根 README 仍是短入口；安装、运行时依赖、支持矩阵和所有权以本文为准。

## 1. 模块

基线 `moon.mod` 已冻结：

| 项 | 值 |
|---|---|
| 模块名 | `HuLunTunTao/moon-ort` |
| 包版本 | `0.1.0` |
| 许可证 | `MIT` |
| `preferred_target` | `native` |
| `supported_targets` | `native` |
| `repository` | 空；本任务不填写、不创建远端 |

v0.1 只发布 native 目标。本文件不另写基线里没有的 MoonBit 编译器最低版本号。以后对已提交 SHA 做验收时，记录当次实际使用的 MoonBit / moonc 版本。

计划中的目录（除 `moon.mod`、`docs/`、`testdata/` 外，基线均未创建）：

| 路径 | 冻结职责 |
|---|---|
| `src/raw/` | 唯一允许声明 native stub 的包；其 `moon.pkg.json` 不得出现 `cc-link-flags` 或 `-lonnxruntime` |
| `native/vendor/onnxruntime/v1.30.0/` | 随包分发的官方 C API 头文件 |
| `src/runtime/` | `Runtime::load` 与 `Env` |
| `src/session/` | `SessionOptions`、`Session`、元数据、同步 `Run` |
| `src/tensor/` | `f32` / `i64` / `bool` CPU 张量 |
| `src/api/` | 对普通用户稳定的公共入口 |

## 2. 运行时 ABI

v0.1 只动态加载官方 ONNX Runtime **v1.30.0** C API。

- 加载入口是 `OrtGetApiBase`。期望的 API 版本由随包头文件决定，加载时核对该版本，并读取 ORT 版本字符串。
- 调用方用 `Runtime::load(path)` 或环境变量 `MOON_ORT_LIBRARY` 给出共享库路径。正式平台上的库文件名是 `libonnxruntime.dylib`。
- 包构建期不静态链接 ONNX Runtime，不使用 `cc-link-flags`，不使用 `-lonnxruntime`，不把 dylib、压缩包或其他 ORT 二进制放进仓库或 MoonCakes 包。
- MoonCakes 只分发 MoonBit 代码和已用随包头文件编译的 C shim。下游 `moon add` 之后只需自行提供匹配的共享库，不需要安装 C 头文件。SDK 不下载、不缓存、不分发该共享库。
- 缺库或 API 版本不符时，`Runtime::load` 返回结构化错误，不崩溃。错误至少包含：尝试过的路径、动态加载器原始错误、实际 API 版本、期望 API 版本。
- 不提供独立 `doctor` CLI。加载诊断只走上述结构化结果。

未归档、且不能当作本仓库验收的探索：官方 ORT v1.30.0 曾在 macOS arm64 上完成 `dlopen`、协商当时称为 C API v30 的结果、创建 `OrtEnv`，并用独立 C 程序得到 `[2, 3] -> [3.5, 1]`。该模型不是 `testdata/add_f32.onnx`。这组数字不是三个公开场景的预期输出，也不是 SDK 测试证据。另一项未归档探索表明 MoonBit `native-stub` 库包可被独立 executable 消费，且 `moon package --list` 会包含 C stub。两项都还没有绑定已提交 SHA 的可重跑归档，不能作为 M0 输入。真实 MoonCakes 安装仍要等发布之后再验证。

## 3. 编译期头文件

官方 `onnxruntime_c_api.h` **v1.30.0** 以 MIT 许可证随源码放入：

```text
native/vendor/onnxruntime/v1.30.0/onnxruntime_c_api.h
```

C shim 在包构建期使用这份头文件编译。下游不安装开发头文件。

基线 `63c082c` 的仓库里还没有该头文件。SHA-256 与精确下载 URL 待引入该文件的 FFI 提交写入第三方声明。本文不编造哈希。

`THIRD_PARTY_NOTICES.md` 已记录一份 macOS arm64 CPU 运行时归档的 SHA-256：`6ebb5062a934537c352937821f9fe9718e7de1a2db1122a93dd363ffd53a7012`。该值标识共享库归档，不是头文件哈希，也不附带本仓库已提交 SHA 上的可重跑命令，因此不是 SDK 验收证据。

## 4. 能力矩阵

下表是 v0.1 要交付的公共能力。每一行在基线都没有 SDK 实现，也没有 `Run` 证据。

| 能力 | v0.1 契约 |
|---|---|
| `Env` | 动态加载成功后创建；普通用户只持有句柄 |
| `SessionOptions` | 图优化等级、顺序/并行执行、intra-op 线程数、inter-op 线程数 |
| `Session` | 从模型文件创建；查询元数据；同步 `Run` |
| CPU 张量 | `f32`、`i64`、`bool` 稠密张量，含动态 shape |
| 元数据 | 输入输出的数量、名称、元素类型、静态/动态 shape；producer、graph name、domain、description、version，以及底层 API 实际提供的自定义 metadata |
| `Run` | 按名称提交多个输入、选择多个输出、同步执行 |

与正式 ONNX Runtime 能力对照：

| 正式 ORT 能力 | v0.1 | 本计划之后 |
|---|---|---|
| Env、Session、SessionOptions、同步 CPU `Run` | 纳入 | 维持该边界 |
| `f32` / `i64` / `bool` 稠密 CPU 张量与动态 shape | 纳入 | 维持该边界 |
| 输入输出与基本模型元数据 | 纳入 | 维持该边界 |
| 图优化等级、顺序/并行、intra-op / inter-op 线程 | 纳入 | 维持该边界 |
| 字符串、稀疏、Sequence、Map、Optional `OrtValue` | 排除 | 不承诺 |
| I/O Binding、设备指针、零拷贝 GPU 张量 | 排除 | 不承诺 |
| 训练、模型转换、量化、GenAI API | 排除 | 不承诺 |
| 自定义算子注册、自定义 allocator 插件 | 排除 | 不承诺 |
| CUDA、TensorRT、DirectML、NNAPI、QNN、WebGPU、WASM / JavaScript | 排除 | 不承诺 |
| CoreML | 排除 | 另立提案，且不得改变 CPU v0.1 公共 API |
| 纯 MoonBit ONNX 解释器、独立 `doctor` CLI | 排除 | 不承诺 |

`SessionOptions` 只配置 CPU Execution Provider。v0.1 不在运行中切换执行提供程序，不从设备 buffer 或网络 URL 加载模型。

张量默认走调用方数据的安全复制。零拷贝借用只有在生命周期能被严格证明时才能加入，不是 v0.1 的已支持能力。不支持 `f16`、`bf16`、string、稀疏张量、Sequence、Map、Optional 和设备指针。

同步 `Run` 校验缺失输入、重复名称、未知名称、类型不匹配和 shape 不兼容。不支持异步取消、RunOptions 高级配置、I/O Binding 或设备输出。

## 5. 支持矩阵

| 平台 / 执行提供程序 | 状态 | v0.1 承诺 |
|---|---|---|
| macOS arm64 / CPU | 唯一正式平台。加载与微型模型只有未归档探索，没有绑定已提交 SHA 的 SDK 验收 | 正式支持与验收平台 |
| Linux（任意架构） | 未验证 | 不支持。不得写成已支持，也不得用 Linux native 成功来宣称 |
| Windows | 不做 | 不支持 |
| CoreML 及其他非 CPU 提供程序 | 不在本计划内 | 不进入 v0.1 |

本任务不添加 CI。若后续加入 Ubuntu job，该 job 只能做格式、可移植静态检查和不加载 ORT 的纯 MoonBit 测试。Ubuntu 绿灯不是 Linux native 支持，也不能代替 macOS arm64 上的原生构建与运行证据。未配置受控 macOS arm64 runner 之前，项目不是完整发布就绪。

## 6. 所有权、释放与错误

普通用户看不到 `OrtEnv*`、`OrtSession*`、`OrtValue*` 或 allocator 指针。句柄由 MoonBit 侧持有。异常不得跨越 C ABI。失败路径不得遗留 `OrtStatus`。

关闭规则对 `Env`、`SessionOptions`、`Session`、`Tensor` 相同：

- 由持有者关闭恰好一次。
- 重复关闭是错误。
- 关闭后使用是错误。
- 构造失败和部分初始化失败不得把未完成的句柄交给调用方。

| 类型 | 所有权 | 释放时机 | 线程假设 |
|---|---|---|---|
| `Env` | `Runtime::load` 成功后由调用方持有 | 调用方关闭恰好一次。仍在使用的 `Session` 必须先关闭 | v0.1 不承诺把同一个 `Env` 交给多个调用方并发使用 |
| `SessionOptions` | 调用方在创建 `Session` 前持有，用来写入图优化等级、顺序或并行执行、intra-op / inter-op 线程数 | 调用方关闭恰好一次 | 这些数字只描述 ORT 在同步 `Run` 内部如何调度，不表示句柄可跨线程共享 |
| `Session` | 调用方由 `Env` 和模型文件路径创建 | 调用方显式关闭恰好一次。`Run` 不关闭 `Session` | v0.1 不承诺多个调用方并发 `Run` 同一个 `Session` |
| `Tensor` | 输入数据复制进调用方持有的张量。`Run` 返回的输出是调用方新持有的张量 | 调用方关闭恰好一次。`Run` 不关闭调用方仍持有的输入张量；输出由调用方关闭 | v0.1 不承诺跨线程共享张量 |
| 错误 | 值类型，不拥有 ORT 句柄 | 不需要 close | 可按普通 MoonBit 值传递 |

一次同步 `Run` 的顺序：调用方准备好仍由自己持有的输入张量；`Run` 读这些输入并返回新的输出张量；`Run` 返回后输入仍由调用方关闭，输出也由调用方关闭；`Session` 与 `Env` 都保持打开，直到调用方分别关闭它们。

`OrtStatus` 映射为稳定的 MoonBit 错误。调用方能取得错误码、错误消息和 API 名称。除加载错误外，下列情况也返回结构化错误：模型不存在、模型损坏、类型不支持、非法线程参数、输入缺失、重复名称、未知名称、类型不匹配、shape 不兼容、元素数量不匹配、负维度、shape 乘积溢出。

## 7. 三个公开场景

下面三个场景是 v0.1 的公开目标，都不依赖私有资产。基线只有可再生成的夹具文件，没有 MoonBit `Run`。本文不提供运行命令、张量名、shape 或预期数值；这些要等 SDK `Run` 与官方 ORT 对照同时存在后再写。当前没有 SDK `Run` 证据。

夹具由 `testdata/generate_models.py` 生成，生成环境为 `onnx==1.17.0`、opset 13、IR version 9，许可证与本项目同为 MIT。下表 SHA-256 来自已提交的 `testdata/SHA256SUMS`，只证明夹具字节，不证明推理结果。

| 场景 | 夹具 | 夹具 SHA-256 | 目标说明 |
|---|---|---|---|
| 数值特征变换 | `testdata/add_f32.onnx` | `7e1d718adc9faee1a389550e17b038ad0827ebb20dd1d6c632f6542bdb050468` | 单输入单输出 `f32` |
| 双离散特征 / Token 输入 | `testdata/two_inputs_i64.onnx` | `299e6cf24dac9b43b1961bb33f1534a5452be02f0a499fab3f9b206ad6c3f7e0` | 两个 `i64` 输入 |
| 动态 batch 的分数与布尔门控 | `testdata/two_outputs_f32_bool.onnx` 与 `testdata/dynamic_identity_f32.onnx` | `12dd7649d945656fe225134932461a9c4ca412887ac3b03ceda8ad368c39523b`；`794dd006c106b82a851b34d219527489a59c43fe7020d7621a93956e3ebdf432` | `f32` 与 `bool` 两个输出，以及动态 batch |

opset 13 是这批夹具的生成基线，不是 SDK 已验证的算子覆盖范围。

## 8. 公开范围之外

Laya 只属于项目负责人的私有验证。它不是公开场景，不是可用功能，不是 v0.1 的完成条件，也不进入 CI。本文不记录模型 SHA-256、tokenizer 数据或五输入契约。真实输入输出契约在会话元数据导出出现之前保持阻塞；在那之前不得把任何输入个数或输入名称写成模型事实。

`howtomakeaname/tokenizers-moonbit@0.4.0`（Apache-2.0）只是私有验证的候选依赖。上游资产合规之前，不把它写入 `moon.mod`。即便以后合规，它仍然不是本 SDK 的公开能力。

## 9. 与相邻项目的边界

- `tch-mbt` 走 libtorch。`moon-ort` 绑定官方 ONNX Runtime C API，提供 CPU 上的 ONNX 推理句柄，不提供 libtorch 张量或训练接口。
- `mizchi/webnn` 走 WebNN / TFLite，不是 native ONNX Runtime。`moon-ort` 是 native 动态加载，不提供 WebNN、TFLite 或 WASM / JavaScript 后端。

这里只划定路线边界，不描述这两个项目的其余能力。

## 10. 决策记录

v0.1 把边界定在官方 C API、CPU 和三种张量类型，是为了让普通 MoonBit 用户在自备匹配共享库之后做 CPU 推理，同时让验收停留在一个可以测完的集合上。

- 选择 C API 与动态加载：编译期只依赖随包 MIT 头文件，运行期由用户提供 v1.30.0 共享库。静态链接会把二进制分发和平台矩阵绑进包构建。
- 选择 macOS arm64 CPU 作为唯一正式平台：其余操作系统和其他执行提供程序都还没有验收路径。把它们写进支持矩阵会把未验证环境说成已支持。
- 选择 `f32`、`i64`、`bool`：它们分别对应数值特征、离散或 Token 输入、布尔门控这三个公开场景。字符串、稀疏和嵌套 `OrtValue` 不进入首版句柄模型。
- 拒绝薄绑定：完成标准包括句柄所有权、恰好关闭一次、关闭后访问检测、结构化加载错误，以及类型、shape 和字节数检查。只导出若干 C 函数不算完成。

## 11. 许可证

| 对象 | 许可证 | 分发 |
|---|---|---|
| 本项目 | MIT（根 `LICENSE`） | 随仓库与未来的 MoonCakes 包 |
| ONNX Runtime 共享库与 C API | MIT | 共享库不随包分发；头文件按第 3 节随源码分发，SHA-256 待 FFI 提交 |
| `testdata/` 微型 ONNX | MIT，本目录脚本生成，不含第三方权重 | 已在仓库中，可按 `testdata/README.md` 再生 |
| Laya 权重与 tokenizer | 未核实 | 不进入仓库，不进入公开文档的可用能力 |

任何新的第三方源码或模型进入仓库前，先在 `THIRD_PARTY_NOTICES.md` 写明来源、许可证、再分发权限和 SHA-256。该文件归 Coordinator 更新；本文不改写它。

## 12. 故意留下的未核验项

- 头文件 SHA-256 与精确 URL：待 FFI 提交把 `onnxruntime_c_api.h` 放入 `native/vendor/onnxruntime/v1.30.0/` 后再记录。
- 远程加载尖峰与 `native-stub` 尖峰：没有绑定已提交 SHA 的归档。
- SDK `Run`：不存在。三个公开场景没有命令、张量契约或官方 ORT 对照值。
- Laya 真实 I/O：在会话元数据导出出现之前保持阻塞。
