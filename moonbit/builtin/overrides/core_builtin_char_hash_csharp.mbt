///|
pub impl Hash for Char with hash_combine(self, hasher) -> Unit {
  hasher.combine_char(self)
}
