///|
test "session reads static and dynamic shapes and model metadata" {
  let lib = compile_fake("fake_session")
  let rt = @raw.Runtime::load(lib)
  let options = @session.SessionOptions::create(rt)
  let session = @session.Session::create(rt, options, "ok.onnx")
  options.close()
  inspect(session.input_count(), content="2")
  inspect(session.output_count(), content="1")
  inspect(session.input_name(0), content="features")
  inspect(session.input_name(1), content="batch_id")
  inspect(session.output_name(0), content="scores")
  assert_true(session.input_dtype(0) == Float32)
  assert_true(session.input_dtype(1) == Int64)
  assert_true(session.output_dtype(0) == Bool)
  let features = session.input_dimensions(0)
  assert_true(features.length() == 2)
  assert_true(features[0] == Fixed(2L) && features[1] == Fixed(3L))
  let batch = session.input_dimensions(1)
  assert_true(batch.length() == 1 && batch[0] == Symbolic("batch"))
  let scores = session.output_dimensions(0)
  assert_true(scores.length() == 1 && scores[0] == Fixed(2L))
  inspect(session.producer_name(), content="moon-ort-fake")
  inspect(session.graph_name(), content="fake-graph")
  inspect(session.domain(), content="ai.moonort")
  inspect(session.description(), content="fake session")
  assert_true(session.model_version() == 7L)
  let keys = session.custom_metadata_keys()
  assert_true(keys.length() == 1)
  inspect(keys[0], content="purpose")
  inspect(session.custom_metadata("purpose"), content="test")
  let expected =
    #|sha256=abc
    #|input[0] name=features dtype=float32 rank=2 shape=2,3
    #|input[1] name=batch_id dtype=int64 rank=1 shape=batch
    #|output[0] name=scores dtype=bool rank=1 shape=2
    #|
  inspect(session.contract_text("abc"), content=expected)
  let unnamed : @session.Dimension = Symbolic("")
  inspect(unnamed.text(), content="?")
  inspect(@session.DType::from_code(2).text(), content="other(2)")
  session.close()
  rt.close()
}
