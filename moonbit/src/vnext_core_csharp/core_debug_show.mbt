package "moonbitlang/core/debug"

using @builtin { trait Show }

///|
pub impl Show for Repr with to_string(self) {
  render(self)
}
