///|
fn bind_call(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  callee : Expr,
  args : Array[CallArg],
  expected_result : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  match callee {
    Expr::PackageAccess(package_alias, name, _) => {
      let candidates = @semantic.find_functions_by_package_alias(
        index, package_alias, name,
      )
      if candidates.length() == 0 {
        return bind_package_trait_method_call(
          typing, context, index, scope, package_alias, name, args, expected_result,
          span, ast,
        )
      }
      let function_diagnostic_mark = context.diagnostics.length()
      let selected = choose_function(
        typing, context, candidates, scope, index, args, expected_result, span, ast,
      )
      match selected {
        Some(probe) => {
          let bound_args = bind_argument_plan(
            typing,
            context,
            index,
            scope,
            probe.argument_plan,
            ast,
          )
          BoundExpr::Call(
            probe.callable.function_id,
            probe.callable.type_args,
            bound_trait_evidence(context, probe.callable.trait_evidence),
            bound_args,
            selected_call_intrinsic(probe, bound_args),
            probe.callable.return_type,
            span,
          )
        }
        None => {
          let trait_diagnostic_mark = context.diagnostics.length()
          match
            bind_package_trait_method_call_if_available(
              typing, context, index, scope, package_alias, name, args, expected_result,
              span, ast,
            ) {
            Some(expr) => {
              rollback_diagnostics(context, function_diagnostic_mark)
              expr
            }
            None => {
              rollback_diagnostics(context, trait_diagnostic_mark)
              BoundExpr::Error(
                "unresolved package call: " + package_alias + "." + name,
                error_type(),
                span,
              )
            }
          }
        }
      }
    }
    Expr::StaticAccess(target, member_name, _) =>
      bind_static_access(
        typing, context, index, scope, target, member_name, args, expected_result,
        span, ast,
      )
    Expr::FieldAccess(receiver, method_name, _) => {
      let receiver_diagnostics = context.diagnostics.length()
      match
        bind_receiver_function_call(
          @semantic.typing_context(),
          diagnostic_free_context(context),
          index,
          scope,
          receiver,
          method_name,
          args,
          expected_result,
          span,
          ast,
        ) {
        Some(_) =>
          match
            bind_receiver_function_call(
              typing, context, index, scope, receiver, method_name, args, expected_result,
              span, ast,
            ) {
            Some(expr) => expr
            None =>
              BoundExpr::Error("unresolved receiver call", error_type(), span)
          }
        None => {
          rollback_diagnostics(context, receiver_diagnostics)
          let function_value_diagnostics = context.diagnostics.length()
          match
            bind_function_expression_call(
              @semantic.typing_context(),
              diagnostic_free_context(context),
              index,
              scope,
              callee,
              args,
              expected_result,
              span,
              ast,
            ) {
            Some(_) =>
              match
                bind_function_expression_call(
                  typing, context, index, scope, callee, args, expected_result, span,
                  ast,
                ) {
                Some(expr) => expr
                None =>
                  BoundExpr::Error(
                    "unresolved function value call",
                    error_type(),
                    span,
                  )
              }
            None => {
              rollback_diagnostics(context, function_value_diagnostics)
              bind_trait_method_call(
                typing, context, index, scope, receiver, method_name, args, expected_result,
                span, ast,
              )
            }
          }
        }
      }
    }
    Expr::Name("Some", _) =>
      bind_option_some(
        typing, context, index, scope, args, expected_result, span, ast,
      )
    Expr::Name("panic", _) =>
      if args.length() == 0 {
        BoundExpr::Panic(panic_result_type(typing, expected_result), span)
      } else {
        context.error("VNX1201", "panic expects 0 argument(s)", span)
        BoundExpr::Error("invalid panic call", error_type(), span)
      }
    Expr::Name(name, _) => {
      match
        bind_function_value_call(
          typing, context, index, scope, name, args, expected_result, span, ast,
        ) {
        Some(expr) => return expr
        None => ()
      }
      match
        bind_expected_enum_variant(
          typing, context, index, scope, name, args, expected_result, span, ast,
        ) {
        Some(expr) => return expr
        None => ()
      }
      let name_candidates = @semantic.find_functions_by_name(index, name)
      if name_candidates.length() > 0 {
        match
          choose_function(
            typing, context, name_candidates, scope, index, args, expected_result,
            span, ast,
          ) {
          Some(probe) => {
            let bound_args = bind_argument_plan(
              typing,
              context,
              index,
              scope,
              probe.argument_plan,
              ast,
            )
            return BoundExpr::Call(
              probe.callable.function_id,
              probe.callable.type_args,
              bound_trait_evidence(context, probe.callable.trait_evidence),
              bound_args,
              selected_call_intrinsic(probe, bound_args),
              probe.callable.return_type,
              span,
            )
          }
          None => ()
        }
      }
      match
        bind_named_static_receiver_call(
          typing, context, index, scope, name, name, args, expected_result, span,
          ast,
        ) {
        Some(expr) => expr
        None => BoundExpr::Error("unresolved call: " + name, error_type(), span)
      }
    }
    _ =>
      match
        bind_function_expression_call(
          typing, context, index, scope, callee, args, expected_result, span, ast,
        ) {
        Some(expr) => expr
        None => {
          context.error("VNX1200", "unsupported callee expression", span)
          BoundExpr::Error("unsupported callee expression", error_type(), span)
        }
      }
  }
}

///|
fn rollback_diagnostics(context : BindingContext, mark : Int) -> Unit {
  while context.diagnostics.length() > mark {
    ignore(context.diagnostics.pop())
  }
}

///|
fn bind_package_trait_method_call(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  package_alias : String,
  method_name : String,
  args : Array[CallArg],
  expected_result : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  if args.length() == 0 {
    return BoundExpr::Error(
      "unresolved package call: " + package_alias + "." + method_name,
      error_type(),
      span,
    )
  }
  let receiver = args[0].value
  let method_args : Array[CallArg] = []
  for i in 1..<args.length() {
    method_args.push(args[i])
  }
  bind_trait_method_call_with_package_alias(
    typing,
    context,
    index,
    scope,
    receiver,
    method_name,
    method_args,
    expected_result,
    span,
    ast,
    Some(package_alias),
  )
}

///|
fn bind_package_trait_method_call_if_available(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  package_alias : String,
  method_name : String,
  args : Array[CallArg],
  expected_result : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr? {
  if args.length() == 0 {
    return None
  }
  let diagnostic_mark = context.diagnostics.length()
  let expr = bind_package_trait_method_call(
    typing, context, index, scope, package_alias, method_name, args, expected_result,
    span, ast,
  )
  match expr {
    BoundExpr::Error(_, _, _) => {
      rollback_diagnostics(context, diagnostic_mark)
      None
    }
    _ => Some(expr)
  }
}

///|
fn bind_function_expression_call(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  callee : Expr,
  args : Array[CallArg],
  expected_result : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr? {
  let probe_typing = @semantic.typing_context()
  let probe_callee = bind_expr(
    probe_typing,
    diagnostic_free_context(context),
    index,
    scope,
    callee,
    error_type(),
    ast,
  )
  match
    @semantic.resolve_inferred_type(probe_typing, @ir.expr_type(probe_callee)) {
    TypeRef::Function(params, return_type, _) => {
      if args.length() != params.length() {
        return None
      }
      let bound_callee = bind_expr(
        typing,
        context,
        index,
        scope,
        callee,
        @ir.expr_type(probe_callee),
        ast,
      )
      let bound_args : Array[BoundExpr] = []
      for i in 0..<args.length() {
        if args[i].label is Some(_) {
          return None
        }
        bound_args.push(
          bind_expr(
            typing,
            context,
            index,
            scope,
            args[i].value,
            params[i].type_,
            ast,
          ),
        )
      }
      Some(
        apply_conversion(
          typing,
          context,
          BoundExpr::FunctionValueCall(
            bound_callee, bound_args, return_type, span,
          ),
          expected_result,
          span,
        ),
      )
    }
    _ => None
  }
}

///|
fn bind_function_value_call(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  name : String,
  args : Array[CallArg],
  expected_result : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr? {
  match lookup_symbol(scope, name) {
    Some(symbol) =>
      match symbol.type_ {
        TypeRef::Function(params, return_type, _) => {
          if args.length() != params.length() {
            return None
          }
          let bound_args : Array[BoundExpr] = []
          for i in 0..<args.length() {
            if args[i].label is Some(_) {
              return None
            }
            bound_args.push(
              bind_expr(
                typing,
                context,
                index,
                scope,
                args[i].value,
                params[i].type_,
                ast,
              ),
            )
          }
          let callee = BoundExpr::Name(
            symbol.id,
            symbol.name,
            symbol.type_,
            span,
          )
          Some(
            apply_conversion(
              typing,
              context,
              BoundExpr::FunctionValueCall(
                callee, bound_args, return_type, span,
              ),
              expected_result,
              span,
            ),
          )
        }
        _ => None
      }
    None => None
  }
}

///|
fn panic_result_type(typing : TypingContext, expected : TypeRef) -> TypeRef {
  let resolved = @semantic.resolve_inferred_type(typing, expected)
  if @semantic.unresolved_inference_type(resolved) {
    return @binding.unit_type()
  }
  match resolved {
    TypeRef::Error(_) => @binding.unit_type()
    _ => resolved
  }
}

///|
fn bind_receiver_function_call(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  receiver : Expr,
  method_name : String,
  args : Array[CallArg],
  expected_result : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr? {
  let probe_receiver = bind_expr(
    @semantic.typing_context(),
    diagnostic_free_context(context),
    index,
    scope,
    receiver,
    error_type(),
    ast,
  )
  let receiver_type = @ir.expr_type(probe_receiver)
  let exact_candidates = @semantic.find_receiver_functions_exact(
    index, receiver_type, method_name,
  )
  let candidates = if exact_candidates.length() > 0 {
    exact_candidates
  } else {
    @semantic.find_receiver_functions(index, receiver_type, method_name)
  }
  if candidates.length() == 0 {
    return None
  }
  let call_args : Array[CallArg] = [
    { label: None, value: receiver, span: @ast.expr_span(receiver) },
  ]
  for arg in args {
    call_args.push(arg)
  }
  let selected = choose_function(
    typing,
    diagnostic_free_context(context),
    candidates,
    scope,
    index,
    call_args,
    expected_result,
    span,
    ast,
  )
  match selected {
    Some(probe) => {
      let bound_args = bind_argument_plan(
        typing,
        context,
        index,
        scope,
        probe.argument_plan,
        ast,
      )
      Some(
        BoundExpr::Call(
          probe.callable.function_id,
          probe.callable.type_args,
          bound_trait_evidence(context, probe.callable.trait_evidence),
          bound_args,
          selected_call_intrinsic(probe, bound_args),
          probe.callable.return_type,
          span,
        ),
      )
    }
    None => None
  }
}

///|
fn selected_call_intrinsic(
  probe : CallableProbe,
  bound_args : Array[BoundExpr],
) -> String? {
  match probe.callable.function_intrinsic {
    Some(intrinsic) => Some(intrinsic)
    None =>
      if core_string_println_call(probe, bound_args) {
        Some("%println")
      } else {
        None
      }
  }
}

///|
fn core_string_println_call(
  probe : CallableProbe,
  bound_args : Array[BoundExpr],
) -> Bool {
  if bound_args.length() != 1 {
    return false
  }
  if probe.callable.function_id !=
    "fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:println" {
    return false
  }
  @binding.type_equal(@ir.expr_type(bound_args[0]), @binding.string_type())
}
