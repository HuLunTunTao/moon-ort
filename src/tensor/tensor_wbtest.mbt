///|
fn bytes_equal(left : Bytes, right : Bytes) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i = 0; i < left.length(); i = i + 1 {
    if left[i] != right[i] {
      return false
    }
  }
  true
}

///|
fn compile_fake_tensor_wbtest() -> String raise Failure {
  let path = "/tmp/moon-ort-sdk-tensor-wbtest.dylib"
  let code = @test_support.compile_fake("fake_tensor", path)
  if code != 0 {
    fail("c compiler failed to build fake_tensor: \{code}")
  }
  path
}

///|
test "tensor constructors use fixed little-endian bytes" {
  let runtime = @raw.Runtime::load(compile_fake_tensor_wbtest())
  let integer = Tensor::from_i64(runtime, [1L], [1L], expected_rank=1)
  assert_true(
    bytes_equal(integer.ort.copy_bytes(), b"\x01\x00\x00\x00\x00\x00\x00\x00"),
  )
  let bools = Tensor::from_bool(runtime, [2L], [true, false], expected_rank=1)
  assert_true(bytes_equal(bools.ort.copy_bytes(), b"\x01\x00"))
  integer.close()
  bools.close()
  runtime.close()
}

///|
test "tensor preserves structured runtime load errors" {
  let missing = "/no/such/libonnxruntime-moon-ort-tensor.dylib"
  try @raw.Runtime::load(missing) catch {
    error =>
      match lift(error, "Tensor::test") {
        Runtime(@raw.MissingLibrary(path, _)) => inspect(path, content=missing)
        other => fail(Show::to_string(other))
      }
  } noraise {
    _ => fail("expected MissingLibrary")
  }
}
