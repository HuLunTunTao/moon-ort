///|
fn compile_fake(name : String) -> String raise Failure {
  let out = "/tmp/moon-ort-ffi-\{name}.dylib"
  let code = @test_support.compile_fake(name, out)
  if code != 0 {
    fail("c compiler failed to build \{name}: \{code}")
  }
  out
}

///|
test "missing library returns attempted path" {
  let missing = "/no/such/libonnxruntime-moon-ort.dylib"
  try @raw.Runtime::load(missing) catch {
    MissingLibrary(path, message) => {
      inspect(path, content=missing)
      assert_true(message.length() > 0)
    }
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected MissingLibrary")
  }
}

///|
test "empty path is rejected" {
  try @raw.Runtime::load("") catch {
    InvalidArgument(message) =>
      inspect(message, content="runtime path is empty")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected InvalidArgument")
  }
}

///|
test "api mismatch reports expected and actual versions" {
  let lib = compile_fake("fake_api_mismatch")
  try @raw.Runtime::load(lib) catch {
    ApiMismatch(_, _, expected, actual) => {
      inspect(expected, content="30")
      inspect(actual, content="-1")
    }
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected ApiMismatch")
  }
}

///|
test "missing OrtGetApiBase is a structured symbol error" {
  let lib = compile_fake("fake_no_symbol")
  try @raw.Runtime::load(lib) catch {
    SymbolNotFound(path, message) => {
      inspect(path, content=lib)
      assert_true(message.length() > 0)
    }
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected SymbolNotFound")
  }
}

///|
test "create env failure releases OrtStatus" {
  let lib = compile_fake("fake_create_fail")
  try @raw.Runtime::load(lib) catch {
    Status(code, message, api) => {
      inspect(code, content="1")
      inspect(api, content="CreateEnv")
      inspect(message, content="fake create env failed")
    }
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected Status")
  }
}

///|
test "env close is once and later use fails" {
  let lib = compile_fake("fake_env")
  let rt = @raw.Runtime::load(lib)
  inspect(rt.version(), content="fake-env-1.30.0")
  inspect(rt.api_version(), content="30")
  inspect(@raw.header_api_version(), content="30")
  rt.close()
  try rt.version() catch {
    UseAfterClose(api) => inspect(api, content="Runtime::version")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  try rt.api_version() catch {
    UseAfterClose(api) => inspect(api, content="Runtime::api_version")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected UseAfterClose")
  }
  try rt.close() catch {
    AlreadyClosed(api) => inspect(api, content="Runtime::close")
    other => fail(other.to_string())
  } noraise {
    _ => fail("expected AlreadyClosed")
  }
}

///|
test "repeated env construct and close does not crash" {
  let lib = compile_fake("fake_env")
  for i = 0; i < 20; i = i + 1 {
    let rt = @raw.Runtime::load(lib)
    assert_true(rt.version() == "fake-env-1.30.0")
    rt.close()
    ignore(i)
  }
}
