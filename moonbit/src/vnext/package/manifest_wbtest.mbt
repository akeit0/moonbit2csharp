///|
test "vnext package manifest gives unaliased imports default aliases" {
  let manifest = parse_moon_pkg(
    "import {\n  \"mizchi/markdown\",\n  \"moonbitlang/core/debug\" @debug,\n}\n",
    "moon.pkg",
  )
  assert_eq(manifest.imports.length(), 2)
  assert_eq(manifest.imports[0].alias_name, "markdown")
  assert_eq(manifest.imports[0].package_id, "pkg:mizchi/markdown")
  assert_eq(manifest.imports[1].alias_name, "debug")
}

///|
test "vnext package manifest accepts keyword package alias" {
  let manifest = parse_moon_pkg(
    "import {\n  \"moonbit2csharp/frontend/vnext/package\" @package,\n}\n", "moon.pkg",
  )
  assert_eq(manifest.diagnostics.length(), 0)
  assert_eq(manifest.imports.length(), 1)
  assert_eq(manifest.imports[0].alias_name, "package")
}

///|
test "vnext package source package declaration is discoverable" {
  match
    package_name_from_source(
      "// Generated using moon info\npackage \"mizchi/markdown\"\n\npub fn parse(String) -> Int\n",
      "pkg.generated.mbti",
    ) {
    Some(name) => assert_eq(name, "mizchi/markdown")
    None => fail("expected package declaration")
  }
}
