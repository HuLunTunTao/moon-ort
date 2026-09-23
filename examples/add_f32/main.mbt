///|
extern "C" fn host_exit(code : Int) -> Unit = "exit"

///|
fn format_f32(values : Array[Float]) -> String {
  let builder = StringBuilder()
  builder.write_string("[")
  for i = 0; i < values.length(); i = i + 1 {
    if i > 0 {
      builder.write_string(", ")
    }
    builder.write_string(values[i].to_string())
  }
  builder.write_string("]")
  builder.to_string()
}

///|
fn usage() -> Unit {
  println(
    "usage: moon run examples/add_f32 -- <libonnxruntime.dylib> <model.onnx>",
  )
  host_exit(2)
}

///|
fn main {
  let args = @env.args()
  if args.length() != 3 {
    usage()
  }
  try {
    let runtime = @raw.Runtime::load(args[1])
    let options = @session.SessionOptions::create(runtime)
    let session = @session.Session::create(runtime, options, args[2])
    let input = @tensor.Tensor::from_f32(runtime, [2L], [0.5, -1.5])
    let outputs = session.run(["input"], [input], ["output"])
    println("output=" + format_f32(outputs[0].read_f32()))
    outputs[0].close()
    input.close()
    session.close()
    options.close()
    runtime.close()
  } catch {
    error => {
      println(error.to_string())
      host_exit(1)
    }
  }
}
