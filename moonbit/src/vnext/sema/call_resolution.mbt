///|
fn apply_conversion(
  typing : TypingContext,
  context : BindingContext,
  expr : BoundExpr,
  expected : TypeRef,
  span : SourceSpan,
) -> BoundExpr {
  let actual = @ir.expr_type(expr)
  let expected = @semantic.resolve_inferred_type(typing, expected)
  let conversion = @semantic.classify_conversion_with_inference(
    typing, expected, actual,
  )
  match conversion {
    @semantic.ConversionKind::Identity => expr
    @semantic.ConversionKind::Incompatible =>
      if expected == error_type() || expected == TypeRef::Builtin("Error") {
        expr
      } else {
        context.error(
          "VNX1301",
          "type mismatch: expected " +
          diagnostic_type_name(expected) +
          ", actual " +
          diagnostic_type_name(@semantic.resolve_inferred_type(typing, actual)),
          span,
        )
        expr
      }
    _ =>
      BoundExpr::Conversion(
        @semantic.conversion_kind_text(conversion),
        expr,
        expected,
        span,
      )
  }
}

///|
fn diagnostic_type_name(type_ : TypeRef) -> String {
  match type_ {
    TypeRef::Declared(symbol, args) => {
      let suffix = diagnostic_type_args(args)
      symbol.name + suffix + "@" + symbol.package_id
    }
    TypeRef::Apply(type_constructor, args) =>
      @binding.constructor_name(type_constructor) + diagnostic_type_args(args)
    TypeRef::TypeParameter(name, symbol_id) => name + "@" + symbol_id
    TypeRef::Unknown(reason) => "<unknown:" + reason + ">"
    TypeRef::Tuple(items) => "Tuple" + diagnostic_type_args(items)
    TypeRef::Function(_, _, _) => "Function"
    TypeRef::TraitObject(trait_ref) =>
      trait_ref.trait_.name + diagnostic_type_args(trait_ref.args)
    _ => @binding.type_name(type_)
  }
}

///|
fn diagnostic_type_args(args : Array[TypeRef]) -> String {
  if args.length() == 0 {
    return ""
  }
  let parts : Array[String] = []
  for arg in args {
    parts.push(diagnostic_type_name(arg))
  }
  "[" + parts.join(", ") + "]"
}

///|
fn lookup_symbol(scope : Array[Symbol], name : String) -> Symbol? {
  let mut index = scope.length()
  while index > 0 {
    index = index - 1
    let symbol = scope[index]
    if symbol.name == name {
      return Some(symbol)
    }
  }
  None
}

///|
fn lookup_value_symbol(index : DeclarationIndex, name : String) -> Symbol? {
  @semantic.find_global_by_name(index, name)
}

///|
fn find_function(index : DeclarationIndex, fid : String) -> FunctionSignature {
  match @semantic.find_function(index, fid) {
    Some(signature) => signature
    None => {
      let span = source_span("", 0, 0, 1, 1)
      {
        function_id: fid,
        package_id: "",
        module_path: "",
        name: "",
        receiver_type: None,
        type_params: [],
        parameters: [],
        return_type: error_type(),
        effect: no_raise(),
        aliases: [],
        intrinsic: None,
        is_public: false,
        span,
      }
    }
  }
}

///|
fn choose_function(
  typing : TypingContext,
  context : BindingContext,
  candidates : Array[FunctionSignature],
  scope : Array[Symbol],
  index : DeclarationIndex,
  args : Array[CallArg],
  expected_result : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> CallableProbe? {
  let matching : Array[CallableProbe] = []
  for candidate in unique_function_candidates(candidates) {
    match
      probe_callable(
        context,
        index,
        scope,
        candidate,
        args,
        expected_result,
        span,
        ast,
        [],
        None,
      ) {
      Some(probe) => matching.push(probe)
      None => ()
    }
  }
  if matching.length() == 1 {
    commit_type_substitutions(typing, matching[0].substitutions)
    Some(matching[0])
  } else if matching.length() == 0 {
    context.error(
      "VNX1201",
      "no function accepts " + args.length().to_string() + " argument(s)",
      span,
    )
    None
  } else {
    context.error("VNX1202", "ambiguous function call", span)
    None
  }
}

///|
fn unique_function_candidates(
  candidates : Array[FunctionSignature],
) -> Array[FunctionSignature] {
  let result : Array[FunctionSignature] = []
  for candidate in candidates {
    let mut seen = false
    for existing in result {
      if existing.function_id == candidate.function_id {
        seen = true
        break
      }
    }
    if !seen {
      result.push(candidate)
    }
  }
  result
}

///|
fn choose_operator(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  key : @semantic.OperatorKey,
  self_type : TypeRef,
  args : Array[CallArg],
  expected_result : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> CallableProbe? {
  let matching : Array[CallableProbe] = []
  for
    candidate in find_operator_candidates_with_implicit_self(
      index, key, self_type,
    ) {
    match
      probe_callable(
        context,
        index,
        scope,
        candidate.signature,
        args,
        expected_result,
        span,
        ast,
        [candidate.evidence],
        Some(candidate.method_body),
      ) {
      Some(probe) => matching.push(probe)
      None => ()
    }
  }
  if matching.length() == 1 {
    commit_type_substitutions(typing, matching[0].substitutions)
    Some(matching[0])
  } else if matching.length() == 0 {
    context.error("VNX1201", "no operator implementation", span)
    None
  } else {
    context.error("VNX1202", "ambiguous operator implementation", span)
    None
  }
}

///|
fn find_operator_candidates_with_implicit_self(
  index : DeclarationIndex,
  key : @semantic.OperatorKey,
  self_type : TypeRef,
) -> Array[@semantic.OperatorCandidate] {
  let candidates = @semantic.find_operator_candidates(index, key, self_type)
  if candidates.length() > 0 {
    return candidates
  }
  match implicit_operator_self_type(self_type) {
    Some(converted_self_type) =>
      @semantic.find_operator_candidates(index, key, converted_self_type)
    None => []
  }
}

///|
fn implicit_operator_self_type(self_type : TypeRef) -> TypeRef? {
  match @binding.type_constructor_name(self_type) {
    Some(("Array", [item])) => Some(@binding.array_view_type(item))
    Some(("FixedArray", [item])) => Some(@binding.array_view_type(item))
    _ => None
  }
}

///|
fn probe_callable(
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  signature : FunctionSignature,
  args : Array[CallArg],
  expected_result : TypeRef,
  span : SourceSpan,
  ast : Module,
  trait_evidence : Array[@semantic.ImplEvidence],
  method_body : @semantic.ImplMethodBody?,
) -> CallableProbe? {
  let call_typing = @semantic.typing_context()
  let call_site_key = signature.function_id +
    ":" +
    span.start.to_string() +
    ":" +
    span.end.to_string()
  let type_param_names = function_signature_type_param_names(signature)
  let params : Array[ParameterDef] = []
  for param in signature.parameters {
    params.push({
      symbol: {
        id: param.symbol.id,
        kind: param.symbol.kind,
        name: param.symbol.name,
        type_: @semantic.instantiate_function_type_at_call_site(
          call_typing,
          type_param_names,
          param.symbol.type_,
          call_site_key,
        ),
        span: param.symbol.span,
      },
      label: param.label,
      optional: param.optional,
      has_default: param.has_default,
      default_ref: param.default_ref,
      argument_type: @semantic.instantiate_function_type_at_call_site(
        call_typing,
        type_param_names,
        param.argument_type,
        call_site_key,
      ),
    })
  }
  let return_type = @semantic.instantiate_function_type_at_call_site(
    call_typing,
    type_param_names,
    signature.return_type,
    call_site_key,
  )
  if !is_error_type(expected_result) {
    if !@semantic.unify_types(call_typing, return_type, expected_result) &&
      @semantic.classify_conversion_with_inference(
        call_typing, expected_result, return_type,
      ) ==
      @semantic.ConversionKind::Incompatible {
      return None
    }
  }
  let probe_plan = match create_argument_plan(context, params, args) {
    Some(plan) => plan
    None => return None
  }
  for item in probe_plan.items {
    let ok = match item {
      ArgumentPlanItem::Supplied(parameter, arg) =>
        probe_argument_type(
          call_typing,
          context,
          index,
          scope,
          arg.value,
          parameter.argument_type,
          ast,
        )
      ArgumentPlanItem::Defaulted(parameter, default_arg) =>
        probe_argument_type(
          call_typing,
          context,
          index,
          scope,
          default_arg.value,
          parameter.argument_type,
          ast,
        )
      ArgumentPlanItem::OptionalNone(_, _) => true
    }
    if !ok {
      return None
    }
  }
  let resolved_params : Array[ParameterDef] = []
  for param in params {
    resolved_params.push({
      symbol: {
        id: param.symbol.id,
        kind: param.symbol.kind,
        name: param.symbol.name,
        type_: @semantic.resolve_inferred_type(call_typing, param.symbol.type_),
        span: param.symbol.span,
      },
      label: param.label,
      optional: param.optional,
      has_default: param.has_default,
      default_ref: param.default_ref,
      argument_type: @semantic.resolve_inferred_type(
        call_typing,
        param.argument_type,
      ),
    })
  }
  let argument_plan = match
    create_argument_plan(context, resolved_params, args) {
    Some(plan) => plan
    None => return None
  }
  let type_args = inferred_type_args(
    call_typing, type_param_names, call_site_key,
  )
  let all_trait_evidence = trait_evidence
  for evidence in resolved_generic_trait_evidence(index, signature, type_args) {
    all_trait_evidence.push(evidence)
  }
  Some({
    callable: {
      function_id: signature.function_id,
      receiver_type: None,
      type_args,
      parameters: resolved_params,
      return_type: @semantic.resolve_inferred_type(call_typing, return_type),
      effect: signature.effect,
      function_intrinsic: signature.intrinsic,
      trait_evidence: all_trait_evidence,
      method_body,
    },
    argument_plan,
    substitutions: call_typing.substitutions,
  })
}

///|
fn resolved_generic_trait_evidence(
  index : DeclarationIndex,
  signature : FunctionSignature,
  type_args : Array[TypeRef],
) -> Array[@semantic.ImplEvidence] {
  let result : Array[@semantic.ImplEvidence] = []
  for i in 0..<signature.type_params.length() {
    if i >= type_args.length() {
      break
    }
    let self_type = type_args[i]
    for constraint in signature.type_params[i].constraints {
      let (_alias, trait_name) = split_constraint_name(constraint)
      match @semantic.find_visible_trait(index, _alias, trait_name) {
        Some(trait_def) =>
          match find_impl_evidence_for_trait(index, trait_def, self_type) {
            Some(evidence) => result.push(evidence)
            None => ()
          }
        None => ()
      }
    }
  }
  result
}

///|
fn function_signature_type_param_names(
  signature : FunctionSignature,
) -> Array[String] {
  let result : Array[String] = []
  for param in signature.type_params {
    result.push(param.name)
  }
  result
}

///|
fn split_constraint_name(name : String) -> (String?, String) {
  for i in 0..<name.length() {
    if name[i] == '.' {
      return (Some(name[0:i].to_owned()), name[i + 1:].to_owned())
    }
  }
  (None, name)
}

///|
fn find_impl_evidence_for_trait(
  index : DeclarationIndex,
  trait_def : @semantic.TraitDefinition,
  self_type : TypeRef,
) -> @semantic.ImplEvidence? {
  for
    impl_ in @semantic.find_impls_by_trait_self(
      index,
      trait_def.symbol.id,
      self_type,
    ) {
    return Some({
      evidence_id: impl_.impl_id,
      trait_ref: impl_.trait_ref,
      self_type: impl_.self_type,
      type_args: [],
      source: impl_.source,
    })
  }
  None
}

///|
fn probe_argument_type(
  call_typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  value : Expr,
  parameter_type : TypeRef,
  ast : Module,
) -> Bool {
  let expected = @semantic.resolve_inferred_type(call_typing, parameter_type)
  let probe = bind_expr(
    call_typing,
    diagnostic_free_context(context),
    index,
    scope,
    value,
    expected,
    ast,
  )
  let actual = @ir.expr_type(probe)
  if !is_error_type(actual) {
    return @semantic.classify_conversion_with_inference(
        call_typing, expected, actual,
      ) !=
      @semantic.ConversionKind::Incompatible
  }
  let inferred = bind_expr(
    call_typing,
    diagnostic_free_context(context),
    index,
    scope,
    value,
    error_type(),
    ast,
  )
  let inferred_type = @ir.expr_type(inferred)
  if is_error_type(inferred_type) {
    true
  } else {
    @semantic.classify_conversion_with_inference(
      call_typing, expected, inferred_type,
    ) !=
    @semantic.ConversionKind::Incompatible
  }
}

///|
fn bound_trait_evidence(
  context : BindingContext,
  evidence : Array[@semantic.ImplEvidence],
) -> Array[@ir.BoundTraitEvidence] {
  let result : Array[@ir.BoundTraitEvidence] = []
  for item in evidence {
    mark_used_trait_impl(context, item.trait_ref, item.self_type)
    result.push({
      evidence_id: item.evidence_id,
      trait_ref: item.trait_ref,
      self_type: item.self_type,
      type_args: item.type_args,
    })
  }
  result
}

///|
fn mark_used_trait_impl(
  context : BindingContext,
  trait_ref : @binding.TraitRef,
  self_type : TypeRef,
) -> Unit {
  if context.suppress_diagnostics {
    return
  }
  let key = trait_ref.trait_.id + "|" + @binding.type_key(self_type)
  if context.used_trait_impl_keys.contains(key) {
    return
  }
  context.used_trait_impl_keys.add(key)
  context.used_trait_impls.push({ trait_ref, self_type })
}

///|
fn mark_used_trait_object_conversion(
  context : BindingContext,
  index : DeclarationIndex,
  expected : TypeRef,
  actual : TypeRef,
) -> Unit {
  match expected {
    TypeRef::TraitObject(trait_ref) => {
      let actual = @semantic.resolve_inferred_type(
        @semantic.typing_context(),
        actual,
      )
      for
        _impl in @semantic.find_impls_by_trait_self(
          index,
          trait_ref.trait_.id,
          actual,
        ) {
        mark_used_trait_impl(context, trait_ref, actual)
        return
      }
    }
    _ => ()
  }
}

///|
fn commit_type_substitutions(
  typing : TypingContext,
  substitutions : Array[TypeSubstitution],
) -> Unit {
  for substitution in substitutions {
    if !substitution.variable.has_prefix("type-param:") {
      ignore(
        @semantic.unify_types(
          typing,
          TypeRef::Unknown(substitution.variable),
          substitution.type_,
        ),
      )
    }
  }
}

///|
fn diagnostic_free_context(context : BindingContext) -> BindingContext {
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
    current_return_type: context.current_return_type,
    current_owner_id: context.current_owner_id,
    current_effect: context.current_effect,
    loop_depth: context.loop_depth,
    used_trait_impls: [],
    used_trait_impl_keys: Set::default(),
    trait_default_context: context.trait_default_context,
    diagnostics: [],
    suppress_diagnostics: true,
  }
}

///|
fn is_error_type(type_ : TypeRef) -> Bool {
  match type_ {
    TypeRef::Error(_) => true
    _ => false
  }
}

///|
fn inferred_type_args(
  typing : TypingContext,
  type_params : Array[String],
  call_site_key : String,
) -> Array[TypeRef] {
  let args : Array[TypeRef] = []
  for param in type_params {
    args.push(
      @semantic.resolve_inferred_type(
        typing,
        TypeRef::Unknown("infer:call:" + call_site_key + ":" + param),
      ),
    )
  }
  args
}
