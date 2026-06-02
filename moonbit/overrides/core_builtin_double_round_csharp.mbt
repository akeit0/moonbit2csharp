#as_free_fn
pub fn Double::trunc(self : Double) -> Double = "System.Math" "Truncate"

#as_free_fn
pub fn Double::ceil(self : Double) -> Double = "System.Math" "Ceiling"

#as_free_fn
pub fn Double::floor(self : Double) -> Double = "System.Math" "Floor"

#as_free_fn
pub fn Double::round(self : Double) -> Double {
  (self + 0.5).floor()
}
