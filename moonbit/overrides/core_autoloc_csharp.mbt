#external
#csharp("MoonBitSourceLoc")
type SourceLoc

pub(all) struct ArgsLoc(Array[SourceLoc?])

extern "csharp" fn SourceLoc::repr(self : SourceLoc) -> String =
  #| return self.ToString();

extern "csharp" fn SourceLoc::to_string(self : SourceLoc) -> String =
  #| return self.ToString();

extern "csharp" fn SourceLoc::to_json_string(self : SourceLoc) -> String =
  #| return self.ToJsonString();

pub fn ArgsLoc::to_json(self : ArgsLoc) -> String {
  let buf = StringBuilder::new(size_hint=10)
  let items : Array[SourceLoc?] = self.0
  buf.write_char('[')
  for i, item in items {
    if i != 0 {
      buf.write_string(", ")
    }
    match item {
      None => buf.write_string("null")
      Some(loc) => buf.write_string(loc.to_json_string())
    }
  }
  buf.write_char(']')
  buf.to_string()
}
