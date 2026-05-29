///|
fn Parser::parse_pattern(self : Parser) -> @ast.Pattern {
  let first = self.parse_primary_pattern()
  if !self.pattern_or_continues() {
    return self.parse_optional_alias_pattern(first)
  }
  let alternatives : Array[@ast.Pattern] = [first]
  let mut end_span = pattern_span(first)
  while self.pattern_or_continues() {
    if self.current().kind is (TokenKind::Newline | TokenKind::Semicolon) {
      self.skip_separators()
    }
    ignore(self.bump())
    let next = self.parse_primary_pattern()
    alternatives.push(next)
    end_span = pattern_span(next)
  }
  self.parse_optional_alias_pattern(
    @ast.Pattern::Or(alternatives, merge_span(pattern_span(first), end_span)),
  )
}

///|
fn Parser::parse_optional_alias_pattern(
  self : Parser,
  pattern : @ast.Pattern,
) -> @ast.Pattern {
  if self.current().kind == TokenKind::As {
    ignore(self.bump())
    let name = self.expect(TokenKind::Identifier)
    @ast.Pattern::Alias(
      pattern,
      name.text,
      merge_span(pattern_span(pattern), name.span),
    )
  } else {
    pattern
  }
}

///|
fn Parser::pattern_or_continues(self : Parser) -> Bool {
  if self.current().kind == TokenKind::Pipe {
    true
  } else if self.current().kind is (TokenKind::Newline | TokenKind::Semicolon) {
    self.next_non_separator_token().kind == TokenKind::Pipe
  } else {
    false
  }
}

///|
fn Parser::parse_primary_pattern(self : Parser) -> @ast.Pattern {
  match self.current().kind {
    TokenKind::Underscore => {
      let token = self.bump()
      if self.current().kind
        is (TokenKind::DotDot
        | TokenKind::RangeInclusive
        | TokenKind::RangeExclusive) {
        return self.finish_range_pattern(None, token.span)
      }
      return @ast.Pattern::Wildcard(token.span)
    }
    TokenKind::IntLiteral => {
      let token = self.bump()
      return self.finish_literal_or_range_pattern(
        token.text,
        token.span,
        @ast.Pattern::IntLiteral(token.text, token.span),
      )
    }
    TokenKind::Minus => {
      let start = self.bump()
      let token = self.expect(TokenKind::IntLiteral)
      return self.finish_literal_or_range_pattern(
        "-" + token.text,
        merge_span(start.span, token.span),
        @ast.Pattern::IntLiteral(
          "-" + token.text,
          merge_span(start.span, token.span),
        ),
      )
    }
    TokenKind::DotDot | TokenKind::RangeInclusive | TokenKind::RangeExclusive => {
      let range = self.bump()
      let end = self.parse_optional_pattern_bound()
      let end_span = match end {
        Some(bound) => bound.span
        None => range.span
      }
      return @ast.Pattern::Range(
        None,
        match end {
          Some(bound) => Some(bound.text)
          None => None
        },
        range.kind == TokenKind::RangeInclusive,
        merge_span(range.span, end_span),
      )
    }
    TokenKind::StringLiteral => {
      let token = self.bump()
      return @ast.Pattern::StringLiteral(unquote(token.text), token.span)
    }
    TokenKind::CharLiteral => {
      let token = self.bump()
      let value = unquote(token.text)
      return self.finish_literal_or_range_pattern(
        value,
        token.span,
        @ast.Pattern::CharLiteral(value, token.span),
      )
    }
    TokenKind::True => {
      let token = self.bump()
      return @ast.Pattern::BoolLiteral(true, token.span)
    }
    TokenKind::False => {
      let token = self.bump()
      return @ast.Pattern::BoolLiteral(false, token.span)
    }
    TokenKind::LParen => return self.parse_tuple_pattern()
    TokenKind::LBracket => return self.parse_array_pattern()
    TokenKind::LBrace => return self.parse_struct_pattern()
    TokenKind::PackageName | TokenKind::At =>
      return self.parse_package_constructor_pattern()
    _ => ()
  }
  let first = self.expect(TokenKind::Identifier)
  if self.current().kind == TokenKind::ColonColon {
    ignore(self.bump())
    let variant = self.expect(TokenKind::Identifier)
    let payloads = self.parse_constructor_pattern_args()
    return @ast.Pattern::Constructor(
      Some({
        package_alias: None,
        name: first.text,
        args: [],
        is_trait_object: false,
        span: first.span,
      }),
      variant.text,
      payloads,
      merge_span(first.span, variant.span),
    )
  }
  if self.current().kind == TokenKind::LParen {
    let payloads = self.parse_constructor_pattern_args()
    @ast.Pattern::Constructor(None, first.text, payloads, first.span)
  } else {
    @ast.Pattern::Name(first.text, first.span)
  }
}

///|
fn Parser::parse_package_constructor_pattern(self : Parser) -> @ast.Pattern {
  let alias_name = self.expect_package_name()
  ignore(self.expect(TokenKind::Dot))
  let type_name = self.expect(TokenKind::Identifier)
  ignore(self.expect(TokenKind::ColonColon))
  let variant = self.expect(TokenKind::Identifier)
  let payloads = self.parse_constructor_pattern_args()
  @ast.Pattern::Constructor(
    Some({
      package_alias: Some(alias_name.text),
      name: type_name.text,
      args: [],
      is_trait_object: false,
      span: type_name.span,
    }),
    variant.text,
    payloads,
    merge_span(alias_name.span, variant.span),
  )
}

///|
priv struct PatternBound {
  text : String
  span : @common.SourceSpan
}

///|
fn Parser::finish_literal_or_range_pattern(
  self : Parser,
  start_text : String,
  start_span : @common.SourceSpan,
  fallback : @ast.Pattern,
) -> @ast.Pattern {
  if self.current().kind
    is (TokenKind::DotDot
    | TokenKind::RangeInclusive
    | TokenKind::RangeExclusive) {
    self.finish_range_pattern(Some(start_text), start_span)
  } else {
    fallback
  }
}

///|
fn Parser::finish_range_pattern(
  self : Parser,
  start_text : String?,
  start_span : @common.SourceSpan,
) -> @ast.Pattern {
  let range = self.bump()
  let end = self.parse_optional_pattern_bound()
  let end_span = match end {
    Some(bound) => bound.span
    None => range.span
  }
  @ast.Pattern::Range(
    start_text,
    match end {
      Some(bound) => Some(bound.text)
      None => None
    },
    range.kind == TokenKind::RangeInclusive,
    merge_span(start_span, end_span),
  )
}

///|
fn Parser::parse_optional_pattern_bound(self : Parser) -> PatternBound? {
  match self.current().kind {
    TokenKind::IntLiteral => {
      let token = self.bump()
      Some({ text: token.text, span: token.span })
    }
    TokenKind::CharLiteral => {
      let token = self.bump()
      Some({ text: unquote(token.text), span: token.span })
    }
    TokenKind::Minus => {
      let start = self.bump()
      let token = self.expect(TokenKind::IntLiteral)
      Some({ text: "-" + token.text, span: merge_span(start.span, token.span) })
    }
    TokenKind::Underscore => {
      ignore(self.bump())
      None
    }
    _ => None
  }
}

///|
fn Parser::parse_tuple_pattern(self : Parser) -> @ast.Pattern {
  let start = self.expect(TokenKind::LParen)
  let items : Array[@ast.Pattern] = []
  let mut saw_comma = false
  self.skip_separators()
  while self.current().kind != TokenKind::RParen &&
        self.current().kind != TokenKind::Eof {
    items.push(self.parse_pattern())
    if self.current().kind == TokenKind::Comma {
      ignore(self.bump())
      saw_comma = true
      self.skip_separators()
    } else {
      break
    }
  }
  let close = self.expect(TokenKind::RParen)
  if items.length() == 1 && !saw_comma {
    return items[0]
  }
  @ast.Pattern::Tuple(items, merge_span(start.span, close.span))
}

///|
fn Parser::parse_struct_pattern(self : Parser) -> @ast.Pattern {
  let start = self.expect(TokenKind::LBrace)
  let fields : Array[@ast.StructPatternField] = []
  let mut has_rest = false
  self.skip_separators()
  while self.current().kind != TokenKind::RBrace &&
        self.current().kind != TokenKind::Eof {
    if self.current().kind == TokenKind::DotDot {
      ignore(self.bump())
      has_rest = true
    } else {
      fields.push(self.parse_struct_pattern_field())
    }
    self.skip_separators()
    if self.current().kind == TokenKind::Comma {
      ignore(self.bump())
      self.skip_separators()
    } else {
      break
    }
  }
  let close = self.expect(TokenKind::RBrace)
  @ast.Pattern::Struct(fields, has_rest, merge_span(start.span, close.span))
}

///|
fn Parser::parse_struct_pattern_field(self : Parser) -> @ast.StructPatternField {
  let name = self.expect(TokenKind::Identifier)
  if self.current().kind == TokenKind::Colon ||
    self.current().kind == TokenKind::Eq {
    ignore(self.bump())
    let pattern = self.parse_pattern()
    {
      name: name.text,
      pattern,
      span: merge_span(name.span, pattern_span(pattern)),
    }
  } else {
    {
      name: name.text,
      pattern: @ast.Pattern::Name(name.text, name.span),
      span: name.span,
    }
  }
}

///|
fn Parser::parse_array_pattern(self : Parser) -> @ast.Pattern {
  let start = self.expect(TokenKind::LBracket)
  let prefix : Array[@ast.Pattern] = []
  let suffix : Array[@ast.Pattern] = []
  let mut rest : @ast.ArrayPatternRest? = None
  self.skip_separators()
  while self.current().kind != TokenKind::RBracket &&
        self.current().kind != TokenKind::Eof {
    if self.current().kind == TokenKind::DotDot {
      rest = Some(self.parse_array_pattern_rest())
      self.skip_separators()
      if self.current().kind == TokenKind::Comma {
        ignore(self.bump())
        self.skip_separators()
      }
      while self.current().kind != TokenKind::RBracket &&
            self.current().kind != TokenKind::Eof {
        suffix.push(self.parse_pattern())
        if self.current().kind == TokenKind::Comma {
          ignore(self.bump())
          self.skip_separators()
        } else {
          break
        }
      }
      break
    } else {
      prefix.push(self.parse_pattern())
      if self.current().kind == TokenKind::Comma {
        ignore(self.bump())
        self.skip_separators()
      } else {
        break
      }
    }
  }
  let close = self.expect(TokenKind::RBracket)
  @ast.Pattern::Array(prefix, rest, suffix, merge_span(start.span, close.span))
}

///|
fn Parser::parse_array_pattern_rest(self : Parser) -> @ast.ArrayPatternRest {
  let rest_token = self.expect(TokenKind::DotDot)
  let rest_name = if self.current().kind == TokenKind::Identifier {
    Some(self.bump().text)
  } else {
    None
  }
  { name: rest_name, span: rest_token.span }
}

///|
fn Parser::parse_constructor_pattern_args(self : Parser) -> Array[@ast.Pattern] {
  let payloads : Array[@ast.Pattern] = []
  if self.current().kind != TokenKind::LParen {
    return payloads
  }
  ignore(self.bump())
  self.skip_separators()
  while self.current().kind != TokenKind::RParen &&
        self.current().kind != TokenKind::Eof {
    payloads.push(self.parse_constructor_pattern_payload())
    self.skip_separators()
    if self.current().kind == TokenKind::Comma {
      ignore(self.bump())
      self.skip_separators()
    } else {
      break
    }
  }
  ignore(self.expect(TokenKind::RParen))
  payloads
}

///|
fn Parser::parse_constructor_pattern_payload(self : Parser) -> @ast.Pattern {
  if self.current().kind == TokenKind::DotDot {
    let rest = self.bump()
    @ast.Pattern::Rest(rest.span)
  } else if self.current().kind == TokenKind::Identifier &&
    self.peek().kind == TokenKind::Tilde {
    let label = self.bump()
    ignore(self.bump())
    @ast.Pattern::Labelled(
      label.text,
      @ast.Pattern::Name(label.text, label.span),
      label.span,
    )
  } else if self.current().kind == TokenKind::Identifier &&
    self.peek().kind == TokenKind::Eq {
    let label = self.bump()
    ignore(self.bump())
    let pattern = self.parse_pattern()
    @ast.Pattern::Labelled(
      label.text,
      pattern,
      merge_span(label.span, pattern_span(pattern)),
    )
  } else {
    self.parse_pattern()
  }
}

///|
fn pattern_span(pattern : @ast.Pattern) -> @common.SourceSpan {
  match pattern {
    @ast.Pattern::Wildcard(span)
    | @ast.Pattern::Name(_, span)
    | @ast.Pattern::IntLiteral(_, span)
    | @ast.Pattern::CharLiteral(_, span)
    | @ast.Pattern::StringLiteral(_, span)
    | @ast.Pattern::BoolLiteral(_, span)
    | @ast.Pattern::Range(_, _, _, span)
    | @ast.Pattern::Tuple(_, span)
    | @ast.Pattern::Array(_, _, _, span)
    | @ast.Pattern::Struct(_, _, span)
    | @ast.Pattern::Or(_, span)
    | @ast.Pattern::Alias(_, _, span)
    | @ast.Pattern::Labelled(_, _, span)
    | @ast.Pattern::Rest(span)
    | @ast.Pattern::Constructor(_, _, _, span) => span
  }
}
