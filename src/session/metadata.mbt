///|
/// ONNX element type reported for a model input or output.
///
/// `Float32`, `Int64`, and `Bool` are the v0.1 tensor types. Any other code
/// from the raw API is kept as `Other` so the query does not drop it.
pub(all) enum DType {
  Float32
  Int64
  Bool
  Other(Int)
} derive(Eq)

///|
pub extend DType with Eq::{not_equal, equal}

///|
pub fn DType::from_code(code : Int) -> DType {
  if code == @raw.dtype_f32 {
    Float32
  } else if code == @raw.dtype_i64 {
    Int64
  } else if code == @raw.dtype_bool {
    Bool
  } else {
    Other(code)
  }
}

///|
pub fn DType::text(self : DType) -> String {
  match self {
    Float32 => "float32"
    Int64 => "int64"
    Bool => "bool"
    Other(code) => "other(\{code})"
  }
}

///|
/// One axis of a model input or output.
///
/// A negative raw dimension is dynamic. Its symbolic name may be empty.
pub(all) enum Dimension {
  Fixed(Int64)
  Symbolic(String)
} derive(Eq)

///|
pub extend Dimension with Eq::{not_equal, equal}

///|
pub fn Dimension::text(self : Dimension) -> String {
  match self {
    Fixed(size) => size.to_string()
    Symbolic(name) => if name.length() == 0 { "?" } else { name }
  }
}

///|
fn shape_text(dims : Array[Dimension]) -> String {
  let builder = StringBuilder()
  for i = 0; i < dims.length(); i = i + 1 {
    if i > 0 {
      builder.write_string(",")
    }
    builder.write_string(dims[i].text())
  }
  builder.to_string()
}

///|
fn collect_dimensions(
  shape : FixedArray[Int64],
  names : FixedArray[String],
) -> Array[Dimension] {
  if shape.length() != names.length() {
    abort("shape rank and dimension names disagree")
  }
  let dims : Array[Dimension] = []
  for i = 0; i < shape.length(); i = i + 1 {
    if shape[i] < 0L {
      dims.push(Symbolic(names[i]))
    } else {
      dims.push(Fixed(shape[i]))
    }
  }
  dims
}

///|
fn copy_strings(values : FixedArray[String]) -> Array[String] {
  let out : Array[String] = []
  for i = 0; i < values.length(); i = i + 1 {
    out.push(values[i])
  }
  out
}

///|
pub fn Session::output_count(self : Session) -> Int raise @raw.OrtError {
  self.raw.output_count()
}

///|
pub fn Session::input_name(
  self : Session,
  index : Int,
) -> String raise @raw.OrtError {
  self.raw.input_name(index)
}

///|
pub fn Session::output_name(
  self : Session,
  index : Int,
) -> String raise @raw.OrtError {
  self.raw.output_name(index)
}

///|
pub fn Session::input_dtype(
  self : Session,
  index : Int,
) -> DType raise @raw.OrtError {
  DType::from_code(self.raw.input_element_type(index))
}

///|
pub fn Session::output_dtype(
  self : Session,
  index : Int,
) -> DType raise @raw.OrtError {
  DType::from_code(self.raw.output_element_type(index))
}

///|
/// Static axes are `Fixed`. A negative raw dimension becomes `Symbolic`.
pub fn Session::input_dimensions(
  self : Session,
  index : Int,
) -> Array[Dimension] raise @raw.OrtError {
  collect_dimensions(
    self.raw.input_shape(index),
    self.raw.input_dimension_params(index),
  )
}

///|
pub fn Session::output_dimensions(
  self : Session,
  index : Int,
) -> Array[Dimension] raise @raw.OrtError {
  collect_dimensions(
    self.raw.output_shape(index),
    self.raw.output_dimension_params(index),
  )
}

///|
pub fn Session::producer_name(self : Session) -> String raise @raw.OrtError {
  self.raw.producer_name()
}

///|
pub fn Session::graph_name(self : Session) -> String raise @raw.OrtError {
  self.raw.graph_name()
}

///|
pub fn Session::domain(self : Session) -> String raise @raw.OrtError {
  self.raw.domain()
}

///|
pub fn Session::description(self : Session) -> String raise @raw.OrtError {
  self.raw.description()
}

///|
pub fn Session::model_version(self : Session) -> Int64 raise @raw.OrtError {
  self.raw.model_version()
}

///|
pub fn Session::custom_metadata_keys(
  self : Session,
) -> Array[String] raise @raw.OrtError {
  copy_strings(self.raw.custom_metadata_keys())
}

///|
pub fn Session::custom_metadata(
  self : Session,
  key : String,
) -> String raise @raw.OrtError {
  self.raw.custom_metadata(key)
}

///|
fn write_endpoint(
  builder : StringBuilder,
  kind : String,
  index : Int,
  name : String,
  dtype : DType,
  dims : Array[Dimension],
) -> Unit {
  builder.write_string(
    "\{kind}[\{index}] name=\{name} dtype=\{dtype.text()} rank=\{dims.length()} shape=\{shape_text(dims)}\n",
  )
}

///|
/// Input/output contract for `sha256`. The text has no weights.
///
/// `sha256` is the model file digest computed by the caller. Each line is one
/// input or output: name, dtype, rank, and shape. Dynamic axes use their
/// symbolic name, or `?` when the raw API leaves that name empty.
pub fn Session::contract_text(
  self : Session,
  sha256 : String,
) -> String raise @raw.OrtError {
  let builder = StringBuilder()
  builder.write_string("sha256=\{sha256}\n")
  let inputs = self.input_count()
  for i = 0; i < inputs; i = i + 1 {
    write_endpoint(
      builder,
      "input",
      i,
      self.input_name(i),
      self.input_dtype(i),
      self.input_dimensions(i),
    )
  }
  let outputs = self.output_count()
  for i = 0; i < outputs; i = i + 1 {
    write_endpoint(
      builder,
      "output",
      i,
      self.output_name(i),
      self.output_dtype(i),
      self.output_dimensions(i),
    )
  }
  builder.to_string()
}
