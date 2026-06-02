package "moonbitlang/core/builtin"

///|
pub extern "csharp" fn Bool::to_string(self : Bool) -> String =
  #|return self ? "true" : "false";

///|
pub impl Show for Bool with to_string(self) {
  Bool::to_string(self)
}
