package "moonbitlang/core/builtin"

///|
pub extern "csharp" fn Int::to_string(
  self : Int,
  radix? : Int = 10,
) -> String =
  #|return System.Convert.ToString(self, radix);

///|
pub extern "csharp" fn Int::max(self : Int, other : Int) -> Int =
  #|return self > other ? self : other;

///|
pub extern "csharp" fn Int::next_power_of_two(self : Int) -> Int =
  #|if (self < 0)
  #|{
  #|    throw new Panic("panic");
  #|}
  #|if (self <= 1)
  #|{
  #|    return 1;
  #|}
  #|const int maxPowerOfTwo = 1073741824;
  #|if (self > maxPowerOfTwo)
  #|{
  #|    return maxPowerOfTwo;
  #|}
  #|var value = (uint)(self - 1);
  #|value |= value >> 1;
  #|value |= value >> 2;
  #|value |= value >> 4;
  #|value |= value >> 8;
  #|value |= value >> 16;
  #|return unchecked((int)(value + 1));
