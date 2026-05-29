extern "csharp" fn String::view(
  self : String,
  start_offset? : Int = 0,
  end_offset? : Int,
) -> StringView =
  #| var start = start_offset < 0 ? self.Length + start_offset : start_offset;
  #| var end = end_offset.IsSome ? end_offset.Unwrap() : self.Length;
  #| if (end < 0) end = self.Length + end;
  #| return new MoonBitStringView(self, start, end);

extern "csharp" fn StringView::str(self : StringView) -> String =
  #| return self.Data;

pub fn StringView::data(self : StringView) -> String {
  self.str()
}

extern "csharp" fn StringView::start(self : StringView) -> Int =
  #| return self.Start;

pub fn StringView::start_offset(self : StringView) -> Int {
  self.start()
}

extern "csharp" fn StringView::end(self : StringView) -> Int =
  #| return self.End;

extern "csharp" fn StringView::length(self : StringView) -> Int =
  #| return self.Length;

extern "csharp" fn StringView::unsafe_get(
  self : StringView,
  index : Int,
) -> UInt16 =
  #| return self[index];

#alias(code_unit_at)
extern "csharp" fn StringView::at(
  self : StringView,
  index : Int,
) -> UInt16 =
  #| return self[index];

#alias(to_string, deprecated)
extern "csharp" fn StringView::to_owned(self : StringView) -> String =
  #| return self.ToString();

extern "csharp" fn StringView::sub(
  self : StringView,
  start : Int,
  end? : Int,
) -> StringView =
  #| return self.Sub(start, end.IsSome ? end.Unwrap() : null);

extern "csharp" fn StringView::view(
  self : StringView,
  start_offset? : Int = 0,
  end_offset? : Int,
) -> StringView =
  #| return self.Sub(start_offset, end_offset.IsSome ? end_offset.Unwrap() : null);
