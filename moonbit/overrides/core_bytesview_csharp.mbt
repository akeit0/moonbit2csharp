///|
extern "csharp" fn BytesView::bytes(self : BytesView) -> Bytes =
  #| return self.Buffer;

///|
extern "csharp" fn BytesView::start(self : BytesView) -> Int =
  #| return self.StartOffset;

///|
extern "csharp" fn BytesView::len(self : BytesView) -> Int =
  #| return self.Length;

///|
extern "csharp" fn BytesView::length(self : BytesView) -> Int =
  #| return self.Length;

///|
extern "csharp" fn BytesView::unsafe_get(self : BytesView, index : Int) -> Byte =
  #| return self[index];

///|
extern "csharp" fn BytesView::make(
  bytes : Bytes,
  start : Int,
  len : Int,
) -> BytesView =
  #| return new BytesView(bytes, start, len);

///|
#alias("_[_:_]")
extern "csharp" fn Bytes::view(
  self : Bytes,
  start? : Int = 0,
  end? : Int,
) -> BytesView =
  #| var len = self.Length;
  #| var actualEnd = end.IsSome ? end.Value : len;
  #| if (actualEnd < 0) actualEnd = len + actualEnd;
  #| var actualStart = start < 0 ? len + start : start;
  #| if (actualStart < 0 || actualStart > actualEnd || actualEnd > len)
  #| {
  #|     throw new Panic("Invalid index for View");
  #| }
  #| return new BytesView(self, actualStart, actualEnd - actualStart);

///|
#alias("_[_:_]")
extern "csharp" fn BytesView::view(
  self : BytesView,
  start? : Int = 0,
  end? : Int,
) -> BytesView =
  #| var len = self.Length;
  #| var actualEnd = end.IsSome ? end.Value : len;
  #| if (actualEnd < 0) actualEnd = len + actualEnd;
  #| var actualStart = start < 0 ? len + start : start;
  #| if (actualStart < 0 || actualStart > actualEnd || actualEnd > len)
  #| {
  #|     throw new Panic("Invalid index for View");
  #| }
  #| return new BytesView(self.Buffer, self.StartOffset + actualStart, actualEnd - actualStart);
