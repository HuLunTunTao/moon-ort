///|
test "illegal thread counts are rejected and not stored" {
  let lib = compile_fake("fake_session")
  let rt = @raw.Runtime::load(lib)
  let options = SessionOptions::create(rt)
  options.set_intra_op_threads(3)
  options.set_inter_op_threads(4)
  options.set_execution_mode(Parallel)
  options.set_graph_optimization_level(All)
  try options.set_intra_op_threads(-1) catch {
    @raw.InvalidArgument(message) =>
      inspect(message, content="intra-op thread count is negative")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try options.set_inter_op_threads(-2) catch {
    @raw.InvalidArgument(message) =>
      inspect(message, content="inter-op thread count is negative")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try Session::create(rt, options, "options-probe.onnx") catch {
    @raw.Status(_, message, _) =>
      inspect(message, content="intra=3;inter=4;opt=99;mode=1")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected Status")
  }
  options.close()
  try options.set_intra_op_threads(1) catch {
    @raw.UseAfterClose(api) =>
      inspect(api, content="SessionOptions::set_intra_op_threads")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  try options.close() catch {
    @raw.AlreadyClosed(api) => inspect(api, content="SessionOptions::close")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected AlreadyClosed")
  }
  rt.close()
}

///|
test "missing model and empty path are structured errors" {
  let lib = compile_fake("fake_session")
  let rt = @raw.Runtime::load(lib)
  let options = SessionOptions::create(rt)
  try Session::create(rt, options, "") catch {
    @raw.InvalidArgument(message) =>
      inspect(message, content="model path is empty")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try Session::create(rt, options, "missing.onnx") catch {
    @raw.Status(code, message, api) => {
      inspect(code, content="3")
      inspect(api, content="CreateSession")
      inspect(message, content="model file not found")
    }
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected Status")
  }
  let session = Session::create(rt, options, "ok.onnx")
  try session.input_name(-1) catch {
    @raw.InvalidArgument(message) =>
      inspect(message, content="input index is negative")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try session.output_name(3) catch {
    @raw.InvalidArgument(message) =>
      inspect(message, content="output index is out of range")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try session.custom_metadata("") catch {
    @raw.InvalidArgument(message) =>
      inspect(message, content="custom metadata key is empty")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  try session.custom_metadata("missing") catch {
    @raw.InvalidArgument(message) =>
      inspect(message, content="custom metadata key not found")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  session.close()
  try session.producer_name() catch {
    @raw.UseAfterClose(api) => inspect(api, content="Session::producer_name")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  options.close()
  try Session::create(rt, options, "ok.onnx") catch {
    @raw.UseAfterClose(api) => inspect(api, content="Session::create")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  rt.close()
}
