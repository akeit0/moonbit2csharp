///|
pub(all) struct ParseResult {
  module_ : @ast.Module
  diagnostics : Array[@common.Diagnostic]
} derive(Eq, Debug)

///|
pub fn parse_source(file : @text.SourceFile) -> ParseResult {
  parse_source_with_mode(file, false)
}

///|
pub fn parse_declaration_source(file : @text.SourceFile) -> ParseResult {
  parse_interface_source(file)
}

///|
pub fn parse_source_with_mode(
  file : @text.SourceFile,
  declarations_only : Bool,
) -> ParseResult {
  let lexed = lex(file)
  let parser : Parser = {
    tokens: lexed.tokens,
    pos: 0,
    pending_aliases: [],
    pending_intrinsic: None,
    pending_decl_enabled: true,
    is_interface: file.path.has_suffix(".mbti"),
    declarations_only,
    diagnostics: lexed.diagnostics,
  }
  parser.parse_module()
}

///|
priv struct Parser {
  tokens : Array[Token]
  mut pos : Int
  mut pending_aliases : Array[String]
  mut pending_intrinsic : String?
  mut pending_decl_enabled : Bool
  is_interface : Bool
  declarations_only : Bool
  diagnostics : Array[@common.Diagnostic]
}

///|
fn Parser::parse_module(self : Parser) -> ParseResult {
  let usings : Array[@ast.UsingDecl] = []
  let functions : Array[@ast.Function] = []
  let structs : Array[@ast.StructDecl] = []
  let opaque_types : Array[@ast.OpaqueTypeDecl] = []
  let enums : Array[@ast.EnumDecl] = []
  let traits : Array[@ast.TraitDecl] = []
  let impls : Array[@ast.ImplDecl] = []
  let globals : Array[@ast.GlobalLet] = []
  while self.current().kind != TokenKind::Eof {
    self.skip_separators()
    if self.current().kind == TokenKind::Eof {
      break
    }
    match self.current().kind {
      TokenKind::Attribute => self.record_attribute()
      TokenKind::Using =>
        if self.take_pending_decl_enabled() {
          usings.push(self.parse_using())
        } else {
          ignore(self.parse_using())
        }
      TokenKind::Import => self.skip_import_decl()
      _ => {
        let is_public = self.skip_decl_modifiers()
        let enabled = self.take_pending_decl_enabled()
        match self.current().kind {
          TokenKind::Using =>
            if enabled {
              usings.push(self.parse_using())
            } else {
              ignore(self.parse_using())
            }
          TokenKind::Extern | TokenKind::Fn =>
            if enabled {
              functions.push(self.parse_function(is_public))
            } else {
              ignore(self.parse_function(is_public))
            }
          TokenKind::Struct =>
            if enabled {
              structs.push(self.parse_struct())
            } else {
              ignore(self.parse_struct())
            }
          TokenKind::Enum | TokenKind::Suberror =>
            if enabled {
              enums.push(self.parse_enum())
            } else {
              ignore(self.parse_enum())
            }
          TokenKind::Trait =>
            if enabled {
              traits.push(self.parse_trait())
            } else {
              ignore(self.parse_trait())
            }
          TokenKind::Impl =>
            if !enabled {
              if self.impl_decl_is_default_method() {
                self.skip_interface_impl_decl()
              } else {
                ignore(self.parse_impl())
              }
            } else if self.declarations_only &&
              self.impl_decl_is_default_method() {
              self.skip_interface_impl_decl()
            } else {
              impls.push(self.parse_impl())
            }
          TokenKind::Package => self.skip_package_decl()
          TokenKind::Type =>
            if enabled {
              opaque_types.push(self.parse_opaque_type_decl())
            } else {
              ignore(self.parse_opaque_type_decl())
            }
          TokenKind::Test => self.skip_test_block()
          TokenKind::Let | TokenKind::Const =>
            if enabled {
              globals.push(self.parse_global_let())
            } else {
              ignore(self.parse_global_let())
            }
          _ =>
            if enabled {
              functions.push(self.parse_function(is_public))
            } else {
              ignore(self.parse_function(is_public))
            }
        }
      }
    }
  }
  let module_ : @ast.Module = {
    usings,
    functions,
    structs,
    opaque_types,
    enums,
    traits,
    impls,
    globals,
  }
  { module_, diagnostics: self.diagnostics }
}

///|
fn Parser::record_attribute(self : Parser) -> Unit {
  let token = self.bump()
  match alias_attribute_value(token.text) {
    Some(alias_text) => self.pending_aliases.push(alias_text)
    None => ()
  }
  match intrinsic_attribute_value(token.text) {
    Some(intrinsic) => self.pending_intrinsic = Some(intrinsic)
    None => ()
  }
  match cfg_attribute_enabled(token.text) {
    Some(enabled) =>
      self.pending_decl_enabled = self.pending_decl_enabled && enabled
    None => ()
  }
}

///|
fn alias_attribute_value(text : String) -> String? {
  quoted_attribute_value(text, "#alias(")
}

///|
fn quoted_attribute_value(text : String, prefix : String) -> String? {
  let suffix = ")"
  if text.length() >= prefix.length() + suffix.length() &&
    text[0:prefix.length()] == prefix &&
    text[text.length() - suffix.length():] == suffix {
    let body = text[prefix.length():text.length() - suffix.length()]
    let mut first = body.trim()
    for item in body.split(",") {
      first = item.trim()
      break
    }
    if first.has_prefix("\"") && first.has_suffix("\"") && first.length() >= 2 {
      Some(first[1:first.length() - 1].to_owned())
    } else if first.length() > 0 {
      Some(first.to_owned())
    } else {
      None
    }
  } else {
    None
  }
}

///|
fn intrinsic_attribute_value(text : String) -> String? {
  quoted_attribute_value(text, "#intrinsic(")
}

///|
fn cfg_attribute_enabled(text : String) -> Bool? {
  let prefix = "#cfg("
  let suffix = ")"
  if text.length() < prefix.length() + suffix.length() ||
    text[0:prefix.length()] != prefix ||
    text[text.length() - suffix.length():] != suffix {
    return None
  }
  let body = text[prefix.length():text.length() - suffix.length()].trim()
  if body == "target=\"js\"" {
    Some(false)
  } else if body == "not(target=\"js\")" {
    Some(true)
  } else {
    Some(true)
  }
}

///|
fn Parser::take_pending_decl_enabled(self : Parser) -> Bool {
  let enabled = self.pending_decl_enabled
  self.pending_decl_enabled = true
  enabled
}

///|
fn Parser::parse_using(self : Parser) -> @ast.UsingDecl {
  let start = self.expect(TokenKind::Using)
  let alias_name = self.expect_package_name()
  ignore(self.expect(TokenKind::LBrace))
  let items : Array[@ast.UsingItem] = []
  while !(self.current().kind is (TokenKind::RBrace | TokenKind::Eof)) {
    self.skip_separators()
    if self.current().kind is (TokenKind::RBrace | TokenKind::Eof) {
      break
    }
    let mut kind = @ast.UsingItemKind::Value
    match self.current().kind {
      TokenKind::Type | TokenKind::Trait => {
        ignore(self.bump())
        kind = @ast.UsingItemKind::Type
      }
      _ => ()
    }
    let name = self.expect(TokenKind::Identifier)
    items.push({ kind, name: name.text, span: name.span })
    if self.current().kind == TokenKind::Comma {
      ignore(self.bump())
    } else {
      break
    }
  }
  ignore(self.expect(TokenKind::RBrace))
  { package_alias: alias_name.text, items, span: start.span }
}

///|
fn Parser::skip_visibility(self : Parser) -> Bool {
  match self.current().kind {
    TokenKind::Pub => {
      ignore(self.bump())
      if self.current().kind == TokenKind::LParen {
        ignore(self.bump())
        if self.current().kind == TokenKind::All ||
          self.current().kind == TokenKind::Identifier {
          ignore(self.bump())
        }
        ignore(self.expect(TokenKind::RParen))
      }
      true
    }
    TokenKind::Priv => {
      ignore(self.bump())
      false
    }
    _ => false
  }
}

///|
fn Parser::parse_struct(self : Parser) -> @ast.StructDecl {
  let start = self.expect(TokenKind::Struct)
  let name = self.expect(TokenKind::Identifier)
  let type_params = self.parse_nominal_type_params()
  if self.current().kind == TokenKind::LParen {
    let fields = self.parse_tuple_struct_fields()
    let derives = self.parse_derive_clause()
    return { name: name.text, type_params, fields, derives, span: start.span }
  }
  ignore(self.expect(TokenKind::LBrace))
  let fields : Array[@ast.StructField] = []
  while !self.at_struct_body_end() {
    self.skip_separators()
    if self.at_struct_body_end() {
      break
    }
    let mutable = if self.current().kind == TokenKind::Mut {
      ignore(self.bump())
      true
    } else {
      false
    }
    let field_name = self.expect(TokenKind::Identifier)
    ignore(self.expect(TokenKind::Colon))
    let field_type = self.parse_type()
    fields.push({
      name: field_name.text,
      mutable,
      type_: field_type,
      span: field_name.span,
    })
  }
  ignore(self.expect(TokenKind::RBrace))
  let derives = self.parse_derive_clause()
  { name: name.text, type_params, fields, derives, span: start.span }
}

///|
fn Parser::parse_tuple_struct_fields(self : Parser) -> Array[@ast.StructField] {
  ignore(self.expect(TokenKind::LParen))
  let fields : Array[@ast.StructField] = []
  let mut index = 0
  while !(self.current().kind is (TokenKind::RParen | TokenKind::Eof)) {
    let type_ = self.parse_type()
    fields.push({
      name: index.to_string(),
      mutable: false,
      type_,
      span: type_.span,
    })
    index = index + 1
    if self.current().kind == TokenKind::Comma {
      ignore(self.bump())
    } else {
      break
    }
  }
  ignore(self.expect(TokenKind::RParen))
  fields
}

///|
fn Parser::parse_opaque_type_decl(self : Parser) -> @ast.OpaqueTypeDecl {
  let start = self.expect(TokenKind::Type)
  let name = self.expect(TokenKind::Identifier)
  let type_params = self.parse_nominal_type_params()
  while !(self.current().kind
        is (TokenKind::Newline | TokenKind::Semicolon | TokenKind::Eof)) {
    ignore(self.bump())
  }
  { name: name.text, type_params, span: start.span }
}

///|
fn Parser::skip_test_block(self : Parser) -> Unit {
  ignore(self.expect(TokenKind::Test))
  if self.current().kind == TokenKind::StringLiteral {
    ignore(self.bump())
  }
  self.skip_separators()
  if self.current().kind == TokenKind::LBrace {
    self.skip_balanced_braces()
  } else {
    self.expect_statement_separator()
  }
}

///|
fn Parser::skip_package_decl(self : Parser) -> Unit {
  ignore(self.expect(TokenKind::Package))
  while !(self.current().kind
        is (TokenKind::Newline | TokenKind::Semicolon | TokenKind::Eof)) {
    ignore(self.bump())
  }
}

///|
fn Parser::skip_import_decl(self : Parser) -> Unit {
  ignore(self.expect(TokenKind::Import))
  self.skip_separators()
  if self.current().kind == TokenKind::LBrace {
    self.skip_balanced_braces()
  } else {
    self.expect_statement_separator()
  }
}

///|
fn Parser::skip_interface_impl_decl(self : Parser) -> Unit {
  ignore(self.expect(TokenKind::Impl))
  while !(self.current().kind
        is (TokenKind::Newline | TokenKind::Semicolon | TokenKind::Eof)) {
    if self.current().kind == TokenKind::LBrace {
      self.skip_balanced_braces()
      return
    } else {
      ignore(self.bump())
    }
  }
}

///|
fn Parser::parse_enum(self : Parser) -> @ast.EnumDecl {
  let start = if self.current().kind == TokenKind::Suberror {
    self.bump()
  } else {
    self.expect(TokenKind::Enum)
  }
  let name = self.expect(TokenKind::Identifier)
  let type_params = self.parse_nominal_type_params()
  ignore(self.expect(TokenKind::LBrace))
  let variants : Array[@ast.EnumVariant] = []
  while !self.at_struct_body_end() {
    self.skip_separators()
    if self.at_struct_body_end() {
      break
    }
    let variant = self.expect(TokenKind::Identifier)
    let payloads : Array[@ast.EnumPayload] = []
    if self.current().kind == TokenKind::LParen {
      ignore(self.bump())
      self.skip_separators()
      while !(self.current().kind is (TokenKind::RParen | TokenKind::Eof)) {
        let label = self.parse_payload_label()
        let type_ = self.parse_type()
        payloads.push({ label, type_, span: type_.span })
        self.skip_separators()
        if self.current().kind == TokenKind::Comma {
          ignore(self.bump())
          self.skip_separators()
        } else {
          break
        }
      }
      ignore(self.expect(TokenKind::RParen))
    }
    variants.push({ name: variant.text, payloads, span: variant.span })
    if !self.at_struct_body_end() {
      self.expect_statement_separator()
    }
  }
  ignore(self.expect(TokenKind::RBrace))
  let derives = self.parse_derive_clause()
  { name: name.text, type_params, variants, derives, span: start.span }
}

///|
fn Parser::skip_decl_modifiers(self : Parser) -> Bool {
  let mut is_public = false
  let mut changed = true
  while changed {
    changed = false
    if self.current().kind == TokenKind::Attribute {
      self.record_attribute()
      changed = true
    }
    if self.current().kind
      is (TokenKind::Pub | TokenKind::Priv | TokenKind::Readonly) {
      if self.skip_visibility() {
        is_public = true
      }
      changed = true
    }
  }
  is_public || self.is_interface
}

///|
fn Parser::parse_payload_label(self : Parser) -> String? {
  if self.current().kind == TokenKind::Identifier &&
    self.peek_kind(1) is (TokenKind::Tilde | TokenKind::Colon) {
    let label = self.bump()
    if self.current().kind == TokenKind::Tilde {
      ignore(self.bump())
    }
    ignore(self.expect(TokenKind::Colon))
    Some(label.text)
  } else {
    None
  }
}

///|
fn Parser::parse_derive_clause(self : Parser) -> Array[String] {
  let derives : Array[String] = []
  if self.current().kind == TokenKind::Derive {
    ignore(self.bump())
    if self.current().kind == TokenKind::LParen {
      ignore(self.bump())
      self.skip_separators()
      while !(self.current().kind is (TokenKind::RParen | TokenKind::Eof)) {
        match self.current().kind {
          TokenKind::Identifier => derives.push(self.bump().text)
          _ => ignore(self.bump())
        }
        self.skip_separators()
        if self.current().kind == TokenKind::Comma {
          ignore(self.bump())
          self.skip_separators()
        } else {
          break
        }
      }
      ignore(self.expect(TokenKind::RParen))
    }
  }
  derives
}

///|
fn Parser::parse_impl(self : Parser) -> @ast.ImplDecl {
  let start = self.expect(TokenKind::Impl)
  let type_params = self.parse_type_params()
  let trait_name = self.parse_impl_trait_name()
  let self_type = if self.current().kind == TokenKind::For {
    ignore(self.bump())
    self.parse_type()
  } else {
    {
      package_alias: None,
      name: "Self",
      args: [],
      is_trait_object: false,
      span: start.span,
    }
  }
  if self.current().kind != TokenKind::With {
    return {
      type_params,
      trait_name,
      self_type,
      methods: [],
      is_interface: self.is_interface,
      span: start.span,
    }
  }
  ignore(self.bump())
  let methods : Array[@ast.ImplMethodDecl] = []
  if self.current().kind is (TokenKind::Identifier | TokenKind::Fn) {
    methods.push(self.parse_impl_method())
  } else {
    ignore(self.expect(TokenKind::LBrace))
    while !self.at_struct_body_end() {
      self.skip_separators()
      if self.at_struct_body_end() {
        break
      }
      methods.push(self.parse_impl_method())
      if !self.at_struct_body_end() {
        self.expect_statement_separator()
      }
    }
    ignore(self.expect(TokenKind::RBrace))
  }
  {
    type_params,
    trait_name,
    self_type,
    methods,
    is_interface: self.is_interface,
    span: start.span,
  }
}

///|
fn Parser::parse_impl_trait_name(self : Parser) -> String {
  if self.current().kind is (TokenKind::PackageName | TokenKind::At) {
    let alias_name = self.expect_package_name().text
    ignore(self.expect(TokenKind::Dot))
    alias_name + "." + self.expect(TokenKind::Identifier).text
  } else {
    self.expect(TokenKind::Identifier).text
  }
}

///|
fn Parser::parse_trait(self : Parser) -> @ast.TraitDecl {
  let start = self.expect(TokenKind::Trait)
  let name = self.expect(TokenKind::Identifier)
  if self.current().kind == TokenKind::Colon {
    self.skip_trait_super_types()
  }
  ignore(self.expect(TokenKind::LBrace))
  let methods : Array[@ast.TraitMethodDecl] = []
  while !self.at_struct_body_end() {
    self.skip_separators()
    if self.at_struct_body_end() {
      break
    }
    methods.push(self.parse_trait_method())
    if !self.at_struct_body_end() {
      self.expect_statement_separator()
    }
  }
  ignore(self.expect(TokenKind::RBrace))
  { name: name.text, methods, span: start.span }
}

///|
fn Parser::parse_trait_method(self : Parser) -> @ast.TraitMethodDecl {
  if self.current().kind == TokenKind::Fn {
    ignore(self.bump())
  }
  let name = self.expect(TokenKind::Identifier)
  ignore(self.expect(TokenKind::LParen))
  let parameters : Array[@ast.TypeSyntax] = []
  while !(self.current().kind is (TokenKind::RParen | TokenKind::Eof)) {
    if self.current().kind == TokenKind::Identifier &&
      self.peek_kind(1) == TokenKind::Colon {
      ignore(self.bump())
      ignore(self.bump())
    }
    parameters.push(self.parse_type())
    if self.current().kind == TokenKind::Comma {
      ignore(self.bump())
      self.skip_separators()
    } else {
      break
    }
  }
  ignore(self.expect(TokenKind::RParen))
  ignore(self.expect(TokenKind::Arrow))
  let return_type = self.parse_type()
  let mut has_default = false
  if self.current().kind == TokenKind::Eq {
    has_default = true
    ignore(self.bump())
    if self.current().kind == TokenKind::Underscore {
      ignore(self.bump())
    } else if self.current().kind == TokenKind::LBrace {
      self.skip_balanced_braces()
    } else {
      ignore(self.bump())
    }
  }
  { name: name.text, parameters, return_type, has_default, span: name.span }
}

///|
fn Parser::skip_trait_super_types(self : Parser) -> Unit {
  ignore(self.expect(TokenKind::Colon))
  while !(self.current().kind is (TokenKind::LBrace | TokenKind::Eof)) {
    ignore(self.bump())
  }
}

///|
fn Parser::impl_decl_is_default_method(self : Parser) -> Bool {
  let mut index = self.pos + 1
  while index < self.tokens.length() {
    match self.tokens[index].kind {
      TokenKind::For => return false
      TokenKind::With => return true
      TokenKind::LBrace | TokenKind::RBrace | TokenKind::Eof => return false
      _ => index = index + 1
    }
  }
  false
}

///|
fn Parser::parse_impl_method(self : Parser) -> @ast.ImplMethodDecl {
  if self.current().kind == TokenKind::Fn {
    ignore(self.bump())
  }
  let name = self.expect(TokenKind::Identifier)
  let params = if self.current().kind == TokenKind::LParen {
    ignore(self.bump())
    let parsed = self.parse_impl_params()
    ignore(self.expect(TokenKind::RParen))
    parsed
  } else {
    []
  }
  let return_type = if self.current().kind == TokenKind::Arrow {
    ignore(self.bump())
    Some(self.parse_type())
  } else {
    None
  }
  self.skip_effect_suffix()
  if self.declarations_only {
    let mut intrinsic : String? = None
    if self.current().kind == TokenKind::Eq {
      ignore(self.bump())
      self.skip_separators()
      if self.current().kind == TokenKind::StringLiteral {
        intrinsic = Some(self.parse_string_binding())
      } else {
        self.skip_declaration_body_tail()
        return {
          name: name.text,
          params,
          return_type,
          body: Some(@ast.Expr::Missing(name.span)),
          intrinsic: None,
          span: name.span,
        }
      }
    } else if self.current().kind == TokenKind::LBrace {
      self.skip_balanced_braces()
      return {
        name: name.text,
        params,
        return_type,
        body: Some(@ast.Expr::Missing(name.span)),
        intrinsic: None,
          span: name.span,
        }
    }
    return {
      name: name.text,
      params,
      return_type,
      body: None,
      intrinsic,
      span: name.span,
    }
  }
  let mut body : @ast.Expr? = None
  let mut intrinsic : String? = None
  if self.current().kind == TokenKind::Eq {
    ignore(self.bump())
    self.skip_separators()
    match self.current().kind {
      TokenKind::StringLiteral => intrinsic = Some(self.parse_string_binding())
      _ => body = Some(self.parse_expr())
    }
  } else if self.current().kind == TokenKind::LBrace {
    ignore(self.bump())
    self.skip_separators()
    body = Some(self.parse_block_expr())
    self.skip_separators()
    ignore(self.expect(TokenKind::RBrace))
  }
  { name: name.text, params, return_type, body, intrinsic, span: name.span }
}

///|
fn Parser::parse_impl_params(self : Parser) -> Array[@ast.Param] {
  let params : Array[@ast.Param] = []
  self.skip_separators()
  if self.current().kind == TokenKind::RParen {
    return params
  }
  let mut ordinal = 0
  while !self.at_param_list_end() {
    let name = self.parse_param_name()
    let type_ = if self.current().kind == TokenKind::Colon {
      ignore(self.bump())
      self.parse_type()
    } else {
      inferred_type_syntax(name.span)
    }
    params.push({
      name: if name.text == "_" {
        "arg" + ordinal.to_string()
      } else {
        name.text
      },
      optional: false,
      labelled: false,
      type_,
      default_value: None,
      span: name.span,
    })
    ordinal = ordinal + 1
    if self.current().kind == TokenKind::Comma {
      ignore(self.bump())
      self.skip_separators()
    } else {
      break
    }
  }
  params
}

///|
fn Parser::parse_param_name(self : Parser) -> Token {
  match self.current().kind {
    TokenKind::Identifier | TokenKind::Underscore => self.bump()
    _ => self.expect(TokenKind::Identifier)
  }
}

///|
fn Parser::skip_balanced_parens(self : Parser) -> Unit {
  ignore(self.expect(TokenKind::LParen))
  let mut depth = 1
  while depth > 0 && self.current().kind != TokenKind::Eof {
    match self.current().kind {
      TokenKind::LParen => {
        ignore(self.bump())
        depth = depth + 1
      }
      TokenKind::RParen => {
        ignore(self.bump())
        depth = depth - 1
      }
      _ => ignore(self.bump())
    }
  }
}

///|
fn Parser::skip_balanced_braces(self : Parser) -> Unit {
  ignore(self.expect(TokenKind::LBrace))
  let mut depth = 1
  while depth > 0 && self.current().kind != TokenKind::Eof {
    match self.current().kind {
      TokenKind::LBrace => {
        ignore(self.bump())
        depth = depth + 1
      }
      TokenKind::RBrace => {
        ignore(self.bump())
        depth = depth - 1
      }
      _ => ignore(self.bump())
    }
  }
}

///|
fn Parser::skip_balanced_brackets(self : Parser) -> Unit {
  ignore(self.expect(TokenKind::LBracket))
  let mut depth = 1
  while depth > 0 && self.current().kind != TokenKind::Eof {
    match self.current().kind {
      TokenKind::LBracket => {
        ignore(self.bump())
        depth = depth + 1
      }
      TokenKind::RBracket => {
        ignore(self.bump())
        depth = depth - 1
      }
      _ => ignore(self.bump())
    }
  }
}

///|
fn Parser::parse_type_params(self : Parser) -> Array[@ast.TypeParamSyntax] {
  let names : Array[@ast.TypeParamSyntax] = []
  if self.current().kind == TokenKind::LBracket {
    ignore(self.bump())
    self.skip_separators()
    while !self.at_bracketed_list_end() {
      let name = self.expect_type_param_name()
      let constraints : Array[String] = []
      if self.current().kind == TokenKind::Colon {
        ignore(self.bump())
        constraints.push(self.parse_type_param_constraint_name())
        while self.current().kind == TokenKind::Plus {
          ignore(self.bump())
          constraints.push(self.parse_type_param_constraint_name())
        }
      }
      names.push({ name: name.text, constraints, span: name.span })
      if self.current().kind == TokenKind::Comma {
        ignore(self.bump())
        self.skip_separators()
      } else {
        break
      }
    }
    ignore(self.expect(TokenKind::RBracket))
  }
  names
}

///|
fn Parser::expect_type_param_name(self : Parser) -> Token {
  match self.current().kind {
    TokenKind::Identifier | TokenKind::Underscore => self.bump()
    _ => self.expect(TokenKind::Identifier)
  }
}

///|
fn Parser::parse_type_param_constraint_name(self : Parser) -> String {
  let package_alias = if self.current().kind
    is (TokenKind::PackageName | TokenKind::At) {
    let alias_name = self.expect_package_name().text
    ignore(self.expect(TokenKind::Dot))
    Some(alias_name)
  } else {
    None
  }
  let name = self.expect(TokenKind::Identifier).text
  match package_alias {
    Some(alias_name) => alias_name + "." + name
    None => name
  }
}

///|
fn Parser::parse_nominal_type_params(self : Parser) -> Array[String] {
  let result : Array[String] = []
  for param in self.parse_type_params() {
    result.push(param.name)
  }
  result
}

///|
fn Parser::parse_global_let(self : Parser) -> @ast.GlobalLet {
  let start = if self.current().kind == TokenKind::Const {
    self.bump()
  } else {
    self.expect(TokenKind::Let)
  }
  let name = self.expect(TokenKind::Identifier)
  let mut has_type_annotation = false
  let type_ = if self.current().kind == TokenKind::Colon {
    has_type_annotation = true
    ignore(self.bump())
    self.parse_type()
  } else {
    unit_type_syntax(name.span)
  }
  let value = if self.current().kind == TokenKind::Eq {
    ignore(self.bump())
    self.parse_expr()
  } else if self.is_interface {
    @ast.Expr::UnitLiteral(name.span)
  } else {
    ignore(self.expect(TokenKind::Eq))
    self.parse_expr()
  }
  { name: name.text, type_, has_type_annotation, value, span: start.span }
}

///|
fn Parser::parse_function(self : Parser, is_public : Bool) -> @ast.Function {
  let aliases = self.take_pending_aliases()
  let pending_intrinsic = self.take_pending_intrinsic()
  let extern_ = if self.current().kind == TokenKind::Extern {
    Some(self.parse_extern_header())
  } else {
    None
  }
  let fn_token = self.expect(TokenKind::Fn)
  let type_params = self.parse_type_params()
  let (receiver, name) = self.parse_function_name()
  let params = if self.current().kind == TokenKind::LParen {
    ignore(self.bump())
    let parsed = self.parse_params()
    ignore(self.expect(TokenKind::RParen))
    parsed
  } else {
    []
  }
  let mut raises : @ast.TypeSyntax? = None
  let return_type = if self.current().kind == TokenKind::Arrow {
    ignore(self.bump())
    let type_ = self.parse_type()
    raises = self.parse_effect_suffix()
    type_
  } else {
    unit_type_syntax(name.span)
  }
  let (body, intrinsic, external) = match extern_ {
    Some(extern_decl) => self.parse_extern_function_body(extern_decl, name.span)
    None =>
      if self.declarations_only {
        self.parse_declaration_function_body(name.span)
      } else {
        self.parse_regular_function_body(name.span)
      }
  }
  let resolved_intrinsic = match intrinsic {
    Some(_) => intrinsic
    None => pending_intrinsic
  }
  {
    name: name.text,
    receiver,
    type_params,
    params,
    return_type,
    raises,
    body,
    external,
    intrinsic: resolved_intrinsic,
    aliases,
    is_public: is_public || external is Some(_),
    span: fn_token.span,
  }
}

///|
fn Parser::parse_regular_function_body(
  self : Parser,
  span : @common.SourceSpan,
) -> (@ast.Expr, String?, @ast.ExternDecl?) {
  if self.current().kind == TokenKind::Eq {
    ignore(self.bump())
    self.skip_separators()
    match self.current().kind {
      TokenKind::StringLiteral =>
        (@ast.Expr::UnitLiteral(span), Some(self.parse_string_binding()), None)
      _ => (self.parse_expr(), None, None)
    }
  } else if self.is_interface &&
    self.current().kind
    is (TokenKind::Newline | TokenKind::Semicolon | TokenKind::Eof) {
    (
      @ast.Expr::UnitLiteral(span),
      None,
      Some({ target: "interface", body: None }),
    )
  } else {
    ignore(self.expect(TokenKind::LBrace))
    self.skip_separators()
    let parsed_body = self.parse_block_expr()
    self.skip_separators()
    ignore(self.expect(TokenKind::RBrace))
    (parsed_body, None, None)
  }
}

///|
fn Parser::parse_declaration_function_body(
  self : Parser,
  span : @common.SourceSpan,
) -> (@ast.Expr, String?, @ast.ExternDecl?) {
  let mut intrinsic : String? = None
  if self.current().kind == TokenKind::Eq {
    ignore(self.bump())
    self.skip_separators()
    if self.current().kind == TokenKind::StringLiteral {
      intrinsic = Some(self.parse_string_binding())
    } else {
      self.skip_declaration_body_tail()
    }
  } else if self.current().kind == TokenKind::LBrace {
    self.skip_balanced_braces()
  } else if self.current().kind
    is (TokenKind::Newline | TokenKind::Semicolon | TokenKind::Eof) {
    ()
  } else {
    self.skip_declaration_body_tail()
  }
  (@ast.Expr::UnitLiteral(span), intrinsic, None)
}

///|
fn Parser::skip_declaration_body_tail(self : Parser) -> Unit {
  while !(self.current().kind
        is (TokenKind::Newline | TokenKind::Semicolon | TokenKind::Eof)) {
    match self.current().kind {
      TokenKind::LBrace => self.skip_balanced_braces()
      TokenKind::LParen => self.skip_balanced_parens()
      TokenKind::LBracket => self.skip_balanced_brackets()
      _ => ignore(self.bump())
    }
  }
}

///|
fn Parser::take_pending_aliases(self : Parser) -> Array[String] {
  let aliases = self.pending_aliases
  self.pending_aliases = []
  aliases
}

///|
fn Parser::take_pending_intrinsic(self : Parser) -> String? {
  let intrinsic = self.pending_intrinsic
  self.pending_intrinsic = None
  intrinsic
}

///|
fn Parser::parse_extern_header(self : Parser) -> @ast.ExternDecl {
  ignore(self.expect(TokenKind::Extern))
  let target = if self.current().kind == TokenKind::StringLiteral {
    unquote(self.bump().text)
  } else {
    ""
  }
  { target, body: None }
}

///|
fn Parser::parse_extern_function_body(
  self : Parser,
  extern_decl : @ast.ExternDecl,
  span : @common.SourceSpan,
) -> (@ast.Expr, String?, @ast.ExternDecl?) {
  let mut body : String? = None
  let mut intrinsic : String? = None
  if self.current().kind == TokenKind::Eq {
    ignore(self.bump())
    self.skip_separators()
    if self.current().kind == TokenKind::StringLiteral {
      let text = self.bump().text
      if text.has_prefix("#|") {
        body = Some(self.collect_raw_body_lines(text))
      } else {
        intrinsic = Some(self.collect_string_binding(unquote(text)))
      }
    }
  }
  (
    @ast.Expr::UnitLiteral(span),
    intrinsic,
    Some({ target: extern_decl.target, body }),
  )
}

///|
fn Parser::parse_string_binding(self : Parser) -> String {
  self.collect_string_binding(unquote(self.bump().text))
}

///|
fn Parser::collect_string_binding(self : Parser, first : String) -> String {
  let mut value = first
  while self.current().kind == TokenKind::StringLiteral {
    value = value + " " + unquote(self.bump().text)
  }
  value
}

///|
fn Parser::collect_raw_body_lines(self : Parser, first : String) -> String {
  let body = StringBuilder::new()
  write_raw_body_line_content(body, first)
  while self.raw_string_line_follows_after_separators() {
    self.skip_separators()
    body.write_string("\n")
    write_raw_body_line_content(body, self.bump().text)
  }
  body.to_string()
}

///|
fn Parser::raw_string_line_follows_after_separators(self : Parser) -> Bool {
  let mut index = self.pos
  while index < self.tokens.length() &&
        self.tokens[index].kind is (TokenKind::Newline | TokenKind::Semicolon) {
    index = index + 1
  }
  index < self.tokens.length() &&
  self.tokens[index].kind == TokenKind::StringLiteral &&
  self.tokens[index].text.has_prefix("#|")
}

///|
fn write_raw_body_line_content(body : StringBuilder, text : String) -> Unit {
  if text.has_prefix("#|") {
    body.write_stringview(text[2:])
  } else {
    body.write_string(text)
  }
}

///|
fn Parser::parse_function_name(self : Parser) -> (@ast.TypeSyntax?, Token) {
  if self.receiver_type_ahead() {
    let receiver = self.parse_type()
    ignore(self.expect(TokenKind::ColonColon))
    let name = self.expect_name_token()
    (Some(receiver), name)
  } else {
    let first = self.expect_name_token()
    (None, first)
  }
}

///|
fn Parser::receiver_type_ahead(self : Parser) -> Bool {
  let mut index = self.pos
  let mut bracket_depth = 0
  let mut paren_depth = 0
  while index < self.tokens.length() {
    match self.tokens[index].kind {
      TokenKind::ColonColon if bracket_depth == 0 && paren_depth == 0 =>
        return true
      TokenKind::LBracket => bracket_depth = bracket_depth + 1
      TokenKind::RBracket =>
        if bracket_depth > 0 {
          bracket_depth = bracket_depth - 1
        } else {
          return false
        }
      TokenKind::LParen =>
        if index == self.pos {
          paren_depth = paren_depth + 1
        } else if bracket_depth == 0 && paren_depth == 0 {
          return false
        } else {
          paren_depth = paren_depth + 1
        }
      TokenKind::RParen =>
        if paren_depth > 0 {
          paren_depth = paren_depth - 1
        } else {
          return false
        }
      TokenKind::Newline
      | TokenKind::Semicolon
      | TokenKind::LBrace
      | TokenKind::Eq
      | TokenKind::Arrow
      | TokenKind::Eof => return false
      _ => ()
    }
    index = index + 1
  }
  false
}

///|
fn Parser::expect_name_token(self : Parser) -> Token {
  match self.current().kind {
    TokenKind::Identifier | TokenKind::All => self.bump()
    _ => self.expect(TokenKind::Identifier)
  }
}

///|
fn unit_type_syntax(span : @common.SourceSpan) -> @ast.TypeSyntax {
  { package_alias: None, name: "Unit", args: [], is_trait_object: false, span }
}

///|
fn inferred_type_syntax(span : @common.SourceSpan) -> @ast.TypeSyntax {
  { package_alias: None, name: "_", args: [], is_trait_object: false, span }
}

///|
fn Parser::parse_params(self : Parser) -> Array[@ast.Param] {
  let params : Array[@ast.Param] = []
  self.skip_separators()
  if self.current().kind == TokenKind::RParen {
    return params
  }
  let mut ordinal = 0
  while !self.at_param_list_end() {
    if self.interface_unnamed_param_ahead() {
      let type_ = self.parse_type()
      let name = "arg" + ordinal.to_string()
      params.push({
        name,
        optional: false,
        labelled: false,
        type_,
        default_value: None,
        span: type_.span,
      })
    } else {
      let name = self.parse_param_name()
      let optional = if self.current().kind == TokenKind::Question {
        ignore(self.bump())
        true
      } else {
        false
      }
      let labelled = if self.current().kind == TokenKind::Tilde {
        ignore(self.bump())
        true
      } else {
        false
      }
      ignore(self.expect(TokenKind::Colon))
      let type_ = self.parse_type()
      let default_value = if self.current().kind == TokenKind::Eq {
        ignore(self.bump())
        Some(self.parse_expr())
      } else {
        None
      }
      params.push({
        name: if name.text == "_" {
          "arg" + ordinal.to_string()
        } else {
          name.text
        },
        optional,
        labelled,
        type_,
        default_value,
        span: name.span,
      })
    }
    ordinal = ordinal + 1
    if self.current().kind == TokenKind::Comma {
      ignore(self.bump())
      self.skip_separators()
    } else {
      break
    }
  }
  params
}

///|
fn Parser::interface_unnamed_param_ahead(self : Parser) -> Bool {
  self.is_interface &&
  (
    self.current().kind == TokenKind::LParen ||
    self.current().kind == TokenKind::Amp ||
    self.current().kind == TokenKind::At ||
    self.current().kind == TokenKind::PackageName ||
    (
      self.current().kind == TokenKind::Identifier &&
      (
        self.peek_kind(1)
        is (TokenKind::Comma | TokenKind::RParen | TokenKind::LBracket) ||
        (
          self.peek_kind(1) == TokenKind::Question &&
          self.peek_kind(2) != TokenKind::Colon
        )
      )
    )
  )
}

///|
fn Parser::parse_type(self : Parser) -> @ast.TypeSyntax {
  let is_trait_object = if self.current().kind == TokenKind::Amp {
    ignore(self.bump())
    true
  } else {
    false
  }
  if self.current().kind == TokenKind::LParen {
    let type_ = self.parse_tuple_type(is_trait_object)
    return self.apply_optional_type_suffix(type_)
  }
  let package_alias = if self.current().kind
    is (TokenKind::PackageName | TokenKind::At) {
    let alias_name = self.expect_package_name().text
    ignore(self.expect(TokenKind::Dot))
    Some(alias_name)
  } else {
    None
  }
  let name = if self.current().kind == TokenKind::Underscore {
    self.bump()
  } else {
    self.expect(TokenKind::Identifier)
  }
  let args : Array[@ast.TypeSyntax] = []
  if self.current().kind == TokenKind::LBracket {
    ignore(self.bump())
    self.skip_separators()
    if self.current().kind != TokenKind::RBracket {
      while !self.at_bracketed_list_end() {
        args.push(self.parse_type())
        if self.current().kind == TokenKind::Comma {
          ignore(self.bump())
          self.skip_separators()
        } else {
          break
        }
      }
    }
    ignore(self.expect(TokenKind::RBracket))
  }
  let type_ : @ast.TypeSyntax = {
    package_alias,
    name: name.text,
    args,
    is_trait_object,
    span: name.span,
  }
  self.apply_optional_type_suffix(type_)
}

///|
fn Parser::expect_package_name(self : Parser) -> Token {
  if self.current().kind == TokenKind::PackageName {
    self.bump()
  } else {
    ignore(self.expect(TokenKind::At))
    match self.current().kind {
      TokenKind::Identifier | TokenKind::Package => self.bump()
      _ => self.expect(TokenKind::Identifier)
    }
  }
}

///|
fn Parser::apply_optional_type_suffix(
  self : Parser,
  type_ : @ast.TypeSyntax,
) -> @ast.TypeSyntax {
  let mut result = type_
  while self.current().kind == TokenKind::Question {
    let question = self.bump()
    result = {
      package_alias: None,
      name: "Option",
      args: [result],
      is_trait_object: false,
      span: merge_span(result.span, question.span),
    }
  }
  result
}

///|
fn Parser::parse_tuple_type(
  self : Parser,
  is_trait_object : Bool,
) -> @ast.TypeSyntax {
  let start = self.expect(TokenKind::LParen)
  let items : Array[@ast.TypeSyntax] = []
  let mut saw_comma = false
  self.skip_separators()
  while !(self.current().kind is (TokenKind::RParen | TokenKind::Eof)) {
    items.push(self.parse_type())
    if self.current().kind == TokenKind::Comma {
      ignore(self.bump())
      saw_comma = true
      self.skip_separators()
    } else {
      break
    }
  }
  let close = self.expect(TokenKind::RParen)
  if self.current().kind == TokenKind::Arrow {
    ignore(self.bump())
    let return_type = self.parse_type()
    self.skip_effect_suffix()
    let args = items
    args.push(return_type)
    return {
      package_alias: None,
      name: "Function",
      args,
      is_trait_object,
      span: merge_span(start.span, close.span),
    }
  }
  if items.length() == 1 && !saw_comma {
    return items[0]
  }
  {
    package_alias: None,
    name: "Tuple",
    args: items,
    is_trait_object,
    span: merge_span(start.span, close.span),
  }
}

///|
fn Parser::parse_effect_suffix(self : Parser) -> @ast.TypeSyntax? {
  if self.current().kind == TokenKind::Raise {
    ignore(self.bump())
    if self.current().kind == TokenKind::Question {
      ignore(self.bump())
      None
    } else if self.current().kind
      is (TokenKind::Identifier | TokenKind::PackageName | TokenKind::At) {
      Some(self.parse_type())
    } else {
      Some(unit_type_syntax(self.current().span))
    }
  } else {
    None
  }
}

///|
fn Parser::skip_effect_suffix(self : Parser) -> Unit {
  ignore(self.parse_effect_suffix())
}

///|
fn Parser::current(self : Parser) -> Token {
  if self.pos < self.tokens.length() {
    self.tokens[self.pos]
  } else {
    self.tokens[self.tokens.length() - 1]
  }
}

///|
fn Parser::peek(self : Parser) -> Token {
  self.peek_token(1)
}

///|
fn Parser::peek_token(self : Parser, offset : Int) -> Token {
  if self.pos + offset < self.tokens.length() {
    self.tokens[self.pos + offset]
  } else {
    self.tokens[self.tokens.length() - 1]
  }
}

///|
fn Parser::peek_kind(self : Parser, offset : Int) -> TokenKind {
  let index = self.pos + offset
  if index < self.tokens.length() {
    self.tokens[index].kind
  } else {
    TokenKind::Eof
  }
}

///|
fn Parser::bump(self : Parser) -> Token {
  let token = self.current()
  self.pos = self.pos + 1
  token
}

///|
fn Parser::expect(self : Parser, kind : TokenKind) -> Token {
  if self.current().kind == kind {
    self.bump()
  } else {
    let current = self.current()
    self.diagnostics.push({
      severity: "error",
      code: "VNX0100",
      message: "unexpected token",
      span: current.span,
    })
    if current.kind != TokenKind::Eof {
      ignore(self.bump())
    }
    { kind, text: "", span: current.span }
  }
}

///|
fn Parser::skip_separators(self : Parser) -> Unit {
  while self.current().kind == TokenKind::Newline ||
        self.current().kind == TokenKind::Semicolon {
    ignore(self.bump())
  }
}

///|
fn Parser::expect_statement_separator(self : Parser) -> Unit {
  if self.current().kind == TokenKind::Newline ||
    self.current().kind == TokenKind::Semicolon {
    self.skip_separators()
  } else if !(self.current().kind is (TokenKind::RBrace | TokenKind::Eof)) {
    let current = self.current()
    self.diagnostics.push({
      severity: "error",
      code: "VNX0101",
      message: "expected statement separator",
      span: current.span,
    })
  }
}

///|
fn Parser::at_struct_body_end(self : Parser) -> Bool {
  self.current().kind is (TokenKind::RBrace | TokenKind::Eof)
}

///|
fn Parser::at_bracketed_list_end(self : Parser) -> Bool {
  self.current().kind is (TokenKind::RBracket | TokenKind::Eof)
}

///|
fn Parser::at_param_list_end(self : Parser) -> Bool {
  self.current().kind is (TokenKind::RParen | TokenKind::Eof)
}

///|
fn merge_span(
  left : @common.SourceSpan,
  right : @common.SourceSpan,
) -> @common.SourceSpan {
  {
    file: left.file,
    start: left.start,
    end: right.end,
    line: left.line,
    column: left.column,
  }
}
