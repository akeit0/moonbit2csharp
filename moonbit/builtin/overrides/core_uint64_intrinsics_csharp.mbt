pub fn Int64::reinterpret_as_uint64(self : Int64) -> UInt64 =
  "%i64.to_u64_reinterpret"

pub fn UInt64::reinterpret_as_int64(self : UInt64) -> Int64 =
  "%u64.to_i64_reinterpret"

pub fn UInt64::to_uint(self : UInt64) -> UInt = "%u64.to_u32"

pub fn Double::reinterpret_as_int64(self : Double) -> Int64 =
  "%f64_to_i64_reinterpret"
