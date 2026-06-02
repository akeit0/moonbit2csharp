extern "csharp" fn Int::to_double(self : Int) -> Double =
  #| return (double)self;

extern "csharp" fn Int::reinterpret_as_uint(self : Int) -> UInt =
  #| return unchecked((uint)self);

extern "csharp" fn Int::max(self : Int, other : Int) -> Int =
  #| return self > other ? self : other;

extern "csharp" fn Int::min(self : Int, other : Int) -> Int =
  #| return self < other ? self : other;

extern "csharp" fn Int::next_power_of_two(self : Int) -> Int =
  #| if (self <= 1) return 1;
  #| var value = (uint)(self - 1);
  #| value |= value >> 1;
  #| value |= value >> 2;
  #| value |= value >> 4;
  #| value |= value >> 8;
  #| value |= value >> 16;
  #| return unchecked((int)(value + 1));

extern "csharp" fn Int::unsafe_to_char(self : Int) -> Char =
  #| return self;

extern "csharp" fn UInt::reinterpret_as_int(self : UInt) -> Int =
  #| return unchecked((int)self);

extern "csharp" fn UInt::to_uint64(self : UInt) -> UInt64 =
  #| return (ulong)self;

extern "csharp" fn UInt16::to_int(self : UInt16) -> Int =
  #| return (int)self;

extern "csharp" fn UInt16::is_leading_surrogate(self : UInt16) -> Bool =
  #| return self is >= 0xD800 and <= 0xDBFF;

extern "csharp" fn UInt16::is_trailing_surrogate(self : UInt16) -> Bool =
  #| return self is >= 0xDC00 and <= 0xDFFF;

extern "csharp" fn UInt16::unsafe_to_char(self : UInt16) -> Char =
  #| return (int)self;

extern "csharp" fn UInt64::to_double(self : UInt64) -> Double =
  #| return (double)self;

extern "csharp" fn UInt64::reinterpret_as_double(self : UInt64) -> Double =
  #| return System.BitConverter.UInt64BitsToDouble(self);

extern "csharp" fn Int64::reinterpret_as_double(self : Int64) -> Double =
  #| return System.BitConverter.Int64BitsToDouble(self);

extern "csharp" fn Char::to_uint(self : Char) -> UInt =
  #| return (uint)self;

extern "csharp" fn Byte::to_uint(self : Byte) -> UInt =
  #| return (uint)self;

extern "csharp" fn Byte::to_double(self : Byte) -> Double =
  #| return (double)self;

extern "csharp" fn[T] physical_equal(a : T, b : T) -> Bool =
  #| return object.ReferenceEquals(a, b);

extern "csharp" fn Bytes::length(self : Bytes) -> Int =
  #| return self.Length;

extern "csharp" fn Bytes::unsafe_get(self : Bytes, idx : Int) -> Byte =
  #| return self[idx];

extern "csharp" fn String::length(self : String) -> Int =
  #| return self.Length;

extern "csharp" fn String::unsafe_get(self : String, idx : Int) -> UInt16 =
  #| return (ushort)self[idx];

extern "csharp" fn[T] FixedArray::length(self : FixedArray[T]) -> Int =
  #| return self.Length;

pub impl BitAnd for UInt with land(self : UInt, other : UInt) -> UInt =
  "%u32.bitand"
