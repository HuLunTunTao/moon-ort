///|
/// Element type of a dense CPU tensor.
///
/// The numeric codes match ONNX `float`, `int64`, and `bool`.
pub enum DType {
  F32
  I64
  Bool
}

///|
pub impl Show for DType with fn output(self, logger) {
  logger.write_string(
    match self {
      F32 => "f32"
      I64 => "i64"
      Bool => "bool"
    },
  )
}

///|
fn DType::code(self : DType) -> Int {
  match self {
    F32 => @raw.dtype_f32
    I64 => @raw.dtype_i64
    Bool => @raw.dtype_bool
  }
}

///|
fn DType::width(self : DType) -> Int {
  match self {
    F32 => 4
    I64 => 8
    Bool => 1
  }
}

///|
fn DType::same(self : DType, other : DType) -> Bool {
  match (self, other) {
    (F32, F32) | (I64, I64) | (Bool, Bool) => true
    _ => false
  }
}

///|
/// Owned dense CPU tensor.
///
/// The `OrtValue` pointer stays inside `src/raw`. Callers pass MoonBit arrays;
/// this value copies them and closes the underlying tensor exactly once.
pub struct Tensor {
  priv ort : @raw.Value
  priv kind : DType
  priv dims : Array[Int64]
  priv count : Int64
  priv nbytes : Int
  priv closed : Ref[Bool]
}

///|
/// Structured tensor failure.
///
/// `Runtime` preserves structured dynamic-loading failures from `src/raw`.
/// Other raw failures are mapped into tensor-specific variants. The `api`
/// string is the tensor method the caller used.
pub suberror TensorError {
  Runtime(@raw.OrtError)
  Status(Int, String, String)
  AlreadyClosed(String)
  UseAfterClose(String)
  InvalidArgument(String)
}

///|
pub impl Show for TensorError with fn output(self, logger) {
  match self {
    Runtime(error) => logger.write_string(error.to_string())
    Status(code, message, api) =>
      logger.write_string(
        "ort status; api=\{api}; code=\{code}; message=\{message}",
      )
    AlreadyClosed(api) => logger.write_string("already closed; api=\{api}")
    UseAfterClose(api) => logger.write_string("use after close; api=\{api}")
    InvalidArgument(message) =>
      logger.write_string("invalid argument; message=\{message}")
  }
}

///|
fn lift(error : @raw.OrtError, api : String) -> TensorError {
  match error {
    @raw.UseAfterClose(_) => UseAfterClose(api)
    @raw.AlreadyClosed(_) => AlreadyClosed(api)
    @raw.InvalidArgument(message) => InvalidArgument(message)
    @raw.Status(code, message, status_api) => Status(code, message, status_api)
    @raw.MissingLibrary(_, _)
    | @raw.SymbolNotFound(_, _)
    | @raw.ApiMismatch(_, _, _, _) => Runtime(error)
  }
}

///|
fn release_value(value : @raw.Value) -> Unit {
  value.close() catch {
    _ => ()
  }
}

///|
fn shape_fixed(shape : Array[Int64]) -> FixedArray[Int64] {
  let fixed = FixedArray::make(shape.length(), 0L)
  for i = 0; i < shape.length(); i = i + 1 {
    fixed[i] = shape[i]
  }
  fixed
}

///|
fn shape_agrees(expected : Array[Int64], actual : FixedArray[Int64]) -> Bool {
  if expected.length() != actual.length() {
    return false
  }
  for i = 0; i < expected.length(); i = i + 1 {
    if expected[i] != actual[i] {
      return false
    }
  }
  true
}

///|
/// Check rank, dimensions, and byte count before any C call.
///
/// Rank 0 is a scalar. A dimension may be zero. `expected_rank`, when set,
/// must equal `shape.length()`; an empty shape is rejected when that rank
/// is not zero.
fn prepare(
  shape : Array[Int64],
  dtype : DType,
  value_count : Int,
  expected_rank : Int?,
) -> (Array[Int64], Int64, Int) raise TensorError {
  let dims = shape.copy()
  match expected_rank {
    Some(rank) => {
      if rank < 0 {
        raise InvalidArgument("tensor rank is negative")
      }
      if dims.length() == 0 && rank != 0 {
        raise InvalidArgument("tensor shape is empty")
      }
      if dims.length() != rank {
        raise InvalidArgument("tensor rank does not match")
      }
    }
    None => ()
  }
  if dims.length() > 64 {
    raise InvalidArgument("tensor rank exceeds 64")
  }
  let mut count : Int64 = 1L
  for i = 0; i < dims.length(); i = i + 1 {
    let dim = dims[i]
    if dim < 0L {
      raise InvalidArgument("tensor dimension is negative")
    }
    if dim != 0L && count > 9223372036854775807L / dim {
      raise InvalidArgument("tensor shape product overflows")
    }
    count = count * dim
  }
  let width = dtype.width()
  let max_count = (2147483647 / width).to_int64()
  if count > max_count {
    raise InvalidArgument("tensor byte count overflows")
  }
  let byte_count = (count * width.to_int64()).to_int()
  if value_count.to_int64() != count {
    raise InvalidArgument("tensor byte count does not match data")
  }
  (dims, count, byte_count)
}

///|
fn encode_f32(values : Array[Float], byte_count : Int) -> Bytes {
  Bytes::makei(byte_count, fn(index) {
    let bits = values[index / 4].reinterpret_as_uint()
    (bits >> (index % 4 * 8)).to_byte()
  })
}

///|
fn encode_i64(values : Array[Int64], byte_count : Int) -> Bytes {
  Bytes::makei(byte_count, fn(index) {
    let bits = values[index / 8].reinterpret_as_uint64()
    (bits >> (index % 8 * 8)).to_byte()
  })
}

///|
fn encode_bool(values : Array[Bool], byte_count : Int) -> Bytes {
  Bytes::makei(byte_count, fn(index) {
    if values[index] {
      b'\x01'
    } else {
      b'\x00'
    }
  })
}

///|
fn Tensor::open(
  runtime : @raw.Runtime,
  dtype : DType,
  dims : Array[Int64],
  count : Int64,
  byte_count : Int,
  data : Bytes,
  api : String,
) -> Tensor raise TensorError {
  let value = @raw.Value::create_cpu_tensor(
    runtime,
    dtype.code(),
    shape_fixed(dims),
    data,
  ) catch {
    error => raise lift(error, api)
  }
  errdefer release_value(value)
  agree(value, dtype, dims, count, byte_count, api)
  Tensor::{
    ort: value,
    kind: dtype,
    dims,
    count,
    nbytes: byte_count,
    closed: Ref::Ref(false),
  }
}

///|
fn agree(
  value : @raw.Value,
  dtype : DType,
  dims : Array[Int64],
  count : Int64,
  byte_count : Int,
  api : String,
) -> Unit raise TensorError {
  let element = value.element_type() catch { error => raise lift(error, api) }
  if element != dtype.code() {
    raise InvalidArgument("tensor element type does not match OrtValue")
  }
  let actual_count = value.element_count() catch {
    error => raise lift(error, api)
  }
  if actual_count != count {
    raise InvalidArgument("tensor element count does not match OrtValue")
  }
  let actual_bytes = value.byte_count() catch {
    error => raise lift(error, api)
  }
  if actual_bytes != byte_count {
    raise InvalidArgument("tensor byte count does not match OrtValue")
  }
  let actual_shape = value.shape() catch { error => raise lift(error, api) }
  if !shape_agrees(dims, actual_shape) {
    raise InvalidArgument("tensor shape does not match OrtValue")
  }
}

///|
/// Copy `values` into an `f32` CPU tensor.
///
/// `shape` is the concrete runtime shape. Its length is the rank, so the same
/// constructor covers a scalar, a vector, and a rank-2 batch. Bytes are
/// little-endian, which is the native endianness copied by the C shim on
/// macOS arm64. The caller's array is not borrowed.
pub fn Tensor::from_f32(
  runtime : @raw.Runtime,
  shape : Array[Int64],
  values : Array[Float],
  expected_rank? : Int,
) -> Tensor raise TensorError {
  let (dims, count, byte_count) = prepare(
    shape,
    F32,
    values.length(),
    expected_rank,
  )
  let data = encode_f32(values, byte_count)
  Tensor::open(runtime, F32, dims, count, byte_count, data, "Tensor::from_f32")
}

///|
/// Copy `values` into an `i64` CPU tensor. See `Tensor::from_f32` for shape rules.
pub fn Tensor::from_i64(
  runtime : @raw.Runtime,
  shape : Array[Int64],
  values : Array[Int64],
  expected_rank? : Int,
) -> Tensor raise TensorError {
  let (dims, count, byte_count) = prepare(
    shape,
    I64,
    values.length(),
    expected_rank,
  )
  let data = encode_i64(values, byte_count)
  Tensor::open(runtime, I64, dims, count, byte_count, data, "Tensor::from_i64")
}

///|
/// Copy `values` into a `bool` CPU tensor. See `Tensor::from_f32` for shape rules.
pub fn Tensor::from_bool(
  runtime : @raw.Runtime,
  shape : Array[Int64],
  values : Array[Bool],
  expected_rank? : Int,
) -> Tensor raise TensorError {
  let (dims, count, byte_count) = prepare(
    shape,
    Bool,
    values.length(),
    expected_rank,
  )
  let data = encode_bool(values, byte_count)
  Tensor::open(
    runtime,
    Bool,
    dims,
    count,
    byte_count,
    data,
    "Tensor::from_bool",
  )
}

///|
fn Tensor::ensure_open(self : Tensor, api : String) -> Unit raise TensorError {
  if self.closed.val {
    raise UseAfterClose(api)
  }
}

///|
fn Tensor::copy_data(
  self : Tensor,
  dtype : DType,
  api : String,
) -> Bytes raise TensorError {
  self.ensure_open(api)
  if !self.kind.same(dtype) {
    raise InvalidArgument("tensor element type does not match")
  }
  let data = self.ort.copy_bytes() catch { error => raise lift(error, api) }
  if data.length() != self.nbytes {
    raise InvalidArgument("tensor byte count does not match data")
  }
  data
}

///|
/// Release the tensor exactly once. A second call returns `AlreadyClosed`.
///
/// Close this tensor before closing the runtime that created it.
pub fn Tensor::close(self : Tensor) -> Unit raise TensorError {
  if self.closed.val {
    raise AlreadyClosed("Tensor::close")
  }
  self.ort.close() catch {
    error => raise lift(error, "Tensor::close")
  }
  self.closed.val = true
}

///|
pub fn Tensor::dtype(self : Tensor) -> DType raise TensorError {
  self.ensure_open("Tensor::dtype")
  self.kind
}

///|
/// Return a copy of the concrete shape. Rank 0 is an empty array.
pub fn Tensor::shape(self : Tensor) -> Array[Int64] raise TensorError {
  self.ensure_open("Tensor::shape")
  self.dims.copy()
}

///|
pub fn Tensor::rank(self : Tensor) -> Int raise TensorError {
  self.ensure_open("Tensor::rank")
  self.dims.length()
}

///|
pub fn Tensor::element_count(self : Tensor) -> Int64 raise TensorError {
  self.ensure_open("Tensor::element_count")
  self.count
}

///|
pub fn Tensor::byte_count(self : Tensor) -> Int raise TensorError {
  self.ensure_open("Tensor::byte_count")
  self.nbytes
}

///|
fn read_u32_le(data : Bytes, offset : Int) -> UInt {
  data[offset].to_uint() |
  (data[offset + 1].to_uint() << 8) |
  (data[offset + 2].to_uint() << 16) |
  (data[offset + 3].to_uint() << 24)
}

///|
fn read_u64_le(data : Bytes, offset : Int) -> UInt64 {
  let mut bits = 0UL
  for i = 0; i < 8; i = i + 1 {
    bits = bits | (data[offset + i].to_uint64() << (i * 8))
  }
  bits
}

///|
/// Copy `f32` values out. The buffer does not alias ORT memory.
pub fn Tensor::read_f32(self : Tensor) -> Array[Float] raise TensorError {
  let data = self.copy_data(F32, "Tensor::read_f32")
  Array::makei(data.length() / 4, fn(index) {
    Float::reinterpret_from_uint(read_u32_le(data, index * 4))
  })
}

///|
/// Copy `i64` values out. The buffer does not alias ORT memory.
pub fn Tensor::read_i64(self : Tensor) -> Array[Int64] raise TensorError {
  let data = self.copy_data(I64, "Tensor::read_i64")
  Array::makei(data.length() / 8, fn(index) {
    read_u64_le(data, index * 8).reinterpret_as_int64()
  })
}

///|
/// Copy `bool` values out. A byte other than 0 or 1 is `InvalidArgument`.
pub fn Tensor::read_bool(self : Tensor) -> Array[Bool] raise TensorError {
  let data = self.copy_data(Bool, "Tensor::read_bool")
  for i = 0; i < data.length(); i = i + 1 {
    if data[i] != b'\x00' && data[i] != b'\x01' {
      raise InvalidArgument("bool tensor byte is not 0 or 1")
    }
  }
  Array::makei(data.length(), fn(index) { data[index] == b'\x01' })
}
