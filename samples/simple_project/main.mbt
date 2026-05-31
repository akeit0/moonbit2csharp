fn main {
  let b = b"hello?"
  println(b)
  let array = b.unsafe_to_bytesArray()
  array[5]='!'.to_int().to_byte()
  println(b)
}


fn Bytes::unsafe_to_bytesArray(bytes :Bytes ) -> FixedArray[Byte] = "%identity"
