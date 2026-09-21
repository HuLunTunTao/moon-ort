///|
/// ONNX element type `float`.
pub let dtype_f32 : Int = 1

///|
/// ONNX element type `int64`.
pub let dtype_i64 : Int = 7

///|
/// ONNX element type `bool`.
pub let dtype_bool : Int = 9

///|
fn Value::guard_open(self : Value, api : String) -> Unit raise OrtError {
  if moon_ort_value_state(self) != 0 {
    raise UseAfterClose(api)
  }
}

///|
fn Value::check(self : Value) -> Unit raise OrtError {
  raise_handle(
    moon_ort_value_code(self),
    moon_ort_value_status_code(self),
    moon_ort_value_message(self),
    moon_ort_value_api_name(self),
  )
}

///|
/// Copy `data` into a CPU tensor. `data` is native-endian and is not borrowed.
///
/// `shape` is a concrete shape: every dimension is non-negative. Rank 0 is a
/// scalar. Supported element types are `dtype_f32`, `dtype_i64`, and `dtype_bool`.
pub fn Value::create_cpu_tensor(
  runtime : Runtime,
  element_type : Int,
  shape : FixedArray[Int64],
  data : Bytes,
) -> Value raise OrtError {
  runtime.guard_open("Value::create_cpu_tensor")
  let value = moon_ort_value_create(runtime, element_type, shape, data)
  value.check()
  value
}

///|
/// Release the tensor exactly once.
pub fn Value::close(self : Value) -> Unit raise OrtError {
  match moon_ort_value_close(self) {
    0 => ()
    5 => raise AlreadyClosed("Value::close")
    _ => raise InvalidArgument(moon_ort_value_message(self))
  }
}

///|
pub fn Value::element_type(self : Value) -> Int raise OrtError {
  self.guard_open("Value::element_type")
  let element = moon_ort_value_element_type(self)
  self.check()
  element
}

///|
pub fn Value::shape(self : Value) -> FixedArray[Int64] raise OrtError {
  self.guard_open("Value::shape")
  let shape = moon_ort_value_shape(self)
  self.check()
  shape
}

///|
pub fn Value::element_count(self : Value) -> Int64 raise OrtError {
  self.guard_open("Value::element_count")
  let count = moon_ort_value_element_count(self)
  self.check()
  count
}

///|
pub fn Value::byte_count(self : Value) -> Int raise OrtError {
  self.guard_open("Value::byte_count")
  let count = moon_ort_value_byte_count(self)
  self.check()
  count
}

///|
/// Copy the tensor bytes out. The returned buffer does not alias ORT memory.
pub fn Value::copy_bytes(self : Value) -> Bytes raise OrtError {
  self.guard_open("Value::copy_bytes")
  let data = moon_ort_value_copy_bytes(self)
  self.check()
  data
}
