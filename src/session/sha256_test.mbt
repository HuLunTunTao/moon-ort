///|
test "file sha256 matches known vectors and the add fixture" {
  let empty = "/tmp/moon-ort-sha-empty"
  let abc = "/tmp/moon-ort-sha-abc"
  if @test_support.write_file(empty, "") != 0 {
    fail("failed to create empty file")
  }
  if @test_support.write_file(abc, "abc") != 0 {
    fail("failed to create abc file")
  }
  inspect(
    file_sha256(empty),
    content="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  )
  inspect(
    file_sha256(abc),
    content="ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  )
  inspect(
    file_sha256("testdata/add_f32.onnx"),
    content="7e1d718adc9faee1a389550e17b038ad0827ebb20dd1d6c632f6542bdb050468",
  )
  inspect(
    file_sha256("testdata/dynamic_identity_f32.onnx"),
    content="794dd006c106b82a851b34d219527489a59c43fe7020d7621a93956e3ebdf432",
  )
}

///|
test "file sha256 rejects an empty path and a missing file" {
  try file_sha256("") catch {
    Unreadable(message) => inspect(message, content="model path is empty")
  } noraise {
    _ => fail("expected Unreadable")
  }
  try file_sha256("/no/such/moon-ort-model.onnx") catch {
    Unreadable(message) => assert_true(message.length() > 0)
  } noraise {
    _ => fail("expected Unreadable")
  }
}
