fn main {
  let arr = [1, 2, 3]
  let s = "moonbit"
  println(arr.length())
  println(arr[1])
  arr.push(4)
  println(arr.length())
  println(arr)
  println(s.length())
  println(s.has_prefix("moon"))
  println(s.contains("nb"))
  println(s.replace_all(old="moon", new="csharp"))
}
