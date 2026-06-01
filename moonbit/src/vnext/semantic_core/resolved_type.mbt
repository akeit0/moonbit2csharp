///|
pub(all) enum TypeDefKind {
  Struct
  Enum
  Trait
  Builtin
  Alias
  ErrorType
  Opaque
} derive(Eq, Debug)

///|
#valtype
pub(all) struct TypeDefId {
  package_id : String
  module_path : String
  name : String
  arity : Int
  kind : TypeDefKind
} derive(Eq, Debug)

///|
pub(all) struct ResolvedTraitRef {
  trait_id : TypeDefId
  args : Array[ResolvedType]
} derive(Eq, Debug)

///|
pub(all) struct ResolvedParamType {
  label : String?
  type_ : ResolvedType
  optional : Bool
  has_default : Bool
} derive(Eq, Debug)

///|
pub(all) enum ResolvedEffect {
  NoRaise
  Raises(ResolvedType)
  RaisePolymorphic(String?)
  UnknownEffect(String)
} derive(Eq, Debug)

///|
pub(all) enum ResolvedType {
  Invalid(String)
  Unknown(String)
  Builtin(String)
  Nominal(TypeDefId, Array[ResolvedType])
  TypeParam(String, String)
  Tuple(Array[ResolvedType])
  Function(Array[ResolvedParamType], ResolvedType, ResolvedEffect)
  Array(ResolvedType)
  FixedArray(ResolvedType)
  ArrayView(ResolvedType)
  Option(ResolvedType)
  TraitObject(ResolvedTraitRef)
} derive(Eq, Debug)

///|
pub fn type_def_id_from_symbol(
  symbol : TypeSymbolRef,
  arity : Int,
  kind? : TypeDefKind = TypeDefKind::Struct,
) -> TypeDefId {
  {
    package_id: symbol.package_id,
    module_path: symbol.module_path,
    name: symbol.name,
    arity,
    kind,
  }
}

///|
pub fn resolved_type_from_type_ref(type_ : TypeRef) -> ResolvedType {
  match type_ {
    TypeRef::Builtin(name) => ResolvedType::Builtin(name)
    TypeRef::Declared(symbol, [item]) =>
      match resolved_core_builtin_type(symbol, item) {
        Some(resolved) => resolved
        None => resolved_nominal_type(symbol, [item])
      }
    TypeRef::Declared(symbol, args) => resolved_nominal_type(symbol, args)
    TypeRef::TypeParameter(name, symbol_id) =>
      ResolvedType::TypeParam(name, symbol_id)
    TypeRef::Tuple(items) => {
      let resolved_items : Array[ResolvedType] = []
      for item in items {
        resolved_items.push(resolved_type_from_type_ref(item))
      }
      ResolvedType::Tuple(resolved_items)
    }
    TypeRef::Function(params, return_type, effect) => {
      let resolved_params : Array[ResolvedParamType] = []
      for param in params {
        resolved_params.push({
          label: param.label,
          type_: resolved_type_from_type_ref(param.type_),
          optional: param.optional,
          has_default: param.has_default,
        })
      }
      ResolvedType::Function(
        resolved_params,
        resolved_type_from_type_ref(return_type),
        resolved_effect_from_effect_ref(effect),
      )
    }
    TypeRef::Apply(TypeConstructorRef::Builtin("Array"), [item]) =>
      ResolvedType::Array(resolved_type_from_type_ref(item))
    TypeRef::Apply(TypeConstructorRef::Builtin("FixedArray"), [item]) =>
      ResolvedType::FixedArray(resolved_type_from_type_ref(item))
    TypeRef::Apply(TypeConstructorRef::Builtin("ArrayView"), [item]) =>
      ResolvedType::ArrayView(resolved_type_from_type_ref(item))
    TypeRef::Apply(TypeConstructorRef::Builtin("Option"), [item]) =>
      ResolvedType::Option(resolved_type_from_type_ref(item))
    TypeRef::Apply(TypeConstructorRef::Declared(symbol), [item]) =>
      match resolved_core_builtin_type(symbol, item) {
        Some(resolved) => resolved
        None =>
          ResolvedType::Nominal(
            type_def_id_from_constructor(
              TypeConstructorRef::Declared(symbol),
              1,
            ),
            [resolved_type_from_type_ref(item)],
          )
      }
    TypeRef::Apply(type_constructor, args) => {
      let resolved_args : Array[ResolvedType] = []
      for arg in args {
        resolved_args.push(resolved_type_from_type_ref(arg))
      }
      ResolvedType::Nominal(
        type_def_id_from_constructor(type_constructor, args.length()),
        resolved_args,
      )
    }
    TypeRef::TraitObject(trait_ref) => {
      let resolved_args : Array[ResolvedType] = []
      for arg in trait_ref.args {
        resolved_args.push(resolved_type_from_type_ref(arg))
      }
      ResolvedType::TraitObject({
        trait_id: type_def_id_from_symbol(
          trait_ref.trait_,
          trait_ref.args.length(),
          kind=TypeDefKind::Trait,
        ),
        args: resolved_args,
      })
    }
    TypeRef::Unknown(reason) => ResolvedType::Unknown(reason)
    TypeRef::Error(reason) => ResolvedType::Invalid(reason)
  }
}

///|
fn type_def_id_from_constructor(
  type_constructor : TypeConstructorRef,
  arity : Int,
) -> TypeDefId {
  match type_constructor {
    TypeConstructorRef::Builtin(name) =>
      {
        package_id: "pkg:moonbitlang/core/builtin",
        module_path: "",
        name,
        arity,
        kind: TypeDefKind::Builtin,
      }
    TypeConstructorRef::Declared(symbol) =>
      type_def_id_from_symbol(symbol, arity)
    TypeConstructorRef::TypeParameter(name, _) =>
      { package_id: "", module_path: "", name, arity, kind: TypeDefKind::Alias }
  }
}

///|
fn resolved_core_builtin_type(
  symbol : TypeSymbolRef,
  item : TypeRef,
) -> ResolvedType? {
  match @binding.core_builtin_type_symbol_name(symbol) {
    Some("Array") =>
      Some(ResolvedType::Array(resolved_type_from_type_ref(item)))
    Some("FixedArray") =>
      Some(ResolvedType::FixedArray(resolved_type_from_type_ref(item)))
    Some("ArrayView") =>
      Some(ResolvedType::ArrayView(resolved_type_from_type_ref(item)))
    Some("Option") =>
      Some(ResolvedType::Option(resolved_type_from_type_ref(item)))
    _ => None
  }
}

///|
fn resolved_nominal_type(
  symbol : TypeSymbolRef,
  args : FixedArray[TypeRef],
) -> ResolvedType {
  let resolved_args : Array[ResolvedType] = []
  for arg in args {
    resolved_args.push(resolved_type_from_type_ref(arg))
  }
  ResolvedType::Nominal(
    type_def_id_from_symbol(symbol, args.length()),
    resolved_args,
  )
}

///|
fn resolved_effect_from_effect_ref(effect : EffectRef) -> ResolvedEffect {
  match effect {
    EffectRef::NoRaise => ResolvedEffect::NoRaise
    EffectRef::Raises(error_type) =>
      ResolvedEffect::Raises(resolved_type_from_type_ref(error_type))
    EffectRef::RaisePolymorphic(symbol) =>
      ResolvedEffect::RaisePolymorphic(symbol)
    EffectRef::UnknownEffect(reason) => ResolvedEffect::UnknownEffect(reason)
  }
}

///|
pub fn resolved_type_equal(left : ResolvedType, right : ResolvedType) -> Bool {
  left == right
}

///|
pub fn resolved_type_has_invalid_or_unknown(type_ : ResolvedType) -> Bool {
  match type_ {
    Invalid(_) | Unknown(_) => true
    Nominal(_, args) | Tuple(args) =>
      resolved_type_array_has_invalid_or_unknown(args)
    Function(params, return_type, effect) => {
      for param in params {
        if resolved_type_has_invalid_or_unknown(param.type_) {
          return true
        }
      }
      resolved_type_has_invalid_or_unknown(return_type) ||
      resolved_effect_has_invalid_or_unknown(effect)
    }
    Array(item) | FixedArray(item) | ArrayView(item) | Option(item) =>
      resolved_type_has_invalid_or_unknown(item)
    TraitObject(trait_ref) =>
      resolved_type_array_has_invalid_or_unknown(trait_ref.args)
    _ => false
  }
}

///|
fn resolved_type_array_has_invalid_or_unknown(
  items : Array[ResolvedType],
) -> Bool {
  for item in items {
    if resolved_type_has_invalid_or_unknown(item) {
      return true
    }
  }
  false
}

///|
fn resolved_effect_has_invalid_or_unknown(effect : ResolvedEffect) -> Bool {
  match effect {
    Raises(type_) => resolved_type_has_invalid_or_unknown(type_)
    UnknownEffect(_) => true
    _ => false
  }
}
