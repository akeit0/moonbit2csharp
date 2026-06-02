package "moonbitlang/core/builtin"

///|
pub impl Logger for StringBuilder with write_string(self, value) =
  "%logger_write_string"

///|
pub impl Logger for StringBuilder with write_view(self, value) =
  "%logger_write_view"

///|
pub impl Logger for StringBuilder with write_char(self, value) =
  "%logger_write_char"
