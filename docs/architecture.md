# 架构

`moon-ort` 选择 ONNX Runtime C API，而不是在构建期静态链接运行时。这样 MoonBit 包只包含
MoonBit 代码、原生 shim 与必要的 C API 头文件；运行时二进制由应用自行选择和部署。

```text
MoonBit application
        │
        ▼
Session / Tensor API
        │
        ▼
native shim (C API)
        │ dlopen
        ▼
libonnxruntime 1.30.0
```

## 分层

- `src/raw`：动态加载、C ABI 和原始句柄；不向普通调用方暴露指针。
- `src/session`：会话选项、模型元数据和同步推理 API。
- `src/tensor`：`f32`、`i64`、`bool` 稠密 CPU 张量与数据转换。

## 生命周期

`Runtime` 拥有 ONNX Runtime 环境；`SessionOptions` 与 `Session` 在其存活期间使用该环境。
应用关闭对象的顺序应为：输出张量、输入张量、Session、SessionOptions、Runtime。

`Session::run` 会把输入张量转换为临时原始值；调用完成后输入张量仍归调用方所有。每个返回的
输出张量也归调用方所有，必须关闭一次。创建、执行或转换失败时，库会释放已创建的临时原始资源并
以结构化错误返回。

## ABI 约束

v0.1 固定 ONNX Runtime 1.30.0 / C API 30。加载阶段会检查所需符号和 API 版本；不匹配时返回
错误，而不会让异常跨过 C ABI。

设计取舍与完整支持列表见 [支持范围](support.md)。
