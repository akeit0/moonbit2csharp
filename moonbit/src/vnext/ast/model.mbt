///|
pub(all) struct Module {
  usings : Array[UsingDecl]
  functions : Array[Function]
  structs : Array[StructDecl]
  opaque_types : Array[OpaqueTypeDecl]
  enums : Array[EnumDecl]
  traits : Array[TraitDecl]
  impls : Array[ImplDecl]
  globals : Array[GlobalLet]
} derive(Eq, Debug)

///|
pub(all) struct UsingDecl {
  package_alias : String
  items : Array[UsingItem]
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) enum UsingItemKind {
  Type
  Value
} derive(Eq, Debug)

///|
pub(all) struct UsingItem {
  kind : UsingItemKind
  name : String
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct StructDecl {
  name : String
  type_params : Array[String]
  fields : Array[StructField]
  derives : Array[String]
  valtype : Bool
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct StructField {
  name : String
  mutable : Bool
  type_ : TypeSyntax
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct OpaqueTypeDecl {
  name : String
  type_params : Array[String]
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct EnumDecl {
  name : String
  type_params : Array[String]
  variants : Array[EnumVariant]
  derives : Array[String]
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct EnumVariant {
  name : String
  payloads : Array[EnumPayload]
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct EnumPayload {
  label : String?
  type_ : TypeSyntax
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct TraitDecl {
  name : String
  methods : Array[TraitMethodDecl]
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct TraitMethodDecl {
  name : String
  parameters : Array[TypeSyntax]
  return_type : TypeSyntax
  has_default : Bool
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct ImplDecl {
  type_params : Array[TypeParamSyntax]
  trait_name : String
  self_type : TypeSyntax
  methods : Array[ImplMethodDecl]
  is_interface : Bool
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct ImplMethodDecl {
  name : String
  params : Array[Param]
  return_type : TypeSyntax?
  body : Expr?
  intrinsic : String?
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct GlobalLet {
  name : String
  type_ : TypeSyntax
  has_type_annotation : Bool
  value : Expr
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct Function {
  name : String
  receiver : TypeSyntax?
  type_params : Array[TypeParamSyntax]
  params : Array[Param]
  return_type : TypeSyntax
  raises : TypeSyntax?
  body : Expr
  external : ExternDecl?
  intrinsic : String?
  aliases : Array[String]
  is_public : Bool
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct ExternDecl {
  target : String
  body : String?
} derive(Eq, Debug)

///|
pub(all) struct TypeParamSyntax {
  name : String
  constraints : Array[String]
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct Param {
  name : String
  optional : Bool
  labelled : Bool
  type_ : TypeSyntax
  default_value : Expr?
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct TypeSyntax {
  package_alias : String?
  name : String
  args : Array[TypeSyntax]
  is_trait_object : Bool
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) enum Expr {
  Name(String, @common.SourceSpan)
  IntLiteral(String, @common.SourceSpan)
  FloatLiteral(String, @common.SourceSpan)
  CharLiteral(String, @common.SourceSpan)
  StringLiteral(String, @common.SourceSpan)
  BytesLiteral(String, @common.SourceSpan)
  InterpolatedString(Array[StringPart], @common.SourceSpan)
  BoolLiteral(Bool, @common.SourceSpan)
  UnitLiteral(@common.SourceSpan)
  EmptyBraceLiteral(@common.SourceSpan)
  TupleLiteral(Array[Expr], @common.SourceSpan)
  LocalLet(String, TypeSyntax?, Expr, Expr, @common.SourceSpan)
  LocalLetPattern(Pattern, Expr, Expr, @common.SourceSpan)
  LocalFunction(Function, Expr, @common.SourceSpan)
  Sequence(Expr, Expr, @common.SourceSpan)
  Call(Expr, Array[CallArg], @common.SourceSpan)
  Index(Expr, Expr?, Expr?, Bool, @common.SourceSpan)
  PackageAccess(String, String, @common.SourceSpan)
  StaticAccess(TypeSyntax, String, @common.SourceSpan)
  FieldAccess(Expr, String, @common.SourceSpan)
  Assign(Expr, Expr, @common.SourceSpan)
  If(Expr, Expr, Expr, @common.SourceSpan)
  ArrayLiteral(Array[ArrayElement], @common.SourceSpan)
  MapLiteral(Array[MapEntry], @common.SourceSpan)
  StructLiteral(Array[StructFieldValue], @common.SourceSpan)
  TypedStructLiteral(TypeSyntax, Array[StructFieldValue], @common.SourceSpan)
  StructUpdateLiteral(Expr, Array[StructFieldValue], @common.SourceSpan)
  TypeAscription(Expr, TypeSyntax, @common.SourceSpan)
  Lambda(Array[String], Expr, @common.SourceSpan)
  Unary(String, Expr, @common.SourceSpan)
  Binary(String, Expr, Expr, @common.SourceSpan)
  IsPattern(Expr, Pattern, @common.SourceSpan)
  Match(Expr, Array[MatchArm], @common.SourceSpan)
  Raise(Expr, @common.SourceSpan)
  TryCatch(Expr, Array[MatchArm], @common.SourceSpan)
  Guard(Expr, Expr, @common.SourceSpan)
  While(Expr, Expr, @common.SourceSpan)
  ForIn(
    Array[String],
    Expr,
    Array[ForLoopBinding],
    Expr,
    Expr?,
    @common.SourceSpan
  )
  Pipe(Expr, Expr, Bool, @common.SourceSpan)
  ForRange(
    String,
    Expr,
    RangeKind,
    Expr,
    Array[ForLoopBinding],
    Expr,
    Expr?,
    @common.SourceSpan
  )
  ForLoop(
    Array[ForLoopBinding],
    Expr?,
    Array[Expr],
    Expr,
    Expr?,
    @common.SourceSpan
  )
  Break(Expr?, @common.SourceSpan)
  Continue(Array[Expr], @common.SourceSpan)
  Return(Expr?, @common.SourceSpan)
  Missing(@common.SourceSpan)
} derive(Eq, Debug)

///|
pub(all) enum StringPart {
  Text(String)
  Expr(Expr)
  WriteTo(String, Expr)
} derive(Eq, Debug)

///|
pub(all) enum ArrayElement {
  Value(Expr)
  Spread(Expr, @common.SourceSpan)
} derive(Eq, Debug)

///|
pub(all) struct MatchArm {
  pattern : Pattern
  condition : Expr?
  body : Expr
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) enum Pattern {
  Wildcard(@common.SourceSpan)
  Name(String, @common.SourceSpan)
  IntLiteral(String, @common.SourceSpan)
  CharLiteral(String, @common.SourceSpan)
  StringLiteral(String, @common.SourceSpan)
  BoolLiteral(Bool, @common.SourceSpan)
  Range(String?, String?, Bool, @common.SourceSpan)
  Tuple(Array[Pattern], @common.SourceSpan)
  Array(Array[Pattern], ArrayPatternRest?, Array[Pattern], @common.SourceSpan)
  Struct(Array[StructPatternField], Bool, @common.SourceSpan)
  Or(Array[Pattern], @common.SourceSpan)
  Alias(Pattern, String, @common.SourceSpan)
  Labelled(String, Pattern, @common.SourceSpan)
  Rest(@common.SourceSpan)
  Constructor(TypeSyntax?, String, Array[Pattern], @common.SourceSpan)
} derive(Eq, Debug)

///|
pub(all) struct StructPatternField {
  name : String
  pattern : Pattern
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct ArrayPatternRest {
  name : String?
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct ForLoopBinding {
  name : String
  value : Expr
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) enum RangeKind {
  DotDot
  Inclusive
  LtInclusive
  Exclusive
  InclusiveReverse
  ExclusiveReverse
} derive(Eq, Debug)

///|
pub(all) struct CallArg {
  label : String?
  value : Expr
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct StructFieldValue {
  name : String
  value : Expr
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct MapEntry {
  key : Expr
  value : Expr
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub fn expr_span(expr : Expr) -> @common.SourceSpan {
  match expr {
    Name(_, s)
    | IntLiteral(_, s)
    | FloatLiteral(_, s)
    | CharLiteral(_, s)
    | StringLiteral(_, s)
    | BytesLiteral(_, s)
    | InterpolatedString(_, s)
    | BoolLiteral(_, s)
    | UnitLiteral(s)
    | EmptyBraceLiteral(s)
    | TupleLiteral(_, s)
    | LocalLet(_, _, _, _, s)
    | LocalLetPattern(_, _, _, s)
    | LocalFunction(_, _, s)
    | Sequence(_, _, s)
    | Call(_, _, s)
    | Index(_, _, _, _, s)
    | PackageAccess(_, _, s)
    | StaticAccess(_, _, s)
    | FieldAccess(_, _, s)
    | Assign(_, _, s)
    | If(_, _, _, s)
    | ArrayLiteral(_, s)
    | MapLiteral(_, s)
    | StructLiteral(_, s)
    | TypedStructLiteral(_, _, s)
    | StructUpdateLiteral(_, _, s)
    | TypeAscription(_, _, s)
    | Lambda(_, _, s)
    | Unary(_, _, s)
    | Binary(_, _, _, s)
    | IsPattern(_, _, s)
    | Match(_, _, s)
    | Raise(_, s)
    | TryCatch(_, _, s)
    | Guard(_, _, s)
    | While(_, _, s)
    | ForIn(_, _, _, _, _, s)
    | Pipe(_, _, _, s)
    | ForRange(_, _, _, _, _, _, _, s)
    | ForLoop(_, _, _, _, _, s)
    | Break(_, s)
    | Continue(_, s)
    | Return(_, s)
    | Missing(s) => s
  }
}
