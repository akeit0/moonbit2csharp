package "moonbitlang/core/builtin"

///|
pub extern "csharp" fn[T] ArrayView::length(
  self : ArrayView[T],
) -> Int =
  #|return self.Length;

///|
pub extern "csharp" fn[X] ArrayView::iter(self : ArrayView[X]) -> Iter[X] =
  #|var index = 0;
  #|return new MoonBitIter<X>(() =>
  #|{
  #|    if (index >= self.Length)
  #|    {
  #|        return MoonBitOption<X>.None();
  #|    }
  #|    return MoonBitOption<X>.Some(self.Buffer[self.StartOffset + index++]);
  #|});
