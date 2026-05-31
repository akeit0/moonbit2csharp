///|
fn bind_option_some(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  args : Array[CallArg],
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let expected = option_expected_type(typing, expected, span)
  match option_item_type(expected) {
    Some(item_type) =>
      if args.length() == 1 {
        let value = bind_expr(
          typing,
          context,
          index,
          scope,
          args[0].value,
          item_type,
          ast,
        )
        BoundExpr::OptionSome(
          value,
          @semantic.resolve_inferred_type(typing, expected),
          span,
        )
      } else {
        context.error("VNX1500", "Some expects one argument", span)
        BoundExpr::Error("invalid Some", error_type(), span)
      }
    None => {
      context.error("VNX1501", "Some requires expected Option type", span)
      BoundExpr::Error("Some without Option expected type", error_type(), span)
    }
  }
}

///|
fn option_expected_type(
  typing : TypingContext,
  expected : TypeRef,
  span : SourceSpan,
) -> TypeRef {
  let resolved = @semantic.resolve_inferred_type(typing, expected)
  if @semantic.unresolved_inference_type(resolved) {
    let item_type = @semantic.inference_type(
      "option-item:" + span.start.to_string(),
    )
    let option_type = @binding.option_type(item_type)
    ignore(@semantic.unify_types(typing, resolved, option_type))
    option_type
  } else {
    resolved
  }
}

///|
fn bind_array_literal(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  items : Array[@ast.ArrayElement],
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let expected = @semantic.resolve_inferred_type(typing, expected)
  let element_type = array_literal_element_type(typing, expected, span)
  let bound_items : Array[BoundArrayElement] = []
  for item in items {
    match item {
      @ast.ArrayElement::Value(value) => {
        let bound = bind_expr(
          typing, context, index, scope, value, element_type, ast,
        )
        if !type_equal(@ir.expr_type(bound), element_type) {
          if @semantic.classify_conversion_with_inference(
              typing,
              element_type,
              @ir.expr_type(bound),
            ) ==
            @semantic.ConversionKind::Incompatible {
            context.error(
              "VNX1300",
              "array element type mismatch",
              expr_span(value),
            )
          }
        }
        bound_items.push(BoundArrayElement::Value(bound))
      }
      @ast.ArrayElement::Spread(value, spread_span) => {
        let spread_type = @semantic.inference_type(
          "array-spread:" + spread_span.start.to_string(),
        )
        let bound = bind_expr(
          typing, context, index, scope, value, spread_type, ast,
        )
        if !unify_spread_element_type(
            typing,
            @ir.expr_type(bound),
            element_type,
          ) {
          context.error(
            "VNX1302", "array spread expression must be array-view- or iter-compatible",
            spread_span,
          )
        }
        bound_items.push(
          BoundArrayElement::Spread(
            normalize_array_spread_expr(typing, bound, spread_span),
          ),
        )
      }
    }
  }
  let element_type = @semantic.resolve_inferred_type(typing, element_type)
  let type_ = if array_literal_has_spread(bound_items) {
    @binding.array_type(element_type)
  } else {
    match @binding.type_constructor_name(expected) {
      Some(("FixedArray", [_])) => @binding.fixed_array_type(element_type)
      _ => @binding.array_type(element_type)
    }
  }
  apply_conversion(
    typing,
    context,
    BoundExpr::ArrayLiteral(bound_items, type_, span),
    expected,
    span,
  )
}

///|
fn normalize_array_spread_expr(
  typing : TypingContext,
  value : BoundExpr,
  span : SourceSpan,
) -> BoundExpr {
  let value_type = @semantic.resolve_inferred_type(typing, @ir.expr_type(value))
  match @binding.type_constructor_name(value_type) {
    Some(("Iter", [item])) =>
      BoundExpr::Call(
        @binding.function_id(
          "pkg:moonbitlang/core/builtin", "moonbitlang/core/builtin", "Iter::to_array",
        ),
        [item],
        [],
        [value],
        None,
        @binding.array_type(item),
        span,
      )
    _ => value
  }
}

///|
fn unify_spread_element_type(
  typing : TypingContext,
  source_type : TypeRef,
  element_type : TypeRef,
) -> Bool {
  let resolved = @semantic.resolve_inferred_type(typing, source_type)
  match @binding.type_constructor_name(resolved) {
    Some(("Array", [item]))
    | Some(("FixedArray", [item]))
    | Some(("ArrayView", [item]))
    | Some(("Iter", [item])) =>
      @semantic.unify_types(typing, element_type, item)
    _ =>
      if @semantic.unresolved_inference_type(resolved) {
        @semantic.unify_types(
          typing,
          resolved,
          @binding.array_view_type(element_type),
        )
      } else {
        false
      }
  }
}

///|
fn array_literal_element_type(
  typing : TypingContext,
  expected : TypeRef,
  span : SourceSpan,
) -> TypeRef {
  match @binding.type_constructor_name(expected) {
    Some(("Array", [item]))
    | Some(("FixedArray", [item]))
    | Some(("ArrayView", [item])) => item
    _ => {
      let item = @semantic.inference_type(
        "array-item:" + span.start.to_string(),
      )
      if @semantic.unresolved_inference_type(expected) {
        ignore(
          @semantic.unify_types(typing, expected, @binding.array_type(item)),
        )
      }
      item
    }
  }
}

///|
fn array_literal_has_spread(items : Array[BoundArrayElement]) -> Bool {
  for item in items {
    match item {
      BoundArrayElement::Spread(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn bind_map_literal(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  entries : Array[MapEntry],
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let expected = @semantic.resolve_inferred_type(typing, expected)
  match map_item_types(expected) {
    Some((key_type, value_type)) => {
      let bound_entries : Array[BoundMapEntry] = []
      for entry in entries {
        let key = bind_expr(
          typing,
          context,
          index,
          scope,
          entry.key,
          key_type,
          ast,
        )
        let value = bind_expr(
          typing,
          context,
          index,
          scope,
          entry.value,
          value_type,
          ast,
        )
        if @semantic.classify_conversion(key_type, @ir.expr_type(key)) ==
          @semantic.ConversionKind::Incompatible {
          context.error(
            "VNX1350",
            "map key type mismatch",
            expr_span(entry.key),
          )
        }
        if @semantic.classify_conversion(value_type, @ir.expr_type(value)) ==
          @semantic.ConversionKind::Incompatible {
          context.error(
            "VNX1351",
            "map value type mismatch",
            expr_span(entry.value),
          )
        }
        bound_entries.push({ key, value })
      }
      BoundExpr::MapLiteral(bound_entries, expected, span)
    }
    None => {
      context.error("VNX1352", "map literal requires expected Map type", span)
      BoundExpr::Error(
        "map literal without expected Map type",
        error_type(),
        span,
      )
    }
  }
}

///|
fn map_item_types(type_ : TypeRef) -> (TypeRef, TypeRef)? {
  match type_ {
    TypeRef::Apply(TypeConstructorRef::Builtin("Map"), [key, value]) =>
      Some((key, value))
    _ => None
  }
}

///|
