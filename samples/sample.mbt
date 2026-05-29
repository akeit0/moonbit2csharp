///|
struct Point {
  x : Int
  y : Int
} derive(Show)

///|
fn f() -> (Int, Bool, Double) {
  (1, false, 3.14)
}

///|
fn main {
  // tuple creation
  let tuple = (3.14, false, [1, 2, 3])

  // tuple element access
  println(tuple.0)
  println(tuple.2)

  // tuple destructuring
  let (a, b2, d2) = f()
  println("\{a}, \{b2}, \{d2}")

  // struct construction and field access
  let p = Point::{ x: 2, y: 5 }
  println(p)

  println("number 1 to 3:")
  for i in 1..<4 {
    println(i)
  }

  println("number 1 to 4:")
  for i in 1..<=4 {
    println(i)
  }
}
