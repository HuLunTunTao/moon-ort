///|
extern "C" fn host_exit(code : Int) -> Unit = "exit"

///|
fn usage() -> Unit {
  println(
    "usage: moon run src/session/cmd -- <model.onnx>  with MOON_ORT_LIBRARY set, or moon run src/session/cmd -- <libonnxruntime> <model.onnx>",
  )
  host_exit(2)
}

///|
fn main {
  let args = @env.args()
  let (library, model) = if args.length() >= 3 {
    (args[1], args[2])
  } else if args.length() == 2 {
    match @env.get_env_var("MOON_ORT_LIBRARY") {
      Some(value) => (value, args[1])
      None => {
        usage()
        ("", "")
      }
    }
  } else {
    usage()
    ("", "")
  }
  if library.length() == 0 || model.length() == 0 {
    usage()
  }
  let sha = @session.file_sha256(model) catch {
    @session.Unreadable(message) => {
      println("unreadable file; message=\{message}")
      host_exit(1)
      abort("exit")
    }
  }
  try {
    let rt = @raw.Runtime::load(library)
    let options = @session.SessionOptions::create(rt)
    let session = @session.Session::create(rt, options, model)
    let text = @session.Session::contract_text(session, sha)
    println(text[:text.length() - 1].to_owned())
    session.close()
    options.close()
    rt.close()
  } catch {
    err => {
      println(err.to_string())
      host_exit(1)
    }
  }
}
