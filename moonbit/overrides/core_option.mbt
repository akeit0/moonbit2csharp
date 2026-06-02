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

///|
pub fn[X : Show] Option::to_string(self : X?) -> String {
  match self {
    None => "None"
    Some(value) => "Some(" + value.to_string() + ")"
  }
}

///|
pub fn[T] Option::unwrap_or(self : T?, default : T) -> T {
  match self {
    None => default
    Some(value) => value
  }
}
