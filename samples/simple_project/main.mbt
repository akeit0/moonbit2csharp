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

  @rabbit.hello()
  println(to_string2(3))
}

///|
fn[T : Show2] to_string2(v : T) -> String {
  v.to_string2()
}

///|
fn[T : Debug] print_debug(x : T) -> Unit {
  println(x.to_repr().to_string())
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

// impl Show for TestError with fn to_string(self) {
//   match self {
//     TestError::Example => "Example error".to_string()
//   }
// }

trait Show2 {
  fn to_string2(self:Self) -> String =_
  fn output(self:Self, logger : &Logger) -> Unit
}


impl Show2 with fn to_string2(self) {
   let logger = StringBuilder::new()
   self.output(logger)
   self.output(logger)
    logger.to_string()
}


impl Show2 for Int with fn output(self, logger) {
  logger.write_string(self.to_string())
}
