///|
using @common {type Diagnostic, type SourceSpan}

///|
using @binding {
  type EffectRef,
  type FunctionSignature,
  type GlobalSignature,
  type ImportRef,
  type ParamTypeRef,
  type ParameterDef,
  type Symbol,
  type TraitRef,
  type TypeConstructorRef,
  type TypeDefinition,
  type TypeRef,
  type TypeSymbolRef,
}

///|
using @ir {type BoundExpr, type BoundModule}

///|
pub(all) struct TypeHeader {
  symbol : TypeSymbolRef
  type_params : Array[String]
  span : SourceSpan
} derive(Eq, Debug)

///|
pub(all) enum UsingItemKind {
  Type
  Function
  Global
} derive(Eq, Debug)

///|
pub(all) struct UsingItem {
  package_alias : String
  package_id : String
  name : String
  kind : UsingItemKind
  span : SourceSpan
} derive(Eq, Debug)

///|
pub(all) enum OperatorArity {
  Unary
  Binary
} derive(Eq, Debug)

///|
pub(all) enum OperatorFamily {
  Arithmetic
  Bitwise
  Equality
  Comparison
} derive(Eq, Debug)

///|
pub(all) enum OperatorKind {
  Add
  Sub
  Mul
  Div
  Neg
  Mod
  BitAnd
  BitOr
  BitXOr
  Shl
  Shr
  Equal
  NotEqual
  Less
  Greater
  LessEqual
  GreaterEqual
} derive(Eq, Debug)

///|
pub(all) struct OperatorKey {
  kind : OperatorKind
  arity : OperatorArity
  family : OperatorFamily
} derive(Eq, Debug)

///|
pub(all) struct TraitMethodSignature {
  method_id : String
  name : String
  parameters : Array[ParamTypeRef]
  return_type : TypeRef
  has_default : Bool
  default_function_id : String?
  span : SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct TraitDefinition {
  symbol : TypeSymbolRef
  type_params : Array[String]
  methods : Array[TraitMethodSignature]
  span : SourceSpan
} derive(Eq, Debug)

///|
pub(all) enum ImplMethodBody {
  Function(String)
  Intrinsic(String)
  DefaultMethod
} derive(Eq, Debug)

///|
pub(all) struct ImplMethodSignature {
  method_id : String
  name : String
  function_id : String
  body : ImplMethodBody
  span : SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct ImplDefinition {
  impl_id : String
  trait_ref : TraitRef
  self_type : TypeRef
  methods : Array[ImplMethodSignature]
  source : ImplEvidenceSource
  span : SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct OperatorCandidate {
  signature : FunctionSignature
  evidence : ImplEvidence
  method_body : ImplMethodBody
} derive(Eq, Debug)

///|
pub(all) struct OperatorImplEntry {
  key : OperatorKey
  self_type : TypeRef
  candidate : OperatorCandidate
} derive(Eq, Debug)

///|
pub(all) struct TraitMethodLookupEntry {
  trait_symbol : TypeSymbolRef
  trait_method : TraitMethodSignature
} derive(Eq, Debug)

///|
pub(all) struct ConcreteTraitMethodCandidate {
  trait_ref : TraitRef
  trait_method : TraitMethodSignature
  impl_method : ImplMethodSignature
  evidence : ImplEvidence
} derive(Eq, Debug)

///|
pub(all) struct OperatorTraitBinding {
  trait_symbol : TypeSymbolRef
  method_name : String
  parameters : Array[ParamTypeRef]
  return_type : TypeRef
} derive(Eq, Debug)

///|
pub(all) enum ImplEvidenceSource {
  ConcreteImpl(String)
  BuiltinImpl(String)
  TypeParamBound(String, Int)
  TraitObjectVTable
  DefaultMethod(String, String)
} derive(Eq, Debug)

///|
pub(all) struct ImplEvidence {
  evidence_id : String
  trait_ref : TraitRef
  self_type : TypeRef
  type_args : Array[TypeRef]
  source : ImplEvidenceSource
} derive(Eq, Debug)

///|
pub(all) struct SelectedCallable {
  function_id : String
  receiver_type : TypeRef?
  type_args : Array[TypeRef]
  parameters : Array[ParameterDef]
  return_type : TypeRef
  effect : EffectRef
  function_intrinsic : String?
  trait_evidence : Array[ImplEvidence]
  method_body : ImplMethodBody?
} derive(Eq, Debug)

///|
pub(all) struct DeclarationIndex {
  package_id : String
  module_name : String
  imports : Array[ImportRef]
  using_items : Array[UsingItem]
  traits : Array[TraitDefinition]
  traits_by_id : Map[String, TraitDefinition]
  traits_by_name : Map[String, Array[TraitDefinition]]
  trait_methods_by_name : Map[String, Array[TraitMethodLookupEntry]]
  trait_methods_by_key : Map[String, TraitMethodLookupEntry]
  impls : Array[ImplDefinition]
  impl_method_function_ids : @set.Set[String]
  operator_impls : Array[OperatorImplEntry]
  operator_impls_by_key : Map[String, OperatorCandidate]
  type_headers : Array[TypeHeader]
  type_definitions : Array[TypeDefinition]
  functions : Array[FunctionSignature]
  functions_by_id : Map[String, FunctionSignature]
  functions_by_name : Map[String, Array[FunctionSignature]]
  functions_by_alias : Map[String, Array[FunctionSignature]]
  receiver_functions_by_method : Map[String, Array[FunctionSignature]]
  static_receiver_functions_by_key : Map[String, Array[FunctionSignature]]
  builtin_functions : Array[FunctionSignature]
  imported_functions : Array[FunctionSignature]
  globals : Array[Symbol]
  globals_by_name : Map[String, Symbol]
  imported_globals : Array[GlobalSignature]
  diagnostics : Array[Diagnostic]
}

///|
pub fn declaration_index(
  package_id : String,
  module_name : String,
  imports : Array[ImportRef],
  diagnostics : Array[Diagnostic],
) -> DeclarationIndex {
  {
    package_id,
    module_name,
    imports,
    using_items: [],
    traits: [],
    traits_by_id: Map([]),
    traits_by_name: Map([]),
    trait_methods_by_name: Map([]),
    trait_methods_by_key: Map([]),
    impls: [],
    impl_method_function_ids: @set.Set::default(),
    operator_impls: [],
    operator_impls_by_key: Map([]),
    type_headers: [],
    type_definitions: [],
    functions: [],
    functions_by_id: Map([]),
    functions_by_name: Map([]),
    functions_by_alias: Map([]),
    receiver_functions_by_method: Map([]),
    static_receiver_functions_by_key: Map([]),
    builtin_functions: [],
    imported_functions: [],
    globals: [],
    globals_by_name: Map([]),
    imported_globals: [],
    diagnostics,
  }
}

///|
pub fn DeclarationIndex::error(
  self : DeclarationIndex,
  code : String,
  message : String,
  span : SourceSpan,
) -> Unit {
  self.diagnostics.push({ severity: "error", code, message, span })
}
