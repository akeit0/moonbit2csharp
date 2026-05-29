///|
pub fn args() -> Array[String] {
  @env.args()
}

///|
pub fn source_from_args() -> String {
  let direct = @env.get_env_var("MOONBIT_CSHARP_SOURCE")
  if direct is Some(_) {
    direct.unwrap()
  } else {
    let count_text = @env.get_env_var("MOONBIT_CSHARP_SOURCE_COUNT")
    if count_text is Some(_) {
      source_from_env_chunks(
        "MOONBIT_CSHARP_SOURCE_",
        parse_positive_int(count_text.unwrap()),
      )
    } else {
      let args = @env.args()
      let mut source = ""
      if args.length() > 1 {
        source = args[1]
      }
      source
    }
  }
}

///|
pub fn env_source_from_args(source : String) -> String {
  let direct = @env.get_env_var("MOONBIT_CSHARP_ENV_SOURCE")
  if direct is Some(_) {
    direct.unwrap()
  } else {
    let count_text = @env.get_env_var("MOONBIT_CSHARP_ENV_SOURCE_COUNT")
    if count_text is Some(_) {
      source_from_env_chunks(
        "MOONBIT_CSHARP_ENV_SOURCE_",
        parse_positive_int(count_text.unwrap()),
      )
    } else {
      source
    }
  }
}

///|
pub fn builtin_source_from_args() -> String {
  text_from_env_or_file_or_chunks(
    "MOONBIT_CSHARP_BUILTIN_SOURCE", "MOONBIT_CSHARP_BUILTIN_SOURCE_FILE", "MOONBIT_CSHARP_BUILTIN_SOURCE_COUNT",
    "MOONBIT_CSHARP_BUILTIN_SOURCE_",
  )
}

///|
pub fn frontend2_core_builtin_source_from_args() -> String {
  text_from_env_or_file_or_chunks(
    "MOONBIT_CSHARP_FRONTEND2_CORE_BUILTIN_SOURCE", "MOONBIT_CSHARP_FRONTEND2_CORE_BUILTIN_SOURCE_FILE",
    "MOONBIT_CSHARP_FRONTEND2_CORE_BUILTIN_SOURCE_COUNT", "MOONBIT_CSHARP_FRONTEND2_CORE_BUILTIN_SOURCE_",
  )
}

///|
pub fn module_name_from_args() -> String {
  match @env.get_env_var("MOONBIT_CSHARP_MODULE_NAME") {
    Some(name) => name
    None => "MoonBitModule"
  }
}

///|
pub fn frontend_mode_from_args() -> String {
  match @env.get_env_var("MOONBIT_CSHARP_MODE") {
    Some(mode) => mode
    None => "ir"
  }
}

///|
pub fn frontend2_mode_from_args() -> String {
  match @env.get_env_var("MOONBIT_CSHARP_FRONTEND2_MODE") {
    Some(mode) => mode
    None =>
      match @env.get_env_var("MOONBIT_CSHARP_MODE") {
        Some(mode) => mode
        None => "executable-ir"
      }
  }
}

///|
pub fn source_from_env_chunks(prefix : String, count : Int) -> String {
  let chunks : Array[String] = []
  for i in 0..<count {
    let key = prefix + i.to_string()
    match @env.get_env_var(key) {
      Some(chunk) => chunks.push(chunk)
      None => ()
    }
  }
  join_strings(chunks, "")
}

///|
pub fn join_strings(parts : Array[String], sep : String) -> String {
  let builder = StringBuilder::new()
  for i in 0..<parts.length() {
    if i > 0 {
      builder.write_string(sep)
    }
    builder.write_string(parts[i])
  }
  builder.to_string()
}

///|
pub fn parse_positive_int(text : String) -> Int {
  let mut value = 0
  for i in 0..<text.length() {
    let ch = text.code_unit_at(i)
    if ch is ('0'..='9') {
      value = value * 10 + (ch.to_int() - 48)
    }
  }
  value
}

///|
fn text_from_env_or_file_or_chunks(
  direct_key : String,
  file_key : String,
  count_key : String,
  chunk_prefix : String,
) -> String {
  let direct = @env.get_env_var(direct_key)
  if direct is Some(_) {
    direct.unwrap()
  } else {
    let file = @env.get_env_var(file_key)
    if file is Some(_) {
      read_text_file(file.unwrap())
    } else {
      let count_text = @env.get_env_var(count_key)
      if count_text is Some(_) {
        source_from_env_chunks(
          chunk_prefix,
          parse_positive_int(count_text.unwrap()),
        )
      } else {
        ""
      }
    }
  }
}
