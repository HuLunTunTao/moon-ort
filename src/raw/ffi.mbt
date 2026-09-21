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
