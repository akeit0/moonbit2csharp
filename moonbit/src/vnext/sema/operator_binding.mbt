///|
fn bind_unary_operator(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  op : String,
  value : Expr,
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  if op == "!" {
    return bind_bool_not_operator(
      typing, context, index, scope, value, span, ast,
    )
  }
  let args : Array[CallArg] = [{ label: None, value, span: expr_span(value) }]
  let self_type = unary_operator_self_type(context, index, scope, value, ast)
  match @semantic.unary_operator_key_from_token(op) {
    Some(key) =>
      match
        bind_type_param_operator_call(
          typing,
          context,
          index,
          scope,
          key,
          value,
          [],
          expected,
          span,
          ast,
        ) {
        Some(expr) => expr
        None =>
          match
            choose_operator(
              typing,
              diagnostic_free_context(context),
              index,
              scope,
              key,
              self_type,
              args,
              expected,
              span,
              ast,
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
              if bound_args.length() == 1 {
                BoundExpr::Unary(
                  op,
                  bound_args[0],
                  probe.callable.function_id,
                  selected_intrinsic(probe.callable),
                  probe.callable.return_type,
                  span,
                )
              } else {
                context.error(
                  "VNX1102", "invalid unary operator argument plan", span,
                )
                BoundExpr::Error(
                  "invalid unary operator argument plan",
                  error_type(),
                  span,
                )
              }
            }
            None =>
              bind_unsupported_unary_operator(
                typing, context, index, scope, op, value, span, ast,
              )
          }
      }
    None =>
      bind_unsupported_unary_operator(
        typing, context, index, scope, op, value, span, ast,
      )
  }
}

///|
fn bind_binary_operator(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  op : String,
  left : Expr,
  right : Expr,
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  if op == "<+" {
    return bind_logger_append_operator(
      typing, context, index, scope, left, right, span, ast,
    )
  }
  if op == "&&" || op == "||" {
    return bind_bool_logical_operator(
      typing, context, index, scope, op, left, right, span, ast,
    )
  }
  let args : Array[CallArg] = [
    { label: None, value: left, span: expr_span(left) },
    { label: None, value: right, span: expr_span(right) },
  ]
  let self_type = binary_operator_self_type(
    context, index, scope, left, right, ast,
  )
  match @semantic.binary_operator_key_from_token(op) {
    Some(key) =>
      match
        bind_type_param_operator_call(
          typing,
          context,
          index,
          scope,
          key,
          left,
          [{ label: None, value: right, span: expr_span(right) }],
          expected,
          span,
          ast,
        ) {
        Some(expr) => expr
        None =>
          match
            choose_operator(
              typing,
              diagnostic_free_context(context),
              index,
              scope,
              key,
              self_type,
              args,
              expected,
              span,
              ast,
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
              if bound_args.length() == 2 {
                BoundExpr::Binary(
                  op,
                  bound_args[0],
                  bound_args[1],
                  probe.callable.function_id,
                  probe.callable.type_args,
                  bound_trait_evidence(context, probe.callable.trait_evidence),
                  selected_intrinsic(probe.callable),
                  probe.callable.return_type,
                  span,
                )
              } else {
                context.error(
                  "VNX1101", "invalid binary operator argument plan", span,
                )
                BoundExpr::Error(
                  "invalid binary operator argument plan",
                  error_type(),
                  span,
                )
              }
            }
            None =>
              match
                bind_builtin_option_equality(
                  typing, context, index, scope, op, left, right, span, ast,
                ) {
                Some(expr) => expr
                None =>
                  bind_unsupported_binary_operator(
                    typing, context, index, scope, op, left, right, span, ast,
                  )
              }
          }
      }
    None =>
      bind_unsupported_binary_operator(
        typing, context, index, scope, op, left, right, span, ast,
      )
  }
}

///|
fn bind_logger_append_operator(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target : Expr,
  value : Expr,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  bind_expr(
    typing,
    context,
    index,
    scope,
    logger_append_expr(target, value, span),
    unit_type(),
    ast,
  )
}

///|
fn logger_append_expr(target : Expr, value : Expr, span : SourceSpan) -> Expr {
  match value {
    Expr::InterpolatedString(parts, _) => {
      let calls : Array[Expr] = []
      for part in parts {
        match part {
          @ast.StringPart::Text(text) =>
            if text.length() > 0 {
              calls.push(
                logger_append_call(
                  target,
                  "write_string",
                  Expr::StringLiteral(text, span),
                  span,
                ),
              )
            }
          @ast.StringPart::Expr(expr) =>
            calls.push(logger_append_call(target, "write_object", expr, span))
          @ast.StringPart::WriteTo(name, expr) =>
            calls.push(logger_append_write_to(target, name, expr, span))
        }
      }
      sequence_exprs(calls, span)
    }
    Expr::StringLiteral(_, _) =>
      logger_append_call(target, "write_string", value, span)
    Expr::CharLiteral(_, _) =>
      logger_append_call(target, "write_char", value, span)
    _ => logger_append_call(target, "write_object", value, span)
  }
}

///|
fn logger_append_write_to(
  target : Expr,
  name : String,
  expr : Expr,
  span : SourceSpan,
) -> Expr {
  Expr::LocalLet(name, None, target, expr, span)
}

///|
fn logger_append_call(
  target : Expr,
  method_name : String,
  value : Expr,
  span : SourceSpan,
) -> Expr {
  Expr::Call(
    Expr::FieldAccess(target, method_name, span),
    [{ label: None, value, span }],
    span,
  )
}

///|
fn sequence_exprs(items : Array[Expr], span : SourceSpan) -> Expr {
  if items.length() == 0 {
    return Expr::UnitLiteral(span)
  }
  let mut result = items[items.length() - 1]
  let mut index = items.length() - 2
  while index >= 0 {
    result = Expr::Sequence(items[index], result, span)
    index = index - 1
  }
  result
}

///|
fn bind_type_param_operator_call(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  key : @semantic.OperatorKey,
  receiver : Expr,
  args : Array[CallArg],
  expected_result : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr? {
  let receiver_probe = bind_expr(
    @semantic.typing_context(),
    diagnostic_free_context(context),
    index,
    scope,
    receiver,
    @semantic.local_inference_type(
      "operator-receiver:" + span.start.to_string(),
    ),
    ast,
  )
  let receiver_type = @ir.expr_type(receiver_probe)
  match receiver_type {
    TypeRef::TypeParameter(type_param_name, _) => {
      let binding = @semantic.operator_trait_binding(key, receiver_type)
      match
        trait_method_selection_from_type_param_trait(
          context,
          index,
          type_param_name,
          receiver_type,
          binding.trait_symbol,
          binding.method_name,
        ) {
        Some(selection) => {
          let parameters = trait_method_parameters(
            selection.method_id,
            selection.parameters,
            selection.self_type,
            span,
          )
          match
            choose_trait_method_arguments(
              typing,
              context,
              index,
              scope,
              parameters,
              args,
              selection.return_type,
              expected_result,
              span,
              ast,
            ) {
            Some(plan) => {
              let bound_receiver = bind_expr(
                typing,
                context,
                index,
                scope,
                receiver,
                selection.self_type,
                ast,
              )
              let bound_args = bind_argument_plan(
                typing, context, index, scope, plan, ast,
              )
              Some(
                BoundExpr::TraitMethodCall(
                  bound_receiver,
                  selection.trait_ref,
                  selection.method_id,
                  binding.method_name,
                  bound_args,
                  selection.dispatch,
                  selection.return_type,
                  span,
                ),
              )
            }
            None => None
          }
        }
        None => None
      }
    }
    _ => None
  }
}

///|
fn bind_builtin_option_equality(
  typing : TypingContext,
  _context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  op : String,
  left : Expr,
  right : Expr,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr? {
  if op != "==" && op != "!=" {
    return None
  }
  let probe_typing = @semantic.typing_context()
  let probe_context = diagnostic_free_context(_context)
  let left_probe = bind_expr(
    probe_typing,
    probe_context,
    index,
    scope,
    left,
    error_type(),
    ast,
  )
  let left_type = @ir.expr_type(left_probe)
  let _right_probe = bind_expr(
    probe_typing, probe_context, index, scope, right, left_type, ast,
  )
  let option_type = @semantic.resolve_inferred_type(probe_typing, left_type)
  if !is_option_type(option_type) {
    return None
  }
  let left_bound = bind_expr(
    typing, _context, index, scope, left, option_type, ast,
  )
  let right_bound = bind_expr(
    typing, _context, index, scope, right, option_type, ast,
  )
  Some(
    BoundExpr::Binary(
      op,
      left_bound,
      right_bound,
      "builtin:option:" + op,
      [],
      [],
      if op == "==" {
        Some("%option_eq")
      } else {
        Some("%option_ne")
      },
      bool_type(),
      span,
    ),
  )
}

///|
fn bind_bool_not_operator(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  value : Expr,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let bound_value = bind_expr(
    typing,
    context,
    index,
    scope,
    value,
    bool_type(),
    ast,
  )
  BoundExpr::Unary("!", bound_value, "", Some("%bool_not"), bool_type(), span)
}

///|
fn bind_bool_logical_operator(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  op : String,
  left : Expr,
  right : Expr,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let (left_bound, left_symbols) = if op == "&&" {
    bind_if_condition(context, index, scope, left, ast)
  } else {
    (bind_expr(typing, context, index, scope, left, bool_type(), ast), [])
  }
  let right_scope = if op == "&&" {
    scope_with_pattern_symbols(scope, left_symbols)
  } else {
    scope
  }
  let right_bound = bind_expr(
    typing,
    context,
    index,
    right_scope,
    right,
    bool_type(),
    ast,
  )
  BoundExpr::Binary(
    op,
    left_bound,
    right_bound,
    "",
    [],
    [],
    None,
    bool_type(),
    span,
  )
}

///|
fn bind_unsupported_unary_operator(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  op : String,
  value : Expr,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let bound_value = bind_expr(
    typing,
    context,
    index,
    scope,
    value,
    error_type(),
    ast,
  )
  context.error("VNX1102", "unsupported unary operator", span)
  BoundExpr::Unary(op, bound_value, "", None, error_type(), span)
}

///|
fn bind_unsupported_binary_operator(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  op : String,
  left : Expr,
  right : Expr,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let left_bound = bind_expr(
    typing,
    context,
    index,
    scope,
    left,
    error_type(),
    ast,
  )
  let right_bound = bind_expr(
    typing,
    context,
    index,
    scope,
    right,
    error_type(),
    ast,
  )
  context.error(
    "VNX1101",
    "unsupported binary operator `" +
    op +
    "` for " +
    diagnostic_type_name(
      @semantic.resolve_inferred_type(typing, @ir.expr_type(left_bound)),
    ) +
    " and " +
    diagnostic_type_name(
      @semantic.resolve_inferred_type(typing, @ir.expr_type(right_bound)),
    ),
    span,
  )
  BoundExpr::Binary(
    op,
    left_bound,
    right_bound,
    "",
    [],
    [],
    None,
    error_type(),
    span,
  )
}

///|
fn unary_operator_self_type(
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  value : Expr,
  ast : Module,
) -> TypeRef {
  let probe = bind_expr(
    @semantic.typing_context(),
    diagnostic_free_context(context),
    index,
    scope,
    value,
    error_type(),
    ast,
  )
  @ir.expr_type(probe)
}

///|
fn selected_intrinsic(callable : @semantic.SelectedCallable) -> String? {
  match callable.method_body {
    Some(@semantic.ImplMethodBody::Intrinsic(intrinsic)) => Some(intrinsic)
    _ => None
  }
}

///|
fn binary_operator_self_type(
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  left : Expr,
  right : Expr,
  ast : Module,
) -> TypeRef {
  match left {
    Expr::FloatLiteral(_, _) => {
      let right_probe = bind_expr(
        @semantic.typing_context(),
        diagnostic_free_context(context),
        index,
        scope,
        right,
        error_type(),
        ast,
      )
      let right_type = @ir.expr_type(right_probe)
      if @binding.type_equal(right_type, double_type()) ||
        @binding.type_equal(right_type, float_type()) {
        return right_type
      }
    }
    _ => ()
  }
  let left_probe = bind_expr(
    @semantic.typing_context(),
    diagnostic_free_context(context),
    index,
    scope,
    left,
    error_type(),
    ast,
  )
  @ir.expr_type(left_probe)
}
