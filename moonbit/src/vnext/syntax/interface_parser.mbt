///|
pub fn parse_interface_source(file : @text.SourceFile) -> ParseResult {
  parse_source_with_mode(file, true)
}
