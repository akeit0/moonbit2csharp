///|
pub(all) struct BoundModule {
  schema : String
  module_name : String
  symbols : Array[@binding.Symbol]
  types : Array[@binding.TypeDefinition]
  traits : Array[BoundTrait]
  used_trait_impls : Array[@binding.UsedTraitImpl]
  functions : Array[BoundFunction]
  globals : Array[BoundGlobal]
  default_arguments : Array[@binding.DefaultArgument]
  diagnostics : Array[@common.Diagnostic]
} derive(Eq, Debug)

///|
pub(all) struct BoundTrait {
  symbol : @binding.TypeSymbolRef
  methods : Array[BoundTraitMethod]
} derive(Eq, Debug)

///|
pub(all) struct BoundTraitMethod {
  name : String
  parameters : Array[@binding.TypeRef]
  return_type : @binding.TypeRef
  has_default : Bool
  default_function_id : String?
} derive(Eq, Debug)

///|
pub(all) struct BoundGlobal {
  symbol_id : String
  name : String
  is_public : Bool
  type_ : @binding.TypeRef
  value : BoundExpr
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct BoundFunction {
  symbol_id : String
  name : String
  is_public : Bool
  type_params : Array[@binding.TypeParamConstraint]
  params : Array[BoundParam]
  return_type : @binding.TypeRef
  effect : @binding.EffectRef
  external : BoundExternalFunction?
  body : BoundExpr
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct BoundExternalFunction {
  target : String
  body : String
} derive(Eq, Debug)

///|
pub(all) struct BoundParam {
  symbol_id : String
  name : String
  label : String?
  optional : Bool
  has_default : Bool
  default_ref : String?
  type_ : @binding.TypeRef
} derive(Eq, Debug)

///|
pub(all) struct BoundTraitEvidence {
  evidence_id : String
  trait_ref : @binding.TraitRef
  self_type : @binding.TypeRef
  type_args : Array[@binding.TypeRef]
} derive(Eq, Debug)

///|
pub(all) enum BoundExpr {
  Name(String, String, @binding.TypeRef, @common.SourceSpan)
  FunctionRef(String, String, @binding.TypeRef, @common.SourceSpan)
  IntLiteral(String, @binding.TypeRef, @common.SourceSpan)
  FloatLiteral(String, @binding.TypeRef, @common.SourceSpan)
  CharLiteral(String, @binding.TypeRef, @common.SourceSpan)
  StringLiteral(String, @binding.TypeRef, @common.SourceSpan)
  BytesLiteral(String, @binding.TypeRef, @common.SourceSpan)
  BoolLiteral(Bool, @binding.TypeRef, @common.SourceSpan)
  UnitLiteral(@binding.TypeRef, @common.SourceSpan)
  TupleLiteral(Array[BoundExpr], @binding.TypeRef, @common.SourceSpan)
  TupleGet(BoundExpr, Int, @binding.TypeRef, @common.SourceSpan)
  LocalLet(BoundLocal, BoundExpr, @binding.TypeRef, @common.SourceSpan)
  LocalFunction(
    BoundLocalFunction,
    BoundExpr,
    @binding.TypeRef,
    @common.SourceSpan
  )
  Sequence(BoundExpr, BoundExpr, @binding.TypeRef, @common.SourceSpan)
  Call(
    String,
    Array[@binding.TypeRef],
    Array[BoundTraitEvidence],
    Array[BoundExpr],
    String?,
    @binding.TypeRef,
    @common.SourceSpan
  )
  FunctionValueCall(
    BoundExpr,
    Array[BoundExpr],
    @binding.TypeRef,
    @common.SourceSpan
  )
  Lambda(
    Array[@binding.Symbol],
    BoundExpr,
    @binding.TypeRef,
    @common.SourceSpan
  )
  IndexGet(BoundExpr, BoundExpr, @binding.TypeRef, @common.SourceSpan)
  EnumCase(
    String,
    String,
    String,
    Array[BoundExpr],
    @binding.TypeRef,
    @common.SourceSpan
  )
  FieldAccess(
    BoundExpr,
    @binding.FieldRef,
    @binding.TypeRef,
    @common.SourceSpan
  )
  FieldAssign(
    BoundExpr,
    @binding.FieldRef,
    BoundExpr,
    @binding.TypeRef,
    @common.SourceSpan
  )
  Assign(@binding.Symbol, BoundExpr, @binding.TypeRef, @common.SourceSpan)
  IndexAssign(
    BoundExpr,
    BoundExpr,
    BoundExpr,
    @binding.TypeRef,
    @common.SourceSpan
  )
  If(BoundExpr, BoundExpr, BoundExpr, @binding.TypeRef, @common.SourceSpan)
  TraitMethodCall(
    BoundExpr,
    @binding.TraitRef,
    String,
    String,
    Array[BoundExpr],
    BoundTraitDispatch,
    @binding.TypeRef,
    @common.SourceSpan
  )
  OptionSome(BoundExpr, @binding.TypeRef, @common.SourceSpan)
  OptionNone(@binding.TypeRef, @common.SourceSpan)
  Panic(@binding.TypeRef, @common.SourceSpan)
  ArrayLiteral(Array[BoundArrayElement], @binding.TypeRef, @common.SourceSpan)
  MapLiteral(Array[BoundMapEntry], @binding.TypeRef, @common.SourceSpan)
  StructLiteral(
    String,
    Array[BoundFieldValue],
    @binding.TypeRef,
    @common.SourceSpan
  )
  StructUpdate(
    String,
    BoundExpr,
    Array[BoundFieldValue],
    @binding.TypeRef,
    @common.SourceSpan
  )
  Conversion(String, BoundExpr, @binding.TypeRef, @common.SourceSpan)
  Unary(
    String,
    BoundExpr,
    String,
    String?,
    @binding.TypeRef,
    @common.SourceSpan
  )
  Binary(
    String,
    BoundExpr,
    BoundExpr,
    String,
    Array[@binding.TypeRef],
    Array[BoundTraitEvidence],
    String?,
    @binding.TypeRef,
    @common.SourceSpan
  )
  IsPattern(BoundExpr, BoundPattern, @binding.TypeRef, @common.SourceSpan)
  Match(BoundExpr, Array[BoundMatchArm], @binding.TypeRef, @common.SourceSpan)
  Raise(BoundExpr, BoundExpr?, @binding.TypeRef, @common.SourceSpan)
  TryCatch(
    BoundExpr,
    Array[BoundMatchArm],
    @binding.TypeRef,
    @common.SourceSpan
  )
  Guard(BoundExpr, BoundExpr, @binding.TypeRef, @common.SourceSpan)
  While(BoundExpr, BoundExpr, @binding.TypeRef, @common.SourceSpan)
  ForRange(BoundRangeLoop, @binding.TypeRef, @common.SourceSpan)
  ForIn(BoundForInLoop, @binding.TypeRef, @common.SourceSpan)
  ForLoop(BoundForLoop, @binding.TypeRef, @common.SourceSpan)
  Break(BoundExpr?, @binding.TypeRef, @common.SourceSpan)
  Continue(Array[BoundExpr], @binding.TypeRef, @common.SourceSpan)
  Return(BoundExpr?, @binding.TypeRef, @common.SourceSpan)
  Error(String, @binding.TypeRef, @common.SourceSpan)
} derive(Eq, Debug)

///|
pub(all) struct BoundMatchArm {
  pattern : BoundPattern
  condition : BoundExpr?
  body : BoundExpr
} derive(Eq, Debug)

///|
pub(all) enum BoundPattern {
  Wildcard
  Binding(@binding.Symbol)
  IntLiteral(String)
  CharLiteral(String)
  StringLiteral(String)
  BoolLiteral(Bool)
  Range(String?, String?, Bool)
  Tuple(Array[BoundPattern])
  Array(Array[BoundPattern], BoundArrayPatternRest?, Array[BoundPattern])
  Struct(String, Array[BoundStructPatternField])
  Or(Array[BoundPattern])
  OptionNone
  OptionSome(BoundPattern)
  EnumCase(String, String, String, Array[BoundPattern])
} derive(Eq, Debug)

///|
pub(all) struct BoundStructPatternField {
  field : @binding.FieldRef
  pattern : BoundPattern
} derive(Eq, Debug)

///|
pub(all) struct BoundArrayPatternRest {
  symbol : @binding.Symbol?
} derive(Eq, Debug)

///|
pub(all) enum BoundTraitDispatch {
  TraitObject
  TypeParamBound(String)
  ConcreteImpl(String, String?)
} derive(Eq, Debug)

///|
pub(all) struct BoundFieldValue {
  name : String
  value : BoundExpr
} derive(Eq, Debug)

///|
pub(all) struct BoundMapEntry {
  key : BoundExpr
  value : BoundExpr
} derive(Eq, Debug)

///|
pub(all) enum BoundArrayElement {
  Value(BoundExpr)
  Spread(BoundExpr)
} derive(Eq, Debug)

///|
pub(all) struct BoundLocal {
  symbol_id : String
  name : String
  type_ : @binding.TypeRef
  value : BoundExpr
} derive(Eq, Debug)

///|
pub(all) struct BoundLocalFunction {
  symbol : @binding.Symbol
  params : Array[@binding.Symbol]
  return_type : @binding.TypeRef
  body : BoundExpr
} derive(Eq, Debug)

///|
pub(all) struct BoundRangeLoop {
  symbol_id : String
  name : String
  start : BoundExpr
  end_ : BoundExpr
  inclusive : Bool
  reverse : Bool
  exclude_start : Bool
  body : BoundExpr
} derive(Eq, Debug)

///|
pub(all) struct BoundForInLoop {
  value_symbols : Array[@binding.Symbol]
  iterator : BoundExpr
  bindings : Array[BoundForLoopBinding]
  body : BoundExpr
  no_break : BoundExpr?
} derive(Eq, Debug)

///|
pub(all) struct BoundForLoop {
  bindings : Array[BoundForLoopBinding]
  condition : BoundExpr?
  updates : Array[BoundExpr]
  body : BoundExpr
} derive(Eq, Debug)

///|
pub(all) struct BoundForLoopBinding {
  symbol : @binding.Symbol
  value : BoundExpr
} derive(Eq, Debug)

///|
pub fn expr_type(expr : BoundExpr) -> @binding.TypeRef {
  match expr {
    Name(_, _, type_, _)
    | FunctionRef(_, _, type_, _)
    | IntLiteral(_, type_, _)
    | FloatLiteral(_, type_, _)
    | CharLiteral(_, type_, _)
    | StringLiteral(_, type_, _)
    | BytesLiteral(_, type_, _)
    | BoolLiteral(_, type_, _)
    | UnitLiteral(type_, _)
    | TupleLiteral(_, type_, _)
    | TupleGet(_, _, type_, _)
    | LocalLet(_, _, type_, _)
    | LocalFunction(_, _, type_, _)
    | Sequence(_, _, type_, _)
    | Call(_, _, _, _, _, type_, _)
    | FunctionValueCall(_, _, type_, _)
    | Lambda(_, _, type_, _)
    | IndexGet(_, _, type_, _)
    | EnumCase(_, _, _, _, type_, _)
    | FieldAccess(_, _, type_, _)
    | FieldAssign(_, _, _, type_, _)
    | Assign(_, _, type_, _)
    | IndexAssign(_, _, _, type_, _)
    | If(_, _, _, type_, _)
    | TraitMethodCall(_, _, _, _, _, _, type_, _)
    | OptionSome(_, type_, _)
    | OptionNone(type_, _)
    | Panic(type_, _)
    | ArrayLiteral(_, type_, _)
    | MapLiteral(_, type_, _)
    | StructLiteral(_, _, type_, _)
    | StructUpdate(_, _, _, type_, _)
    | Conversion(_, _, type_, _)
    | Unary(_, _, _, _, type_, _)
    | Binary(_, _, _, _, _, _, _, type_, _)
    | IsPattern(_, _, type_, _)
    | Match(_, _, type_, _)
    | Raise(_, _, type_, _)
    | TryCatch(_, _, type_, _)
    | Guard(_, _, type_, _)
    | While(_, _, type_, _)
    | ForRange(_, type_, _)
    | ForIn(_, type_, _)
    | ForLoop(_, type_, _)
    | Break(_, type_, _)
    | Continue(_, type_, _)
    | Return(_, type_, _)
    | Error(_, type_, _) => type_
  }
}
