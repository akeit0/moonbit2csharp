///|
pub(all) struct SourceSpan {
  file : String
  start : Int
  end : Int
  line : Int
  column : Int
} derive(Eq, Debug)

///|
pub(all) struct Diagnostic {
  severity : String
  code : String
  message : String
  span : SourceSpan
} derive(Eq, Debug)

///|
pub fn source_span(
  file : String,
  start : Int,
  end : Int,
  line : Int,
  column : Int,
) -> SourceSpan {
  { file, start, end, line, column }
}
