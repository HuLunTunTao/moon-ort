///|
/// Graph optimization levels from ONNX Runtime `GraphOptimizationLevel`.
pub let graph_optimization_disable_all : Int = 0

///|
pub let graph_optimization_basic : Int = 1

///|
pub let graph_optimization_extended : Int = 2

///|
pub let graph_optimization_layout : Int = 3

///|
pub let graph_optimization_all : Int = 99

///|
/// Execution modes from ONNX Runtime `ExecutionMode`.
pub let execution_sequential : Int = 0

///|
pub let execution_parallel : Int = 1

///|
fn SessionOptions::guard_open(
  self : SessionOptions,
  api : String,
) -> Unit raise OrtError {
  if moon_ort_options_state(self) != 0 {
    raise UseAfterClose(api)
  }
}

///|
fn SessionOptions::check(self : SessionOptions) -> Unit raise OrtError {
  raise_handle(
    moon_ort_options_code(self),
    moon_ort_options_status_code(self),
    moon_ort_options_message(self),
    moon_ort_options_api_name(self),
  )
}

///|
fn Session::guard_open(self : Session, api : String) -> Unit raise OrtError {
  if moon_ort_session_state(self) != 0 {
    raise UseAfterClose(api)
  }
}

///|
fn Session::check(self : Session) -> Unit raise OrtError {
  raise_handle(
    moon_ort_session_code(self),
    moon_ort_session_status_code(self),
    moon_ort_session_message(self),
    moon_ort_session_api_name(self),
  )
}

///|
/// Create `OrtSessionOptions` for `runtime`. The C pointer stays in the shim.
pub fn SessionOptions::create(
  runtime : Runtime,
) -> SessionOptions raise OrtError {
  runtime.guard_open("SessionOptions::create")
  let options = moon_ort_options_create(runtime)
  options.check()
  options
}

///|
/// Release `OrtSessionOptions` exactly once.
pub fn SessionOptions::close(self : SessionOptions) -> Unit raise OrtError {
  match moon_ort_options_close(self) {
    0 => ()
    5 => raise AlreadyClosed("SessionOptions::close")
    _ => raise InvalidArgument(moon_ort_options_message(self))
  }
}

///|
pub fn SessionOptions::set_intra_op_threads(
  self : SessionOptions,
  threads : Int,
) -> Unit raise OrtError {
  self.guard_open("SessionOptions::set_intra_op_threads")
  ignore(moon_ort_options_set_intra(self, threads))
  self.check()
}

///|
pub fn SessionOptions::set_inter_op_threads(
  self : SessionOptions,
  threads : Int,
) -> Unit raise OrtError {
  self.guard_open("SessionOptions::set_inter_op_threads")
  ignore(moon_ort_options_set_inter(self, threads))
  self.check()
}

///|
pub fn SessionOptions::set_graph_optimization_level(
  self : SessionOptions,
  level : Int,
) -> Unit raise OrtError {
  self.guard_open("SessionOptions::set_graph_optimization_level")
  ignore(moon_ort_options_set_graph_optimization(self, level))
  self.check()
}

///|
pub fn SessionOptions::set_execution_mode(
  self : SessionOptions,
  mode : Int,
) -> Unit raise OrtError {
  self.guard_open("SessionOptions::set_execution_mode")
  ignore(moon_ort_options_set_execution_mode(self, mode))
  self.check()
}

///|
pub fn SessionOptions::execution_mode(
  self : SessionOptions,
) -> Int raise OrtError {
  self.guard_open("SessionOptions::execution_mode")
  let mode = moon_ort_options_execution_mode(self)
  self.check()
  mode
}

///|
/// Create an `OrtSession` from a model file. This does not run the model.
pub fn Session::create(
  runtime : Runtime,
  options : SessionOptions,
  path : String,
) -> Session raise OrtError {
  runtime.guard_open("Session::create")
  options.guard_open("Session::create")
  let session = moon_ort_session_create(runtime, options, path)
  session.check()
  session
}

///|
/// Release `OrtSession` exactly once.
pub fn Session::close(self : Session) -> Unit raise OrtError {
  match moon_ort_session_close(self) {
    0 => ()
    5 => raise AlreadyClosed("Session::close")
    _ => raise InvalidArgument(moon_ort_session_message(self))
  }
}

///|
pub fn Session::input_count(self : Session) -> Int raise OrtError {
  self.guard_open("Session::input_count")
  let count = moon_ort_session_input_count(self)
  self.check()
  count
}

///|
pub fn Session::output_count(self : Session) -> Int raise OrtError {
  self.guard_open("Session::output_count")
  let count = moon_ort_session_output_count(self)
  self.check()
  count
}

///|
pub fn Session::input_name(
  self : Session,
  index : Int,
) -> String raise OrtError {
  self.guard_open("Session::input_name")
  let name = moon_ort_session_input_name(self, index)
  self.check()
  name
}

///|
pub fn Session::output_name(
  self : Session,
  index : Int,
) -> String raise OrtError {
  self.guard_open("Session::output_name")
  let name = moon_ort_session_output_name(self, index)
  self.check()
  name
}

///|
pub fn Session::input_element_type(
  self : Session,
  index : Int,
) -> Int raise OrtError {
  self.guard_open("Session::input_element_type")
  let element = moon_ort_session_input_element_type(self, index)
  self.check()
  element
}

///|
pub fn Session::output_element_type(
  self : Session,
  index : Int,
) -> Int raise OrtError {
  self.guard_open("Session::output_element_type")
  let element = moon_ort_session_output_element_type(self, index)
  self.check()
  element
}

///|
/// Static dimensions are non-negative. A negative dimension is dynamic.
pub fn Session::input_shape(
  self : Session,
  index : Int,
) -> FixedArray[Int64] raise OrtError {
  self.guard_open("Session::input_shape")
  let shape = moon_ort_session_input_shape(self, index)
  self.check()
  shape
}

///|
pub fn Session::output_shape(
  self : Session,
  index : Int,
) -> FixedArray[Int64] raise OrtError {
  self.guard_open("Session::output_shape")
  let shape = moon_ort_session_output_shape(self, index)
  self.check()
  shape
}

///|
/// Symbolic dimension names. An empty string means that dimension has no name.
pub fn Session::input_dimension_params(
  self : Session,
  index : Int,
) -> FixedArray[String] raise OrtError {
  self.guard_open("Session::input_dimension_params")
  let names = moon_ort_session_input_dimension_params(self, index)
  self.check()
  names
}

///|
pub fn Session::output_dimension_params(
  self : Session,
  index : Int,
) -> FixedArray[String] raise OrtError {
  self.guard_open("Session::output_dimension_params")
  let names = moon_ort_session_output_dimension_params(self, index)
  self.check()
  names
}

///|
pub fn Session::producer_name(self : Session) -> String raise OrtError {
  self.guard_open("Session::producer_name")
  let name = moon_ort_session_producer_name(self)
  self.check()
  name
}

///|
pub fn Session::graph_name(self : Session) -> String raise OrtError {
  self.guard_open("Session::graph_name")
  let name = moon_ort_session_graph_name(self)
  self.check()
  name
}

///|
pub fn Session::domain(self : Session) -> String raise OrtError {
  self.guard_open("Session::domain")
  let name = moon_ort_session_domain(self)
  self.check()
  name
}

///|
pub fn Session::description(self : Session) -> String raise OrtError {
  self.guard_open("Session::description")
  let name = moon_ort_session_description(self)
  self.check()
  name
}

///|
pub fn Session::model_version(self : Session) -> Int64 raise OrtError {
  self.guard_open("Session::model_version")
  let version = moon_ort_session_model_version(self)
  self.check()
  version
}

///|
pub fn Session::custom_metadata_keys(
  self : Session,
) -> FixedArray[String] raise OrtError {
  self.guard_open("Session::custom_metadata_keys")
  let keys = moon_ort_session_custom_metadata_keys(self)
  self.check()
  keys
}

///|
pub fn Session::custom_metadata(
  self : Session,
  key : String,
) -> String raise OrtError {
  self.guard_open("Session::custom_metadata")
  let value = moon_ort_session_custom_metadata(self, key)
  self.check()
  value
}

///|
/// Run `self` synchronously.
///
/// `input_names` addresses open CPU values already created for this runtime.
/// Each name must be one returned by `Session::input_name`, and
/// `input_names.length()` must equal `inputs.length()`. Each output name must
/// be one returned by `Session::output_name`.
///
/// Returned values are owned by the caller and must be closed exactly once.
/// Inputs stay owned by the caller. A failed run releases every output value
/// created before the failure and does not leave an `OrtStatus`. Pointers stay
/// inside this package.
pub fn Session::run(
  self : Session,
  input_names : FixedArray[String],
  inputs : FixedArray[Value],
  output_names : FixedArray[String],
) -> FixedArray[Value] raise OrtError {
  self.guard_open("Session::run")
  let outputs = moon_ort_session_run(self, input_names, inputs, output_names)
  self.check()
  outputs
}
