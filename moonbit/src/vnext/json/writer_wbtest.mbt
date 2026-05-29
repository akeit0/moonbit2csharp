///|
test "type json preserves semantic type categories" {
  let s = @common.source_span("types.mbt", 0, 0, 1, 1)
  let box_symbol : @binding.TypeSymbolRef = {
    id: "type:pkg:demo:Box/1",
    package_id: "pkg:demo",
    module_path: "types",
    name: "Box",
  }
  let show_symbol : @binding.TypeSymbolRef = {
    id: "trait:pkg:demo:Show",
    package_id: "pkg:demo",
    module_path: "types",
    name: "Show",
  }
  let t_type = @binding.TypeRef::TypeParameter("T", "type-param:T")
  let fn_type = @binding.TypeRef::Function(
    [{ label: None, type_: t_type, optional: false, has_default: false }],
    @binding.int_type(),
    @binding.EffectRef::Raises(@binding.TypeRef::Declared(box_symbol, [t_type])),
  )
  let trait_type = @binding.TypeRef::TraitObject({
    trait_: show_symbol,
    args: [t_type],
  })
  let module_ : @ir.BoundModule = {
    schema: "moonbit2csharp.vnext.semantic-ir/0.1",
    module_name: "Types",
    symbols: [
      {
        id: "sym:fn-type",
        kind: @binding.SymbolKind::Type,
        name: "FnType",
        type_: fn_type,
        span: s,
      },
      {
        id: "sym:trait-type",
        kind: @binding.SymbolKind::Trait,
        name: "ShowObject",
        type_: trait_type,
        span: s,
      },
      {
        id: "sym:declared",
        kind: @binding.SymbolKind::Type,
        name: "BoxInt",
        type_: @binding.TypeRef::Declared(box_symbol, [@binding.int_type()]),
        span: s,
      },
    ],
    types: [],
    traits: [],
    used_trait_impls: [],
    functions: [],
    globals: [],
    default_arguments: [],
    diagnostics: [],
  }
  let json = write_module_json(module_)
  assert_true(json.contains("\"kind\":\"Function\""))
  assert_true(json.contains("\"kind\":\"Raises\""))
  assert_true(json.contains("\"kind\":\"TraitObject\""))
  assert_true(json.contains("\"kind\":\"Declared\""))
  assert_true(json.contains("\"kind\":\"TypeParameter\""))
}
