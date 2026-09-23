# 使用推理会话

一次推理由四个对象组成：`Runtime` 负责加载共享库，`SessionOptions` 配置 CPU 会话，
`Session` 持有模型，`Tensor` 持有输入或输出数据。

调用方需要关闭 `Runtime`、`SessionOptions`、`Session`、输入张量和每一个返回的输出张量。
输入张量在 `Session::run` 后仍归调用方所有；输出张量也归调用方所有。

## 最小示例

仓库提供可直接运行的 [add_f32 示例](../examples/add_f32)。它加载
`testdata/add_f32.onnx`，将 `[0.5, -1.5]` 传给输入 `input`，并读取输出 `output`：

```sh
export MOON_ORT_LIBRARY=/path/to/libonnxruntime.1.30.0.dylib
moon run examples/add_f32 -- "$MOON_ORT_LIBRARY" testdata/add_f32.onnx
```

预期输出为：

```text
output=[2, -3.5]
```

## 核心调用顺序

```moonbit
let runtime = @raw.Runtime::load(library_path)
let options = @session.SessionOptions::create(runtime)
let session = @session.Session::create(runtime, options, model_path)
let input = @tensor.Tensor::from_f32(runtime, [2L], [0.5, -1.5])
let outputs = session.run(["input"], [input], ["output"])

let values = outputs[0].read_f32()

outputs[0].close()
input.close()
session.close()
options.close()
runtime.close()
```

`Session::run` 按名称匹配输入和输出。错误的名称、重复输入、缺失输入、元素类型不匹配或固定
维度不匹配会返回 `RunError`。模型的输入输出名称、元素类型和维度可通过 `Session` 的元数据
查询方法读取。

## 配置 CPU 会话

创建 `Session` 前可以设置图优化等级、执行模式与线程数：

```moonbit
options.set_intra_op_threads(2)
options.set_inter_op_threads(1)
options.set_execution_mode(@session.Sequential)
options.set_graph_optimization_level(@session.All)
```

`0` 表示交由 ONNX Runtime 选择默认线程数。配置项只影响 CPU 会话内部的执行方式，不会启用
GPU 或其他执行提供程序。
