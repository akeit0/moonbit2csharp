///|
pub(all) struct PackageManifest {
  imports : Array[@binding.ImportRef]
  diagnostics : Array[@common.Diagnostic]
} derive(Eq, Debug)

///|
pub(all) struct PackageSource {
  import_ref : @binding.ImportRef
  file_path : String
  source : String
} derive(Eq, Debug)

///|
pub(all) struct SourceUnit {
  file_path : String
  source : String
} derive(Eq, Debug)

///|
pub fn package_name_from_source(source : String, file_path : String) -> String? {
  let file = @text.source_file(file_path, source)
  let lexed = @syntax.lex(file)
  let parser : PackageDeclParser = { tokens: lexed.tokens, pos: 0 }
  parser.parse()
}

///|
pub fn parse_moon_pkg(source : String, file_path : String) -> PackageManifest {
  let file = @text.source_file(file_path, source)
  let lexed = @syntax.lex(file)
  let parser : ManifestParser = {
    tokens: lexed.tokens,
    pos: 0,
    diagnostics: lexed.diagnostics,
    imports: [],
  }
  parser.parse()
}

///|
priv struct ManifestParser {
  tokens : Array[@syntax.Token]
  mut pos : Int
  diagnostics : Array[@common.Diagnostic]
  imports : Array[@binding.ImportRef]
}

///|
fn ManifestParser::parse(self : ManifestParser) -> PackageManifest {
  while self.current().kind != @syntax.TokenKind::Eof {
    if self.current().kind == @syntax.TokenKind::Import {
      self.parse_import_block()
    } else {
      ignore(self.bump())
    }
  }
  { imports: self.imports, diagnostics: self.diagnostics }
}

///|
fn ManifestParser::parse_import_block(self : ManifestParser) -> Unit {
  ignore(self.bump())
  if !self.try_bump(@syntax.TokenKind::LBrace) {
    return
  }
  while self.current().kind != @syntax.TokenKind::RBrace &&
        self.current().kind != @syntax.TokenKind::Eof {
    if self.current().kind == @syntax.TokenKind::StringLiteral {
      let path_token = self.bump()
      let module_path = unquote(path_token.text)
      if self.current().kind == @syntax.TokenKind::PackageName {
        let alias_name = self.bump().text
        self.imports.push({
          alias_name,
          package_id: "pkg:" + module_path,
          module_path,
        })
      } else if self.try_bump(@syntax.TokenKind::At) {
        match self.parse_alias_token() {
          Some(alias_name) =>
            self.imports.push({
              alias_name,
              package_id: "pkg:" + module_path,
              module_path,
            })
          None => ()
        }
      } else {
        self.imports.push({
          alias_name: default_import_alias(module_path),
          package_id: "pkg:" + module_path,
          module_path,
        })
      }
    } else {
      ignore(self.bump())
    }
    ignore(self.try_bump(@syntax.TokenKind::Comma))
  }
  ignore(self.try_bump(@syntax.TokenKind::RBrace))
}

///|
fn ManifestParser::parse_alias_token(self : ManifestParser) -> String? {
  let current = self.current()
  match current.kind {
    @syntax.TokenKind::Identifier => {
      ignore(self.bump())
      Some(current.text)
    }
    _ => {
      self.diagnostics.push({
        severity: "error",
        code: "VNXPKG0100",
        message: "unexpected moon.pkg token",
        span: current.span,
      })
      None
    }
  }
}

///|
fn default_import_alias(module_path : String) -> String {
  let parts = module_path.split("/")
  let mut alias_name = module_path
  for part in parts {
    alias_name = part.to_owned()
  }
  alias_name
}

///|
fn ManifestParser::current(self : ManifestParser) -> @syntax.Token {
  if self.pos < self.tokens.length() {
    self.tokens[self.pos]
  } else {
    self.tokens[self.tokens.length() - 1]
  }
}

///|
fn ManifestParser::bump(self : ManifestParser) -> @syntax.Token {
  let token = self.current()
  self.pos = self.pos + 1
  token
}

///|
fn ManifestParser::try_bump(
  self : ManifestParser,
  kind : @syntax.TokenKind,
) -> Bool {
  if self.current().kind == kind {
    ignore(self.bump())
    true
  } else {
    false
  }
}

///|
fn unquote(text : String) -> String {
  if text.length() >= 2 {
    text[1:text.length() - 1].to_owned()
  } else {
    text
  }
}

///|
priv struct PackageDeclParser {
  tokens : Array[@syntax.Token]
  mut pos : Int
}

///|
fn PackageDeclParser::parse(self : PackageDeclParser) -> String? {
  while self.current().kind != @syntax.TokenKind::Eof {
    if self.current().kind == @syntax.TokenKind::Package {
      ignore(self.bump())
      if self.current().kind == @syntax.TokenKind::StringLiteral {
        return Some(unquote(self.bump().text))
      }
      return None
    }
    ignore(self.bump())
  }
  None
}

///|
fn PackageDeclParser::current(self : PackageDeclParser) -> @syntax.Token {
  if self.pos < self.tokens.length() {
    self.tokens[self.pos]
  } else {
    self.tokens[self.tokens.length() - 1]
  }
}

///|
fn PackageDeclParser::bump(self : PackageDeclParser) -> @syntax.Token {
  let token = self.current()
  self.pos = self.pos + 1
  token
}
