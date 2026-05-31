///|
fn compile_test_source_to_json(
  source : String,
  file_path : String,
  module_name : String,
) -> String {
  compile_package_sources_with_declarations_to_json(
    [{ file_path, source }],
    module_name,
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([]),
  )
}

///|
fn test_core_declaration_sources(
  extra : Array[@package.PackageSource],
) -> Array[@package.PackageSource] {
  let result : Array[@package.PackageSource] = [
    {
      import_ref: test_core_import_ref(),
      file_path: "test_core.mbt",
      source: test_core_source(),
    },
  ]
  for source in extra {
    result.push(source)
  }
  result
}

///|
fn test_core_import_ref() -> @binding.ImportRef {
  {
    alias_name: "builtin",
    package_id: "pkg:moonbitlang/core/builtin",
    module_path: "moonbitlang/core/builtin",
  }
}

///|
fn test_core_source() -> String {
  (
    #|pub(open) trait Logger {
    #|  write_string(Self, String) -> Unit = _
    #|  write_view(Self, StringView) -> Unit = _
    #|  write_char(Self, Char) -> Unit = _
    #|}
    #|pub(open) trait Show {
    #|  to_string(Self) -> String = _
    #|}
    #|pub(open) trait Eq {
    #|  equal(Self, Self) -> Bool
    #|  not_equal(Self, Self) -> Bool = _
    #|}
    #|pub(open) trait Compare : Eq {
    #|  compare(Self, Self) -> Int
    #|  op_lt(Self, Self) -> Bool = _
    #|  op_gt(Self, Self) -> Bool = _
    #|  op_le(Self, Self) -> Bool = _
    #|  op_ge(Self, Self) -> Bool = _
    #|}
    #|pub(open) trait Neg {
    #|  neg(Self) -> Self
    #|}
    #|pub(open) trait Add {
    #|  add(Self, Self) -> Self
    #|}
    #|pub(open) trait Sub {
    #|  sub(Self, Self) -> Self
    #|}
    #|pub(open) trait Mul {
    #|  mul(Self, Self) -> Self
    #|}
    #|pub(open) trait Div {
    #|  div(Self, Self) -> Self
    #|}
    #|pub(open) trait Mod {
    #|  mod(Self, Self) -> Self
    #|}
    #|pub(open) trait BitAnd {
    #|  land(Self, Self) -> Self
    #|}
    #|pub(open) trait BitOr {
    #|  lor(Self, Self) -> Self
    #|}
    #|pub(open) trait BitXOr {
    #|  lxor(Self, Self) -> Self
    #|}
    #|pub(open) trait Shl {
    #|  shl(Self, Int) -> Self
    #|}
    #|pub(open) trait Shr {
    #|  shr(Self, Int) -> Self
    #|}
    #|pub impl Neg for Int with neg(self) = "%i32_neg"
    #|pub impl Add for Int with add(self, other) = "%i32_add"
    #|pub impl Sub for Int with sub(self, other) = "%i32_sub"
    #|pub impl Mul for Int with mul(self, other) = "%i32_mul"
    #|pub impl Div for Int with div(self, other) = "%i32_div"
    #|pub impl Mod for Int with mod(self, other) = "%i32_mod"
    #|pub impl BitAnd for Int with land(self : Int, other : Int) -> Int = "%i32_land"
    #|pub impl BitOr for Int with lor(self : Int, other : Int) -> Int = "%i32_lor"
    #|pub impl BitXOr for Int with lxor(self : Int, other : Int) -> Int = "%i32_lxor"
    #|pub impl Shl for Int with shl(self, other) = "%i32_shl"
    #|pub impl Shr for Int with shr(self, other) = "%i32_shr"
    #|pub impl Eq for Int with equal(self : Int, other : Int) -> Bool = "%i32_eq"
    #|pub impl Eq for Int with not_equal(self : Int, other : Int) -> Bool = "%i32_ne"
    #|pub impl Compare for Int with compare(self, other) = "%i32_compare"
    #|pub impl Compare for Int with op_lt(x, y) = "%i32.lt"
    #|pub impl Compare for Int with op_le(x, y) = "%i32.le"
    #|pub impl Compare for Int with op_gt(x, y) = "%i32.gt"
    #|pub impl Compare for Int with op_ge(x, y) = "%i32.ge"
    #|pub impl Add for String with add(self, other) = "%string_add"
    #|pub impl Eq for String with equal(self : String, other : String) -> Bool = "%string_eq"
    #|pub impl Eq for Bool with equal(self : Bool, other : Bool) -> Bool = "%bool_eq"
    #|pub impl Eq for Char with equal(self : Char, other : Char) -> Bool = "%char_eq"
    #|pub impl Eq for Char with not_equal(self : Char, other : Char) -> Bool = "%i32_ne"
    #|pub impl Compare for Char with compare(self : Char, other : Char) -> Int = "%i32_compare"
    #|pub impl Compare for Char with op_lt(x : Char, y : Char) -> Bool = "%i32.lt"
    #|pub impl Compare for Char with op_le(x : Char, y : Char) -> Bool = "%i32.le"
    #|pub impl Compare for Char with op_gt(x : Char, y : Char) -> Bool = "%i32.gt"
    #|pub impl Compare for Char with op_ge(x : Char, y : Char) -> Bool = "%i32.ge"
    #|pub impl Eq for UInt16 with equal(self : UInt16, other : UInt16) -> Bool = "%u16_eq"
    #|pub impl Eq for UInt16 with not_equal(self : UInt16, other : UInt16) -> Bool = "%u16_ne"
    #|pub impl[T] Add for Array[T] with add(self, other) = "%array_add"
    #|pub impl Logger for StringBuilder with write_string(self, value) = "%logger_write_string"
    #|pub impl Logger for StringBuilder with write_view(self, value) = "%logger_write_view"
    #|pub impl Logger for StringBuilder with write_char(self, value) = "%logger_write_char"
    #|pub impl Show for StringView with to_string(self) = "%stringview_to_string"
    #|pub impl Show for String with to_string(self) = "%identity_string"
    #|pub impl Show for Char with to_string(self) = "%char_to_string"
    #|pub impl Show for Bytes with to_string(self) = "%bytes_to_string"
    #|pub fn[T : Show] StringBuilder::write_object(self : StringBuilder, value : T) -> Unit {
    #|  self.write_string(value.to_string())
    #|}
    #|fn println_mono(value : String) -> Unit = "%println"
    #|pub fn[T : Show] println(input : T) -> Unit {
    #|  println_mono(input.to_string())
    #|}
    #|pub extern "csharp" fn StringBuilder::new() -> StringBuilder =
    #|  #|return new MoonBitStringBuilder();
    #|pub extern "csharp" fn StringBuilder::write_char(self : StringBuilder, value : Char) -> Unit =
    #|  #|return self.WriteChar(value);
    #|pub extern "csharp" fn StringBuilder::to_string(self : StringBuilder) -> String =
    #|  #|return self.ToString();
    #|pub extern "csharp" fn String::unsafe_get(self : String, index : Int) -> UInt16 =
    #|  #|return self[index];
    #|#alias("_[_]")
    #|pub fn String::at(self : String, idx : Int) -> UInt16 = "%string_get"
  )
}

///|
test "vnext lowers logger append interpolated strings to logger writes" {
  let source = "fn main() -> Unit {\n  let world = \"world\"\n  let sb = StringBuilder::new()\n  sb <+ \"Hello, \\{world}!\"\n}\n"
  let json = compile_test_source_to_json(source, "logger_append.mbt", "Main")
  assert_true(json.contains("\"diagnostics\":[]"))
  assert_true(json.contains("\"name\":\"write_string\""))
  assert_true(json.contains("\"name\":\"StringBuilder::write_object\""))
  assert_true(json.contains("\"value\":\"Hello, \""))
  assert_true(json.contains("\"value\":\"!\""))
}

///|
test "vnext compiles demo function through package architecture" {
  let source = "fn demo_func(a:Int, b : Int)-> Int{\n\n  a + b\n}\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(
    json.contains("\"schema\":\"moonbit2csharp.vnext.semantic-ir/0.1\""),
  )
  assert_true(json.contains("\"kind\":\"Function\""))
  assert_true(json.contains("\"name\":\"demo_func\""))
  assert_true(json.contains("\"kind\":\"Binary\""))
  assert_true(json.contains("\"selectedIntrinsic\":\"%i32_add\""))
  if !json.contains("\"diagnostics\":[]") {
    fail(json)
  }
}

///|
test "vnext resolves string add operator" {
  let source = "fn join(a:String, b:String)->String { a + b }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"selectedIntrinsic\":\"%string_add\""))
  if !json.contains("\"diagnostics\":[]") {
    fail(json)
  }
}

///|
test "vnext infers empty array element type through append receiver call" {
  let core_source =
    #|pub fn[T] Array::append(self : Array[T], other : ArrayView[T]) -> Unit = "%array_append"
    #|
  let source =
    #|fn collect(value : String) -> Array[String] {
    #|  let xs = []
    #|  xs.append([value])
    #|  xs
    #|}
    #|
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "demo.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: test_core_import_ref(),
        file_path: "core_array_append.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Array::append\"",
    ),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext feeds inferred match result type to later arms" {
  let core_source =
    #|pub fn[T] Array::append(self : Array[T], other : ArrayView[T]) -> Unit = "%array_append"
    #|
  let source =
    #|fn collect(flag : Bool, value : String) -> Array[String] {
    #|  let result = match flag {
    #|    true => [value]
    #|    false => {
    #|      let xs = []
    #|      xs.append([value])
    #|      xs
    #|    }
    #|  }
    #|  result
    #|}
    #|
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "demo.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: test_core_import_ref(),
        file_path: "core_array_append.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Array::append\"",
    ),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext keeps receiver candidates for unresolved local array" {
  let core_source =
    #|pub fn[T] Array::append(self : Array[T], other : ArrayView[T]) -> Unit = "%array_append"
    #|
  let source =
    #|fn collect(value : String) -> Array[String] {
    #|  let result = match true {
    #|    true => [value]
    #|    false => {
    #|      let xs = []
    #|      xs.append([value])
    #|      [..xs]
    #|    }
    #|  }
    #|  result
    #|}
    #|
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "demo.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: test_core_import_ref(),
        file_path: "core_array_append.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Array::append\"",
    ),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext parses comparison equality and shift operators as selected calls" {
  let source = "fn less_eq(a:Int, b:Int)->Bool { a <= b }\nfn eq(a:Int, b:Int)->Bool { a == b }\nfn shift(a:Int, b:Int)->Int { a << b }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"selectedIntrinsic\":\"%i32.le\""))
  assert_true(json.contains("\"selectedIntrinsic\":\"%i32_eq\""))
  assert_true(json.contains("\"selectedIntrinsic\":\"%i32_shl\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext lowers range for loops as typed unit statements" {
  let source = "struct Counter { mut val: Int }\nfn sum()->Int { let counter : Counter = {val:0}; for i in 0..<4 { counter.val = counter.val + i }; counter.val }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"ForRange\""))
  assert_true(json.contains("\"name\":\"i\""))
  assert_true(json.contains("\"inclusive\":false"))
  assert_true(json.contains("\"reverse\":false"))
  assert_true(json.contains("\"excludeStart\":false"))
  assert_true(json.contains("\"kind\":\"FieldAssign\""))
  assert_true(json.contains("\"kind\":\"Builtin\",\"name\":\"Unit\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext lowers C-style for loops break continue and local updates" {
  let source = "struct Counter { mut val: Int }\nfn loop_sum()->Int { let counter : Counter = {val:0}; for i = 0; i < 4; i = i + 1 { counter.val = counter.val + i }; counter.val }\nfn loop_break()->Unit { for j = 0; j < 4; j = j + 1 { break } }\nfn loop_continue()->Unit { for k = 0; k < 4; k = k + 1 { continue } }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"ForLoop\""))
  assert_true(json.contains("\"bindings\":["))
  assert_true(json.contains("\"updates\":[{\"kind\":\"Assign\""))
  assert_true(json.contains("\"kind\":\"Break\""))
  assert_true(json.contains("\"kind\":\"Continue\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext accepts empty range and C-style loop bodies" {
  let source = "fn f()->Unit{\n    for i in 0..<10 {\n    }\n    for i =0; i < 10; i=i+1 {\n    }\n}\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"ForRange\""))
  assert_true(json.contains("\"kind\":\"ForLoop\""))
  assert_true(json.contains("\"kind\":\"UnitLiteral\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext lowers for-in loops with value and index bindings" {
  let source = "struct Counter { mut val: Int }\nfn sum(xs:FixedArray[Int])->Int { let counter : Counter = {val:0}; for x in xs { counter.val = counter.val + x }; for i, x in xs { counter.val = counter.val + i + x }; counter.val }\n"
  let core_source = "struct Iter[X] { f : () -> X? }\nstruct Iter2[X, Y] { iter : Iter[(X, Y)] }\n///|\npub extern \"csharp\" fn[T] FixedArray::iter(self : FixedArray[T]) -> Iter[T] =\n  #|return default!;\n///|\npub extern \"csharp\" fn[T] FixedArray::iter2(self : FixedArray[T]) -> Iter2[Int, T] =\n  #|return default!;\n"
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "demo.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: {
          alias_name: "builtin",
          package_id: "pkg:moonbitlang/core/builtin",
          module_path: "moonbitlang/core/builtin",
        },
        file_path: "core_fixedarray_iter.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(json.contains("\"kind\":\"ForIn\""))
  assert_true(json.contains("\"iterator\":{\"kind\":\"Call\""))
  assert_true(json.contains("FixedArray::iter"))
  assert_true(
    json.contains(
      "\"valueSymbols\":[{\"symbolId\":\"local:fn:pkg:Demo:Demo:sum:",
    ),
  )
  assert_true(json.contains("\"name\":\"x\""))
  assert_true(json.contains("FixedArray::iter2"))
  assert_true(json.contains("\"name\":\"i\""))
  assert_true(json.contains("\"kind\":\"FieldAssign\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves for-in through iter methods" {
  let source = "fn chars(s:String)->Unit { for c in s { let _ = c }; for part in s.split(\"\\n\") { let _ = part } }\n"
  let core_source = "struct Iter[X] { f : () -> X? }\npub extern \"csharp\" fn String::iter(self : String) -> Iter[Char] =\n  #|return default!;\npub extern \"csharp\" fn String::split(self : String, sep : StringView) -> Iter[StringView] =\n  #|return default!;\n"
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "demo.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: {
          alias_name: "builtin",
          package_id: "pkg:moonbitlang/core/builtin",
          module_path: "moonbitlang/core/builtin",
        },
        file_path: "core_string_iter.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(json.contains("\"kind\":\"ForIn\""))
  assert_true(json.contains("String::iter"))
  assert_true(json.contains("String::split"))
  assert_true(json.contains("\"iterator\":{\"kind\":\"Call\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext lowers valued functional loop break and continue arguments" {
  let source = "fn first_hit()->Int { for i = 0 { if i == 4 { break i } else { continue i + 1 } } }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"ForLoop\""))
  assert_true(json.contains("\"kind\":\"Break\",\"value\":{\"kind\":\"Name\""))
  assert_true(
    json.contains("\"kind\":\"Continue\",\"args\":[{\"kind\":\"Binary\""),
  )
  assert_true(json.contains("\"type\":{\"kind\":\"Builtin\",\"name\":\"Int\"}"))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext lowers explicit return as control IR" {
  let source = "fn keep(x:Int)->Int { if x > 0 { return x } else { return 0 } }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Return\",\"value\":{\"kind\":\"Name\""))
  assert_true(
    json.contains("\"kind\":\"Return\",\"value\":{\"kind\":\"IntLiteral\""),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves Array for-in through declaration-only core source" {
  let source =
    #|pub(all) struct LinkDefinition { val : Int }
    #|pub(all) struct ParseResult { definitions : Array[LinkDefinition] }
    #|struct BlockParser {}
    #|fn BlockParser::parse_document(self : BlockParser) -> ParseResult {
    #|  { definitions: [] }
    #|}
    #|fn f(inner_parser: BlockParser)->Unit {
    #|  let inner_result = inner_parser.parse_document()
    #|  for def in inner_result.definitions {
    #|    let _ = def
    #|  }
    #|}
  let core_source =
    #|struct Iter[X] {
    #|  f : () -> X?
    #|}
    #|pub extern "csharp" fn[X] Iter::new(f : () -> X?) -> Iter[X] =
    #|  #| return new MoonBitIter<X>(f);
    #|pub fn[T] Array::iter(self : Array[T]) -> Iter[T] {
    #|  Iter::new(() => { None })
    #|}
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "demo.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: test_core_import_ref(),
        file_path: "core_iterable.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(json.contains("\"kind\":\"ForIn\""))
  assert_true(json.contains("Array::iter"))
  assert_true(json.contains("\"name\":\"def\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext contextually types Some in generic iterator lambda" {
  let source =
    #|fn first(xs : Array[Int]) -> Iter[Int] {
    #|  let mut index = 0
    #|  let len = xs.length()
    #|  Iter::new(() => {
    #|    if index >= len {
    #|      None
    #|    } else {
    #|      let item = xs.unsafe_get(index)
    #|      index = index + 1
    #|      Some(item)
    #|    }
    #|  })
    #|}
  let core_source =
    #|struct Iter[X] {
    #|  f : () -> X?
    #|}
    #|pub extern "csharp" fn[X] Iter::new(f : () -> X?) -> Iter[X] =
    #|  #| return new MoonBitIter<X>(f);
    #|pub extern "csharp" fn[T] Array::length(self : Array[T]) -> Int =
    #|  #| return self.Length;
    #|pub extern "csharp" fn[T] Array::unsafe_get(self : Array[T], index : Int) -> T =
    #|  #| return self[index];
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "demo.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: test_core_import_ref(),
        file_path: "core_iterable.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(json.contains("\"kind\":\"OptionSome\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext calls function-valued struct fields" {
  let source =
    #|struct Box {
    #|  f : () -> Int
    #|}
    #|fn call(box : Box) -> Int {
    #|  (box.f)()
    #|}
  let json = compile_test_source_to_json(source, "demo.mbt", "demo")
  assert_true(json.contains("\"kind\":\"FunctionValueCall\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext maps range loop operator variants to semantic flags" {
  let source = "struct Counter { mut val: Int }\nfn ranges()->Int { let counter : Counter = {val:0}; for a in 0..4 { counter.val = counter.val + a }; for b in 0..=4 { counter.val = counter.val + b }; for c in 0..<=4 { counter.val = counter.val + c }; for d in 4>..0 { counter.val = counter.val + d }; for e in 4>=..0 { counter.val = counter.val + e }; counter.val }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"name\":\"a\""))
  assert_true(json.contains("\"name\":\"b\""))
  assert_true(json.contains("\"name\":\"c\""))
  assert_true(json.contains("\"name\":\"d\""))
  assert_true(json.contains("\"name\":\"e\""))
  assert_true(json.contains("\"inclusive\":false,\"reverse\":false"))
  assert_true(json.contains("\"inclusive\":true,\"reverse\":false"))
  assert_true(
    json.contains("\"inclusive\":true,\"reverse\":true,\"excludeStart\":true"),
  )
  assert_true(
    json.contains("\"inclusive\":true,\"reverse\":true,\"excludeStart\":false"),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves function call and array result types" {
  let source = "fn add(a:Int, b:Int)->Int { a + b }\nfn call()->Int { add(1, 2) }\nfn array()->Array[Int] { [1, 2] }\nfn fixed()->FixedArray[Int] { [3, 4] }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Call\""))
  assert_true(json.contains("\"functionId\":\"fn:pkg:Demo:Demo:add\""))
  assert_true(json.contains("\"kind\":\"Apply\""))
  assert_true(json.contains("\"kind\":\"Builtin\",\"name\":\"Array\""))
  assert_true(json.contains("\"kind\":\"Builtin\",\"name\":\"FixedArray\""))
  assert_true(json.contains("\"kind\":\"IntLiteral\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext emits extern csharp functions as explicit ir facts" {
  let source = "extern \"csharp\" fn answer() -> Int =\n  #|return 42;\nfn call()->Int { answer() }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"name\":\"answer\""))
  assert_true(
    json.contains(
      "\"external\":{\"target\":\"csharp\",\"body\":\"return 42;\"}",
    ),
  )
  assert_true(json.contains("\"functionId\":\"fn:pkg:Demo:Demo:answer\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext collects raw multiline text after let initializer separator" {
  let source = "fn main()->String {\n  let source =\n    #| # Hello, MoonBit!\n    #| This is a sample markdown document.\n  source\n}\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"StringLiteral\""))
  assert_true(
    json.contains("# Hello, MoonBit!\\n This is a sample markdown document."),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext json writer escapes tab characters in strings" {
  let source = "fn main()->String { \" \\t\" }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\\t"))
  assert_false(json.contains(" \t"))
}

///|
test "vnext skips top-level test blocks for executable module parsing" {
  let source = "fn main()->Unit { () }\ntest \"sample\" {\n  let x : Int = 42\n  debug_inspect(x.to_string(), content=\"100\")\n}\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"name\":\"main\""))
  assert_false(json.contains("\"debug_inspect\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves prelude println as explicit extern csharp function" {
  let source = "fn main()->Unit { println(\"ok\") }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"name\":\"println\""))
  assert_true(json.contains("\"selectedIntrinsic\":\"%println\""))
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:println\"",
    ),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves generic println for bytes through Show evidence" {
  let source = "fn main()->Unit { println(b\"hello?\") }\n"
  let json = compile_test_source_to_json(source, "bytes_println.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"BytesLiteral\""))
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:println\"",
    ),
  )
  assert_true(
    json.contains("\"typeArgs\":[{\"kind\":\"Builtin\",\"name\":\"Bytes\"}]"),
  )
  assert_true(json.contains("\"traitEvidence\":[]"))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves contextual map literals" {
  let source = "fn literal()->Map[String, Int] { {\"a\":2, \"b\":3} }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"MapLiteral\""))
  assert_true(json.contains("\"entries\":["))
  assert_true(json.contains("\"kind\":\"StringLiteral\",\"value\":\"a\""))
  assert_true(json.contains("\"kind\":\"IntLiteral\",\"value\":\"2\""))
  assert_true(json.contains("\"kind\":\"Builtin\",\"name\":\"Map\""))
  assert_true(json.contains("\"kind\":\"Builtin\",\"name\":\"String\""))
  assert_true(json.contains("\"kind\":\"Builtin\",\"name\":\"Int\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves contextual empty map literals" {
  let source = "struct StoredDocument { source : String }\nlet documents : Map[Int, StoredDocument] = {}\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"MapLiteral\""))
  assert_true(json.contains("\"entries\":[]"))
  assert_true(json.contains("\"kind\":\"Builtin\",\"name\":\"Map\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext parses bool unit and parenthesized expressions without generated frontend" {
  let source = "fn yes()->Bool { true }\nfn no()->Bool { (false) }\nfn unit()->Unit { () }\nfn grouped()->Int { (1 + 2) }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"BoolLiteral\",\"value\":true"))
  assert_true(json.contains("\"kind\":\"BoolLiteral\",\"value\":false"))
  assert_true(json.contains("\"kind\":\"UnitLiteral\""))
  assert_true(json.contains("\"name\":\"grouped\""))
  assert_true(json.contains("\"kind\":\"Binary\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves imported generic struct literal through moon.pkg alias" {
  let imported_source = "pub(all) struct MyStruct[T]{\n  mut a: Array[T]\n}\n"
  let source = "let m : @my_pkg.MyStruct[Int] = {a:[2]}\n"
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "main.mbt", source }],
    "Main",
    "import {\n  \"my/pkg\" @my_pkg,\n}\n",
    "moon.pkg",
    [
      {
        import_ref: {
          alias_name: "my_pkg",
          package_id: "pkg:my/pkg",
          module_path: "my/pkg",
        },
        file_path: "my_pkg.mbt",
        source: imported_source,
      },
    ],
    test_core_declaration_sources([]),
  )
  assert_true(json.contains("\"types\":["))
  assert_true(json.contains("\"name\":\"MyStruct\""))
  assert_true(json.contains("\"typeParams\":[\"T\"]"))
  assert_true(json.contains("\"mutable\":true"))
  assert_true(json.contains("\"kind\":\"GlobalLet\""))
  assert_true(json.contains("\"kind\":\"StructLiteral\""))
  assert_false(json.contains("\"fieldId\""))
  assert_true(json.contains("\"kind\":\"Declared\""))
  assert_true(json.contains("\"packageId\":\"pkg:my/pkg\""))
  assert_true(json.contains("\"kind\":\"Apply\""))
  assert_true(json.contains("\"kind\":\"Builtin\",\"name\":\"Array\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext indexes declaration-only core override sources" {
  let source = "fn f(line : String) -> StringView { line.trim_end(chars=\" \") }\n"
  let core_source = "pub extern \"csharp\" fn String::trim_end(self : String, chars? : StringView) -> StringView =\n  #| return self.TrimEnd(chars.ToString().ToCharArray());\n"
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "main.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: {
          alias_name: "builtin",
          package_id: "pkg:moonbitlang/core/builtin",
          module_path: "moonbitlang/core/builtin",
        },
        file_path: "core_builtin_string_methods_csharp.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:String::trim_end\"",
    ),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves builtin string and stringview methods from core declarations" {
  let source =
    #|fn f(s : String, v : StringView) -> Bool {
    #|  let a = s.trim().to_string()
    #|  let b = s.view(start_offset=0, end_offset=1).to_owned()
    #|  let c = s.unsafe_substring(start=0, end=1)
    #|  let d = s.get_char(0)
    #|  let e = v.unsafe_get(0).to_int()
    #|  a.is_empty() || b.has_prefix("a") || c.has_suffix("b") || d is Some(_) || e == 1
    #|}
  let core_source =
    #|pub extern "csharp" fn UInt16::to_int(self : UInt16) -> Int =
    #|  #|return default!;
    #|pub extern "csharp" fn String::trim(self : String, chars? : StringView) -> StringView =
    #|  #|return default!;
    #|pub extern "csharp" fn String::view(self : String, start_offset? : Int, end_offset? : Int) -> StringView =
    #|  #|return default!;
    #|pub extern "csharp" fn String::unsafe_substring(self : String, start~ : Int, end~ : Int) -> String =
    #|  #|return default!;
    #|pub extern "csharp" fn String::get_char(self : String, idx : Int) -> Char? =
    #|  #|return default!;
    #|pub extern "csharp" fn String::is_empty(self : String) -> Bool =
    #|  #|return default!;
    #|pub extern "csharp" fn String::has_prefix(self : String, str : StringView) -> Bool =
    #|  #|return default!;
    #|pub extern "csharp" fn String::has_suffix(self : String, str : StringView) -> Bool =
    #|  #|return default!;
    #|pub extern "csharp" fn StringView::to_string(self : StringView) -> String =
    #|  #|return default!;
    #|pub extern "csharp" fn StringView::to_owned(self : StringView) -> String =
    #|  #|return default!;
    #|pub extern "csharp" fn StringView::unsafe_get(self : StringView, index : Int) -> UInt16 =
    #|  #|return default!;
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "main.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: {
          alias_name: "builtin",
          package_id: "pkg:moonbitlang/core/builtin",
          module_path: "moonbitlang/core/builtin",
        },
        file_path: "core_string_methods.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(json.contains("\"String::trim\""))
  assert_true(json.contains("\"String::view\""))
  assert_true(json.contains("\"String::unsafe_substring\""))
  assert_true(json.contains("\"String::get_char\""))
  assert_true(json.contains("\"StringView::unsafe_get\""))
  assert_true(json.contains("\"UInt16::to_int\""))
  assert_false(json.contains("unknown trait method"))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext using imports selected type and function names" {
  let imported_source = "pub(all) struct MyStruct[T]{\n  a: Array[T]\n}\npub fn make_int(a:Int)->Int { a }\n"
  let source = "using @my_pkg { type MyStruct, make_int }\nlet m : MyStruct[Int] = {a:[2]}\nfn call()->Int { make_int(1) }\n"
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "main.mbt", source }],
    "Main",
    "import {\n  \"my/pkg\" @my_pkg,\n}\n",
    "moon.pkg",
    [
      {
        import_ref: {
          alias_name: "my_pkg",
          package_id: "pkg:my/pkg",
          module_path: "my/pkg",
        },
        file_path: "my_pkg.mbt",
        source: imported_source,
      },
    ],
    test_core_declaration_sources([]),
  )
  assert_true(json.contains("\"kind\":\"GlobalLet\""))
  assert_true(json.contains("\"name\":\"MyStruct\""))
  assert_true(json.contains("\"packageId\":\"pkg:my/pkg\""))
  assert_true(json.contains("\"functionId\":\"fn:pkg:my/pkg:my/pkg:make_int\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves package-qualified imported function calls" {
  let imported_source = "pub fn make_int(a:Int)->Int { a }\n"
  let source = "fn call()->Int { @my_pkg.make_int(1) }\n"
  let json = compile_package_source_to_json(
    source,
    "main.mbt",
    "Main",
    "import {\n  \"my/pkg\" @my_pkg,\n}\n",
    "moon.pkg",
    [
      {
        import_ref: {
          alias_name: "my_pkg",
          package_id: "pkg:my/pkg",
          module_path: "my/pkg",
        },
        file_path: "my_pkg.mbt",
        source: imported_source,
      },
    ],
  )
  assert_true(json.contains("\"functionId\":\"fn:pkg:my/pkg:my/pkg:make_int\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves core char equality operators" {
  let source = "fn same(a : Char, b : Char)->Bool { a == b || a != '-' }\n"
  let json = compile_test_source_to_json(source, "main.mbt", "Main")
  assert_true(json.contains("\"selectedIntrinsic\":\"%char_eq\""))
  assert_true(json.contains("\"selectedIntrinsic\":\"%i32_ne\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext infers option literals in local match result" {
  let source = "enum Marker { A\nB }\nfn f(x : Int)->Marker? { let m = match x { 0 => Some(Marker::A) _ => None }; m }\n"
  let json = compile_test_source_to_json(source, "main.mbt", "Main")
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext supports wildcard discard local let" {
  let source = "fn side()->Int { 1 }\nfn f()->Int { let _ = side(); 2 }\n"
  let json = compile_test_source_to_json(source, "main.mbt", "Main")
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext package compilation emits imported implementation functions" {
  let imported_source = "pub fn make_int(a:Int)->Int { a + 1 }\n"
  let source = "fn call()->Int { @my_pkg.make_int(1) }\n"
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "main.mbt", source }],
    "Main",
    "import {\n  \"my/pkg\" @my_pkg,\n}\n",
    "moon.pkg",
    [
      {
        import_ref: {
          alias_name: "my_pkg",
          package_id: "pkg:my/pkg",
          module_path: "my/pkg",
        },
        file_path: "my_pkg.mbt",
        source: imported_source,
      },
    ],
    test_core_declaration_sources([]),
  )
  assert_true(json.contains("\"name\":\"make_int\""))
  assert_true(json.contains("\"name\":\"call\""))
  assert_true(json.contains("\"functionId\":\"fn:pkg:my/pkg:my/pkg:make_int\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext package compilation keeps mbti functions as signatures only" {
  let imported_source = "package \"my/pkg\"\n\npub fn make_int(Int) -> Int\n"
  let source = "fn call()->Int { @my_pkg.make_int(1) }\n"
  let json = compile_package_source_to_json(
    source,
    "main.mbt",
    "Main",
    "import {\n  \"my/pkg\" @my_pkg,\n}\n",
    "moon.pkg",
    [
      {
        import_ref: {
          alias_name: "my_pkg",
          package_id: "pkg:my/pkg",
          module_path: "my/pkg",
        },
        file_path: "pkg.generated.mbti",
        source: imported_source,
      },
    ],
  )
  assert_true(json.contains("\"functionId\":\"fn:pkg:my/pkg:my/pkg:make_int\""))
  assert_false(json.contains("\"name\":\"make_int\",\"params\""))
  assert_true(json.contains("\"name\":\"call\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves unaliased mbti package functions and returned struct fields" {
  let imported_source = "package \"mizchi/markdown\"\n\npub(all) struct Document {\n  children : Array[String]\n}\n\npub(all) struct ParseResult {\n  document : Document\n}\n\npub fn parse(String, strict? : Bool, wikilinks? : Bool) -> ParseResult\npub fn render_html(Document, autolink? : Bool) -> String\n"
  let source = "fn main()->String { let result = @markdown.parse(\"# hi\"); @markdown.render_html(result.document) }\n"
  let json = compile_package_source_to_json(
    source,
    "main.mbt",
    "Main",
    "import {\n  \"mizchi/markdown\",\n}\n",
    "moon.pkg",
    [
      {
        import_ref: {
          alias_name: "markdown",
          package_id: "pkg:mizchi/markdown",
          module_path: "mizchi/markdown",
        },
        file_path: "pkg.generated.mbti",
        source: imported_source,
      },
    ],
  )
  assert_true(json.contains("\"packageId\":\"pkg:mizchi/markdown\""))
  assert_true(json.contains("\"name\":\"ParseResult\""))
  assert_true(json.contains("\"name\":\"document\""))
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:mizchi/markdown:mizchi/markdown:parse\"",
    ),
  )
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:mizchi/markdown:mizchi/markdown:render_html\"",
    ),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves package-qualified and using-imported globals" {
  let imported_source = "pub let default_value : Int = 42\n"
  let source = "using @my_pkg { default_value }\nfn qualified()->Int { @my_pkg.default_value }\nfn imported()->Int { default_value }\n"
  let json = compile_package_source_to_json(
    source,
    "main.mbt",
    "Main",
    "import {\n  \"my/pkg\" @my_pkg,\n}\n",
    "moon.pkg",
    [
      {
        import_ref: {
          alias_name: "my_pkg",
          package_id: "pkg:my/pkg",
          module_path: "my/pkg",
        },
        file_path: "my_pkg.mbt",
        source: imported_source,
      },
    ],
  )
  assert_true(
    json.contains("\"symbolId\":\"global:pkg:my/pkg:my/pkg:default_value\""),
  )
  assert_true(json.contains("\"name\":\"qualified\""))
  assert_true(json.contains("\"name\":\"imported\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves static receiver function aliases from interface declarations" {
  let source = "fn make()->Ref[Int] { Ref::new(1) }\n"
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "main.mbt", source }],
    "Main",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: {
          alias_name: "ref",
          package_id: "pkg:moonbitlang/core/ref",
          module_path: "moonbitlang/core/ref",
        },
        file_path: "ref.pkg.generated.mbti",
        source: "package \"moonbitlang/core/ref\"\npub(all) struct Ref[T] { mut val : T }\n#alias(new, deprecated)\npub fn[T] Ref::Ref(T) -> Self[T]\n",
      },
    ]),
  )
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:moonbitlang/core/ref:moonbitlang/core/ref:Ref::Ref\"",
    ),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext supports float literal, implicit view conversions, and lazy local struct typing" {
  let source = "struct MyStruct { val: Int }\nfn float_id(f:Float)->Float { f }\nfn call_float()->Float { float_id(1.0) }\nfn view(s:StringView)->StringView { s }\nfn call_view()->StringView { view(\"x\") }\nfn array_view(a:ArrayView[Int])->ArrayView[Int] { a }\nfn call_array_view()->ArrayView[Int] { array_view([1]) }\nfn fixed()->FixedArray[Int] { [2] }\nfn call_fixed_view()->ArrayView[Int] { array_view(fixed()) }\nfn make()->MyStruct { let s = {val:2}; s }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"FloatLiteral\",\"value\":\"1.0\""))
  assert_true(json.contains("\"kind\":\"StringLiteral\",\"value\":\"x\""))
  assert_true(json.contains("\"conversion\":\"StringToStringView\""))
  assert_true(json.contains("\"conversion\":\"ArrayToArrayView\""))
  assert_true(json.contains("\"conversion\":\"FixedArrayToArrayView\""))
  assert_true(json.contains("\"kind\":\"LocalLet\""))
  assert_true(json.contains("\"kind\":\"StructLiteral\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves generic receiver fields after type substitution" {
  let source = "struct Box[T] { mut value: T }\nfn read(box:Box[Int])->Int { box.value }\nfn write(box:Box[Int])->Unit { box.value = 3 }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"FieldAccess\""))
  assert_true(json.contains("\"kind\":\"FieldAssign\""))
  assert_true(
    json.contains("\"fieldId\":\"type:pkg:Demo:Demo:Box:field:value\""),
  )
  assert_true(json.contains("\"kind\":\"Builtin\",\"name\":\"Int\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves declared generic types before builtin names" {
  let source = "struct Map[K, V] { value: V }\nfn read(m:Map[Int, String])->String { m.value }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Declared\""))
  assert_true(json.contains("\"name\":\"Map\""))
  assert_true(json.contains("\"kind\":\"FieldAccess\""))
  assert_true(json.contains("\"kind\":\"Builtin\",\"name\":\"String\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves custom alias indexer functions through callable selection" {
  let source = "struct Cell { mut value: Int }\n#alias(\"_[_]\")\nfn Cell::get(self:Cell, index:Int)->Int { self.value + index }\n#alias(\"_[_]=_\")\nfn Cell::set(self:Cell, index:Int, value:Int)->Unit { self.value = index + value }\nfn read(cell:Cell)->Int { cell[2] }\nfn write(cell:Cell)->Unit { cell[1] = 9 }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"functionId\":\"fn:pkg:Demo:Demo:Cell::get\""))
  assert_true(json.contains("\"functionId\":\"fn:pkg:Demo:Demo:Cell::set\""))
  assert_true(json.contains("\"kind\":\"Call\""))
  assert_false(json.contains("\"kind\":\"IndexGet\""))
  assert_false(json.contains("\"kind\":\"IndexAssign\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext parses braced block expressions without losing struct and map literals" {
  let source = "struct Box { val: Int }\nfn rank(x:Int)->Int { match x { 1 => { let y = 2; y } _ => 0 } }\nfn local()->Int { let v = { let x = 3; x }; v }\nfn make()->Box { {val:2} }\nfn map()->Map[String, Int] { {\"a\":2} }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"name\":\"rank\""))
  assert_true(json.contains("\"kind\":\"Match\""))
  assert_true(json.contains("\"kind\":\"LocalLet\""))
  assert_true(json.contains("\"kind\":\"StructLiteral\""))
  assert_true(json.contains("\"kind\":\"MapLiteral\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves unary minus through operator intrinsics" {
  let source = "fn neg_one()->Int { -1 }\nfn neg(x:Int)->Int { -x }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Unary\""))
  assert_true(json.contains("\"op\":\"-\""))
  assert_true(json.contains("\"selectedIntrinsic\":\"%i32_neg\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext infers generic function calls from arguments and expected return type" {
  let source = "fn[T] id(x:T)->T { x }\nfn call_int()->Int { id(1) }\nfn call_view()->StringView { id(\"x\") }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(
    json.contains(
      "\"name\":\"id\",\"isPublic\":false,\"typeParams\":[{\"name\":\"T\"",
    ),
  )
  assert_true(json.contains("\"functionId\":\"fn:pkg:Demo:Demo:id\""))
  assert_true(json.contains("\"name\":\"call_int\""))
  assert_true(json.contains("\"kind\":\"Builtin\",\"name\":\"Int\""))
  assert_true(json.contains("\"conversion\":\"StringToStringView\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext infers generic option receiver methods" {
  let source =
    #|fn unwrap_char(c : Char?) -> Char { c.unwrap() }
    #|fn unwrap_or_space(c : Char?) -> Char { c.unwrap_or(' ') }
  let core_source =
    #|pub extern "csharp" fn[T] Option::unwrap(self : T?) -> T =
    #|  #|return default!;
    #|pub extern "csharp" fn[T] Option::unwrap_or(self : T?, default : T) -> T =
    #|  #|return default!;
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "main.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: test_core_import_ref(),
        file_path: "core_option.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(json.contains("\"Option::unwrap\""))
  assert_true(json.contains("\"Option::unwrap_or\""))
  assert_true(json.contains("\"kind\":\"Builtin\",\"name\":\"Char\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext infers generic array receiver methods with expected lambda" {
  let source =
    #|fn sort_values(values : Array[(Int, String)]) -> Unit {
    #|  let sorted = values.copy()
    #|  sorted.sort_by(fn(a, b) { a.0.compare(b.0) })
    #|}
  let core_source =
    #|pub extern "csharp" fn[T] Array::copy(self : Array[T]) -> Array[T] =
    #|  #|return default!;
    #|pub extern "csharp" fn[T] Array::sort_by(self : Array[T], cmp : (T, T) -> Int) -> Unit =
    #|  #|return default!;
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "main.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: test_core_import_ref(),
        file_path: "core_array.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(json.contains("\"Array::copy\""))
  assert_true(json.contains("\"Array::sort_by\""))
  assert_true(json.contains("\"kind\":\"Lambda\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext keeps array receiver candidate when lambda uses default not_equal" {
  let source =
    #|fn non_empty(value : String) -> Array[String] {
    #|  let lines = [value]
    #|  lines.filter(line => line != "")
    #|}
  let core_source =
    #|pub extern "csharp" fn[T] Array::filter(self : Array[T], f : (T) -> Bool) -> Array[T] =
    #|  #|return default!;
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "main.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: test_core_import_ref(),
        file_path: "core_array.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(json.contains("\"Array::filter\""))
  assert_true(
    json.contains(
      "\"selectedFunctionId\":\"default-trait:type:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Eq:not_equal\"",
    ),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves iter receiver methods across declared and builtin core type shapes" {
  let source =
    #|fn indent(pre_lines : ArrayView[String]) -> Iter[String] {
    #|  pre_lines.iter().map(line => line)
    #|}
  let core_source =
    #|struct Iter[X] {
    #|  f : () -> X?
    #|  mut size_hint : Int?
    #|}
    #|pub fn[T] ArrayView::iter(self : ArrayView[T]) -> Iter[T] = "%arrayview_iter"
    #|pub fn[X, Y] Iter::map(self : Iter[X], f : (X) -> Y) -> Iter[Y] = "%iter_map"
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "main.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: test_core_import_ref(),
        file_path: "core_iterable.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:ArrayView::iter\"",
    ),
  )
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Iter::map\"",
    ),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext accepts iter spread in array literals" {
  let source =
    #|fn indent(pre_lines : ArrayView[String]) -> Array[String] {
    #|  [..pre_lines.iter().map(line => line)]
    #|}
  let core_source =
    #|struct Iter[X] {
    #|  f : () -> X?
    #|  mut size_hint : Int?
    #|}
    #|pub fn[T] ArrayView::iter(self : ArrayView[T]) -> Iter[T] = "%arrayview_iter"
    #|pub fn[X, Y] Iter::map(self : Iter[X], f : (X) -> Y) -> Iter[Y] = "%iter_map"
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "main.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: test_core_import_ref(),
        file_path: "core_iterable.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(json.contains("\"kind\":\"Spread\""))
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Iter::map\"",
    ),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext uses array to arrayview conversion for function call results" {
  let source =
    #|fn lines() -> Array[String] {
    #|  []
    #|}
    #|fn take(lines : ArrayView[String]) -> Unit {
    #|  ()
    #|}
    #|fn run() -> Unit {
    #|  take(lines())
    #|}
  let json = compile_test_source_to_json(source, "main.mbt", "Demo")
  assert_true(json.contains("\"functionId\":\"fn:pkg:Demo:Demo:take\""))
  assert_true(json.contains("\"conversion\":\"ArrayToArrayView\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext solves generic arrayview parameter from function call result" {
  let source =
    #|fn lines() -> Array[String] {
    #|  []
    #|}
    #|fn[T] take(lines : ArrayView[T]) -> Unit {
    #|  ()
    #|}
    #|fn run() -> Unit {
    #|  take(lines())
    #|}
  let json = compile_test_source_to_json(source, "main.mbt", "Demo")
  assert_true(json.contains("\"functionId\":\"fn:pkg:Demo:Demo:take\""))
  assert_true(json.contains("\"conversion\":\"ArrayToArrayView\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext solves empty local array from append argument result" {
  let source =
    #|fn lines() -> Array[String] {
    #|  []
    #|}
    #|fn run() -> Array[String] {
    #|  let xs = []
    #|  xs.append(lines())
    #|  xs
    #|}
  let core_source =
    #|pub fn[T] Array::append(self : Array[T], other : ArrayView[T]) -> Unit = "%array_append"
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "main.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: test_core_import_ref(),
        file_path: "core_array.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(json.contains("\"conversion\":\"ArrayToArrayView\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves generic local call return from later body constraints" {
  let source =
    #|pub extern "csharp" fn[T] Array::make_uninit(len : Int) -> Array[T] =
    #|  #|return default!;
    #|pub extern "csharp" fn[T] Array::unsafe_set(self : Array[T], index : Int, value : T) -> Unit =
    #|  #|return default!;
    #|fn[T] make(len : Int, elem : T) -> Array[T] {
    #|  let arr = Array::make_uninit(len)
    #|  for i in 0..<len {
    #|    arr.unsafe_set(i, elem)
    #|  }
    #|  arr
    #|}
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(
    json.contains("\"functionId\":\"fn:pkg:Demo:Demo:Array::make_uninit\""),
  )
  assert_false(json.contains("infer:call:T"))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext emits trait declarations, trait object types, and generic constraints" {
  let source = "trait Animal { speak(Self) -> String }\nfn[T : Animal] keep(x:T)->T { x }\nfn[T : Animal] speak_bound(x:T)->String { x.speak() }\nfn animal(a:&Animal)->String { a.speak() }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"traits\":["))
  assert_true(json.contains("\"kind\":\"Trait\""))
  assert_true(json.contains("\"name\":\"Animal\""))
  assert_true(json.contains("\"methods\":[{\"name\":\"speak\""))
  assert_true(json.contains("\"kind\":\"Builtin\",\"name\":\"Self\""))
  assert_true(json.contains("\"constraints\":[\"Animal\"]"))
  assert_true(json.contains("\"kind\":\"TraitObject\""))
  assert_true(json.contains("\"name\":\"animal\""))
  assert_true(json.contains("\"kind\":\"TraitMethodCall\""))
  assert_true(json.contains("\"kind\":\"TypeParamBound\""))
  assert_true(json.contains("\"implTypeParam\":\"TAnimalImpl\""))
  assert_true(json.contains("\"kind\":\"TraitObject\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves generic equality operators through trait constraints" {
  let source = "trait Eq { equal(Self, Self) -> Bool }\nfn[K : Eq] same(left : K, right : K) -> Bool { left == right }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"TraitMethodCall\""))
  assert_true(json.contains("\"name\":\"equal\""))
  assert_true(json.contains("\"kind\":\"TypeParamBound\""))
  assert_true(json.contains("\"implTypeParam\":\"KEqImpl\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves generic receiver equality operators through trait constraints" {
  let source = "trait Eq { equal(Self, Self) -> Bool }\nstruct Box[K] { key : K }\nfn[K : Eq] Box::same(self : Box[K], key : K) -> Bool { self.key == key }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"TraitMethodCall\""))
  assert_true(json.contains("\"name\":\"equal\""))
  assert_true(json.contains("\"kind\":\"TypeParamBound\""))
  assert_true(json.contains("\"implTypeParam\":\"KEqImpl\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves concrete intrinsic trait methods" {
  let source = "trait Flip { flip(Self) -> Self }\nimpl Flip for Int with flip(self) = \"%i32_neg\"\nfn call(a:Int)->Int { a.flip() }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"TraitMethodCall\""))
  assert_true(json.contains("\"kind\":\"ConcreteImpl\""))
  assert_true(json.contains("\"selectedIntrinsic\":\"%i32_neg\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext emits selected local operator impl body" {
  let source = "struct Pair { a : Int; b : Int }\nimpl Add for Pair with add(self, other) { { a: self.a + other.a, b: self.b + other.b } }\nfn call(x:Pair, y:Pair)->Pair { x + y }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"name\":\"add\""))
  assert_true(
    json.contains(
      "\"selectedFunctionId\":\"fn:pkg:Demo:Demo:impl:moonbitlang/core/builtin:Add:Pair:add\"",
    ),
  )
  assert_true(
    json.contains(
      "\"symbolId\":\"fn:pkg:Demo:Demo:impl:moonbitlang/core/builtin:Add:Pair:add\"",
    ),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext emits selected package path operator impl body" {
  let source = "struct ContentParens { size : Int; lines : Array[String] }\nimpl Add for ContentParens with add(self, other) { { size: self.size + other.size, lines: self.lines + other.lines } }\nfn call(x:ContentParens, y:ContentParens)->ContentParens { x + y }\n"
  let json = compile_test_source_to_json(
    source, "printer.mbt", "moonbitlang/core/debug",
  )
  assert_true(
    json.contains(
      "\"selectedFunctionId\":\"fn:pkg:moonbitlang/core/debug:moonbitlang/core/debug:impl:moonbitlang/core/builtin:Add:ContentParens:add\"",
    ),
  )
  assert_true(
    json.contains(
      "\"symbolId\":\"fn:pkg:moonbitlang/core/debug:moonbitlang/core/debug:impl:moonbitlang/core/builtin:Add:ContentParens:add\"",
    ),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext selected callable emits final argument diagnostics after probe" {
  let source = "fn[T] id(x:T)->T { x }\nfn call()->Int { id(missing) }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"functionId\":\"fn:pkg:Demo:Demo:id\""))
  assert_true(json.contains("\"code\":\"VNX1100\""))
  assert_false(json.contains("\"code\":\"VNX1201\""))
}

///|
test "vnext supports option type sugar and optional parameter model" {
  let source = "fn some()->Int? { Some(1) }\nfn none()->Int? { None }\nfn takes(a:Int?)->Int? { a }\nfn question(a?:Int)->Int? { a }\nfn call_question()->Int? { question() }\nfn call_question_given()->Int? { let a = 1; question(a~) }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Apply\""))
  assert_true(json.contains("\"kind\":\"Builtin\",\"name\":\"Option\""))
  assert_true(json.contains("\"kind\":\"OptionSome\""))
  assert_true(json.contains("\"kind\":\"OptionNone\""))
  assert_true(json.contains("\"name\":\"takes\""))
  assert_true(json.contains("\"name\":\"question\""))
  assert_true(json.contains("\"label\":\"a\""))
  assert_true(json.contains("\"optional\":true"))
  assert_true(json.contains("\"functionId\":\"fn:pkg:Demo:Demo:question\""))
  assert_true(json.contains("\"kind\":\"OptionNone\""))
  assert_true(json.contains("\"name\":\"call_question_given\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext lowers default labelled parameter expressions at omitted call sites" {
  let source = "let default_value : Int = 42\nfn optional(opt? : Int = default_value) -> Int { opt }\nfn call_default()->Int { optional() }\nfn call_default_given()->Int { optional(opt=0) }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(
    json.contains(
      "\"name\":\"opt\",\"label\":\"opt\",\"optional\":true,\"hasDefault\":true",
    ),
  )
  assert_true(json.contains("\"name\":\"optional\""))
  assert_true(json.contains("\"name\":\"call_default\""))
  assert_true(json.contains("\"kind\":\"GlobalLet\""))
  assert_true(
    json.contains("\"symbolId\":\"global:pkg:Demo:Demo:default_value\""),
  )
  assert_true(json.contains("\"name\":\"call_default_given\""))
  assert_true(json.contains("\"kind\":\"IntLiteral\",\"value\":\"0\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext supports mutable field assignment and default expression call-site lowering" {
  let source = "struct Counter { mut val: Int }\nfn incr(counter? : Counter = {val:0}) -> Int { counter.val = counter.val + 1; counter.val }\nfn call_default()->Int { incr() }\nfn call_given()->Int { let counter : Counter = {val:0}; incr(counter~) }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"name\":\"Counter\""))
  assert_true(json.contains("\"mutable\":true"))
  assert_true(json.contains("\"kind\":\"FieldAssign\""))
  assert_true(json.contains("\"kind\":\"FieldAccess\""))
  assert_true(json.contains("\"kind\":\"Sequence\""))
  assert_true(json.contains("\"kind\":\"StructLiteral\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext supports generic mutable struct default and shared global default" {
  let source = "struct Ref[T] { mut val: T }\nfn incr(counter? : Ref[Int] = { val: 0 }) -> Ref[Int] { counter.val = counter.val + 1; counter }\nlet default_counter : Ref[Int] = { val: 0 }\nfn incr_2(counter? : Ref[Int] = default_counter) -> Int { counter.val = counter.val + 1; counter.val }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"name\":\"Ref\""))
  assert_true(json.contains("\"typeParams\":[\"T\"]"))
  assert_true(json.contains("\"name\":\"val\",\"mutable\":true"))
  assert_true(json.contains("\"name\":\"default_counter\""))
  assert_true(
    json.contains("\"symbolId\":\"global:pkg:Demo:Demo:default_counter\""),
  )
  assert_true(json.contains("\"name\":\"incr\""))
  assert_true(json.contains("\"name\":\"incr_2\""))
  assert_true(json.contains("\"kind\":\"FieldAssign\""))
  assert_true(json.contains("\"kind\":\"FieldAccess\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext supports labelled parameter and shorthand argument syntax" {
  let source = "fn labelled_1(arg1~ : Int, arg2~ : Int) -> Int { arg1 + arg2 }\nfn call_labelled() -> Int { let arg1 = 1; labelled_1(arg2=2, arg1~) }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"name\":\"arg1\",\"label\":\"arg1\""))
  assert_true(json.contains("\"name\":\"arg2\",\"label\":\"arg2\""))
  assert_true(json.contains("\"functionId\":\"fn:pkg:Demo:Demo:labelled_1\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext rejects duplicate labelled call arguments during call planning" {
  let source = "fn labelled_1(arg1~ : Int) -> Int { arg1 }\nfn call_labelled() -> Int { labelled_1(arg1=1, arg1=2) }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"code\":\"VNX1201\""))
  assert_false(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext local lookup uses innermost shadowing binding" {
  let source = "fn shadow(x:Int)->Int { let x = 2; x }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"LocalLet\""))
  assert_true(json.contains("\"kind\":\"IntLiteral\",\"value\":\"2\""))
  assert_true(json.contains("\"symbolId\":\"local:fn:pkg:Demo:Demo:shadow:"))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext rejects local let without statement separator" {
  let source = "struct MyStruct { val: Int }\nfn make()->MyStruct { let s = {val:2} s }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"code\":\"VNX0101\""))
  assert_true(json.contains("\"span\":{\"file\":\"demo.mbt\""))
}

///|
test "vnext resolves constant enum declaration and case expression" {
  let source = "enum Relation {\n  Smaller\n  Greater\n  Equal\n}\nfn smaller()->Relation { Relation::Smaller }\nfn inferred()->Relation { Smaller }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Enum\""))
  assert_true(json.contains("\"name\":\"Relation\""))
  assert_true(json.contains("\"name\":\"Smaller\""))
  assert_true(json.contains("\"name\":\"Greater\""))
  assert_true(json.contains("\"name\":\"Equal\""))
  assert_true(json.contains("\"kind\":\"EnumCase\""))
  assert_true(
    json.contains(
      "\"variantId\":\"type:pkg:Demo:Demo:Relation:variant:Smaller\"",
    ),
  )
  assert_true(json.contains("\"name\":\"inferred\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves constant enum match patterns" {
  let source = "enum Relation {\n  Smaller\n  Greater\n}\nfn rank(r:Relation)->Int { match r { Smaller => 1 Greater => 2 } }\nfn rank_qualified(r:Relation)->Int { match r { Relation::Smaller => 1 _ => 0 } }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Match\""))
  assert_true(json.contains("\"pattern\":{\"kind\":\"EnumCase\""))
  assert_true(
    json.contains(
      "\"variantId\":\"type:pkg:Demo:Demo:Relation:variant:Smaller\"",
    ),
  )
  assert_true(json.contains("\"pattern\":{\"kind\":\"Wildcard\"}"))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves payload enum match bindings" {
  let source = "enum Lst {\n  Nil\n  Cons(Int, Lst)\n}\nfn head(xs:Lst)->Int { match xs { Cons(x, _) => x Nil => 0 } }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Match\""))
  assert_true(
    json.contains("\"variantId\":\"type:pkg:Demo:Demo:Lst:variant:Cons\""),
  )
  assert_true(json.contains("\"payloads\":["))
  assert_true(json.contains("\"kind\":\"Binding\""))
  assert_true(json.contains("\"name\":\"x\""))
  assert_true(json.contains("\"kind\":\"Wildcard\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves literal match patterns" {
  let source = "fn int_rank(x:Int)->Int { match x { 0 => 10 1 => 11 _ => 12 } }\nfn bool_rank(x:Bool)->Int { match x { true => 1 false => 0 } }\nfn string_rank(x:String)->Int { match x { \"a\" => 1 _ => 0 } }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Match\""))
  assert_true(json.contains("\"kind\":\"IntLiteral\",\"value\":\"0\""))
  assert_true(json.contains("\"kind\":\"BoolLiteral\",\"value\":true"))
  assert_true(json.contains("\"kind\":\"StringLiteral\",\"value\":\"a\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves range match patterns" {
  let source = "fn rank(x:Int)->Int { match x {\n  ..=0 => 1\n  1..<4 => 2\n  4.. => 3\n  _ => 0\n} }\nfn small(x:Int)->Bool { x is -3..=3 }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Range\""))
  assert_true(json.contains("\"start\":null,\"end\":\"0\",\"inclusive\":true"))
  assert_true(
    json.contains("\"start\":\"1\",\"end\":\"4\",\"inclusive\":false"),
  )
  assert_true(json.contains("\"start\":\"4\",\"end\":null,\"inclusive\":false"))
  assert_true(
    json.contains("\"start\":\"-3\",\"end\":\"3\",\"inclusive\":true"),
  )
  assert_true(json.contains("\"kind\":\"IsPattern\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves option match patterns" {
  let source = "fn value(x:Int?)->Int { match x { Some(v) => v None => 0 } }\nfn one(x:Int?)->Int { match x { Some(1) => 10 Some(_) => 1 None => 0 } }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"OptionSome\""))
  assert_true(json.contains("\"kind\":\"OptionNone\""))
  assert_true(json.contains("\"kind\":\"Binding\""))
  assert_true(json.contains("\"kind\":\"IntLiteral\",\"value\":\"1\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves tuple match patterns" {
  let source = "fn pick(pair:(Int, Int))->Int { match pair {\n  (0, y) => y\n  (x, _) => x\n} }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Match\""))
  assert_true(json.contains("\"pattern\":{\"kind\":\"Tuple\""))
  assert_true(
    json.contains("\"items\":[{\"kind\":\"IntLiteral\",\"value\":\"0\""),
  )
  assert_true(json.contains("\"kind\":\"Binding\""))
  assert_true(json.contains("\"name\":\"y\""))
  assert_true(json.contains("\"name\":\"x\""))
  assert_true(json.contains("\"kind\":\"Tuple\",\"items\":["))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves array match patterns" {
  let source = "fn pick(xs:FixedArray[Int])->Int { match xs {\n  [] => 0\n  [x] => x\n  [x, y] => x + y\n  _ => 99\n} }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Match\""))
  assert_true(json.contains("\"pattern\":{\"kind\":\"Array\""))
  assert_true(json.contains("\"items\":[]"))
  assert_true(json.contains("\"kind\":\"Binding\""))
  assert_true(json.contains("\"name\":\"x\""))
  assert_true(json.contains("\"name\":\"y\""))
  assert_true(json.contains("\"kind\":\"Builtin\",\"name\":\"FixedArray\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext lowers pipe syntax through normal call resolution" {
  let source = "fn add(a:Int, b:Int)->Int { a + b }\nfn forward()->Int { 1 |> add(5) }\nfn backward()->Int { add(1) <| 5 }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"name\":\"forward\""))
  assert_true(json.contains("\"name\":\"backward\""))
  assert_true(json.contains("\"functionId\":\"fn:pkg:Demo:Demo:add\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext binds boolean guard as early return statement ir" {
  let source = "fn guarded(ok:Bool, value:Int)->Int {\n  guard ok else { -1 }\n  value\n}\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Guard\""))
  assert_true(json.contains("\"condition\":{\"kind\":\"Name\""))
  assert_true(json.contains("\"else\":{\"kind\":\"Unary\",\"op\":\"-\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext binds guard break without forcing function return type" {
  let source = "fn guarded_loop()->Unit {\n  for i = 0; i < 10; i = i + 1 {\n    guard i < 5 else { break }\n  }\n}\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Guard\""))
  assert_true(json.contains("\"kind\":\"Break\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext keeps guard pattern bindings in following sequence" {
  let source = "enum Inline {\n  Text(content~ : String, span~ : Int)\n  Other\n}\nfn text_or_empty(inline:Inline)->String {\n  guard inline is Text(content~, span~) else { return \"\" }\n  guard span > 0 else { return content }\n  content\n}\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Guard\""))
  assert_true(json.contains("\"name\":\"content\""))
  assert_true(json.contains("\"name\":\"span\""))
  assert_true(json.contains("\"selectedIntrinsic\":\"%i32.gt\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext context types char literals for UInt16 string code units" {
  let source = "fn is_space(s:String)->Bool { s.unsafe_get(0) == ' ' }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(
    json.contains(
      "\"selectedFunctionId\":\"fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:impl:Eq:UInt16:equal\"",
    ),
  )
  assert_true(
    json.contains(
      "\"kind\":\"CharLiteral\",\"value\":\" \",\"type\":{\"kind\":\"Builtin\",\"name\":\"UInt16\"}",
    ),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext accepts char literal match and is patterns for UInt16 code units" {
  let source =
    #|fn classify(ch:UInt16)->Int {
    #|  match ch {
    #|    '.' => 1
    #|    ':' => 2
    #|    _ => 0
    #|  }
    #|}
    #|fn is_punct(ch:UInt16)->Bool { ch is ('.' | ':') }
    #|fn is_exponent(ch:UInt16)->Bool { ch is ('e' | 'E' | 'p' | 'P') }
    #|fn is_sign(ch:UInt16)->Bool { ch is ('+' | '-') }
    #|
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Match\""))
  assert_true(json.contains("\"kind\":\"IsPattern\""))
  assert_true(json.contains("\"kind\":\"CharLiteral\",\"value\":\".\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext accepts char literal match on string index code units" {
  let source =
    #|fn escape(value : String) -> Unit {
    #|  let ch = value[0]
    #|  match ch {
    #|    '"' => ()
    #|    '\\' => ()
    #|    '\n' => ()
    #|    '\r' => ()
    #|    '\t' => ()
    #|    _ => ()
    #|  }
    #|}
    #|
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Match\""))
  assert_true(json.contains("\"kind\":\"IndexGet\""))
  assert_true(
    json.contains(
      "\"name\":\"ch\",\"type\":{\"kind\":\"Builtin\",\"name\":\"UInt16\"}",
    ),
  )
  assert_true(json.contains("\"kind\":\"CharLiteral\",\"value\":\"\\\"\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves tuple literals and tuple destructuring locals" {
  let source = "fn pick()->Int {\n  let (a, _, b) = (1, 2, 3)\n  a + b\n}\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"TupleLiteral\""))
  assert_true(json.contains("\"kind\":\"TupleGet\""))
  assert_true(json.contains("\"name\":\"a\""))
  assert_true(json.contains("\"name\":\"b\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves array index get and set" {
  let source = "fn pick(xs:FixedArray[Int])->Int { xs[1] }\nfn set(xs:FixedArray[Int])->Unit { xs[0] = 3 }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"IndexGet\""))
  assert_true(json.contains("\"kind\":\"IndexAssign\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves bytes literal receiver and index assignment" {
  let source = "fn main { let b = b\"hello?\"; let array = b.unsafe_to_bytesArray(); array[5] = 1.to_byte() }\nfn Bytes::unsafe_to_bytesArray(bytes : Bytes) -> FixedArray[Byte] = \"%identity\"\nfn Int::to_byte(self : Int) -> Byte = \"%i32_to_byte\"\n"
  let json = compile_test_source_to_json(source, "bytes_literal.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"BytesLiteral\""))
  assert_true(json.contains("\"kind\":\"Builtin\",\"name\":\"Bytes\""))
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:Demo:Demo:Bytes::unsafe_to_bytesArray\"",
    ),
  )
  assert_true(json.contains("\"kind\":\"IndexAssign\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves or match patterns" {
  let source = "enum Relation {\n  Smaller\n  Greater\n  Equal\n}\nenum Lst {\n  Nil\n  Cons(Int, Lst)\n}\nfn f(r:Relation)->Int { match r {\n  Smaller | Equal => 1\n  Greater => 2\n} }\nfn g(x:Int)->Int { match x {\n  0 | 1 => 10\n  _ => 0\n} }\nfn h(xs:Lst)->Int { match xs {\n  Nil | Cons(0, _) => 42\n  Cons(x, _) => x\n} }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Or\""))
  assert_true(json.contains("\"alternatives\":["))
  assert_true(
    json.contains(
      "\"variantId\":\"type:pkg:Demo:Demo:Relation:variant:Smaller\"",
    ),
  )
  assert_true(
    json.contains("\"variantId\":\"type:pkg:Demo:Demo:Relation:variant:Equal\""),
  )
  assert_true(
    json.contains("\"variantId\":\"type:pkg:Demo:Demo:Lst:variant:Nil\""),
  )
  assert_true(
    json.contains("\"variantId\":\"type:pkg:Demo:Demo:Lst:variant:Cons\""),
  )
  assert_true(json.contains("\"kind\":\"IntLiteral\",\"value\":\"0\""))
  assert_true(json.contains("\"kind\":\"IntLiteral\",\"value\":\"1\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves match arm conditions" {
  let source = "fn f(x:Int, keep:Bool)->Int { match x {\n  y if keep => y\n  _ => 0\n} }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Match\""))
  assert_true(json.contains("\"condition\":{\"kind\":\"Name\""))
  assert_true(json.contains("\"name\":\"keep\""))
  assert_true(json.contains("\"kind\":\"Binding\""))
  assert_true(json.contains("\"name\":\"y\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves is pattern expressions" {
  let source = "enum Relation {\n  Smaller\n  Greater\n}\nfn is_small(r:Relation)->Bool { r is Smaller }\nfn is_one(x:Int)->Bool { x is 1 }\nfn is_single(xs:FixedArray[Int])->Bool { xs is [x] }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"IsPattern\""))
  assert_true(json.contains("\"pattern\":{\"kind\":\"EnumCase\""))
  assert_true(json.contains("\"kind\":\"IntLiteral\",\"value\":\"1\""))
  assert_true(json.contains("\"pattern\":{\"kind\":\"Array\""))
  assert_true(json.contains("\"kind\":\"Binding\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves array rest patterns as ArrayView bindings" {
  let source = "fn head(xs:FixedArray[Int])->Int { match xs {\n  [x, ..] => x\n  _ => 0\n} }\nfn last(xs:FixedArray[Int])->Int { match xs {\n  [.., x] => x\n  _ => 0\n} }\nfn edges(xs:FixedArray[Int])->Int { match xs {\n  [x, ..rest, y] => x + y\n  _ => 0\n} }\nfn has_tail(xs:FixedArray[Int])->Bool { xs is [_, ..rest] }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Array\""))
  assert_true(json.contains("\"rest\":{\"symbol\":null}"))
  assert_true(json.contains("\"suffix\":["))
  assert_true(json.contains("\"name\":\"rest\""))
  assert_true(
    json.contains(
      "\"constructor\":{\"kind\":\"Builtin\",\"name\":\"ArrayView\"}",
    ),
  )
  assert_true(json.contains("\"kind\":\"Builtin\",\"name\":\"Int\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext scopes is pattern bindings into if then branch" {
  let source = "fn use_array(xs:FixedArray[Int])->Int { if xs is [x] { x } else { 0 } }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"If\""))
  assert_true(json.contains("\"condition\":{\"kind\":\"IsPattern\""))
  assert_true(json.contains("\"pattern\":{\"kind\":\"Array\""))
  assert_true(json.contains("\"kind\":\"Binding\""))
  assert_true(json.contains("\"then\":{\"kind\":\"Name\""))
  assert_true(json.contains("\"name\":\"x\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves payload enum construction from expected type" {
  let source = "enum Lst {\n  Nil\n  Cons(Int, Lst)\n}\nfn nil()->Lst { Nil }\nfn cons()->Lst { Cons(1, Nil) }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Enum\""))
  assert_true(json.contains("\"name\":\"Lst\""))
  assert_true(json.contains("\"name\":\"Nil\""))
  assert_true(json.contains("\"name\":\"Cons\""))
  assert_true(
    json.contains(
      "\"payloads\":[{\"label\":null,\"type\":{\"kind\":\"Builtin\",\"name\":\"Int\"}},{\"label\":null,\"type\":{\"kind\":\"Declared\"",
    ),
  )
  assert_true(json.contains("\"name\":\"cons\""))
  assert_true(json.contains("\"kind\":\"IntLiteral\",\"value\":\"1\""))
  assert_true(
    json.contains("\"variantId\":\"type:pkg:Demo:Demo:Lst:variant:Cons\""),
  )
  assert_true(
    json.contains("\"variantId\":\"type:pkg:Demo:Demo:Lst:variant:Nil\""),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves imported enum case through package alias" {
  let imported_source = "pub(all) enum Relation {\n  Smaller\n  Greater\n}\n"
  let source = "let r : @my_pkg.Relation = @my_pkg.Relation::Smaller\n"
  let json = compile_package_source_to_json(
    source,
    "main.mbt",
    "Main",
    "import {\n  \"my/pkg\" @my_pkg,\n}\n",
    "moon.pkg",
    [
      {
        import_ref: {
          alias_name: "my_pkg",
          package_id: "pkg:my/pkg",
          module_path: "my/pkg",
        },
        file_path: "my_pkg.mbt",
        source: imported_source,
      },
    ],
  )
  assert_true(json.contains("\"kind\":\"Enum\""))
  assert_true(json.contains("\"packageId\":\"pkg:my/pkg\""))
  assert_true(json.contains("\"kind\":\"EnumCase\""))
  assert_true(
    json.contains(
      "\"variantId\":\"type:pkg:my/pkg:my/pkg:Relation:variant:Smaller\"",
    ),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves option equality from lazy local and some operand" {
  let source = "enum BulletMarker {\n  Dash\n  Asterisk\n}\nfn same(marker:BulletMarker)->Bool {\n  let current_marker = match marker {\n    Dash => Some(BulletMarker::Dash)\n    Asterisk => None\n  }\n  current_marker != Some(marker)\n}\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"selectedIntrinsic\":\"%option_ne\""))
  assert_true(
    json.contains("\"constructor\":{\"kind\":\"Builtin\",\"name\":\"Option\"}"),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves constant enum equality" {
  let source = "enum OrderedDelimiter {\n  Dot\n  Paren\n} derive(Eq)\nfn same(left:OrderedDelimiter, right:OrderedDelimiter)->Bool { left == right }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"selectedFunctionId\":\"derived:trait:"))
  assert_true(json.contains("\"selectedIntrinsic\":null"))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves derived Debug to_repr for struct" {
  let source = "struct Pair {\n  a : String\n  b : Int\n} derive(Debug)\nfn repr_pair(p : Pair) -> @debug.Repr { p.to_repr() }\n"
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "demo.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin, \"moonbitlang/core/debug\" as debug }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: {
          alias_name: "debug",
          package_id: "pkg:moonbitlang/core/debug",
          module_path: "moonbitlang/core/debug",
        },
        file_path: "debug.mbti",
        source: "package \"moonbitlang/core/debug\"\ntype Repr\npub(open) trait Debug {\n  to_repr(Self) -> Repr\n}\npub impl Debug for Int\npub impl Debug for String\n",
      },
    ]),
  )
  assert_true(json.contains("\"name\":\"to_repr\""))
  assert_true(json.contains("\"functionId\":\"derived:trait:"))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves generic static constructor result into constrained receiver method" {
  let source = "struct TypeA { a : StringView\n  b : Int } derive(Hash, Eq, Debug)\nstruct TypeB { a : TypeA\n  b : Int } derive(Hash, Eq, Debug)\nfn f(b1 : TypeB, b2 : TypeB) -> String { @set.Set::Set([b1, b2]).to_repr().to_string() }\n"
  let set_source = "package \"moonbitlang/core/set\"\npub struct Set[K] {}\npub fn[K : Hash + Eq] Set::Set(ArrayView[K], capacity? : Int) -> Self[K]\npub fn[K : @debug.Debug] Set::to_repr(Self[K]) -> @debug.Repr\n"
  let debug_source = "package \"moonbitlang/core/debug\"\ntype Repr\npub(open) trait Debug {\n  to_repr(Self) -> Repr\n}\npub impl Debug for Int\npub impl Debug for String\npub impl Debug for StringView\npub impl Show for Repr with to_string(self) = \"%repr_to_string\"\n"
  let hash_source = "pub(open) trait Hash {\n  hash_combine(Self, Hasher) -> Unit\n}\ntype Hasher\n"
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "main.mbt", source }],
    "Demo",
    "import {\n  \"moonbitlang/core/builtin\" as builtin\n  \"moonbitlang/core/debug\" @debug\n  \"moonbitlang/core/set\" @set\n}\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: {
          alias_name: "debug",
          package_id: "pkg:moonbitlang/core/debug",
          module_path: "moonbitlang/core/debug",
        },
        file_path: "debug.mbt",
        source: debug_source,
      },
      {
        import_ref: {
          alias_name: "set",
          package_id: "pkg:moonbitlang/core/set",
          module_path: "moonbitlang/core/set",
        },
        file_path: "set.mbti",
        source: set_source,
      },
      {
        import_ref: test_core_import_ref(),
        file_path: "hash.mbt",
        source: hash_source,
      },
    ]),
  )
  if !json.contains("\"diagnostics\":[]") {
    fail(json)
  }
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:moonbitlang/core/set:moonbitlang/core/set:Set::Set\"",
    ),
  )
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:moonbitlang/core/set:moonbitlang/core/set:Set::to_repr\"",
    ),
  )
}

///|
test "vnext lowers panic expression" {
  let source = "fn unreachable()->Int { panic() }\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"Panic\""))
  assert_true(json.contains("\"kind\":\"Builtin\",\"name\":\"Int\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext lowers simple project dependency syntax" {
  let source = "fn repeat_char(ch : Char, count : Int) -> String {\n  let buf = StringBuilder::new()\n  for i = 0; i < count; {\n    buf.write_char(ch)\n    continue i + 1\n  }\n  buf.to_string()\n}\nfn main()->Unit {\n  let speech = \"ok\"\n  println(\"[\\{speech}]\" + repeat_char('-', 1))\n}\n"
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"kind\":\"CharLiteral\",\"value\":\"-\""))
  assert_true(json.contains("\"name\":\"StringBuilder::new\""))
  assert_true(json.contains("\"name\":\"StringBuilder::write_char\""))
  assert_true(json.contains("\"name\":\"StringBuilder::to_string\""))
  assert_true(json.contains("\"selectedIntrinsic\":\"%string_add\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext byte eq not_equal bodies resolve receiver to_int" {
  let source =
    #|pub extern "csharp" fn Byte::to_int(self : Byte) -> Int = #|return self;
    #|pub impl Eq for Byte with equal(self : Byte, that : Byte) -> Bool {
    #|  self.to_int() == that.to_int()
    #|}
    #|pub impl Eq for Byte with not_equal(self : Byte, that : Byte) -> Bool {
    #|  self.to_int() != that.to_int()
    #|}
    #|fn main {
    #|  let b1 : Byte = 1
    #|  let b2 : Byte = 2
    #|  let _ = b1 != b2
    #|}
  let json = compile_test_source_to_json(source, "byte_eq.mbt", "Main")
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext declaration source core numeric not_equal binds" {
  let core_source =
    #|pub extern "csharp" fn Byte::to_int(self : Byte) -> Int = #|return self;
    #|pub impl Eq for Byte with equal(self : Byte, that : Byte) -> Bool {
    #|  self.to_int() == that.to_int()
    #|}
    #|pub impl Eq for Byte with not_equal(self : Byte, that : Byte) -> Bool {
    #|  self.to_int() != that.to_int()
    #|}
  let source = "fn main { let b1 : Byte = 1; let _ = b1 != 2 }\n"
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "main.mbt", source }],
    "Main",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: test_core_import_ref(),
        file_path: "core_numeric_ops.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext declaration source core numeric empty main stays clean" {
  let core_source =
    #|pub extern "csharp" fn Byte::to_int(self : Byte) -> Int = #|return self;
    #|pub impl Eq for Byte with equal(self : Byte, that : Byte) -> Bool {
    #|  self.to_int() == that.to_int()
    #|}
    #|pub impl Eq for Byte with not_equal(self : Byte, that : Byte) -> Bool {
    #|  self.to_int() != that.to_int()
    #|}
  let source = "fn main {}\n"
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "main.mbt", source }],
    "Main",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: test_core_import_ref(),
        file_path: "core_numeric_ops.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
}

///|
test "vnext resolves bare type constructor calls to static receiver constructors" {
  let source = "fn make_set() -> Set[String] { Set([]) }\nfn make_map() -> Map[String, Int] { Map([]) }\n"
  let set_source = "package \"moonbitlang/core/set\"\npub struct Set[K] {}\npub fn[K : Hash + Eq] Set::Set(ArrayView[K], capacity? : Int) -> Self[K]\n"
  let map_source = "package \"moonbitlang/core/builtin\"\npub fn[K : Hash + Eq, V] Map::Map(ArrayView[(K, V)], capacity? : Int) -> Map[K, V]\n"
  let hash_source = "pub(open) trait Hash {\n  hash_combine(Self, Hasher) -> Unit\n}\ntype Hasher\n"
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "main.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: test_core_import_ref(),
        file_path: "hash.mbt",
        source: hash_source,
      },
      {
        import_ref: {
          alias_name: "set",
          package_id: "pkg:moonbitlang/core/set",
          module_path: "moonbitlang/core/set",
        },
        file_path: "set.mbti",
        source: set_source,
      },
      {
        import_ref: test_core_import_ref(),
        file_path: "map.mbti",
        source: map_source,
      },
    ]),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:moonbitlang/core/set:moonbitlang/core/set:Set::Set\"",
    ),
  )
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Map::Map\"",
    ),
  )
}

///|
test "vnext resolves open-ended string slice to stringview to_owned" {
  let source =
    #|fn split_qualified(name : String) -> (String?, String) {
    #|  for i in 0..<name.length() {
    #|    if name[i] == '.' {
    #|      return (Some(name[0:i].to_owned()), name[i + 1:].to_owned())
    #|    }
    #|  }
    #|  (None, name)
    #|}
  let core_source =
    #|pub extern "csharp" fn String::length(self : String) -> Int =
    #|  #|return default!;
    #|#alias("_[_:_]")
    #|pub extern "csharp" fn String::view(self : String, start_offset? : Int, end_offset? : Int) -> StringView =
    #|  #|return default!;
    #|pub extern "csharp" fn StringView::to_owned(self : StringView) -> String =
    #|  #|return default!;
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "main.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: {
          alias_name: "builtin",
          package_id: "pkg:moonbitlang/core/builtin",
          module_path: "moonbitlang/core/builtin",
        },
        file_path: "core_stringview.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
  assert_true(json.contains("\"StringView::to_owned\""))
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:String::view\"",
    ),
  )
}

///|
test "vnext resolves open-ended bytes slice through slice alias" {
  let source =
    #|fn tail(bytes : Bytes) -> BytesView { bytes[5:] }
  let core_source =
    #|#alias("_[_:_]")
    #|pub extern "csharp" fn Bytes::view(self : Bytes, start? : Int = 0, end? : Int) -> BytesView =
    #|  #|return default!;
  let json = compile_package_sources_with_declarations_to_json(
    [{ file_path: "main.mbt", source }],
    "Demo",
    "import { \"moonbitlang/core/builtin\" as builtin }\n",
    "moon.pkg",
    [],
    test_core_declaration_sources([
      {
        import_ref: {
          alias_name: "builtin",
          package_id: "pkg:moonbitlang/core/builtin",
          module_path: "moonbitlang/core/builtin",
        },
        file_path: "core_bytesview.mbt",
        source: core_source,
      },
    ]),
  )
  assert_true(json.contains("\"diagnostics\":[]"))
  assert_true(
    json.contains(
      "\"functionId\":\"fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Bytes::view\"",
    ),
  )
}

///|
test "vnext unresolved slice reports primary resolution diagnostic only" {
  let source = #|fn bad(value : Int) -> Int { value[0:] }
  let json = compile_test_source_to_json(source, "bad_slice.mbt", "Demo")
  assert_true(json.contains("\"message\":\"cannot find slice implementation\""))
  assert_false(json.contains("\"executable IR contains error expression\""))
}

///|
test "vnext nested local function binds without parsing parameter ids" {
  let source =
    #|fn outer() -> Int {
    #|  fn inner(x : Int) -> Int {
    #|    x + 1
    #|  }
    #|  inner(41)
    #|}
  let json = compile_test_source_to_json(source, "demo.mbt", "Demo")
  assert_true(json.contains("\"name\":\"outer\""))
  assert_true(json.contains("\"name\":\"inner\""))
  assert_true(json.contains("\"kind\":\"LocalFunction\""))
  assert_true(json.contains("\"diagnostics\":[]"))
}
