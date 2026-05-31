///|
pub(all) enum SymbolKind {
  Module
  Type
  Trait
  TypeParameter
  Function
  Parameter
  Local
  Global
  Field
  EnumVariant
} derive(Eq, Debug)

///|
pub(all) struct TypeSymbolRef {
  id : String
  package_id : String
  module_path : String
  name : String
} derive(Eq, Debug)

///|
pub(all) enum TypeConstructorRef {
  Builtin(String)
  Declared(TypeSymbolRef)
  TypeParameter(String, String)
} derive(Eq, Debug)

///|
pub(all) enum EffectRef {
  NoRaise
  Raises(TypeRef)
  RaisePolymorphic(String?)
  UnknownEffect(String)
} derive(Eq, Debug)

///|
pub(all) struct ParamTypeRef {
  label : String?
  type_ : TypeRef
  optional : Bool
  has_default : Bool
} derive(Eq, Debug)

///|
pub(all) struct TraitRef {
  trait_ : TypeSymbolRef
  args : Array[TypeRef]
} derive(Eq, Debug)

///|
pub(all) enum TypeRef {
  Builtin(String)
  Declared(TypeSymbolRef, Array[TypeRef])
  TypeParameter(String, String)
  Tuple(Array[TypeRef])
  Function(Array[ParamTypeRef], TypeRef, EffectRef)
  Apply(TypeConstructorRef, Array[TypeRef])
  TraitObject(TraitRef)
  Unknown(String)
  Error(String)
} derive(Eq, Debug)

///|
pub(all) struct Symbol {
  id : String
  kind : SymbolKind
  name : String
  type_ : TypeRef
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct ImportRef {
  alias_name : String
  package_id : String
  module_path : String
} derive(Eq, Debug)

///|
pub(all) struct FieldDef {
  id : String
  name : String
  mutable : Bool
  type_ : TypeRef
} derive(Eq, Debug)

///|
pub(all) struct FieldRef {
  owner_type_id : String
  field_id : String
  name : String
  mutable : Bool
  type_ : TypeRef
} derive(Eq, Debug)

///|
pub(all) enum TypeDefinition {
  Opaque(OpaqueTypeDefinition)
  Struct(StructDefinition)
  Enum(EnumDefinition)
} derive(Eq, Debug)

///|
pub(all) struct OpaqueTypeDefinition {
  symbol : TypeSymbolRef
  type_params : Array[String]
} derive(Eq, Debug)

///|
pub(all) struct StructDefinition {
  symbol : TypeSymbolRef
  type_params : Array[String]
  fields : Array[FieldDef]
  derives : Array[String]
} derive(Eq, Debug)

///|
pub(all) struct EnumVariantDef {
  id : String
  name : String
  payloads : Array[EnumPayloadDef]
} derive(Eq, Debug)

///|
pub(all) struct EnumPayloadDef {
  label : String?
  type_ : TypeRef
} derive(Eq, Debug)

///|
pub(all) struct EnumDefinition {
  symbol : TypeSymbolRef
  type_params : Array[String]
  variants : Array[EnumVariantDef]
  derives : Array[String]
} derive(Eq, Debug)

///|
pub fn type_definition_header(
  def : TypeDefinition,
) -> (TypeSymbolRef, Array[String]) {
  match def {
    Opaque(opaque_def) => (opaque_def.symbol, opaque_def.type_params)
    Struct(struct_def) => (struct_def.symbol, struct_def.type_params)
    Enum(enum_def) => (enum_def.symbol, enum_def.type_params)
  }
}

///|
pub(all) struct ParameterDef {
  symbol : Symbol
  label : String?
  optional : Bool
  has_default : Bool
  default_ref : String?
  argument_type : TypeRef
} derive(Eq, Debug)

///|
pub(all) struct DefaultArgument {
  id : String
  owner_function : String
  parameter_symbol_id : String
  value : @ast.Expr
} derive(Eq, Debug)

///|
pub(all) struct GlobalSignature {
  symbol : Symbol
  package_id : String
  module_path : String
} derive(Eq, Debug)

///|
pub(all) struct FunctionSignature {
  function_id : String
  package_id : String
  module_path : String
  name : String
  receiver_type : TypeRef?
  type_params : Array[TypeParamConstraint]
  parameters : Array[ParameterDef]
  return_type : TypeRef
  effect : EffectRef
  aliases : Array[String]
  intrinsic : String?
  is_public : Bool
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct UsedTraitImpl {
  trait_ref : TraitRef
  self_type : TypeRef
} derive(Eq, Debug)

///|
pub(all) struct BindingContext {
  module_name : String
  package_id : String
  imports : Array[ImportRef]
  current_type_params : Array[TypeParamConstraint]
  symbols : Array[Symbol]
  types : Array[TypeDefinition]
  functions : Array[FunctionSignature]
  imported_functions : Array[FunctionSignature]
  imported_globals : Array[GlobalSignature]
  default_arguments : Array[DefaultArgument]
  default_arguments_by_id : Map[String, DefaultArgument]
  current_return_type : TypeRef?
  current_owner_id : String?
  current_effect : EffectRef
  mut loop_depth : Int
  used_trait_impls : Array[UsedTraitImpl]
  used_trait_impl_keys : Set[String]
  trait_default_context : TraitRef?
  diagnostics : Array[@common.Diagnostic]
  suppress_diagnostics : Bool
} derive(Eq, Debug)

///|
pub(all) struct TypeParamConstraint {
  name : String
  constraints : Array[String]
} derive(Eq, Debug)

///|
pub fn binding_context(
  module_name : String,
  diagnostics : Array[@common.Diagnostic],
) -> BindingContext {
  {
    module_name,
    package_id: "pkg:" + module_name,
    imports: [],
    current_type_params: [],
    symbols: [],
    types: [],
    functions: [],
    imported_functions: [],
    imported_globals: [],
    default_arguments: [],
    default_arguments_by_id: Map([]),
    current_return_type: None,
    current_owner_id: None,
    current_effect: no_raise(),
    loop_depth: 0,
    used_trait_impls: [],
    used_trait_impl_keys: Set::default(),
    trait_default_context: None,
    diagnostics,
    suppress_diagnostics: false,
  }
}

///|
pub fn binding_context_with_imports(
  module_name : String,
  package_id : String,
  imports : Array[ImportRef],
  imported_types : Array[TypeDefinition],
  imported_functions : Array[FunctionSignature],
  imported_globals : Array[GlobalSignature],
  diagnostics : Array[@common.Diagnostic],
) -> BindingContext {
  {
    module_name,
    package_id,
    imports,
    current_type_params: [],
    symbols: [],
    types: imported_types,
    functions: [],
    imported_functions,
    imported_globals,
    default_arguments: [],
    default_arguments_by_id: Map([]),
    current_return_type: None,
    current_owner_id: None,
    current_effect: no_raise(),
    loop_depth: 0,
    used_trait_impls: [],
    used_trait_impl_keys: Set::default(),
    trait_default_context: None,
    diagnostics,
    suppress_diagnostics: false,
  }
}

///|
pub fn add_default_arguments(
  context : BindingContext,
  default_arguments : Array[DefaultArgument],
) -> Unit {
  for default_arg in default_arguments {
    context.default_arguments.push(default_arg)
    context.default_arguments_by_id.set(default_arg.id, default_arg)
  }
}

///|
pub fn BindingContext::error(
  self : BindingContext,
  code : String,
  message : String,
  span : @common.SourceSpan,
) -> Unit {
  if !self.suppress_diagnostics {
    self.diagnostics.push({ severity: "error", code, message, span })
  }
}

///|
pub fn int_type() -> TypeRef {
  TypeRef::Builtin("Int")
}

///|
pub fn float_type() -> TypeRef {
  TypeRef::Builtin("Float")
}

///|
pub fn double_type() -> TypeRef {
  TypeRef::Builtin("Double")
}

///|
pub fn bool_type() -> TypeRef {
  TypeRef::Builtin("Bool")
}

///|
pub fn char_type() -> TypeRef {
  TypeRef::Builtin("Char")
}

///|
pub fn char_code_unit_type() -> TypeRef {
  TypeRef::Builtin("UInt16")
}

///|
pub fn char_literal_pattern_type(target_type : TypeRef) -> TypeRef {
  if target_type is TypeRef::Builtin("UInt16") {
    target_type
  } else {
    char_type()
  }
}

///|
pub fn is_char_like_type(type_ : TypeRef) -> Bool {
  type_equal(type_, char_type()) || type_equal(type_, char_code_unit_type())
}

///|
pub fn char_literal_pattern_types_compatible(
  target_type : TypeRef,
  pattern_type : TypeRef,
) -> Bool {
  type_equal(target_type, pattern_type) ||
  (
    type_equal(target_type, char_code_unit_type()) &&
    type_equal(pattern_type, char_type())
  ) ||
  (
    type_equal(target_type, char_type()) &&
    type_equal(pattern_type, char_code_unit_type())
  )
}

///|
pub fn literal_match_pattern_types_compatible(
  target_type : TypeRef,
  pattern_type : TypeRef,
) -> Bool {
  type_equal(target_type, pattern_type) ||
  (
    is_char_like_type(target_type) &&
    is_char_like_type(pattern_type) &&
    char_literal_pattern_types_compatible(target_type, pattern_type)
  )
}

///|
pub fn string_type() -> TypeRef {
  TypeRef::Builtin("String")
}

///|
pub fn string_view_type() -> TypeRef {
  TypeRef::Builtin("StringView")
}

///|
pub fn unit_type() -> TypeRef {
  TypeRef::Builtin("Unit")
}

///|
pub fn error_type() -> TypeRef {
  TypeRef::Error("<error>")
}

///|
pub fn array_type(element : TypeRef) -> TypeRef {
  TypeRef::Apply(TypeConstructorRef::Builtin("Array"), [element])
}

///|
pub fn fixed_array_type(element : TypeRef) -> TypeRef {
  TypeRef::Apply(TypeConstructorRef::Builtin("FixedArray"), [element])
}

///|
pub fn array_view_type(element : TypeRef) -> TypeRef {
  TypeRef::Apply(TypeConstructorRef::Builtin("ArrayView"), [element])
}

///|
pub fn option_type(element : TypeRef) -> TypeRef {
  TypeRef::Apply(TypeConstructorRef::Builtin("Option"), [element])
}

///|
pub fn map_type(key : TypeRef, value : TypeRef) -> TypeRef {
  TypeRef::Apply(TypeConstructorRef::Builtin("Map"), [key, value])
}

///|
pub fn iter_item_type(type_ : TypeRef) -> TypeRef? {
  match type_ {
    TypeRef::Declared(symbol, [item]) =>
      if is_core_builtin_type_symbol(symbol, "Iter") {
        Some(item)
      } else {
        None
      }
    _ => None
  }
}

///|
pub fn iter2_item_types(type_ : TypeRef) -> (TypeRef, TypeRef)? {
  match type_ {
    TypeRef::Declared(symbol, [first, second]) =>
      if is_core_builtin_type_symbol(symbol, "Iter2") {
        Some((first, second))
      } else {
        None
      }
    _ => None
  }
}

///|
pub fn no_raise() -> EffectRef {
  EffectRef::NoRaise
}

///|
pub fn make_type_symbol(
  package_id : String,
  module_path : String,
  name : String,
) -> TypeSymbolRef {
  {
    id: "type:" + package_id + ":" + module_path + ":" + name,
    package_id,
    module_path,
    name,
  }
}

///|
pub fn local_type_symbol(
  context : BindingContext,
  name : String,
) -> TypeSymbolRef {
  make_type_symbol(context.package_id, context.module_name, name)
}

///|
pub fn type_name(type_ : TypeRef) -> String {
  match type_ {
    Builtin(name) => name
    Declared(symbol, _) => symbol.name
    TypeParameter(name, _) => name
    Tuple(_) => "Tuple"
    Function(_, _, _) => "Function"
    Apply(type_constructor, _) => constructor_name(type_constructor)
    TraitObject(trait_ref) => trait_ref.trait_.name
    Unknown(reason) => "<unknown:" + reason + ">"
    Error(reason) => reason
  }
}

///|
pub fn type_key(type_ : TypeRef) -> String {
  match type_ {
    Builtin(name) => "builtin:" + name
    Declared(symbol, args) => "decl:" + symbol.id + type_args_key(args)
    TypeParameter(name, symbol_id) => "param:" + symbol_id + ":" + name
    Tuple(items) => "tuple" + type_args_key(items)
    Function(_, _, _) => "function"
    Apply(type_constructor, args) =>
      "apply:" + constructor_key(type_constructor) + type_args_key(args)
    TraitObject(trait_ref) =>
      "trait-object:" + trait_ref.trait_.id + type_args_key(trait_ref.args)
    Unknown(reason) => "unknown:" + reason
    Error(reason) => "error:" + reason
  }
}

///|
fn type_args_key(args : Array[TypeRef]) -> String {
  if args.length() == 0 {
    return ""
  }
  let parts : Array[String] = []
  for arg in args {
    parts.push(type_key(arg))
  }
  "[" + parts.join(",") + "]"
}

///|
fn constructor_key(type_constructor : TypeConstructorRef) -> String {
  match type_constructor {
    Builtin(name) => "builtin:" + name
    Declared(symbol) => "decl:" + symbol.id
    TypeParameter(name, symbol_id) => "param:" + symbol_id + ":" + name
  }
}

///|
pub fn constructor_name(type_constructor : TypeConstructorRef) -> String {
  match type_constructor {
    Builtin(name) => name
    Declared(symbol) => symbol.name
    TypeParameter(name, _) => name
  }
}

///|
pub fn type_equal(left : TypeRef, right : TypeRef) -> Bool {
  match (left, right) {
    (Builtin(a), Builtin(b)) => a == b
    (Declared(a, left_args), Declared(b, right_args)) =>
      a.id == b.id && type_arrays_equal(left_args, right_args)
    (Declared(symbol, left_args), Apply(Builtin(name), right_args))
    | (Apply(Builtin(name), right_args), Declared(symbol, left_args)) =>
      is_core_builtin_type_symbol(symbol, name) &&
      type_arrays_equal(left_args, right_args)
    (TypeParameter(a, _), TypeParameter(b, _)) => a == b
    (Tuple(a), Tuple(b)) => type_arrays_equal(a, b)
    (
      Function(a_params, a_return, a_effect),
      Function(b_params, b_return, b_effect),
    ) =>
      param_type_arrays_equal(a_params, b_params) &&
      type_equal(a_return, b_return) &&
      effect_equal(a_effect, b_effect)
    (Apply(a, left_args), Apply(b, right_args)) =>
      constructor_equal(a, b) && type_arrays_equal(left_args, right_args)
    (TraitObject(a), TraitObject(b)) =>
      a.trait_.id == b.trait_.id && type_arrays_equal(a.args, b.args)
    (Unknown(a), Unknown(b)) => a == b
    (Error(_), Error(_)) => true
    _ => false
  }
}

///|
pub fn is_core_builtin_type_symbol(
  symbol : TypeSymbolRef,
  name : String,
) -> Bool {
  match core_builtin_type_symbol_name(symbol) {
    Some(actual) => actual == name
    None => false
  }
}

///|
pub fn core_builtin_type_symbol_name(symbol : TypeSymbolRef) -> String? {
  if symbol.package_id == "pkg:moonbitlang/core/builtin" {
    Some(symbol.name)
  } else {
    None
  }
}

///|
pub fn type_constructor_name(type_ : TypeRef) -> (String, Array[TypeRef])? {
  match type_ {
    TypeRef::Apply(TypeConstructorRef::Builtin(name), args) =>
      Some((name, args))
    TypeRef::Apply(TypeConstructorRef::Declared(symbol), args) =>
      match core_builtin_type_symbol_name(symbol) {
        Some(name) => Some((name, args))
        None => None
      }
    TypeRef::Declared(symbol, args) =>
      match core_builtin_type_symbol_name(symbol) {
        Some(name) => Some((name, args))
        None => None
      }
    _ => None
  }
}

///|
fn constructor_equal(
  left : TypeConstructorRef,
  right : TypeConstructorRef,
) -> Bool {
  match (left, right) {
    (Builtin(a), Builtin(b)) => a == b
    (Declared(a), Declared(b)) => a.id == b.id
    (Declared(symbol), Builtin(name)) | (Builtin(name), Declared(symbol)) =>
      is_core_builtin_type_symbol(symbol, name)
    (TypeParameter(a, _), TypeParameter(b, _)) => a == b
    _ => false
  }
}

///|
fn type_arrays_equal(left : Array[TypeRef], right : Array[TypeRef]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    if !type_equal(left[i], right[i]) {
      return false
    }
  }
  true
}

///|
fn param_type_arrays_equal(
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
      !type_equal(left[i].type_, right[i].type_) {
      return false
    }
  }
  true
}

///|
fn effect_equal(left : EffectRef, right : EffectRef) -> Bool {
  match (left, right) {
    (NoRaise, NoRaise) => true
    (Raises(a), Raises(b)) => type_equal(a, b)
    (RaisePolymorphic(a), RaisePolymorphic(b)) => a == b
    (UnknownEffect(a), UnknownEffect(b)) => a == b
    _ => false
  }
}

///|
pub fn function_id(
  package_id : String,
  module_path : String,
  name : String,
) -> String {
  "fn:" + package_id + ":" + module_path + ":" + name
}

///|
pub fn parameter_id(function_id : String, name : String) -> String {
  "param:" + function_id + ":" + name
}

///|
pub fn binding_context_with_owner(
  context : BindingContext,
  owner_id : String,
) -> BindingContext {
  {
    module_name: context.module_name,
    package_id: context.package_id,
    imports: context.imports,
    current_type_params: context.current_type_params,
    symbols: context.symbols,
    types: context.types,
    functions: context.functions,
    imported_functions: context.imported_functions,
    imported_globals: context.imported_globals,
    default_arguments: context.default_arguments,
    default_arguments_by_id: context.default_arguments_by_id,
    current_return_type: context.current_return_type,
    current_owner_id: Some(owner_id),
    current_effect: context.current_effect,
    loop_depth: context.loop_depth,
    used_trait_impls: context.used_trait_impls,
    used_trait_impl_keys: context.used_trait_impl_keys,
    trait_default_context: context.trait_default_context,
    diagnostics: context.diagnostics,
    suppress_diagnostics: context.suppress_diagnostics,
  }
}

///|
pub fn default_argument_id(
  function_id : String,
  parameter_name : String,
) -> String {
  "default:" + function_id + ":" + parameter_name
}

///|
pub fn global_id(
  package_id : String,
  module_path : String,
  name : String,
) -> String {
  "global:" + package_id + ":" + module_path + ":" + name
}

///|
pub fn local_id(function_id : String, name : String, start : Int) -> String {
  "local:" + function_id + ":" + start.to_string() + ":" + name
}
