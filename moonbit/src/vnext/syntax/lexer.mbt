///|
pub fn lex(file : @text.SourceFile) -> LexResult {
  let lexer : Lexer = {
    file,
    source: file.text,
    tokens: [],
    diagnostics: [],
    pos: 0,
    line: 1,
    col: 1,
  }
  lexer.scan()
  lexer.finish()
}

///|
priv struct Lexer {
  file : @text.SourceFile
  source : String
  tokens : Array[Token]
  diagnostics : Array[@common.Diagnostic]
  mut pos : Int
  mut line : Int
  mut col : Int
}

///|
priv enum LexClass {
  Space
  StringLiteral
  CharLiteral
  HashLine
  NumberLiteral
  IdentifierOrKeyword
  PunctuationOrBad
}

///|
priv struct PunctuationToken {
  kind : TokenKind
  text : String
}

///|
fn Lexer::scan(self : Lexer) -> Unit {
  while !self.at_end() {
    if self.prefixed_string_literal_ahead() {
      self.scan_prefixed_string_literal()
      continue
    }
    match classify_leading_char(self.peek()) {
      LexClass::Space => self.scan_space()
      LexClass::StringLiteral => self.scan_string_literal()
      LexClass::CharLiteral => self.scan_char_literal()
      LexClass::HashLine => self.scan_hash_line()
      LexClass::NumberLiteral => self.scan_number_literal()
      LexClass::IdentifierOrKeyword => self.scan_identifier_or_keyword()
      LexClass::PunctuationOrBad => self.scan_punctuation_or_bad()
    }
  }
}

///|
fn Lexer::prefixed_string_literal_ahead(self : Lexer) -> Bool {
  self.pos + 1 < self.source.length() &&
  (
    (self.source[self.pos] == 'b' && self.source[self.pos + 1] is ('"' | '\'')) ||
    (self.source[self.pos] == '$' && self.source[self.pos + 1] == '|')
  )
}

///|
fn Lexer::scan_prefixed_string_literal(self : Lexer) -> Unit {
  let start = self.pos
  let start_col = self.col
  let start_line = self.line
  if self.source[self.pos] == '$' {
    self.scan_dollar_pipe_string_literal()
    return
  }
  self.advance()
  let kind = if self.peek() == '\'' {
    TokenKind::CharLiteral
  } else {
    TokenKind::StringLiteral
  }
  self.scan_quoted_literal_from(start, start_line, start_col, kind)
}

///|
fn Lexer::scan_dollar_pipe_string_literal(self : Lexer) -> Unit {
  let start = self.pos
  let start_col = self.col
  let start_line = self.line
  self.advance_by(2)
  while !self.at_end() && self.peek() != '\n' {
    self.advance()
  }
  self.tokens.push({
    kind: TokenKind::StringLiteral,
    text: self.source[start:self.pos].to_owned(),
    span: self.span(start, self.pos, start_line, start_col),
  })
}

///|
fn Lexer::finish(self : Lexer) -> LexResult {
  self.tokens.push({
    kind: TokenKind::Eof,
    text: "",
    span: self.span(self.pos, self.pos, self.line, self.col),
  })
  { tokens: self.tokens, diagnostics: self.diagnostics }
}

///|
fn Lexer::scan_space(self : Lexer) -> Unit {
  if self.peek() == '\n' {
    self.push_fixed(TokenKind::Newline, "\n", self.pos, self.line, self.col)
    self.advance_line()
  } else {
    self.advance()
  }
}

///|
fn Lexer::scan_string_literal(self : Lexer) -> Unit {
  self.scan_quoted_literal(TokenKind::StringLiteral)
}

///|
fn Lexer::scan_char_literal(self : Lexer) -> Unit {
  self.scan_quoted_literal(TokenKind::CharLiteral)
}

///|
fn Lexer::scan_quoted_literal(self : Lexer, kind : TokenKind) -> Unit {
  let start = self.pos
  let start_col = self.col
  let start_line = self.line
  self.scan_quoted_literal_from(start, start_line, start_col, kind)
}

///|
fn Lexer::scan_quoted_literal_from(
  self : Lexer,
  start : Int,
  start_line : Int,
  start_col : Int,
  kind : TokenKind,
) -> Unit {
  let quote = self.peek()
  self.advance()
  while !self.at_end() && self.peek() != quote {
    if self.peek() == '\\' {
      self.advance()
      if !self.at_end() {
        self.advance()
      }
    } else {
      self.advance()
    }
  }
  if !self.at_end() {
    self.advance()
  }
  self.tokens.push({
    kind,
    text: self.source[start:self.pos].to_owned(),
    span: self.span(start, self.pos, start_line, start_col),
  })
}

///|
fn Lexer::scan_hash_line(self : Lexer) -> Unit {
  if self.pos + 1 < self.source.length() && self.source[self.pos + 1] == '|' {
    self.scan_hash_pipe_string_literal()
  } else if self.attribute_ahead() {
    self.scan_attribute_line()
  } else {
    while !self.at_end() && self.peek() != '\n' {
      self.advance()
    }
  }
}

///|
fn Lexer::attribute_ahead(self : Lexer) -> Bool {
  self.pos + 1 < self.source.length() &&
  is_ident_start(self.source[self.pos + 1])
}

///|
fn Lexer::scan_attribute_line(self : Lexer) -> Unit {
  let start = self.pos
  let start_col = self.col
  let start_line = self.line
  while !self.at_end() && self.peek() != '\n' {
    self.advance()
  }
  self.tokens.push({
    kind: TokenKind::Attribute,
    text: self.source[start:self.pos].to_owned(),
    span: self.span(start, self.pos, start_line, start_col),
  })
}

///|
fn Lexer::scan_hash_pipe_string_literal(self : Lexer) -> Unit {
  let start = self.pos
  let start_col = self.col
  let start_line = self.line
  self.advance_by(2)
  while !self.at_end() && self.peek() != '\n' {
    self.advance()
  }
  self.tokens.push({
    kind: TokenKind::StringLiteral,
    text: self.source[start:self.pos].to_owned(),
    span: self.span(start, self.pos, start_line, start_col),
  })
}

///|
fn Lexer::scan_number_literal(self : Lexer) -> Unit {
  let start = self.pos
  let start_col = self.col
  let start_line = self.line
  let hex_float = self.hex_number_ahead()
  self.scan_int_literal_digits()
  let mut kind = TokenKind::IntLiteral
  if self.has_float_fraction() {
    kind = TokenKind::FloatLiteral
    self.advance()
    self.scan_decimal_digits()
  }
  if self.has_float_exponent(hex_float) {
    kind = TokenKind::FloatLiteral
    self.scan_float_exponent()
  }
  self.scan_number_suffix()
  self.tokens.push({
    kind,
    text: self.source[start:self.pos].to_owned(),
    span: self.span(start, self.pos, start_line, start_col),
  })
}

///|
fn Lexer::hex_number_ahead(self : Lexer) -> Bool {
  self.pos + 1 < self.source.length() &&
  self.source[self.pos] == '0' &&
  self.source[self.pos + 1] is ('x' | 'X')
}

///|
fn Lexer::has_float_exponent(self : Lexer, hex_float : Bool) -> Bool {
  !self.at_end() &&
  (self.peek() is ('e' | 'E') || (hex_float && self.peek() is ('p' | 'P')))
}

///|
fn Lexer::scan_float_exponent(self : Lexer) -> Unit {
  self.advance()
  if !self.at_end() && self.peek() is ('+' | '-') {
    self.advance()
  }
  self.scan_decimal_digits()
}

///|
fn Lexer::scan_number_suffix(self : Lexer) -> Unit {
  while !self.at_end() && is_number_suffix_char(self.peek()) {
    self.advance()
  }
}

///|
fn is_number_suffix_char(ch : UInt16) -> Bool {
  ch is ('u' | 'U' | 'l' | 'L' | 'f' | 'F')
}

///|
fn Lexer::scan_int_literal_digits(self : Lexer) -> Unit {
  if self.peek() == '0' && self.pos + 1 < self.source.length() {
    match self.source[self.pos + 1] {
      'x' | 'X' => {
        self.advance_by(2)
        self.scan_digits(is_hex_digit)
        return
      }
      'o' | 'O' => {
        self.advance_by(2)
        self.scan_digits(is_octal_digit)
        return
      }
      'b' | 'B' => {
        self.advance_by(2)
        self.scan_digits(is_binary_digit)
        return
      }
      _ => ()
    }
  }
  self.scan_decimal_digits()
}

///|
fn Lexer::scan_decimal_digits(self : Lexer) -> Unit {
  self.scan_digits(is_digit)
}

///|
fn Lexer::scan_digits(self : Lexer, accepts : (UInt16) -> Bool) -> Unit {
  while !self.at_end() && (accepts(self.peek()) || self.peek() == '_') {
    self.advance()
  }
}

///|
fn Lexer::scan_identifier_or_keyword(self : Lexer) -> Unit {
  let start = self.pos
  let start_col = self.col
  let start_line = self.line
  while !self.at_end() && is_ident_part(self.peek()) {
    self.advance()
  }
  let text = self.source[start:self.pos].to_owned()
  self.tokens.push({
    kind: keyword_kind(text),
    text,
    span: self.span(start, self.pos, start_line, start_col),
  })
}

///|
fn Lexer::scan_punctuation_or_bad(self : Lexer) -> Unit {
  if self.peek() == '@' &&
    self.pos + 1 < self.source.length() &&
    is_ident_start(self.source[self.pos + 1]) {
    self.scan_package_name()
    return
  }
  if self.peek() == '/' &&
    self.pos + 1 < self.source.length() &&
    self.source[self.pos + 1] == '/' {
    self.scan_line_comment()
    return
  }
  let start = self.pos
  let start_col = self.col
  let start_line = self.line
  let token = match self.peek() {
    '.' => Some(self.dot_token())
    '>' => Some(self.greater_token())
    '<' => Some(self.less_token())
    ':' =>
      Some(
        self.two_char_token(
          ':',
          TokenKind::ColonColon,
          "::",
          TokenKind::Colon,
          ":",
        ),
      )
    '=' => Some(self.equal_token())
    '-' => Some(self.minus_token())
    '&' => Some(self.amp_token())
    '|' => Some(self.pipe_token())
    '!' =>
      Some(
        self.two_char_token(
          '=',
          TokenKind::BangEq,
          "!=",
          TokenKind::Exclamation,
          "!",
        ),
      )
    ';' => Some(token(TokenKind::Semicolon, ";"))
    ',' => Some(token(TokenKind::Comma, ","))
    '@' => Some(token(TokenKind::At, "@"))
    '(' => Some(token(TokenKind::LParen, "("))
    ')' => Some(token(TokenKind::RParen, ")"))
    '[' => Some(token(TokenKind::LBracket, "["))
    ']' => Some(token(TokenKind::RBracket, "]"))
    '{' => Some(token(TokenKind::LBrace, "{"))
    '}' => Some(token(TokenKind::RBrace, "}"))
    '+' =>
      Some(
        self.two_char_token(
          '=',
          TokenKind::AugmentedAssign,
          "+=",
          TokenKind::Plus,
          "+",
        ),
      )
    '*' =>
      Some(
        self.two_char_token(
          '=',
          TokenKind::AugmentedAssign,
          "*=",
          TokenKind::Star,
          "*",
        ),
      )
    '/' =>
      Some(
        self.two_char_token(
          '=',
          TokenKind::AugmentedAssign,
          "/=",
          TokenKind::Slash,
          "/",
        ),
      )
    '%' =>
      Some(
        self.two_char_token(
          '=',
          TokenKind::AugmentedAssign,
          "%=",
          TokenKind::Percent,
          "%",
        ),
      )
    '^' =>
      Some(
        self.two_char_token(
          '=',
          TokenKind::AugmentedAssign,
          "^=",
          TokenKind::Caret,
          "^",
        ),
      )
    '?' => Some(token(TokenKind::Question, "?"))
    '~' => Some(token(TokenKind::Tilde, "~"))
    '_' => Some(token(TokenKind::Underscore, "_"))
    _ => {
      self.scan_bad_character()
      None
    }
  }
  guard token is Some(token) else { return }
  self.tokens.push({
    kind: token.kind,
    text: token.text,
    span: self.span(start, start + token.text.length(), start_line, start_col),
  })
  self.advance_by(token.text.length())
}

///|
fn Lexer::scan_package_name(self : Lexer) -> Unit {
  let start = self.pos
  let start_col = self.col
  let start_line = self.line
  self.advance()
  let name_start = self.pos
  while !self.at_end() && is_ident_part(self.peek()) {
    self.advance()
  }
  self.tokens.push({
    kind: TokenKind::PackageName,
    text: self.source[name_start:self.pos].to_owned(),
    span: self.span(start, self.pos, start_line, start_col),
  })
}

///|
fn Lexer::scan_bad_character(self : Lexer) -> Unit {
  let start = self.pos
  let span = self.span(start, start + 1, self.line, self.col)
  self.diagnostics.push({
    severity: "error",
    code: "VNX0001",
    message: "unexpected character",
    span,
  })
  self.tokens.push({
    kind: TokenKind::Bad,
    text: self.source[start:start + 1].to_owned(),
    span,
  })
  self.advance()
}

///|
fn Lexer::scan_line_comment(self : Lexer) -> Unit {
  while !self.at_end() && self.peek() != '\n' {
    self.advance()
  }
}

///|
fn Lexer::at_end(self : Lexer) -> Bool {
  self.pos >= self.source.length()
}

///|
fn Lexer::peek(self : Lexer) -> UInt16 {
  self.source[self.pos]
}

///|
fn Lexer::advance(self : Lexer) -> Unit {
  self.pos = self.pos + 1
  self.col = self.col + 1
}

///|
fn Lexer::advance_by(self : Lexer, count : Int) -> Unit {
  for _ in 0..<count {
    self.advance()
  }
}

///|
fn Lexer::advance_line(self : Lexer) -> Unit {
  self.pos = self.pos + 1
  self.line = self.line + 1
  self.col = 1
}

///|
fn Lexer::push_fixed(
  self : Lexer,
  kind : TokenKind,
  text : String,
  start : Int,
  line : Int,
  col : Int,
) -> Unit {
  self.tokens.push({
    kind,
    text,
    span: self.span(start, start + text.length(), line, col),
  })
}

///|
fn Lexer::span(
  self : Lexer,
  start : Int,
  end_ : Int,
  line : Int,
  col : Int,
) -> @common.SourceSpan {
  @text.span(self.file, start, end_, line, col)
}

///|
fn Lexer::has_float_fraction(self : Lexer) -> Bool {
  self.pos + 1 < self.source.length() &&
  self.source[self.pos] == '.' &&
  is_digit(self.source[self.pos + 1])
}

///|
fn Lexer::dot_token(self : Lexer) -> PunctuationToken {
  if self.pos + 1 >= self.source.length() || self.source[self.pos + 1] != '.' {
    return token(TokenKind::Dot, ".")
  }
  if self.pos + 2 >= self.source.length() {
    return token(TokenKind::DotDot, "..")
  }
  match self.source[self.pos + 2] {
    '<' =>
      if self.pos + 3 < self.source.length() && self.source[self.pos + 3] == '=' {
        token(TokenKind::RangeLtInclusive, "..<=")
      } else {
        token(TokenKind::RangeExclusive, "..<")
      }
    '.' => token(TokenKind::Ellipsis, "...")
    '=' => token(TokenKind::RangeInclusive, "..=")
    _ => token(TokenKind::DotDot, "..")
  }
}

///|
fn Lexer::greater_token(self : Lexer) -> PunctuationToken {
  if self.pos + 1 >= self.source.length() {
    return token(TokenKind::Greater, ">")
  }
  match self.source[self.pos + 1] {
    '=' =>
      if self.pos + 3 < self.source.length() &&
        self.source[self.pos + 2] == '.' &&
        self.source[self.pos + 3] == '.' {
        token(TokenKind::RangeInclusiveRev, ">=..")
      } else {
        token(TokenKind::GreaterEq, ">=")
      }
    '.' =>
      if self.pos + 2 < self.source.length() && self.source[self.pos + 2] == '.' {
        token(TokenKind::RangeExclusiveRev, ">..")
      } else {
        token(TokenKind::Greater, ">")
      }
    '>' =>
      if self.pos + 2 < self.source.length() && self.source[self.pos + 2] == '=' {
        token(TokenKind::AugmentedAssign, ">>=")
      } else {
        token(TokenKind::Shr, ">>")
      }
    _ => token(TokenKind::Greater, ">")
  }
}

///|
fn Lexer::less_token(self : Lexer) -> PunctuationToken {
  if self.pos + 1 >= self.source.length() {
    return token(TokenKind::Less, "<")
  }
  match self.source[self.pos + 1] {
    '<' =>
      if self.pos + 2 < self.source.length() && self.source[self.pos + 2] == '=' {
        token(TokenKind::AugmentedAssign, "<<=")
      } else {
        token(TokenKind::Shl, "<<")
      }
    '|' => token(TokenKind::PipeBackward, "<|")
    '+' => token(TokenKind::LessPlus, "<+")
    '=' => token(TokenKind::LessEq, "<=")
    _ => token(TokenKind::Less, "<")
  }
}

///|
fn Lexer::equal_token(self : Lexer) -> PunctuationToken {
  if self.pos + 1 >= self.source.length() {
    return token(TokenKind::Eq, "=")
  }
  match self.source[self.pos + 1] {
    '=' => token(TokenKind::EqEq, "==")
    '>' => token(TokenKind::FatArrow, "=>")
    _ => token(TokenKind::Eq, "=")
  }
}

///|
fn Lexer::pipe_token(self : Lexer) -> PunctuationToken {
  if self.pos + 1 >= self.source.length() {
    return token(TokenKind::Pipe, "|")
  }
  match self.source[self.pos + 1] {
    '|' => token(TokenKind::PipePipe, "||")
    '>' => token(TokenKind::PipeForward, "|>")
    '=' => token(TokenKind::AugmentedAssign, "|=")
    _ => token(TokenKind::Pipe, "|")
  }
}

///|
fn Lexer::amp_token(self : Lexer) -> PunctuationToken {
  if self.pos + 1 >= self.source.length() {
    return token(TokenKind::Amp, "&")
  }
  match self.source[self.pos + 1] {
    '&' => token(TokenKind::AmpAmp, "&&")
    '=' => token(TokenKind::AugmentedAssign, "&=")
    _ => token(TokenKind::Amp, "&")
  }
}

///|
fn Lexer::minus_token(self : Lexer) -> PunctuationToken {
  if self.pos + 1 >= self.source.length() {
    return token(TokenKind::Minus, "-")
  }
  match self.source[self.pos + 1] {
    '>' => token(TokenKind::Arrow, "->")
    '=' => token(TokenKind::AugmentedAssign, "-=")
    _ => token(TokenKind::Minus, "-")
  }
}

///|
fn Lexer::two_char_token(
  self : Lexer,
  second : UInt16,
  two_kind : TokenKind,
  two_text : String,
  one_kind : TokenKind,
  one_text : String,
) -> PunctuationToken {
  if self.pos + 1 < self.source.length() && self.source[self.pos + 1] == second {
    return token(two_kind, two_text)
  }
  token(one_kind, one_text)
}

///|
fn token(kind : TokenKind, text : String) -> PunctuationToken {
  { kind, text }
}

///|
fn classify_leading_char(ch : UInt16) -> LexClass {
  if is_space(ch) {
    LexClass::Space
  } else if ch == '"' {
    LexClass::StringLiteral
  } else if ch == '\'' {
    LexClass::CharLiteral
  } else if ch == '#' {
    LexClass::HashLine
  } else if is_digit(ch) {
    LexClass::NumberLiteral
  } else if is_ident_start(ch) {
    LexClass::IdentifierOrKeyword
  } else {
    LexClass::PunctuationOrBad
  }
}

///|
fn is_space(ch : UInt16) -> Bool {
  ch is (' ' | '\n' | '\r' | '\t')
}

///|
fn is_ident_start(ch : UInt16) -> Bool {
  ch == '_' || (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')
}

///|
fn is_ident_part(ch : UInt16) -> Bool {
  is_ident_start(ch) || (ch >= '0' && ch <= '9')
}

///|
fn is_digit(ch : UInt16) -> Bool {
  ch >= '0' && ch <= '9'
}

///|
fn is_binary_digit(ch : UInt16) -> Bool {
  ch is ('0' | '1')
}

///|
fn is_octal_digit(ch : UInt16) -> Bool {
  ch >= '0' && ch <= '7'
}

///|
fn is_hex_digit(ch : UInt16) -> Bool {
  is_digit(ch) || (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F')
}

///|
fn keyword_kind(text : String) -> TokenKind {
  match text {
    "_" => TokenKind::Underscore
    "fn" => TokenKind::Fn
    "using" => TokenKind::Using
    "pub" => TokenKind::Pub
    "priv" => TokenKind::Priv
    "all" => TokenKind::All
    "readonly" => TokenKind::Readonly
    "import" => TokenKind::Import
    "extern" => TokenKind::Extern
    "break" => TokenKind::Break
    "continue" => TokenKind::Continue
    "struct" => TokenKind::Struct
    "enum" => TokenKind::Enum
    "trait" => TokenKind::Trait
    "derive" => TokenKind::Derive
    "impl" => TokenKind::Impl
    "for" => TokenKind::For
    "in" => TokenKind::In
    "with" => TokenKind::With
    "raise" => TokenKind::Raise
    "throw" => TokenKind::Throw
    "try" => TokenKind::Try
    "catch" => TokenKind::Catch
    "async" => TokenKind::Async
    "typealias" => TokenKind::TypeAlias
    "traitalias" => TokenKind::TraitAlias
    "fnalias" => TokenKind::FnAlias
    "false" => TokenKind::False
    "true" => TokenKind::True
    "mut" => TokenKind::Mut
    "type" => TokenKind::Type
    "as" => TokenKind::As
    "else" => TokenKind::Else
    "if" => TokenKind::If
    "let" => TokenKind::Let
    "const" => TokenKind::Const
    "match" => TokenKind::Match
    "while" => TokenKind::While
    "return" => TokenKind::Return
    "test" => TokenKind::Test
    "loop" => TokenKind::Loop
    "guard" => TokenKind::Guard
    "defer" => TokenKind::Defer
    "is" => TokenKind::Is
    "suberror" => TokenKind::Suberror
    "and" => TokenKind::And
    "letrec" => TokenKind::Letrec
    "enumview" => TokenKind::Enumview
    "declare" => TokenKind::Declare
    "noraise" => TokenKind::Noraise
    "nobreak" => TokenKind::Nobreak
    "where" => TokenKind::Where
    "lexmatch" => TokenKind::Lexmatch
    "package" => TokenKind::Package
    _ => TokenKind::Identifier
  }
}
