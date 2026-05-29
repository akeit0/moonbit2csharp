///|
using @binding {char_literal_pattern_types_compatible, type_equal}

///|
pub(all) struct TypeSubstitution {
  variable : String
  type_ : TypeRef
} derive(Eq, Debug)

///|
pub(all) struct TypingContext {
  substitutions : Array[TypeSubstitution]
} derive(Eq, Debug)

///|
pub fn typing_context() -> TypingContext {
  { substitutions: [] }
}

///|
pub fn inference_type(name : String) -> TypeRef {
  TypeRef::Unknown("infer:" + name)
}

///|
pub fn local_inference_type(symbol_id : String) -> TypeRef {
  TypeRef::Unknown("local-type:" + symbol_id)
}

///|
pub fn resolve_inferred_type(
  context : TypingContext,
  type_ : TypeRef,
) -> TypeRef {
  match type_ {
    TypeRef::Unknown(reason) =>
      match find_substitution(context, reason) {
        Some(resolved) => resolve_inferred_type(context, resolved)
        None => type_
      }
    TypeRef::TypeParameter(name, symbol_id) =>
      match find_substitution(context, symbol_id) {
        Some(resolved) => resolve_inferred_type(context, resolved)
        None => TypeRef::TypeParameter(name, symbol_id)
      }
    TypeRef::Declared(symbol, args) => {
      let resolved_args : Array[TypeRef] = []
      for arg in args {
        resolved_args.push(resolve_inferred_type(context, arg))
      }
      TypeRef::Declared(symbol, resolved_args)
    }
    TypeRef::Tuple(items) => {
      let resolved_items : Array[TypeRef] = []
      for item in items {
        resolved_items.push(resolve_inferred_type(context, item))
      }
      TypeRef::Tuple(resolved_items)
    }
    TypeRef::Function(params, return_type, effect) => {
      let resolved_params : Array[ParamTypeRef] = []
      for param in params {
        resolved_params.push({
          label: param.label,
          type_: resolve_inferred_type(context, param.type_),
          optional: param.optional,
          has_default: param.has_default,
        })
      }
      TypeRef::Function(
        resolved_params,
        resolve_inferred_type(context, return_type),
        resolve_inferred_effect(context, effect),
      )
    }
    TypeRef::Apply(type_constructor, args) => {
      let resolved_args : Array[TypeRef] = []
      for arg in args {
        resolved_args.push(resolve_inferred_type(context, arg))
      }
      TypeRef::Apply(type_constructor, resolved_args)
    }
    TypeRef::TraitObject(trait_ref) => {
      let resolved_args : Array[TypeRef] = []
      for arg in trait_ref.args {
        resolved_args.push(resolve_inferred_type(context, arg))
      }
      TypeRef::TraitObject({ trait_: trait_ref.trait_, args: resolved_args })
    }
    _ => type_
  }
}

///|
pub fn unify_types(
  context : TypingContext,
  expected : TypeRef,
  actual : TypeRef,
) -> Bool {
  let expected = resolve_inferred_type(context, expected)
  let actual = resolve_inferred_type(context, actual)
  match inference_variable_key(expected) {
    Some(key) => bind_inference_variable(context, key, actual)
    None =>
      match inference_variable_key(actual) {
        Some(key) => bind_inference_variable(context, key, expected)
        None => unify_concrete_types(context, expected, actual)
      }
  }
}

///|
pub fn instantiate_function_type(
  _context : TypingContext,
  type_params : Array[String],
  type_ : TypeRef,
) -> TypeRef {
  instantiate_type_params(type_params, type_, "call:")
}

///|
pub fn instantiate_function_type_at_call_site(
  _context : TypingContext,
  type_params : Array[String],
  type_ : TypeRef,
  call_site_key : String,
) -> TypeRef {
  instantiate_type_params(type_params, type_, "call:" + call_site_key + ":")
}

///|
fn instantiate_type_params(
  type_params : Array[String],
  type_ : TypeRef,
  prefix : String,
) -> TypeRef {
  match type_ {
    TypeRef::TypeParameter(name, _) =>
      if contains_type_param(type_params, name) {
        inference_type(prefix + name)
      } else {
        type_
      }
    TypeRef::Declared(symbol, args) => {
      let result : Array[TypeRef] = []
      for arg in args {
        result.push(instantiate_type_params(type_params, arg, prefix))
      }
      TypeRef::Declared(symbol, result)
    }
    TypeRef::Tuple(items) => {
      let result : Array[TypeRef] = []
      for item in items {
        result.push(instantiate_type_params(type_params, item, prefix))
      }
      TypeRef::Tuple(result)
    }
    TypeRef::Function(params, return_type, effect) => {
      let result : Array[ParamTypeRef] = []
      for param in params {
        result.push({
          label: param.label,
          type_: instantiate_type_params(type_params, param.type_, prefix),
          optional: param.optional,
          has_default: param.has_default,
        })
      }
      TypeRef::Function(
        result,
        instantiate_type_params(type_params, return_type, prefix),
        effect,
      )
    }
    TypeRef::Apply(type_constructor, args) => {
      let result : Array[TypeRef] = []
      for arg in args {
        result.push(instantiate_type_params(type_params, arg, prefix))
      }
      TypeRef::Apply(type_constructor, result)
    }
    TypeRef::TraitObject(trait_ref) => {
      let result : Array[TypeRef] = []
      for arg in trait_ref.args {
        result.push(instantiate_type_params(type_params, arg, prefix))
      }
      TypeRef::TraitObject({ trait_: trait_ref.trait_, args: result })
    }
    _ => type_
  }
}

///|
fn contains_type_param(type_params : Array[String], name : String) -> Bool {
  for param in type_params {
    if param == name {
      return true
    }
  }
  false
}

///|
pub fn unresolved_inference_type(type_ : TypeRef) -> Bool {
  match type_ {
    TypeRef::Unknown(reason) =>
      reason.contains("infer:") || reason.contains("local-type:")
    TypeRef::Declared(_, args)
    | TypeRef::Tuple(args)
    | TypeRef::Apply(_, args) => {
      for arg in args {
        if unresolved_inference_type(arg) {
          return true
        }
      }
      false
    }
    TypeRef::Function(params, return_type, _) => {
      for param in params {
        if unresolved_inference_type(param.type_) {
          return true
        }
      }
      unresolved_inference_type(return_type)
    }
    TypeRef::TraitObject(trait_ref) => {
      for arg in trait_ref.args {
        if unresolved_inference_type(arg) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn unify_concrete_types(
  context : TypingContext,
  expected : TypeRef,
  actual : TypeRef,
) -> Bool {
  if type_equal(expected, actual) {
    return true
  }
  if char_literal_pattern_types_compatible(expected, actual) {
    return true
  }
  match (expected, actual) {
    (TypeRef::Declared(left, left_args), TypeRef::Declared(right, right_args)) =>
      left.id == right.id && unify_type_arrays(context, left_args, right_args)
    (TypeRef::Tuple(left), TypeRef::Tuple(right)) =>
      unify_type_arrays(context, left, right)
    (
      TypeRef::Apply(left_constructor, left_args),
      TypeRef::Apply(right_constructor, right_args),
    ) =>
      constructor_equal(left_constructor, right_constructor) &&
      unify_type_arrays(context, left_args, right_args)
    (
      TypeRef::Function(left_params, left_return, _),
      TypeRef::Function(right_params, right_return, _),
    ) =>
      unify_param_arrays(context, left_params, right_params) &&
      unify_types(context, left_return, right_return)
    (TypeRef::TraitObject(left), TypeRef::TraitObject(right)) =>
      left.trait_.id == right.trait_.id &&
      unify_type_arrays(context, left.args, right.args)
    _ => false
  }
}

///|
fn unify_type_arrays(
  context : TypingContext,
  left : Array[TypeRef],
  right : Array[TypeRef],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    if !unify_types(context, left[i], right[i]) {
      return false
    }
  }
  true
}

///|
fn unify_param_arrays(
  context : TypingContext,
  left : Array[ParamTypeRef],
  right : Array[ParamTypeRef],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    if left[i].label != right[i].label ||
      left[i].optional != right[i].optional ||
      left[i].has_default != right[i].has_default ||
      !unify_types(context, left[i].type_, right[i].type_) {
      return false
    }
  }
  true
}

///|
fn constructor_equal(
  left : TypeConstructorRef,
  right : TypeConstructorRef,
) -> Bool {
  match (left, right) {
    (TypeConstructorRef::Builtin(a), TypeConstructorRef::Builtin(b)) => a == b
    (TypeConstructorRef::Declared(a), TypeConstructorRef::Declared(b)) =>
      a.id == b.id
    (TypeConstructorRef::Declared(symbol), TypeConstructorRef::Builtin(name))
    | (TypeConstructorRef::Builtin(name), TypeConstructorRef::Declared(symbol)) =>
      @binding.is_core_builtin_type_symbol(symbol, name)
    (
      TypeConstructorRef::TypeParameter(a, _),
      TypeConstructorRef::TypeParameter(b, _),
    ) => a == b
    _ => false
  }
}

///|
fn resolve_inferred_effect(
  context : TypingContext,
  effect : EffectRef,
) -> EffectRef {
  match effect {
    EffectRef::Raises(error_type) =>
      EffectRef::Raises(resolve_inferred_type(context, error_type))
    _ => effect
  }
}

///|
fn inference_variable_key(type_ : TypeRef) -> String? {
  match type_ {
    TypeRef::Unknown(reason) =>
      if reason.contains("infer:") || reason.contains("local-type:") {
        Some(reason)
      } else {
        None
      }
    _ => None
  }
}

///|
fn bind_inference_variable(
  context : TypingContext,
  variable : String,
  type_ : TypeRef,
) -> Bool {
  if type_ == TypeRef::Unknown(variable) {
    return true
  }
  match type_ {
    TypeRef::TypeParameter(_, symbol_id) =>
      if symbol_id == variable {
        return true
      }
    _ => ()
  }
  match find_substitution(context, variable) {
    Some(existing) => unify_types(context, existing, type_)
    None => {
      if occurs_in(variable, type_) {
        return false
      }
      context.substitutions.push({ variable, type_ })
      true
    }
  }
}

///|
fn occurs_in(variable : String, type_ : TypeRef) -> Bool {
  match inference_variable_key(type_) {
    Some(key) => if key == variable { return true }
    None => ()
  }
  match type_ {
    TypeRef::Declared(_, args)
    | TypeRef::Tuple(args)
    | TypeRef::Apply(_, args) => {
      for arg in args {
        if occurs_in(variable, arg) {
          return true
        }
      }
      false
    }
    TypeRef::Function(params, return_type, effect) => {
      for param in params {
        if occurs_in(variable, param.type_) {
          return true
        }
      }
      occurs_in(variable, return_type) || occurs_in_effect(variable, effect)
    }
    TypeRef::TraitObject(trait_ref) => {
      for arg in trait_ref.args {
        if occurs_in(variable, arg) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn occurs_in_effect(variable : String, effect : EffectRef) -> Bool {
  match effect {
    EffectRef::Raises(error_type) => occurs_in(variable, error_type)
    _ => false
  }
}

///|
fn find_substitution(context : TypingContext, variable : String) -> TypeRef? {
  for substitution in context.substitutions {
    if substitution.variable == variable {
      return Some(substitution.type_)
    }
  }
  None
}
