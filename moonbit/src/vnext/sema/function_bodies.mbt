///|
fn bind_function_body(
  context : BindingContext,
  index : DeclarationIndex,
  ast : Module,
  function : Function,
) -> BoundFunction {
  let fid = function_id(
    context.package_id,
    context.module_name,
    function_decl_name(function),
  )
  let signature = find_function(index, fid)
  let typing = @semantic.typing_context()
  let function_context = context_with_type_params(
    context,
    type_param_constraints(function.type_params),
    Some(signature.return_type),
    signature.effect,
    Some(fid),
  )
  let body = bind_expr(
    typing,
    function_context,
    index,
    source_function_parameter_symbols(signature.parameters, function.params),
    function.body,
    signature.return_type,
    ast,
  )
  let params : Array[BoundParam] = []
  for param in source_function_parameters(signature.parameters, function.params) {
    params.push({
      symbol_id: param.symbol.id,
      name: param.symbol.name,
      label: param.label,
      optional: param.optional,
      has_default: param.has_default,
      default_ref: param.default_ref,
      type_: param.symbol.type_,
    })
  }
  {
    symbol_id: fid,
    name: function_decl_name(function),
    type_params: type_param_defs(function.type_params),
    params,
    return_type: signature.return_type,
    effect: signature.effect,
    external: None,
    body,
    span: function.span,
  }
}

///|
fn source_function_parameters(
  signature_params : Array[ParameterDef],
  source_params : Array[@ast.Param],
) -> Array[ParameterDef] {
  let params : Array[ParameterDef] = []
  for i in 0..<signature_params.length() {
    let param = signature_params[i]
    let name = if i < source_params.length() && source_params[i].name != "_" {
      source_params[i].name
    } else {
      param.symbol.name
    }
    params.push({
      symbol: {
        id: param.symbol.id,
        kind: param.symbol.kind,
        name,
        type_: param.symbol.type_,
        span: param.symbol.span,
      },
      label: param.label,
      optional: param.optional,
      has_default: param.has_default,
      default_ref: param.default_ref,
      argument_type: param.argument_type,
    })
  }
  params
}

///|
fn source_function_parameter_symbols(
  signature_params : Array[ParameterDef],
  source_params : Array[@ast.Param],
) -> Array[Symbol] {
  parameter_symbols(source_function_parameters(signature_params, source_params))
}

///|
fn bind_external_function(
  context : BindingContext,
  index : DeclarationIndex,
  function : Function,
  target : String,
  body : String,
) -> BoundFunction {
  let fid = function_id(
    context.package_id,
    context.module_name,
    function_decl_name(function),
  )
  let signature = find_function(index, fid)
  let params : Array[BoundParam] = []
  for param in signature.parameters {
    params.push({
      symbol_id: param.symbol.id,
      name: param.symbol.name,
      label: param.label,
      optional: param.optional,
      has_default: param.has_default,
      default_ref: param.default_ref,
      type_: param.symbol.type_,
    })
  }
  {
    symbol_id: fid,
    name: function_decl_name(function),
    type_params: type_param_defs(function.type_params),
    params,
    return_type: signature.return_type,
    effect: signature.effect,
    external: Some({ target, body }),
    body: BoundExpr::UnitLiteral(@binding.unit_type(), function.span),
    span: function.span,
  }
}

///|
fn bind_impl_method_bodies(
  context : BindingContext,
  index : DeclarationIndex,
  ast : Module,
) -> Array[BoundFunction] {
  bind_all_impl_method_bodies(context, index, ast, [])
}

///|
fn bind_selected_impl_method_bodies(
  context : BindingContext,
  index : DeclarationIndex,
  ast : Module,
  selected_function_ids : Array[String],
) -> Array[BoundFunction] {
  bind_all_impl_method_bodies(context, index, ast, selected_function_ids)
}

///|
fn bind_all_impl_method_bodies(
  context : BindingContext,
  index : DeclarationIndex,
  ast : Module,
  selected_function_ids : Array[String],
) -> Array[BoundFunction] {
  let functions : Array[BoundFunction] = []
  for impl_decl in ast.impls {
    for impl_method in impl_decl.methods {
      match
        bind_one_impl_method_body(
          context, index, ast, impl_decl, impl_method, selected_function_ids,
        ) {
        Some(function) => functions.push(function)
        None => ()
      }
    }
  }
  functions
}

///|
fn bind_one_impl_method_body(
  context : BindingContext,
  index : DeclarationIndex,
  ast : Module,
  impl_decl : ImplDecl,
  impl_method : @ast.ImplMethodDecl,
  selected_function_ids : Array[String],
) -> BoundFunction? {
  if is_default_trait_impl_decl(impl_decl) {
    bind_default_trait_impl_method_body(
      context, index, ast, impl_decl, impl_method, selected_function_ids,
    )
  } else {
    bind_concrete_impl_method_body(
      context, index, ast, impl_decl, impl_method, selected_function_ids,
    )
  }
}

///|
fn bind_default_trait_impl_method_body(
  context : BindingContext,
  index : DeclarationIndex,
  ast : Module,
  impl_decl : ImplDecl,
  impl_method : @ast.ImplMethodDecl,
  selected_function_ids : Array[String],
) -> BoundFunction? {
  match impl_method.body {
    None => None
    Some(body_expr) => {
      let mut trait_name = impl_decl.trait_name
      for part in impl_decl.trait_name.split(".") {
        trait_name = part.to_owned()
      }
      let trait_def = match
        @semantic.find_visible_trait(index, None, trait_name) {
        Some(def) => def
        None => return None
      }
      let function_id = @semantic.default_trait_method_function_id(
        trait_def.symbol.id,
        impl_method.name,
      )
      if selected_function_ids.length() > 0 &&
        !contains_string(selected_function_ids, function_id) {
        return None
      }
      let signature = match @semantic.find_function(index, function_id) {
        Some(found) => found
        None => return None
      }
      let binding_type_params = @semantic.default_trait_impl_type_params(
        type_param_constraints(impl_decl.type_params),
        trait_def.symbol.name,
      )
      let trait_ref : TraitRef = { trait_: trait_def.symbol, args: [] }
      let typing = @semantic.typing_context()
      let function_context = context_with_trait_default(
        context_with_type_params(
          context,
          binding_type_params,
          Some(signature.return_type),
          signature.effect,
          Some(function_id),
        ),
        trait_ref,
      )
      let body = bind_expr(
        typing,
        function_context,
        index,
        impl_method_parameter_symbols(signature.parameters, impl_method.params),
        body_expr,
        signature.return_type,
        ast,
      )
      let params : Array[BoundParam] = []
      for
        param in impl_method_parameters(
          signature.parameters,
          impl_method.params,
        ) {
        params.push({
          symbol_id: param.symbol.id,
          name: param.symbol.name,
          label: param.label,
          optional: param.optional,
          has_default: param.has_default,
          default_ref: param.default_ref,
          type_: param.symbol.type_,
        })
      }
      Some({
        symbol_id: function_id,
        name: impl_method.name,
        type_params: default_trait_impl_type_param_defs(
          impl_decl,
          trait_def.symbol.name,
        ),
        params,
        return_type: signature.return_type,
        effect: signature.effect,
        external: None,
        body,
        span: impl_method.span,
      })
    }
  }
}

///|
fn default_trait_impl_type_param_defs(
  impl_decl : ImplDecl,
  trait_name : String,
) -> Array[@ir.BoundTypeParam] {
  let constraints = @semantic.default_trait_impl_type_params(
    type_param_constraints(impl_decl.type_params),
    trait_name,
  )
  let result : Array[@ir.BoundTypeParam] = []
  for param in constraints {
    result.push({ name: param.name, constraints: param.constraints })
  }
  result
}

///|
fn context_with_trait_default(
  context : BindingContext,
  trait_ref : TraitRef,
) -> BindingContext {
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
    used_trait_impls: context.used_trait_impls,
    used_trait_impl_keys: context.used_trait_impl_keys,
    trait_default_context: Some(trait_ref),
    diagnostics: context.diagnostics,
    suppress_diagnostics: context.suppress_diagnostics,
  }
}

///|
fn bind_concrete_impl_method_body(
  context : BindingContext,
  index : DeclarationIndex,
  ast : Module,
  impl_decl : ImplDecl,
  impl_method : @ast.ImplMethodDecl,
  selected_function_ids : Array[String],
) -> BoundFunction? {
  match impl_method.body {
    None => return None
    Some(body_expr) => {
      let self_type = resolve_type_with_params(
        context,
        index,
        impl_decl.self_type,
        type_param_names(impl_decl.type_params),
      )
      let selected_concrete_signature = if selected_function_ids.length() > 0 {
        find_selected_concrete_impl_method_signature(
          index,
          self_type,
          impl_method.name,
          selected_function_ids,
        )
      } else {
        None
      }
      let mut trait_name = impl_decl.trait_name
      for part in impl_decl.trait_name.split(".") {
        trait_name = part.to_owned()
      }
      let trait_def = match
        @semantic.find_visible_trait(index, None, trait_name) {
        Some(def) => def
        None =>
          match selected_concrete_signature {
            Some(_) =>
              {
                symbol: @binding.make_type_symbol(
                  context.package_id,
                  context.module_name,
                  trait_name,
                ),
                type_params: [],
                methods: [],
                span: impl_decl.span,
              }
            None => return None
          }
      }
      let selected_declared_signature = if selected_function_ids.length() > 0 {
        let declared_function_id = @semantic.impl_method_function_id_for(
          index,
          trait_def.symbol,
          self_type,
          impl_method.name,
        )
        if contains_string(selected_function_ids, declared_function_id) {
          Some(find_function(index, declared_function_id))
        } else {
          None
        }
      } else {
        None
      }
      let signature = match selected_concrete_signature {
        Some(found) => found
        None =>
          match selected_declared_signature {
            Some(found) => found
            None =>
              match
                find_impl_method_body_signature(
                  index,
                  trait_def,
                  self_type,
                  impl_method.name,
                  selected_function_ids,
                ) {
                Some(found) => found
                None =>
                  if selected_function_ids.length() > 0 {
                    match
                      find_impl_method_body_signature(
                        index,
                        trait_def,
                        self_type,
                        impl_method.name,
                        [],
                      ) {
                      Some(found) =>
                        if contains_string(
                            selected_function_ids,
                            found.function_id,
                          ) ||
                          (
                            !found.function_id.has_prefix("default-trait:") &&
                            selected_includes_default_trait_method(
                              selected_function_ids,
                              trait_def.symbol.id,
                              impl_method.name,
                            )
                          ) {
                          found
                        } else {
                          return None
                        }
                      None => return None
                    }
                  } else {
                    return None
                  }
              }
          }
      }
      if selected_function_ids.length() > 0 &&
        !contains_string(selected_function_ids, signature.function_id) {
        if !signature.function_id.has_prefix("default-trait:") &&
          selected_includes_default_trait_method(
            selected_function_ids,
            trait_def.symbol.id,
            impl_method.name,
          ) {
          ()
        } else {
          return None
        }
      }
      let typing = @semantic.typing_context()
      let function_context = context_with_type_params(
        context,
        type_param_constraints(impl_decl.type_params),
        Some(signature.return_type),
        signature.effect,
        Some(signature.function_id),
      )
      let body = bind_expr(
        typing,
        function_context,
        index,
        impl_method_parameter_symbols(signature.parameters, impl_method.params),
        body_expr,
        signature.return_type,
        ast,
      )
      let params : Array[BoundParam] = []
      let impl_params = impl_method_parameters(
        signature.parameters,
        impl_method.params,
      )
      for param in impl_params {
        params.push({
          symbol_id: param.symbol.id,
          name: param.symbol.name,
          label: param.label,
          optional: param.optional,
          has_default: param.has_default,
          default_ref: param.default_ref,
          type_: param.symbol.type_,
        })
      }
      Some({
        symbol_id: signature.function_id,
        name: impl_method.name,
        type_params: type_param_defs(impl_decl.type_params),
        params,
        return_type: signature.return_type,
        effect: signature.effect,
        external: None,
        body,
        span: impl_method.span,
      })
    }
  }
}

///|
fn find_selected_concrete_impl_method_signature(
  index : DeclarationIndex,
  self_type : TypeRef,
  method_name : String,
  selected_function_ids : Array[String],
) -> FunctionSignature? {
  let mut default_match : FunctionSignature? = None
  for impl_def in index.impls {
    if !@binding.type_equal(impl_def.self_type, self_type) {
      continue
    }
    for impl_method in impl_def.methods {
      if impl_method.name == method_name &&
        contains_string(selected_function_ids, impl_method.function_id) {
        match impl_method.body {
          @semantic.ImplMethodBody::DefaultMethod =>
            if default_match is None {
              default_match = Some(
                find_function(index, impl_method.function_id),
              )
            }
          _ => return Some(find_function(index, impl_method.function_id))
        }
      }
    }
  }
  default_match
}

///|
fn selected_includes_default_trait_method(
  selected_function_ids : Array[String],
  trait_id : String,
  method_name : String,
) -> Bool {
  contains_string(
    selected_function_ids,
    @semantic.default_trait_method_function_id(trait_id, method_name),
  )
}

///|
fn is_default_trait_impl_decl(impl_decl : ImplDecl) -> Bool {
  impl_decl.self_type.package_alias is None &&
  impl_decl.self_type.name == "Self" &&
  impl_decl.self_type.args.length() == 0
}

///|
fn find_impl_method_function_signature(
  index : DeclarationIndex,
  trait_def : @semantic.TraitDefinition,
  self_type : TypeRef,
  method_name : String,
) -> FunctionSignature? {
  let mut default_method : FunctionSignature? = None
  for impl_def in index.impls {
    if impl_def.trait_ref.trait_.id == trait_def.symbol.id &&
      @binding.type_equal(impl_def.self_type, self_type) {
      for impl_method in impl_def.methods {
        if impl_method.name == method_name {
          match impl_method.body {
            @semantic.ImplMethodBody::DefaultMethod =>
              if default_method is None {
                default_method = Some(
                  find_function(index, impl_method.function_id),
                )
              }
            _ => return Some(find_function(index, impl_method.function_id))
          }
        }
      }
    }
  }
  default_method
}

///|
fn find_impl_method_body_signature(
  index : DeclarationIndex,
  trait_def : @semantic.TraitDefinition,
  self_type : TypeRef,
  method_name : String,
  selected_function_ids : Array[String],
) -> FunctionSignature? {
  match
    find_concrete_impl_method_function_signature(
      index, trait_def, self_type, method_name,
    ) {
    Some(concrete) =>
      if selected_function_ids.length() == 0 ||
        contains_string(selected_function_ids, concrete.function_id) ||
        selected_includes_default_trait_method(
          selected_function_ids,
          trait_def.symbol.id,
          method_name,
        ) {
        return Some(concrete)
      }
    None => ()
  }
  if selected_function_ids.length() > 0 {
    for impl_def in index.impls {
      if impl_def.trait_ref.trait_.id != trait_def.symbol.id ||
        !@binding.type_equal(impl_def.self_type, self_type) {
        continue
      }
      for impl_method in impl_def.methods {
        if impl_method.name == method_name &&
          contains_string(selected_function_ids, impl_method.function_id) {
          return Some(find_function(index, impl_method.function_id))
        }
      }
    }
    return None
  }
  find_impl_method_function_signature(index, trait_def, self_type, method_name)
}

///|
fn find_concrete_impl_method_function_signature(
  index : DeclarationIndex,
  trait_def : @semantic.TraitDefinition,
  self_type : TypeRef,
  method_name : String,
) -> FunctionSignature? {
  for impl_def in index.impls {
    if impl_def.trait_ref.trait_.id != trait_def.symbol.id ||
      !@binding.type_equal(impl_def.self_type, self_type) {
      continue
    }
    for impl_method in impl_def.methods {
      if impl_method.name == method_name &&
        !(impl_method.body is @semantic.ImplMethodBody::DefaultMethod) {
        return Some(find_function(index, impl_method.function_id))
      }
    }
  }
  None
}

///|
fn impl_method_parameters(
  signature_params : Array[ParameterDef],
  source_params : Array[@ast.Param],
) -> Array[ParameterDef] {
  let params : Array[ParameterDef] = []
  for i in 0..<signature_params.length() {
    let param = signature_params[i]
    let name = if i < source_params.length() && source_params[i].name != "_" {
      source_params[i].name
    } else {
      param.symbol.name
    }
    params.push({
      symbol: {
        id: param.symbol.id,
        kind: param.symbol.kind,
        name,
        type_: param.symbol.type_,
        span: param.symbol.span,
      },
      label: param.label,
      optional: param.optional,
      has_default: param.has_default,
      default_ref: param.default_ref,
      argument_type: param.argument_type,
    })
  }
  params
}

///|
fn impl_method_parameter_symbols(
  signature_params : Array[ParameterDef],
  source_params : Array[@ast.Param],
) -> Array[Symbol] {
  parameter_symbols(impl_method_parameters(signature_params, source_params))
}

///|
fn type_param_names(type_params : Array[@ast.TypeParamSyntax]) -> Array[String] {
  let names : Array[String] = []
  for param in type_params {
    names.push(param.name)
  }
  names
}

///|
fn type_param_defs(
  type_params : Array[@ast.TypeParamSyntax],
) -> Array[@ir.BoundTypeParam] {
  let result : Array[@ir.BoundTypeParam] = []
  for param in type_params {
    result.push({ name: param.name, constraints: param.constraints })
  }
  result
}

///|
fn type_param_constraints(
  type_params : Array[@ast.TypeParamSyntax],
) -> Array[TypeParamConstraint] {
  let result : Array[TypeParamConstraint] = []
  for param in type_params {
    result.push({ name: param.name, constraints: param.constraints })
  }
  result
}

///|
fn context_with_type_params(
  context : BindingContext,
  type_params : Array[TypeParamConstraint],
  return_type : TypeRef?,
  effect : @binding.EffectRef,
  owner_id : String?,
) -> BindingContext {
  {
    module_name: context.module_name,
    package_id: context.package_id,
    imports: context.imports,
    current_type_params: type_params,
    symbols: context.symbols,
    types: context.types,
    functions: context.functions,
    imported_functions: context.imported_functions,
    imported_globals: context.imported_globals,
    default_arguments: context.default_arguments,
    default_arguments_by_id: context.default_arguments_by_id,
    current_return_type: return_type,
    current_owner_id: owner_id,
    current_effect: effect,
    loop_depth: context.loop_depth,
    used_trait_impls: context.used_trait_impls,
    used_trait_impl_keys: context.used_trait_impl_keys,
    trait_default_context: context.trait_default_context,
    diagnostics: context.diagnostics,
    suppress_diagnostics: context.suppress_diagnostics,
  }
}

///|
fn bind_global(
  context : BindingContext,
  index : DeclarationIndex,
  ast : Module,
  global : GlobalLet,
) -> BoundGlobal {
  let type_ = if global.has_type_annotation {
    resolve_type(context, index, global.type_)
  } else {
    infer_global_body_type(global.value)
  }
  let symbol_id = global_id(
    context.package_id,
    context.module_name,
    global.name,
  )
  let typing = @semantic.typing_context()
  let value = bind_expr(typing, context, index, [], global.value, type_, ast)
  { symbol_id, name: global.name, type_, value, span: global.span }
}

///|
fn infer_global_body_type(value : @ast.Expr) -> TypeRef {
  match value {
    @ast.Expr::IntLiteral(_, _) => @binding.int_type()
    @ast.Expr::FloatLiteral(_, _) => @binding.double_type()
    @ast.Expr::StringLiteral(_, _) => @binding.string_type()
    @ast.Expr::BoolLiteral(_, _) => @binding.bool_type()
    @ast.Expr::CharLiteral(_, _) => @binding.char_type()
    @ast.Expr::UnitLiteral(_) => @binding.unit_type()
    _ => @binding.error_type()
  }
}
