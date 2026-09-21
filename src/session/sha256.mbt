///|
/// Failure while reading a model file to hash it.
///
/// This is separate from `OrtError`: the raw API has no file-hash function,
/// and its error constructors are not available outside `src/raw`.
pub suberror IoError {
  Unreadable(String)
}

///|
pub impl Show for IoError with fn output(self, logger) {
  match self {
    Unreadable(message) =>
      logger.write_string("unreadable file; message=\{message}")
  }
}

///|
#external
priv type CFile

///|
#borrow(path, mode)
extern "C" fn moonbit_fopen_ffi(path : Bytes, mode : Bytes) -> CFile = "moonbit_fopen_ffi"

///|
extern "C" fn moonbit_is_null(ptr : CFile) -> Int = "moonbit_is_null"

///|
#borrow(ptr)
extern "C" fn moonbit_fread_ffi(
  ptr : Bytes,
  size : Int,
  nitems : Int,
  stream : CFile,
) -> UInt64 = "moonbit_fread_ffi"

///|
extern "C" fn moonbit_fclose_ffi(stream : CFile) -> Int = "moonbit_fclose_ffi"

///|
extern "C" fn moonbit_fseek_ffi(
  stream : CFile,
  offset : Int64,
  whence : Int,
) -> Int = "moonbit_fseek_ffi"

///|
extern "C" fn moonbit_ftell_ffi(stream : CFile) -> Int64 = "moonbit_ftell_ffi"

///|
extern "C" fn moonbit_get_error_message() -> Bytes = "moonbit_get_error_message"

///|
fn c_bytes(text : String) -> Bytes {
  @utf8.encode(text) + b"\x00"
}

///|
fn io_message() -> String {
  @utf8.decode_lossy(moonbit_get_error_message())
}

///|
priv struct Sha256 {
  state : FixedArray[UInt]
  block : FixedArray[Byte]
  mut filled : Int
  mut nbytes : UInt64
}

///|
fn sha256_k(index : Int) -> UInt {
  let words : Array[UInt] = [
    0x428a2f98U, 0x71374491U, 0xb5c0fbcfU, 0xe9b5dba5U, 0x3956c25bU, 0x59f111f1U,
    0x923f82a4U, 0xab1c5ed5U, 0xd807aa98U, 0x12835b01U, 0x243185beU, 0x550c7dc3U,
    0x72be5d74U, 0x80deb1feU, 0x9bdc06a7U, 0xc19bf174U, 0xe49b69c1U, 0xefbe4786U,
    0x0fc19dc6U, 0x240ca1ccU, 0x2de92c6fU, 0x4a7484aaU, 0x5cb0a9dcU, 0x76f988daU,
    0x983e5152U, 0xa831c66dU, 0xb00327c8U, 0xbf597fc7U, 0xc6e00bf3U, 0xd5a79147U,
    0x06ca6351U, 0x14292967U, 0x27b70a85U, 0x2e1b2138U, 0x4d2c6dfcU, 0x53380d13U,
    0x650a7354U, 0x766a0abbU, 0x81c2c92eU, 0x92722c85U, 0xa2bfe8a1U, 0xa81a664bU,
    0xc24b8b70U, 0xc76c51a3U, 0xd192e819U, 0xd6990624U, 0xf40e3585U, 0x106aa070U,
    0x19a4c116U, 0x1e376c08U, 0x2748774cU, 0x34b0bcb5U, 0x391c0cb3U, 0x4ed8aa4aU,
    0x5b9cca4fU, 0x682e6ff3U, 0x748f82eeU, 0x78a5636fU, 0x84c87814U, 0x8cc70208U,
    0x90befffaU, 0xa4506cebU, 0xbef9a3f7U, 0xc67178f2U,
  ]
  words[index]
}

///|
fn rotr(value : UInt, bits : Int) -> UInt {
  (value >> bits) | (value << (32 - bits))
}

///|
fn Sha256::new() -> Sha256 {
  let state = FixedArray::make(8, 0U)
  state[0] = 0x6a09e667U
  state[1] = 0xbb67ae85U
  state[2] = 0x3c6ef372U
  state[3] = 0xa54ff53aU
  state[4] = 0x510e527fU
  state[5] = 0x9b05688cU
  state[6] = 0x1f83d9abU
  state[7] = 0x5be0cd19U
  { state, block: FixedArray::make(64, b'\x00'), filled: 0, nbytes: 0UL, }
}

///|
fn Sha256::compress(self : Sha256) -> Unit {
  let w = FixedArray::make(64, 0U)
  for i = 0; i < 16; i = i + 1 {
    let j = i * 4
    w[i] = (self.block[j].to_uint() << 24) |
      (self.block[j + 1].to_uint() << 16) |
      (self.block[j + 2].to_uint() << 8) |
      self.block[j + 3].to_uint()
  }
  for i = 16; i < 64; i = i + 1 {
    let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
    let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
    w[i] = w[i - 16] + s0 + w[i - 7] + s1
  }
  let mut a = self.state[0]
  let mut b = self.state[1]
  let mut c = self.state[2]
  let mut d = self.state[3]
  let mut e = self.state[4]
  let mut f = self.state[5]
  let mut g = self.state[6]
  let mut h = self.state[7]
  for i = 0; i < 64; i = i + 1 {
    let s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
    let ch = (e & f) ^ ((e ^ 0xFFFFFFFFU) & g)
    let temp1 = h + s1 + ch + sha256_k(i) + w[i]
    let s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
    let maj = (a & b) ^ (a & c) ^ (b & c)
    let temp2 = s0 + maj
    h = g
    g = f
    f = e
    e = d + temp1
    d = c
    c = b
    b = a
    a = temp1 + temp2
  }
  self.state[0] = self.state[0] + a
  self.state[1] = self.state[1] + b
  self.state[2] = self.state[2] + c
  self.state[3] = self.state[3] + d
  self.state[4] = self.state[4] + e
  self.state[5] = self.state[5] + f
  self.state[6] = self.state[6] + g
  self.state[7] = self.state[7] + h
}

///|
fn Sha256::push(self : Sha256, byte : Byte) -> Unit {
  self.block[self.filled] = byte
  self.filled = self.filled + 1
  if self.filled == 64 {
    self.compress()
    self.filled = 0
  }
}

///|
fn Sha256::update(self : Sha256, data : Bytes, start : Int, len : Int) -> Unit {
  let mut offset = 0
  while offset < len {
    let space = 64 - self.filled
    let mut take = len - offset
    if take > space {
      take = space
    }
    for i = 0; i < take; i = i + 1 {
      self.block[self.filled + i] = data[start + offset + i]
    }
    self.filled = self.filled + take
    offset = offset + take
    self.nbytes = self.nbytes + take.to_uint64()
    if self.filled == 64 {
      self.compress()
      self.filled = 0
    }
  }
}

///|
fn Sha256::digest(self : Sha256) -> Bytes {
  let bits = self.nbytes * 8UL
  self.push(b'\x80')
  while self.filled != 56 {
    self.push(b'\x00')
  }
  let mut shift = 56
  while shift >= 0 {
    let piece = (bits >> shift) & 0xFFUL
    self.push(piece.to_uint().to_byte())
    shift = shift - 8
  }
  let out : Array[Byte] = []
  for i = 0; i < 8; i = i + 1 {
    let word = self.state[i]
    out.push((word >> 24).to_byte())
    out.push((word >> 16).to_byte())
    out.push((word >> 8).to_byte())
    out.push(word.to_byte())
  }
  Bytes::from_array(out)
}

///|
/// SHA-256 of `path`, streamed so the model bytes are not retained.
///
/// The result is lowercase hex. An empty path or a file that cannot be read
/// returns `IoError`. This does not parse the model and does not print weights.
pub fn file_sha256(path : String) -> String raise IoError {
  if path.length() == 0 {
    raise Unreadable("model path is empty")
  }
  let file = moonbit_fopen_ffi(c_bytes(path), c_bytes("rb"))
  if moonbit_is_null(file) != 0 {
    raise Unreadable(io_message())
  }
  defer ignore(moonbit_fclose_ffi(file))
  hash_open_file(file)
}

///|
fn hash_open_file(file : CFile) -> String raise IoError {
  if moonbit_fseek_ffi(file, 0L, 2) != 0 {
    raise Unreadable(io_message())
  }
  let size = moonbit_ftell_ffi(file)
  if size < 0L {
    raise Unreadable(io_message())
  }
  if moonbit_fseek_ffi(file, 0L, 0) != 0 {
    raise Unreadable(io_message())
  }
  let hasher = Sha256::new()
  let buf = Bytes::make(4096, b'\x00')
  let mut left = size
  while left > 0L {
    let want = if left < 4096L { left.to_int() } else { 4096 }
    let got = moonbit_fread_ffi(buf, 1, want, file)
    if got == 0UL {
      raise Unreadable("model file ended early")
    }
    let n = got.to_int()
    hasher.update(buf, 0, n)
    left = left - n.to_int64()
  }
  @hex.encode(hasher.digest())
}
