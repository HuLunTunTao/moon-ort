///|
/// A loaded ONNX model. The `OrtSession` pointer stays in the raw shim.
///
/// Create it from a local file. This does not run the model, switch execution
/// providers, or accept a device buffer or URL. Close it exactly once.
pub struct Session {
  priv raw : @raw.Session
  priv runtime : @raw.Runtime
}

///|
/// Create a CPU session for `path` using `options`.
pub fn Session::create(
  runtime : @raw.Runtime,
  options : SessionOptions,
  path : String,
) -> Session raise @raw.OrtError {
  { raw: @raw.Session::create(runtime, options.raw, path), runtime, }
}

///|
/// Release the session exactly once.
pub fn Session::close(self : Session) -> Unit raise @raw.OrtError {
  self.raw.close()
}

///|
pub fn Session::input_count(self : Session) -> Int raise @raw.OrtError {
  self.raw.input_count()
}
