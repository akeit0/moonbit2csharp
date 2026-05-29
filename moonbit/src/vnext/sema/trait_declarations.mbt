///|
fn collect_traits(
  context : BindingContext,
  index : DeclarationIndex,
  ast : Module,
) -> Unit {
  for trait_decl in ast.traits {
    let symbol = @binding.make_type_symbol(
      context.package_id,
      context.module_name,
      trait_decl.name,
    )
    @semantic.declare_trait(index, {
      symbol,
      type_params: [],
      methods: [],
      span: trait_decl.span,
    })
    context.symbols.push({
      id: symbol.id,
      kind: SymbolKind::Trait,
      name: trait_decl.name,
      type_: TypeRef::TraitObject({ trait_: symbol, args: [] }),
      span: trait_decl.span,
    })
  }
  for trait_decl in ast.traits {
    let symbol = @binding.make_type_symbol(
      context.package_id,
      context.module_name,
      trait_decl.name,
    )
    let methods : Array[@semantic.TraitMethodSignature] = []
    for trait_method in trait_decl.methods {
      let parameters : Array[@binding.ParamTypeRef] = []
      for param_type in trait_method.parameters {
        parameters.push({
          label: None,
          type_: resolve_trait_type(context, index, param_type),
          optional: false,
          has_default: false,
        })
      }
      methods.push({
        method_id: "trait-method:" + symbol.id + ":" + trait_method.name,
        name: trait_method.name,
        parameters,
        return_type: resolve_trait_type(
          context,
          index,
          trait_method.return_type,
        ),
        has_default: trait_method.has_default,
        default_function_id: None,
        span: trait_method.span,
      })
    }
    @semantic.declare_trait(index, {
      symbol,
      type_params: [],
      methods,
      span: trait_decl.span,
    })
  }
}

///|
fn resolve_trait_type(
  context : BindingContext,
  index : DeclarationIndex,
  type_ : TypeSyntax,
) -> TypeRef {
  if type_.package_alias is None && type_.name == "Self" {
    TypeRef::Builtin("Self")
  } else {
    resolve_type(context, index, type_)
  }
}
