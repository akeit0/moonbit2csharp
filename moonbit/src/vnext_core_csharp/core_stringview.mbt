package "moonbitlang/core/builtin"

///|
pub impl Show for StringView with to_string(self) = "%stringview_to_string"

///|
pub impl Eq for StringView with equal(self, other) = "%stringview_eq"

///|
pub impl Eq for StringView with not_equal(self, other) = "%stringview_ne"

///|
pub fn StringView::to_owned(self : StringView) -> String = "%stringview_to_string"

///|
pub fn StringView::is_empty(self : StringView) -> Bool = "%stringview_is_empty"

///|
pub fn StringView::find(self : StringView, needle : StringView) -> Int? = "%stringview_find"

///|
pub fn StringView::view(
  self : StringView,
  start_offset? : Int = 0,
  end_offset? : Int,
) -> StringView = "%stringview_view"

///|
pub fn StringView::get_char(self : StringView, idx : Int) -> Char? = "%stringview_get_char"

///|
pub fn StringView::to_array(self : StringView) -> Array[Char] = "%stringview_to_array"

///|
pub fn StringView::char_length(self : StringView) -> Int = "%stringview_char_length"

///|
pub fn StringView::to_lower(self : StringView) -> StringView = "%stringview_to_lower"

///|
pub extern "csharp" fn StringView::repeat(
  self : StringView,
  n : Int,
) -> StringView =
  #|if (n < 0)
  #|{
  #|    throw new Panic("invalid length");
  #|}
  #|var value = string.Concat(System.Linq.Enumerable.Repeat(self.ToString(), n));
  #|return new StringView(value, 0, value.Length);

///|
pub fn StringView::to_upper(self : StringView) -> StringView = "%stringview_to_upper"

///|
pub fn StringView::has_prefix(self : StringView, prefix : StringView) -> Bool = "%stringview_has_prefix"

///|
pub fn StringView::has_suffix(self : StringView, suffix : StringView) -> Bool = "%stringview_has_suffix"

///|
pub fn StringView::contains(self : StringView, needle : StringView) -> Bool = "%stringview_contains"

///|
pub fn StringView::contains_char(self : StringView, char : Char) -> Bool = "%stringview_contains_char"

///|
pub fn StringView::trim(
  self : StringView,
  chars? : StringView = "\t\n\r ",
) -> StringView = "%stringview_trim"

///|
pub fn StringView::trim_start(
  self : StringView,
  chars? : StringView = "\t\n\r ",
) -> StringView = "%stringview_trim_start"

///|
pub fn StringView::trim_end(
  self : StringView,
  chars? : StringView = "\t\n\r ",
) -> StringView = "%stringview_trim_end"

///|
pub extern "csharp" fn StringView::strip_prefix(
  self : StringView,
  prefix : StringView,
) -> StringView? =
  #|var prefixLength = prefix.Length;
  #|return self.AsSpan().StartsWith(prefix.AsSpan(), System.StringComparison.Ordinal)
  #|    ? Option<StringView>.Some(new StringView(self.Data, self.Start + prefixLength, self.End))
  #|    : Option<StringView>.None();

///|
pub extern "csharp" fn StringView::strip_suffix(
  self : StringView,
  suffix : StringView,
) -> StringView? =
  #|var suffixLength = suffix.Length;
  #|return self.AsSpan().EndsWith(suffix.AsSpan(), System.StringComparison.Ordinal)
  #|    ? Option<StringView>.Some(new StringView(self.Data, self.Start, self.End - suffixLength))
  #|    : Option<StringView>.None();

///|
pub extern "csharp" fn StringView::escape(
  self : StringView,
  quote? : Bool = true,
) -> StringView =
  #|var source = self.ToString();
  #|var builder = new System.Text.StringBuilder();
  #|if (quote)
  #|{
  #|    builder.Append('"');
  #|}
  #|
  #|foreach (var ch in source)
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
