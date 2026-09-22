///|
#borrow(name, output)
extern "C" fn compile_fake_ffi(name : String, output : String) -> Int = "moon_ort_test_compile_fake"

///|
pub fn compile_fake(name : String, output : String) -> Int {
  compile_fake_ffi(name, output)
}

///|
extern "C" fn verify_cc_select_ffi() -> Int = "moon_ort_test_verify_cc_select"

///|
pub fn verify_cc_select() -> Int {
  verify_cc_select_ffi()
}

///|
#borrow(path, contents)
extern "C" fn write_file_ffi(path : String, contents : String) -> Int = "moon_ort_test_write_file"

///|
pub fn write_file(path : String, contents : String) -> Int {
  write_file_ffi(path, contents)
}
