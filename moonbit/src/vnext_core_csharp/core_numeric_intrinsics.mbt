package "moonbitlang/core/builtin"

///|
pub impl Show for Double with to_string(self) = "%f64_to_string"

///|
pub impl Show for Float with to_string(self) = "%f32_to_string"

///|
pub extern "csharp" fn Double::to_string(self : Double) -> String =
  #|return self == 0.0 ? "0" : self.ToString("G17", System.Globalization.CultureInfo.InvariantCulture);

///|
pub extern "csharp" fn Float::to_string(self : Float) -> String =
  #|return self == 0.0f ? "0" : self.ToString("G9", System.Globalization.CultureInfo.InvariantCulture);

///|
pub extern "csharp" fn Double::mod(self : Double, other : Double) -> Double =
  #|return self % other;

///|
pub extern "csharp" fn Float::to_double(self : Float) -> Double =
  #|return self;

///|
pub extern "csharp" fn Float::from_double(value : Double) -> Float =
  #|return (float)value;

///|
pub impl Neg for Double with neg(self) = "%f64_neg"

///|
pub impl Add for Double with add(self, other) = "%f64_add"

///|
pub impl Sub for Double with sub(self, other) = "%f64_sub"

///|
pub impl Mul for Double with mul(self, other) = "%f64_mul"

///|
pub impl Div for Double with div(self, other) = "%f64_div"

///|
pub impl Mod for Double with mod(self, other) {
  Double::mod(self, other)
}

///|
pub impl Eq for Double with equal(self : Double, other : Double) -> Bool = "%f64_eq"

///|
pub impl Eq for Double with not_equal(self : Double, other : Double) -> Bool = "%f64_ne"

///|
pub impl Compare for Double with compare(self, other) = "%f64_compare"

///|
pub impl Compare for Double with op_lt(x, y) = "%f64.lt"

///|
pub impl Compare for Double with op_le(x, y) = "%f64.le"

///|
pub impl Compare for Double with op_gt(x, y) = "%f64.gt"

///|
pub impl Compare for Double with op_ge(x, y) = "%f64.ge"

///|
pub impl Neg for Float with neg(self) = "%f32.neg"

///|
pub impl Add for Float with add(self, other) = "%f32.add"

///|
pub impl Sub for Float with sub(self, other) = "%f32.sub"

///|
pub impl Mul for Float with mul(self, other) = "%f32.mul"

///|
pub impl Div for Float with div(self, other) = "%f32.div"

///|
pub impl Mod for Float with mod(self, other) {
  Float::from_double(Double::mod(self.to_double(), other.to_double()))
}

///|
pub impl Eq for Float with equal(self : Float, other : Float) -> Bool = "%f32.eq"

///|
pub impl Eq for Float with not_equal(self : Float, other : Float) -> Bool = "%f32.ne"

///|
pub impl Compare for Float with compare(self, other) = "%f32.compare"

///|
pub impl Compare for Float with op_lt(x, y) = "%f32.lt"

///|
pub impl Compare for Float with op_le(x, y) = "%f32.le"

///|
pub impl Compare for Float with op_gt(x, y) = "%f32.gt"

///|
pub impl Compare for Float with op_ge(x, y) = "%f32.ge"
