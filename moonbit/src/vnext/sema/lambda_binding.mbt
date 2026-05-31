///|
fn bind_lambda(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  param_names : Array[String],
  body : Expr,
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let expected = @semantic.resolve_inferred_type(typing, expected)
  match expected {
    TypeRef::Function(param_types, return_type, effect) => {
      if param_names.length() != param_types.length() {
        context.error("VNX1903", "lambda parameter arity mismatch", span)
        return BoundExpr::Error(
          "lambda parameter arity mismatch",
          error_type(),
          span,
        )
      }
      let next_scope = scope.copy()
      let params : Array[Symbol] = []
      for i in 0..<param_names.length() {
        let symbol : Symbol = {
          id: local_id(
            local_owner_id(context, scope),
            param_names[i],
            span.start + i,
          ),
          kind: SymbolKind::Parameter,
          name: param_names[i],
          type_: param_types[i].type_,
          span,
        }
        params.push(symbol)
        next_scope.push(symbol)
      }
      let lambda_context = context_with_return_type(
        context,
        Some(return_type),
        effect,
      )
      let bound_body = bind_expr(
        typing, lambda_context, index, next_scope, body, return_type, ast,
      )
      BoundExpr::Lambda(
        params,
        bound_body,
        TypeRef::Function(param_types, @ir.expr_type(bound_body), effect),
        span,
      )
    }
    _ => {
      context.error(
        "VNX1903", "lambda expression requires an expected function type", span,
      )
      BoundExpr::Error("unsupported lambda", error_type(), span)
    }
  }
}

///|
fn context_with_return_type(
  context : BindingContext,
  return_type : TypeRef?,
  effect : @binding.EffectRef,
) -> BindingContext {
  {
    module_name: context.module_name,
    package_id: context.package_id,
    imports: context.imports,
    current_type_params: context.current_type_params,
    symbols: context.symbols,
    types: context.types,
    functions: context.functions,
    imported_functions: context.imported_functions,
    imported_globals: context.imported_globals,
    default_arguments: context.default_arguments,
    default_arguments_by_id: context.default_arguments_by_id,
    current_return_type: return_type,
    current_owner_id: context.current_owner_id,
    current_effect: effect,
    loop_depth: context.loop_depth,
    loop_break_expected_types: context.loop_break_expected_types,
    used_trait_impls: context.used_trait_impls,
    used_trait_impl_keys: context.used_trait_impl_keys,
    trait_default_context: context.trait_default_context,
    diagnostics: context.diagnostics,
    suppress_diagnostics: context.suppress_diagnostics,
  }
}
