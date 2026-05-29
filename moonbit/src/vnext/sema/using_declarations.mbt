///|
fn declare_usings(index : DeclarationIndex, ast : Module) -> Unit {
  for using_decl in ast.usings {
    match @semantic.resolve_import_alias(index, using_decl.package_alias) {
      Some(package_id) =>
        for item in using_decl.items {
          declare_using_item(index, using_decl.package_alias, package_id, item)
        }
      None =>
        index.error(
          "VNX2003",
          "unknown package alias in using: " + using_decl.package_alias,
          using_decl.span,
        )
    }
  }
}

///|
fn declare_using_item(
  index : DeclarationIndex,
  package_alias : String,
  package_id : String,
  item : @ast.UsingItem,
) -> Unit {
  match item.kind {
    @ast.UsingItemKind::Type =>
      @semantic.add_using_item(index, {
        package_alias,
        package_id,
        name: item.name,
        kind: @semantic.UsingItemKind::Type,
        span: item.span,
      })
    @ast.UsingItemKind::Value => {
      let mut resolved = false
      if @semantic.find_functions_by_package_alias(
          index,
          package_alias,
          item.name,
        ).length() >
        0 {
        @semantic.add_using_item(index, {
          package_alias,
          package_id,
          name: item.name,
          kind: @semantic.UsingItemKind::Function,
          span: item.span,
        })
        resolved = true
      }
      if @semantic.find_global_by_package_alias(index, package_alias, item.name)
        is Some(_) {
        @semantic.add_using_item(index, {
          package_alias,
          package_id,
          name: item.name,
          kind: @semantic.UsingItemKind::Global,
          span: item.span,
        })
        resolved = true
      }
      if !resolved {
        index.error(
          "VNX2004",
          "unknown imported value in using: " + item.name,
          item.span,
        )
      }
    }
  }
}
