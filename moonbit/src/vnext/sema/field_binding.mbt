///|
fn bind_field_access(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target : Expr,
  field_name : String,
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
  match tuple_field_index(@ir.expr_type(bound_target), field_name) {
    Some(index) =>
      return BoundExpr::TupleGet(
        bound_target,
        index,
        tuple_access_item_type(@ir.expr_type(bound_target), index),
        span,
      )
    None => ()
  }
  match field_ref(index, @ir.expr_type(bound_target), field_name) {
    Some(field) =>
      BoundExpr::FieldAccess(bound_target, field, field.type_, span)
    None => {
      context.error("VNX1600", "unknown field: " + field_name, span)
      BoundExpr::Error("unknown field: " + field_name, error_type(), span)
    }
  }
}

///|
fn tuple_field_index(type_ : TypeRef, field_name : String) -> Int? {
  match type_ {
    TypeRef::Tuple(items) =>
      match parse_tuple_field_name(field_name) {
        Some(index) =>
          if index >= 0 && index < items.length() {
            Some(index)
          } else {
            None
          }
        None => None
      }
    _ => None
  }
}

///|
fn tuple_access_item_type(type_ : TypeRef, index : Int) -> TypeRef {
  match type_ {
    TypeRef::Tuple(items) =>
      if index >= 0 && index < items.length() {
        items[index]
      } else {
        error_type()
      }
    _ => error_type()
  }
}

///|
fn parse_tuple_field_name(field_name : String) -> Int? {
  if field_name.length() == 0 {
    return None
  }
  let mut result = 0
  for i in 0..<field_name.length() {
    let ch = field_name[i]
    if ch < '0' || ch > '9' {
      return None
    }
    result = result * 10 + ch.to_int() - '0'.to_int()
  }
  Some(result)
}

///|
fn bind_assignment(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target : Expr,
  value : Expr,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  match target {
    Expr::Name(name, _) =>
      match lookup_symbol(scope, name) {
        Some(symbol) =>
          if symbol.kind == SymbolKind::Local {
            let bound_value = bind_expr(
              typing,
              context,
              index,
              scope,
              value,
              symbol.type_,
              ast,
            )
            BoundExpr::Assign(symbol, bound_value, unit_type(), span)
          } else {
            context.error("VNX1603", "assignment target is not local", span)
            BoundExpr::Error(
              "assignment target is not local",
              error_type(),
              span,
            )
          }
        None => {
          context.error("VNX1100", "unknown name: " + name, span)
          BoundExpr::Error("unknown name: " + name, error_type(), span)
        }
      }
    Expr::FieldAccess(receiver, field_name, _) => {
      let bound_receiver = bind_expr(
        typing,
        context,
        index,
        scope,
        receiver,
        error_type(),
        ast,
      )
      match field_ref(index, @ir.expr_type(bound_receiver), field_name) {
        Some(field) =>
          if field.mutable {
            let bound_value = bind_expr(
              typing,
              context,
              index,
              scope,
              value,
              field.type_,
              ast,
            )
            BoundExpr::FieldAssign(
              bound_receiver,
              field,
              bound_value,
              unit_type(),
              span,
            )
          } else {
            context.error(
              "VNX1601",
              "field is not mutable: " + field_name,
              span,
            )
            BoundExpr::Error("immutable field assignment", error_type(), span)
          }
        None => {
          context.error("VNX1600", "unknown field: " + field_name, span)
          BoundExpr::Error("unknown field: " + field_name, error_type(), span)
        }
      }
    }
    Expr::Index(receiver, index_expr, end_index, is_slice, _) => {
      match
        bind_index_set_alias(
          typing, context, index, scope, receiver, index_expr, end_index, is_slice,
          value, span, ast,
        ) {
        Some(bound_set) => return bound_set
        None => ()
      }
      let bound_get = bind_index_get(
        typing, context, index, scope, receiver, index_expr, end_index, is_slice,
        span, ast,
      )
      match bound_get {
        BoundExpr::IndexGet(bound_receiver, bound_index, item_type, _) => {
          let bound_value = bind_expr(
            typing, context, index, scope, value, item_type, ast,
          )
          BoundExpr::IndexAssign(
            bound_receiver,
            bound_index,
            bound_value,
            unit_type(),
            span,
          )
        }
        _ => bound_get
      }
    }
    _ => {
      context.error("VNX1602", "unsupported assignment target", span)
      BoundExpr::Error("unsupported assignment target", error_type(), span)
    }
  }
}

///|
fn bind_index_get(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target : Expr,
  index_expr : Expr?,
  end_index : Expr?,
  is_slice : Bool,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  if is_slice {
    match
      bind_slice_view_call(
        typing, context, index, scope, target, index_expr, end_index, span, ast,
      ) {
      Some(bound_slice) => return bound_slice
      None => {
        context.error("VNX1905", "cannot find slice implementation", span)
        return BoundExpr::Error(
          "unresolved slice implementation",
          error_type(),
          span,
        )
      }
    }
  }
  match (index_expr, end_index) {
    (Some(index_value), None) => {
      let bound_target = bind_expr(
        typing,
        context,
        index,
        scope,
        target,
        error_type(),
        ast,
      )
      let item_type = index_item_type(@ir.expr_type(bound_target))
      match item_type {
        Some(type_) => {
          let bound_index = bind_expr(
            typing,
            context,
            index,
            scope,
            index_value,
            int_type(),
            ast,
          )
          BoundExpr::IndexGet(bound_target, bound_index, type_, span)
        }
        None =>
          match
            bind_index_get_alias(
              typing, context, index, scope, target, index_value, span, ast,
            ) {
            Some(bound_alias_get) => bound_alias_get
            None => {
              context.error("VNX1905", "unsupported index target type", span)
              BoundExpr::Error("unsupported index", error_type(), span)
            }
          }
      }
    }
    _ => {
      context.error("VNX1905", "unsupported index expression", span)
      BoundExpr::Error("unsupported index", error_type(), span)
    }
  }
}

///|
fn bind_slice_view_call(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target : Expr,
  start_index : Expr?,
  end_index : Expr?,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr? {
  let candidates = functions_with_alias(index, "_[_:_]")
  if candidates.length() == 0 {
    return None
  }
  for candidate in candidates {
    match slice_alias_args(candidate, target, start_index, end_index) {
      Some(args) =>
        match
          choose_function(
            typing,
            diagnostic_free_context(context),
            [candidate],
            scope,
            index,
            args,
            error_type(),
            span,
            ast,
          ) {
          Some(_) =>
            match
              choose_function(
                typing,
                context,
                [candidate],
                scope,
                index,
                args,
                error_type(),
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
                return Some(
                  BoundExpr::Call(
                    probe.callable.function_id,
                    probe.callable.type_args,
                    bound_trait_evidence(context, probe.callable.trait_evidence),
                    bound_args,
                    probe.callable.function_intrinsic,
                    probe.callable.return_type,
                    span,
                  ),
                )
              }
              None => ()
            }
          None => ()
        }
      None => ()
    }
  }
  None
}

///|
fn slice_alias_args(
  candidate : FunctionSignature,
  target : Expr,
  start_index : Expr?,
  end_index : Expr?,
) -> Array[CallArg]? {
  if candidate.parameters.length() < 3 {
    return None
  }
  let args : Array[CallArg] = [
    { label: None, value: target, span: @ast.expr_span(target) },
  ]
  match start_index {
    Some(value) =>
      args.push({
        label: slice_alias_parameter_label(candidate.parameters[1]),
        value,
        span: @ast.expr_span(value),
      })
    None => ()
  }
  match end_index {
    Some(value) =>
      args.push({
        label: slice_alias_parameter_label(candidate.parameters[2]),
        value,
        span: @ast.expr_span(value),
      })
    None => ()
  }
  Some(args)
}

///|
fn slice_alias_parameter_label(parameter : ParameterDef) -> String? {
  match parameter.label {
    Some(label) => Some(label)
    None =>
      if parameter.optional || parameter.has_default {
        Some(parameter.symbol.name)
      } else {
        None
      }
  }
}

///|
fn bind_index_get_alias(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target : Expr,
  index_value : Expr,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr? {
  let candidates = functions_with_alias(index, "_[_]")
  if candidates.length() == 0 {
    return None
  }
  let args : Array[CallArg] = [
    { label: None, value: target, span: @ast.expr_span(target) },
    { label: None, value: index_value, span: @ast.expr_span(index_value) },
  ]
  match
    choose_function(
      typing,
      diagnostic_free_context(context),
      candidates,
      scope,
      index,
      args,
      error_type(),
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
      Some(
        BoundExpr::Call(
          probe.callable.function_id,
          probe.callable.type_args,
          bound_trait_evidence(context, probe.callable.trait_evidence),
          bound_args,
          probe.callable.function_intrinsic,
          probe.callable.return_type,
          span,
        ),
      )
    }
    None => None
  }
}

///|
fn bind_index_set_alias(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target : Expr,
  index_expr : Expr?,
  end_index : Expr?,
  is_slice : Bool,
  value : Expr,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr? {
  if is_slice {
    return None
  }
  match (index_expr, end_index) {
    (Some(index_value), None) => {
      let candidates = functions_with_alias(index, "_[_]=_")
      if candidates.length() == 0 {
        return None
      }
      let args : Array[CallArg] = [
        { label: None, value: target, span: @ast.expr_span(target) },
        { label: None, value: index_value, span: @ast.expr_span(index_value) },
        { label: None, value, span: @ast.expr_span(value) },
      ]
      match
        choose_function(
          typing,
          diagnostic_free_context(context),
          candidates,
          scope,
          index,
          args,
          unit_type(),
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
          Some(
            BoundExpr::Call(
              probe.callable.function_id,
              probe.callable.type_args,
              bound_trait_evidence(context, probe.callable.trait_evidence),
              bound_args,
              probe.callable.function_intrinsic,
              probe.callable.return_type,
              span,
            ),
          )
        }
        None => None
      }
    }
    _ => None
  }
}

///|
fn functions_with_alias(
  index : DeclarationIndex,
  alias_text : String,
) -> Array[FunctionSignature] {
  @semantic.find_functions_by_alias(index, alias_text)
}

///|
fn index_item_type(target_type : TypeRef) -> TypeRef? {
  match @binding.type_constructor_name(target_type) {
    Some((name, [item_type])) =>
      if name is ("Array" | "FixedArray" | "ArrayView") {
        Some(item_type)
      } else {
        None
      }
    _ =>
      match target_type {
        TypeRef::Builtin("String") | TypeRef::Builtin("StringView") =>
          Some(@binding.char_code_unit_type())
        _ => None
      }
  }
}

///|
fn field_ref(
  index : DeclarationIndex,
  receiver_type : TypeRef,
  field_name : String,
) -> @binding.FieldRef? {
  match receiver_type {
    TypeRef::Apply(TypeConstructorRef::Builtin("Ref"), [item_type]) =>
      if field_name == "val" {
        Some({
          owner_type_id: "builtin:Ref",
          field_id: "builtin:Ref:field:val",
          name: "val",
          mutable: true,
          type_: item_type,
        })
      } else {
        None
      }
    TypeRef::Declared(symbol, args) =>
      match @semantic.find_type_definition(index, symbol.id) {
        Some(TypeDefinition::Struct(def)) =>
          match find_field_def(def.fields, field_name) {
            Some(field_def) =>
              Some({
                owner_type_id: def.symbol.id,
                field_id: field_def.id,
                name: field_def.name,
                mutable: field_def.mutable,
                type_: @semantic.substitute_type(
                  def.type_params,
                  args,
                  field_def.type_,
                ),
              })
            None => None
          }
        Some(TypeDefinition::Opaque(_)) | Some(TypeDefinition::Enum(_)) => None
        None => None
      }
    _ => None
  }
}

///|
fn find_field_def(fields : Array[FieldDef], name : String) -> FieldDef? {
  for field in fields {
    if field.name == name {
      return Some(field)
    }
  }
  None
}
