///|
pub fn resolve_builtin_scalar_type(name : String) -> TypeRef? {
  match name {
    "Byte" => Some(TypeRef::Builtin("Byte"))
    "Int" => Some(@binding.int_type())
    "Int16" => Some(TypeRef::Builtin("Int16"))
    "Int64" => Some(TypeRef::Builtin("Int64"))
    "UInt" => Some(TypeRef::Builtin("UInt"))
    "UInt16" => Some(TypeRef::Builtin("UInt16"))
    "UInt64" => Some(TypeRef::Builtin("UInt64"))
    "Float" => Some(@binding.float_type())
    "Double" => Some(@binding.double_type())
    "Bool" => Some(@binding.bool_type())
    "Char" => Some(@binding.char_type())
    "String" => Some(@binding.string_type())
    "StringView" => Some(@binding.string_view_type())
    "StringBuilder" => Some(TypeRef::Builtin("StringBuilder"))
    "Bytes" => Some(TypeRef::Builtin("Bytes"))
    "BytesView" => Some(TypeRef::Builtin("BytesView"))
    "SourceLoc" => Some(TypeRef::Builtin("SourceLoc"))
    "Error" => Some(TypeRef::Builtin("Error"))
    "Unit" => Some(@binding.unit_type())
    _ => None
  }
}

///|
pub fn builtin_unary_type_constructor(name : String) -> ((TypeRef) -> TypeRef)? {
  match name {
    "Array" => Some(@binding.array_type)
    "FixedArray" => Some(@binding.fixed_array_type)
    "ReadOnlyArray" =>
      Some(fn(item) {
        TypeRef::Apply(TypeConstructorRef::Builtin("ReadOnlyArray"), [item])
      })
    "ArrayView" => Some(@binding.array_view_type)
    "MutArrayView" =>
      Some(fn(item) {
        TypeRef::Apply(TypeConstructorRef::Builtin("MutArrayView"), [item])
      })
    "UninitializedArray" =>
      Some(fn(item) {
        TypeRef::Apply(TypeConstructorRef::Builtin("UninitializedArray"), [item])
      })
    "Option" => Some(@binding.option_type)
    "Ref" =>
      Some(fn(item) {
        TypeRef::Apply(TypeConstructorRef::Builtin("Ref"), [item])
      })
    _ => None
  }
}

///|
pub fn builtin_binary_type_constructor(
  name : String,
) -> ((TypeRef, TypeRef) -> TypeRef)? {
  match name {
    "Map" => Some(@binding.map_type)
    "Result" =>
      Some(fn(ok, err) {
        TypeRef::Apply(TypeConstructorRef::Builtin("Result"), [ok, err])
      })
    _ => None
  }
}
