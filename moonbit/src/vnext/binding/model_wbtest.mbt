///|
test "binding context copies imported type definitions" {
  let span = @common.source_span("dep.mbt", 0, 0, 1, 1)
  let imported_symbol : TypeSymbolRef = {
    id: "type:pkg:dep:dep:Imported",
    package_id: "pkg:dep",
    module_path: "dep",
    name: "Imported",
  }
  let local_symbol : TypeSymbolRef = {
    id: "type:pkg:demo:demo:Local",
    package_id: "pkg:demo",
    module_path: "demo",
    name: "Local",
  }
  let imported_types : Array[TypeDefinition] = [
    TypeDefinition::Opaque({ symbol: imported_symbol, type_params: [] }),
  ]
  let context = binding_context_with_imports(
    "demo",
    "pkg:demo",
    [],
    imported_types,
    [],
    [],
    [],
  )
  context.types.push(
    TypeDefinition::Opaque({ symbol: local_symbol, type_params: [] }),
  )
  assert_eq(imported_types.length(), 1)
  assert_eq(context.types.length(), 2)
  assert_true(context.types[0] == imported_types[0])
  inspect(span.file, content="dep.mbt")
}
