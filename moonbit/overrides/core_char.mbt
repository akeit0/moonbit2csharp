package "moonbitlang/core/builtin"

///|
pub extern "csharp" fn Char::to_string(self : Char) -> String =
  #|return char.ConvertFromUtf32(self);

///|
pub extern "csharp" fn Char::escape(
  self : Char,
  quote? : Bool = true,
) -> String =
  #|var builder = new System.Text.StringBuilder();
  #|if (quote)
  #|{
  #|    builder.Append('\'');
  #|}
  #|switch (self)
  #|{
  #|    case 39:
  #|        builder.Append("\\'");
  #|        break;
  #|    case 92:
  #|        builder.Append("\\\\");
  #|        break;
  #|    case 10:
  #|        builder.Append("\\n");
  #|        break;
  #|    case 13:
  #|        builder.Append("\\r");
  #|        break;
  #|    case 8:
  #|        builder.Append("\\b");
  #|        break;
  #|    case 9:
  #|        builder.Append("\\t");
  #|        break;
  #|    default:
  #|        var text = char.ConvertFromUtf32(self);
  #|        if (System.Text.Rune.TryCreate(self, out var rune) && !System.Text.Rune.IsControl(rune))
  #|        {
  #|            builder.Append(text);
  #|        }
  #|        else
  #|        {
  #|            builder.Append("\\u{");
  #|            builder.Append(self.ToString("x", System.Globalization.CultureInfo.InvariantCulture));
  #|            builder.Append('}');
  #|        }
  #|        break;
  #|}
  #|if (quote)
  #|{
  #|    builder.Append('\'');
  #|}
  #|return builder.ToString();
