///|
test "vnext lexer keeps keyword literal punctuation and bad token behavior" {
  let file = @text.source_file(
    "lexer.mbt", "fn add(a:Int)->Float {\n  @pkg.value? ~ \"x\" 1.0 $ \n}\n",
  )
  let result = lex(file)
  let kinds : Array[TokenKind] = []
  for token in result.tokens {
    kinds.push(token.kind)
  }
  assert_eq(kinds.length(), 23)
  assert_true(kinds[0] == TokenKind::Fn)
  assert_true(kinds[7] == TokenKind::Arrow)
  assert_true(kinds[10] == TokenKind::Newline)
  assert_true(kinds[11] == TokenKind::PackageName)
  assert_true(result.tokens[11].text == "pkg")
  assert_true(kinds[12] == TokenKind::Dot)
  assert_true(kinds[14] == TokenKind::Question)
  assert_true(kinds[15] == TokenKind::Tilde)
  assert_true(kinds[16] == TokenKind::StringLiteral)
  assert_true(kinds[17] == TokenKind::FloatLiteral)
  assert_true(kinds[18] == TokenKind::Bad)
  assert_true(kinds[22] == TokenKind::Eof)
  assert_eq(result.diagnostics.length(), 1)
  assert_eq(result.diagnostics[0].code, "VNX0001")
}

///|
test "vnext lexer uses longest match for range operator and static tokens" {
  let file = @text.source_file(
    "operators.mbt", ".. ..< ..<= ..= ... >.. >=.. :: << >> <= >= == != && || |> <| <+ => -> - * / % < > | ^ _",
  )
  let result = lex(file)
  let kinds : Array[TokenKind] = []
  for token in result.tokens {
    kinds.push(token.kind)
  }
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(kinds.length(), 31)
  assert_true(kinds[0] == TokenKind::DotDot)
  assert_true(kinds[1] == TokenKind::RangeExclusive)
  assert_true(kinds[2] == TokenKind::RangeLtInclusive)
  assert_true(kinds[3] == TokenKind::RangeInclusive)
  assert_true(kinds[4] == TokenKind::Ellipsis)
  assert_true(kinds[5] == TokenKind::RangeExclusiveRev)
  assert_true(kinds[6] == TokenKind::RangeInclusiveRev)
  assert_true(kinds[7] == TokenKind::ColonColon)
  assert_true(kinds[8] == TokenKind::Shl)
  assert_true(kinds[9] == TokenKind::Shr)
  assert_true(kinds[10] == TokenKind::LessEq)
  assert_true(kinds[11] == TokenKind::GreaterEq)
  assert_true(kinds[12] == TokenKind::EqEq)
  assert_true(kinds[13] == TokenKind::BangEq)
  assert_true(kinds[14] == TokenKind::AmpAmp)
  assert_true(kinds[15] == TokenKind::PipePipe)
  assert_true(kinds[16] == TokenKind::PipeForward)
  assert_true(kinds[17] == TokenKind::PipeBackward)
  assert_true(kinds[18] == TokenKind::LessPlus)
  assert_true(kinds[19] == TokenKind::FatArrow)
  assert_true(kinds[20] == TokenKind::Arrow)
  assert_true(kinds[21] == TokenKind::Minus)
  assert_true(kinds[22] == TokenKind::Star)
  assert_true(kinds[23] == TokenKind::Slash)
  assert_true(kinds[24] == TokenKind::Percent)
  assert_true(kinds[25] == TokenKind::Less)
  assert_true(kinds[26] == TokenKind::Greater)
  assert_true(kinds[27] == TokenKind::Pipe)
  assert_true(kinds[28] == TokenKind::Caret)
  assert_true(kinds[29] == TokenKind::Underscore)
  assert_true(kinds[30] == TokenKind::Eof)
}

///|
test "vnext lexer accepts scientific float exponents" {
  let result = lex(
    @text.source_file("numbers.mbt", "1.35003920212974897128e-08"),
  )
  assert_eq(result.diagnostics.length(), 0)
  assert_true(result.tokens[0].kind == TokenKind::FloatLiteral)
  assert_eq(result.tokens[0].text, "1.35003920212974897128e-08")
}

///|
test "vnext lexer accepts hex float exponents" {
  let result = lex(@text.source_file("numbers.mbt", "0x1.0p-1022"))
  assert_eq(result.diagnostics.length(), 0)
  assert_true(result.tokens[0].kind == TokenKind::FloatLiteral)
  assert_eq(result.tokens[0].text, "0x1.0p-1022")
}

///|
test "vnext lexer keeps radix and separator integer literals whole" {
  let file = @text.source_file("numbers.mbt", "0xFF 0o377 0b1010 10_000 1.25")
  let result = lex(file)
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.tokens.length(), 6)
  assert_true(result.tokens[0].kind == TokenKind::IntLiteral)
  assert_eq(result.tokens[0].text, "0xFF")
  assert_eq(result.tokens[1].text, "0o377")
  assert_eq(result.tokens[2].text, "0b1010")
  assert_eq(result.tokens[3].text, "10_000")
  assert_true(result.tokens[4].kind == TokenKind::FloatLiteral)
  assert_eq(result.tokens[4].text, "1.25")
}

///|
test "vnext lexer treats hash identifier lines as generic attributes" {
  let source = "#coverage.skip\n#unknown(value)\n#|raw string\n# comment\n"
  let result = lex(@text.source_file("attributes.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
  assert_true(result.tokens[0].kind == TokenKind::Attribute)
  assert_eq(result.tokens[0].text, "#coverage.skip")
  assert_true(result.tokens[2].kind == TokenKind::Attribute)
  assert_eq(result.tokens[2].text, "#unknown(value)")
  assert_true(result.tokens[4].kind == TokenKind::StringLiteral)
  assert_true(result.tokens[result.tokens.length() - 1].kind == TokenKind::Eof)
}
