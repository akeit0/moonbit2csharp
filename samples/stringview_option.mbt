fn main {
  let view : StringView = "moonbit"[0:-2]
  let some : StringView? = Some(view)
  let none : StringView? = None
  let unwrapped : StringView = some.unwrap()
  println(view.length())
  println(view.to_owned())
  println(if none is None {println("before returning none");
     "none" } else { "some" })
  println(if some is Some(_) { "some" } else { "none" })
  println(unwrapped.to_owned())
}
