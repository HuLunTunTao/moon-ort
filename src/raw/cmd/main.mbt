///|
extern "C" fn host_exit(code : Int) -> Unit = "exit"

///|
fn main {
  let args = @env.args()
  let path = if args.length() >= 2 {
    args[1]
  } else {
    match @env.get_env_var("MOON_ORT_LIBRARY") {
      Some(value) => value
      None => ""
    }
  }
  if path.length() == 0 {
    println(
      "usage: moon run src/raw/cmd -- <libonnxruntime.dylib>  or set MOON_ORT_LIBRARY",
    )
    host_exit(2)
  }
  try {
    let rt = @raw.Runtime::load(path)
    println("ort_version=" + rt.version())
    println("api_version=" + rt.api_version().to_string())
    println("expected_api=" + @raw.header_api_version().to_string())
    rt.close()
  } catch {
    e => {
      println(e.to_string())
      host_exit(1)
    }
  }
}
