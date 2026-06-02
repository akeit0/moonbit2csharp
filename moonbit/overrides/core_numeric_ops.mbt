package "moonbitlang/core/builtin"

///|
pub extern "csharp" fn Byte::to_int(self : Byte) -> Int =
  #|return self;

///|
pub extern "csharp" fn Int::to_byte(self : Int) -> Byte =
  #|return (byte)self;

///|
pub extern "csharp" fn Int16::from_int(value : Int) -> Int16 =
  #|return (short)value;

///|
pub extern "csharp" fn Int16::to_int(self : Int16) -> Int =
  #|return self;

///|
pub extern "csharp" fn Int::to_uint16(self : Int) -> UInt16 =
  #|return (ushort)self;

///|
pub extern "csharp" fn UInt16::to_int(self : UInt16) -> Int =
  #|return self;

///|
pub impl Add for Byte with add(self : Byte, that : Byte) -> Byte {
  (self.to_int() + that.to_int()).to_byte()
}

///|
pub impl Sub for Byte with sub(self : Byte, that : Byte) -> Byte {
  (self.to_int() - that.to_int()).to_byte()
}

///|
pub impl Mul for Byte with mul(self : Byte, that : Byte) -> Byte {
  (self.to_int() * that.to_int()).to_byte()
}

///|
pub impl Div for Byte with div(self : Byte, that : Byte) -> Byte {
  (self.to_int() / that.to_int()).to_byte()
}

///|
pub impl Mod for Byte with mod(self : Byte, that : Byte) -> Byte {
  (self.to_int() % that.to_int()).to_byte()
}

///|
pub impl Eq for Byte with equal(self : Byte, that : Byte) -> Bool {
  self.to_int() == that.to_int()
}

///|
pub impl Eq for Byte with not_equal(self : Byte, that : Byte) -> Bool {
  self.to_int() != that.to_int()
}

///|
pub impl Compare for Byte with compare(self : Byte, that : Byte) -> Int {
  self.to_int().compare(that.to_int())
}

///|
pub impl Compare for Byte with op_lt(x, y) {
  x.to_int() < y.to_int()
}

///|
pub impl Compare for Byte with op_le(x, y) {
  x.to_int() <= y.to_int()
}

///|
pub impl Compare for Byte with op_gt(x, y) {
  x.to_int() > y.to_int()
}

///|
pub impl Compare for Byte with op_ge(x, y) {
  x.to_int() >= y.to_int()
}

///|
pub impl BitAnd for Byte with land(self : Byte, that : Byte) -> Byte {
  (self.to_int() & that.to_int()).to_byte()
}

///|
pub impl BitOr for Byte with lor(self : Byte, that : Byte) -> Byte {
  (self.to_int() | that.to_int()).to_byte()
}

///|
pub impl BitXOr for Byte with lxor(self : Byte, that : Byte) -> Byte {
  (self.to_int() ^ that.to_int()).to_byte()
}

///|
pub impl Shl for Byte with shl(self : Byte, count : Int) -> Byte {
  (self.to_int() << count).to_byte()
}

///|
pub impl Shr for Byte with shr(self : Byte, count : Int) -> Byte {
  (self.to_int() >> count).to_byte()
}

///|
pub impl Add for Int16 with add(self : Int16, that : Int16) -> Int16 {
  Int16::from_int(self.to_int() + that.to_int())
}

///|
pub impl Sub for Int16 with sub(self : Int16, that : Int16) -> Int16 {
  Int16::from_int(self.to_int() - that.to_int())
}

///|
pub impl Mul for Int16 with mul(self : Int16, that : Int16) -> Int16 {
  Int16::from_int(self.to_int() * that.to_int())
}

///|
pub impl Div for Int16 with div(self : Int16, that : Int16) -> Int16 {
  Int16::from_int(self.to_int() / that.to_int())
}

///|
pub impl Mod for Int16 with mod(self : Int16, that : Int16) -> Int16 {
  Int16::from_int(self.to_int() % that.to_int())
}

///|
pub impl Eq for Int16 with equal(self, that) {
  self.to_int() == that.to_int()
}

///|
pub impl Eq for Int16 with not_equal(self, that) {
  self.to_int() != that.to_int()
}

///|
pub impl Compare for Int16 with compare(self, that) {
  self.to_int().compare(that.to_int())
}

///|
pub impl Compare for Int16 with op_lt(x, y) {
  x.to_int() < y.to_int()
}

///|
pub impl Compare for Int16 with op_le(x, y) {
  x.to_int() <= y.to_int()
}

///|
pub impl Compare for Int16 with op_gt(x, y) {
  x.to_int() > y.to_int()
}

///|
pub impl Compare for Int16 with op_ge(x, y) {
  x.to_int() >= y.to_int()
}

///|
pub impl Shl for Int16 with shl(self : Int16, that : Int) -> Int16 {
  Int16::from_int(self.to_int() << that)
}

///|
pub impl Shr for Int16 with shr(self : Int16, that : Int) -> Int16 {
  Int16::from_int(self.to_int() >> that)
}

///|
pub impl BitOr for Int16 with lor(self : Int16, that : Int16) -> Int16 {
  Int16::from_int(self.to_int() | that.to_int())
}

///|
pub impl BitAnd for Int16 with land(self : Int16, that : Int16) -> Int16 {
  Int16::from_int(self.to_int() & that.to_int())
}

///|
pub impl BitXOr for Int16 with lxor(self : Int16, that : Int16) -> Int16 {
  Int16::from_int(self.to_int() ^ that.to_int())
}

///|
pub impl Neg for Int16 with neg(self : Int16) -> Int16 {
  Int16::from_int(-self.to_int())
}

///|
pub impl Add for UInt16 with add(self : UInt16, that : UInt16) -> UInt16 {
  (self.to_int() + that.to_int()).to_uint16()
}

///|
pub impl Sub for UInt16 with sub(self : UInt16, that : UInt16) -> UInt16 {
  (self.to_int() - that.to_int()).to_uint16()
}

///|
pub impl Mul for UInt16 with mul(self : UInt16, that : UInt16) -> UInt16 {
  (self.to_int() * that.to_int()).to_uint16()
}

///|
pub impl Div for UInt16 with div(self : UInt16, that : UInt16) -> UInt16 {
  (self.to_int() / that.to_int()).to_uint16()
}

///|
pub impl Mod for UInt16 with mod(self : UInt16, that : UInt16) -> UInt16 {
  (self.to_int() % that.to_int()).to_uint16()
}

///|
pub impl Eq for UInt16 with equal(self, that) {
  self.to_int() == that.to_int()
}

///|
pub impl Eq for UInt16 with not_equal(self, that) {
  self.to_int() != that.to_int()
}

///|
pub impl Compare for UInt16 with compare(self, that) {
  self.to_int().compare(that.to_int())
}

///|
pub impl Compare for UInt16 with op_lt(x, y) {
  x.to_int() < y.to_int()
}

///|
pub impl Compare for UInt16 with op_le(x, y) {
  x.to_int() <= y.to_int()
}

///|
pub impl Compare for UInt16 with op_gt(x, y) {
  x.to_int() > y.to_int()
}

///|
pub impl Compare for UInt16 with op_ge(x, y) {
  x.to_int() >= y.to_int()
}

///|
pub impl Shl for UInt16 with shl(self : UInt16, that : Int) -> UInt16 {
  (self.to_int() << that).to_uint16()
}

///|
pub impl Shr for UInt16 with shr(self : UInt16, that : Int) -> UInt16 {
  (self.to_int() >> that).to_uint16()
}

///|
pub impl BitOr for UInt16 with lor(self : UInt16, that : UInt16) -> UInt16 {
  (self.to_int() | that.to_int()).to_uint16()
}

///|
pub impl BitAnd for UInt16 with land(self : UInt16, that : UInt16) -> UInt16 {
  (self.to_int() & that.to_int()).to_uint16()
}

///|
pub impl BitXOr for UInt16 with lxor(self : UInt16, that : UInt16) -> UInt16 {
  (self.to_int() ^ that.to_int()).to_uint16()
}

///|
pub impl Neg for Int64 with neg(self : Int64) -> Int64 = "%i64_neg"

///|
pub impl Add for Int64 with add(self, other) = "%i64_add"

///|
pub impl Sub for Int64 with sub(self, other) = "%i64_sub"

///|
pub impl Mul for Int64 with mul(self, other) = "%i64_mul"

///|
pub impl Div for Int64 with div(self, other) = "%i64_div"

///|
pub impl Mod for Int64 with mod(self, other) = "%i64_mod"

///|
pub impl BitAnd for Int64 with land(self, other) = "%i64_land"

///|
pub impl BitOr for Int64 with lor(self, other) = "%i64_lor"

///|
pub impl BitXOr for Int64 with lxor(self, other) = "%i64_lxor"

///|
pub impl Shl for Int64 with shl(self, other) = "%i64_shl"

///|
pub impl Shr for Int64 with shr(self, other) = "%i64_shr"

///|
pub impl Eq for Int64 with equal(self : Int64, other : Int64) -> Bool = "%i64_eq"

///|
pub impl Eq for Int64 with not_equal(self : Int64, other : Int64) -> Bool = "%i64_ne"

///|
pub impl Compare for Int64 with compare(self, other) = "%i64_compare"

///|
pub impl Compare for Int64 with op_lt(x, y) = "%i64.lt"

///|
pub impl Compare for Int64 with op_le(x, y) = "%i64.le"

///|
pub impl Compare for Int64 with op_gt(x, y) = "%i64.gt"

///|
pub impl Compare for Int64 with op_ge(x, y) = "%i64.ge"

///|
pub impl Add for UInt64 with add(self, other) = "%u64.add"

///|
pub impl Sub for UInt64 with sub(self, other) = "%u64.sub"

///|
pub impl Mul for UInt64 with mul(self, other) = "%u64.mul"

///|
pub impl Div for UInt64 with div(self, other) = "%u64.div"

///|
pub impl Mod for UInt64 with mod(self, other) = "%u64.mod"

///|
pub impl Compare for UInt64 with compare(self, other) = "%u64.compare"

///|
pub impl Compare for UInt64 with op_lt(x, y) = "%u64.lt"

///|
pub impl Compare for UInt64 with op_le(x, y) = "%u64.le"

///|
pub impl Compare for UInt64 with op_gt(x, y) = "%u64.gt"

///|
pub impl Compare for UInt64 with op_ge(x, y) = "%u64.ge"

///|
pub impl Eq for UInt64 with equal(self : UInt64, other : UInt64) -> Bool = "%u64.eq"

///|
pub impl Eq for UInt64 with not_equal(self : UInt64, other : UInt64) -> Bool = "%u64.ne"

///|
pub impl BitAnd for UInt64 with land(self, other) = "%u64.bitand"

///|
pub impl BitOr for UInt64 with lor(self, other) = "%u64.bitor"

///|
pub impl BitXOr for UInt64 with lxor(self, other) = "%u64.bitxor"

///|
pub impl Shl for UInt64 with shl(self, shift) = "%u64.shl"

///|
pub impl Shr for UInt64 with shr(self, shift) = "%u64.shr"
