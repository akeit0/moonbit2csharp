///|
fn main {
  let world = "world"
  let sb = StringBuilder::new()
  sb <+ "Hello, \{world}!"
  println(sb.to_string())
  let s : Set[Int] = Set::Set([])
  s.add(1)
  s.add(2)
  s.add(3)
  s.add(2)

  println(s.to_repr().to_string())
  let b1 = TypeB::{ a: TypeA::{ a: "example", b: 42 }, b: 10 }
  let b2 = TypeB::{ a: TypeA::{ a: "example", b: 42 }, b: 10 }
  let b3 = TypeB::{ a: TypeA::{ a: "example", b: 43 }, b: 10 }
  print_debug(b1)

  let r = raise_test_error() catch {
    e => {
      println(
        if e is TestError::Example {
          "Caught Example"
        } else {
          "Caught some other error"
        },
      )
      "a"
    }
  }
  println(r)
  try {
    raise_error()
    raise_error()
  } catch {
    e => println("Error printing: \{e}")
  }

  Set::Set([b1, b2, b3]).to_repr().to_string() |> println

}

///|
fn raise_test_error() -> String raise TestError {
  raise TestError::Example
}

///|
fn raise_error() -> Unit raise Error {
  println(raise_test_error())
}

///|
struct TypeA {
  a : StringView
  b : Int
} derive(Hash, Eq, Debug)

///|
struct TypeB {
  a : TypeA
  b : Int
} derive(Hash, Eq, Debug)

///|
suberror TestError {
  Example
}

///|
fn[T : Debug] print_debug(x : T) -> Unit {
  println(x.to_repr().to_string())
}
