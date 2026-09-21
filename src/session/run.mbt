///|
/// Failure from one synchronous `Session::run`.
///
/// Callers match these variants. Raw `OrtError` and `TensorError` are mapped
/// here so a run does not ask the caller to handle pointer-level errors.
pub suberror RunError {
  WrongName(String)
  MissingInput(String)
  DuplicateName(String)
  TypeMismatch(String)
  ShapeMismatch(String)
  UseAfterClose(String)
  AlreadyClosed(String)
  Status(Int, String, String)
  InvalidArgument(String)
}

///|
pub impl Show for RunError with fn output(self, logger) {
  match self {
    WrongName(name) => logger.write_string("wrong name; name=\{name}")
    MissingInput(name) => logger.write_string("missing input; name=\{name}")
    DuplicateName(name) => logger.write_string("duplicate name; name=\{name}")
    TypeMismatch(name) => logger.write_string("dtype mismatch; name=\{name}")
    ShapeMismatch(name) => logger.write_string("shape mismatch; name=\{name}")
    UseAfterClose(api) => logger.write_string("use after close; api=\{api}")
    AlreadyClosed(api) => logger.write_string("already closed; api=\{api}")
    Status(code, message, api) =>
      logger.write_string(
        "ort status; api=\{api}; code=\{code}; message=\{message}",
      )
    InvalidArgument(message) =>
      logger.write_string("invalid argument; message=\{message}")
  }
}

///|
fn lift_ort(error : @raw.OrtError) -> RunError {
  match error {
    @raw.UseAfterClose(api) => UseAfterClose(api)
    @raw.AlreadyClosed(api) => AlreadyClosed(api)
    @raw.InvalidArgument(message) => InvalidArgument(message)
    @raw.Status(code, message, api) => Status(code, message, api)
    @raw.MissingLibrary(path, message) =>
      InvalidArgument(
        "missing library; attempted_paths=[" + path + "]; loader=" + message,
      )
    @raw.SymbolNotFound(path, message) =>
      InvalidArgument(
        "symbol not found; attempted_paths=[" + path + "]; loader=" + message,
      )
    @raw.ApiMismatch(path, message, expected, actual) =>
      InvalidArgument(
        "api mismatch; attempted_paths=[" +
        path +
        "]; expected_api=" +
        expected.to_string() +
        "; actual_api=" +
        actual.to_string() +
        "; loader=" +
        message,
      )
  }
}

///|
fn lift_tensor(error : @tensor.TensorError) -> RunError {
  match error {
    @tensor.UseAfterClose(api) => UseAfterClose(api)
    @tensor.AlreadyClosed(api) => AlreadyClosed(api)
    @tensor.InvalidArgument(message) => InvalidArgument(message)
    @tensor.Status(code, message, api) => Status(code, message, api)
  }
}

///|
fn type_info_unavailable(message : String) -> Bool {
  message == "SessionGetInputTypeInfo is unavailable" ||
  message == "type info is unavailable" ||
  message == "GetTensorElementType is unavailable" ||
  message == "GetDimensions is unavailable"
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
fn shape_array(shape : FixedArray[Int64]) -> Array[Int64] {
  let dims : Array[Int64] = []
  for i = 0; i < shape.length(); i = i + 1 {
    dims.push(shape[i])
  }
  dims
}

///|
fn fixed_strings(values : Array[String]) -> FixedArray[String] {
  FixedArray::makei(values.length(), fn(index) { values[index] })
}

///|
fn contains_name(names : Array[String], name : String) -> Bool {
  for i = 0; i < names.length(); i = i + 1 {
    if names[i] == name {
      return true
    }
  }
  false
}

///|
fn name_index(names : Array[String], name : String) -> Int? {
  for i = 0; i < names.length(); i = i + 1 {
    if names[i] == name {
      return Some(i)
    }
  }
  None
}

///|
fn close_value(value : @raw.Value) -> Unit {
  value.close() catch {
    _ => ()
  }
}

///|
fn release_values(values : Array[@raw.Value]) -> Unit {
  for i = 0; i < values.length(); i = i + 1 {
    close_value(values[i])
  }
}

///|
fn release_tensors(values : Array[@tensor.Tensor]) -> Unit {
  for i = 0; i < values.length(); i = i + 1 {
    values[i].close() catch {
      _ => ()
    }
  }
}

///|
fn release_outputs(
  values : FixedArray[@raw.Value],
  adopted : Array[@tensor.Tensor],
) -> Unit {
  for i = 0; i < values.length(); i = i + 1 {
    close_value(values[i])
  }
  release_tensors(adopted)
}

///|
fn dtype_matches(actual : @tensor.DType, expected : DType) -> Bool {
  match (actual, expected) {
    (@tensor.F32, Float32) | (@tensor.I64, Int64) | (@tensor.Bool, Bool) => true
    _ => false
  }
}

///|
/// A symbolic axis accepts any concrete non-negative size. Fixed axes must match.
fn shape_matches(actual : Array[Int64], expected : Array[Dimension]) -> Bool {
  if actual.length() != expected.length() {
    return false
  }
  for i = 0; i < actual.length(); i = i + 1 {
    match expected[i] {
      Fixed(size) => if actual[i] != size { return false }
      Symbolic(_) => ()
    }
  }
  true
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
fn encode_f32(values : Array[Float]) -> Bytes {
  Bytes::makei(values.length() * 4, fn(index) {
    let bits = values[index / 4].reinterpret_as_uint()
    (bits >> (index % 4 * 8)).to_byte()
  })
}

///|
fn encode_i64(values : Array[Int64]) -> Bytes {
  Bytes::makei(values.length() * 8, fn(index) {
    let bits = values[index / 8].reinterpret_as_uint64()
    (bits >> (index % 8 * 8)).to_byte()
  })
}

///|
fn encode_bool(values : Array[Bool]) -> Bytes {
  Bytes::makei(values.length(), fn(index) {
    if values[index] {
      b'\x01'
    } else {
      b'\x00'
    }
  })
}

///|
fn decode_f32(data : Bytes) -> Array[Float] raise RunError {
  if data.length() % 4 != 0 {
    raise InvalidArgument("f32 output byte count is not a multiple of 4")
  }
  Array::makei(data.length() / 4, fn(index) {
    Float::reinterpret_from_uint(read_u32_le(data, index * 4))
  })
}

///|
fn decode_i64(data : Bytes) -> Array[Int64] raise RunError {
  if data.length() % 8 != 0 {
    raise InvalidArgument("i64 output byte count is not a multiple of 8")
  }
  Array::makei(data.length() / 8, fn(index) {
    read_u64_le(data, index * 8).reinterpret_as_int64()
  })
}

///|
fn decode_bool(data : Bytes) -> Array[Bool] raise RunError {
  for i = 0; i < data.length(); i = i + 1 {
    if data[i] != b'\x00' && data[i] != b'\x01' {
      raise InvalidArgument("bool output byte is not 0 or 1")
    }
  }
  Array::makei(data.length(), fn(index) { data[index] == b'\x01' })
}

///|
fn reject_duplicates(
  names : Array[String],
  kind : String,
) -> Unit raise RunError {
  for i = 0; i < names.length(); i = i + 1 {
    for j = 0; j < i; j = j + 1 {
      if names[j] == names[i] {
        raise DuplicateName("duplicate " + kind + " name: " + names[i])
      }
    }
  }
}

///|
fn reject_unknown(
  names : Array[String],
  known : Array[String],
  kind : String,
) -> Unit raise RunError {
  for i = 0; i < names.length(); i = i + 1 {
    if !contains_name(known, names[i]) {
      raise WrongName(kind + " name is not in the session: " + names[i])
    }
  }
}

///|
fn input_contract(
  session : Session,
  index : Int,
) -> (DType, Array[Dimension])? raise RunError {
  let dtype = session.input_dtype(index) catch {
    @raw.InvalidArgument(message) => {
      if type_info_unavailable(message) {
        return None
      }
      raise InvalidArgument(message)
    }
    error => raise lift_ort(error)
  }
  let dims = session.input_dimensions(index) catch {
    @raw.InvalidArgument(message) => {
      if type_info_unavailable(message) {
        return None
      }
      raise InvalidArgument(message)
    }
    error => raise lift_ort(error)
  }
  Some((dtype, dims))
}

///|
fn copy_input(
  runtime : @raw.Runtime,
  tensor : @tensor.Tensor,
) -> @raw.Value raise RunError {
  let dtype = tensor.dtype() catch { error => raise lift_tensor(error) }
  let shape = tensor.shape() catch { error => raise lift_tensor(error) }
  let (code, bytes) = match dtype {
    @tensor.F32 => {
      let values = tensor.read_f32() catch { error => raise lift_tensor(error) }
      (@raw.dtype_f32, encode_f32(values))
    }
    @tensor.I64 => {
      let values = tensor.read_i64() catch { error => raise lift_tensor(error) }
      (@raw.dtype_i64, encode_i64(values))
    }
    @tensor.Bool => {
      let values = tensor.read_bool() catch {
        error => raise lift_tensor(error)
      }
      (@raw.dtype_bool, encode_bool(values))
    }
  }
  @raw.Value::create_cpu_tensor(runtime, code, shape_fixed(shape), bytes) catch {
    error => raise lift_ort(error)
  }
}

///|
/// Copy one raw output into a caller-owned tensor, then close the raw value.
fn take_output(
  runtime : @raw.Runtime,
  value : @raw.Value,
) -> @tensor.Tensor raise RunError {
  errdefer close_value(value)
  let code = value.element_type() catch { error => raise lift_ort(error) }
  let shape = value.shape() catch { error => raise lift_ort(error) }
  let bytes = value.copy_bytes() catch { error => raise lift_ort(error) }
  let dims = shape_array(shape)
  let tensor = if code == @raw.dtype_f32 {
    let values = decode_f32(bytes)
    @tensor.Tensor::from_f32(runtime, dims, values) catch {
      error => raise lift_tensor(error)
    }
  } else if code == @raw.dtype_i64 {
    let values = decode_i64(bytes)
    @tensor.Tensor::from_i64(runtime, dims, values) catch {
      error => raise lift_tensor(error)
    }
  } else if code == @raw.dtype_bool {
    let values = decode_bool(bytes)
    @tensor.Tensor::from_bool(runtime, dims, values) catch {
      error => raise lift_tensor(error)
    }
  } else {
    raise InvalidArgument(
      "output element type is unsupported: " + code.to_string(),
    )
  }
  value.close() catch {
    error => {
      tensor.close() catch {
        _ => ()
      }
      raise lift_ort(error)
    }
  }
  tensor
}

///|
fn check_inputs(
  session : Session,
  model_inputs : Array[String],
  input_names : Array[String],
  inputs : Array[@tensor.Tensor],
) -> Unit raise RunError {
  if input_names.length() != inputs.length() {
    raise InvalidArgument("input count does not match values")
  }
  reject_duplicates(input_names, "input")
  reject_unknown(input_names, model_inputs, "input")
  for i = 0; i < model_inputs.length(); i = i + 1 {
    if !contains_name(input_names, model_inputs[i]) {
      raise MissingInput("missing input: " + model_inputs[i])
    }
  }
  for i = 0; i < inputs.length(); i = i + 1 {
    let name = input_names[i]
    let dtype = inputs[i].dtype() catch {
      @tensor.UseAfterClose(_) => raise UseAfterClose("Tensor::dtype")
      error => raise lift_tensor(error)
    }
    let shape = inputs[i].shape() catch { error => raise lift_tensor(error) }
    let index = match name_index(model_inputs, name) {
      Some(found) => found
      None => raise WrongName("input name is not in the session: " + name)
    }
    match input_contract(session, index) {
      None => ()
      Some((expected_dtype, expected_shape)) => {
        if !dtype_matches(dtype, expected_dtype) {
          raise TypeMismatch("input dtype does not match: " + name)
        }
        if !shape_matches(shape, expected_shape) {
          raise ShapeMismatch("input shape does not match: " + name)
        }
      }
    }
  }
}

///|
/// Run `self` synchronously. Callers pass and receive tensors.
///
/// The caller keeps ownership of every input tensor. Each returned tensor is
/// owned by the caller and must be closed once. Returned tensors follow
/// `output_names`.
///
/// Release order for one call:
/// 1. Validate names, duplicates, missing inputs, and, when the session reports
///    them, dtype and shape. No ORT value is created if this fails.
/// 2. Copy each input into a temporary raw value. The caller's tensor stays open.
/// 3. Raw `Session::run` either returns output values or releases every output
///    and the OrtStatus. Temporary inputs are closed on that failure.
/// 4. Copy each raw output into a caller-owned tensor, then close that raw
///    output. If a later output fails, close tensors already adopted, close
///    the remaining raw outputs, then close the temporary inputs.
/// 5. Close the temporary inputs after every output has been adopted.
pub fn Session::run(
  self : Session,
  input_names : Array[String],
  inputs : Array[@tensor.Tensor],
  output_names : Array[String],
) -> Array[@tensor.Tensor] raise RunError {
  let input_count = self.input_count() catch {
    @raw.UseAfterClose(_) => raise UseAfterClose("Session::run")
    error => raise lift_ort(error)
  }
  let output_count = self.output_count() catch {
    error => raise lift_ort(error)
  }
  let model_inputs : Array[String] = []
  for i = 0; i < input_count; i = i + 1 {
    let name = self.input_name(i) catch { error => raise lift_ort(error) }
    model_inputs.push(name)
  }
  let model_outputs : Array[String] = []
  for i = 0; i < output_count; i = i + 1 {
    let name = self.output_name(i) catch { error => raise lift_ort(error) }
    model_outputs.push(name)
  }
  check_inputs(self, model_inputs, input_names, inputs)
  reject_duplicates(output_names, "output")
  reject_unknown(output_names, model_outputs, "output")
  let temps : Array[@raw.Value] = []
  errdefer release_values(temps)
  for i = 0; i < inputs.length(); i = i + 1 {
    temps.push(copy_input(self.runtime, inputs[i]))
  }
  let raw_inputs = FixedArray::makei(temps.length(), fn(index) { temps[index] })
  let raw_outputs = self.raw.run(
    fixed_strings(input_names),
    raw_inputs,
    fixed_strings(output_names),
  ) catch {
    error => raise lift_ort(error)
  }
  let adopted : Array[@tensor.Tensor] = []
  errdefer release_outputs(raw_outputs, adopted)
  for i = 0; i < raw_outputs.length(); i = i + 1 {
    adopted.push(take_output(self.runtime, raw_outputs[i]))
  }
  release_values(temps)
  adopted
}

///|
/// `MOON_ORT_LIBRARY`, when the process set it.
///
/// The official-library package test uses this path. A missing value, a fake
/// library, or any version other than 1.30.0 skips that comparison.
pub fn configured_library() -> String? {
  @env.get_env_var("MOON_ORT_LIBRARY")
}
