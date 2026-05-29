extern "csharp" fn BytesView::bytes(self : BytesView) -> Bytes =
  #| return self.Buffer;

extern "csharp" fn BytesView::start(self : BytesView) -> Int =
  #| return self.StartOffset;

extern "csharp" fn BytesView::len(self : BytesView) -> Int =
  #| return self.Length;

extern "csharp" fn BytesView::length(self : BytesView) -> Int =
  #| return self.Length;

extern "csharp" fn BytesView::unsafe_get(self : BytesView, index : Int) -> Byte =
  #| return self[index];

pub fn Bytes::to_array(self : Bytes) -> Array[Byte] {
  Array::makei(self.length(), fn(i) { self.unsafe_get(i) })
}

pub fn BytesView::to_array(self : BytesView) -> Array[Byte] {
  Array::makei(self.length(), fn(i) { self.unsafe_get(i) })
}
