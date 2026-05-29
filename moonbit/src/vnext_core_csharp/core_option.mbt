package "moonbitlang/core/builtin"

///|
pub impl[X : Eq] Eq for X? with equal(self, other) {
  match (self, other) {
    (None, None) => true
    (Some(x), Some(y)) => x == y
    _ => false
  }
}

///|
pub extern "csharp" fn[X] Option::unwrap(self : X?) -> X =
  #|return self.Unwrap();
