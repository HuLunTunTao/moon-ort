///|
test "session reads metadata and can outlive options" {
  let lib = compile_fake("fake_session")
  let rt = @raw.Runtime::load(lib)
  let options = @raw.SessionOptions::create(rt)
  options.set_execution_mode(@raw.execution_parallel)
  inspect(options.execution_mode(), content="1")
  let session = @raw.Session::create(rt, options, "ok.onnx")
  options.close()
  inspect(session.input_count(), content="2")
  inspect(session.output_count(), content="1")
  inspect(session.input_name(0), content="features")
  inspect(session.input_name(1), content="batch_id")
  inspect(session.output_name(0), content="scores")
  inspect(session.input_element_type(0), content="1")
  inspect(session.input_element_type(1), content="7")
  inspect(session.output_element_type(0), content="9")
  let features = session.input_shape(0)
  inspect(features.length(), content="2")
  assert_true(features[0] == 2L && features[1] == 3L)
  let batch = session.input_shape(1)
  assert_true(batch.length() == 1 && batch[0] == -1L)
  let scores = session.output_shape(0)
  assert_true(scores.length() == 1 && scores[0] == 2L)
  let feature_names = session.input_dimension_params(0)
  inspect(feature_names[0], content="")
  inspect(feature_names[1], content="")
  let batch_names = session.input_dimension_params(1)
  inspect(batch_names[0], content="batch")
  inspect(session.producer_name(), content="moon-ort-fake")
  inspect(session.graph_name(), content="fake-graph")
  inspect(session.domain(), content="ai.moonort")
  inspect(session.description(), content="fake session")
  assert_true(session.model_version() == 7L)
  let keys = session.custom_metadata_keys()
  assert_true(keys.length() == 1)
  inspect(keys[0], content="purpose")
  inspect(session.custom_metadata("purpose"), content="test")
  session.close()
  rt.close()
}

///|
test "session options reach CreateSession" {
  let lib = compile_fake("fake_session")
  let rt = @raw.Runtime::load(lib)
  let options = @raw.SessionOptions::create(rt)
  options.set_intra_op_threads(3)
  options.set_inter_op_threads(4)
  options.set_graph_optimization_level(@raw.graph_optimization_all)
  options.set_execution_mode(@raw.execution_parallel)
  try @raw.Session::create(rt, options, "options-probe.onnx") catch {
    Status(code, message, api) => {
      inspect(code, content="1")
      inspect(api, content="CreateSession")
      inspect(message, content="intra=3;inter=4;opt=99;mode=1")
    }
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected Status")
  }
  options.close()
  rt.close()
}

///|
test "open session keeps the runtime open" {
  let lib = compile_fake("fake_session")
  let rt = @raw.Runtime::load(lib)
  let options = @raw.SessionOptions::create(rt)
  let session = @raw.Session::create(rt, options, "ok.onnx")
  options.close()
  try rt.close() catch {
    InvalidArgument(message) =>
      inspect(message, content="runtime has open handles")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  inspect(rt.version(), content="fake-session-1.30.0")
  session.close()
  rt.close()
}

///|
test "repeated session construct and close does not crash" {
  let lib = compile_fake("fake_session")
  for i = 0; i < 20; i = i + 1 {
    let rt = @raw.Runtime::load(lib)
    let options = @raw.SessionOptions::create(rt)
    let session = @raw.Session::create(rt, options, "ok.onnx")
    assert_true(session.input_name(0) == "features")
    session.close()
    options.close()
    rt.close()
    ignore(i)
  }
}
