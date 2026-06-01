///|
fn bind_static_access(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target : TypeSyntax,
  member_name : String,
  args : Array[CallArg],
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  match
    bind_static_function_call(
      typing, context, index, scope, target, member_name, args, expected, span, ast,
    ) {
    Some(expr) => return expr
    None => ()
  }
  if target.args.length() > 0 {
    context.error(
      "VNX1705", "explicit enum case type arguments are not supported yet", span,
    )
    return BoundExpr::Error(
      "unsupported enum type arguments",
      error_type(),
      span,
    )
  }
  match
    @semantic.find_visible_type_header(index, target.package_alias, target.name) {
    Some(header) =>
      bind_enum_case(
        typing,
        context,
        index,
        scope,
        header.symbol.id,
        member_name,
        args,
        expected,
        span,
        ast,
      )
    None => {
      context.error("VNX1700", "unknown static target: " + target.name, span)
      BoundExpr::Error("unknown static target", error_type(), span)
    }
  }
}

///|
fn bind_static_function_call(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  target : TypeSyntax,
  member_name : String,
  args : Array[CallArg],
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr? {
  bind_named_static_receiver_call(
    typing,
    context,
    index,
    scope,
    target.name,
    member_name,
    args,
    expected,
    span,
    ast,
  )
}

///|
fn bind_named_static_receiver_call(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  receiver_name : String,
  member_name : String,
  args : Array[CallArg],
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr? {
  let candidates = @semantic.find_static_receiver_functions(
    index, receiver_name, member_name,
  )
  if candidates.length() == 0 {
    return None
  }
  let selected = choose_function(
    typing, context, candidates, scope, index, args, expected, span, ast,
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
fn bind_enum_case(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  type_id : String,
  variant_name : String,
  args : Array[CallArg],
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  match @semantic.find_type_definition(index, type_id) {
    Some(TypeDefinition::Enum(def)) =>
      match
        bind_enum_variant(
          typing, context, index, scope, def, variant_name, args, expected, span,
          ast,
        ) {
        Some(expr) => expr
        None => {
          context.error(
            "VNX1703",
            "unknown enum variant: " + variant_name,
            span,
          )
          BoundExpr::Error("unknown enum variant", error_type(), span)
        }
      }
    Some(TypeDefinition::Opaque(_)) | Some(TypeDefinition::Struct(_)) => {
      context.error("VNX1704", "static member target is not an enum", span)
      BoundExpr::Error("static member target is not enum", error_type(), span)
    }
    None => BoundExpr::Error("unknown enum type", error_type(), span)
  }
}

///|
fn bind_expected_enum_variant(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  variant_name : String,
  args : Array[CallArg],
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr? {
  let expected = @semantic.resolve_inferred_type(typing, expected)
  match expected {
    TypeRef::Declared(symbol, _) =>
      match @semantic.find_type_definition(index, symbol.id) {
        Some(TypeDefinition::Enum(def)) =>
          bind_enum_variant(
            typing, context, index, scope, def, variant_name, args, expected, span,
            ast,
          )
        _ => None
      }
    _ => None
  }
}

///|
fn bind_enum_variant(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  def : @binding.EnumDefinition,
  variant_name : String,
  args : Array[CallArg],
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr? {
  match find_enum_variant(def.variants, variant_name) {
    Some(variant) => {
      if args.length() != variant.payloads.length() {
        context.error("VNX1702", "enum payload arity mismatch", span)
        return Some(
          BoundExpr::Error("enum payload arity mismatch", error_type(), span),
        )
      }
      let planned_args = plan_enum_call_args(context, variant, args, span)
      let enum_type = enum_case_type(def.symbol, def.type_params, expected)
      ignore(@semantic.unify_types(typing, expected, enum_type))
      let type_args = enum_type_args(enum_type)
      let bound_args : Array[BoundExpr] = []
      for i in 0..<planned_args.length() {
        let arg = match planned_args[i] {
          Some(arg) => arg
          None =>
            return Some(
              BoundExpr::Error(
                "invalid enum payload labels",
                error_type(),
                span,
              ),
            )
        }
        let payload_type = @semantic.substitute_type(
          def.type_params,
          type_args,
          variant.payloads[i].type_,
        )
        bound_args.push(
          bind_expr(typing, context, index, scope, arg.value, payload_type, ast),
        )
      }
      Some(
        BoundExpr::EnumCase(
          def.symbol.id,
          variant.id,
          variant.name,
          bound_args,
          enum_type,
          span,
        ),
      )
    }
    None => None
  }
}

///|
fn plan_enum_call_args(
  context : BindingContext,
  variant : @binding.EnumVariantDef,
  args : Array[CallArg],
  span : SourceSpan,
) -> Array[CallArg?] {
  let planned : Array[CallArg?] = []
  for _ in 0..<variant.payloads.length() {
    planned.push(None)
  }
  let mut positional_index = 0
  for arg in args {
    match arg.label {
      Some(label) => {
        let index = enum_call_payload_label_index(variant, label)
        if index < 0 {
          context.error(
            "VNX1706",
            "unknown enum payload label: " + label,
            arg.span,
          )
        } else if planned[index] is Some(_) {
          context.error(
            "VNX1707",
            "duplicate enum payload label: " + label,
            arg.span,
          )
        } else {
          planned[index] = Some(arg)
        }
      }
      None => {
        positional_index = next_empty_enum_arg_slot(planned, positional_index)
        if positional_index >= planned.length() {
          context.error("VNX1702", "enum payload arity mismatch", arg.span)
        } else {
          planned[positional_index] = Some(arg)
          positional_index = positional_index + 1
        }
      }
    }
  }
  for i in 0..<planned.length() {
    if planned[i] is None {
      context.error("VNX1708", "missing enum payload argument", span)
    }
  }
  planned
}

///|
fn next_empty_enum_arg_slot(args : Array[CallArg?], start : Int) -> Int {
  let mut index = start
  while index < args.length() && args[index] is Some(_) {
    index = index + 1
  }
  index
}

///|
fn enum_call_payload_label_index(
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
fn find_enum_variant(
  variants : Array[EnumVariantDef],
  name : String,
) -> EnumVariantDef? {
  for variant in variants {
    if variant.name == name {
      return Some(variant)
    }
  }
  None
}

///|
fn enum_type_args(type_ : TypeRef) -> FixedArray[TypeRef] {
  match type_ {
    TypeRef::Declared(_, args) => args
    _ => []
  }
}

///|
fn enum_case_type(
  symbol : @binding.TypeSymbolRef,
  type_params : Array[String],
  expected : TypeRef,
) -> TypeRef {
  match expected {
    TypeRef::Declared(expected_symbol, args) =>
      if expected_symbol.id == symbol.id {
        TypeRef::Declared(symbol, args)
      } else {
        TypeRef::Declared(symbol, type_param_refs(type_params))
      }
    _ => TypeRef::Declared(symbol, type_param_refs(type_params))
  }
}

///|
fn type_param_refs(type_params : Array[String]) -> FixedArray[TypeRef] {
  let refs = FixedArray::make(type_params.length(), @binding.unresolved_type_ref())
  for i in 0..<type_params.length() {
    let param = type_params[i]
    refs[i] = TypeRef::TypeParameter(param, "type-param:" + param)
  }
  refs
}
