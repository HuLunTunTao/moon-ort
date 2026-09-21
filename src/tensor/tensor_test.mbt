///|
/// Build the raw fake OrtValue library. This is not official ONNX Runtime.
#borrow(command)
extern "C" fn host_system(command : String) -> Int = "moon_ort_host_system"

///|
fn compile_fake_tensor() -> String raise Failure {
  let out = "/tmp/moon-ort-sdk-tensor-fake_tensor.dylib"
  let code = host_system(
    "gcc-15 -Wall -Wextra -Werror -shared -fPIC -I native/vendor/onnxruntime/v1.30.0 -o \{out} native/support/fake_tensor.c",
  )
  if code != 0 {
    fail("gcc-15 failed to build fake_tensor: \{code}")
  }
  out
}

///|
fn assert_f32(
  actual : Array[Float],
  expected : Array[Float],
) -> Unit raise Failure {
  if actual.length() != expected.length() {
    fail("f32 length \{actual.length()} != \{expected.length()}")
  }
  for i = 0; i < actual.length(); i = i + 1 {
    if actual[i] != expected[i] {
      fail("f32 index \{i}")
    }
  }
}

///|
fn assert_i64(
  actual : Array[Int64],
  expected : Array[Int64],
) -> Unit raise Failure {
  if actual.length() != expected.length() {
    fail("i64 length \{actual.length()} != \{expected.length()}")
  }
  for i = 0; i < actual.length(); i = i + 1 {
    if actual[i] != expected[i] {
      fail("i64 index \{i}")
    }
  }
}

///|
fn assert_bool(
  actual : Array[Bool],
  expected : Array[Bool],
) -> Unit raise Failure {
  if actual.length() != expected.length() {
    fail("bool length \{actual.length()} != \{expected.length()}")
  }
  for i = 0; i < actual.length(); i = i + 1 {
    if actual[i] != expected[i] {
      fail("bool index \{i}")
    }
  }
}

///|
fn assert_shape(
  actual : Array[Int64],
  expected : Array[Int64],
) -> Unit raise Failure {
  if actual.length() != expected.length() {
    fail("shape length \{actual.length()} != \{expected.length()}")
  }
  for i = 0; i < actual.length(); i = i + 1 {
    if actual[i] != expected[i] {
      fail("shape index \{i}")
    }
  }
}

///|
fn expect_invalid(
  action : () -> Tensor raise TensorError,
  message : String,
) -> Unit raise Failure {
  try action() catch {
    InvalidArgument(actual) => if actual != message { fail(actual) }
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
}

///|
/// Fixture numbers from testdata/cases/manifest.json. Stored and read back
/// only; this does not run the ONNX graphs and does not load libonnxruntime.
test "fixture f32 i64 and bool values round-trip" {
  let rt = @raw.Runtime::load(compile_fake_tensor())
  let input : Array[Float] = [0.5, -1.5]
  let input_shape = [2L]
  let add_input = Tensor::from_f32(rt, input_shape, input, expected_rank=1)
  inspect(add_input.dtype(), content="f32")
  inspect(add_input.rank(), content="1")
  inspect(add_input.element_count(), content="2")
  inspect(add_input.byte_count(), content="8")
  assert_shape(add_input.shape(), [2L])
  assert_f32(add_input.read_f32(), [0.5, -1.5])
  input[0] = 9.0
  input_shape[0] = 9L
  assert_f32(add_input.read_f32(), [0.5, -1.5])
  assert_shape(add_input.shape(), [2L])
  let add_output = Tensor::from_f32(rt, [2L], [2.0, -3.5], expected_rank=1)
  assert_f32(add_output.read_f32(), [2.0, -3.5])
  let left = Tensor::from_i64(rt, [2L], [-5L, -3L], expected_rank=1)
  let right = Tensor::from_i64(rt, [2L], [-3L, -1L], expected_rank=1)
  let sum = Tensor::from_i64(rt, [2L], [-8L, -4L], expected_rank=1)
  assert_i64(left.read_i64(), [-5L, -3L])
  assert_i64(right.read_i64(), [-3L, -1L])
  assert_i64(sum.read_i64(), [-8L, -4L])
  inspect(left.byte_count(), content="16")
  let scores = Tensor::from_f32(rt, [2L], [-1.5, 0.25], expected_rank=1)
  let shifted = Tensor::from_f32(rt, [2L], [-0.5, 1.25], expected_rank=1)
  let positive = Tensor::from_bool(rt, [2L], [false, true], expected_rank=1)
  assert_f32(scores.read_f32(), [-1.5, 0.25])
  assert_f32(shifted.read_f32(), [-0.5, 1.25])
  assert_bool(positive.read_bool(), [false, true])
  inspect(positive.dtype(), content="bool")
  inspect(positive.byte_count(), content="2")
  let batch1 = Tensor::from_f32(rt, [1L, 2L], [1.0, -2.0], expected_rank=2)
  let batch3 = Tensor::from_f32(
    rt,
    [3L, 2L],
    [2.0, 0.0, -0.5, 2.0, 2.0, -1.5],
    expected_rank=2,
  )
  assert_shape(batch1.shape(), [1L, 2L])
  assert_f32(batch1.read_f32(), [1.0, -2.0])
  assert_shape(batch3.shape(), [3L, 2L])
  assert_f32(batch3.read_f32(), [2.0, 0.0, -0.5, 2.0, 2.0, -1.5])
  inspect(batch3.element_count(), content="6")
  inspect(batch3.byte_count(), content="24")
  add_input.close()
  add_output.close()
  left.close()
  right.close()
  sum.close()
  scores.close()
  shifted.close()
  positive.close()
  batch1.close()
  batch3.close()
  rt.close()
}

///|
test "scalar f32 and a zero dimension use the runtime shape" {
  let rt = @raw.Runtime::load(compile_fake_tensor())
  let scalar = Tensor::from_f32(rt, [], [0.5])
  inspect(scalar.rank(), content="0")
  inspect(scalar.element_count(), content="1")
  inspect(scalar.byte_count(), content="4")
  assert_shape(scalar.shape(), [])
  assert_f32(scalar.read_f32(), [0.5])
  let ranked = Tensor::from_f32(rt, [], [0.5], expected_rank=0)
  assert_f32(ranked.read_f32(), [0.5])
  let empty = Tensor::from_f32(rt, [2L, 0L, 3L], [], expected_rank=3)
  inspect(empty.element_count(), content="0")
  inspect(empty.byte_count(), content="0")
  assert_shape(empty.shape(), [2L, 0L, 3L])
  assert_f32(empty.read_f32(), [])
  let vector = Tensor::from_f32(rt, [2L], [0.5, -1.5])
  inspect(vector.rank(), content="1")
  scalar.close()
  ranked.close()
  empty.close()
  vector.close()
  rt.close()
}

///|
test "wrong rank empty shape byte count and dtype are structured errors" {
  let rt = @raw.Runtime::load(compile_fake_tensor())
  rt.close()
  let one : Array[Float] = [0.0]
  let pair : Array[Float] = [0.0, 0.0]
  expect_invalid(
    () => Tensor::from_f32(rt, [2L], pair, expected_rank=2),
    "tensor rank does not match",
  )
  expect_invalid(
    () => Tensor::from_f32(rt, [], one, expected_rank=1),
    "tensor shape is empty",
  )
  expect_invalid(
    () => Tensor::from_f32(rt, [2L], one, expected_rank=1),
    "tensor byte count does not match data",
  )
  expect_invalid(
    () => Tensor::from_i64(rt, [-1L], [], expected_rank=1),
    "tensor dimension is negative",
  )
  expect_invalid(
    () => Tensor::from_i64(rt, [3037000500L, 3037000500L], [], expected_rank=2),
    "tensor shape product overflows",
  )
  expect_invalid(
    () => Tensor::from_f32(rt, [536870912L], [], expected_rank=1),
    "tensor byte count overflows",
  )
  expect_invalid(
    () => Tensor::from_bool(rt, Array::make(65, 0L), [], expected_rank=65),
    "tensor rank exceeds 64",
  )
  expect_invalid(
    () => Tensor::from_f32(rt, [1L], one, expected_rank=-1),
    "tensor rank is negative",
  )
}

///|
test "tensor close is once and later use fails" {
  let rt = @raw.Runtime::load(compile_fake_tensor())
  let tensor = Tensor::from_i64(rt, [2L], [-5L, -3L], expected_rank=1)
  try tensor.read_f32() catch {
    InvalidArgument(message) =>
      inspect(message, content="tensor element type does not match")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try rt.close() catch {
    @raw.InvalidArgument(message) =>
      inspect(message, content="runtime has open handles")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  assert_i64(tensor.read_i64(), [-5L, -3L])
  tensor.close()
  try tensor.read_i64() catch {
    UseAfterClose(api) => inspect(api, content="Tensor::read_i64")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  try tensor.shape() catch {
    UseAfterClose(api) => inspect(api, content="Tensor::shape")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  try tensor.dtype() catch {
    UseAfterClose(api) => inspect(api, content="Tensor::dtype")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  try tensor.rank() catch {
    UseAfterClose(api) => inspect(api, content="Tensor::rank")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  try tensor.element_count() catch {
    UseAfterClose(api) => inspect(api, content="Tensor::element_count")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  try tensor.byte_count() catch {
    UseAfterClose(api) => inspect(api, content="Tensor::byte_count")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  try tensor.close() catch {
    AlreadyClosed(api) => inspect(api, content="Tensor::close")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected AlreadyClosed")
  }
  rt.close()
}
