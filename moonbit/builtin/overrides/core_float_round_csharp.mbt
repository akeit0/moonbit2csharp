#as_free_fn
pub fn Float::trunc(self : Float) -> Float = "System.MathF" "Truncate"

#as_free_fn
pub fn Float::ceil(self : Float) -> Float = "System.MathF" "Ceiling"

#as_free_fn
pub fn Float::floor(self : Float) -> Float = "System.MathF" "Floor"

#as_free_fn
pub fn Float::round(self : Float) -> Float {
  floor(self + 0.5)
}
