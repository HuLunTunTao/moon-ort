///|
#borrow(command)
extern "C" fn host_system(command : String) -> Int = "moon_ort_host_system"

///|
fn compile_fake_run() -> String raise Failure {
  let out = "/tmp/moon-ort-ffi-fake_run.dylib"
  let code = host_system(
    "sh native/support/cc_compile.sh \{out} native/support/fake_run.c",
  )
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
