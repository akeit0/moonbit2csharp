///|
fn bind_for_range(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  name : String,
  start : Expr,
  range_kind : @ast.RangeKind,
  end_ : Expr,
  bindings : Array[@ast.ForLoopBinding],
  body : Expr,
  no_break_expr : Expr?,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  if bindings.length() > 0 {
    context.error(
      "VNX1905", "range-for state bindings are not supported yet", span,
    )
  }
  match no_break_expr {
    Some(_) =>
      context.error(
        "VNX1906", "range-for nobreak clause is not supported yet", span,
      )
    None => ()
  }
  let symbol_id = local_id(local_owner_id(context, scope), name, span.start)
  let symbol : Symbol = {
    id: symbol_id,
    kind: SymbolKind::Local,
    name,
    type_: int_type(),
    span,
  }
  let next_scope = scope.copy()
  next_scope.push(symbol)
  let bound_start = bind_expr(
    typing,
    context,
    index,
    scope,
    start,
    int_type(),
    ast,
  )
  let bound_end = bind_expr(
    typing,
    context,
    index,
    scope,
    end_,
    int_type(),
    ast,
  )
  let previous_loop_depth = context.loop_depth
  context.loop_depth = previous_loop_depth + 1
  let bound_body = bind_expr(
    typing,
    context,
    index,
    next_scope,
    body,
    unit_type(),
    ast,
  )
  context.loop_depth = previous_loop_depth
  let (inclusive, reverse, exclude_start) = range_flags(range_kind)
  BoundExpr::ForRange(
    {
      symbol_id,
      name,
      start: bound_start,
      end_: bound_end,
      inclusive,
      reverse,
      exclude_start,
      body: bound_body,
    },
    unit_type(),
    span,
  )
}

///|
fn bind_while(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  condition : Expr,
  body : Expr,
  span : SourceSpan,
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
  let previous_loop_depth = context.loop_depth
  context.loop_depth = previous_loop_depth + 1
  let bound_body = bind_expr(
    typing,
    context,
    index,
    scope,
    body,
    unit_type(),
    ast,
  )
  context.loop_depth = previous_loop_depth
  BoundExpr::While(bound_condition, bound_body, unit_type(), span)
}

///|
fn bind_for_in(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  names : Array[String],
  value : Expr,
  bindings : Array[@ast.ForLoopBinding],
  body : Expr,
  no_break_expr : Expr?,
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let bound_iterator = bind_for_in_iterator(
    typing,
    context,
    index,
    scope,
    value,
    names.length(),
    span,
    ast,
  )
  let item_types = for_in_item_types(
    context,
    @ir.expr_type(bound_iterator),
    names.length(),
    span,
  )
  let owner = local_owner_id(context, scope)
  let next_scope = scope.copy()
  let value_symbols : Array[Symbol] = []
  if names.length() == 0 {
    let symbol : Symbol = {
      id: local_id(owner, "_", span.start),
      kind: SymbolKind::Local,
      name: "_",
      type_: if item_types.length() > 0 {
        item_types[0]
      } else {
        error_type()
      },
      span,
    }
    value_symbols.push(symbol)
  } else {
    for i in 0..<names.length() {
      let symbol : Symbol = {
        id: local_id(owner, names[i], span.start + i),
        kind: SymbolKind::Local,
        name: names[i],
        type_: if i < item_types.length() {
          item_types[i]
        } else {
          error_type()
        },
        span,
      }
      if symbol.name != "_" {
        next_scope.push(symbol)
      }
      value_symbols.push(symbol)
    }
  }
  let bound_bindings = bind_loop_state_bindings(
    typing, context, index, scope, next_scope, bindings, ast,
  )
  let previous_loop_depth = context.loop_depth
  context.loop_depth = previous_loop_depth + 1
  let bound_body = bind_expr(
    typing,
    context,
    index,
    next_scope,
    body,
    unit_type(),
    ast,
  )
  context.loop_depth = previous_loop_depth
  let bound_no_break = match no_break_expr {
    Some(expr) =>
      Some(bind_expr(typing, context, index, next_scope, expr, expected, ast))
    None => None
  }
  let result_type = match bound_no_break {
    Some(expr) => @ir.expr_type(expr)
    None => loop_result_type(bound_body)
  }
  BoundExpr::ForIn(
    {
      value_symbols,
      iterator: bound_iterator,
      bindings: bound_bindings,
      body: bound_body,
      no_break: bound_no_break,
    },
    result_type,
    span,
  )
}

///|
fn bind_for_in_iterator(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  value : Expr,
  arity : Int,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let target = bind_expr(
    typing,
    context,
    index,
    scope,
    value,
    error_type(),
    ast,
  )
  match @ir.expr_type(target) {
    TypeRef::Error(_) =>
      return BoundExpr::Error(
        "for-in target does not resolve to Iter",
        error_type(),
        span,
      )
    _ => ()
  }
  match @binding.iter_item_type(@ir.expr_type(target)) {
    Some(_) => if arity <= 1 { return target }
    None => ()
  }
  match @binding.iter2_item_types(@ir.expr_type(target)) {
    Some(_) => if arity == 2 { return target }
    None => ()
  }
  let method_name = if arity == 2 { "iter2" } else { "iter" }
  match
    bind_receiver_function_call(
      typing,
      context,
      index,
      scope,
      value,
      method_name,
      [],
      error_type(),
      span,
      ast,
    ) {
    Some(iterator) => iterator
    None => {
      context.error("VNX1904", "for-in target does not resolve to Iter", span)
      BoundExpr::Error(
        "for-in target does not resolve to Iter",
        error_type(),
        span,
      )
    }
  }
}

///|
fn for_in_item_types(
  context : BindingContext,
  iterator_type : TypeRef,
  arity : Int,
  span : SourceSpan,
) -> Array[TypeRef] {
  if arity == 2 {
    match @binding.iter2_item_types(iterator_type) {
      Some((first, second)) => return [first, second]
      None => ()
    }
    match iterator_type {
      TypeRef::Error(_) => return [error_type(), error_type()]
      _ => {
        context.error(
          "VNX1904", "for-in target does not resolve to Iter2", span,
        )
        return [error_type(), error_type()]
      }
    }
  }
  match @binding.iter_item_type(iterator_type) {
    Some(type_) => [type_]
    None =>
      match iterator_type {
        TypeRef::Error(_) => [error_type()]
        _ => {
          context.error(
            "VNX1904", "for-in target does not resolve to Iter", span,
          )
          [error_type()]
        }
      }
  }
}

///|
fn bind_for_loop(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  bindings : Array[@ast.ForLoopBinding],
  condition : Expr?,
  updates : Array[Expr],
  body : Expr,
  no_break_expr : Expr?,
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  match no_break_expr {
    Some(_) =>
      context.error(
        "VNX1909", "for-loop nobreak clause is not supported yet", span,
      )
    None => ()
  }
  let next_scope = scope.copy()
  let bound_bindings = bind_loop_state_bindings(
    typing, context, index, scope, next_scope, bindings, ast,
  )
  let bound_condition = match condition {
    Some(expr) =>
      Some(
        bind_expr(typing, context, index, next_scope, expr, bool_type(), ast),
      )
    None => None
  }
  let bound_updates : Array[BoundExpr] = []
  for update in updates {
    bound_updates.push(
      bind_expr(typing, context, index, next_scope, update, unit_type(), ast),
    )
  }
  let previous_loop_depth = context.loop_depth
  let previous_loop_break_expected_types = context.loop_break_expected_types
  context.loop_depth = previous_loop_depth + 1
  context.loop_break_expected_types = push_loop_break_expected_type(
    previous_loop_break_expected_types,
    expected,
  )
  let bound_body = bind_expr(
    typing,
    context,
    index,
    next_scope,
    body,
    unit_type(),
    ast,
  )
  context.loop_depth = previous_loop_depth
  context.loop_break_expected_types = previous_loop_break_expected_types
  let result_type = loop_result_type(bound_body)
  BoundExpr::ForLoop(
    {
      bindings: bound_bindings,
      condition: bound_condition,
      updates: bound_updates,
      body: bound_body,
    },
    result_type,
    span,
  )
}

///|
fn bind_loop_state_bindings(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  outer_scope : Array[Symbol],
  loop_scope : Array[Symbol],
  bindings : Array[@ast.ForLoopBinding],
  ast : Module,
) -> Array[@ir.BoundForLoopBinding] {
  let bound_bindings : Array[@ir.BoundForLoopBinding] = []
  for binding in bindings {
    let symbol_id = local_id(
      local_owner_id(context, outer_scope),
      binding.name,
      binding.span.start,
    )
    let local_type = @semantic.local_inference_type(symbol_id)
    let symbol : Symbol = {
      id: symbol_id,
      kind: SymbolKind::Local,
      name: binding.name,
      type_: local_type,
      span: binding.span,
    }
    let bound_value = bind_expr(
      typing,
      context,
      index,
      loop_scope,
      binding.value,
      local_type,
      ast,
    )
    ignore(
      @semantic.unify_types(typing, local_type, @ir.expr_type(bound_value)),
    )
    let resolved_symbol : Symbol = {
      id: symbol.id,
      kind: symbol.kind,
      name: symbol.name,
      type_: @semantic.resolve_inferred_type(typing, @ir.expr_type(bound_value)),
      span: symbol.span,
    }
    loop_scope.push(resolved_symbol)
    bound_bindings.push({ symbol: resolved_symbol, value: bound_value })
  }
  bound_bindings
}

///|
fn bind_break(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  value : Expr?,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  if context.loop_depth == 0 {
    context.error("VNX1700", "break outside loop", span)
  }
  let expected = current_loop_break_expected_type(context)
  let bound_value = match value {
    Some(expr) =>
      Some(bind_expr(typing, context, index, scope, expr, expected, ast))
    None => None
  }
  BoundExpr::Break(bound_value, unit_type(), span)
}

///|
fn push_loop_break_expected_type(
  types : Array[TypeRef],
  expected : TypeRef,
) -> Array[TypeRef] {
  let result = types.copy()
  result.push(expected)
  result
}

///|
fn current_loop_break_expected_type(context : BindingContext) -> TypeRef {
  let types = context.loop_break_expected_types
  if types.length() == 0 {
    error_type()
  } else {
    types[types.length() - 1]
  }
}

///|
fn bind_continue(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  args : Array[Expr],
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  if context.loop_depth == 0 {
    context.error("VNX1701", "continue outside loop", span)
  }
  let bound_args : Array[BoundExpr] = []
  for arg in args {
    bound_args.push(
      bind_expr(typing, context, index, scope, arg, error_type(), ast),
    )
  }
  BoundExpr::Continue(bound_args, unit_type(), span)
}

///|
fn loop_result_type(body : BoundExpr) -> TypeRef {
  match first_break_value_type(body) {
    Some(type_) => type_
    None => unit_type()
  }
}

///|
fn first_break_value_type(expr : BoundExpr) -> TypeRef? {
  match expr {
    BoundExpr::Break(Some(value), _, _) => Some(@ir.expr_type(value))
    BoundExpr::Sequence(first, body, _, _) =>
      match first_break_value_type(first) {
        Some(type_) => Some(type_)
        None => first_break_value_type(body)
      }
    BoundExpr::LocalLet(_, body, _, _) => first_break_value_type(body)
    BoundExpr::If(_, then_, else_, _, _) =>
      match first_break_value_type(then_) {
        Some(type_) => Some(type_)
        None => first_break_value_type(else_)
      }
    BoundExpr::Match(_, arms, _, _) => {
      for arm in arms {
        match first_break_value_type(arm.body) {
          Some(type_) => return Some(type_)
          None => ()
        }
      }
      None
    }
    _ => None
  }
}

///|
fn range_flags(range_kind : @ast.RangeKind) -> (Bool, Bool, Bool) {
  match range_kind {
    @ast.RangeKind::DotDot => (false, false, false)
    @ast.RangeKind::Inclusive => (true, false, false)
    @ast.RangeKind::LtInclusive => (true, false, false)
    @ast.RangeKind::Exclusive => (false, false, false)
    @ast.RangeKind::InclusiveReverse => (true, true, false)
    @ast.RangeKind::ExclusiveReverse => (true, true, true)
  }
}
