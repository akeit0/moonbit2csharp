pub(all) enum IterResult {
  IterEnd
  IterContinue
} derive(Eq)

struct Iter[X] {
  f : () -> X?
  mut size_hint : Int?
}

struct Iter2[X, Y] {
  iter : Iter[(X, Y)]
}

pub fn[X] Iter::next(self : Iter[X]) -> X? {
  let result = (self.f)()
  match (result, self.size_hint) {
    (Some(_), Some(n)) =>
      self.size_hint = if n > 0 { Some(n - 1) } else { Some(0) }
    (None, _) => self.size_hint = Some(0)
    _ => ()
  }
  result
}

pub fn[X] Iter::size_hint(self : Iter[X]) -> Int? {
  self.size_hint
}

pub fn[X] Iter::new(f : () -> X?, size_hint? : Int) -> Iter[X] {
  { f, size_hint }
}

pub fn[X] Iter::filter(self : Iter[X], f : (X) -> Bool) -> Iter[X] {
  Iter::new(() => {
    let mut done = false
    let mut result : X? = None
    while done == false {
      let next = self.next()
      match next {
        Some(x) =>
          if f(x) {
            result = Some(x)
            done = true
          }
        None => done = true
      }
    }
    result
  })
}

#locals(f)
pub fn[X, R] Iter::fold(
  self : Iter[X],
  f : (R, X) -> R,
  init~ : R,
) -> R {
  let mut acc = init
  let mut done = false
  while done == false {
    let next = self.next()
    if next is Some(x) {
      acc = f(acc, x)
    } else {
      done = true
    }
  }
  acc
}

pub fn[X] Iter::iter(self : Iter[X]) -> Iter[X] {
  self
}

pub fn[X, Y] Iter::map(self : Iter[X], f : (X) -> Y) -> Iter[Y] {
  Iter::new(
    () => {
      match self.next() {
        Some(item) => Some(f(item))
        None => None
      }
    },
    size_hint=self.size_hint(),
  )
}

pub fn[X, Y] Iter2::new(
  f : () -> (X, Y)?,
  size_hint? : Int,
) -> Iter2[X, Y] {
  { iter: Iter::new(f, size_hint~) }
}

pub fn[X, Y] Iter2::iter(self : Iter2[X, Y]) -> Iter[(X, Y)] {
  self.iter
}

pub fn[X, Y] Iter2::iter2(self : Iter2[X, Y]) -> Iter2[X, Y] {
  self
}

pub fn[X, Y] Iter2::next(self : Iter2[X, Y]) -> (X, Y)? {
  self.iter.next()
}

pub fn[X, Y] Iter2::each(
  self : Iter2[X, Y],
  f : (X, Y) -> Unit,
) -> Unit {
  let mut done = false
  while done == false {
    match self.next() {
      Some((x, y)) => f(x, y)
      None => done = true
    }
  }
}

pub fn[X, Y] Iter2::to_array(self : Iter2[X, Y]) -> Array[(X, Y)] {
  self.iter.collect()
}

pub fn[T] Array::iter(self : Array[T]) -> Iter[T] {
  let mut index = 0
  let len = self.length()
  Iter::new(
    () => {
      if index >= len {
        None
      } else {
        let item = self.unsafe_get(index)
        index = index + 1
        Some(item)
      }
    },
    size_hint=len,
  )
}

pub fn[X] ArrayView::iter(self : ArrayView[X]) -> Iter[X] {
  let mut index = 0
  let len = self.length()
  Iter::new(
    () => {
      if index >= len {
        None
      } else {
        let item = self.unsafe_get(index)
        index = index + 1
        Some(item)
      }
    },
    size_hint=len,
  )
}

pub fn StringView::iter(self : StringView) -> Iter[Char] {
  let mut index = 0
  let len = self.length()
  Iter::new(
    () => {
      if index >= len {
        None
      } else {
        let c1 = self.unsafe_get(index)
        if c1.is_leading_surrogate() && index + 1 < len {
          let c2 = self.unsafe_get(index + 1)
          if c2.is_trailing_surrogate() {
            index = index + 2
            return Some(
              ((c1.to_int() - 0xD800) * 0x400 + c2.to_int() - 0xDC00 + 0x10000).unsafe_to_char(),
            )
          }
        }
        index = index + 1
        Some(c1.unsafe_to_char())
      }
    },
    size_hint=len,
  )
}

pub fn Int::until(self : Int, end : Int) -> Iter[Int] {
  let mut current = self
  Iter::new(() => {
    if current >= end {
      None
    } else {
      let item = current
      current = current + 1
      Some(item)
    }
  })
}

#alias(collect)
pub fn[X] Iter::to_array(self : Iter[X]) -> Array[X] {
  let result : Array[X] = []
  let mut done = false
  while done == false {
    let next = self.next()
    match next {
      Some(item) => result.push(item)
      None => done = true
    }
  }
  result
}

pub fn[X] Iter::any(self : Iter[X], f : (X) -> Bool) -> Bool {
  let mut found = false
  let mut done = false
  while done == false && found == false {
    match self.next() {
      Some(value) => found = f(value)
      None => done = true
    }
  }
  found
}

pub fn string_view_find_at(
  self : StringView,
  needle : StringView,
  start : Int,
) -> Int? {
  if needle.length() == 0 {
    return Some(start)
  }
  let limit = self.length() - needle.length()
  let mut i = start
  while i <= limit {
    let mut j = 0
    let mut ok = true
    while j < needle.length() {
      if self.unsafe_get(i + j) != needle.unsafe_get(j) {
        ok = false
        break
      }
      j = j + 1
    }
    if ok {
      return Some(i)
    }
    i = i + 1
  }
  None
}

pub fn StringView::split(
  self : StringView,
  sep : StringView,
) -> Iter[StringView] {
  let sep_len = sep.length()
  if sep_len == 0 {
      let mut index = 0
      return Iter::new(
      () => {
        if index >= self.length() {
          None
        } else {
          let item = self.view(start_offset=index, end_offset=index + 1)
          index = index + 1
          Some(item)
        }
      },
      size_hint=self.length(),
    )
  }
  let mut remaining = Some(self)
  Iter::new(() => {
    guard remaining is Some(view) else { None }
    let limit = view.length() - sep_len
    let mut i = 0
    let mut found : Int? = None
    while i <= limit && found is None {
      let mut j = 0
      let mut ok = true
      while j < sep_len {
        if view.unsafe_get(i + j) != sep.unsafe_get(j) {
          ok = false
          break
        }
        j = j + 1
      }
      if ok {
        found = Some(i)
      }
      i = i + 1
    }
    guard found is Some(end) else {
      remaining = None
      Some(view)
    }
    remaining = Some(view.view(start_offset=end + sep_len))
    Some(view.view(start_offset=0, end_offset=end))
  })
}

pub fn String::split(self : String, sep : StringView) -> Iter[StringView] {
  self.view(start_offset=0).split(sep)
}
