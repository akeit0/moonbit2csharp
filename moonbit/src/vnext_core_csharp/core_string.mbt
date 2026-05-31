package "moonbitlang/core/builtin"

///|
pub fn String::split(self : String, sep : StringView) -> Iter[StringView] = "%string_split"

///|
pub fn String::is_empty(self : String) -> Bool = "%string_is_empty"

///|
pub fn String::unsafe_substring(
  str : String,
  start~ : Int,
  end~ : Int,
) -> String = "%string.substring"

///|
pub extern "csharp" fn String::view(
  self : String,
  start_offset? : Int = 0,
  end_offset? : Int,
) -> StringView =
  #|var end = end_offset.IsSome ? end_offset.Value : self.Length;
  #|return new StringView(self, start_offset, end);

///|
pub fn String::get_char(self : String, idx : Int) -> Char? = "%string_get_char"

///|
pub fn String::to_array(self : String) -> Array[Char] = "%string_to_array"

///|
pub fn String::char_length(self : String) -> Int = "%string_char_length"

///|
pub fn String::make(length : Int, value : Char) -> String = "%string_make"

///|
pub extern "csharp" fn String::repeat(self : String, n : Int) -> String =
  #|if (n < 0)
  #|{
  #|    throw new Panic("invalid length");
  #|}
  #|return string.Concat(System.Linq.Enumerable.Repeat(self, n));

///|
pub fn String::to_lower(self : String) -> String = "%string_to_lower"

///|
pub fn String::to_upper(self : String) -> String = "%string_to_upper"

///|
pub fn String::has_prefix(self : String, prefix : StringView) -> Bool = "%string_has_prefix"

///|
pub fn String::has_suffix(self : String, suffix : StringView) -> Bool = "%string_has_suffix"

///|
pub fn String::contains(self : String, needle : StringView) -> Bool = "%string_contains"

///|
pub fn String::contains_char(self : String, char : Char) -> Bool = "%string_contains_char"

///|
pub fn String::trim(
  self : String,
  chars? : StringView = "\t\n\r ",
) -> StringView = "%string_trim"

///|
pub fn String::trim_start(
  self : String,
  chars? : StringView = "\t\n\r ",
) -> StringView = "%string_trim_start"

///|
pub fn String::trim_end(
  self : String,
  chars? : StringView = "\t\n\r ",
) -> StringView = "%string_trim_end"

///|
pub extern "csharp" fn String::strip_prefix(
  self : String,
  prefix : StringView,
) -> StringView? =
  #|var prefixLength = prefix.Length;
  #|return self.AsSpan().StartsWith(prefix.AsSpan(), System.StringComparison.Ordinal)
  #|    ? Option<StringView>.Some(new StringView(self, prefixLength, self.Length))
  #|    : Option<StringView>.None();

///|
pub extern "csharp" fn String::strip_suffix(
  self : String,
  suffix : StringView,
) -> StringView? =
  #|var suffixLength = suffix.Length;
  #|return self.AsSpan().EndsWith(suffix.AsSpan(), System.StringComparison.Ordinal)
  #|    ? Option<StringView>.Some(new StringView(self, 0, self.Length - suffixLength))
  #|    : Option<StringView>.None();

///|
pub extern "csharp" fn String::escape(
  self : String,
  quote? : Bool = true,
) -> String =
  #|var builder = new System.Text.StringBuilder();
  #|if (quote)
  #|{
  #|    builder.Append('"');
  #|}
  #|
  #|foreach (var ch in self)
  #|{
  #|    switch (ch)
  #|    {
  #|        case '"':
  #|            builder.Append("\\\"");
  #|            break;
  #|        case '\\':
  #|            builder.Append("\\\\");
  #|            break;
  #|        case '\n':
  #|            builder.Append("\\n");
  #|            break;
  #|        case '\r':
  #|            builder.Append("\\r");
  #|            break;
  #|        case '\b':
  #|            builder.Append("\\b");
  #|            break;
  #|        case '\t':
  #|            builder.Append("\\t");
  #|            break;
  #|        default:
  #|            if (ch < ' ')
  #|            {
  #|                builder.Append("\\u{");
  #|                builder.Append(((int)ch).ToString("x2", System.Globalization.CultureInfo.InvariantCulture));
  #|                builder.Append('}');
  #|            }
  #|            else
  #|            {
  #|                builder.Append(ch);
  #|            }
  #|            break;
  #|    }
  #|}
  #|
  #|if (quote)
  #|{
  #|    builder.Append('"');
  #|}
  #|return builder.ToString();
