pub(open) trait Logger {
  write_string(Self, String) -> Unit = _
  write_view(Self, StringView) -> Unit = _
  write_char(Self, Char) -> Unit = _
}

pub(open) trait Show {
  to_string(Self) -> String = _
}

pub impl Logger for StringBuilder with write_string(self, value) =
  "%logger_write_string"

pub impl Logger for StringBuilder with write_view(self, value) =
  "%logger_write_view"

pub impl Logger for StringBuilder with write_char(self, value) =
  "%logger_write_char"

pub impl Show for StringView with to_string(self) =
  "%stringview_to_string"

pub impl Show for String with to_string(self) =
  "%identity_string"

pub impl Show for Char with to_string(self) =
  "%char_to_string"
