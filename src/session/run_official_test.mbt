///|
fn format_f32(values : Array[Float]) -> String {
  let builder = StringBuilder()
  builder.write_string("[")
  for i = 0; i < values.length(); i = i + 1 {
    if i > 0 {
      builder.write_string(", ")
    }
    builder.write_string(values[i].to_string())
  }
  builder.write_string("]")
  builder.to_string()
}

///|
fn format_i64(values : Array[Int64]) -> String {
  let builder = StringBuilder()
  builder.write_string("[")
  for i = 0; i < values.length(); i = i + 1 {
    if i > 0 {
      builder.write_string(", ")
    }
    builder.write_string(values[i].to_string())
  }
  builder.write_string("]")
  builder.to_string()
}

///|
fn format_bool(values : Array[Bool]) -> String {
  let builder = StringBuilder()
  builder.write_string("[")
  for i = 0; i < values.length(); i = i + 1 {
    if i > 0 {
      builder.write_string(", ")
    }
    builder.write_string(if values[i] { "true" } else { "false" })
  }
  builder.write_string("]")
  builder.to_string()
}

///|
/// `None` means this process is not pointing at official libonnxruntime 1.30.0.
fn official_runtime() -> @raw.Runtime? raise @raw.OrtError {
  match @session.configured_library() {
    None => {
      println(
        "skip: MOON_ORT_LIBRARY is not set; official libonnxruntime 1.30.0 was not run",
      )
      None
    }
    Some(path) => {
      let runtime = @raw.Runtime::load(path) catch {
        error => {
          println(
            "skip: MOON_ORT_LIBRARY did not load as official libonnxruntime 1.30.0; \{error}",
          )
          return None
        }
      }
      let version = runtime.version() catch {
        error => {
          runtime.close() catch {
            _ => ()
          }
          println(
            "skip: MOON_ORT_LIBRARY did not report official libonnxruntime 1.30.0; \{error}",
          )
          return None
        }
      }
      let api = runtime.api_version() catch {
        error => {
          runtime.close() catch {
            _ => ()
          }
          println(
            "skip: MOON_ORT_LIBRARY did not report official API 30; \{error}",
          )
          return None
        }
      }
      if version != "1.30.0" || api != 30 {
        println(
          "skip: MOON_ORT_LIBRARY version=\{version} api=\{api} is not official libonnxruntime 1.30.0",
        )
        runtime.close()
        return None
      }
      Some(runtime)
    }
  }
}

///|
fn close_outputs(
  outputs : Array[@tensor.Tensor],
) -> Unit raise @tensor.TensorError {
  for i = 0; i < outputs.length(); i = i + 1 {
    outputs[i].close()
  }
}

///|
/// Expected values are the tools/reference fixtures at rtol=0 atol=0.
/// This test skips unless MOON_ORT_LIBRARY is official libonnxruntime 1.30.0.
test "official libonnxruntime 1.30.0 matches tracked fixture outputs" {
  match official_runtime() {
    None => ()
    Some(rt) => {
      let options = @session.SessionOptions::create(rt)
      options.set_intra_op_threads(1)
      options.set_inter_op_threads(1)
      options.set_execution_mode(Sequential)
      options.set_graph_optimization_level(All)
      let add = @session.Session::create(rt, options, "testdata/add_f32.onnx")
      let add_input = @tensor.Tensor::from_f32(rt, [2L], [0.5, -1.5])
      let add_out = add.run(["input"], [add_input], ["output"])
      let add_values = add_out[0].read_f32()
      println(
        "add_f32 input=[0.5, -1.5] output=\{format_f32(add_values)} reference=[2.0, -3.5]",
      )
      assert_f32(add_values, [2.0, -3.5])
      assert_shape(add_out[0].shape(), [2L])
      close_outputs(add_out)
      add_input.close()
      add.close()
      let sum_session = @session.Session::create(
        rt, options, "testdata/two_inputs_i64.onnx",
      )
      let left = @tensor.Tensor::from_i64(rt, [2L], [-5L, -3L])
      let right = @tensor.Tensor::from_i64(rt, [2L], [-3L, -1L])
      let sum_out = sum_session.run(["left", "right"], [left, right], ["sum"])
      let sum_values = sum_out[0].read_i64()
      println(
        "two_inputs_i64 input=[-5, -3]+[-3, -1] output=\{format_i64(sum_values)} reference=[-8, -4]",
      )
      assert_i64(sum_values, [-8L, -4L])
      close_outputs(sum_out)
      left.close()
      right.close()
      sum_session.close()
      let gate = @session.Session::create(
        rt, options, "testdata/two_outputs_f32_bool.onnx",
      )
      let scores = @tensor.Tensor::from_f32(rt, [2L], [-1.5, 0.25])
      let gate_out = gate.run(["scores"], [scores], ["shifted", "positive"])
      let shifted = gate_out[0].read_f32()
      let positive = gate_out[1].read_bool()
      println(
        "two_outputs_f32_bool input=[-1.5, 0.25] shifted=\{format_f32(shifted)} reference=[-0.5, 1.25] positive=\{format_bool(positive)} reference=[false, true]",
      )
      assert_f32(shifted, [-0.5, 1.25])
      assert_bool(positive, [false, true])
      close_outputs(gate_out)
      scores.close()
      gate.close()
      let dynamic = @session.Session::create(
        rt, options, "testdata/dynamic_identity_f32.onnx",
      )
      let batch1 = @tensor.Tensor::from_f32(rt, [1L, 2L], [1.0, -2.0])
      let batch1_out = dynamic.run(["input"], [batch1], ["output"])
      let batch1_values = batch1_out[0].read_f32()
      println(
        "dynamic_identity_f32 batch1 input=[[1.0, -2.0]] output=\{format_f32(batch1_values)} reference=[1.0, -2.0]",
      )
      assert_shape(batch1_out[0].shape(), [1L, 2L])
      assert_f32(batch1_values, [1.0, -2.0])
      close_outputs(batch1_out)
      batch1.close()
      let batch3 = @tensor.Tensor::from_f32(rt, [3L, 2L], [
        2.0, 0.0, -0.5, 2.0, 2.0, -1.5,
      ])
      let batch3_out = dynamic.run(["input"], [batch3], ["output"])
      let batch3_values = batch3_out[0].read_f32()
      println(
        "dynamic_identity_f32 batch3 input=[[2.0, 0.0], [-0.5, 2.0], [2.0, -1.5]] output=\{format_f32(batch3_values)} reference=[2.0, 0.0, -0.5, 2.0, 2.0, -1.5]",
      )
      assert_shape(batch3_out[0].shape(), [3L, 2L])
      assert_f32(batch3_values, [2.0, 0.0, -0.5, 2.0, 2.0, -1.5])
      close_outputs(batch3_out)
      batch3.close()
      dynamic.close()
      options.close()
      rt.close()
    }
  }
}
