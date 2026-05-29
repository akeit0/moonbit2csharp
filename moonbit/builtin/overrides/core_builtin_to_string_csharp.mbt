extern "csharp" fn Int::to_string(self : Int, radix? : Int = 10) -> String =
  #| return System.Convert.ToString(self, radix);

extern "csharp" fn Int16::to_string(self : Int16, radix? : Int = 10) -> String =
  #| return System.Convert.ToString(self, radix);

extern "csharp" fn Int64::to_string(self : Int64, radix? : Int = 10) -> String =
  #| return System.Convert.ToString(self, radix);

extern "csharp" fn UInt::to_string(self : UInt, radix? : Int = 10) -> String =
  #| return System.Convert.ToString(self, radix);

extern "csharp" fn UInt16::to_string(self : UInt16, radix? : Int = 10) -> String =
  #| return System.Convert.ToString(self, radix);

extern "csharp" fn UInt64::to_string(self : UInt64, radix? : Int = 10) -> String =
  #| if (radix == 10) return self.ToString(System.Globalization.CultureInfo.InvariantCulture);
  #| if (radix < 2 || radix > 36) throw new MoonBitPanic("radix out of range");
  #| const string digits = "0123456789abcdefghijklmnopqrstuvwxyz";
  #| Span<char> buffer = stackalloc char[64];
  #| var value = self;
  #| var pos = buffer.Length;
  #| do
  #| {
  #|     buffer[--pos] = digits[(int)(value % (ulong)radix)];
  #|     value /= (ulong)radix;
  #| }
  #| while (value != 0);
  #| return new string(buffer[pos..]);

extern "csharp" fn Double::to_string(self : Double) -> String =
  #| return self == 0.0 ? "0" : self.ToString("G17", System.Globalization.CultureInfo.InvariantCulture);

extern "csharp" fn Float::to_string(self : Float) -> String =
  #| return self == 0.0f ? "0" : self.ToString("G9", System.Globalization.CultureInfo.InvariantCulture);

extern "csharp" fn Bool::to_string(self : Bool) -> String =
  #| return self ? "true" : "false";
