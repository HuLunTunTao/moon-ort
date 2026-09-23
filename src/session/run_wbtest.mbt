///|
test "run preserves structured runtime load errors" {
  let missing = "/no/such/libonnxruntime-moon-ort-run.dylib"
  try @raw.Runtime::load(missing) catch {
    error =>
      match lift_ort(error) {
        Runtime(@raw.MissingLibrary(path, _)) => inspect(path, content=missing)
        other => fail(Show::to_string(other))
      }
  } noraise {
    _ => fail("expected MissingLibrary")
  }
}
