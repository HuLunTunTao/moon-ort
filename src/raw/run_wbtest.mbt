///|
fn compile_fake_run() -> String raise Failure {
  let out = "/tmp/moon-ort-ffi-fake_run-\{@test_support.temp_suffix()}.dylib"
  let code = @test_support.compile_fake("fake_run", out)
  if code != 0 {
    fail("c compiler failed to build fake_run: \{code}")
  }
  out
}

///|
/// The failed tensor is not returned by `Value::create_cpu_tensor`. This
/// white-box test passes that null `OrtValue` into `Session::run`.
test "run rejects a null value" {
  let rt = Runtime::load(compile_fake_run())
  let options = SessionOptions::create(rt)
  let session = Session::create(rt, options, "ok.onnx")
  options.close()
  let shape = FixedArray::make(1, 1L)
  let bad = moon_ort_value_create(rt, 99, shape, b"")
  let input_names : FixedArray[String] = ["input"]
  let nulls : FixedArray[Value] = [bad]
  let output_names : FixedArray[String] = ["output"]
  try session.run(input_names, nulls, output_names) catch {
    InvalidArgument(message) => inspect(message, content="input value is null")
    other => fail(Show::to_string(other))
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  session.close()
  rt.close()
}

///|
/// A 1023-byte caller name must not match an ORT name that extends it by one
/// byte after the native 1024-byte scratch buffer silently truncates it.
test "run rejects a prefix of an overlong session input name" {
  let rt = Runtime::load(compile_fake_run())
  let options = SessionOptions::create(rt)
  let session = Session::create(rt, options, "long-input-name.onnx")
  options.close()
  let shape = FixedArray::make(1, 2L)
  let input = Value::create_cpu_tensor(
    rt, dtype_f32, shape, b"\x00\x00\x00\x3f\x00\x00\xc0\xbf",
  )
  let builder = StringBuilder()
  for i = 0; i < 1023; i = i + 1 {
    builder.write_string("x")
  }
  let prefix = builder.to_string()
  let input_names : FixedArray[String] = [prefix]
  let inputs : FixedArray[Value] = [input]
  let output_names : FixedArray[String] = ["output"]
  inspect(session.custom_metadata("alloc_live"), content="0")
  try session.run(input_names, inputs, output_names) catch {
    InvalidArgument(message) => inspect(message, content="name is too long")
    other => fail(Show::to_string(other))
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  // Rejected ORT names must still be freed through the ORT allocator.
  inspect(session.custom_metadata("alloc_live"), content="0")
  input.close()
  session.close()
  rt.close()
}

///|
/// Validate that a run caches the session's names once, even when checking 64
/// caller names against the last of 4096 session names.
test "run name validation reads each session name once" {
  let rt = Runtime::load(compile_fake_run())
  let options = SessionOptions::create(rt)
  let session = Session::create(rt, options, "many-names.onnx")
  options.close()
  let shape = FixedArray::make(1, 2L)
  let input = Value::create_cpu_tensor(
    rt, dtype_f32, shape, b"\x00\x00\x00\x3f\x00\x00\xc0\xbf",
  )
  let input_names : FixedArray[String] = FixedArray::make(64, "input-4095")
  input_names[63] = "missing"
  let inputs : FixedArray[Value] = FixedArray::make(64, input)
  let no_output_names : FixedArray[String] = []
  try session.run(input_names, inputs, no_output_names) catch {
    InvalidArgument(message) =>
      inspect(message, content="input name is not in the session")
    other => fail(Show::to_string(other))
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  inspect(session.custom_metadata("name_getter_calls"), content="4096")
  inspect(session.custom_metadata("alloc_live"), content="0")
  let valid_input_names : FixedArray[String] = ["input-4095"]
  let valid_inputs : FixedArray[Value] = [input]
  let output_names : FixedArray[String] = FixedArray::make(64, "output-4095")
  output_names[63] = "missing"
  try session.run(valid_input_names, valid_inputs, output_names) catch {
    InvalidArgument(message) =>
      inspect(message, content="output name is not in the session")
    other => fail(Show::to_string(other))
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  inspect(session.custom_metadata("name_getter_calls"), content="12288")
  inspect(session.custom_metadata("alloc_live"), content="0")
  input.close()
  session.close()
  rt.close()
}
