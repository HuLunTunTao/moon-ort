///|
fn compile_fake(name : String) -> String raise Failure {
  let out = "/tmp/moon-ort-sdk-\{name}.dylib"
  let code = @test_support.compile_fake(name, out)
  if code != 0 {
    fail("c compiler failed to build \{name}: \{code}")
  }
  out
}

///|
test "session loads a model and closes once" {
  let lib = compile_fake("fake_session")
  let rt = @raw.Runtime::load(lib)
  let options = SessionOptions::create(rt)
  let session = Session::create(rt, options, "ok.onnx")
  inspect(session.input_count(), content="2")
  options.close()
  inspect(session.input_count(), content="2")
  session.close()
  try session.input_count() catch {
    @raw.UseAfterClose(api) => inspect(api, content="Session::input_count")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  try session.close() catch {
    @raw.AlreadyClosed(api) => inspect(api, content="Session::close")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected AlreadyClosed")
  }
  rt.close()
}

///|
test "session options are visible to CreateSession" {
  let lib = compile_fake("fake_session")
  let rt = @raw.Runtime::load(lib)
  let options = SessionOptions::create(rt)
  options.set_intra_op_threads(3)
  options.set_inter_op_threads(4)
  options.set_execution_mode(Parallel)
  assert_true(options.execution_mode() == Parallel)
  options.set_execution_mode(Sequential)
  assert_true(options.execution_mode() == Sequential)
  options.set_execution_mode(Parallel)
  let levels : Array[GraphOptimization] = [
    DisableAll,
    Basic,
    Extended,
    Layout,
    All,
  ]
  for level in levels {
    options.set_graph_optimization_level(level)
    let opt = match level {
      DisableAll => "0"
      Basic => "1"
      Extended => "2"
      Layout => "3"
      All => "99"
    }
    try Session::create(rt, options, "options-probe.onnx") catch {
      @raw.Status(code, message, api) => {
        inspect(code, content="1")
        inspect(api, content="CreateSession")
        inspect(message, content="intra=3;inter=4;opt=\{opt};mode=1")
      }
      other => fail(other.to_string())
    } noraise {
      _ => fail("expected Status")
    }
  }
  options.set_intra_op_threads(0)
  options.set_inter_op_threads(0)
  options.set_execution_mode(Sequential)
  options.set_graph_optimization_level(DisableAll)
  assert_true(options.execution_mode() == Sequential)
  try Session::create(rt, options, "options-probe.onnx") catch {
    @raw.Status(_, message, _) =>
      inspect(message, content="intra=0;inter=0;opt=0;mode=0")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected Status")
  }
  options.close()
  rt.close()
}

///|
test "graph optimization raw codes are total" {
  assert_true(
    GraphOptimization::from_raw(@raw.graph_optimization_disable_all)
    is Some(DisableAll),
  )
  assert_true(
    GraphOptimization::from_raw(@raw.graph_optimization_basic) is Some(Basic),
  )
  assert_true(
    GraphOptimization::from_raw(@raw.graph_optimization_extended)
    is Some(Extended),
  )
  assert_true(
    GraphOptimization::from_raw(@raw.graph_optimization_layout) is Some(Layout),
  )
  assert_true(
    GraphOptimization::from_raw(@raw.graph_optimization_all) is Some(All),
  )
  assert_true(GraphOptimization::from_raw(4) is None)
}
