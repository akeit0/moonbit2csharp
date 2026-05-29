package "moonbitlang/core/builtin"

///|
pub fn[X] Iter::new(f : () -> X?, size_hint? : Int) -> Iter[X] = "%iter_new"

///|
pub fn[X] Iter::next(self : Iter[X]) -> X? = "%iter_next"

///|
pub fn[X] Iter::size_hint(self : Iter[X]) -> Int? = "%iter_size_hint"

///|
pub extern "csharp" fn[X, Y] Iter::map(
  self : Iter[X],
  f : (X) -> Y,
) -> Iter[Y] =
  #|return new MoonBitIter<Y>(() =>
  #|{
  #|    var next = self.Next();
  #|    return next.IsSome
  #|        ? MoonBitOption<Y>.Some(f(next.Value))
  #|        : MoonBitOption<Y>.None();
  #|});

///|
pub fn[X] Iter::any(self : Iter[X], f : (X) -> Bool) -> Bool {
  let mut result = false
  let mut done = false
  while !done {
    match self.next() {
      Some(x) =>
        if f(x) {
          result = true
          done = true
        }
      None => done = true
    }
  }
  result
}

///|
pub fn[X] Iter::all(self : Iter[X], f : (X) -> Bool) -> Bool {
  let mut result = true
  let mut done = false
  while !done {
    match self.next() {
      Some(x) =>
        if !f(x) {
          result = false
          done = true
        }
      None => done = true
    }
  }
  result
}

///|
pub fn[X] Iter::to_array(self : Iter[X]) -> Array[X] {
  let result = Array::new()
  let mut done = false
  while !done {
    match self.next() {
      Some(x) => result.push(x)
      None => done = true
    }
  }
  result
}
