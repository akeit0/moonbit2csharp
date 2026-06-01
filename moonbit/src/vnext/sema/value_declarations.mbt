///|
fn collect_functions(
  context : BindingContext,
  index : DeclarationIndex,
  ast : Module,
) -> Unit {
  for function in ast.functions {
    let type_params = type_param_names(function.type_params)
    let type_param_constraints = type_param_constraints(function.type_params)
    let receiver_type = match function.receiver {
      Some(receiver) =>
        Some(
          resolve_function_receiver_type(context, index, receiver, type_params),
        )
      None => None
    }
    let return_type = resolve_function_member_type(
      context,
      index,
      function.return_type,
      type_params,
      receiver_type,
    )
    let effect = match function.raises {
      Some(error_type) =>
        @binding.EffectRef::Raises(
          resolve_function_member_type(
            context, index, error_type, type_params, receiver_type,
          ),
        )
      None => no_raise()
    }
    let fid = function_id(
      context.package_id,
      context.module_name,
      function_decl_name(function),
    )
    let params : Array[ParameterDef] = []
    for param in function.params {
      let has_default = param.default_value is Some(_)
      let default_ref = if has_default {
        Some(default_argument_id(fid, param.name))
      } else {
        None
      }
      let declared_type = resolve_function_member_type(
        context,
        index,
        param.type_,
        type_params,
        receiver_type,
      )
      let symbol_type = if param.optional && !has_default {
        @binding.option_type(declared_type)
      } else {
        declared_type
      }
      let symbol : Symbol = {
        id: parameter_id(fid, param.name),
        kind: SymbolKind::Parameter,
        name: param.name,
        type_: symbol_type,
        span: param.span,
      }
      params.push({
        symbol,
        label: if param.optional || param.labelled {
          Some(param.name)
        } else {
          None
        },
        optional: param.optional,
        has_default,
        default_ref,
        argument_type: declared_type,
      })
      register_default_argument(context, fid, symbol.id, default_ref, param)
    }
    context.symbols.push({
      id: fid,
      kind: SymbolKind::Function,
      name: function_decl_name(function),
      type_: return_type,
      span: function.span,
    })
    for param_def in params {
      context.symbols.push(param_def.symbol)
    }
    let signature : FunctionSignature = {
      function_id: fid,
      package_id: context.package_id,
      module_path: context.module_name,
      name: function_decl_name(function),
      receiver_type,
      type_params: type_param_constraints,
      parameters: params,
      return_type,
      effect,
      aliases: function.aliases,
      intrinsic: function.intrinsic,
      is_public: function.is_public,
      span: function.span,
    }
    context.functions.push(signature)
    @semantic.declare_function(index, signature)
  }
}

///|
fn resolve_function_receiver_type(
  context : BindingContext,
  index : DeclarationIndex,
  receiver : @ast.TypeSyntax,
  type_params : Array[String],
) -> TypeRef {
  if receiver.args.length() > 0 {
    return resolve_type_with_params(context, index, receiver, type_params)
  }
  match
    @semantic.find_visible_type_header(
      index,
      receiver.package_alias,
      receiver.name,
    ) {
    Some(header) =>
      if !receiver_type_header_should_resolve_as_builtin(index, header) {
        return declared_receiver_type(
          context, index, receiver, type_params, header,
        )
      }
    None => ()
  }
  match receiver.package_alias {
    Some(_) => ()
    None => {
      match @semantic.resolve_builtin_scalar_type(receiver.name) {
        Some(resolved) => return resolved
        None => ()
      }
      if receiver.args.length() == 0 && type_params.length() == 0 {
        match @semantic.builtin_unary_type_constructor(receiver.name) {
          Some(_) => return TypeRef::Builtin(receiver.name)
          None => ()
        }
        match @semantic.builtin_binary_type_constructor(receiver.name) {
          Some(_) => return TypeRef::Builtin(receiver.name)
          None => ()
        }
      }
      match @semantic.builtin_unary_type_constructor(receiver.name) {
        Some(make_type) =>
          return make_type(
            TypeRef::TypeParameter(
              type_params[0],
              "type-param:" + type_params[0],
            ),
          )
        None => ()
      }
      if type_params.length() >= 2 {
        match @semantic.builtin_binary_type_constructor(receiver.name) {
          Some(make_type) =>
            return make_type(
              TypeRef::TypeParameter(
                type_params[0],
                "type-param:" + type_params[0],
              ),
              TypeRef::TypeParameter(
                type_params[1],
                "type-param:" + type_params[1],
              ),
            )
          None => ()
        }
      }
    }
  }
  match
    @semantic.find_visible_type_header(
      index,
      receiver.package_alias,
      receiver.name,
    ) {
    Some(header) =>
      declared_receiver_type(context, index, receiver, type_params, header)
    None => resolve_type_with_params(context, index, receiver, type_params)
  }
}

///|
fn declared_receiver_type(
  context : BindingContext,
  index : DeclarationIndex,
  receiver : @ast.TypeSyntax,
  type_params : Array[String],
  header : @semantic.TypeHeader,
) -> TypeRef {
  if header.type_params.length() > 0 &&
    type_params.length() >= header.type_params.length() {
    let args = FixedArray::make(header.type_params.length(), @binding.unresolved_type_ref())
    for i in 0..<header.type_params.length() {
      args[i] = TypeRef::TypeParameter(type_params[i], "type-param:" + type_params[i])
    }
    TypeRef::Declared(header.symbol, args)
  } else {
    resolve_type_with_params(context, index, receiver, type_params)
  }
}

///|
fn receiver_type_header_should_resolve_as_builtin(
  index : DeclarationIndex,
  header : @semantic.TypeHeader,
) -> Bool {
  header.symbol.package_id == "pkg:moonbitlang/core/builtin" &&
  !core_builtin_receiver_struct_defined_in_current_package(index, header) &&
  (
    @semantic.resolve_builtin_scalar_type(header.symbol.name) is Some(_) ||
    (
      header.type_params.length() == 1 &&
      @semantic.builtin_unary_type_constructor(header.symbol.name) is Some(_)
    ) ||
    (
      header.type_params.length() == 2 &&
      @semantic.builtin_binary_type_constructor(header.symbol.name) is Some(_)
    )
  )
}

///|
fn core_builtin_receiver_struct_defined_in_current_package(
  index : DeclarationIndex,
  header : @semantic.TypeHeader,
) -> Bool {
  if index.package_id != header.symbol.package_id {
    return false
  }
  match @semantic.find_type_definition(index, header.symbol.id) {
    Some(TypeDefinition::Struct(_)) => true
    _ => false
  }
}

///|
fn function_decl_name(function : @ast.Function) -> String {
  match function.receiver {
    Some(receiver) => receiver.name + "::" + function.name
    None => function.name
  }
}

///|
fn resolve_function_member_type(
  context : BindingContext,
  index : DeclarationIndex,
  type_ : @ast.TypeSyntax,
  type_params : Array[String],
  receiver_type : TypeRef?,
) -> TypeRef {
  match receiver_type {
    Some(resolved) =>
      return resolve_type_with_self(
        context, index, type_, type_params, resolved,
      )
    None => ()
  }
  resolve_type_with_params(context, index, type_, type_params)
}

///|
fn register_default_argument(
  context : BindingContext,
  function_id : String,
  parameter_symbol_id : String,
  default_ref : String?,
  param : @ast.Param,
) -> Unit {
  match (default_ref, param.default_value) {
    (Some(id), Some(value)) => {
      let default_arg : @binding.DefaultArgument = {
        id,
        owner_function: function_id,
        parameter_symbol_id,
        value,
      }
      context.default_arguments.push(default_arg)
      context.default_arguments_by_id.set(id, default_arg)
    }
    _ => ()
  }
}

///|
fn collect_globals(
  context : BindingContext,
  index : DeclarationIndex,
  ast : Module,
) -> Unit {
  for global in ast.globals {
    let type_ = if global.has_type_annotation {
      resolve_type(context, index, global.type_)
    } else {
      infer_global_header_type(global.value)
    }
    let symbol : Symbol = {
      id: global_id(context.package_id, context.module_name, global.name),
      kind: SymbolKind::Global,
      name: global.name,
      type_,
      span: global.span,
    }
    context.symbols.push(symbol)
    @semantic.declare_global(index, symbol)
  }
}

///|
fn infer_global_header_type(value : @ast.Expr) -> TypeRef {
  match value {
    @ast.Expr::IntLiteral(_, _) => @binding.int_type()
    @ast.Expr::FloatLiteral(_, _) => @binding.double_type()
    @ast.Expr::StringLiteral(_, _) => @binding.string_type()
    @ast.Expr::BytesLiteral(_, _) => @binding.TypeRef::Builtin("Bytes")
    @ast.Expr::BoolLiteral(_, _) => @binding.bool_type()
    @ast.Expr::CharLiteral(_, _) => @binding.char_type()
    @ast.Expr::UnitLiteral(_) => @binding.unit_type()
    _ => @binding.error_type()
  }
}
