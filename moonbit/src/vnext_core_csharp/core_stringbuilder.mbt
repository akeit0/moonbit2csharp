package "moonbitlang/core/builtin"

///|
pub extern "csharp" fn StringBuilder::new(
  size_hint? : Int = 0,
) -> StringBuilder =
  #|return new StringBuilder(size_hint);

///|
pub extern "csharp" fn StringBuilder::is_empty(self : StringBuilder) -> Bool =
  #|return self.ToString().Length == 0;

///|
pub extern "csharp" fn StringBuilder::reset(self : StringBuilder) -> Unit =
  #|return self.Reset();

///|
pub extern "csharp" fn StringBuilder::to_string(self : StringBuilder) -> String =
  #|return self.ToString();

///|
pub extern "csharp" fn StringBuilder::write_stringview(
  self : StringBuilder,
  value : StringView,
) -> Unit =
  #|return self.WriteString(value);

///|
pub fn[T : Show] StringBuilder::write_object(
  self : StringBuilder,
  value : T,
) -> Unit {
  value.output(self)
}
