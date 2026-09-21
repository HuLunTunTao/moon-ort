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
fn make_shape(dims : Array[Int64]) -> FixedArray[Int64] {
  let shape = FixedArray::make(dims.length(), 0L)
  for i = 0; i < dims.length(); i = i + 1 {
    shape[i] = dims[i]
  }
  shape
}

///|
test "cpu tensors round-trip f32 i64 and bool" {
  let lib = compile_fake("fake_tensor")
  let rt = Runtime::load(lib)
  let f32_data : Bytes = b"\x00\x00\x80\x3f\x00\x00\x00\x40\x00\x00\x40\x40\x00\x00\x80\x40\x00\x00\xa0\x40\x00\x00\xc0\x40"
  let f32_value = Value::create_cpu_tensor(
    rt,
    dtype_f32,
    make_shape([2L, 3L]),
    f32_data,
  )
  inspect(f32_value.element_type(), content="1")
  let f32_shape = f32_value.shape()
  assert_true(
    f32_shape.length() == 2 && f32_shape[0] == 2L && f32_shape[1] == 3L,
  )
  assert_true(f32_value.element_count() == 6L)
  inspect(f32_value.byte_count(), content="24")
  assert_true(bytes_equal(f32_value.copy_bytes(), f32_data))
  f32_value.close()
  let i64_data : Bytes = b"\x01\x00\x00\x00\x00\x00\x00\x00\x02\x00\x00\x00\x00\x00\x00\x00"
  let i64_value = Value::create_cpu_tensor(
    rt,
    dtype_i64,
    make_shape([2L]),
    i64_data,
  )
  assert_true(i64_value.element_type() == dtype_i64)
  assert_true(i64_value.element_count() == 2L)
  assert_true(bytes_equal(i64_value.copy_bytes(), i64_data))
  i64_value.close()
  let bool_data : Bytes = b"\x01\x00\x01"
  let bool_value = Value::create_cpu_tensor(
    rt,
    dtype_bool,
    make_shape([3L]),
    bool_data,
  )
  assert_true(bool_value.element_type() == dtype_bool)
  assert_true(bytes_equal(bool_value.copy_bytes(), bool_data))
  bool_value.close()
  let scalar = Value::create_cpu_tensor(
    rt,
    dtype_f32,
    FixedArray::make(0, 0L),
    b"\x00\x00\x80\x3f",
  )
  assert_true(scalar.shape().length() == 0)
  assert_true(scalar.element_count() == 1L)
  assert_true(scalar.byte_count() == 4)
  scalar.close()
  let empty = Value::create_cpu_tensor(
    rt,
    dtype_f32,
    make_shape([2L, 0L, 3L]),
    b"",
  )
  assert_true(empty.element_count() == 0L)
  assert_true(empty.byte_count() == 0)
  assert_true(empty.copy_bytes().length() == 0)
  let empty_shape = empty.shape()
  assert_true(empty_shape.length() == 3 && empty_shape[1] == 0L)
  empty.close()
  rt.close()
}
