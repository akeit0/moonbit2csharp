///|
priv struct CallArgumentIndex {
  positional : Array[CallArg]
  labelled : Map[String, CallArg]
  has_duplicate_label : Bool
}

///|
fn create_argument_plan(
  context : BindingContext,
  parameters : Array[ParameterDef],
  args : Array[CallArg],
) -> ArgumentPlan? {
  let arg_index = call_argument_index(args)
  if !call_shape_matches(parameters, arg_index) {
    return None
  }
  let items : Array[ArgumentPlanItem] = []
  let mut positional_index = 0
  for parameter in parameters {
    let arg = find_call_arg_for_parameter(
      arg_index, parameter, positional_index,
    )
    if parameter.label is None {
      positional_index = positional_index + 1
    }
    match arg {
      Some(supplied) =>
        items.push(ArgumentPlanItem::Supplied(parameter, supplied))
      None =>
        if parameter.has_default {
          match parameter.default_ref {
            Some(default_ref) =>
              match find_default_argument(context, default_ref) {
                Some(default_arg) =>
                  items.push(
                    ArgumentPlanItem::Defaulted(parameter, default_arg),
                  )
                None => return None
              }
            None => return None
          }
        } else if parameter.optional {
          items.push(
            ArgumentPlanItem::OptionalNone(parameter, parameter.symbol.span),
          )
        } else {
          return None
        }
    }
  }
  Some({ items, })
}

///|
fn bind_argument_plan(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  plan : ArgumentPlan,
  ast : Module,
) -> Array[BoundExpr] {
  let bound_args : Array[BoundExpr] = Array::new(capacity = plan.items.length())
  for item in plan.items {
    match item {
      ArgumentPlanItem::Supplied(parameter, arg) => {
        let value = bind_argument_expr(
          typing,
          context,
          index,
          scope,
          arg.value,
          parameter.argument_type,
          ast,
        )
        mark_used_trait_object_conversion(
          context,
          index,
          parameter.argument_type,
          @ir.expr_type(value),
        )
        if parameter.optional && !parameter.has_default {
          bound_args.push(
            BoundExpr::OptionSome(value, parameter.symbol.type_, arg.span),
          )
        } else {
          bound_args.push(value)
        }
      }
      ArgumentPlanItem::Defaulted(parameter, default_arg) =>
        bound_args.push(
          bind_expr(
            typing,
            context,
            index,
            scope,
            default_arg.value,
            parameter.argument_type,
            ast,
          ),
        )
      ArgumentPlanItem::OptionalNone(parameter, span) =>
        bound_args.push(BoundExpr::OptionNone(parameter.symbol.type_, span))
    }
  }
  bound_args
}

///|
fn bind_argument_expr(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  value : @ast.Expr,
  expected : TypeRef,
  ast : @ast.Module,
) -> BoundExpr {
  let contextual_probe = bind_expr(
    typing,
    diagnostic_free_context(context),
    index,
    scope,
    value,
    expected,
    ast,
  )
  if !is_error_type(@ir.expr_type(contextual_probe)) {
    return bind_expr(typing, context, index, scope, value, expected, ast)
  }
  let inferred = bind_expr(
    typing,
    context,
    index,
    scope,
    value,
    error_type(),
    ast,
  )
  if is_error_type(@ir.expr_type(inferred)) {
    return bind_expr(typing, context, index, scope, value, expected, ast)
  }
  apply_conversion(typing, context, inferred, expected, @ast.expr_span(value))
}

///|
fn parameter_symbols(parameters : Array[ParameterDef]) -> Array[Symbol] {
  let symbols : Array[Symbol] = []
  for parameter in parameters {
    symbols.push(parameter.symbol)
  }
  symbols
}

///|
fn call_argument_index(args : Array[CallArg]) -> CallArgumentIndex {
  let positional : Array[CallArg] = []
  let labelled : Map[String, CallArg] = Map([])
  let mut has_duplicate_label = false
  for arg in args {
    match arg.label {
      Some(label) =>
        match labelled.get(label) {
          Some(_) => has_duplicate_label = true
          None => labelled.set(label, arg)
        }
      None => positional.push(arg)
    }
  }
  { positional, labelled, has_duplicate_label }
}

///|
fn call_shape_matches(
  parameters : Array[ParameterDef],
  args : CallArgumentIndex,
) -> Bool {
  if args.has_duplicate_label {
    return false
  }
  let mut positional_arity = 0
  for parameter in parameters {
    if parameter.label is None {
      positional_arity = positional_arity + 1
    }
  }
  if args.positional.length() != positional_arity {
    return false
  }
  for label, _arg in args.labelled {
    if find_parameter_by_label(parameters, label) is None {
      return false
    }
  }
  for parameter in parameters {
    match parameter.label {
      Some(label) =>
        if !parameter.optional && args.labelled.get(label) is None {
          return false
        }
      None => ()
    }
  }
  true
}

///|
fn find_call_arg_for_parameter(
  args : CallArgumentIndex,
  parameter : ParameterDef,
  positional_index : Int,
) -> CallArg? {
  match parameter.label {
    Some(label) => args.labelled.get(label)
    None =>
      if positional_index < args.positional.length() {
        Some(args.positional[positional_index])
      } else {
        None
      }
  }
}

///|
fn find_default_argument(
  context : BindingContext,
  default_ref : String,
) -> @binding.DefaultArgument? {
  context.default_arguments_by_id.get(default_ref)
}

///|
fn find_parameter_by_label(
  parameters : Array[ParameterDef],
  label : String,
) -> ParameterDef? {
  for parameter in parameters {
    if parameter.label == Some(label) {
      return Some(parameter)
    }
  }
  None
}

///|
fn is_option_type(type_ : TypeRef) -> Bool {
  option_item_type(type_) is Some(_)
}

///|
fn option_item_type(type_ : TypeRef) -> TypeRef? {
  match type_ {
    TypeRef::Apply(TypeConstructorRef::Builtin("Option"), [item]) => Some(item)
    _ => None
  }
}
