extern "csharp" fn Char::to_string(self : Char) -> String =
  #| return char.ConvertFromUtf32(self);

extern "csharp" fn Char::to_int(self : Char) -> Int =
  #| return self;

extern "csharp" fn Byte::to_hex(self : Byte) -> String =
  #| return self.ToString("x2", System.Globalization.CultureInfo.InvariantCulture);

extern "csharp" fn String::make(length : Int, value : Char) -> String =
  #| if (length < 0) throw new MoonBitPanic("invalid length");
  #| return string.Concat(System.Linq.Enumerable.Repeat(char.ConvertFromUtf32(value), length));

extern "csharp" fn String::repeat(self : String, n : Int) -> String =
  #| if (n < 0) throw new MoonBitPanic("invalid length");
  #| return string.Concat(System.Linq.Enumerable.Repeat(self, n));

extern "csharp" fn String::contains(self : String, str : StringView) -> Bool =
  #| return self.AsSpan().Contains(str.AsSpan(), System.StringComparison.Ordinal);

extern "csharp" fn String::has_prefix(self : String, str : StringView) -> Bool =
  #| return self.AsSpan().StartsWith(str.AsSpan(), System.StringComparison.Ordinal);

extern "csharp" fn String::has_suffix(self : String, str : StringView) -> Bool =
  #| return self.AsSpan().EndsWith(str.AsSpan(), System.StringComparison.Ordinal);

pub fn String::strip_suffix(self : String, suffix : StringView) -> StringView? {
  if self.has_suffix(suffix) {
    Some(self[:self.length() - suffix.length()])
  } else {
    None
  }
}

extern "csharp" fn String::replace_all(
  self : String,
  old~ : StringView,
  new~ : StringView,
) -> String =
  #| return self.Replace(old.ToString(), @new.ToString(), System.StringComparison.Ordinal);

extern "csharp" fn String::trim(
  self : String,
  chars? : StringView = "\t\n\r ",
) -> StringView =
  #| var value = self.Trim(chars.ToString().ToCharArray());
  #| return new MoonBitStringView(value, 0, value.Length);

extern "csharp" fn String::trim_start(
  self : String,
  chars? : StringView = "\t\n\r ",
) -> StringView =
  #| var value = self.TrimStart(chars.ToString().ToCharArray());
  #| return new MoonBitStringView(value, 0, value.Length);

extern "csharp" fn String::trim_end(
  self : String,
  chars? : StringView = "\t\n\r ",
) -> StringView =
  #| var value = self.TrimEnd(chars.ToString().ToCharArray());
  #| return new MoonBitStringView(value, 0, value.Length);

extern "csharp" fn Double::to_string(self : Double) -> String =
  #| return self.ToString(System.Globalization.CultureInfo.InvariantCulture);

extern "csharp" fn String::is_empty(self : String) -> Bool =
  #| return self.Length == 0;

extern "csharp" fn String::char_length(
  self : String,
  start_offset? : Int = 0,
  end_offset? : Int,
) -> Int =
  #| var start = start_offset;
  #| var end = end_offset.IsSome ? end_offset.Unwrap() : self.Length;
  #| if (start < 0 || start > end || end > self.Length) throw new MoonBitPanic("invalid start or end index for String::codepoint_length");
  #| var count = 0;
  #| for (var i = start; i < end; i++, count++)
  #| {
  #|     var ch = self[i];
  #|     if (char.IsHighSurrogate(ch) && i + 1 < end)
  #|     {
  #|         if (!char.IsLowSurrogate(self[i + 1])) throw new MoonBitPanic("invalid surrogate pair");
  #|         i++;
  #|     }
  #| }
  #| return count;

extern "csharp" fn String::to_lower(self : String) -> String =
  #| return self.ToLowerInvariant();

extern "csharp" fn String::unsafe_substring(
  str : String,
  start~ : Int,
  end~ : Int,
) -> String =
  #| return str.Substring(start, end - start);

extern "csharp" fn String::to_array(self : String) -> Array[Char] =
  #| var items = new System.Collections.Generic.List<int>();
  #| for (var i = 0; i < self.Length; i++)
  #| {
  #|     var ch = self[i];
  #|     items.Add(char.IsHighSurrogate(ch) && i + 1 < self.Length && char.IsLowSurrogate(self[i + 1]) ? char.ConvertToUtf32(ch, self[++i]) : ch);
  #| }
  #| return new MoonBitArray<int>(items.ToArray());

extern "csharp" fn String::before(self : String, needle : StringView) -> StringView? =
  #| var index = self.IndexOf(needle.ToString(), System.StringComparison.Ordinal);
  #| return index < 0 ? MoonBitOption<MoonBitStringView>.None() : MoonBitOption<MoonBitStringView>.Some(new MoonBitStringView(self, 0, index));

extern "csharp" fn String::after(self : String, needle : StringView) -> StringView? =
  #| var needleText = needle.ToString();
  #| var index = self.IndexOf(needleText, System.StringComparison.Ordinal);
  #| return index < 0 ? MoonBitOption<MoonBitStringView>.None() : MoonBitOption<MoonBitStringView>.Some(new MoonBitStringView(self, index + needleText.Length, self.Length));

extern "csharp" fn String::split_once(
  self : String,
  needle : StringView,
) -> (StringView, StringView)? =
  #| var needleText = needle.ToString();
  #| var index = self.IndexOf(needleText, System.StringComparison.Ordinal);
  #| return index < 0 ? MoonBitOption<(MoonBitStringView, MoonBitStringView)>.None() : MoonBitOption<(MoonBitStringView, MoonBitStringView)>.Some((new MoonBitStringView(self, 0, index), new MoonBitStringView(self, index + needleText.Length, self.Length)));

extern "csharp" fn StringView::trim(
  self : StringView,
  chars? : StringView = "\t\n\r ",
) -> StringView =
  #| var value = self.ToString();
  #| var trimmed = value.Trim(chars.ToString().ToCharArray());
  #| return new MoonBitStringView(trimmed, 0, trimmed.Length);

extern "csharp" fn StringView::trim_start(
  self : StringView,
  chars? : StringView = "\t\n\r ",
) -> StringView =
  #| var value = self.ToString();
  #| var trimmed = value.TrimStart(chars.ToString().ToCharArray());
  #| return new MoonBitStringView(trimmed, 0, trimmed.Length);

extern "csharp" fn StringView::trim_end(
  self : StringView,
  chars? : StringView = "\t\n\r ",
) -> StringView =
  #| var value = self.ToString();
  #| var trimmed = value.TrimEnd(chars.ToString().ToCharArray());
  #| return new MoonBitStringView(trimmed, 0, trimmed.Length);

extern "csharp" fn StringView::repeat(self : StringView, n : Int) -> StringView =
  #| if (n < 0) throw new MoonBitPanic("invalid length");
  #| var value = string.Concat(System.Linq.Enumerable.Repeat(self.ToString(), n));
  #| return new MoonBitStringView(value, 0, value.Length);

extern "csharp" fn StringView::is_empty(self : StringView) -> Bool =
  #| return self.Length == 0;

extern "csharp" fn StringView::has_prefix(
  self : StringView,
  str : StringView,
) -> Bool =
  #| return self.AsSpan().StartsWith(str.AsSpan(), System.StringComparison.Ordinal);

extern "csharp" fn StringView::has_suffix(
  self : StringView,
  str : StringView,
) -> Bool =
  #| return self.AsSpan().EndsWith(str.AsSpan(), System.StringComparison.Ordinal);

pub fn StringView::strip_prefix(
  self : StringView,
  prefix : StringView,
) -> StringView? {
  if self.has_prefix(prefix) {
    Some(self[prefix.length():])
  } else {
    None
  }
}

pub fn StringView::strip_suffix(
  self : StringView,
  suffix : StringView,
) -> StringView? {
  if self.has_suffix(suffix) {
    Some(self[:self.length() - suffix.length()])
  } else {
    None
  }
}

extern "csharp" fn StringView::contains(
  self : StringView,
  str : StringView,
) -> Bool =
  #| return self.AsSpan().Contains(str.AsSpan(), System.StringComparison.Ordinal);

extern "csharp" fn StringView::find(self : StringView, str : StringView) -> Int? =
  #| var index = self.AsSpan().IndexOf(str.AsSpan());
  #| return index < 0 ? MoonBitOption<int>.None() : MoonBitOption<int>.Some(index);

extern "csharp" fn String::get_char(self : String, idx : Int) -> Char? =
  #| if ((uint)idx >= (uint)self.Length) return MoonBitOption<int>.None();
  #| var c = self[idx];
  #| if (char.IsHighSurrogate(c))
  #| {
  #|     if (idx + 1 >= self.Length || !char.IsLowSurrogate(self[idx + 1])) return MoonBitOption<int>.None();
  #|     return MoonBitOption<int>.Some(char.ConvertToUtf32(c, self[idx + 1]));
  #| }
  #| if (char.IsLowSurrogate(c)) return MoonBitOption<int>.None();
  #| return MoonBitOption<int>.Some(c);

extern "csharp" fn[A] Array::join(
  self : Array[A],
  separator : StringView,
) -> String =
  #| var sep = separator.ToString();
  #| var items = new string[self.Length];
  #| for (var i = 0; i < self.Length; i++) items[i] = self.Buffer[i]?.ToString() ?? "";
  #| return string.Join(sep, items);
