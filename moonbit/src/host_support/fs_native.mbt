///|
#borrow(path)
extern "c" fn open_file_readonly(path : Bytes, flags : Int) -> Int = "open"

///|
#borrow(buffer)
extern "c" fn read_file_chunk(fd : Int, buffer : Bytes, count : Int) -> Int = "read"

///|
#borrow(buffer)
extern "c" fn write_fd_chunk(fd : Int, buffer : Bytes, count : Int) -> Int = "write"

///|
extern "c" fn close_file(fd : Int) -> Int = "close"

///|
pub fn read_text_file(path : String) -> String {
  let fd = open_file_readonly(string_to_utf8_bytes(path, true), 0)
  if fd < 0 {
    println("cannot open file: \{path}")
    panic()
  }
  let bytes : Array[Byte] = []
  let buffer = Bytes::new(8192)
  let mut keep_reading = true
  while keep_reading {
    let read = read_file_chunk(fd, buffer, buffer.length())
    if read < 0 {
      ignore(close_file(fd))
      println("cannot read file: \{path}")
      panic()
    } else if read == 0 {
      keep_reading = false
    } else {
      for i in 0..<read {
        bytes.push(buffer[i])
      }
    }
  }
  ignore(close_file(fd))
  utf8_bytes_to_string(Bytes::from_array(bytes))
}

///|
pub fn write_stderr(text : String) -> Unit {
  let bytes = string_to_utf8_bytes(text, false)
  ignore(write_fd_chunk(2, bytes, bytes.length()))
}

///|
pub fn path_file_name(path : String) -> String {
  let mut last = 0
  let mut i = 0
  while i < path.length() {
    let ch = path[i]
    if ch == '/' || ch == '\\' {
      last = i + 1
    }
    i += 1
  }
  path[last:].to_owned()
}

///|
fn string_to_utf8_bytes(str : String, append_nul : Bool) -> Bytes {
  let res : Array[Byte] = []
  let len = str.length()
  let mut i = 0
  while i < len {
    let mut c = str.code_unit_at(i).to_int()
    if 0xD800 <= c && c <= 0xDBFF {
      c -= 0xD800
      i += 1
      let l = str.code_unit_at(i).to_int() - 0xDC00
      c = (c << 10) + l + 0x10000
    }
    if c < 0x80 {
      res.push(c.to_byte())
    } else if c < 0x800 {
      res.push((0xc0 + (c >> 6)).to_byte())
      res.push((0x80 + (c & 0x3f)).to_byte())
    } else if c < 0x10000 {
      res.push((0xe0 + (c >> 12)).to_byte())
      res.push((0x80 + ((c >> 6) & 0x3f)).to_byte())
      res.push((0x80 + (c & 0x3f)).to_byte())
    } else {
      res.push((0xf0 + (c >> 18)).to_byte())
      res.push((0x80 + ((c >> 12) & 0x3f)).to_byte())
      res.push((0x80 + ((c >> 6) & 0x3f)).to_byte())
      res.push((0x80 + (c & 0x3f)).to_byte())
    }
    i += 1
  }
  if append_nul {
    res.push((0).to_byte())
  }
  Bytes::from_array(res)
}

///|
fn utf8_bytes_to_string(bytes : Bytes) -> String {
  let res = StringBuilder::new()
  let len = bytes.length()
  let mut i = 0
  while i < len {
    let mut c = bytes[i].to_int()
    if c == 0 {
      break
    } else if c < 0x80 {
      res.write_char(c.unsafe_to_char())
      i += 1
    } else if c < 0xE0 {
      if i + 1 >= len {
        break
      }
      c = ((c & 0x1F) << 6) | (bytes[i + 1].to_int() & 0x3F)
      res.write_char(c.unsafe_to_char())
      i += 2
    } else if c < 0xF0 {
      if i + 2 >= len {
        break
      }
      c = ((c & 0x0F) << 12) |
        ((bytes[i + 1].to_int() & 0x3F) << 6) |
        (bytes[i + 2].to_int() & 0x3F)
      res.write_char(c.unsafe_to_char())
      i += 3
    } else {
      if i + 3 >= len {
        break
      }
      c = ((c & 0x07) << 18) |
        ((bytes[i + 1].to_int() & 0x3F) << 12) |
        ((bytes[i + 2].to_int() & 0x3F) << 6) |
        (bytes[i + 3].to_int() & 0x3F)
      c -= 0x10000
      res.write_char(((c >> 10) + 0xD800).unsafe_to_char())
      res.write_char(((c & 0x3FF) + 0xDC00).unsafe_to_char())
      i += 4
    }
  }
  res.to_string()
}
