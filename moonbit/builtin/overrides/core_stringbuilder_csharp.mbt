type StringBuilder

extern "csharp" fn StringBuilder::new(
  size_hint? : Int = 0,
) -> StringBuilder =
  #| return new MoonBitStringBuilder(size_hint);

extern "csharp" fn StringBuilder::to_string(self : StringBuilder) -> String =
  #| return self.ToString();

extern "csharp" fn StringBuilder::is_empty(self : StringBuilder) -> Bool =
  #| return self.ToString().Length == 0;

extern "csharp" fn StringBuilder::reset(self : StringBuilder) -> Unit =
  #| return self.Reset();
