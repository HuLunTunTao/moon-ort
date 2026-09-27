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
/// Fail if a configured library is not the pinned official runtime.
fn load_official_runtime(path : String) -> @raw.Runtime raise Failure {
  let runtime = @raw.Runtime::load(path) catch {
    error => fail("MOON_ORT_LIBRARY could not be loaded: \{error}")
  }
  let version = runtime.version() catch {
    error => {
      runtime.close() catch {
        _ => ()
      }
      fail("MOON_ORT_LIBRARY version could not be read: \{error}")
    }
  }
  let api = runtime.api_version() catch {
    error => {
      runtime.close() catch {
        _ => ()
      }
      fail("MOON_ORT_LIBRARY API version could not be read: \{error}")
    }
  }
  if version != "1.30.0" || api != 30 {
    runtime.close() catch {
      _ => ()
    }
    fail(
      "MOON_ORT_LIBRARY version=\{version} api=\{api}; expected version=1.30.0 api=30",
    )
  }
  runtime
}

///|
/// `None` means MOON_ORT_LIBRARY was not configured; configured libraries must pass validation.
fn official_runtime() -> @raw.Runtime? raise Failure {
  match @session.configured_library() {
    None => {
      println(
        "skip: MOON_ORT_LIBRARY is not set; official libonnxruntime 1.30.0 was not run",
      )
      None
    }
    Some(path) => Some(load_official_runtime(path))
  }
}

///|
fn compile_fake_official(name : String) -> String raise Failure {
  let path = "/tmp/moon-ort-official-\{name}.dylib"
  let code = @test_support.compile_fake(name, path)
  if code != 0 {
    fail("c compiler failed to build \{name}: \{code}")
  }
  path
}

///|
test "configured missing official runtime fails instead of skipping" {
  try load_official_runtime("/no/such/libonnxruntime-moon-ort.dylib") catch {
    Failure(message) => assert_true(message.contains("could not be loaded"))
  } noraise {
    _ => fail("expected configured library load to fail")
  }
}

///|
test "configured library without ORT symbols fails instead of skipping" {
  let path = compile_fake_official("fake_no_symbol")
  try load_official_runtime(path) catch {
    Failure(message) => assert_true(message.contains("could not be loaded"))
  } noraise {
    runtime => {
      runtime.close()
      fail("expected library without ORT symbols to fail")
    }
  }
}

///|
test "configured non-official runtime version fails instead of skipping" {
  let path = compile_fake_official("fake_env")
  try load_official_runtime(path) catch {
    Failure(message) => {
      assert_true(message.contains("fake-env-1.30.0"))
      assert_true(message.contains("expected version=1.30.0 api=30"))
    }
  } noraise {
    runtime => {
      runtime.close()
      fail("expected non-official runtime version to fail")
    }
  }
}

///|
test "configured runtime API mismatch fails instead of skipping" {
  let path = compile_fake_official("fake_api_mismatch")
  try load_official_runtime(path) catch {
    Failure(message) => assert_true(message.contains("could not be loaded"))
  } noraise {
    runtime => {
      runtime.close()
      fail("expected API mismatch to fail")
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
      let add_input_values = official_fixture_add_f32_input_data()
      let add_input = @tensor.Tensor::from_f32(
        rt,
        official_fixture_add_f32_input_shape(),
        add_input_values,
      )
      let add_out = add.run(["input"], [add_input], ["output"])
      let add_values = add_out[0].read_f32()
      println(
        "add_f32 input=\{format_f32(add_input_values)} output=\{format_f32(add_values)} reference=\{format_f32(official_fixture_add_f32_output_data())}",
      )
      assert_f32(add_values, official_fixture_add_f32_output_data())
      assert_shape(add_out[0].shape(), official_fixture_add_f32_output_shape())
      close_outputs(add_out)
      add_input.close()
      add.close()
      let sum_session = @session.Session::create(
        rt, options, "testdata/two_inputs_i64.onnx",
      )
      let left_values = official_fixture_two_inputs_i64_left_data()
      let right_values = official_fixture_two_inputs_i64_right_data()
      let left = @tensor.Tensor::from_i64(
        rt,
        official_fixture_two_inputs_i64_left_shape(),
        left_values,
      )
      let right = @tensor.Tensor::from_i64(
        rt,
        official_fixture_two_inputs_i64_right_shape(),
        right_values,
      )
      let sum_out = sum_session.run(["left", "right"], [left, right], ["sum"])
      let sum_values = sum_out[0].read_i64()
      println(
        "two_inputs_i64 input=\{format_i64(left_values)}+\{format_i64(right_values)} output=\{format_i64(sum_values)} reference=\{format_i64(official_fixture_two_inputs_i64_sum_data())}",
      )
      assert_i64(sum_values, official_fixture_two_inputs_i64_sum_data())
      assert_shape(
        sum_out[0].shape(),
        official_fixture_two_inputs_i64_sum_shape(),
      )
      close_outputs(sum_out)
      left.close()
      right.close()
      sum_session.close()
      let gate = @session.Session::create(
        rt, options, "testdata/two_outputs_f32_bool.onnx",
      )
      let scores_values = official_fixture_two_outputs_f32_bool_scores_data()
      let scores = @tensor.Tensor::from_f32(
        rt,
        official_fixture_two_outputs_f32_bool_scores_shape(),
        scores_values,
      )
      let gate_out = gate.run(["scores"], [scores], ["shifted", "positive"])
      let shifted = gate_out[0].read_f32()
      let positive = gate_out[1].read_bool()
      println(
        "two_outputs_f32_bool input=\{format_f32(scores_values)} shifted=\{format_f32(shifted)} reference=\{format_f32(official_fixture_two_outputs_f32_bool_shifted_data())} positive=\{format_bool(positive)} reference=\{format_bool(official_fixture_two_outputs_f32_bool_positive_data())}",
      )
      assert_f32(shifted, official_fixture_two_outputs_f32_bool_shifted_data())
      assert_bool(
        positive,
        official_fixture_two_outputs_f32_bool_positive_data(),
      )
      assert_shape(
        gate_out[0].shape(),
        official_fixture_two_outputs_f32_bool_shifted_shape(),
      )
      assert_shape(
        gate_out[1].shape(),
        official_fixture_two_outputs_f32_bool_positive_shape(),
      )
      close_outputs(gate_out)
      scores.close()
      gate.close()
      let dynamic = @session.Session::create(
        rt, options, "testdata/dynamic_identity_f32.onnx",
      )
      let batch1_input_values = official_fixture_dynamic_identity_f32_batch1_input_data()
      let batch1 = @tensor.Tensor::from_f32(
        rt,
        official_fixture_dynamic_identity_f32_batch1_input_shape(),
        batch1_input_values,
      )
      let batch1_out = dynamic.run(["input"], [batch1], ["output"])
      let batch1_values = batch1_out[0].read_f32()
      println(
        "dynamic_identity_f32 batch1 output=\{format_f32(batch1_values)} reference=\{format_f32(official_fixture_dynamic_identity_f32_batch1_output_data())}",
      )
      assert_shape(
        batch1_out[0].shape(),
        official_fixture_dynamic_identity_f32_batch1_output_shape(),
      )
      assert_f32(
        batch1_values,
        official_fixture_dynamic_identity_f32_batch1_output_data(),
      )
      close_outputs(batch1_out)
      batch1.close()
      let batch3_input_values = official_fixture_dynamic_identity_f32_batch3_input_data()
      let batch3 = @tensor.Tensor::from_f32(
        rt,
        official_fixture_dynamic_identity_f32_batch3_input_shape(),
        batch3_input_values,
      )
      let batch3_out = dynamic.run(["input"], [batch3], ["output"])
      let batch3_values = batch3_out[0].read_f32()
      println(
        "dynamic_identity_f32 batch3 output=\{format_f32(batch3_values)} reference=\{format_f32(official_fixture_dynamic_identity_f32_batch3_output_data())}",
      )
      assert_shape(
        batch3_out[0].shape(),
        official_fixture_dynamic_identity_f32_batch3_output_shape(),
      )
      assert_f32(
        batch3_values,
        official_fixture_dynamic_identity_f32_batch3_output_data(),
      )
      close_outputs(batch3_out)
      batch3.close()
      dynamic.close()
      options.close()
      rt.close()
    }
  }
}

///|
/// The fake libraries cannot validate protobuf rejection by ONNX Runtime.
test "official runtime rejects corrupt model without crashing" {
  match official_runtime() {
    None => ()
    Some(rt) => {
      let options = @session.SessionOptions::create(rt)
      try
        @session.Session::create(
          rt, options, "testdata/negative/invalid_model.onnx",
        )
      catch {
        @raw.Status(code, message, api) => {
          assert_true(code != 0)
          assert_true(message.length() > 0)
          inspect(api, content="CreateSession")
        }
        error => fail("invalid model returned unexpected error: \{error}")
      } noraise {
        session => {
          session.close()
          fail("invalid protobuf model unexpectedly loaded")
        }
      }
      // A rejected model must not poison the environment or abort the process.
      inspect(rt.version(), content="1.30.0")
      options.close()
      rt.close()
    }
  }
}
