///|
test "session handles reject a second close and later use" {
  let lib = compile_fake("fake_session")
  let rt = @raw.Runtime::load(lib)
  let options = @raw.SessionOptions::create(rt)
  let session = @raw.Session::create(rt, options, "ok.onnx")
  session.close()
  try session.input_count() catch {
    UseAfterClose(api) => inspect(api, content="Session::input_count")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  try session.close() catch {
    AlreadyClosed(api) => inspect(api, content="Session::close")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected AlreadyClosed")
  }
  options.close()
  try options.set_intra_op_threads(1) catch {
    UseAfterClose(api) =>
      inspect(api, content="SessionOptions::set_intra_op_threads")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  try options.close() catch {
    AlreadyClosed(api) => inspect(api, content="SessionOptions::close")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected AlreadyClosed")
  }
  rt.close()
}

///|
test "session create rejects empty path missing file and foreign options" {
  let lib = compile_fake("fake_session")
  let rt = @raw.Runtime::load(lib)
  let options = @raw.SessionOptions::create(rt)
  try @raw.Session::create(rt, options, "") catch {
    InvalidArgument(message) => inspect(message, content="model path is empty")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try @raw.Session::create(rt, options, "missing.onnx") catch {
    Status(code, message, api) => {
      inspect(code, content="3")
      inspect(api, content="CreateSession")
      inspect(message, content="model file not found")
    }
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected Status")
  }
  let other = @raw.Runtime::load(lib)
  try @raw.Session::create(other, options, "ok.onnx") catch {
    InvalidArgument(message) =>
      inspect(message, content="session options belong to a different runtime")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  options.close()
  try @raw.Session::create(rt, options, "ok.onnx") catch {
    UseAfterClose(api) => inspect(api, content="Session::create")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  rt.close()
  try @raw.SessionOptions::create(rt) catch {
    UseAfterClose(api) => inspect(api, content="SessionOptions::create")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  other.close()
}

///|
test "session options and indexes reject invalid arguments" {
  let lib = compile_fake("fake_session")
  let rt = @raw.Runtime::load(lib)
  let options = @raw.SessionOptions::create(rt)
  try options.set_intra_op_threads(-1) catch {
    InvalidArgument(message) =>
      inspect(message, content="intra-op thread count is negative")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try options.set_graph_optimization_level(4) catch {
    InvalidArgument(message) =>
      inspect(message, content="graph optimization level is invalid")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try options.set_execution_mode(2) catch {
    InvalidArgument(message) =>
      inspect(message, content="execution mode is invalid")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  let session = @raw.Session::create(rt, options, "ok.onnx")
  try session.input_name(-1) catch {
    InvalidArgument(message) =>
      inspect(message, content="input index is negative")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try session.output_name(3) catch {
    InvalidArgument(message) =>
      inspect(message, content="output index is out of range")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try session.custom_metadata("") catch {
    InvalidArgument(message) =>
      inspect(message, content="custom metadata key is empty")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try session.custom_metadata("missing") catch {
    InvalidArgument(message) =>
      inspect(message, content="custom metadata key not found")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  session.close()
  options.close()
  rt.close()
}

///|
test "tensor handles reject a second close and later use" {
  let lib = compile_fake("fake_tensor")
  let rt = @raw.Runtime::load(lib)
  let value = @raw.Value::create_cpu_tensor(
    rt,
    @raw.dtype_f32,
    make_shape([1L]),
    b"\x00\x00\x80\x3f",
  )
  value.close()
  try value.copy_bytes() catch {
    UseAfterClose(api) => inspect(api, content="Value::copy_bytes")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  try value.close() catch {
    AlreadyClosed(api) => inspect(api, content="Value::close")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected AlreadyClosed")
  }
  rt.close()
  try
    @raw.Value::create_cpu_tensor(
      rt,
      @raw.dtype_f32,
      make_shape([1L]),
      b"\x00\x00\x80\x3f",
    )
  catch {
    UseAfterClose(api) => inspect(api, content="Value::create_cpu_tensor")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
}

///|
test "tensor create checks shape bytes and dtype" {
  let lib = compile_fake("fake_tensor")
  let rt = @raw.Runtime::load(lib)
  try
    @raw.Value::create_cpu_tensor(rt, @raw.dtype_f32, make_shape([-1L]), b"")
  catch {
    InvalidArgument(message) =>
      inspect(message, content="tensor dimension is negative")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try
    @raw.Value::create_cpu_tensor(
      rt,
      @raw.dtype_f32,
      make_shape([1L]),
      b"\x00\x00",
    )
  catch {
    InvalidArgument(message) =>
      inspect(message, content="tensor byte count does not match data")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try @raw.Value::create_cpu_tensor(rt, 2, make_shape([1L]), b"") catch {
    InvalidArgument(message) =>
      inspect(message, content="tensor element type is not f32, i64, or bool")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try
    @raw.Value::create_cpu_tensor(
      rt,
      @raw.dtype_bool,
      make_shape([1L]),
      b"\x02",
    )
  catch {
    InvalidArgument(message) =>
      inspect(message, content="bool tensor byte is not 0 or 1")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try
    @raw.Value::create_cpu_tensor(
      rt,
      @raw.dtype_i64,
      make_shape([3037000500L, 3037000500L]),
      b"",
    )
  catch {
    InvalidArgument(message) =>
      inspect(message, content="tensor shape product overflows")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try
    @raw.Value::create_cpu_tensor(
      rt,
      @raw.dtype_f32,
      make_shape([536870912L]),
      b"",
    )
  catch {
    InvalidArgument(message) =>
      inspect(message, content="tensor byte count overflows")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  let mut failed = b""
  for i = 0; i < 52; i = i + 1 {
    failed = failed + b"\x00"
  }
  try
    @raw.Value::create_cpu_tensor(rt, @raw.dtype_f32, make_shape([13L]), failed)
  catch {
    Status(code, message, api) => {
      inspect(code, content="1")
      inspect(api, content="CreateTensorAsOrtValue")
      inspect(message, content="fake tensor create failed")
    }
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected Status")
  }
  rt.close()
}
