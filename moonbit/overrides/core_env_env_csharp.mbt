pub fn args() -> Array[String] {
  get_cli_args_internal()
}

extern "csharp" fn get_cli_args_internal() -> Array[String] =
  #| return MoonBitArray.FromArray(System.Environment.GetCommandLineArgs());

pub fn now() -> UInt64 {
  now_internal()
}

extern "csharp" fn now_internal() -> UInt64 =
  #| return (ulong)System.DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

pub fn current_dir() -> String? {
  current_dir_internal()
}

extern "csharp" fn current_dir_internal() -> String? =
  #| return MoonBitOption<string>.Some(System.Environment.CurrentDirectory);

pub fn get_env_var(key : String) -> String? {
  get_env_var_internal(key)
}

extern "csharp" fn get_env_var_internal(key : String) -> String? =
  #| var value = System.Environment.GetEnvironmentVariable(key);
  #| return value is null ? MoonBitOption<string>.None() : MoonBitOption<string>.Some(value);

pub fn set_env_var(key : String, value : String) -> Unit {
  set_env_var_internal(key, value)
}

extern "csharp" fn set_env_var_internal(
  key : String,
  value : String,
) -> Unit =
  #| System.Environment.SetEnvironmentVariable(key, value);
  #| return MoonBitUnit.Value;

pub fn unset_env_var(key : String) -> Unit {
  unset_env_var_internal(key)
}

extern "csharp" fn unset_env_var_internal(key : String) -> Unit =
  #| System.Environment.SetEnvironmentVariable(key, null);
  #| return MoonBitUnit.Value;
