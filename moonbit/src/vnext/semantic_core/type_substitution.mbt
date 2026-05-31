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
    TypeRef::Function(param_types, return_type, effect) => {
      let mapped_params : Array[ParamTypeRef] = []
      for param in param_types {
        mapped_params.push({
          label: param.label,
          type_: substitute_type(params, args, param.type_),
          optional: param.optional,
          has_default: param.has_default,
        })
      }
      TypeRef::Function(
        mapped_params,
        substitute_type(params, args, return_type),
        substitute_effect(params, args, effect),
      )
    }
    TypeRef::TraitObject(trait_ref) => {
      let mapped_args : Array[TypeRef] = []
      for arg in trait_ref.args {
        mapped_args.push(substitute_type(params, args, arg))
      }
      TypeRef::TraitObject({ trait_: trait_ref.trait_, args: mapped_args })
    }
    _ => type_
  }
}

///|
fn substitute_effect(
  params : Array[String],
  args : Array[TypeRef],
  effect : EffectRef,
) -> EffectRef {
  match effect {
    EffectRef::Raises(error_type) =>
      EffectRef::Raises(substitute_type(params, args, error_type))
    _ => effect
  }
}
