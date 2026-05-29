struct Iter[X] {
  f : () -> X?
  mut size_hint : Int?
}

pub fn[X] Iter::next(self : Iter[X]) -> X? {
  let result = (self.f)()
  match (result, self.size_hint) {
    (Some(_), Some(n)) =>
      self.size_hint = Some(if n > 0 { n - 1 } else { 0 })
    (None, _) => self.size_hint = Some(0)
    _ => ()
  }
  result
}

pub fn[X] Iter::new(
  f : () -> X?,
  size_hint~ : Int? = None,
) -> Iter[X] {
  { f, size_hint }
}

fn string_view_find_at(
  self : StringView,
  needle : StringView,
  start : Int,
) -> Int? {
  if needle.length() == 0 {
    Some(start)
  } else if needle.length() > self.length() || start > self.length() {
    None
  } else {
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
          let item = self.sub(start=index, end=index + 1)
          index = index + 1
          Some(item)
        }
      },
      size_hint=Some(self.length()),
    )
  }
  let mut remaining = Some(self)
  Iter::new(() => {
    guard remaining is Some(view) else { None }
    guard string_view_find_at(view, sep, 0) is Some(end) else {
      remaining = None
      Some(view)
    }
    remaining = Some(view.sub(start=end + sep_len))
    Some(view.sub(start=0, end=end))
  })
}

pub fn String::split(self : String, sep : StringView) -> Iter[StringView] {
  StringView::split(self.view(), sep)
}
