///|
pub(all) struct SourceFile {
  file_id : String
  path : String
  text : String
} derive(Eq, Debug)

///|
pub fn source_file(path : String, text : String) -> SourceFile {
  { file_id: "file:" + path, path, text }
}

///|
pub fn span(
  file : SourceFile,
  start : Int,
  end : Int,
  line : Int,
  column : Int,
) -> @common.SourceSpan {
  @common.source_span(file.path, start, end, line, column)
}
