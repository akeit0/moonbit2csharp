///|
fn bind_match(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target : Expr,
  arms : Array[@ast.MatchArm],
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let bound_target = bind_expr(
    typing,
    context,
    index,
    scope,
    target,
    error_type(),
    ast,
  )
  let target_type = @semantic.resolve_inferred_type(
    typing,
    @ir.expr_type(bound_target),
  )
  let match_type = match_result_inference_type(typing, expected, span)
  let bound_arms : Array[@ir.BoundMatchArm] = []
  for arm in arms {
    let (pattern, arm_scope) = bind_match_pattern(
      context,
      index,
      scope,
      target_type,
      arm.pattern,
    )
    let condition = match arm.condition {
      Some(condition_expr) =>
        Some(
          bind_expr(
            typing,
            context,
            index,
            arm_scope,
            condition_expr,
            bool_type(),
            ast,
          ),
        )
      None => None
    }
    let arm_expected = @semantic.resolve_inferred_type(typing, match_type)
    let body = bind_expr(
      typing,
      context,
      index,
      arm_scope,
      arm.body,
      arm_expected,
      ast,
    )
    if !terminal_control_expr(body) {
      ignore(@semantic.unify_types(typing, match_type, @ir.expr_type(body)))
    }
    bound_arms.push({ pattern, condition, body })
  }
  BoundExpr::Match(
    bound_target,
    bound_arms,
    @semantic.resolve_inferred_type(typing, match_type),
    span,
  )
}

///|
fn match_result_inference_type(
  typing : TypingContext,
  expected : TypeRef,
  span : SourceSpan,
) -> TypeRef {
  let resolved = @semantic.resolve_inferred_type(typing, expected)
  match resolved {
    TypeRef::Error(_) =>
      @semantic.inference_type("match:" + span.start.to_string())
    _ => resolved
  }
}

///|
fn bind_match_pattern(
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target_type : TypeRef,
  pattern : @ast.Pattern,
) -> (@ir.BoundPattern, Array[Symbol]) {
  let result = bind_pattern(context, index, scope, target_type, pattern)
  let arm_scope = scope.copy()
  for symbol in result.symbols {
    if symbol.name != "_" {
      arm_scope.push(symbol)
    }
  }
  (result.pattern, arm_scope)
}

///|
fn bind_is_pattern(
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target : Expr,
  pattern : @ast.Pattern,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let bound_target = bind_expr(
    @semantic.typing_context(),
    context,
    index,
    scope,
    target,
    error_type(),
    ast,
  )
  let result = bind_pattern(
    context,
    index,
    scope,
    @ir.expr_type(bound_target),
    pattern,
  )
  BoundExpr::IsPattern(bound_target, result.pattern, bool_type(), span)
}

///|
fn bind_if_expr(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  condition : Expr,
  then_ : Expr,
  else_ : Expr,
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let (bound_condition, condition_symbols) = bind_if_condition(
    context, index, scope, condition, ast,
  )
  let then_scope = scope.copy()
  for symbol in condition_symbols {
    if symbol.name != "_" {
      then_scope.push(symbol)
    }
  }
  let bound_then = bind_expr(
    typing, context, index, then_scope, then_, expected, ast,
  )
  let branch_expected = if terminal_control_expr(bound_then) {
    expected
  } else {
    @semantic.resolve_inferred_type(typing, @ir.expr_type(bound_then))
  }
  let bound_else = bind_expr(
    typing, context, index, scope, else_, branch_expected, ast,
  )
  if !terminal_control_expr(bound_then) && !terminal_control_expr(bound_else) {
    ignore(
      @semantic.unify_types(
        typing,
        @ir.expr_type(bound_then),
        @ir.expr_type(bound_else),
      ),
    )
  }
  let result_type = if terminal_control_expr(bound_then) &&
    terminal_control_expr(bound_else) {
    expected
  } else if terminal_control_expr(bound_then) {
    @ir.expr_type(bound_else)
  } else {
    @ir.expr_type(bound_then)
  }
  BoundExpr::If(
    bound_condition,
    bound_then,
    bound_else,
    @semantic.resolve_inferred_type(typing, result_type),
    span,
  )
}

///|
fn terminal_control_expr(expr : BoundExpr) -> Bool {
  match expr {
    BoundExpr::Break(_, _, _)
    | BoundExpr::Continue(_, _, _)
    | BoundExpr::Return(_, _, _) => true
    BoundExpr::If(_, then_, else_, _, _) =>
      terminal_control_expr(then_) && terminal_control_expr(else_)
    _ => false
  }
}

///|
fn bind_if_condition(
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  condition : Expr,
  ast : Module,
) -> (BoundExpr, Array[Symbol]) {
  match condition {
    Expr::IsPattern(target, pattern, span) => {
      let bound_target = bind_expr(
        @semantic.typing_context(),
        context,
        index,
        scope,
        target,
        error_type(),
        ast,
      )
      let result = bind_pattern(
        context,
        index,
        scope,
        @ir.expr_type(bound_target),
        pattern,
      )
      (
        BoundExpr::IsPattern(bound_target, result.pattern, bool_type(), span),
        result.symbols,
      )
    }
    Expr::Binary("&&", left, right, span) => {
      let (left_bound, left_symbols) = bind_if_condition(
        context, index, scope, left, ast,
      )
      let right_scope = scope_with_pattern_symbols(scope, left_symbols)
      let (right_bound, right_symbols) = bind_if_condition(
        context, index, right_scope, right, ast,
      )
      let symbols = left_symbols.copy()
      for symbol in right_symbols {
        symbols.push(symbol)
      }
      (
        BoundExpr::Binary(
          "&&",
          left_bound,
          right_bound,
          "",
          [],
          [],
          None,
          bool_type(),
          span,
        ),
        symbols,
      )
    }
    _ =>
      (
        bind_expr(
          @semantic.typing_context(),
          context,
          index,
          scope,
          condition,
          bool_type(),
          ast,
        ),
        [],
      )
  }
}

///|
priv struct BoundPatternResult {
  pattern : @ir.BoundPattern
  symbols : Array[Symbol]
}

///|
fn bind_pattern(
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target_type : TypeRef,
  pattern : @ast.Pattern,
) -> BoundPatternResult {
  match pattern {
    @ast.Pattern::Wildcard(_) =>
      { pattern: @ir.BoundPattern::Wildcard, symbols: [] }
    @ast.Pattern::Name(name, span) =>
      bind_name_pattern(context, index, scope, target_type, name, span)
    @ast.Pattern::IntLiteral(value, span) => {
      check_literal_pattern_type(context, target_type, int_type(), span)
      { pattern: @ir.BoundPattern::IntLiteral(value), symbols: [] }
    }
    @ast.Pattern::CharLiteral(value, span) => {
      check_literal_pattern_type(
        context,
        target_type,
        @binding.char_literal_pattern_type(target_type),
        span,
      )
      { pattern: @ir.BoundPattern::CharLiteral(value), symbols: [] }
    }
    @ast.Pattern::StringLiteral(value, span) => {
      check_literal_pattern_type(context, target_type, string_type(), span)
      { pattern: @ir.BoundPattern::StringLiteral(value), symbols: [] }
    }
    @ast.Pattern::BoolLiteral(value, span) => {
      check_literal_pattern_type(context, target_type, bool_type(), span)
      { pattern: @ir.BoundPattern::BoolLiteral(value), symbols: [] }
    }
    @ast.Pattern::Range(start, end_, inclusive, span) => {
      let pattern_type = if @binding.is_char_like_type(target_type) {
        @binding.char_literal_pattern_type(target_type)
      } else {
        int_type()
      }
      check_literal_pattern_type(context, target_type, pattern_type, span)
      { pattern: @ir.BoundPattern::Range(start, end_, inclusive), symbols: [] }
    }
    @ast.Pattern::Tuple(items, span) =>
      bind_tuple_pattern(context, index, scope, target_type, items, span)
    @ast.Pattern::Array(prefix, rest, suffix, span) =>
      bind_array_pattern(
        context, index, scope, target_type, prefix, rest, suffix, span,
      )
    @ast.Pattern::Struct(fields, _, span) =>
      bind_struct_pattern(context, index, scope, target_type, fields, span)
    @ast.Pattern::Or(alternatives, span) =>
      bind_or_pattern(context, index, scope, target_type, alternatives, span)
    @ast.Pattern::Alias(pattern, name, span) => {
      let result = bind_pattern(context, index, scope, target_type, pattern)
      let symbol = pattern_binding_symbol(
        context, scope, name, target_type, span,
      )
      result.symbols.push(symbol)
      result
    }
    @ast.Pattern::Labelled(_, pattern, _) =>
      bind_pattern(context, index, scope, target_type, pattern)
    @ast.Pattern::Rest(_) =>
      { pattern: @ir.BoundPattern::Wildcard, symbols: [] }
    @ast.Pattern::Constructor(type_syntax, name, payloads, span) =>
      bind_constructor_pattern(
        context, index, scope, target_type, type_syntax, name, payloads, span,
      )
  }
}

///|
fn bind_name_pattern(
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target_type : TypeRef,
  name : String,
  span : SourceSpan,
) -> BoundPatternResult {
  if name == "None" && option_item_type(target_type) is Some(_) {
    return { pattern: @ir.BoundPattern::OptionNone, symbols: [] }
  }
  match resolve_match_enum_definition(index, target_type, None) {
    Some(def) =>
      match find_enum_variant(def.variants, name) {
        Some(variant) =>
          if variant.payloads.length() == 0 {
            return {
              pattern: @ir.BoundPattern::EnumCase(
                def.symbol.id,
                variant.id,
                variant.name,
                [],
              ),
              symbols: [],
            }
          } else {
            context.error("VNX1802", "enum match payload arity mismatch", span)
            return { pattern: @ir.BoundPattern::Wildcard, symbols: [] }
          }
        None => ()
      }
    None => ()
  }
  let symbol = pattern_binding_symbol(context, scope, name, target_type, span)
  { pattern: @ir.BoundPattern::Binding(symbol), symbols: [symbol] }
}

///|
fn bind_constructor_pattern(
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target_type : TypeRef,
  type_syntax : @ast.TypeSyntax?,
  name : String,
  payloads : Array[@ast.Pattern],
  span : SourceSpan,
) -> BoundPatternResult {
  match (type_syntax, name, option_item_type(target_type)) {
    (None, "Some", Some(item_type)) =>
      if payloads.length() == 1 {
        let payload = bind_pattern(
          context,
          index,
          scope,
          item_type,
          payloads[0],
        )
        return {
          pattern: @ir.BoundPattern::OptionSome(payload.pattern),
          symbols: payload.symbols,
        }
      } else {
        context.error(
          "VNX1804", "Some match pattern requires one payload", span,
        )
        return { pattern: @ir.BoundPattern::Wildcard, symbols: [] }
      }
    _ => ()
  }
  match resolve_match_enum_definition(index, target_type, type_syntax) {
    Some(def) =>
      match find_enum_variant(def.variants, name) {
        Some(variant) => {
          let payload_result = bind_payload_patterns(
            context, index, scope, def, variant, payloads, target_type, span,
          )
          {
            pattern: @ir.BoundPattern::EnumCase(
              def.symbol.id,
              variant.id,
              variant.name,
              payload_result.patterns,
            ),
            symbols: payload_result.symbols,
          }
        }
        None => {
          context.error("VNX1801", "unknown enum match variant: " + name, span)
          { pattern: @ir.BoundPattern::Wildcard, symbols: [] }
        }
      }
    None => {
      context.error("VNX1800", "match pattern target is not an enum", span)
      { pattern: @ir.BoundPattern::Wildcard, symbols: [] }
    }
  }
}

///|
fn bind_or_pattern(
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target_type : TypeRef,
  alternatives : Array[@ast.Pattern],
  span : SourceSpan,
) -> BoundPatternResult {
  let patterns : Array[@ir.BoundPattern] = []
  let symbols : Array[Symbol] = []
  for i in 0..<alternatives.length() {
    let alternative = alternatives[i]
    let result = bind_pattern(context, index, scope, target_type, alternative)
    if i == 0 {
      for symbol in result.symbols {
        symbols.push(symbol)
      }
      patterns.push(result.pattern)
    } else if same_or_pattern_bindings(symbols, result.symbols) {
      patterns.push(normalize_or_pattern_bindings(result.pattern, symbols))
    } else {
      context.error(
        "VNX1807", "or match pattern alternatives must bind the same names", span,
      )
      patterns.push(result.pattern)
    }
  }
  { pattern: @ir.BoundPattern::Or(patterns), symbols }
}

///|
fn same_or_pattern_bindings(
  expected : Array[Symbol],
  actual : Array[Symbol],
) -> Bool {
  if expected.length() != actual.length() {
    return false
  }
  for i in 0..<expected.length() {
    if expected[i].name != actual[i].name ||
      !@binding.type_equal(expected[i].type_, actual[i].type_) {
      return false
    }
  }
  true
}

///|
fn normalize_or_pattern_bindings(
  pattern : @ir.BoundPattern,
  symbols : Array[Symbol],
) -> @ir.BoundPattern {
  match pattern {
    @ir.BoundPattern::Binding(symbol) =>
      match find_or_pattern_symbol(symbols, symbol.name) {
        Some(canonical) => @ir.BoundPattern::Binding(canonical)
        None => pattern
      }
    @ir.BoundPattern::Tuple(items) => {
      let mapped : Array[@ir.BoundPattern] = []
      for item in items {
        mapped.push(normalize_or_pattern_bindings(item, symbols))
      }
      @ir.BoundPattern::Tuple(mapped)
    }
    @ir.BoundPattern::Array(prefix, rest, suffix) => {
      let mapped_prefix : Array[@ir.BoundPattern] = []
      let mapped_suffix : Array[@ir.BoundPattern] = []
      for item in prefix {
        mapped_prefix.push(normalize_or_pattern_bindings(item, symbols))
      }
      for item in suffix {
        mapped_suffix.push(normalize_or_pattern_bindings(item, symbols))
      }
      @ir.BoundPattern::Array(mapped_prefix, rest, mapped_suffix)
    }
    @ir.BoundPattern::Struct(type_id, fields) => {
      let mapped : Array[@ir.BoundStructPatternField] = []
      for field in fields {
        mapped.push({
          field: field.field,
          pattern: normalize_or_pattern_bindings(field.pattern, symbols),
        })
      }
      @ir.BoundPattern::Struct(type_id, mapped)
    }
    @ir.BoundPattern::Or(items) => {
      let mapped : Array[@ir.BoundPattern] = []
      for item in items {
        mapped.push(normalize_or_pattern_bindings(item, symbols))
      }
      @ir.BoundPattern::Or(mapped)
    }
    @ir.BoundPattern::OptionSome(item) =>
      @ir.BoundPattern::OptionSome(normalize_or_pattern_bindings(item, symbols))
    @ir.BoundPattern::EnumCase(type_id, variant_id, name, payloads) => {
      let mapped : Array[@ir.BoundPattern] = []
      for payload in payloads {
        mapped.push(normalize_or_pattern_bindings(payload, symbols))
      }
      @ir.BoundPattern::EnumCase(type_id, variant_id, name, mapped)
    }
    _ => pattern
  }
}

///|
fn find_or_pattern_symbol(symbols : Array[Symbol], name : String) -> Symbol? {
  for symbol in symbols {
    if symbol.name == name {
      return Some(symbol)
    }
  }
  None
}

///|
fn bind_tuple_pattern(
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target_type : TypeRef,
  items : Array[@ast.Pattern],
  span : SourceSpan,
) -> BoundPatternResult {
  match target_type {
    TypeRef::Tuple(item_types) => {
      let patterns : Array[@ir.BoundPattern] = []
      let symbols : Array[Symbol] = []
      if items.length() != item_types.length() {
        context.error("VNX1805", "tuple match pattern arity mismatch", span)
      }
      let limit = if items.length() < item_types.length() {
        items.length()
      } else {
        item_types.length()
      }
      for i in 0..<limit {
        let result = bind_pattern(
          context,
          index,
          scope,
          item_types[i],
          items[i],
        )
        patterns.push(result.pattern)
        for symbol in result.symbols {
          symbols.push(symbol)
        }
      }
      { pattern: @ir.BoundPattern::Tuple(patterns), symbols }
    }
    _ => {
      context.error(
        "VNX1806", "tuple match pattern target is not tuple type", span,
      )
      { pattern: @ir.BoundPattern::Wildcard, symbols: [] }
    }
  }
}

///|
fn bind_array_pattern(
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target_type : TypeRef,
  prefix : Array[@ast.Pattern],
  rest : @ast.ArrayPatternRest?,
  suffix : Array[@ast.Pattern],
  span : SourceSpan,
) -> BoundPatternResult {
  match array_pattern_item_type(target_type) {
    Some(item_type) => {
      let prefix_patterns : Array[@ir.BoundPattern] = []
      let suffix_patterns : Array[@ir.BoundPattern] = []
      let symbols : Array[Symbol] = []
      for item in prefix {
        let result = bind_pattern(context, index, scope, item_type, item)
        prefix_patterns.push(result.pattern)
        for symbol in result.symbols {
          symbols.push(symbol)
        }
      }
      let rest_pattern = bind_array_pattern_rest(
        context, scope, item_type, target_type, rest,
      )
      match rest_pattern {
        Some(bound_rest) =>
          match bound_rest.symbol {
            Some(symbol) => if symbol.name != "_" { symbols.push(symbol) }
            None => ()
          }
        None => ()
      }
      for item in suffix {
        let result = bind_pattern(context, index, scope, item_type, item)
        suffix_patterns.push(result.pattern)
        for symbol in result.symbols {
          symbols.push(symbol)
        }
      }
      {
        pattern: @ir.BoundPattern::Array(
          prefix_patterns, rest_pattern, suffix_patterns,
        ),
        symbols,
      }
    }
    None => {
      context.error(
        "VNX1808", "array match pattern target is not array type", span,
      )
      { pattern: @ir.BoundPattern::Wildcard, symbols: [] }
    }
  }
}

///|
fn bind_struct_pattern(
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target_type : TypeRef,
  fields : Array[@ast.StructPatternField],
  span : SourceSpan,
) -> BoundPatternResult {
  match target_type {
    TypeRef::Declared(symbol, _) => {
      let bound_fields : Array[@ir.BoundStructPatternField] = []
      let symbols : Array[Symbol] = []
      for field in fields {
        match field_ref(index, target_type, field.name) {
          Some(field_ref) => {
            let result = bind_pattern(
              context,
              index,
              scope,
              field_ref.type_,
              field.pattern,
            )
            bound_fields.push({ field: field_ref, pattern: result.pattern })
            for symbol in result.symbols {
              symbols.push(symbol)
            }
          }
          None =>
            context.error(
              "VNX1804",
              "unknown struct pattern field: " + field.name,
              field.span,
            )
        }
      }
      { pattern: @ir.BoundPattern::Struct(symbol.id, bound_fields), symbols }
    }
    _ => {
      context.error("VNX1805", "struct pattern requires struct target", span)
      { pattern: @ir.BoundPattern::Wildcard, symbols: [] }
    }
  }
}

///|
fn bind_array_pattern_rest(
  context : BindingContext,
  scope : Array[Symbol],
  item_type : TypeRef,
  target_type : TypeRef,
  rest : @ast.ArrayPatternRest?,
) -> @ir.BoundArrayPatternRest? {
  match rest {
    Some(rest_pattern) =>
      match rest_pattern.name {
        Some(name) =>
          Some({
            symbol: Some(
              pattern_binding_symbol(
                context,
                scope,
                name,
                array_rest_type(target_type, item_type),
                rest_pattern.span,
              ),
            ),
          })
        None => Some({ symbol: None })
      }
    None => None
  }
}

///|
fn array_rest_type(target_type : TypeRef, item_type : TypeRef) -> TypeRef {
  if type_equal(target_type, string_type()) ||
    type_equal(target_type, string_view_type()) {
    string_view_type()
  } else {
    array_view_type(item_type)
  }
}

///|
fn check_literal_pattern_type(
  context : BindingContext,
  target_type : TypeRef,
  pattern_type : TypeRef,
  span : SourceSpan,
) -> Unit {
  if !@binding.literal_match_pattern_types_compatible(target_type, pattern_type) {
    context.error("VNX1803", "literal match pattern type mismatch", span)
  }
}

///|
fn array_pattern_item_type(type_ : TypeRef) -> TypeRef? {
  match @binding.type_constructor_name(type_) {
    Some(("Array", [item]))
    | Some(("FixedArray", [item]))
    | Some(("ArrayView", [item])) => Some(item)
    _ =>
      match type_ {
        TypeRef::Builtin("String") | TypeRef::Builtin("StringView") =>
          Some(@binding.char_code_unit_type())
        _ => None
      }
  }
}

///|
fn pattern_binding_symbol(
  context : BindingContext,
  scope : Array[Symbol],
  name : String,
  type_ : TypeRef,
  span : SourceSpan,
) -> Symbol {
  {
    id: local_id(local_owner_id(context, scope), name, span.start),
    kind: SymbolKind::Local,
    name,
    type_,
    span,
  }
}

///|
priv struct BoundPayloadPatterns {
  patterns : Array[@ir.BoundPattern]
  symbols : Array[Symbol]
}

///|
fn bind_payload_patterns(
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  def : @binding.EnumDefinition,
  variant : @binding.EnumVariantDef,
  payloads : Array[@ast.Pattern],
  target_type : TypeRef,
  span : SourceSpan,
) -> BoundPayloadPatterns {
  let patterns : Array[@ir.BoundPattern] = []
  let symbols : Array[Symbol] = []
  let planned_payloads = plan_enum_payload_patterns(
    context, variant, payloads, span,
  )
  if planned_payloads.length() != variant.payloads.length() {
    context.error("VNX1802", "enum match payload arity mismatch", span)
    return { patterns, symbols }
  }
  let type_args = enum_type_args(target_type)
  for i in 0..<planned_payloads.length() {
    let payload_type = @semantic.substitute_type(
      def.type_params,
      type_args,
      variant.payloads[i].type_,
    )
    let result = bind_pattern(
      context,
      index,
      scope,
      payload_type,
      planned_payloads[i],
    )
    patterns.push(result.pattern)
    for symbol in result.symbols {
      symbols.push(symbol)
    }
  }
  { patterns, symbols }
}

///|
fn plan_enum_payload_patterns(
  context : BindingContext,
  variant : @binding.EnumVariantDef,
  payloads : Array[@ast.Pattern],
  span : SourceSpan,
) -> Array[@ast.Pattern] {
  let planned : Array[@ast.Pattern?] = []
  for _ in 0..<variant.payloads.length() {
    planned.push(None)
  }
  let mut positional_index = 0
  for payload in payloads {
    match payload {
      @ast.Pattern::Rest(rest_span) =>
        for i in 0..<planned.length() {
          if planned[i] is None {
            planned[i] = Some(@ast.Pattern::Wildcard(rest_span))
          }
        }
      @ast.Pattern::Labelled(label, pattern, label_span) => {
        let index = enum_payload_label_index(variant, label)
        if index < 0 {
          context.error(
            "VNX1809",
            "unknown enum payload label: " + label,
            label_span,
          )
        } else if planned[index] is Some(_) {
          context.error(
            "VNX1810",
            "duplicate enum payload label: " + label,
            label_span,
          )
        } else {
          planned[index] = Some(pattern)
        }
      }
      _ => {
        positional_index = next_empty_enum_pattern_slot(
          planned, positional_index,
        )
        if positional_index >= planned.length() {
          context.error("VNX1802", "enum match payload arity mismatch", span)
        } else {
          planned[positional_index] = Some(payload)
          positional_index = positional_index + 1
        }
      }
    }
  }
  let result : Array[@ast.Pattern] = []
  for item in planned {
    match item {
      Some(pattern) => result.push(pattern)
      None => ()
    }
  }
  result
}

///|
fn next_empty_enum_pattern_slot(
  patterns : Array[@ast.Pattern?],
  start : Int,
) -> Int {
  let mut index = start
  while index < patterns.length() && patterns[index] is Some(_) {
    index = index + 1
  }
  index
}

///|
fn enum_payload_label_index(
  variant : @binding.EnumVariantDef,
  label : String,
) -> Int {
  for i in 0..<variant.payloads.length() {
    if variant.payloads[i].label == Some(label) {
      return i
    }
  }
  -1
}

///|
fn resolve_match_enum_definition(
  index : DeclarationIndex,
  target_type : TypeRef,
  type_syntax : @ast.TypeSyntax?,
) -> @binding.EnumDefinition? {
  match type_syntax {
    Some(type_) =>
      match
        @semantic.find_visible_type_header(
          index,
          type_.package_alias,
          type_.name,
        ) {
        Some(header) =>
          match @semantic.find_type_definition(index, header.symbol.id) {
            Some(TypeDefinition::Enum(def)) => Some(def)
            _ => None
          }
        None => None
      }
    None =>
      match target_type {
        TypeRef::Declared(symbol, _) =>
          match @semantic.find_type_definition(index, symbol.id) {
            Some(TypeDefinition::Enum(def)) => Some(def)
            _ => None
          }
        _ => None
      }
  }
}
