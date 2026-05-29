///|
fn Parser::parse_block_expr(self : Parser) -> @ast.Expr {
  self.skip_separators()
  if self.current().kind is (TokenKind::RBrace | TokenKind::Eof) {
    @ast.Expr::UnitLiteral(self.current().span)
  } else if self.current().kind == TokenKind::Let {
    let start = self.expect(TokenKind::Let)
    if self.current().kind == TokenKind::Mut {
      ignore(self.bump())
    }
    let pattern = self.parse_pattern()
    let explicit_type = if pattern is @ast.Pattern::Name(_, _) &&
      self.current().kind == TokenKind::Colon {
      ignore(self.bump())
      Some(self.parse_type())
    } else {
      None
    }
    ignore(self.expect(TokenKind::Eq))
    self.skip_separators()
    let value = self.parse_expr()
    self.expect_statement_separator()
    let body = self.parse_block_expr()
    match pattern {
      @ast.Pattern::Name(name, _) =>
        @ast.Expr::LocalLet(
          name,
          explicit_type,
          value,
          body,
          merge_span(start.span, @ast.expr_span(body)),
        )
      _ =>
        @ast.Expr::LocalLetPattern(
          pattern,
          value,
          body,
          merge_span(start.span, @ast.expr_span(body)),
        )
    }
  } else if self.current().kind == TokenKind::Fn {
    let function_ = self.parse_function(false)
    self.expect_statement_separator()
    let body = self.parse_block_expr()
    @ast.Expr::LocalFunction(
      function_,
      body,
      merge_span(function_.span, @ast.expr_span(body)),
    )
  } else {
    let first = self.parse_expr()
    if self.current().kind is (TokenKind::RBrace | TokenKind::Eof) {
      first
    } else {
      self.expect_statement_separator()
      if self.current().kind is (TokenKind::RBrace | TokenKind::Eof) {
        first
      } else {
        let body = self.parse_block_expr()
        @ast.Expr::Sequence(
          first,
          body,
          merge_span(@ast.expr_span(first), @ast.expr_span(body)),
        )
      }
    }
  }
}

///|

///|
fn Parser::parse_expr(self : Parser) -> @ast.Expr {
  if self.current().kind == TokenKind::LParen &&
    self.parenthesized_lambda_ahead() {
    return self.parse_parenthesized_lambda()
  }
  let left = self.parse_pipe_expr()
  if self.current().kind == TokenKind::FatArrow {
    ignore(self.bump())
    let body = if self.current().kind == TokenKind::LBrace {
      ignore(self.bump())
      let block = self.parse_block_expr()
      self.skip_separators()
      ignore(self.expect(TokenKind::RBrace))
      block
    } else {
      self.parse_expr()
    }
    @ast.Expr::Lambda(
      lambda_param_names(left),
      body,
      merge_span(@ast.expr_span(left), @ast.expr_span(body)),
    )
  } else if self.current().kind == TokenKind::Eq {
    ignore(self.bump())
    let value = self.parse_expr()
    @ast.Expr::Assign(
      left,
      value,
      merge_span(@ast.expr_span(left), @ast.expr_span(value)),
    )
  } else if self.current().kind == TokenKind::AugmentedAssign {
    let op = self.bump()
    let value = self.parse_expr()
    let binary = @ast.Expr::Binary(
      op.text[0:op.text.length() - 1].to_owned(),
      left,
      value,
      merge_span(@ast.expr_span(left), @ast.expr_span(value)),
    )
    @ast.Expr::Assign(
      left,
      binary,
      merge_span(@ast.expr_span(left), @ast.expr_span(value)),
    )
  } else if self.current().kind == TokenKind::Catch {
    self.parse_catch_expr(left)
  } else {
    left
  }
}

///|
fn Parser::parenthesized_lambda_ahead(self : Parser) -> Bool {
  if self.current().kind != TokenKind::LParen {
    return false
  }
  let mut cursor = 0
  let mut depth = 0
  while self.peek_token(cursor).kind != TokenKind::Eof {
    match self.peek_token(cursor).kind {
      TokenKind::LParen => depth = depth + 1
      TokenKind::RParen => {
        depth = depth - 1
        if depth == 0 {
          let mut next = cursor + 1
          while self.peek_token(next).kind
                is (TokenKind::Newline | TokenKind::Semicolon) {
            next = next + 1
          }
          return self.peek_token(next).kind == TokenKind::FatArrow
        }
      }
      _ => ()
    }
    cursor = cursor + 1
  }
  false
}

///|
fn Parser::parse_parenthesized_lambda(self : Parser) -> @ast.Expr {
  let open = self.expect(TokenKind::LParen)
  let params : Array[String] = []
  self.skip_separators()
  while self.current().kind != TokenKind::RParen &&
        self.current().kind != TokenKind::Eof {
    let name = self.expect(TokenKind::Identifier)
    params.push(name.text)
    if self.current().kind == TokenKind::Colon {
      ignore(self.bump())
      ignore(self.parse_type())
    }
    if self.current().kind == TokenKind::Comma {
      ignore(self.bump())
      self.skip_separators()
    } else {
      break
    }
  }
  ignore(self.expect(TokenKind::RParen))
  self.skip_separators()
  ignore(self.expect(TokenKind::FatArrow))
  let body = self.parse_lambda_body()
  @ast.Expr::Lambda(params, body, merge_span(open.span, @ast.expr_span(body)))
}

///|
fn Parser::parse_lambda_body(self : Parser) -> @ast.Expr {
  if self.current().kind == TokenKind::LBrace {
    ignore(self.bump())
    let block = self.parse_block_expr()
    self.skip_separators()
    ignore(self.expect(TokenKind::RBrace))
    block
  } else {
    self.parse_expr()
  }
}

///|
fn Parser::parse_pipe_expr(self : Parser) -> @ast.Expr {
  let mut left = self.parse_is_expr()
  while self.current().kind
        is (TokenKind::PipeForward | TokenKind::PipeBackward) {
    let token = self.bump()
    let right = self.parse_is_expr()
    left = @ast.Expr::Pipe(
      left,
      right,
      token.kind == TokenKind::PipeForward,
      merge_span(@ast.expr_span(left), @ast.expr_span(right)),
    )
  }
  left
}

///|
fn lambda_param_names(expr : @ast.Expr) -> Array[String] {
  match expr {
    @ast.Expr::Name(name, _) => [name]
    @ast.Expr::UnitLiteral(_) => []
    @ast.Expr::TupleLiteral(items, _) => {
      let names : Array[String] = []
      for item in items {
        match item {
          @ast.Expr::Name(name, _) => names.push(name)
          _ => ()
        }
      }
      names
    }
    _ => []
  }
}

///|
fn Parser::parse_is_expr(self : Parser) -> @ast.Expr {
  self.parse_add_expr()
}

///|
fn Parser::parse_is_operand(self : Parser) -> @ast.Expr {
  let mut left = self.parse_unary_expr()
  while self.is_expr_continuation_ahead() {
    ignore(self.bump())
    let pattern = self.parse_pattern()
    left = @ast.Expr::IsPattern(
      left,
      pattern,
      merge_span(@ast.expr_span(left), pattern_span(pattern)),
    )
  }
  left
}

///|
fn Parser::is_expr_continuation_ahead(self : Parser) -> Bool {
  if self.current().kind == TokenKind::Is {
    return true
  }
  if self.current().kind == TokenKind::Newline &&
    self.next_non_separator_token().kind == TokenKind::Is {
    self.skip_separators()
    return true
  }
  false
}

///|
fn Parser::parse_add_expr(self : Parser) -> @ast.Expr {
  self.parse_binary_expr(1)
}

///|
fn Parser::parse_binary_expr(self : Parser, min_precedence : Int) -> @ast.Expr {
  let mut left = self.parse_is_operand()
  while binary_precedence(self.current().kind) >= min_precedence {
    let op = self.bump()
    self.skip_separators()
    let right = self.parse_binary_expr(binary_precedence(op.kind) + 1)
    left = @ast.Expr::Binary(
      op.text,
      left,
      right,
      merge_span(@ast.expr_span(left), @ast.expr_span(right)),
    )
  }
  left
}

///|
fn Parser::parse_unary_expr(self : Parser) -> @ast.Expr {
  match self.current().kind {
    TokenKind::Minus => {
      let op = self.bump()
      let value = self.parse_unary_expr()
      @ast.Expr::Unary(
        op.text,
        value,
        merge_span(op.span, @ast.expr_span(value)),
      )
    }
    TokenKind::Exclamation => {
      let op = self.bump()
      let value = self.parse_unary_expr()
      @ast.Expr::Unary(
        op.text,
        value,
        merge_span(op.span, @ast.expr_span(value)),
      )
    }
    _ => self.parse_primary()
  }
}

///|
fn Parser::parse_primary(self : Parser) -> @ast.Expr {
  let mut expr = match self.current().kind {
    TokenKind::PackageName | TokenKind::At =>
      self.parse_package_access_or_static_access()
    TokenKind::Identifier => {
      let token = self.bump()
      @ast.Expr::Name(token.text, token.span)
    }
    TokenKind::IntLiteral => {
      let token = self.bump()
      @ast.Expr::IntLiteral(token.text, token.span)
    }
    TokenKind::FloatLiteral => {
      let token = self.bump()
      @ast.Expr::FloatLiteral(token.text, token.span)
    }
    TokenKind::CharLiteral => {
      let token = self.bump()
      @ast.Expr::CharLiteral(unquote(token.text), token.span)
    }
    TokenKind::StringLiteral => self.parse_string_literal_expr()
    TokenKind::Fn => self.parse_lambda()
    TokenKind::True => {
      let token = self.bump()
      @ast.Expr::BoolLiteral(true, token.span)
    }
    TokenKind::False => {
      let token = self.bump()
      @ast.Expr::BoolLiteral(false, token.span)
    }
    TokenKind::If => self.parse_if()
    TokenKind::Match => self.parse_match()
    TokenKind::Lexmatch => self.parse_unsupported_lexmatch()
    TokenKind::Guard => self.parse_guard()
    TokenKind::Raise => self.parse_raise()
    TokenKind::Try => self.parse_try_catch()
    TokenKind::While => self.parse_while()
    TokenKind::Return => self.parse_return()
    TokenKind::LParen => self.parse_parenthesized_or_unit()
    TokenKind::For => self.parse_for()
    TokenKind::Break => self.parse_break()
    TokenKind::Continue => self.parse_continue()
    TokenKind::LBracket => self.parse_array_literal()
    TokenKind::LBrace => self.parse_brace_literal()
    _ => {
      let token = self.expect(TokenKind::Identifier)
      @ast.Expr::Missing(token.span)
    }
  }
  while self.postfix_expr_continues() {
    if self.current().kind is (TokenKind::Newline | TokenKind::Semicolon) {
      self.skip_separators()
    }
    if self.current().kind == TokenKind::LParen {
      let start = @ast.expr_span(expr)
      ignore(self.bump())
      let args : Array[@ast.CallArg] = []
      self.skip_separators()
      if self.current().kind != TokenKind::RParen {
        while !self.at_param_list_end() {
          args.push(self.parse_call_arg())
          self.skip_separators()
          if self.current().kind == TokenKind::Comma {
            ignore(self.bump())
            self.skip_separators()
          } else {
            break
          }
        }
      }
      let close = self.expect(TokenKind::RParen)
      expr = @ast.Expr::Call(expr, args, merge_span(start, close.span))
    } else if self.current().kind == TokenKind::LBracket {
      expr = self.parse_index_or_slice(expr)
    } else {
      if self.current().kind == TokenKind::ColonColon {
        let start = @ast.expr_span(expr)
        ignore(self.bump())
        if self.current().kind == TokenKind::LBrace {
          match expr_as_type_syntax(expr) {
            Some(type_syntax) =>
              expr = self.parse_typed_struct_literal(type_syntax, start)
            None => {
              self.diagnostics.push({
                severity: "error",
                code: "VNX0103",
                message: "typed struct literal requires a type name",
                span: start,
              })
              expr = @ast.Expr::Missing(start)
            }
          }
          continue
        }
        let name = self.expect_name_token()
        match expr {
          @ast.Expr::Name(type_name, type_span) =>
            expr = @ast.Expr::StaticAccess(
              {
                package_alias: None,
                name: type_name,
                args: [],
                is_trait_object: false,
                span: type_span,
              },
              name.text,
              merge_span(start, name.span),
            )
          _ => {
            self.diagnostics.push({
              severity: "error",
              code: "VNX0102",
              message: "static access requires a type name",
              span: start,
            })
            expr = @ast.Expr::Missing(start)
          }
        }
        continue
      }
      let start = @ast.expr_span(expr)
      ignore(self.bump())
      let name = if self.current().kind == TokenKind::IntLiteral {
        self.bump()
      } else {
        self.expect_name_token()
      }
      expr = @ast.Expr::FieldAccess(
        expr,
        name.text,
        merge_span(start, name.span),
      )
    }
  }
  expr
}

///|
fn Parser::parse_unsupported_lexmatch(self : Parser) -> @ast.Expr {
  let start = self.expect(TokenKind::Lexmatch)
  if self.current().kind == TokenKind::LBrace {
    self.skip_balanced_braces()
  } else {
    while !(self.current().kind is (TokenKind::LBrace | TokenKind::Eof)) {
      ignore(self.bump())
    }
    if self.current().kind == TokenKind::LBrace {
      self.skip_balanced_braces()
    }
  }
  @ast.Expr::Missing(start.span)
}

///|
fn Parser::parse_raise(self : Parser) -> @ast.Expr {
  let start = self.expect(TokenKind::Raise)
  let value = self.parse_expr()
  @ast.Expr::Raise(value, merge_span(start.span, @ast.expr_span(value)))
}

///|
fn Parser::parse_try_catch(self : Parser) -> @ast.Expr {
  let start = self.expect(TokenKind::Try)
  let body = self.parse_braced_block_expr()
  self.skip_separators()
  let expr = self.parse_catch_expr(body)
  @ast.Expr::TryCatch(
    body,
    try_catch_arms(expr),
    merge_span(start.span, @ast.expr_span(expr)),
  )
}

///|
fn Parser::parse_catch_expr(self : Parser, body : @ast.Expr) -> @ast.Expr {
  let start = @ast.expr_span(body)
  ignore(self.expect(TokenKind::Catch))
  ignore(self.expect(TokenKind::LBrace))
  let arms : Array[@ast.MatchArm] = []
  self.skip_separators()
  while self.current().kind != TokenKind::RBrace &&
        self.current().kind != TokenKind::Eof {
    if self.current().kind == TokenKind::Pipe {
      ignore(self.bump())
      self.skip_separators()
    }
    let pattern = self.parse_pattern()
    ignore(self.expect(TokenKind::FatArrow))
    self.skip_separators()
    let arm_body = if self.current().kind == TokenKind::LBrace {
      self.parse_braced_block_expr()
    } else {
      self.parse_expr()
    }
    arms.push({
      pattern,
      condition: None,
      body: arm_body,
      span: merge_span(pattern_span(pattern), @ast.expr_span(arm_body)),
    })
    self.skip_separators()
  }
  let close = self.expect(TokenKind::RBrace)
  @ast.Expr::TryCatch(body, arms, merge_span(start, close.span))
}

///|
fn try_catch_arms(expr : @ast.Expr) -> Array[@ast.MatchArm] {
  match expr {
    @ast.Expr::TryCatch(_, arms, _) => arms
    _ => []
  }
}

///|
fn Parser::postfix_expr_continues(self : Parser) -> Bool {
  if self.current().kind
    is (TokenKind::LParen
    | TokenKind::LBracket
    | TokenKind::Dot
    | TokenKind::ColonColon) {
    return true
  }
  if self.current().kind is (TokenKind::Newline | TokenKind::Semicolon) {
    let next = self.next_non_separator_token()
    next.kind == TokenKind::Dot
  } else {
    false
  }
}

///|
fn Parser::next_non_separator_token(self : Parser) -> Token {
  let mut cursor = 0
  while self.peek_token(cursor).kind
        is (TokenKind::Newline | TokenKind::Semicolon) {
    cursor = cursor + 1
  }
  self.peek_token(cursor)
}

///|
fn Parser::parse_break(self : Parser) -> @ast.Expr {
  let start = self.expect(TokenKind::Break)
  let value = if self.current().kind
    is (TokenKind::Newline
    | TokenKind::Semicolon
    | TokenKind::RBrace
    | TokenKind::Eof) {
    None
  } else {
    Some(self.parse_expr())
  }
  let span = match value {
    Some(expr) => merge_span(start.span, @ast.expr_span(expr))
    None => start.span
  }
  @ast.Expr::Break(value, span)
}

///|
fn Parser::parse_continue(self : Parser) -> @ast.Expr {
  let start = self.expect(TokenKind::Continue)
  let args : Array[@ast.Expr] = []
  while !(self.current().kind
        is (TokenKind::Newline
        | TokenKind::Semicolon
        | TokenKind::RBrace
        | TokenKind::Eof)) {
    args.push(self.parse_expr())
    if self.current().kind == TokenKind::Comma {
      ignore(self.bump())
      self.skip_separators()
    } else {
      break
    }
  }
  let span = if args.length() == 0 {
    start.span
  } else {
    merge_span(start.span, @ast.expr_span(args[args.length() - 1]))
  }
  @ast.Expr::Continue(args, span)
}

///|
fn Parser::parse_index_or_slice(self : Parser, target : @ast.Expr) -> @ast.Expr {
  let start = @ast.expr_span(target)
  ignore(self.expect(TokenKind::LBracket))
  let first = if self.current().kind == TokenKind::Colon ||
    self.current().kind == TokenKind::RBracket {
    None
  } else {
    Some(self.parse_expr())
  }
  let mut is_slice = false
  let second = if self.current().kind == TokenKind::Colon {
    is_slice = true
    ignore(self.bump())
    if self.current().kind == TokenKind::RBracket {
      None
    } else {
      Some(self.parse_expr())
    }
  } else {
    None
  }
  let close = self.expect(TokenKind::RBracket)
  @ast.Expr::Index(
    target,
    first,
    second,
    is_slice,
    merge_span(start, close.span),
  )
}

///|
fn Parser::parse_lambda(self : Parser) -> @ast.Expr {
  let start = self.expect(TokenKind::Fn)
  ignore(self.expect(TokenKind::LParen))
  let params : Array[String] = []
  while self.current().kind != TokenKind::RParen &&
        self.current().kind != TokenKind::Eof {
    let name = self.expect(TokenKind::Identifier)
    params.push(name.text)
    if self.current().kind == TokenKind::Colon {
      ignore(self.bump())
      ignore(self.parse_type())
    }
    if self.current().kind == TokenKind::Comma {
      ignore(self.bump())
    } else {
      break
    }
  }
  ignore(self.expect(TokenKind::RParen))
  if self.current().kind == TokenKind::Arrow {
    ignore(self.bump())
    ignore(self.parse_type())
    self.skip_effect_suffix()
  }
  ignore(self.expect(TokenKind::LBrace))
  let body = self.parse_block_expr()
  self.skip_separators()
  let close = self.expect(TokenKind::RBrace)
  @ast.Expr::Lambda(params, body, merge_span(start.span, close.span))
}

///|
fn Parser::parse_guard(self : Parser) -> @ast.Expr {
  let start = self.expect(TokenKind::Guard)
  let condition = self.parse_guard_condition()
  if self.current().kind == TokenKind::Newline &&
    self.next_non_separator_token().kind == TokenKind::Else {
    self.skip_separators()
  }
  let else_ = if self.current().kind == TokenKind::Else {
    ignore(self.bump())
    ignore(self.expect(TokenKind::LBrace))
    let body = self.parse_block_expr()
    self.skip_separators()
    ignore(self.expect(TokenKind::RBrace))
    body
  } else {
    @ast.Expr::UnitLiteral(start.span)
  }
  @ast.Expr::Guard(
    condition,
    else_,
    merge_span(start.span, @ast.expr_span(else_)),
  )
}

///|
fn Parser::parse_guard_condition(self : Parser) -> @ast.Expr {
  let left = self.parse_expr()
  if self.current().kind == TokenKind::Newline &&
    self.next_non_separator_token().kind == TokenKind::Is {
    self.skip_separators()
  }
  if self.current().kind == TokenKind::Is {
    ignore(self.bump())
    let pattern = self.parse_pattern()
    @ast.Expr::IsPattern(
      left,
      pattern,
      merge_span(@ast.expr_span(left), pattern_span(pattern)),
    )
  } else {
    left
  }
}

///|
fn Parser::parse_while(self : Parser) -> @ast.Expr {
  let start = self.expect(TokenKind::While)
  let condition = self.parse_expr()
  ignore(self.expect(TokenKind::LBrace))
  let body = self.parse_block_expr()
  self.skip_separators()
  let close = self.expect(TokenKind::RBrace)
  let (no_break_expr, end_span) = self.parse_optional_nobreak_clause(close.span)
  match no_break_expr {
    Some(_) =>
      @ast.Expr::ForLoop(
        [],
        Some(condition),
        [],
        body,
        no_break_expr,
        merge_span(start.span, end_span),
      )
    None =>
      @ast.Expr::While(condition, body, merge_span(start.span, close.span))
  }
}

///|
fn Parser::parse_return(self : Parser) -> @ast.Expr {
  let start = self.expect(TokenKind::Return)
  let value = if self.current().kind
    is (TokenKind::Newline
    | TokenKind::Semicolon
    | TokenKind::RBrace
    | TokenKind::Eof) {
    None
  } else {
    Some(self.parse_expr())
  }
  let span = match value {
    Some(expr) => merge_span(start.span, @ast.expr_span(expr))
    None => start.span
  }
  @ast.Expr::Return(value, span)
}

///|
fn Parser::parse_if(self : Parser) -> @ast.Expr {
  let start = self.expect(TokenKind::If)
  let condition = self.parse_expr()
  ignore(self.expect(TokenKind::LBrace))
  let then_ = self.parse_block_expr()
  ignore(self.expect(TokenKind::RBrace))
  let else_ = if self.current().kind == TokenKind::Else {
    ignore(self.bump())
    if self.current().kind == TokenKind::If {
      self.parse_if()
    } else {
      ignore(self.expect(TokenKind::LBrace))
      let body = self.parse_block_expr()
      ignore(self.expect(TokenKind::RBrace))
      body
    }
  } else {
    @ast.Expr::UnitLiteral(start.span)
  }
  @ast.Expr::If(
    condition,
    then_,
    else_,
    merge_span(start.span, @ast.expr_span(else_)),
  )
}

///|
fn Parser::parse_match(self : Parser) -> @ast.Expr {
  let start = self.expect(TokenKind::Match)
  self.skip_separators()
  let target = self.parse_expr()
  ignore(self.expect(TokenKind::LBrace))
  let arms : Array[@ast.MatchArm] = []
  self.skip_separators()
  while self.current().kind != TokenKind::RBrace &&
        self.current().kind != TokenKind::Eof {
    if self.current().kind == TokenKind::Pipe {
      ignore(self.bump())
      self.skip_separators()
    }
    let pattern = self.parse_pattern()
    let condition = if self.current().kind == TokenKind::If {
      ignore(self.bump())
      Some(self.parse_is_expr())
    } else {
      None
    }
    ignore(self.expect(TokenKind::FatArrow))
    self.skip_separators()
    let body = self.parse_expr()
    arms.push({
      pattern,
      condition,
      body,
      span: merge_span(pattern_span(pattern), @ast.expr_span(body)),
    })
    self.skip_separators()
  }
  let close = self.expect(TokenKind::RBrace)
  @ast.Expr::Match(target, arms, merge_span(start.span, close.span))
}

///|
fn Parser::parse_parenthesized_or_unit(self : Parser) -> @ast.Expr {
  let open = self.expect(TokenKind::LParen)
  self.skip_separators()
  if self.current().kind == TokenKind::RParen {
    let close = self.bump()
    @ast.Expr::UnitLiteral(merge_span(open.span, close.span))
  } else {
    let items : Array[@ast.Expr] = [self.parse_expr()]
    if self.current().kind == TokenKind::Colon {
      ignore(self.bump())
      let type_ = self.parse_type()
      self.skip_separators()
      let close = self.expect(TokenKind::RParen)
      return @ast.Expr::TypeAscription(
        items[0],
        type_,
        merge_span(open.span, close.span),
      )
    }
    while self.current().kind == TokenKind::Comma {
      ignore(self.bump())
      self.skip_separators()
      if self.current().kind == TokenKind::RParen {
        break
      }
      items.push(self.parse_expr())
    }
    self.skip_separators()
    let close = self.expect(TokenKind::RParen)
    if items.length() == 1 {
      items[0]
    } else {
      @ast.Expr::TupleLiteral(items, merge_span(open.span, close.span))
    }
  }
}

///|
fn Parser::parse_for(self : Parser) -> @ast.Expr {
  let start = self.expect(TokenKind::For)
  self.skip_separators()
  if self.current().kind is (TokenKind::Identifier | TokenKind::Underscore) &&
    (self.peek().kind == TokenKind::In || self.peek().kind == TokenKind::Comma) {
    return self.parse_for_in_after_for(start)
  }
  self.parse_for_loop_after_for(start)
}

///|
fn Parser::parse_for_in_after_for(self : Parser, start : Token) -> @ast.Expr {
  let names : Array[String] = []
  names.push(self.expect_loop_binding_name().text)
  while self.current().kind == TokenKind::Comma {
    ignore(self.bump())
    names.push(self.expect_loop_binding_name().text)
  }
  ignore(self.expect(TokenKind::In))
  let value = self.parse_expr()
  if is_range_token(self.current().kind) && names.length() == 1 {
    let range_kind = self.parse_range_kind()
    let range_end = self.parse_expr()
    let bindings = self.parse_optional_loop_state_bindings()
    ignore(self.expect(TokenKind::LBrace))
    let range_body = self.parse_block_expr()
    self.skip_separators()
    let range_close = self.expect(TokenKind::RBrace)
    let (no_break_expr, end_span) = self.parse_optional_nobreak_clause(
      range_close.span,
    )
    return @ast.Expr::ForRange(
      names[0],
      value,
      range_kind,
      range_end,
      bindings,
      range_body,
      no_break_expr,
      merge_span(start.span, end_span),
    )
  }
  let bindings = self.parse_optional_loop_state_bindings()
  ignore(self.expect(TokenKind::LBrace))
  let body = self.parse_block_expr()
  self.skip_separators()
  let close = self.expect(TokenKind::RBrace)
  let (no_break_expr, end_span) = self.parse_optional_nobreak_clause(close.span)
  @ast.Expr::ForIn(
    names,
    value,
    bindings,
    body,
    no_break_expr,
    merge_span(start.span, end_span),
  )
}

///|
fn Parser::expect_loop_binding_name(self : Parser) -> Token {
  if self.current().kind is (TokenKind::Identifier | TokenKind::Underscore) {
    self.bump()
  } else {
    self.expect(TokenKind::Identifier)
  }
}

///|
fn Parser::parse_for_loop_after_for(self : Parser, start : Token) -> @ast.Expr {
  let bindings : Array[@ast.ForLoopBinding] = []
  if !(self.current().kind is (TokenKind::Semicolon | TokenKind::Newline)) {
    while !(self.current().kind is (TokenKind::Semicolon | TokenKind::Newline)) &&
          self.current().kind != TokenKind::Eof {
      let name = self.expect(TokenKind::Identifier)
      ignore(self.expect(TokenKind::Eq))
      let value = self.parse_expr()
      bindings.push({ name: name.text, value, span: name.span })
      if self.current().kind == TokenKind::Comma {
        ignore(self.bump())
      } else {
        break
      }
    }
  }
  if self.current().kind == TokenKind::LBrace {
    ignore(self.bump())
    let body = self.parse_block_expr()
    self.skip_separators()
    let close = self.expect(TokenKind::RBrace)
    let (no_break_expr, end_span) = self.parse_optional_nobreak_clause(
      close.span,
    )
    return @ast.Expr::ForLoop(
      bindings,
      None,
      [],
      body,
      no_break_expr,
      merge_span(start.span, end_span),
    )
  }
  self.expect_for_clause_separator()
  let condition = if self.current().kind
    is (TokenKind::Semicolon | TokenKind::Newline) {
    None
  } else {
    Some(self.parse_expr())
  }
  self.expect_for_clause_separator()
  let updates : Array[@ast.Expr] = []
  if self.current().kind != TokenKind::LBrace {
    while self.current().kind != TokenKind::LBrace &&
          self.current().kind != TokenKind::Eof {
      updates.push(self.parse_expr())
      if self.current().kind == TokenKind::Comma {
        ignore(self.bump())
      } else {
        break
      }
    }
  }
  ignore(self.expect(TokenKind::LBrace))
  let body = self.parse_block_expr()
  self.skip_separators()
  let close = self.expect(TokenKind::RBrace)
  let (no_break_expr, end_span) = self.parse_optional_nobreak_clause(close.span)
  @ast.Expr::ForLoop(
    bindings,
    condition,
    updates,
    body,
    no_break_expr,
    merge_span(start.span, end_span),
  )
}

///|
fn Parser::parse_optional_loop_state_bindings(
  self : Parser,
) -> Array[@ast.ForLoopBinding] {
  let bindings : Array[@ast.ForLoopBinding] = []
  if self.current().kind == TokenKind::Semicolon {
    ignore(self.bump())
  } else if self.current().kind == TokenKind::Newline &&
    self.loop_state_binding_follows_after_separators() {
    self.skip_separators()
  } else {
    return bindings
  }
  self.skip_separators()
  while self.current().kind != TokenKind::LBrace &&
        self.current().kind != TokenKind::Eof {
    let name = self.expect(TokenKind::Identifier)
    ignore(self.expect(TokenKind::Eq))
    let value = self.parse_expr()
    bindings.push({ name: name.text, value, span: name.span })
    if self.current().kind == TokenKind::Comma {
      ignore(self.bump())
      self.skip_separators()
    } else {
      break
    }
  }
  bindings
}

///|
fn Parser::loop_state_binding_follows_after_separators(self : Parser) -> Bool {
  match self.peek_non_separator_tokens(0) {
    (first, second) =>
      first.kind == TokenKind::Identifier && second.kind == TokenKind::Eq
  }
}

///|
fn Parser::parse_optional_nobreak_clause(
  self : Parser,
  close_span : @common.SourceSpan,
) -> (@ast.Expr?, @common.SourceSpan) {
  if self.current().kind == TokenKind::Newline &&
    self.next_non_separator_token().kind == TokenKind::Nobreak {
    self.skip_separators()
  }
  if self.current().kind != TokenKind::Nobreak {
    return (None, close_span)
  }
  ignore(self.bump())
  self.skip_separators()
  ignore(self.expect(TokenKind::LBrace))
  let body = self.parse_block_expr()
  self.skip_separators()
  let close = self.expect(TokenKind::RBrace)
  (Some(body), close.span)
}

///|
fn Parser::expect_for_clause_separator(self : Parser) -> Unit {
  if self.current().kind == TokenKind::Semicolon {
    ignore(self.bump())
  } else if self.current().kind == TokenKind::Newline {
    self.skip_separators()
  } else {
    ignore(self.expect(TokenKind::Semicolon))
  }
}

///|
fn Parser::parse_range_kind(self : Parser) -> @ast.RangeKind {
  let token = self.bump()
  match token.kind {
    TokenKind::DotDot => @ast.RangeKind::DotDot
    TokenKind::RangeInclusive => @ast.RangeKind::Inclusive
    TokenKind::RangeLtInclusive => @ast.RangeKind::LtInclusive
    TokenKind::RangeExclusive => @ast.RangeKind::Exclusive
    TokenKind::RangeInclusiveRev => @ast.RangeKind::InclusiveReverse
    TokenKind::RangeExclusiveRev => @ast.RangeKind::ExclusiveReverse
    _ => {
      self.diagnostics.push({
        severity: "error",
        code: "VNX0103",
        message: "expected range operator",
        span: token.span,
      })
      @ast.RangeKind::Exclusive
    }
  }
}

///|
fn is_range_token(kind : TokenKind) -> Bool {
  kind
  is (TokenKind::DotDot
  | TokenKind::RangeInclusive
  | TokenKind::RangeLtInclusive
  | TokenKind::RangeExclusive
  | TokenKind::RangeInclusiveRev
  | TokenKind::RangeExclusiveRev)
}

///|
fn Parser::parse_package_access_or_static_access(self : Parser) -> @ast.Expr {
  let first = if self.current().kind == TokenKind::PackageName {
    self.bump()
  } else {
    ignore(self.expect(TokenKind::At))
    if self.current().kind == TokenKind::Fn {
      let function_ = self.parse_function(false)
      self.expect_statement_separator()
      let body = self.parse_block_expr()
      return @ast.Expr::LocalFunction(
        function_,
        body,
        merge_span(function_.span, @ast.expr_span(body)),
      )
    }
    match self.current().kind {
      TokenKind::Identifier | TokenKind::Package => self.bump()
      _ => self.expect(TokenKind::Identifier)
    }
  }
  if self.current().kind == TokenKind::Dot {
    ignore(self.bump())
    let member_name = self.expect_name_token()
    if self.current().kind == TokenKind::ColonColon {
      let target_type : @ast.TypeSyntax = {
        package_alias: Some(first.text),
        name: member_name.text,
        args: [],
        is_trait_object: false,
        span: member_name.span,
      }
      ignore(self.bump())
      if self.current().kind == TokenKind::LBrace {
        self.parse_typed_struct_literal(target_type, first.span)
      } else {
        let name = self.expect_name_token()
        @ast.Expr::StaticAccess(
          target_type,
          name.text,
          merge_span(first.span, name.span),
        )
      }
    } else {
      @ast.Expr::PackageAccess(
        first.text,
        member_name.text,
        merge_span(first.span, member_name.span),
      )
    }
  } else {
    let target_type : @ast.TypeSyntax = {
      package_alias: None,
      name: first.text,
      args: [],
      is_trait_object: false,
      span: first.span,
    }
    ignore(self.expect(TokenKind::ColonColon))
    if self.current().kind == TokenKind::LBrace {
      self.parse_typed_struct_literal(target_type, first.span)
    } else {
      let name = self.expect_name_token()
      @ast.Expr::StaticAccess(
        target_type,
        name.text,
        merge_span(first.span, name.span),
      )
    }
  }
}

///|
fn Parser::parse_call_arg(self : Parser) -> @ast.CallArg {
  if self.current().kind == TokenKind::Identifier &&
    self.peek().kind == TokenKind::Eq {
    let label = self.bump()
    ignore(self.bump())
    let value = self.parse_expr()
    {
      label: Some(label.text),
      value,
      span: merge_span(label.span, @ast.expr_span(value)),
    }
  } else if self.current().kind == TokenKind::Identifier &&
    self.peek().kind == TokenKind::Tilde {
    let label = self.bump()
    let tilde = self.bump()
    {
      label: Some(label.text),
      value: @ast.Expr::Name(label.text, label.span),
      span: merge_span(label.span, tilde.span),
    }
  } else {
    let value = self.parse_expr()
    { label: None, value, span: @ast.expr_span(value) }
  }
}

///|
fn binary_precedence(kind : TokenKind) -> Int {
  match kind {
    TokenKind::PipePipe => 1
    TokenKind::LessPlus => 1
    TokenKind::AmpAmp => 2
    TokenKind::Pipe => 3
    TokenKind::Caret => 4
    TokenKind::Amp => 5
    TokenKind::EqEq | TokenKind::BangEq => 6
    TokenKind::Less
    | TokenKind::Greater
    | TokenKind::LessEq
    | TokenKind::GreaterEq => 7
    TokenKind::Shl | TokenKind::Shr => 8
    TokenKind::Plus | TokenKind::Minus => 9
    TokenKind::Star | TokenKind::Slash | TokenKind::Percent => 10
    _ => 0
  }
}

///|
fn Parser::parse_string_literal_expr(self : Parser) -> @ast.Expr {
  let first = self.bump()
  if first.text.has_prefix("$|") {
    return parsed_string_literal(first.text[2:].to_owned(), first.span)
  }
  if !first.text.has_prefix("#|") {
    return parsed_string_literal(unquote(first.text), first.span)
  }
  let body = StringBuilder::new()
  write_raw_body_line_content(body, first.text)
  let mut span = first.span
  while self.raw_string_line_follows_after_separators() {
    self.skip_separators()
    let next = self.bump()
    body.write_string("\n")
    write_raw_body_line_content(body, next.text)
    span = merge_span(span, next.span)
  }
  @ast.Expr::StringLiteral(body.to_string(), span)
}

///|
fn unquote(text : String) -> String {
  if text.length() >= 3 && text[0] == 'b' && text[1] == '"' {
    text[2:text.length() - 1].to_owned()
  } else if text.length() >= 3 && text[0] == 'b' && text[1] == '\'' {
    text[2:text.length() - 1].to_owned()
  } else if text.length() >= 2 {
    text[1:text.length() - 1].to_owned()
  } else {
    text
  }
}

///|
fn parsed_string_literal(
  value : String,
  span : @common.SourceSpan,
) -> @ast.Expr {
  let parts = string_literal_parts(value, span)
  if parts.length() == 1 {
    match parts[0] {
      @ast.StringPart::Text(text) => @ast.Expr::StringLiteral(text, span)
      @ast.StringPart::Expr(expr) => expr
      @ast.StringPart::WriteTo(_, expr) => expr
    }
  } else {
    @ast.Expr::InterpolatedString(parts, span)
  }
}

///|
fn string_literal_parts(
  value : String,
  span : @common.SourceSpan,
) -> Array[@ast.StringPart] {
  let parts : Array[@ast.StringPart] = []
  let text = StringBuilder::new()
  let mut i = 0
  let mut text_start = 0
  while i < value.length() {
    if value[i] == '\\' && i + 1 < value.length() {
      if text_start < i {
        text.write_stringview(value[text_start:i])
      }
      let next = value[i + 1]
      if next == '{' {
        flush_string_part(parts, text)
        let end_index = find_interpolation_end(value, i + 2)
        if end_index < value.length() {
          push_interpolation_part(
            parts,
            value[i + 2:end_index].to_owned(),
            span,
          )
          i = end_index + 1
          text_start = i
        } else {
          text.write_char('\\')
          text.write_char('{')
          i = i + 2
          text_start = i
        }
      } else {
        write_escape(text, next)
        i = i + 2
        text_start = i
      }
    } else {
      i = i + 1
    }
  }
  if text_start < value.length() {
    text.write_stringview(value[text_start:value.length()])
  }
  flush_string_part(parts, text)
  if parts.length() == 0 {
    parts.push(@ast.StringPart::Text(""))
  }
  parts
}

///|
fn find_interpolation_end(value : String, start : Int) -> Int {
  let mut i = start
  while i < value.length() {
    if value[i] == '}' {
      return i
    }
    i = i + 1
  }
  value.length()
}

///|
fn push_interpolation_part(
  parts : Array[@ast.StringPart],
  body : String,
  span : @common.SourceSpan,
) -> Unit {
  match interpolation_write_to(body, span) {
    Some(part) => parts.push(part)
    None => {
      let expr = parse_interpolation_expr(body, span)
      parts.push(@ast.StringPart::Expr(expr))
    }
  }
}

///|
fn interpolation_write_to(
  body : String,
  span : @common.SourceSpan,
) -> @ast.StringPart? {
  let marker = "=>"
  match string_index_of(body, marker) {
    Some(index) => {
      let name = body[0:index].trim().to_owned()
      let expr_text = body[index + marker.length():].trim().to_owned()
      if name.length() == 0 || expr_text.length() == 0 {
        None
      } else {
        Some(
          @ast.StringPart::WriteTo(
            name,
            parse_interpolation_expr(expr_text, span),
          ),
        )
      }
    }
    None => None
  }
}

///|
fn string_index_of(text : String, pattern : String) -> Int? {
  if pattern.length() == 0 {
    return Some(0)
  }
  let mut i = 0
  while i + pattern.length() <= text.length() {
    if text[i:i + pattern.length()] == pattern {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
fn parse_interpolation_expr(
  body : String,
  span : @common.SourceSpan,
) -> @ast.Expr {
  let source = "fn __interpolation__() -> Unit { " + body + " }\n"
  let parsed = parse_source(@text.source_file(span.file, source))
  if parsed.module_.functions.length() > 0 {
    parsed.module_.functions[0].body
  } else {
    @ast.Expr::Name(body.trim().to_owned(), span)
  }
}

///|
fn flush_string_part(
  parts : Array[@ast.StringPart],
  text : StringBuilder,
) -> Unit {
  let value = text.to_string()
  if value.length() > 0 {
    parts.push(@ast.StringPart::Text(value))
    text.reset()
  }
}

///|
fn write_escape(text : StringBuilder, escaped : UInt16) -> Unit {
  match escaped {
    'n' => text.write_char('\n')
    'r' => text.write_char('\r')
    't' => text.write_char('\t')
    '\\' => text.write_char('\\')
    '"' => text.write_char('"')
    '\'' => text.write_char('\'')
    _ => text.write_char(escaped.unsafe_to_char())
  }
}

///|
fn Parser::parse_brace_literal(self : Parser) -> @ast.Expr {
  if self.brace_literal_is_struct_update() {
    self.parse_struct_update_literal()
  } else if self.brace_literal_is_struct() {
    self.parse_struct_literal()
  } else if self.brace_literal_is_map() {
    self.parse_map_literal()
  } else if self.brace_literal_is_empty() {
    self.parse_empty_brace_literal()
  } else {
    self.parse_braced_block_expr()
  }
}

///|
fn Parser::parse_empty_brace_literal(self : Parser) -> @ast.Expr {
  let open = self.expect(TokenKind::LBrace)
  self.skip_separators()
  let close = self.expect(TokenKind::RBrace)
  @ast.Expr::EmptyBraceLiteral(merge_span(open.span, close.span))
}

///|
fn Parser::parse_braced_block_expr(self : Parser) -> @ast.Expr {
  ignore(self.expect(TokenKind::LBrace))
  let body = self.parse_block_expr()
  ignore(self.expect(TokenKind::RBrace))
  body
}

///|
fn Parser::brace_literal_is_struct_update(self : Parser) -> Bool {
  if self.current().kind != TokenKind::LBrace {
    false
  } else {
    match self.peek_non_separator_tokens(1) {
      (first, _) => first.kind == TokenKind::DotDot
    }
  }
}

///|
fn Parser::brace_literal_is_struct(self : Parser) -> Bool {
  if self.current().kind != TokenKind::LBrace {
    false
  } else {
    match self.peek_non_separator_tokens(1) {
      (first, second) =>
        first.kind == TokenKind::Identifier &&
        second.kind is (TokenKind::Colon | TokenKind::Comma | TokenKind::RBrace)
    }
  }
}

///|
fn Parser::brace_literal_is_map(self : Parser) -> Bool {
  if self.current().kind != TokenKind::LBrace {
    false
  } else {
    match self.peek_non_separator_tokens(1) {
      (first, second) =>
        match first.kind {
          TokenKind::StringLiteral
          | TokenKind::IntLiteral
          | TokenKind::True
          | TokenKind::False => second.kind == TokenKind::Colon
          _ => false
        }
    }
  }
}

///|
fn Parser::brace_literal_is_empty(self : Parser) -> Bool {
  if self.current().kind != TokenKind::LBrace {
    false
  } else {
    match self.peek_non_separator_tokens(1) {
      (first, _) => first.kind == TokenKind::RBrace
    }
  }
}

///|
fn Parser::peek_non_separator_tokens(
  self : Parser,
  offset : Int,
) -> (Token, Token) {
  let mut cursor = offset
  while self.peek_token(cursor).kind
        is (TokenKind::Newline | TokenKind::Semicolon) {
    cursor = cursor + 1
  }
  let first = self.peek_token(cursor)
  cursor = cursor + 1
  while self.peek_token(cursor).kind
        is (TokenKind::Newline | TokenKind::Semicolon) {
    cursor = cursor + 1
  }
  (first, self.peek_token(cursor))
}

///|
fn Parser::parse_struct_literal(self : Parser) -> @ast.Expr {
  let (fields, span) = self.parse_struct_literal_fields()
  @ast.Expr::StructLiteral(fields, span)
}

///|
fn Parser::parse_typed_struct_literal(
  self : Parser,
  type_syntax : @ast.TypeSyntax,
  start : @common.SourceSpan,
) -> @ast.Expr {
  let (fields, span) = self.parse_struct_literal_fields()
  @ast.Expr::TypedStructLiteral(type_syntax, fields, merge_span(start, span))
}

///|
fn Parser::parse_struct_update_literal(self : Parser) -> @ast.Expr {
  let open = self.expect(TokenKind::LBrace)
  self.skip_separators()
  ignore(self.expect(TokenKind::DotDot))
  let base = self.parse_expr()
  if self.current().kind == TokenKind::Comma {
    ignore(self.bump())
  }
  self.skip_separators()
  let fields : Array[@ast.StructFieldValue] = []
  while !self.at_struct_body_end() {
    let name = self.expect(TokenKind::Identifier)
    ignore(self.expect(TokenKind::Colon))
    let value = self.parse_expr()
    fields.push({ name: name.text, value, span: name.span })
    if self.current().kind == TokenKind::Comma {
      ignore(self.bump())
      self.skip_separators()
    } else {
      break
    }
  }
  let close = self.expect(TokenKind::RBrace)
  @ast.Expr::StructUpdateLiteral(
    base,
    fields,
    merge_span(open.span, close.span),
  )
}

///|
fn Parser::parse_struct_literal_fields(
  self : Parser,
) -> (Array[@ast.StructFieldValue], @common.SourceSpan) {
  let open = self.expect(TokenKind::LBrace)
  let fields : Array[@ast.StructFieldValue] = []
  self.skip_separators()
  while !self.at_struct_body_end() {
    let name = self.expect(TokenKind::Identifier)
    let value = if self.current().kind == TokenKind::Colon {
      ignore(self.bump())
      self.parse_expr()
    } else {
      @ast.Expr::Name(name.text, name.span)
    }
    fields.push({ name: name.text, value, span: name.span })
    if self.current().kind == TokenKind::Comma {
      ignore(self.bump())
      self.skip_separators()
    } else {
      break
    }
  }
  let close = self.expect(TokenKind::RBrace)
  (fields, merge_span(open.span, close.span))
}

///|
fn expr_as_type_syntax(expr : @ast.Expr) -> @ast.TypeSyntax? {
  match expr {
    @ast.Expr::Name(name, span) =>
      Some({ package_alias: None, name, args: [], is_trait_object: false, span })
    @ast.Expr::PackageAccess(package_alias, name, span) =>
      Some({
        package_alias: Some(package_alias),
        name,
        args: [],
        is_trait_object: false,
        span,
      })
    _ => None
  }
}

///|
fn Parser::parse_map_literal(self : Parser) -> @ast.Expr {
  let open = self.expect(TokenKind::LBrace)
  let entries : Array[@ast.MapEntry] = []
  self.skip_separators()
  while !self.at_struct_body_end() {
    let key = self.parse_expr()
    ignore(self.expect(TokenKind::Colon))
    let value = self.parse_expr()
    entries.push({
      key,
      value,
      span: merge_span(@ast.expr_span(key), @ast.expr_span(value)),
    })
    if self.current().kind == TokenKind::Comma {
      ignore(self.bump())
      self.skip_separators()
    } else {
      break
    }
  }
  let close = self.expect(TokenKind::RBrace)
  @ast.Expr::MapLiteral(entries, merge_span(open.span, close.span))
}

///|
fn Parser::parse_array_literal(self : Parser) -> @ast.Expr {
  let open = self.expect(TokenKind::LBracket)
  self.skip_separators()
  if self.current().kind == TokenKind::For {
    return self.parse_array_comprehension_as_placeholder(open)
  }
  let items : Array[@ast.ArrayElement] = []
  self.skip_separators()
  if self.current().kind != TokenKind::RBracket {
    while !self.at_bracketed_list_end() {
      items.push(self.parse_array_literal_element())
      if self.current().kind == TokenKind::Comma {
        ignore(self.bump())
        self.skip_separators()
      } else {
        break
      }
    }
  }
  let close = self.expect(TokenKind::RBracket)
  @ast.Expr::ArrayLiteral(items, merge_span(open.span, close.span))
}

///|
fn Parser::parse_array_comprehension_as_placeholder(
  self : Parser,
  open : Token,
) -> @ast.Expr {
  while !(self.current().kind is (TokenKind::RBracket | TokenKind::Eof)) {
    if self.current().kind == TokenKind::LBracket {
      self.skip_balanced_brackets()
    } else if self.current().kind == TokenKind::LParen {
      self.skip_balanced_parens()
    } else if self.current().kind == TokenKind::LBrace {
      self.skip_balanced_braces()
    } else {
      ignore(self.bump())
    }
  }
  let close = self.expect(TokenKind::RBracket)
  @ast.Expr::ArrayLiteral([], merge_span(open.span, close.span))
}

///|
fn Parser::parse_array_literal_element(self : Parser) -> @ast.ArrayElement {
  if self.current().kind == TokenKind::DotDot {
    let spread = self.bump()
    let value = self.parse_expr()
    @ast.ArrayElement::Spread(
      value,
      merge_span(spread.span, @ast.expr_span(value)),
    )
  } else {
    @ast.ArrayElement::Value(self.parse_expr())
  }
}
