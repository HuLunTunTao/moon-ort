///|
/// Structured failure from dynamic loading or `OrtEnv` lifetime checks.
///
/// Load failures keep the attempted path and the underlying loader or
/// `OrtStatus` message. This package does not expose `OrtEnv` pointers.
pub suberror OrtError {
  MissingLibrary(String, String)
  SymbolNotFound(String, String)
  ApiMismatch(String, String, Int, Int)
  Status(Int, String, String)
  AlreadyClosed(String)
  UseAfterClose(String)
  InvalidArgument(String)
}

///|
pub impl Show for OrtError with fn output(self, logger) {
  match self {
    MissingLibrary(path, message) =>
      logger.write_string(
        "missing library; attempted_paths=[\{path}]; loader=\{message}",
      )
    SymbolNotFound(path, message) =>
      logger.write_string(
        "symbol not found; attempted_paths=[\{path}]; loader=\{message}",
      )
    ApiMismatch(path, message, expected, actual) =>
      logger.write_string(
        "api mismatch; attempted_paths=[\{path}]; expected_api=\{expected}; actual_api=\{actual}; loader=\{message}",
      )
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
pub extend OrtError with Show::{to_string, output}

///|
fn load_error(handle : Runtime) -> OrtError {
  match moon_ort_code(handle) {
    1 => MissingLibrary(moon_ort_path(handle), moon_ort_message(handle))
    2 => SymbolNotFound(moon_ort_path(handle), moon_ort_message(handle))
    3 =>
      ApiMismatch(
        moon_ort_path(handle),
        moon_ort_message(handle),
        moon_ort_expected_api(handle),
        moon_ort_actual_api(handle),
      )
    4 =>
      Status(
        moon_ort_status_code(handle),
        moon_ort_message(handle),
        moon_ort_api_name(handle),
      )
    _ => InvalidArgument(moon_ort_message(handle))
  }
}

///|
fn Runtime::guard_open(self : Runtime, api : String) -> Unit raise OrtError {
  if moon_ort_state(self) != 0 {
    raise UseAfterClose(api)
  }
}

///|
/// C API version this package was compiled against (`ORT_API_VERSION`).
pub fn header_api_version() -> Int {
  moon_ort_header_api_version()
}

///|
/// Load `path` with `dlopen`, negotiate `OrtGetApiBase`, and create `OrtEnv`.
///
/// `path` is the only attempted location. A missing file, missing
/// `OrtGetApiBase`, or rejected API version returns `OrtError` and does not
/// leave an open environment.
pub fn Runtime::load(path : String) -> Runtime raise OrtError {
  let handle = moon_ort_load(path)
  if moon_ort_code(handle) != 0 {
    raise load_error(handle)
  }
  handle
}

///|
/// ONNX Runtime version string from `OrtGetApiBase::GetVersionString`.
pub fn Runtime::version(self : Runtime) -> String raise OrtError {
  self.guard_open("Runtime::version")
  moon_ort_version(self)
}

///|
pub fn Runtime::api_version(self : Runtime) -> Int raise OrtError {
  self.guard_open("Runtime::api_version")
  moon_ort_api_version(self)
}

///|

///|
fn raise_handle(
  code : Int,
  status_code : Int,
  message : String,
  api : String,
) -> Unit raise OrtError {
  match code {
    0 => ()
    4 => raise Status(status_code, message, api)
    5 => raise AlreadyClosed(api)
    6 => raise UseAfterClose(api)
    _ => raise InvalidArgument(message)
  }
}

///|
/// Release the `OrtEnv` exactly once. A second call returns `AlreadyClosed`.
///
/// Session options, sessions, and tensor values pin the loaded library. Closing
/// the runtime while any of them is still open returns `InvalidArgument` and
/// does not release the environment.
pub fn Runtime::close(self : Runtime) -> Unit raise OrtError {
  match moon_ort_close(self) {
    0 => ()
    5 => raise AlreadyClosed("Runtime::close")
    _ => raise InvalidArgument(moon_ort_message(self))
  }
}
