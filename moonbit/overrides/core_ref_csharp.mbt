package "moonbitlang/core/ref"

pub(all) struct Ref[T] {
  mut val : T
}

pub fn[T] new(x : T) -> Ref[T] {
  { val: x }
}

#alias(new, deprecated)
pub fn[T] Ref::Ref(x : T) -> Self[T] {
  { val: x }
}

#deprecated("Use Debug instead of Show for debugging purposes. See https://github.com/moonbitlang/core/blob/main/debug/README.mbt.md")
pub impl[X : Show] Show for Ref[X]

pub impl[X : Show] Show for Ref[X] with to_string(self) {
  "{val: " + self.val.to_string() + "}"
}
