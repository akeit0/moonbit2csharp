pub fn[T] ArrayView::buf(self : ArrayView[T]) -> UninitializedArray[T] =
  "%arrayview.buf"

pub fn[T] ArrayView::start(self : ArrayView[T]) -> Int = "%arrayview.start"

pub fn[T] ArrayView::len(self : ArrayView[T]) -> Int = "%arrayview.len"

pub fn[T] ArrayView::make(
  buf : UninitializedArray[T],
  start : Int,
  len : Int,
) -> ArrayView[T] = "%arrayview.make"

pub fn[T] ArrayView::unsafe_get(
  self : ArrayView[T],
  index : Int,
) -> T = "%arrayview.unsafe_get"
