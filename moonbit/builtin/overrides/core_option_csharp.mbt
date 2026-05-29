extern "csharp" fn[T] Option::unwrap(self : T?) -> T =
  #| return self.Unwrap();

pub fn[T] Option::unwrap_or(self : T?, default : T) -> T {
  match self {
    Some(value) => value
    None => default
  }
}
