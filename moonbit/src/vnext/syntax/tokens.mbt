///|
pub(all) enum TokenKind {
  Eof
  Bad
  Identifier
  IntLiteral
  FloatLiteral
  CharLiteral
  StringLiteral
  PackageName
  Attribute
  Fn
  Using
  Pub
  Priv
  All
  Readonly
  Import
  Extern
  Break
  Continue
  Struct
  Enum
  Trait
  Derive
  Impl
  For
  In
  With
  Raise
  Throw
  Try
  Catch
  Async
  TypeAlias
  TraitAlias
  FnAlias
  False
  True
  Mut
  Type
  As
  Else
  If
  Let
  Const
  Match
  While
  Return
  Test
  Loop
  Guard
  Defer
  Is
  Suberror
  And
  Letrec
  Enumview
  Declare
  Noraise
  Nobreak
  Where
  Lexmatch
  Package
  Newline
  Semicolon
  Colon
  ColonColon
  Comma
  Dot
  DotDot
  RangeInclusive
  RangeLtInclusive
  RangeExclusive
  RangeInclusiveRev
  RangeExclusiveRev
  Ellipsis
  At
  Eq
  EqEq
  AugmentedAssign
  FatArrow
  LParen
  RParen
  LBracket
  RBracket
  LBrace
  RBrace
  Arrow
  Plus
  Minus
  Star
  Slash
  Percent
  Amp
  AmpAmp
  Pipe
  PipePipe
  PipeForward
  PipeBackward
  Caret
  Less
  LessPlus
  Greater
  LessEq
  GreaterEq
  Shl
  Shr
  Question
  Exclamation
  BangEq
  Tilde
  Underscore
} derive(Eq, Debug)

///|
pub(all) struct Token {
  kind : TokenKind
  text : String
  span : @common.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct LexResult {
  tokens : Array[Token]
  diagnostics : Array[@common.Diagnostic]
} derive(Eq, Debug)
