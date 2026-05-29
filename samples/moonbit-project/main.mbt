///|
fn main {
  let source =
    #| # Hello, MoonBit!
    #| This is a sample markdown document.
    #|
    #| - It supports lists
    #| - And **bold** text
    #| - And *italic* text
    #| - And [links](https://docs.moonbitlang.com/en/latest/)
    #| You can also include code blocks:
    #| ```rust
    #| fn greet(name: &str) {
    #|     println!("Hello, {}!", name);
    #| }
    #| ```
    #| Enjoy using MoonBit for your projects!

  let result = @markdown.parse(source)
  let doc = result.document

  // Render to HTML
  let html = @markdown.render_html(doc)
  println(html)
}

///|
test "panic error case of inspect" {
  let x : Int = 42
  debug_inspect(x.to_string(), content="100")
}

///|
// test "benchmark markdown parsing" (b : @bench.T) {
//   let source =
//     #| # Hello, MoonBit!
//     #| This is a sample markdown document.
//     #|
//     #| - It supports lists
//     #| - And **bold** text
//     #| - And *italic* text
//     #| - And [links](https://docs.moonbitlang.com/en/latest/)
//     #| You can also include code blocks:
//     #| ```rust
//     #| fn greet(name: &str) {
//     #|     println!("Hello, {}!", name);
//     #| }
//     #| ```
//     #| Enjoy using MoonBit for your projects!

//   b.bench(name="parser", fn() { let _ = @markdown.parse(source) })
// }
