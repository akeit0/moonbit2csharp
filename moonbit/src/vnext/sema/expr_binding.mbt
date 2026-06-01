///|
fn bind_expr(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  expr : Expr,
  expected : TypeRef,
  ast : Module,
) -> BoundExpr {
  match expr {
    Expr::Name(name, span) =>
      match lookup_symbol(scope, name) {
        Some(symbol) =>
          apply_conversion(
            typing,
            context,
            BoundExpr::Name(symbol.id, symbol.name, symbol.type_, span),
            expected,
            span,
          )
        None =>
          match lookup_value_symbol(index, name) {
            Some(symbol) =>
              apply_conversion(
                typing,
                context,
                BoundExpr::Name(symbol.id, symbol.name, symbol.type_, span),
                expected,
                span,
              )
            None =>
              if name == "None" {
                match none_expected_type(typing, expected, span) {
                  Some(option_type) => BoundExpr::OptionNone(option_type, span)
                  None => {
                    context.error("VNX1100", "unknown name: " + name, span)
                    BoundExpr::Error(
                      "unknown name: " + name,
                      error_type(),
                      span,
                    )
                  }
                }
              } else {
                match
                  bind_expected_enum_variant(
                    typing,
                    context,
                    index,
                    scope,
                    name,
                    [],
                    expected,
                    span,
                    ast,
                  ) {
                  Some(expr) => expr
                  None =>
                    match
                      bind_function_value_reference(
                        typing, index, name, expected, span,
                      ) {
                      Some(expr) => expr
                      None => {
                        context.error("VNX1100", "unknown name: " + name, span)
                        BoundExpr::Error(
                          "unknown name: " + name,
                          error_type(),
                          span,
                        )
                      }
                    }
                }
              }
          }
      }
    Expr::IntLiteral(value, span) =>
      apply_conversion(
        typing,
        context,
        BoundExpr::IntLiteral(value, int_literal_type(value, expected), span),
        expected,
        span,
      )
    Expr::FloatLiteral(value, span) =>
      apply_conversion(
        typing,
        context,
        BoundExpr::FloatLiteral(value, float_literal_type(expected), span),
        expected,
        span,
      )
    Expr::CharLiteral(value, span) =>
      bind_char_literal(typing, context, value, expected, span)
    Expr::StringLiteral(value, span) =>
      apply_conversion(
        typing,
        context,
        BoundExpr::StringLiteral(value, string_type(), span),
        expected,
        span,
      )
    Expr::BytesLiteral(value, span) =>
      apply_conversion(
        typing,
        context,
        BoundExpr::BytesLiteral(value, @binding.TypeRef::Builtin("Bytes"), span),
        expected,
        span,
      )
    Expr::InterpolatedString(parts, span) =>
      apply_conversion(
        typing,
        context,
        bind_interpolated_string(
          typing, context, index, scope, parts, span, ast,
        ),
        expected,
        span,
      )
    Expr::BoolLiteral(value, span) =>
      apply_conversion(
        typing,
        context,
        BoundExpr::BoolLiteral(value, bool_type(), span),
        expected,
        span,
      )
    Expr::EmptyBraceLiteral(span) =>
      bind_empty_brace_literal(
        typing, context, index, scope, expected, span, ast,
      )
    Expr::TupleLiteral(items, span) =>
      apply_conversion(
        typing,
        context,
        bind_tuple_literal(
          typing, context, index, scope, items, expected, span, ast,
        ),
        expected,
        span,
      )
    Expr::UnitLiteral(span) =>
      apply_conversion(
        typing,
        context,
        BoundExpr::UnitLiteral(unit_type(), span),
        expected,
        span,
      )
    Expr::LocalLet(name, explicit_type, value, body, span) =>
      bind_local_let(
        typing, context, index, scope, name, explicit_type, value, body, expected,
        span, ast,
      )
    Expr::LocalLetPattern(pattern, value, body, span) =>
      bind_local_let_pattern(
        typing, context, index, scope, pattern, value, body, expected, span, ast,
      )
    Expr::LocalFunction(function, body, span) =>
      bind_local_function(
        typing, context, index, scope, function, body, expected, span, ast,
      )
    Expr::Sequence(first, body, span) =>
      bind_sequence_expr(
        typing, context, index, scope, first, body, expected, span, ast,
      )
    Expr::Call(callee, args, span) =>
      apply_conversion(
        typing,
        context,
        bind_call(
          typing, context, index, scope, callee, args, expected, span, ast,
        ),
        expected,
        span,
      )
    Expr::Index(target, index_expr, end_index, is_slice, span) =>
      apply_conversion(
        typing,
        context,
        bind_index_get(
          typing, context, index, scope, target, index_expr, end_index, is_slice,
          span, ast,
        ),
        expected,
        span,
      )
    Expr::PackageAccess(package_alias, name, span) =>
      match @semantic.find_global_by_package_alias(index, package_alias, name) {
        Some(symbol) =>
          apply_conversion(
            typing,
            context,
            BoundExpr::Name(symbol.id, symbol.name, symbol.type_, span),
            expected,
            span,
          )
        None =>
          BoundExpr::Error(
            "unknown package value: " + package_alias + "." + name,
            error_type(),
            span,
          )
      }
    Expr::StaticAccess(target, member_name, span) =>
      apply_conversion(
        typing,
        context,
        bind_static_access(
          typing,
          context,
          index,
          scope,
          target,
          member_name,
          [],
          expected,
          span,
          ast,
        ),
        expected,
        span,
      )
    Expr::FieldAccess(target, field_name, span) =>
      apply_conversion(
        typing,
        context,
        bind_field_access(
          typing, context, index, scope, target, field_name, span, ast,
        ),
        expected,
        span,
      )
    Expr::Assign(target, value, span) =>
      apply_conversion(
        typing,
        context,
        bind_assignment(typing, context, index, scope, target, value, span, ast),
        expected,
        span,
      )
    Expr::If(condition, then_, else_, span) =>
      apply_conversion(
        typing,
        context,
        bind_if_expr(
          typing, context, index, scope, condition, then_, else_, expected, span,
          ast,
        ),
        expected,
        span,
      )
    Expr::ArrayLiteral(items, span) =>
      bind_array_literal(
        typing, context, index, scope, items, expected, span, ast,
      )
    Expr::MapLiteral(entries, span) =>
      bind_map_literal(
        typing, context, index, scope, entries, expected, span, ast,
      )
    Expr::StructLiteral(fields, span) =>
      bind_struct_literal(
        typing, context, index, scope, fields, expected, span, ast,
      )
    Expr::TypedStructLiteral(type_syntax, fields, span) => {
      let declared_type = resolve_type(context, index, type_syntax)
      bind_struct_literal(
        typing, context, index, scope, fields, declared_type, span, ast,
      )
    }
    Expr::StructUpdateLiteral(base, fields, span) =>
      bind_struct_update_literal(
        typing, context, index, scope, base, fields, expected, span, ast,
      )
    Expr::TypeAscription(value, type_syntax, span) => {
      let declared_type = resolve_type(context, index, type_syntax)
      apply_conversion(
        typing,
        context,
        bind_expr(typing, context, index, scope, value, declared_type, ast),
        expected,
        span,
      )
    }
    Expr::Lambda(params, body, span) =>
      bind_lambda(
        typing, context, index, scope, params, body, expected, span, ast,
      )
    Expr::Unary(op, value, span) =>
      apply_conversion(
        typing,
        context,
        bind_unary_operator(
          typing, context, index, scope, op, value, expected, span, ast,
        ),
        expected,
        span,
      )
    Expr::Binary(op, left, right, span) =>
      apply_conversion(
        typing,
        context,
        bind_binary_operator(
          typing, context, index, scope, op, left, right, expected, span, ast,
        ),
        expected,
        span,
      )
    Expr::IsPattern(target, pattern, span) =>
      apply_conversion(
        typing,
        context,
        bind_is_pattern(context, index, scope, target, pattern, span, ast),
        expected,
        span,
      )
    Expr::Match(target, arms, span) =>
      apply_conversion(
        typing,
        context,
        bind_match(
          typing, context, index, scope, target, arms, expected, span, ast,
        ),
        expected,
        span,
      )
    Expr::Raise(value, span) =>
      bind_raise(typing, context, index, scope, value, expected, span, ast)
    Expr::TryCatch(body, arms, span) =>
      apply_conversion(
        typing,
        context,
        bind_try_catch(
          typing, context, index, scope, body, arms, expected, span, ast,
        ),
        expected,
        span,
      )
    Expr::Guard(condition, else_, span) =>
      bind_guard_expr(
        typing, context, index, scope, condition, else_, span, ast,
      )
    Expr::While(condition, body, span) =>
      apply_conversion(
        typing,
        context,
        bind_while(typing, context, index, scope, condition, body, span, ast),
        expected,
        span,
      )
    Expr::ForIn(names, value, bindings, body, no_break_expr, span) =>
      apply_conversion(
        typing,
        context,
        bind_for_in(
          typing, context, index, scope, names, value, bindings, body, no_break_expr,
          expected, span, ast,
        ),
        expected,
        span,
      )
    Expr::Pipe(left, right, forward, span) =>
      bind_expr(
        typing,
        context,
        index,
        scope,
        lower_pipe_expr(left, right, forward, span),
        expected,
        ast,
      )
    Expr::ForRange(
      name,
      start,
      range_kind,
      end_,
      bindings,
      body,
      no_break_expr,
      span
    ) =>
      apply_conversion(
        typing,
        context,
        bind_for_range(
          typing, context, index, scope, name, start, range_kind, end_, bindings,
          body, no_break_expr, span, ast,
        ),
        expected,
        span,
      )
    Expr::ForLoop(bindings, condition, updates, body, no_break_expr, span) =>
      apply_conversion(
        typing,
        context,
        bind_for_loop(
          typing, context, index, scope, bindings, condition, updates, body, no_break_expr,
          expected, span, ast,
        ),
        expected,
        span,
      )
    Expr::Break(value, span) =>
      apply_conversion(
        typing,
        context,
        bind_break(typing, context, index, scope, value, span, ast),
        expected,
        span,
      )
    Expr::Continue(args, span) =>
      apply_conversion(
        typing,
        context,
        bind_continue(typing, context, index, scope, args, span, ast),
        expected,
        span,
      )
    Expr::Return(value, span) =>
      bind_return_expr(typing, context, index, scope, value, span, ast)
    Expr::Missing(span) =>
      BoundExpr::Error("missing expression", error_type(), span)
  }
}

///|
fn bind_empty_brace_literal(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let resolved_expected = @semantic.resolve_inferred_type(typing, expected)
  match resolved_expected {
    TypeRef::Apply(TypeConstructorRef::Builtin("Map"), [_, _]) =>
      bind_map_literal(typing, context, index, scope, [], expected, span, ast)
    TypeRef::Declared(_, _) =>
      bind_struct_literal(
        typing,
        context,
        index,
        scope,
        [],
        expected,
        span,
        ast,
      )
    TypeRef::Builtin("Unit") | TypeRef::Error(_) =>
      BoundExpr::UnitLiteral(unit_type(), span)
    _ =>
      apply_conversion(
        typing,
        context,
        BoundExpr::UnitLiteral(unit_type(), span),
        expected,
        span,
      )
  }
}

///|
fn bind_raise(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  value : Expr,
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let error_type = match context.current_effect {
    @binding.EffectRef::Raises(error_type) => error_type
    _ => TypeRef::Builtin("Error")
  }
  let bound_value = bind_expr(
    typing, context, index, scope, value, error_type, ast,
  )
  let show_object = if error_type == TypeRef::Builtin("Error") {
    raised_error_show_object(typing, context, index, bound_value, span)
  } else {
    None
  }
  let type_ = match @semantic.resolve_inferred_type(typing, expected) {
    TypeRef::Error(_) => unit_type()
    other => other
  }
  BoundExpr::Raise(bound_value, show_object, type_, span)
}

///|
fn raised_error_show_object(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  value : BoundExpr,
  span : SourceSpan,
) -> BoundExpr? {
  match @semantic.find_visible_trait(index, None, "Show") {
    Some(trait_def) => {
      let value_type = @semantic.resolve_inferred_type(
        typing,
        @ir.expr_type(value),
      )
      match find_impl_evidence_for_trait(index, trait_def, value_type) {
        Some(_) => ()
        None => return None
      }
      let show_type = TypeRef::TraitObject({
        trait_: trait_def.symbol,
        args: [],
      })
      mark_used_trait_object_conversion(context, index, show_type, value_type)
      Some(apply_conversion(typing, context, value, show_type, span))
    }
    None => None
  }
}

///|
fn bind_try_catch(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  body : Expr,
  arms : Array[@ast.MatchArm],
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let result_type = match_result_inference_type(typing, expected, span)
  let bound_body = bind_expr(
    typing, context, index, scope, body, result_type, ast,
  )
  let error_target_type = catch_error_type(index, bound_body)
  let bound_arms : Array[@ir.BoundMatchArm] = []
  for arm in arms {
    let (pattern, arm_scope) = bind_match_pattern(
      context,
      index,
      scope,
      error_target_type,
      arm.pattern,
    )
    let arm_body = bind_expr(
      typing,
      context,
      index,
      arm_scope,
      arm.body,
      @semantic.resolve_inferred_type(typing, result_type),
      ast,
    )
    if !terminal_control_expr(arm_body) {
      ignore(
        @semantic.unify_types(typing, result_type, @ir.expr_type(arm_body)),
      )
    }
    bound_arms.push({ pattern, condition: None, body: arm_body })
  }
  BoundExpr::TryCatch(
    bound_body,
    bound_arms,
    @semantic.resolve_inferred_type(typing, result_type),
    span,
  )
}

///|
fn catch_error_type(index : DeclarationIndex, body : BoundExpr) -> TypeRef {
  match body {
    BoundExpr::Call(function_id, _, _, _, _, _, _) =>
      match @semantic.find_function(index, function_id) {
        Some(signature) =>
          match signature.effect {
            @binding.EffectRef::Raises(error_type) => error_type
            _ => TypeRef::Builtin("Error")
          }
        None => TypeRef::Builtin("Error")
      }
    _ => TypeRef::Builtin("Error")
  }
}

///|
fn int_literal_type(value : String, expected : TypeRef) -> TypeRef {
  if value.has_suffix("UL") ||
    value.has_suffix("ul") ||
    value.has_suffix("uL") ||
    value.has_suffix("Ul") {
    TypeRef::Builtin("UInt64")
  } else if value.has_suffix("L") || value.has_suffix("l") {
    TypeRef::Builtin("Int64")
  } else if value.has_suffix("U") || value.has_suffix("u") {
    TypeRef::Builtin("UInt")
  } else {
    match expected {
      TypeRef::Builtin(name) =>
        if name
          is ("Byte" | "Int" | "Int16" | "Int64" | "UInt" | "UInt16" | "UInt64") {
          expected
        } else {
          int_type()
        }
      _ => int_type()
    }
  }
}

///|
fn float_literal_type(expected : TypeRef) -> TypeRef {
  if @binding.type_equal(expected, float_type()) {
    float_type()
  } else {
    double_type()
  }
}

///|
fn bind_function_value_reference(
  typing : TypingContext,
  index : DeclarationIndex,
  name : String,
  expected : TypeRef,
  span : SourceSpan,
) -> BoundExpr? {
  let candidates = @semantic.find_functions_by_name(index, name)
  let matches : Array[BoundExpr] = []
  for candidate in candidates {
    let function_type = function_signature_type(candidate)
    let probe = @semantic.typing_context()
    if @semantic.unify_types(probe, expected, function_type) {
      matches.push(
        BoundExpr::FunctionRef(
          candidate.function_id,
          candidate.name,
          @semantic.resolve_inferred_type(typing, function_type),
          span,
        ),
      )
    }
  }
  if matches.length() == 1 {
    Some(matches[0])
  } else {
    None
  }
}

///|
fn function_signature_type(signature : FunctionSignature) -> TypeRef {
  let params : Array[@binding.ParamTypeRef] = []
  for param in signature.parameters {
    params.push({
      label: param.label,
      type_: param.symbol.type_,
      optional: param.optional,
      has_default: param.has_default,
    })
  }
  TypeRef::Function(params, signature.return_type, signature.effect)
}

///|
fn bind_interpolated_string(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  parts : Array[@ast.StringPart],
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let mut result : BoundExpr? = None
  for part in parts {
    let bound_part = match part {
      @ast.StringPart::Text(text) =>
        BoundExpr::StringLiteral(text, string_type(), span)
      @ast.StringPart::Expr(expr) =>
        bind_interpolated_expr(typing, context, index, scope, expr, span, ast)
      @ast.StringPart::WriteTo(_, expr) =>
        bind_expr(typing, context, index, scope, expr, unit_type(), ast)
    }
    result = match result {
      Some(left) =>
        Some(bound_string_concat(context, index, left, bound_part, span))
      None => Some(bound_part)
    }
  }
  match result {
    Some(expr) => expr
    None => BoundExpr::StringLiteral("", string_type(), span)
  }
}

///|
fn bind_interpolated_expr(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  expr : @ast.Expr,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let bound = bind_expr(
    @semantic.typing_context(),
    diagnostic_free_context(context),
    index,
    scope,
    expr,
    error_type(),
    ast,
  )
  if @binding.type_equal(@ir.expr_type(bound), string_type()) {
    return bind_expr(typing, context, index, scope, expr, string_type(), ast)
  }
  bind_trait_method_call(
    typing,
    context,
    index,
    scope,
    expr,
    "to_string",
    [],
    string_type(),
    span,
    ast,
  )
}

///|
fn bound_string_concat(
  context : BindingContext,
  index : DeclarationIndex,
  left : BoundExpr,
  right : BoundExpr,
  span : SourceSpan,
) -> BoundExpr {
  match @semantic.binary_operator_key_from_token("+") {
    Some(key) =>
      match @semantic.find_operator_candidate(index, key, string_type()) {
        Some(candidate) =>
          BoundExpr::Binary(
            "+",
            left,
            right,
            candidate.signature.function_id,
            [],
            [],
            selected_intrinsic_from_body(candidate.method_body),
            string_type(),
            span,
          )
        None => {
          context.error(
            "VNX1201", "no string concat operator implementation", span,
          )
          BoundExpr::Error("no string concat operator", error_type(), span)
        }
      }
    None => {
      context.error("VNX1101", "unsupported binary operator", span)
      BoundExpr::Error("unsupported string concat operator", error_type(), span)
    }
  }
}

///|
fn selected_intrinsic_from_body(body : @semantic.ImplMethodBody) -> String? {
  match body {
    @semantic.ImplMethodBody::Intrinsic(intrinsic) => Some(intrinsic)
    _ => None
  }
}

///|
fn lower_pipe_expr(
  left : Expr,
  right : Expr,
  forward : Bool,
  span : @common.SourceSpan,
) -> Expr {
  if forward {
    pipe_call(right, left, true, span)
  } else {
    pipe_call(left, right, false, span)
  }
}

///|
fn pipe_call(
  callee_or_call : Expr,
  piped_value : Expr,
  prepend : Bool,
  span : @common.SourceSpan,
) -> Expr {
  match callee_or_call {
    Expr::Call(callee, args, call_span) => {
      let lowered_args : Array[CallArg] = []
      if prepend {
        lowered_args.push({
          label: None,
          value: piped_value,
          span: @ast.expr_span(piped_value),
        })
      }
      for arg in args {
        lowered_args.push(arg)
      }
      if !prepend {
        lowered_args.push({
          label: None,
          value: piped_value,
          span: @ast.expr_span(piped_value),
        })
      }
      Expr::Call(callee, lowered_args, merge_ast_span(span, call_span))
    }
    _ =>
      Expr::Call(
        callee_or_call,
        [{ label: None, value: piped_value, span: @ast.expr_span(piped_value) }],
        span,
      )
  }
}

///|
fn bind_guard_expr(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  condition : Expr,
  else_ : Expr,
  span : @common.SourceSpan,
  ast : Module,
) -> BoundExpr {
  let bound_condition = bind_expr(
    typing,
    context,
    index,
    scope,
    condition,
    bool_type(),
    ast,
  )
  let else_type = match context.current_return_type {
    Some(return_type) =>
      if ast_terminal_control_expr(else_) {
        error_type()
      } else {
        return_type
      }
    None => unit_type()
  }
  let bound_else = bind_expr(
    typing, context, index, scope, else_, else_type, ast,
  )
  BoundExpr::Guard(bound_condition, bound_else, unit_type(), span)
}

///|
fn bind_sequence_expr(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  first : Expr,
  body : Expr,
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let (bound_first, body_scope) = match first {
    Expr::Guard(condition, else_, guard_span) =>
      bind_guard_sequence_prefix(
        typing, context, index, scope, condition, else_, guard_span, ast,
      )
    _ =>
      (bind_expr(typing, context, index, scope, first, unit_type(), ast), scope)
  }
  let bound_body = bind_expr(
    typing, context, index, body_scope, body, expected, ast,
  )
  BoundExpr::Sequence(bound_first, bound_body, @ir.expr_type(bound_body), span)
}

///|
fn bind_guard_sequence_prefix(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  condition : Expr,
  else_ : Expr,
  span : SourceSpan,
  ast : Module,
) -> (BoundExpr, Array[Symbol]) {
  let (bound_condition, condition_symbols) = bind_if_condition(
    context, index, scope, condition, ast,
  )
  let else_type = match context.current_return_type {
    Some(return_type) =>
      if ast_terminal_control_expr(else_) {
        error_type()
      } else {
        return_type
      }
    None => unit_type()
  }
  let bound_else = bind_expr(
    typing, context, index, scope, else_, else_type, ast,
  )
  let body_scope = scope_with_pattern_symbols(scope, condition_symbols)
  (BoundExpr::Guard(bound_condition, bound_else, unit_type(), span), body_scope)
}

///|
fn ast_terminal_control_expr(expr : Expr) -> Bool {
  match expr {
    Expr::Break(_, _) | Expr::Continue(_, _) | Expr::Return(_, _) => true
    Expr::Sequence(first, body, _) =>
      ast_terminal_control_expr(first) || ast_terminal_control_expr(body)
    _ => false
  }
}

///|
fn scope_with_pattern_symbols(
  scope : Array[Symbol],
  symbols : Array[Symbol],
) -> Array[Symbol] {
  let next_scope = scope.copy()
  for symbol in symbols {
    if symbol.name != "_" {
      next_scope.push(symbol)
    }
  }
  next_scope
}

///|
fn bind_char_literal(
  typing : TypingContext,
  context : BindingContext,
  value : String,
  expected : TypeRef,
  span : SourceSpan,
) -> BoundExpr {
  let resolved_expected = @semantic.resolve_inferred_type(typing, expected)
  let literal_type = match resolved_expected {
    TypeRef::Builtin("UInt16") => resolved_expected
    _ => @binding.char_type()
  }
  apply_conversion(
    typing,
    context,
    BoundExpr::CharLiteral(value, literal_type, span),
    expected,
    span,
  )
}

///|
fn bind_return_expr(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  value : Expr?,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let return_type = match context.current_return_type {
    Some(type_) => type_
    None => unit_type()
  }
  let bound_value = match value {
    Some(expr) =>
      Some(bind_expr(typing, context, index, scope, expr, return_type, ast))
    None => None
  }
  BoundExpr::Return(bound_value, unit_type(), span)
}

///|
fn bind_tuple_literal(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  items : Array[Expr],
  expected : TypeRef,
  span : @common.SourceSpan,
  ast : Module,
) -> BoundExpr {
  let expected_items = match @semantic.resolve_inferred_type(typing, expected) {
    TypeRef::Tuple(item_types) => item_types
    _ => []
  }
  let bound_items : Array[BoundExpr] = []
  let item_types = FixedArray::make(items.length(), @binding.unresolved_type_ref())
  for i in 0..<items.length() {
    let item_expected = if i < expected_items.length() {
      expected_items[i]
    } else {
      @semantic.inference_type(
        "tuple-item:" + span.start.to_string() + ":" + i.to_string(),
      )
    }
    let item = bind_expr(
      typing,
      context,
      index,
      scope,
      items[i],
      item_expected,
      ast,
    )
    bound_items.push(item)
    item_types[i] = @semantic.resolve_inferred_type(typing, @ir.expr_type(item))
  }
  BoundExpr::TupleLiteral(bound_items, TypeRef::Tuple(item_types), span)
}

///|
fn bind_local_let_pattern(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  pattern : @ast.Pattern,
  value : Expr,
  body : Expr,
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  match pattern {
    @ast.Pattern::Tuple(items, _) =>
      bind_tuple_local_let(
        typing, context, index, scope, items, value, body, expected, span, ast,
      )
    @ast.Pattern::Constructor(type_syntax, name, payloads, _) =>
      bind_constructor_local_let(
        typing, context, index, scope, type_syntax, name, payloads, value, body,
        expected, span, ast,
      )
    @ast.Pattern::Wildcard(_) => {
      let bound_value = bind_expr(
        typing,
        context,
        index,
        scope,
        value,
        error_type(),
        ast,
      )
      let bound_body = bind_expr(
        typing, context, index, scope, body, expected, ast,
      )
      BoundExpr::Sequence(
        bound_value,
        bound_body,
        @ir.expr_type(bound_body),
        span,
      )
    }
    _ => {
      context.error(
        "VNX1908", "only tuple destructuring local lets are supported in vnext",
        span,
      )
      BoundExpr::Error(
        "unsupported destructuring local let",
        error_type(),
        span,
      )
    }
  }
}

///|
fn bind_constructor_local_let(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  type_syntax : @ast.TypeSyntax?,
  name : String,
  payloads : Array[@ast.Pattern],
  value : Expr,
  body : Expr,
  expected : TypeRef,
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
  let value_type = @semantic.resolve_inferred_type(
    typing,
    @ir.expr_type(bound_value),
  )
  match constructor_local_struct_def(index, value_type, type_syntax, name) {
    Some((_, fields, type_params, args)) => {
      if payloads.length() != fields.length() {
        context.error(
          "VNX1908", "constructor destructuring arity mismatch", span,
        )
      }
      let owner = local_owner_id(context, scope)
      let temp_name = "__struct_" + span.start.to_string()
      let temp_symbol : Symbol = {
        id: local_id(owner, temp_name, span.start),
        kind: SymbolKind::Local,
        name: temp_name,
        type_: value_type,
        span,
      }
      let next_scope = scope.copy()
      next_scope.push(temp_symbol)
      let bindings : Array[StructLocalBinding] = []
      let limit = if payloads.length() < fields.length() {
        payloads.length()
      } else {
        fields.length()
      }
      for i in 0..<limit {
        collect_struct_local_binding(
          context,
          owner,
          bindings,
          payloads[i],
          fields[i],
          @semantic.substitute_type(type_params, args, fields[i].type_),
          span,
        )
      }
      for binding in bindings {
        next_scope.push(binding.symbol)
      }
      let bound_body = bind_expr(
        typing, context, index, next_scope, body, expected, ast,
      )
      BoundExpr::LocalLet(
        {
          symbol_id: temp_symbol.id,
          name: temp_symbol.name,
          type_: temp_symbol.type_,
          value: bound_value,
        },
        wrap_struct_local_bindings(temp_symbol, bindings, bound_body, span),
        @ir.expr_type(bound_body),
        span,
      )
    }
    None => {
      context.error(
        "VNX1908", "constructor destructuring target must be a struct", span,
      )
      BoundExpr::Error(
        "unsupported constructor destructuring local let",
        error_type(),
        span,
      )
    }
  }
}

///|
fn constructor_local_struct_def(
  index : DeclarationIndex,
  value_type : TypeRef,
  type_syntax : @ast.TypeSyntax?,
  name : String,
) -> (String, Array[FieldDef], FixedArray[String], FixedArray[TypeRef])? {
  match value_type {
    TypeRef::Declared(symbol, args) =>
      match @semantic.find_type_definition(index, symbol.id) {
        Some(TypeDefinition::Struct(def)) =>
          if constructor_pattern_matches_struct(symbol.name, type_syntax, name) {
            Some((symbol.id, def.fields, def.type_params, args))
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn constructor_pattern_matches_struct(
  type_name : String,
  type_syntax : @ast.TypeSyntax?,
  name : String,
) -> Bool {
  match type_syntax {
    Some(type_) => type_.name == type_name && name == type_name
    None => name == type_name
  }
}

///|
priv struct StructLocalBinding {
  symbol : Symbol
  field : FieldDef
}

///|
fn collect_struct_local_binding(
  context : BindingContext,
  owner : String,
  bindings : Array[StructLocalBinding],
  pattern : @ast.Pattern,
  field : FieldDef,
  type_ : TypeRef,
  span : SourceSpan,
) -> Unit {
  match pattern {
    @ast.Pattern::Name(name, name_span) =>
      if name != "_" {
        bindings.push({
          symbol: {
            id: local_id(owner, name, name_span.start),
            kind: SymbolKind::Local,
            name,
            type_,
            span: name_span,
          },
          field,
        })
      }
    @ast.Pattern::Wildcard(_) => ()
    _ =>
      context.error(
        "VNX1908", "constructor destructuring currently supports only names and wildcards",
        span,
      )
  }
}

///|
fn wrap_struct_local_bindings(
  temp_symbol : Symbol,
  bindings : Array[StructLocalBinding],
  body : BoundExpr,
  span : SourceSpan,
) -> BoundExpr {
  let mut result = body
  for i = bindings.length() - 1; i >= 0; i = i - 1 {
    let binding = bindings[i]
    let symbol = binding.symbol
    let field : @binding.FieldRef = {
      owner_type_id: field_owner_type_id(temp_symbol.type_),
      field_id: binding.field.id,
      name: binding.field.name,
      mutable: binding.field.mutable,
      type_: symbol.type_,
    }
    result = BoundExpr::LocalLet(
      {
        symbol_id: symbol.id,
        name: symbol.name,
        type_: symbol.type_,
        value: BoundExpr::FieldAccess(
          BoundExpr::Name(
            temp_symbol.id,
            temp_symbol.name,
            temp_symbol.type_,
            span,
          ),
          field,
          symbol.type_,
          span,
        ),
      },
      result,
      @ir.expr_type(result),
      span,
    )
  }
  result
}

///|
fn field_owner_type_id(type_ : TypeRef) -> String {
  match type_ {
    TypeRef::Declared(symbol, _) => symbol.id
    _ => ""
  }
}

///|
fn none_expected_type(
  typing : TypingContext,
  expected : TypeRef,
  span : SourceSpan,
) -> TypeRef? {
  let resolved = @semantic.resolve_inferred_type(typing, expected)
  if is_option_type(resolved) {
    Some(resolved)
  } else if @semantic.unresolved_inference_type(resolved) {
    let item_type = @semantic.inference_type(
      "option-none:" + span.start.to_string(),
    )
    let option_type = @binding.option_type(item_type)
    ignore(@semantic.unify_types(typing, resolved, option_type))
    Some(option_type)
  } else {
    None
  }
}

///|
fn bind_tuple_local_let(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  patterns : Array[@ast.Pattern],
  value : Expr,
  body : Expr,
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let tuple_expected = tuple_expected_for_patterns(span, patterns)
  let bound_value = bind_expr(
    typing, context, index, scope, value, tuple_expected, ast,
  )
  let tuple_type = @semantic.resolve_inferred_type(
    typing,
    @ir.expr_type(bound_value),
  )
  let item_types = match tuple_type {
    TypeRef::Tuple(items) => items
    _ => {
      context.error("VNX1908", "tuple destructuring value must be tuple", span)
      []
    }
  }
  let owner = local_owner_id(context, scope)
  let temp_name = "__tuple_" + span.start.to_string()
  let temp_symbol : Symbol = {
    id: local_id(owner, temp_name, span.start),
    kind: SymbolKind::Local,
    name: temp_name,
    type_: tuple_type,
    span,
  }
  let next_scope = scope.copy()
  next_scope.push(temp_symbol)
  let bindings : Array[TupleLocalBinding] = []
  for i in 0..<patterns.length() {
    collect_tuple_local_bindings(
      context,
      owner,
      bindings,
      patterns[i],
      tuple_item_type(item_types, i),
      i,
      span,
    )
  }
  for binding in bindings {
    next_scope.push(binding.symbol)
  }
  let bound_body = bind_expr(
    typing, context, index, next_scope, body, expected, ast,
  )
  let body_with_bindings = wrap_tuple_local_bindings(
    temp_symbol, bindings, bound_body, span,
  )
  BoundExpr::LocalLet(
    {
      symbol_id: temp_symbol.id,
      name: temp_symbol.name,
      type_: temp_symbol.type_,
      value: bound_value,
    },
    body_with_bindings,
    @ir.expr_type(body_with_bindings),
    span,
  )
}

///|
fn tuple_expected_for_patterns(
  span : SourceSpan,
  patterns : Array[@ast.Pattern],
) -> TypeRef {
  let items = FixedArray::make(patterns.length(), @binding.unresolved_type_ref())
  for i in 0..<patterns.length() {
    items[i] = @semantic.inference_type(
      "tuple-let:" + span.start.to_string() + ":" + i.to_string(),
    )
  }
  TypeRef::Tuple(items)
}

///|
priv struct TupleLocalBinding {
  symbol : Symbol
  index : Int
}

///|
fn tuple_item_type(item_types : FixedArray[TypeRef], index : Int) -> TypeRef {
  if index >= 0 && index < item_types.length() {
    item_types[index]
  } else {
    error_type()
  }
}

///|
fn collect_tuple_local_bindings(
  context : BindingContext,
  owner : String,
  bindings : Array[TupleLocalBinding],
  pattern : @ast.Pattern,
  type_ : TypeRef,
  index : Int,
  span : SourceSpan,
) -> Unit {
  match pattern {
    @ast.Pattern::Name(name, name_span) =>
      if name != "_" {
        bindings.push({
          symbol: {
            id: local_id(owner, name, name_span.start),
            kind: SymbolKind::Local,
            name,
            type_,
            span: name_span,
          },
          index,
        })
      }
    @ast.Pattern::Wildcard(_) => ()
    _ =>
      context.error(
        "VNX1908", "tuple destructuring currently supports only names and wildcards",
        span,
      )
  }
}

///|
fn wrap_tuple_local_bindings(
  temp_symbol : Symbol,
  bindings : Array[TupleLocalBinding],
  body : BoundExpr,
  span : SourceSpan,
) -> BoundExpr {
  let mut result = body
  for i = bindings.length() - 1; i >= 0; i = i - 1 {
    let binding = bindings[i]
    let symbol = binding.symbol
    result = BoundExpr::LocalLet(
      {
        symbol_id: symbol.id,
        name: symbol.name,
        type_: symbol.type_,
        value: BoundExpr::TupleGet(
          BoundExpr::Name(
            temp_symbol.id,
            temp_symbol.name,
            temp_symbol.type_,
            span,
          ),
          binding.index,
          symbol.type_,
          span,
        ),
      },
      result,
      @ir.expr_type(result),
      span,
    )
  }
  result
}

///|
fn merge_ast_span(
  left : @common.SourceSpan,
  right : @common.SourceSpan,
) -> @common.SourceSpan {
  {
    file: left.file,
    start: left.start,
    end: right.end,
    line: left.line,
    column: left.column,
  }
}

///|
fn bind_local_let(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  name : String,
  explicit_type : TypeSyntax?,
  value : Expr,
  body : Expr,
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let symbol_id = local_id(local_owner_id(context, scope), name, span.start)
  let declared_local_type = match explicit_type {
    Some(type_syntax) => resolve_type(context, index, type_syntax)
    None => @semantic.local_inference_type(symbol_id)
  }
  if explicit_type is None && !local_value_needs_context(value) {
    let value_expected = declared_local_type
    let bound_value = bind_expr(
      typing, context, index, scope, value, value_expected, ast,
    )
    ignore(
      @semantic.unify_types(
        typing,
        declared_local_type,
        @ir.expr_type(bound_value),
      ),
    )
    let local_type = @semantic.resolve_inferred_type(
      typing,
      @ir.expr_type(bound_value),
    )
    let symbol : Symbol = {
      id: symbol_id,
      kind: SymbolKind::Local,
      name,
      type_: local_type,
      span,
    }
    let next_scope = scope.copy()
    next_scope.push(symbol)
    if @semantic.unresolved_inference_type(local_type) {
      ignore(
        bind_expr(
          typing,
          diagnostic_free_context(context),
          index,
          next_scope,
          body,
          expected,
          ast,
        ),
      )
    }
    let resolved_declared_type = @semantic.resolve_inferred_type(
      typing, declared_local_type,
    )
    let local_type = if @semantic.unresolved_inference_type(
        resolved_declared_type,
      ) {
      @semantic.resolve_inferred_type(typing, @ir.expr_type(bound_value))
    } else {
      resolved_declared_type
    }
    let final_bound_value = if !@semantic.unresolved_inference_type(
        @ir.expr_type(bound_value),
      ) &&
      (
        @binding.type_equal(
          @semantic.resolve_inferred_type(typing, @ir.expr_type(bound_value)),
          local_type,
        ) ||
        @semantic.unresolved_inference_type(local_type)
      ) {
      bound_value
    } else {
      bind_expr(typing, context, index, scope, value, local_type, ast)
    }
    let resolved_symbol : Symbol = {
      id: symbol_id,
      kind: SymbolKind::Local,
      name,
      type_: local_type,
      span,
    }
    mark_used_trait_object_conversion(
      context,
      index,
      local_type,
      @ir.expr_type(final_bound_value),
    )
    let final_scope = scope.copy()
    final_scope.push(resolved_symbol)
    let bound_body = bind_expr(
      typing, context, index, final_scope, body, expected, ast,
    )
    return BoundExpr::LocalLet(
      { symbol_id, name, type_: local_type, value: final_bound_value },
      bound_body,
      @ir.expr_type(bound_body),
      span,
    )
  }
  let provisional_symbol : Symbol = {
    id: symbol_id,
    kind: SymbolKind::Local,
    name,
    type_: declared_local_type,
    span,
  }
  let next_scope = scope.copy()
  next_scope.push(provisional_symbol)
  ignore(
    bind_expr(
      typing,
      diagnostic_free_context(context),
      index,
      next_scope,
      body,
      expected,
      ast,
    ),
  )
  let value_expected = @semantic.resolve_inferred_type(
    typing, declared_local_type,
  )
  let bound_value = bind_expr(
    typing, context, index, scope, value, value_expected, ast,
  )
  ignore(
    @semantic.unify_types(typing, value_expected, @ir.expr_type(bound_value)),
  )
  let resolved_declared_type = @semantic.resolve_inferred_type(
    typing, declared_local_type,
  )
  let local_type = if @semantic.unresolved_inference_type(
      resolved_declared_type,
    ) {
    @semantic.resolve_inferred_type(typing, @ir.expr_type(bound_value))
  } else {
    resolved_declared_type
  }
  let final_bound_value = if !@semantic.unresolved_inference_type(
      @ir.expr_type(bound_value),
    ) &&
    (
      @binding.type_equal(
        @semantic.resolve_inferred_type(typing, @ir.expr_type(bound_value)),
        local_type,
      ) ||
      @semantic.unresolved_inference_type(local_type)
    ) {
    bound_value
  } else {
    bind_expr(typing, context, index, scope, value, local_type, ast)
  }
  let resolved_symbol : Symbol = {
    id: symbol_id,
    kind: SymbolKind::Local,
    name,
    type_: local_type,
    span,
  }
  mark_used_trait_object_conversion(
    context,
    index,
    local_type,
    @ir.expr_type(final_bound_value),
  )
  let final_scope = scope.copy()
  final_scope.push(resolved_symbol)
  let bound_body = bind_expr(
    typing, context, index, final_scope, body, expected, ast,
  )
  BoundExpr::LocalLet(
    { symbol_id, name, type_: local_type, value: final_bound_value },
    bound_body,
    @ir.expr_type(bound_body),
    span,
  )
}

///|
fn bind_local_function(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  function : Function,
  outer_body : Expr,
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let owner = local_owner_id(context, scope)
  let return_type = resolve_type_with_params(
    context,
    index,
    function.return_type,
    [],
  )
  let param_symbols : Array[Symbol] = []
  let param_types : Array[@binding.ParamTypeRef] = []
  for param in function.params {
    let param_type = resolve_type_with_params(context, index, param.type_, [])
    let symbol : Symbol = {
      id: parameter_id(owner + ":local-fn:" + function.name, param.name),
      name: param.name,
      kind: SymbolKind::Parameter,
      type_: param_type,
      span: param.span,
    }
    param_symbols.push(symbol)
    param_types.push({
      label: if param.labelled {
        Some(param.name)
      } else {
        None
      },
      type_: param_type,
      optional: param.optional,
      has_default: param.default_value is Some(_),
    })
  }
  let function_type = TypeRef::Function(param_types, return_type, no_raise())
  let function_symbol : Symbol = {
    id: local_id(owner, function.name, span.start),
    name: function.name,
    kind: SymbolKind::Local,
    type_: function_type,
    span: function.span,
  }
  let function_scope = scope.copy()
  function_scope.push(function_symbol)
  for symbol in param_symbols {
    function_scope.push(symbol)
  }
  let nested_owner = local_id(owner, function.name, span.start)
  let nested_context = @binding.binding_context_with_owner(
    context, nested_owner,
  )
  let bound_function_body = bind_expr(
    typing,
    nested_context,
    index,
    function_scope,
    function.body,
    return_type,
    ast,
  )
  let outer_scope = scope.copy()
  outer_scope.push(function_symbol)
  let bound_outer = bind_expr(
    typing, context, index, outer_scope, outer_body, expected, ast,
  )
  BoundExpr::LocalFunction(
    {
      symbol: function_symbol,
      params: param_symbols,
      return_type,
      body: bound_function_body,
    },
    bound_outer,
    @ir.expr_type(bound_outer),
    span,
  )
}

///|
fn local_value_needs_context(value : Expr) -> Bool {
  match value {
    Expr::StructLiteral(_, _)
    | Expr::MapLiteral(_, _)
    | Expr::ArrayLiteral(_, _) => true
    _ => false
  }
}

///|
fn local_owner_id(context : BindingContext, _scope : Array[Symbol]) -> String {
  match context.current_owner_id {
    Some(owner) => owner
    None => function_id(context.package_id, context.module_name, "<unknown>")
  }
}
