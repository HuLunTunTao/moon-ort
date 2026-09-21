///|
/// Opaque ONNX Runtime environment. The C `OrtEnv` pointer stays inside the shim.
#external
pub type Runtime

///|
#borrow(path)
extern "C" fn moon_ort_load(path : String) -> Runtime = "moon_ort_load"

///|
#borrow(handle)
extern "C" fn moon_ort_code(handle : Runtime) -> Int = "moon_ort_code"

///|
#borrow(handle)
extern "C" fn moon_ort_state(handle : Runtime) -> Int = "moon_ort_state"

///|
#borrow(handle)
extern "C" fn moon_ort_expected_api(handle : Runtime) -> Int = "moon_ort_expected_api"

///|
#borrow(handle)
extern "C" fn moon_ort_actual_api(handle : Runtime) -> Int = "moon_ort_actual_api"

///|
#borrow(handle)
extern "C" fn moon_ort_status_code(handle : Runtime) -> Int = "moon_ort_status_code"

///|
#borrow(handle)
extern "C" fn moon_ort_api_version(handle : Runtime) -> Int = "moon_ort_api_version"

///|
extern "C" fn moon_ort_header_api_version() -> Int = "moon_ort_header_api_version"

///|
#borrow(handle)
extern "C" fn moon_ort_message(handle : Runtime) -> String = "moon_ort_message"

///|
#borrow(handle)
extern "C" fn moon_ort_path(handle : Runtime) -> String = "moon_ort_path"

///|
#borrow(handle)
extern "C" fn moon_ort_api_name(handle : Runtime) -> String = "moon_ort_api_name"

///|
#borrow(handle)
extern "C" fn moon_ort_version(handle : Runtime) -> String = "moon_ort_version"

///|
#borrow(handle)
extern "C" fn moon_ort_close(handle : Runtime) -> Int = "moon_ort_close"

///|
/// Opaque `OrtSessionOptions`. The C pointer stays inside the shim.
#external
pub type SessionOptions

///|
/// Opaque `OrtSession`. The C pointer stays inside the shim.
#external
pub type Session

///|
#borrow(runtime)
extern "C" fn moon_ort_options_create(runtime : Runtime) -> SessionOptions = "moon_ort_options_create"

///|
#borrow(handle)
extern "C" fn moon_ort_options_code(handle : SessionOptions) -> Int = "moon_ort_options_code"

///|
#borrow(handle)
extern "C" fn moon_ort_options_state(handle : SessionOptions) -> Int = "moon_ort_options_state"

///|
#borrow(handle)
extern "C" fn moon_ort_options_status_code(handle : SessionOptions) -> Int = "moon_ort_options_status_code"

///|
#borrow(handle)
extern "C" fn moon_ort_options_message(handle : SessionOptions) -> String = "moon_ort_options_message"

///|
#borrow(handle)
extern "C" fn moon_ort_options_api_name(handle : SessionOptions) -> String = "moon_ort_options_api_name"

///|
#borrow(handle)
extern "C" fn moon_ort_options_close(handle : SessionOptions) -> Int = "moon_ort_options_close"

///|
#borrow(handle)
extern "C" fn moon_ort_options_set_intra(
  handle : SessionOptions,
  threads : Int,
) -> Int = "moon_ort_options_set_intra"

///|
#borrow(handle)
extern "C" fn moon_ort_options_set_inter(
  handle : SessionOptions,
  threads : Int,
) -> Int = "moon_ort_options_set_inter"

///|
#borrow(handle)
extern "C" fn moon_ort_options_set_graph_optimization(
  handle : SessionOptions,
  level : Int,
) -> Int = "moon_ort_options_set_graph_optimization"

///|
#borrow(handle)
extern "C" fn moon_ort_options_set_execution_mode(
  handle : SessionOptions,
  mode : Int,
) -> Int = "moon_ort_options_set_execution_mode"

///|
#borrow(handle)
extern "C" fn moon_ort_options_execution_mode(handle : SessionOptions) -> Int = "moon_ort_options_execution_mode"

///|
#borrow(runtime, options, path)
extern "C" fn moon_ort_session_create(
  runtime : Runtime,
  options : SessionOptions,
  path : String,
) -> Session = "moon_ort_session_create"

///|
#borrow(handle)
extern "C" fn moon_ort_session_code(handle : Session) -> Int = "moon_ort_session_code"

///|
#borrow(handle)
extern "C" fn moon_ort_session_state(handle : Session) -> Int = "moon_ort_session_state"

///|
#borrow(handle)
extern "C" fn moon_ort_session_status_code(handle : Session) -> Int = "moon_ort_session_status_code"

///|
#borrow(handle)
extern "C" fn moon_ort_session_message(handle : Session) -> String = "moon_ort_session_message"

///|
#borrow(handle)
extern "C" fn moon_ort_session_api_name(handle : Session) -> String = "moon_ort_session_api_name"

///|
#borrow(handle)
extern "C" fn moon_ort_session_close(handle : Session) -> Int = "moon_ort_session_close"

///|
#borrow(handle)
extern "C" fn moon_ort_session_input_count(handle : Session) -> Int = "moon_ort_session_input_count"

///|
#borrow(handle)
extern "C" fn moon_ort_session_output_count(handle : Session) -> Int = "moon_ort_session_output_count"

///|
#borrow(handle)
extern "C" fn moon_ort_session_input_name(
  handle : Session,
  index : Int,
) -> String = "moon_ort_session_input_name"

///|
#borrow(handle)
extern "C" fn moon_ort_session_output_name(
  handle : Session,
  index : Int,
) -> String = "moon_ort_session_output_name"

///|
#borrow(handle)
extern "C" fn moon_ort_session_input_element_type(
  handle : Session,
  index : Int,
) -> Int = "moon_ort_session_input_element_type"

///|
#borrow(handle)
extern "C" fn moon_ort_session_output_element_type(
  handle : Session,
  index : Int,
) -> Int = "moon_ort_session_output_element_type"

///|
#borrow(handle)
extern "C" fn moon_ort_session_input_shape(
  handle : Session,
  index : Int,
) -> FixedArray[Int64] = "moon_ort_session_input_shape"

///|
#borrow(handle)
extern "C" fn moon_ort_session_output_shape(
  handle : Session,
  index : Int,
) -> FixedArray[Int64] = "moon_ort_session_output_shape"

///|
#borrow(handle)
extern "C" fn moon_ort_session_input_dimension_params(
  handle : Session,
  index : Int,
) -> FixedArray[String] = "moon_ort_session_input_dimension_params"

///|
#borrow(handle)
extern "C" fn moon_ort_session_output_dimension_params(
  handle : Session,
  index : Int,
) -> FixedArray[String] = "moon_ort_session_output_dimension_params"

///|
#borrow(handle)
extern "C" fn moon_ort_session_producer_name(handle : Session) -> String = "moon_ort_session_producer_name"

///|
#borrow(handle)
extern "C" fn moon_ort_session_graph_name(handle : Session) -> String = "moon_ort_session_graph_name"

///|
#borrow(handle)
extern "C" fn moon_ort_session_domain(handle : Session) -> String = "moon_ort_session_domain"

///|
#borrow(handle)
extern "C" fn moon_ort_session_description(handle : Session) -> String = "moon_ort_session_description"

///|
#borrow(handle)
extern "C" fn moon_ort_session_model_version(handle : Session) -> Int64 = "moon_ort_session_model_version"

///|
#borrow(handle)
extern "C" fn moon_ort_session_custom_metadata_keys(
  handle : Session,
) -> FixedArray[String] = "moon_ort_session_custom_metadata_keys"

///|
#borrow(handle, key)
extern "C" fn moon_ort_session_custom_metadata(
  handle : Session,
  key : String,
) -> String = "moon_ort_session_custom_metadata"

///|
/// Opaque CPU tensor `OrtValue`. The C pointer stays inside the shim.
#external
pub type Value

///|
#borrow(runtime, shape, data)
extern "C" fn moon_ort_value_create(
  runtime : Runtime,
  element_type : Int,
  shape : FixedArray[Int64],
  data : Bytes,
) -> Value = "moon_ort_value_create"

///|
#borrow(handle)
extern "C" fn moon_ort_value_code(handle : Value) -> Int = "moon_ort_value_code"

///|
#borrow(handle)
extern "C" fn moon_ort_value_state(handle : Value) -> Int = "moon_ort_value_state"

///|
#borrow(handle)
extern "C" fn moon_ort_value_status_code(handle : Value) -> Int = "moon_ort_value_status_code"

///|
#borrow(handle)
extern "C" fn moon_ort_value_message(handle : Value) -> String = "moon_ort_value_message"

///|
#borrow(handle)
extern "C" fn moon_ort_value_api_name(handle : Value) -> String = "moon_ort_value_api_name"

///|
#borrow(handle)
extern "C" fn moon_ort_value_close(handle : Value) -> Int = "moon_ort_value_close"

///|
#borrow(handle)
extern "C" fn moon_ort_value_element_type(handle : Value) -> Int = "moon_ort_value_element_type"

///|
#borrow(handle)
extern "C" fn moon_ort_value_shape(handle : Value) -> FixedArray[Int64] = "moon_ort_value_shape"

///|
#borrow(handle)
extern "C" fn moon_ort_value_element_count(handle : Value) -> Int64 = "moon_ort_value_element_count"

///|
#borrow(handle)
extern "C" fn moon_ort_value_byte_count(handle : Value) -> Int = "moon_ort_value_byte_count"

///|
#borrow(handle)
extern "C" fn moon_ort_value_copy_bytes(handle : Value) -> Bytes = "moon_ort_value_copy_bytes"
