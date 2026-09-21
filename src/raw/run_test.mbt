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
) -> (Runtime, Session) raise OrtError {
  let rt = Runtime::load(lib)
  let options = SessionOptions::create(rt)
  let session = Session::create(rt, options, path)
  options.close()
  (rt, session)
}

///|
test "sync run returns the fake add_f32 vector" {
  let (rt, session) = open_fake_run(compile_fake("fake_run"), "ok.onnx")
  inspect(session.input_name(0), content="input")
  inspect(session.output_name(0), content="output")
  let input = Value::create_cpu_tensor(
    rt,
    dtype_f32,
    make_shape([2L]),
    add_f32_input,
  )
  let input_names : FixedArray[String] = [session.input_name(0)]
  let inputs : FixedArray[Value] = [input]
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
  let input = Value::create_cpu_tensor(
    rt,
    dtype_f32,
    make_shape([2L]),
    add_f32_input,
  )
  let inputs : FixedArray[Value] = [input]
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
test "run rejects an input count mismatch" {
  let (rt, session) = open_fake_run(compile_fake("fake_run"), "ok.onnx")
  let input = Value::create_cpu_tensor(
    rt,
    dtype_f32,
    make_shape([2L]),
    add_f32_input,
  )
  let input_names : FixedArray[String] = ["input", "input"]
  let inputs : FixedArray[Value] = [input]
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
  let input = Value::create_cpu_tensor(
    rt,
    dtype_f32,
    make_shape([2L]),
    add_f32_input,
  )
  let input_names : FixedArray[String] = ["input"]
  let inputs : FixedArray[Value] = [input]
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
  let input = Value::create_cpu_tensor(
    rt,
    dtype_f32,
    make_shape([2L]),
    add_f32_input,
  )
  input.close()
  let closed : FixedArray[Value] = [input]
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
  let rt = Runtime::load(lib)
  let options = SessionOptions::create(rt)
  let session = Session::create(rt, options, "ok.onnx")
  options.close()
  let other = Runtime::load(lib)
  let foreign = Value::create_cpu_tensor(
    other,
    dtype_f32,
    make_shape([2L]),
    add_f32_input,
  )
  let input_names : FixedArray[String] = ["input"]
  let inputs : FixedArray[Value] = [foreign]
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
  let input = Value::create_cpu_tensor(
    rt,
    dtype_f32,
    make_shape([2L]),
    add_f32_input,
  )
  let input_names : FixedArray[String] = [session.input_name(0)]
  let inputs : FixedArray[Value] = [input]
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
