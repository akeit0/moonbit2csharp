pub fn[T] ArrayView::buf(self : ArrayView[T]) -> UninitializedArray[T] =
  "%arrayview.buf"

pub fn[T] ArrayView::start(self : ArrayView[T]) -> Int = "%arrayview.start"

pub fn[T] ArrayView::len(self : ArrayView[T]) -> Int = "%arrayview.len"

pub fn[T] ArrayView::make(
  buf : UninitializedArray[T],
  start : Int,
  len : Int,
) -> ArrayView[T] = "%arrayview.make"

pub fn[T] ArrayView::length(self : ArrayView[T]) -> Int {
  self.len()
}

pub fn[T] ArrayView::unsafe_get(
  self : ArrayView[T],
  index : Int,
) -> T = "%arrayview.unsafe_get"

pub fn[T] ArrayView::view(
  self : ArrayView[T],
  start? : Int = 0,
  end? : Int,
) -> ArrayView[T] {
  let len = self.length()
  let end = match end {
    None => len
    Some(end) => if end < 0 { len + end } else { end }
  }
  let start = if start < 0 { len + start } else { start }
  guard start >= 0 && start <= end && end <= len else {
    abort("View index out of bounds")
  }
  ArrayView::make(self.buf(), self.start() + start, end - start)
}

pub fn[T] Array::view(
  self : Array[T],
  start? : Int = 0,
  end? : Int,
) -> ArrayView[T] {
  let len = self.length()
  let end = match end {
    None => len
    Some(end) => if end < 0 { len + end } else { end }
  }
  let start = if start < 0 { len + start } else { start }
  guard start >= 0 && start <= end && end <= len else {
    abort("View index out of bounds")
  }
  ArrayView::make(self.buffer(), start, end - start)
}

pub fn[T] FixedArray::view(
  self : FixedArray[T],
  start? : Int = 0,
  end? : Int,
) -> ArrayView[T] {
  let len = self.length()
  let end = match end {
    None => len
    Some(end) => if end < 0 { len + end } else { end }
  }
  let start = if start < 0 { len + start } else { start }
  guard start >= 0 && start <= end && end <= len else {
    abort("View index out of bounds")
  }
  ArrayView::make(self, start, end - start)
}

pub fn[T] ArrayView::to_owned(self : ArrayView[T]) -> Array[T] {
  let result : Array[T] = Array::new(capacity=self.length())
  let mut i = 0
  while i < self.length() {
    result.push(self.unsafe_get(i))
    i = i + 1
  }
  result
}

pub fn[A] ArrayView::blit_to(
  self : ArrayView[A],
  dst : Array[A],
  dst_offset? : Int = 0,
) -> Unit {
  guard dst_offset >= 0 && dst_offset <= dst.length() else {
    abort("index out of bounds")
  }
  let len = self.length()
  if dst_offset + len > dst.length() {
    dst.unsafe_grow_to_length(dst_offset + len)
  }
  for i in 0..<len {
    dst.unsafe_set(dst_offset + i, self.unsafe_get(i))
  }
}

pub fn[T] ArrayView::all(
  self : ArrayView[T],
  f : (T) -> Bool raise?,
) -> Bool raise? {
  for i in 0..<self.length() {
    if f(self.unsafe_get(i)) {
    } else {
      return false
    }
  }
  true
}

pub fn[T] ArrayView::any(
  self : ArrayView[T],
  f : (T) -> Bool raise?,
) -> Bool raise? {
  for i in 0..<self.length() {
    if f(self.unsafe_get(i)) {
      return true
    }
  }
  false
}

pub fn[T, U] ArrayView::map(
  self : ArrayView[T],
  f : (T) -> U raise?,
) -> Array[U] raise? {
  Array::makei(self.length(), fn(i) { f(self.unsafe_get(i)) })
}

pub fn[T, U] ArrayView::mapi(
  self : ArrayView[T],
  f : (Int, T) -> U raise?,
) -> Array[U] raise? {
  Array::makei(self.length(), fn(i) { f(i, self.unsafe_get(i)) })
}

pub fn[T : Eq] ArrayView::starts_with(
  self : ArrayView[T],
  prefix : ArrayView[T],
) -> Bool {
  if prefix.length() > self.length() {
    return false
  }
  for i in 0..<prefix.length() {
    if self.unsafe_get(i) != prefix.unsafe_get(i) {
      return false
    }
  }
  true
}

pub fn[T : Eq] ArrayView::ends_with(
  self : ArrayView[T],
  suffix : ArrayView[T],
) -> Bool {
  let offset = self.length() - suffix.length()
  if offset < 0 {
    return false
  }
  for i in 0..<suffix.length() {
    if self.unsafe_get(offset + i) != suffix.unsafe_get(i) {
      return false
    }
  }
  true
}

pub fn[T : Eq] ArrayView::strip_prefix(
  self : ArrayView[T],
  prefix : ArrayView[T],
) -> ArrayView[T]? {
  if self.starts_with(prefix) {
    Some(self.view(start=prefix.length()))
  } else {
    None
  }
}

pub fn[T : Eq] ArrayView::strip_suffix(
  self : ArrayView[T],
  suffix : ArrayView[T],
) -> ArrayView[T]? {
  if self.ends_with(suffix) {
    Some(self.view(end=self.length() - suffix.length()))
  } else {
    None
  }
}

pub fn[T : Eq] ArrayView::search(
  self : ArrayView[T],
  needle : ArrayView[T],
) -> Int? {
  if needle.length() == 0 {
    return Some(0)
  }
  if needle.length() > self.length() {
    return None
  }
  for i in 0..<(self.length() - needle.length() + 1) {
    if self.view(start=i, end=i + needle.length()).starts_with(needle) {
      return Some(i)
    }
  }
  None
}

pub fn[T] MutArrayView::buf(self : MutArrayView[T]) -> UninitializedArray[T] =
  "%arrayview.buf"

pub fn[T] MutArrayView::start(self : MutArrayView[T]) -> Int =
  "%arrayview.start"

pub fn[T] MutArrayView::len(self : MutArrayView[T]) -> Int = "%arrayview.len"

pub fn[T] MutArrayView::make(
  buf : UninitializedArray[T],
  start : Int,
  len : Int,
) -> MutArrayView[T] = "%arrayview.make"

pub fn[T] MutArrayView::length(self : MutArrayView[T]) -> Int {
  self.len()
}

pub fn[T] MutArrayView::unsafe_get(
  self : MutArrayView[T],
  index : Int,
) -> T = "%arrayview.unsafe_get"

pub fn[T] MutArrayView::unsafe_set(
  self : MutArrayView[T],
  index : Int,
  value : T,
) -> Unit = "%arrayview.unsafe_set"

pub fn[T] MutArrayView::view(
  self : MutArrayView[T],
  start? : Int = 0,
  end? : Int,
) -> ArrayView[T] {
  let len = self.length()
  let end = match end {
    None => len
    Some(end) => if end < 0 { len + end } else { end }
  }
  let start = if start < 0 { len + start } else { start }
  guard start >= 0 && start <= end && end <= len else {
    abort("View index out of bounds")
  }
  ArrayView::make(self.buf(), self.start() + start, end - start)
}

pub fn[T] MutArrayView::mut_view(
  self : MutArrayView[T],
  start? : Int = 0,
  end? : Int,
) -> MutArrayView[T] {
  let len = self.length()
  let end = match end {
    None => len
    Some(end) => if end < 0 { len + end } else { end }
  }
  let start = if start < 0 { len + start } else { start }
  guard start >= 0 && start <= end && end <= len else {
    abort("View index out of bounds")
  }
  MutArrayView::make(self.buf(), self.start() + start, end - start)
}

pub fn[T] Array::mut_view(
  self : Array[T],
  start? : Int = 0,
  end? : Int,
) -> MutArrayView[T] {
  let len = self.length()
  let end = match end {
    None => len
    Some(end) => if end < 0 { len + end } else { end }
  }
  let start = if start < 0 { len + start } else { start }
  guard start >= 0 && start <= end && end <= len else {
    abort("View index out of bounds")
  }
  MutArrayView::make(self.buffer(), start, end - start)
}

pub fn[T] FixedArray::mut_view(
  self : FixedArray[T],
  start? : Int = 0,
  end? : Int,
) -> MutArrayView[T] {
  let len = self.length()
  let end = match end {
    None => len
    Some(end) => if end < 0 { len + end } else { end }
  }
  let start = if start < 0 { len + start } else { start }
  guard start >= 0 && start <= end && end <= len else {
    abort("View index out of bounds")
  }
  MutArrayView::make(self, start, end - start)
}

pub fn[T] MutArrayView::to_owned(self : MutArrayView[T]) -> Array[T] {
  self.view().to_owned()
}
