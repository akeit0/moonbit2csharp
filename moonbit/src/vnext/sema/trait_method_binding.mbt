///|
fn bind_trait_method_call(
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
) -> BoundExpr {
  bind_trait_method_call_with_package_alias(
    typing,
    context,
    index,
    scope,
    receiver,
    method_name,
    args,
    expected_result,
    span,
    ast,
    None,
  )
}

///|
fn bind_trait_method_call_with_package_alias(
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
  package_alias : String?,
) -> BoundExpr {
  let bound_receiver = bind_expr(
    typing,
    context,
    index,
    scope,
    receiver,
    @semantic.local_inference_type(
      "trait-receiver:" +
      method_name +
      ":" +
      span.start.to_string() +
      ":" +
      span.end.to_string(),
    ),
    ast,
  )
  let receiver_type = @semantic.resolve_inferred_type(
    typing,
    @ir.expr_type(bound_receiver),
  )
  match
    trait_method_selection(
      context, index, receiver_type, method_name, package_alias,
    ) {
    Some(selection) => {
      let parameters = trait_method_parameters(
        selection.method_id,
        selection.parameters,
        selection.self_type,
        span,
      )
      let selected = choose_trait_method_arguments(
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
      )
      match selected {
        Some(plan) => {
          let bound_args = bind_argument_plan(
            typing, context, index, scope, plan, ast,
          )
          match selection.dispatch {
            BoundTraitDispatch::ConcreteImpl(_, _) => {
              mark_used_trait_impl(
                context,
                selection.trait_ref,
                selection.self_type,
              )
              for usage in selection.impl_type_param_usages {
                mark_used_trait_impl(context, usage.trait_ref, usage.self_type)
              }
            }
            _ => ()
          }
          BoundExpr::TraitMethodCall(
            bound_receiver,
            selection.trait_ref,
            selection.method_id,
            method_name,
            bound_args,
            selection.dispatch,
            selection.return_type,
            span,
          )
        }
        None => {
          context.error(
            "VNX1201",
            "trait method does not accept " +
            args.length().to_string() +
            " argument(s)",
            span,
          )
          BoundExpr::Error("unresolved trait method call", error_type(), span)
        }
      }
    }
    None => {
      context.error("VNX1800", "unknown trait method: " + method_name, span)
      BoundExpr::Error("unknown trait method", error_type(), span)
    }
  }
}

///|
fn trait_method_selection(
  context : BindingContext,
  index : DeclarationIndex,
  receiver_type : TypeRef,
  method_name : String,
  package_alias : String?,
) -> TraitMethodSelection? {
  if trait_default_context_applies(context, receiver_type) {
    match context.trait_default_context {
      Some(trait_ref) =>
        return trait_method_selection_for_trait(
          index, trait_ref, receiver_type, method_name, context,
        )
      None => ()
    }
  }
  match receiver_type {
    TypeRef::TraitObject(trait_ref) =>
      match
        @semantic.find_trait_method(index, trait_ref.trait_.id, method_name) {
        Some(entry) =>
          Some({
            trait_ref,
            method_id: entry.trait_method.method_id,
            parameters: entry.trait_method.parameters,
            return_type: substitute_self_type(
              entry.trait_method.return_type,
              receiver_type,
            ),
            self_type: receiver_type,
            dispatch: BoundTraitDispatch::TraitObject,
            impl_type_param_usages: [],
          })
        None => None
      }
    TypeRef::TypeParameter(name, _) =>
      trait_method_selection_from_type_param(
        context, index, name, receiver_type, method_name, package_alias,
      )
    TypeRef::Builtin("Self") =>
      trait_method_selection_from_type_param(
        context,
        index,
        default_trait_type_param_name(context),
        receiver_type,
        method_name,
        package_alias,
      )
    _ =>
      match
        @semantic.find_concrete_trait_method_candidate(
          index,
          receiver_type,
          method_name,
          None,
        ) {
        Some(candidate) =>
          Some({
            trait_ref: candidate.trait_ref,
            method_id: candidate.trait_method.method_id,
            parameters: candidate.trait_method.parameters,
            return_type: substitute_self_type(
              candidate.trait_method.return_type,
              receiver_type,
            ),
            self_type: receiver_type,
            dispatch: BoundTraitDispatch::ConcreteImpl(
              candidate.impl_method.function_id,
              selected_impl_intrinsic(candidate.impl_method.body),
            ),
            impl_type_param_usages: concrete_impl_type_param_usages(
              index, candidate, receiver_type,
            ),
          })
        None => None
      }
  }
}

///|
fn trait_default_context_applies(
  context : BindingContext,
  receiver_type : TypeRef,
) -> Bool {
  match context.trait_default_context {
    None => false
    Some(_) =>
      match receiver_type {
        TypeRef::Builtin("Self") => true
        TypeRef::TypeParameter(name, _) =>
          name == default_trait_type_param_name(context)
        _ => false
      }
  }
}

///|
fn default_trait_type_param_name(context : BindingContext) -> String {
  if context.current_type_params.length() > 0 {
    context.current_type_params[0].name
  } else {
    "T"
  }
}

///|
fn trait_method_selection_for_trait(
  index : DeclarationIndex,
  trait_ref : TraitRef,
  receiver_type : TypeRef,
  method_name : String,
  context : BindingContext,
) -> TraitMethodSelection? {
  match @semantic.find_trait_method(index, trait_ref.trait_.id, method_name) {
    Some(entry) =>
      Some(
        trait_method_selection_from_type_param_entry(
          entry,
          receiver_type,
          default_trait_type_param_name(context),
        ),
      )
    None => None
  }
}

///|
fn selected_impl_intrinsic(body : @semantic.ImplMethodBody) -> String? {
  match body {
    @semantic.ImplMethodBody::Intrinsic(intrinsic) => Some(intrinsic)
    _ => None
  }
}

///|
fn trait_method_selection_from_type_param(
  context : BindingContext,
  index : DeclarationIndex,
  type_param_name : String,
  receiver_type : TypeRef,
  method_name : String,
  package_alias : String?,
) -> TraitMethodSelection? {
  match
    find_type_param_constraints(context.current_type_params, type_param_name) {
    Some(constraints) =>
      return find_type_param_constraint_method(
        index, constraints, method_name, receiver_type, type_param_name, package_alias,
      )
    None => ()
  }
  None
}

///|
fn find_type_param_constraint_method(
  index : DeclarationIndex,
  constraints : Array[String],
  method_name : String,
  receiver_type : TypeRef,
  type_param_name : String,
  package_alias : String?,
) -> TraitMethodSelection? {
  for constraint in constraints {
    let (constraint_package_alias, trait_name) = split_qualified_trait_constraint(
      constraint,
    )
    let resolved_package_alias = match package_alias {
      Some(alias_name) => Some(alias_name)
      None => constraint_package_alias
    }
    match
      @semantic.find_visible_trait(index, resolved_package_alias, trait_name) {
      Some(trait_def) =>
        match
          @semantic.find_trait_method(index, trait_def.symbol.id, method_name) {
          Some(entry) =>
            return Some(
              trait_method_selection_from_type_param_entry(
                entry, receiver_type, type_param_name,
              ),
            )
          None => ()
        }
      None => ()
    }
  }
  None
}

///|
fn trait_method_selection_from_type_param_trait(
  context : BindingContext,
  index : DeclarationIndex,
  type_param_name : String,
  receiver_type : TypeRef,
  trait_symbol : @binding.TypeSymbolRef,
  method_name : String,
) -> TraitMethodSelection? {
  match
    find_type_param_constraints(context.current_type_params, type_param_name) {
    Some(constraints) =>
      if type_param_constraints_include_trait(index, constraints, trait_symbol) {
        match @semantic.find_trait_method(index, trait_symbol.id, method_name) {
          Some(entry) =>
            return Some(
              trait_method_selection_from_type_param_entry(
                entry, receiver_type, type_param_name,
              ),
            )
          None => ()
        }
      }
    None => ()
  }
  None
}

///|
fn trait_method_selection_from_type_param_entry(
  entry : @semantic.TraitMethodLookupEntry,
  receiver_type : TypeRef,
  type_param_name : String,
) -> TraitMethodSelection {
  {
    trait_ref: { trait_: entry.trait_symbol, args: [] },
    method_id: entry.trait_method.method_id,
    parameters: entry.trait_method.parameters,
    return_type: substitute_self_type(
      entry.trait_method.return_type,
      receiver_type,
    ),
    self_type: receiver_type,
    dispatch: BoundTraitDispatch::TypeParamBound(
      type_param_impl_name(type_param_name, entry.trait_symbol.name),
    ),
    impl_type_param_usages: [],
  }
}

///|
fn concrete_impl_type_param_usages(
  index : DeclarationIndex,
  candidate : @semantic.ConcreteTraitMethodCandidate,
  receiver_type : TypeRef,
) -> Array[@binding.UsedTraitImpl] {
  let result : Array[@binding.UsedTraitImpl] = []
  guard receiver_type is TypeRef::Declared(_, args) else { return result }
  guard @semantic.find_function(index, candidate.impl_method.function_id)
    is Some(signature) else {
    return result
  }
  for i in 0..<signature.type_params.length() {
    if i >= args.length() {
      break
    }
    for constraint in signature.type_params[i].constraints {
      let (package_alias, trait_name) = split_qualified_trait_constraint(
        constraint,
      )
      match
        concrete_impl_constraint_trait(
          index, candidate, package_alias, trait_name,
        ) {
        Some(trait_def) => {
          let trait_ref : @binding.TraitRef = {
            trait_: trait_def.symbol,
            args: [],
          }
          result.push({ trait_ref, self_type: args[i] })
        }
        None => ()
      }
    }
  }
  result
}

///|
fn concrete_impl_constraint_trait(
  index : DeclarationIndex,
  candidate : @semantic.ConcreteTraitMethodCandidate,
  package_alias : String?,
  trait_name : String,
) -> @semantic.TraitDefinition? {
  if package_alias is None && trait_name == candidate.trait_ref.trait_.name {
    return @semantic.find_trait_by_id(index, candidate.trait_ref.trait_.id)
  }
  @semantic.find_visible_trait(index, package_alias, trait_name)
}

///|
fn find_type_param_constraints(
  type_params : Array[TypeParamConstraint],
  name : String,
) -> Array[String]? {
  for param in type_params {
    if param.name == name {
      return Some(param.constraints)
    }
  }
  None
}

///|
fn type_param_constraints_include_trait(
  index : DeclarationIndex,
  constraints : Array[String],
  trait_symbol : @binding.TypeSymbolRef,
) -> Bool {
  for constraint in constraints {
    let (package_alias, trait_name) = split_qualified_trait_constraint(
      constraint,
    )
    match @semantic.find_visible_trait(index, package_alias, trait_name) {
      Some(trait_def) =>
        if trait_def.symbol.id == trait_symbol.id {
          return true
        }
      None => ()
    }
  }
  false
}

///|
fn split_qualified_trait_constraint(name : String) -> (String?, String) {
  for i in 0..<name.length() {
    if name[i] == '.' {
      return (Some(name[0:i].to_owned()), name[i + 1:].to_owned())
    }
  }
  (None, name)
}

///|
fn trait_method_parameters(
  method_id : String,
  parameters : Array[@binding.ParamTypeRef],
  self_type : TypeRef,
  span : SourceSpan,
) -> Array[ParameterDef] {
  let result : Array[ParameterDef] = []
  for i in 1..<parameters.length() {
    let type_ = substitute_self_type(parameters[i].type_, self_type)
    result.push({
      symbol: {
        id: method_id + ":param:" + i.to_string(),
        kind: SymbolKind::Parameter,
        name: "arg" + (i - 1).to_string(),
        type_,
        span,
      },
      label: parameters[i].label,
      optional: parameters[i].optional,
      has_default: parameters[i].has_default,
      default_ref: None,
      argument_type: type_,
    })
  }
  result
}

///|
fn choose_trait_method_arguments(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  parameters : Array[ParameterDef],
  args : Array[CallArg],
  return_type : TypeRef,
  expected_result : TypeRef,
  _span : SourceSpan,
  ast : Module,
) -> ArgumentPlan? {
  let call_typing = @semantic.typing_context()
  if !is_error_type(expected_result) {
    if !@semantic.unify_types(call_typing, return_type, expected_result) &&
      @semantic.classify_conversion(expected_result, return_type) ==
      @semantic.ConversionKind::Incompatible {
      return None
    }
  }
  match create_argument_plan(context, parameters, args) {
    Some(plan) => {
      for item in plan.items {
        match item {
          ArgumentPlanItem::Supplied(parameter, arg) =>
            if !probe_argument_type(
                call_typing,
                context,
                index,
                scope,
                arg.value,
                parameter.argument_type,
                ast,
              ) {
              return None
            }
          ArgumentPlanItem::Defaulted(_, _)
          | ArgumentPlanItem::OptionalNone(_, _) => ()
        }
      }
      commit_type_substitutions(typing, call_typing.substitutions)
      Some(plan)
    }
    None => None
  }
}

///|
fn substitute_self_type(type_ : TypeRef, self_type : TypeRef) -> TypeRef {
  match type_ {
    TypeRef::Builtin("Self") => self_type
    TypeRef::Tuple(items) => {
      let result : Array[TypeRef] = []
      for item in items {
        result.push(substitute_self_type(item, self_type))
      }
      TypeRef::Tuple(result)
    }
    TypeRef::Function(params, return_type, effect) => {
      let result : Array[@binding.ParamTypeRef] = []
      for param in params {
        result.push({
          label: param.label,
          type_: substitute_self_type(param.type_, self_type),
          optional: param.optional,
          has_default: param.has_default,
        })
      }
      TypeRef::Function(
        result,
        substitute_self_type(return_type, self_type),
        effect,
      )
    }
    TypeRef::Apply(type_constructor, args) => {
      let result : Array[TypeRef] = []
      for arg in args {
        result.push(substitute_self_type(arg, self_type))
      }
      TypeRef::Apply(type_constructor, result)
    }
    TypeRef::Declared(symbol, args) => {
      let result : Array[TypeRef] = []
      for arg in args {
        result.push(substitute_self_type(arg, self_type))
      }
      TypeRef::Declared(symbol, result)
    }
    TypeRef::TraitObject(trait_ref) => {
      let result : Array[TypeRef] = []
      for arg in trait_ref.args {
        result.push(substitute_self_type(arg, self_type))
      }
      TypeRef::TraitObject({ trait_: trait_ref.trait_, args: result })
    }
    _ => type_
  }
}

///|
fn type_param_impl_name(
  type_param_name : String,
  trait_name : String,
) -> String {
  type_param_name + trait_name + "Impl"
}
