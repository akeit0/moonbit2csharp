///|
pub fn substitute_type(
  params : Array[String],
  args : Array[TypeRef],
  type_ : TypeRef,
) -> TypeRef {
  match type_ {
    TypeRef::TypeParameter(name, _) => {
      for i in 0..<params.length() {
        if params[i] == name && i < args.length() {
          return args[i]
        }
      }
      type_
    }
    TypeRef::Apply(type_constructor, items) => {
      let mapped : Array[TypeRef] = []
      for item in items {
        mapped.push(substitute_type(params, args, item))
      }
      TypeRef::Apply(type_constructor, mapped)
    }
    TypeRef::Declared(symbol, items) => {
      let mapped : Array[TypeRef] = []
      for item in items {
        mapped.push(substitute_type(params, args, item))
      }
      TypeRef::Declared(symbol, mapped)
    }
    TypeRef::Tuple(items) => {
      let mapped : Array[TypeRef] = []
      for item in items {
        mapped.push(substitute_type(params, args, item))
      }
      TypeRef::Tuple(mapped)
    }
    _ => type_
  }
}
