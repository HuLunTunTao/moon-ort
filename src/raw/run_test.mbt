///|
/// gcc-15 fake only. Official ONNX Runtime 1.30.0 was not executed.
/// The bytes are the add_f32 fixture [0.5, -1.5] -> [2.0, -3.5], not a
/// differential result.
let add_f32_input : Bytes = b"\x00\x00\x00\x3f\x00\x00\xc0\xbf"

///|
let add_f32_output : Bytes = b"\x00\x00\x00\x40\x00\x00\x60\xc0"

///|
fn open_fake_run(
  lib : String,
  path : String,
) -> (@raw.Runtime, @raw.Session) raise @raw.OrtError {
  let rt = @raw.Runtime::load(lib)
  let options = @raw.SessionOptions::create(rt)
  let session = @raw.Session::create(rt, options, path)
  options.close()
  (rt, session)
}

///|
test "sync run returns the fake add_f32 vector" {
  let (rt, session) = open_fake_run(compile_fake("fake_run"), "ok.onnx")
  inspect(session.input_name(0), content="input")
  inspect(session.output_name(0), content="output")
  let input = @raw.Value::create_cpu_tensor(
    rt,
    @raw.dtype_f32,
    make_shape([2L]),
    add_f32_input,
  )
  let input_names : FixedArray[String] = [session.input_name(0)]
  let inputs : FixedArray[@raw.Value] = [input]
  let output_names : FixedArray[String] = [session.output_name(0)]
  let outputs = session.run(input_names, inputs, output_names)
  inspect(outputs.length(), content="1")
  let output = outputs[0]
  inspect(output.element_type(), content="1")
  let shape = output.shape()
  assert_true(shape.length() == 1 && shape[0] == 2L)
  assert_true(output.element_count() == 2L)
  assert_true(bytes_equal(output.copy_bytes(), add_f32_output))
  assert_true(bytes_equal(input.copy_bytes(), add_f32_input))
  output.close()
  try output.close() catch {
    AlreadyClosed(api) => inspect(api, content="Value::close")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected AlreadyClosed")
  }
  input.close()
  session.close()
  rt.close()
}

///|
test "run rejects a wrong input or output name" {
  let (rt, session) = open_fake_run(compile_fake("fake_run"), "ok.onnx")
  let input = @raw.Value::create_cpu_tensor(
    rt,
    @raw.dtype_f32,
    make_shape([2L]),
    add_f32_input,
  )
  let inputs : FixedArray[@raw.Value] = [input]
  let output_names : FixedArray[String] = [session.output_name(0)]
  let wrong_input : FixedArray[String] = ["features"]
  try session.run(wrong_input, inputs, output_names) catch {
    InvalidArgument(message) =>
      inspect(message, content="input name is not in the session")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  let input_names : FixedArray[String] = [session.input_name(0)]
  let wrong_output : FixedArray[String] = ["scores"]
  try session.run(input_names, inputs, wrong_output) catch {
    InvalidArgument(message) =>
      inspect(message, content="output name is not in the session")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  input.close()
  session.close()
  rt.close()
}

///|
test "run distinguishes empty names from names outside the session" {
  let (rt, session) = open_fake_run(compile_fake("fake_run"), "ok.onnx")
  let input = @raw.Value::create_cpu_tensor(
    rt,
    @raw.dtype_f32,
    make_shape([2L]),
    add_f32_input,
  )
  let inputs : FixedArray[@raw.Value] = [input]
  let empty_input : FixedArray[String] = [""]
  let empty_output : FixedArray[String] = [""]
  try session.run(empty_input, inputs, ["output"]) catch {
    InvalidArgument(message) => inspect(message, content="input name is empty")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try session.run(["input"], inputs, empty_output) catch {
    InvalidArgument(message) => inspect(message, content="output name is empty")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  input.close()
  session.close()
  rt.close()
}

///|
test "run rejects an input count mismatch" {
  let (rt, session) = open_fake_run(compile_fake("fake_run"), "ok.onnx")
  let input = @raw.Value::create_cpu_tensor(
    rt,
    @raw.dtype_f32,
    make_shape([2L]),
    add_f32_input,
  )
  let input_names : FixedArray[String] = ["input", "input"]
  let inputs : FixedArray[@raw.Value] = [input]
  let output_names : FixedArray[String] = ["output"]
  try session.run(input_names, inputs, output_names) catch {
    InvalidArgument(message) =>
      inspect(message, content="input count does not match values")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  input.close()
  session.close()
  rt.close()
}

///|
test "run rejects a closed session" {
  let (rt, session) = open_fake_run(compile_fake("fake_run"), "ok.onnx")
  let input = @raw.Value::create_cpu_tensor(
    rt,
    @raw.dtype_f32,
    make_shape([2L]),
    add_f32_input,
  )
  let input_names : FixedArray[String] = ["input"]
  let inputs : FixedArray[@raw.Value] = [input]
  let output_names : FixedArray[String] = ["output"]
  session.close()
  try session.run(input_names, inputs, output_names) catch {
    UseAfterClose(api) => inspect(api, content="Session::run")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  input.close()
  rt.close()
}

///|
test "run rejects a closed value" {
  let (rt, session) = open_fake_run(compile_fake("fake_run"), "ok.onnx")
  let input_names : FixedArray[String] = ["input"]
  let output_names : FixedArray[String] = ["output"]
  let input = @raw.Value::create_cpu_tensor(
    rt,
    @raw.dtype_f32,
    make_shape([2L]),
    add_f32_input,
  )
  input.close()
  let closed : FixedArray[@raw.Value] = [input]
  try session.run(input_names, closed, output_names) catch {
    UseAfterClose(api) => inspect(api, content="Session::run")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  session.close()
  rt.close()
}

///|
test "run rejects a value from another runtime" {
  let lib = compile_fake("fake_run")
  let rt = @raw.Runtime::load(lib)
  let options = @raw.SessionOptions::create(rt)
  let session = @raw.Session::create(rt, options, "ok.onnx")
  options.close()
  let other = @raw.Runtime::load(lib)
  let foreign = @raw.Value::create_cpu_tensor(
    other,
    @raw.dtype_f32,
    make_shape([2L]),
    add_f32_input,
  )
  let input_names : FixedArray[String] = ["input"]
  let inputs : FixedArray[@raw.Value] = [foreign]
  let output_names : FixedArray[String] = ["output"]
  try session.run(input_names, inputs, output_names) catch {
    InvalidArgument(message) =>
      inspect(message, content="input value belongs to a different runtime")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  foreign.close()
  other.close()
  session.close()
  rt.close()
}

///|
test "failed run releases outputs created before failure" {
  let (rt, session) = open_fake_run(compile_fake("fake_run"), "fail-run.onnx")
  let input = @raw.Value::create_cpu_tensor(
    rt,
    @raw.dtype_f32,
    make_shape([2L]),
    add_f32_input,
  )
  let input_names : FixedArray[String] = [session.input_name(0)]
  let inputs : FixedArray[@raw.Value] = [input]
  let output_names : FixedArray[String] = [session.output_name(0)]
  try session.run(input_names, inputs, output_names) catch {
    Status(code, message, api) => {
      inspect(code, content="1")
      inspect(api, content="Run")
      inspect(message, content="run failed after output")
    }
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected Status")
  }
  inspect(session.custom_metadata("status_live"), content="0")
  inspect(session.custom_metadata("orphan_live"), content="0")
  assert_true(bytes_equal(input.copy_bytes(), add_f32_input))
  inspect(session.input_count(), content="1")
  input.close()
  session.close()
  rt.close()
}

///|
/// The fake allocates both requested outputs before returning failure. The raw
/// shim must release the entire partially populated output array.
test "multi-output failure releases every orphaned output" {
  let (rt, session) = open_fake_run(
    compile_fake("fake_run"),
    "multi-fail-run.onnx",
  )
  let input = @raw.Value::create_cpu_tensor(
    rt,
    @raw.dtype_f32,
    make_shape([2L]),
    add_f32_input,
  )
  let second_input = @raw.Value::create_cpu_tensor(
    rt,
    @raw.dtype_f32,
    make_shape([2L]),
    add_f32_input,
  )
  inspect(session.input_count(), content="2")
  inspect(session.output_count(), content="2")
  let input_names : FixedArray[String] = ["input", "second_input"]
  let inputs : FixedArray[@raw.Value] = [input, second_input]
  let output_names : FixedArray[String] = ["output", "second_output"]
  try session.run(input_names, inputs, output_names) catch {
    Status(code, message, api) => {
      inspect(code, content="1")
      inspect(api, content="Run")
      inspect(message, content="run failed after output")
    }
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected Status")
  }
  inspect(session.custom_metadata("status_live"), content="0")
  inspect(session.custom_metadata("orphan_live"), content="0")
  assert_true(bytes_equal(input.copy_bytes(), add_f32_input))
  assert_true(bytes_equal(second_input.copy_bytes(), add_f32_input))
  input.close()
  second_input.close()
  session.close()
  rt.close()
}

///|
/// Fake-only seam test: Run transports a rank-0 tensor through the raw API.
/// The fake echoes a fixed scalar and does not validate ONNX graph execution.
test "sync run preserves a scalar tensor shape and payload" {
  let (rt, session) = open_fake_run(compile_fake("fake_run"), "scalar-run.onnx")
  let scalar_bytes : Bytes = b"\x00\x00\x50\x40"
  let input = @raw.Value::create_cpu_tensor(
    rt,
    @raw.dtype_f32,
    make_shape([]),
    scalar_bytes,
  )
  let outputs = session.run([session.input_name(0)], [input], [
    session.output_name(0),
  ])
  let output = outputs[0]
  inspect(output.shape().length(), content="0")
  inspect(output.element_count(), content="1")
  assert_true(bytes_equal(output.copy_bytes(), scalar_bytes))
  input.close()
  output.close()
  session.close()
  rt.close()
}
