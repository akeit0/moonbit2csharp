package "moonbitlang/core/builtin"


///|
pub extern "csharp" fn[T] ArrayView::length(
  self : ArrayView[T],
) -> Int =
  #|return self.Length;

