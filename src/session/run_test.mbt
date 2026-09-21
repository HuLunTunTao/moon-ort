///|
fn open_run(
  lib : String,
  path : String,
) -> (@raw.Runtime, Session) raise @raw.OrtError {
  let rt = @raw.Runtime::load(lib)
  let options = SessionOptions::create(rt)
  let session = Session::create(rt, options, path)
  options.close()
  (rt, session)
}

///|
fn assert_f32(
  actual : Array[Float],
  expected : Array[Float],
) -> Unit raise Failure {
  if actual.length() != expected.length() {
    fail("f32 length \{actual.length()} != \{expected.length()}")
  }
  for i = 0; i < actual.length(); i = i + 1 {
    if actual[i] != expected[i] {
      fail("f32 index \{i}")
    }
  }
}

///|
fn assert_i64(
  actual : Array[Int64],
  expected : Array[Int64],
) -> Unit raise Failure {
  if actual.length() != expected.length() {
    fail("i64 length \{actual.length()} != \{expected.length()}")
  }
  for i = 0; i < actual.length(); i = i + 1 {
    if actual[i] != expected[i] {
      fail("i64 index \{i}")
    }
  }
}

///|
fn assert_bool(
  actual : Array[Bool],
  expected : Array[Bool],
) -> Unit raise Failure {
  if actual.length() != expected.length() {
    fail("bool length \{actual.length()} != \{expected.length()}")
  }
  for i = 0; i < actual.length(); i = i + 1 {
    if actual[i] != expected[i] {
      fail("bool index \{i}")
    }
  }
}

///|
fn assert_shape(
  actual : Array[Int64],
  expected : Array[Int64],
) -> Unit raise Failure {
  if actual.length() != expected.length() {
    fail("shape length \{actual.length()} != \{expected.length()}")
  }
  for i = 0; i < actual.length(); i = i + 1 {
    if actual[i] != expected[i] {
      fail("shape index \{i}")
    }
  }
}

///|
/// gcc-15 fake only. The vector [2.0, -3.5] is the fake's canned add_f32
/// reply for [0.5, -1.5]. It is not an official ONNX Runtime result.
test "fake run keeps input ownership and closes the output once" {
  let (rt, session) = open_run(compile_fake("fake_run"), "ok.onnx")
  let input = @tensor.Tensor::from_f32(rt, [2L], [0.5, -1.5])
  let outputs = session.run(["input"], [input], ["output"])
  inspect(outputs.length(), content="1")
  assert_shape(outputs[0].shape(), [2L])
  inspect(outputs[0].dtype(), content="f32")
  assert_f32(outputs[0].read_f32(), [2.0, -3.5])
  assert_f32(input.read_f32(), [0.5, -1.5])
  outputs[0].close()
  try outputs[0].close() catch {
    @tensor.AlreadyClosed(api) => inspect(api, content="Tensor::close")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected AlreadyClosed")
  }
  input.close()
  session.close()
  rt.close()
}

///|
test "run rejects a wrong input or output name" {
  let (rt, session) = open_run(compile_fake("fake_run"), "ok.onnx")
  let input = @tensor.Tensor::from_f32(rt, [2L], [0.5, -1.5])
  try session.run(["features"], [input], ["output"]) catch {
    WrongName(message) =>
      inspect(message, content="input name is not in the session: features")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected WrongName")
  }
  try session.run(["input"], [input], ["scores"]) catch {
    WrongName(message) =>
      inspect(message, content="output name is not in the session: scores")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected WrongName")
  }
  assert_f32(input.read_f32(), [0.5, -1.5])
  input.close()
  session.close()
  rt.close()
}

///|
test "run rejects a missing input and a duplicate name" {
  let (rt, session) = open_run(compile_fake("fake_run"), "ok.onnx")
  let input = @tensor.Tensor::from_f32(rt, [2L], [0.5, -1.5])
  let extra = @tensor.Tensor::from_f32(rt, [2L], [0.5, -1.5])
  try session.run([], [], ["output"]) catch {
    MissingInput(message) => inspect(message, content="missing input: input")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected MissingInput")
  }
  try session.run(["input", "input"], [input, extra], ["output"]) catch {
    DuplicateName(message) =>
      inspect(message, content="duplicate input name: input")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected DuplicateName")
  }
  try session.run(["input"], [input], ["output", "output"]) catch {
    DuplicateName(message) =>
      inspect(message, content="duplicate output name: output")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected DuplicateName")
  }
  input.close()
  extra.close()
  session.close()
  rt.close()
}

///|
test "run rejects dtype and shape mismatches from session metadata" {
  // fake_session reports dtype and shape but cannot create tensors.
  let tensors = @raw.Runtime::load(compile_fake("fake_tensor"))
  let (rt, session) = open_run(compile_fake("fake_session"), "ok.onnx")
  let wrong_type = @tensor.Tensor::from_i64(tensors, [2L, 3L], [
    0L, 0L, 0L, 0L, 0L, 0L,
  ])
  let batch = @tensor.Tensor::from_i64(tensors, [1L], [7L])
  try
    session.run(["features", "batch_id"], [wrong_type, batch], ["scores"])
  catch {
    TypeMismatch(message) =>
      inspect(message, content="input dtype does not match: features")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected TypeMismatch")
  }
  let wrong_shape = @tensor.Tensor::from_f32(tensors, [2L, 4L], [
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  ])
  try
    session.run(["features", "batch_id"], [wrong_shape, batch], ["scores"])
  catch {
    ShapeMismatch(message) =>
      inspect(message, content="input shape does not match: features")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected ShapeMismatch")
  }
  wrong_type.close()
  wrong_shape.close()
  batch.close()
  session.close()
  rt.close()
  tensors.close()
}

///|
/// fake_session reports a symbolic batch but cannot create tensors or Run.
/// A shape that matches therefore fails while copying the input, not as
/// ShapeMismatch.
test "symbolic batch dimension is not a shape mismatch" {
  let tensors = @raw.Runtime::load(compile_fake("fake_tensor"))
  let (rt, session) = open_run(compile_fake("fake_session"), "ok.onnx")
  let features = @tensor.Tensor::from_f32(tensors, [2L, 3L], [
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  ])
  let batch = @tensor.Tensor::from_i64(tensors, [4L], [1L, 2L, 3L, 4L])
  try
    session.run(["features", "batch_id"], [features, batch], ["scores"])
  catch {
    InvalidArgument(message) =>
      inspect(message, content="tensor API is unavailable")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
  features.close()
  batch.close()
  session.close()
  rt.close()
  tensors.close()
}

///|
test "run rejects a closed session and a closed input tensor" {
  let (rt, session) = open_run(compile_fake("fake_run"), "ok.onnx")
  let input = @tensor.Tensor::from_f32(rt, [2L], [0.5, -1.5])
  session.close()
  try session.run(["input"], [input], ["output"]) catch {
    UseAfterClose(api) => inspect(api, content="Session::run")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  input.close()
  let (rt2, session2) = open_run(compile_fake("fake_run"), "ok.onnx")
  let closed = @tensor.Tensor::from_f32(rt2, [2L], [0.5, -1.5])
  closed.close()
  try session2.run(["input"], [closed], ["output"]) catch {
    UseAfterClose(api) => inspect(api, content="Tensor::dtype")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  session2.close()
  rt2.close()
  rt.close()
}

///|
/// gcc-15 fake only. fail-run creates an output and an OrtStatus, then the
/// raw layer releases both. The counters are the fake's, not official ORT.
test "failed run releases outputs and keeps the input tensor" {
  let (rt, session) = open_run(compile_fake("fake_run"), "fail-run.onnx")
  let input = @tensor.Tensor::from_f32(rt, [2L], [0.5, -1.5])
  try session.run(["input"], [input], ["output"]) catch {
    Status(code, message, api) => {
      inspect(code, content="1")
      inspect(api, content="Run")
      inspect(message, content="run failed after output")
    }
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected Status")
  }
  inspect(session.custom_metadata("status_live"), content="0")
  inspect(session.custom_metadata("orphan_live"), content="0")
  assert_f32(input.read_f32(), [0.5, -1.5])
  input.close()
  session.close()
  rt.close()
}
