///|

///|
test "c compiler selection prefers a set CC then gcc-15 otherwise cc" {
  let code = @test_support.verify_cc_select()
  if code != 0 {
    fail("cc selection probe failed: \{code}")
  }
}
