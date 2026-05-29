///|
test "vnext parser accepts zero parameter unit function shorthand" {
  let file = @text.source_file("main.mbt", "fn main {\n  println(10)\n}\n")
  let result = parse_source(file)
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.module_.functions.length(), 1)
  let function_ = result.module_.functions[0]
  assert_eq(function_.name, "main")
  assert_eq(function_.params.length(), 0)
  assert_eq(function_.return_type.name, "Unit")
}

///|
test "vnext parser accepts typed struct literal syntax" {
  let source = "struct Document { children : Array[Int] }\nfn make() -> Document { Document::{ children: [] } }\n"
  let result = parse_source(@text.source_file("main.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
  match result.module_.functions[0].body {
    @ast.Expr::TypedStructLiteral(type_, fields, _) => {
      assert_eq(type_.name, "Document")
      assert_eq(fields.length(), 1)
      assert_eq(fields[0].name, "children")
    }
    _ => fail("expected typed struct literal")
  }
}

///|
test "vnext parser accepts boolean not in while condition" {
  let source = "fn scan() -> Unit { while !scanner.is_eof() && scanner.is_blank_line() { scanner.skip_line() } }\n"
  let result = parse_source(@text.source_file("main.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser records trait method default markers" {
  let source = "pub(open) trait Eq { equal(Self, Self) -> Bool\nnot_equal(Self, Self) -> Bool = _ }\n"
  let result = parse_source(@text.source_file("traits.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.module_.traits.length(), 1)
  assert_eq(result.module_.traits[0].methods.length(), 2)
  assert_false(result.module_.traits[0].methods[0].has_default)
  assert_true(result.module_.traits[0].methods[1].has_default)
}

///|
test "vnext parser accepts fn marker in trait methods" {
  let source = "pub(open) trait Debug { fn to_repr(Self) -> Repr }\n"
  let result = parse_source(@text.source_file("traits.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.module_.traits.length(), 1)
  assert_eq(result.module_.traits[0].methods.length(), 1)
  assert_eq(result.module_.traits[0].methods[0].name, "to_repr")
}

///|
test "vnext parser accepts char literal match patterns and guards" {
  let source = "fn f(c : Char) -> Int { match c { Some('\\n') => 1 _ => 0 } }\n"
  let result = parse_source(@text.source_file("main.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser keeps unicode string literals intact" {
  let source = "fn f() -> String { \"😀😃hello\" }\n"
  let result = parse_source(@text.source_file("main.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
  match result.module_.functions[0].body {
    @ast.Expr::StringLiteral(value, _) => assert_eq(value, "😀😃hello")
    _ => fail("expected string literal")
  }
}

///|
test "vnext parser accepts newline-leading method chains" {
  let source = "fn f(text : String) -> String { text\n  .trim()\n  .to_string() }\n"
  let result = parse_source(@text.source_file("main.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts binary operator line continuation" {
  let source = "fn f(a : Bool, b : Bool, c : Bool) -> Bool { if a &&\n  b &&\n  c { true } else { false } }\n"
  let result = parse_source(@text.source_file("main.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts struct update literal syntax" {
  let source = "fn f(run : Run) -> Run { { ..run, deleted: true } }\n"
  let result = parse_source(@text.source_file("main.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
  match result.module_.functions[0].body {
    @ast.Expr::StructUpdateLiteral(_, fields, _) => {
      assert_eq(fields.length(), 1)
      assert_eq(fields[0].name, "deleted")
    }
    _ => fail("expected struct update literal")
  }
}

///|
test "vnext parser accepts array spread literal syntax" {
  let source = "fn f(head : String, rest : Array[String]) -> Array[String] { [head, ..rest] }\n"
  let result = parse_source(@text.source_file("main.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
  match result.module_.functions[0].body {
    @ast.Expr::ArrayLiteral(items, _) => {
      assert_eq(items.length(), 2)
      match items[1] {
        @ast.ArrayElement::Spread(_, _) => ()
        _ => fail("expected spread element")
      }
    }
    _ => fail("expected array literal")
  }
}

///|
test "vnext parser accepts labelled constructor pattern puns" {
  let source = "fn f(block : Block) -> Int { match block { Block::Heading(level~, children~) => level _ => 0 } }\n"
  let result = parse_source(@text.source_file("main.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts multiline or patterns and constructor rest" {
  let source = "fn f(c : Char, inline : Inline) -> Bool { match c { '\\n'\n| '\\t' => true _ => false }; match inline { Inline::Link(..) | Inline::RefLink(..) => true _ => false } }\n"
  let result = parse_source(@text.source_file("main.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts multiline c-style for and newline target match" {
  let source = "fn f(items : Array[Int]) -> Unit { for i = 0\n  i < items.length()\n  i = i + 1 { match\n    items[i] { 0 => () _ => () } } }\n"
  let result = parse_source(@text.source_file("main.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts functional loop nobreak syntax" {
  let source = "fn f(arr : MutArrayView[Int]) -> Bool { for i in 1..<arr.length(); tries = 0 { let sorted = for j = i, sorted = true; j > 0; { continue j - 1, false } nobreak { sorted }; if tries > 8 { break false }; continue tries + 1 } nobreak { true } }\n"
  let result = parse_source(@text.source_file("loops.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts multiline functional for header" {
  let source = "fn f(arr : MutArrayView[Int]) -> (Int, Bool) { for\n  j in 0..<(arr.length() - 1)\n  i = 0, partitioned = true { continue i + 1, partitioned } nobreak { (i, partitioned) } }\n"
  let result = parse_source(@text.source_file("loops.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts underscore for range binder" {
  let source = "fn f(new_len : Int) -> Unit { for _ in 0..<new_len { ignore(new_len) } }\n"
  let result = parse_source(@text.source_file("loops.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts typed closure parameters" {
  let source = "fn f(arr : Array[Int]) -> Unit { let sort_2 = (a : Int, b : Int) => { arr.swap(a, b) }; sort_2(0, 1) }\n"
  let result = parse_source(@text.source_file("lambda.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts wildcard impl method parameters" {
  let source = "pub impl Debug for Unit with to_repr(_) { Repr::unit() }\n"
  let result = parse_source(@text.source_file("impl.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.module_.impls.length(), 1)
  assert_eq(result.module_.impls[0].methods.length(), 1)
  assert_eq(result.module_.impls[0].methods[0].params.length(), 1)
}

///|
test "vnext parser accepts fn marker in trait impl methods" {
  let source = "pub impl Debug for IterResult with fn to_repr(self) { Repr::unit() }\n"
  let result = parse_source(@text.source_file("impl.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.module_.impls.length(), 1)
  assert_eq(result.module_.impls[0].methods.length(), 1)
  assert_eq(result.module_.impls[0].methods[0].name, "to_repr")
}

///|
test "vnext parser accepts function type parameters with raise" {
  let source = "fn fixed_test_sort(f : (MutArrayView[Int]) -> Unit) -> Unit raise { f(make_view()) }\nfn[T] Array::all(self : Array[T], f : (T) -> Bool raise?) -> Bool raise? { self[:].all(f) }\n"
  let result = parse_source(@text.source_file("functions.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts wildcard type arguments" {
  let source = "fn f() -> Unit { let arr : FixedArray[_] = [1, 2, 3]; ignore(arr) }\n"
  let result = parse_source(@text.source_file("types.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts parenthesized type ascription" {
  let source = "fn f(bytes : Bytes, i : Int) -> UInt64 { (0 : UInt64) | (bytes.unsafe_get(i).to_uint64() << 8) }\n"
  let result = parse_source(@text.source_file("ascription.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts const byte strings and raise expressions" {
  let source = "const ZERO = 0.0\nfn f() -> Unit raise InspectError { let base64 = b\"ABC\"; let zero = b'\\x00'; raise InspectError(base64) }\n"
  let result = parse_source(@text.source_file("misc.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts local functions and while nobreak" {
  let source = "fn f(self : Iter[Int], x : Int) -> IterResult { fn set_low_word(d : Double, v : UInt) -> Double { d }; while self.next() is Some(x) { guard f(x) is IterContinue else { break IterEnd } } nobreak { IterContinue } }\n"
  let result = parse_source(@text.source_file("local_fn_loop.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts is expression inside boolean operators" {
  let source = "fn f(self : Int) -> Bool { if self is (0..=0xD7FF) || self is (0xE000..=0x10FFFF) { true } else { false } }\n"
  let result = parse_source(@text.source_file("is_bool.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts open ended underscore range patterns" {
  let source = "fn f(self : UInt16) -> Bool { self is (0..=0xD7FF) || self is (0xE000..<_) }\n"
  let result = parse_source(@text.source_file("range_pattern.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts public using declarations" {
  let source = "pub using @abort {abort}\n"
  let result = parse_source(@text.source_file("using.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.module_.usings.length(), 1)
}

///|
test "vnext parser accepts attributed public generic tuple impl" {
  let source = "#deprecated(\"x\")\npub impl[\n  T0 : Compare,\n  T1 : Compare,\n] Compare for (T0, T1) with compare(self : (T0, T1), other : (T0, T1)) -> Int { self.0.compare(other.0) }\n"
  let result = parse_source(@text.source_file("impls.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.module_.impls.length(), 1)
}

///|
test "vnext parser accepts guard is pattern across newline" {
  let source = "fn f(opener : Token) -> Unit { guard opener\n  is EmphasisMarks(start, marker, count) else { return } }\n"
  let result = parse_source(@text.source_file("main.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser preserves separator after guard without else" {
  let source = "fn f(x : Int) -> Int { guard x >= 0\n  if x <= 1 { return 1 }\n  x }\n"
  let result = parse_source(@text.source_file("main.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts expression is pattern across newline" {
  let source = "fn f(c : Char) -> Bool { c\n  is ('A'..='Z' | 'a'..='z') }\n"
  let result = parse_source(@text.source_file("main.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts integer literal suffixes" {
  let source = "fn f(current_run : Int) -> Int { 1UL << current_run }\n"
  let result = parse_source(@text.source_file("main.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "vnext parser accepts multiline labelled enum payloads" {
  let source = "enum Block { ThematicBreak(\n  marker~ : Char,\n  count~ : Int,\n  span~ : Span\n) }\n"
  let result = parse_source(@text.source_file("main.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.module_.enums[0].variants[0].payloads.length(), 3)
}

///|
test "vnext parser accepts core trait declaration syntax" {
  let source = "pub(open) trait Compare: Eq {\n  compare(Self, Self) -> Int\n  op_lt(Self, Self) -> Bool = _\n}\nimpl Compare with op_lt(x, y) { x.compare(y).is_neg() }\n"
  let result = parse_source(@text.source_file("traits.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.module_.traits.length(), 1)
  assert_eq(result.module_.traits[0].methods.length(), 2)
  assert_eq(result.module_.impls.length(), 0)
}

///|
test "vnext parser accepts type syntax receivers in function names" {
  let source = "pub fn[Obj : Show] &Logger::write_object(self : &Logger, obj : Obj) -> Unit { obj.output(self) }\npub fn[T] Array[T]::first(self : Array[T]) -> T { self[0] }\n"
  let result = parse_source(@text.source_file("methods.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.module_.functions.length(), 2)
  match result.module_.functions[0].receiver {
    Some(receiver) => {
      assert_eq(receiver.name, "Logger")
      assert_true(receiver.is_trait_object)
    }
    None => fail("expected receiver")
  }
  match result.module_.functions[1].receiver {
    Some(receiver) => {
      assert_eq(receiver.name, "Array")
      assert_eq(receiver.args.length(), 1)
    }
    None => fail("expected receiver")
  }
}

///|
test "vnext parser accepts keyword package alias in type syntax" {
  let source = "fn f(sources : Array[@package.PackageSource]) -> Unit { ignore(sources) }\n"
  let result = parse_source(@text.source_file("alias.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.module_.functions.length(), 1)
}

///|
test "vnext parser accepts keyword package alias in expression syntax" {
  let source = "fn f(source : String) -> Int { @package.parse(source) }\n"
  let result = parse_source(@text.source_file("alias_expr.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.module_.functions.length(), 1)
}

///|
test "vnext parser accepts package-qualified constructor patterns" {
  let source = "fn f(expr : @ir.BoundExpr) -> Int { match expr { @ir.BoundExpr::Name(name, _) => 1 _ => 0 } }\n"
  let result = parse_source(@text.source_file("alias_pattern.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.module_.functions.length(), 1)
}

///|
test "vnext parser accepts logger append operator" {
  let source = "fn f(sb : StringBuilder, world : String) -> Unit { sb <+ \"Hello, \\{world}!\" }\n"
  let result = parse_source(@text.source_file("logger_append.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
  match result.module_.functions[0].body {
    @ast.Expr::Binary(op, _, _, _) => assert_eq(op, "<+")
    _ => fail("expected logger append binary")
  }
}

///|
test "vnext parser accepts char and wildcard range patterns" {
  let source = "fn f(c : Char) -> Bool { c is ('A'..='Z' | 'a'..='z') }\nfn g(i : Int) -> Bool { match i { _..=0xFF => true _ => false } }\n"
  let result = parse_source(@text.source_file("patterns.mbt", source))
  assert_eq(result.diagnostics.length(), 0)
}
