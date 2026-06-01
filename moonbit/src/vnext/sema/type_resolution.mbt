///|
fn resolve_type(
  context : BindingContext,
  index : DeclarationIndex,
  type_ : TypeSyntax,
) -> TypeRef {
  resolve_type_with_params(
    context,
    index,
    type_,
    current_type_param_names(context),
  )
}

///|
fn current_type_param_names(context : BindingContext) -> FixedArray[String] {
  let current_params = context.current_type_params
  let names : FixedArray[String] = FixedArray::make(current_params.length(), "")
  for i in 0..<current_params.length() {
    names[i] = current_params[i].name
  }
  names
}

///|
fn resolve_type_with_params(
  context : BindingContext,
  index : DeclarationIndex,
  type_ : TypeSyntax,
  type_params : FixedArray[String],
) -> TypeRef {
  resolve_type_with_params_and_self(context, index, type_, type_params, None)
}

///|
fn resolve_type_with_self(
  context : BindingContext,
  index : DeclarationIndex,
  type_ : TypeSyntax,
  type_params : FixedArray[String],
  self_type : TypeRef,
) -> TypeRef {
  resolve_type_with_params_and_self(
    context,
    index,
    type_,
    type_params,
    Some(self_type),
  )
}

///|
fn resolve_type_with_params_and_self(
  context : BindingContext,
  index : DeclarationIndex,
  type_ : TypeSyntax,
  type_params : FixedArray[String],
  self_type : TypeRef?,
) -> TypeRef {
  if type_.is_trait_object {
    return resolve_trait_object_type(context, index, type_, type_params)
  }
  if type_.package_alias is None && type_.name == "Self" {
    match self_type {
      Some(resolved) =>
        return resolve_self_type_syntax(
          context, index, resolved, type_, type_params,
        )
      None => ()
    }
  }
  for param in type_params {
    if type_.package_alias is None && param == type_.name {
      return TypeRef::TypeParameter(param, "type-param:" + param)
    }
  }
  match
    resolve_builtin_scalar_type_with_self(
      context, index, type_, type_params, self_type,
    ) {
    Some(resolved) => resolved
    None =>
      match
        @semantic.find_visible_type_header(
          index,
          type_.package_alias,
          type_.name,
        ) {
        Some(header) =>
          if type_header_should_resolve_as_builtin(index, header) {
            match
              resolve_builtin_constructed_type_with_self(
                context, index, type_, type_params, self_type,
              ) {
              Some(resolved) => resolved
              None =>
                resolve_declared_type_header(
                  context, index, type_, type_params, header,
                )
            }
          } else {
            resolve_declared_type_header(
              context, index, type_, type_params, header,
            )
          }
        None =>
          match
            resolve_builtin_constructed_type_with_self(
              context, index, type_, type_params, self_type,
            ) {
            Some(resolved) => resolved
            None => {
              context.error(
                "VNX1000",
                "unknown type: " + type_.name,
                type_.span,
              )
              error_type()
            }
          }
      }
  }
}

///|
fn resolve_self_type_syntax(
  context : BindingContext,
  index : DeclarationIndex,
  self_type : TypeRef,
  type_ : TypeSyntax,
  type_params : FixedArray[String],
) -> TypeRef {
  if type_.args.length() == 0 {
    return self_type
  }
  match self_type {
    TypeRef::Declared(symbol, _) => {
      let args = FixedArray::make(
        type_.args.length(),
        @binding.unresolved_type_ref(),
      )
      for i in 0..<type_.args.length() {
        args[i] = resolve_type_with_params_and_self(
          context,
          index,
          type_.args[i],
          type_params,
          Some(self_type),
        )
      }
      TypeRef::Declared(symbol, args)
    }
    TypeRef::Builtin(name) => {
      if type_.args.length() == 1 {
        match @semantic.builtin_unary_type_constructor(name) {
          Some(make_type) =>
            return make_type(
              resolve_type_with_params_and_self(
                context,
                index,
                type_.args[0],
                type_params,
                Some(self_type),
              ),
            )
          None => ()
        }
      } else if type_.args.length() == 2 {
        match @semantic.builtin_binary_type_constructor(name) {
          Some(make_type) =>
            return make_type(
              resolve_type_with_params_and_self(
                context,
                index,
                type_.args[0],
                type_params,
                Some(self_type),
              ),
              resolve_type_with_params_and_self(
                context,
                index,
                type_.args[1],
                type_params,
                Some(self_type),
              ),
            )
          None => ()
        }
      }
      self_type
    }
    TypeRef::Apply(type_constructor, _) => {
      let args = FixedArray::make(
        type_.args.length(),
        @binding.unresolved_type_ref(),
      )
      for i in 0..<type_.args.length() {
        args[i] = resolve_type_with_params_and_self(
          context,
          index,
          type_.args[i],
          type_params,
          Some(self_type),
        )
      }
      TypeRef::Apply(type_constructor, args)
    }
    _ => self_type
  }
}

///|
fn type_header_should_resolve_as_builtin(
  index : DeclarationIndex,
  header : @semantic.TypeHeader,
) -> Bool {
  header.symbol.package_id == "pkg:moonbitlang/core/builtin" &&
  !core_builtin_struct_defined_in_current_package(index, header) &&
  core_builtin_type_header_has_canonical_type(header)
}

///|
fn core_builtin_struct_defined_in_current_package(
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
fn core_builtin_type_header_has_canonical_type(
  header : @semantic.TypeHeader,
) -> Bool {
  @semantic.resolve_builtin_scalar_type(header.symbol.name) is Some(_) ||
  (
    header.type_params.length() == 1 &&
    @semantic.builtin_unary_type_constructor(header.symbol.name) is Some(_)
  ) ||
  (
    header.type_params.length() == 2 &&
    @semantic.builtin_binary_type_constructor(header.symbol.name) is Some(_)
  )
}

///|
fn resolve_declared_type_header(
  context : BindingContext,
  index : DeclarationIndex,
  type_ : TypeSyntax,
  type_params : FixedArray[String],
  header : @semantic.TypeHeader,
) -> TypeRef {
  let args = FixedArray::make(
    type_.args.length(),
    @binding.unresolved_type_ref(),
  )
  for i in 0..<type_.args.length() {
    args[i] = resolve_type_with_params(
      context,
      index,
      type_.args[i],
      type_params,
    )
  }
  TypeRef::Declared(header.symbol, args)
}

///|
fn resolve_trait_object_type(
  context : BindingContext,
  index : DeclarationIndex,
  type_ : TypeSyntax,
  type_params : FixedArray[String],
) -> TypeRef {
  match @semantic.find_visible_trait(index, type_.package_alias, type_.name) {
    Some(trait_def) => {
      let args = FixedArray::make(
        type_.args.length(),
        @binding.unresolved_type_ref(),
      )
      for i in 0..<type_.args.length() {
        args[i] = resolve_type_with_params(
          context,
          index,
          type_.args[i],
          type_params,
        )
      }
      TypeRef::TraitObject({ trait_: trait_def.symbol, args })
    }
    None => {
      context.error("VNX1001", "unknown trait: " + type_.name, type_.span)
      error_type()
    }
  }
}

///|
fn resolve_builtin_scalar_type_with_self(
  context : BindingContext,
  index : DeclarationIndex,
  type_ : TypeSyntax,
  type_params : FixedArray[String],
  self_type : TypeRef?,
) -> TypeRef? {
  match type_.package_alias {
    Some(_) => return None
    None => ()
  }
  if type_.name == "Tuple" {
    let items = FixedArray::make(
      type_.args.length(),
      @binding.unresolved_type_ref(),
    )
    for i in 0..<type_.args.length() {
      items[i] = resolve_type_with_params_and_self(
        context,
        index,
        type_.args[i],
        type_params,
        self_type,
      )
    }
    return Some(TypeRef::Tuple(items))
  }
  if type_.name == "Function" && type_.args.length() >= 1 {
    let parameters : Array[@binding.ParamTypeRef] = []
    for i in 0..<(type_.args.length() - 1) {
      parameters.push({
        label: None,
        type_: resolve_type_with_params_and_self(
          context,
          index,
          type_.args[i],
          type_params,
          self_type,
        ),
        optional: false,
        has_default: false,
      })
    }
    return Some(
      TypeRef::Function(
        parameters,
        resolve_type_with_params_and_self(
          context,
          index,
          type_.args[type_.args.length() - 1],
          type_params,
          self_type,
        ),
        @binding.no_raise(),
      ),
    )
  }
  if type_.args.length() == 0 {
    @semantic.resolve_builtin_scalar_type(type_.name)
  } else {
    None
  }
}

///|
fn resolve_builtin_constructed_type_with_self(
  context : BindingContext,
  index : DeclarationIndex,
  type_ : TypeSyntax,
  type_params : FixedArray[String],
  self_type : TypeRef?,
) -> TypeRef? {
  match type_.package_alias {
    Some(_) => return None
    None => ()
  }
  if type_.args.length() == 1 {
    match @semantic.builtin_unary_type_constructor(type_.name) {
      Some(make_type) =>
        Some(
          make_type(
            resolve_type_with_params_and_self(
              context,
              index,
              type_.args[0],
              type_params,
              self_type,
            ),
          ),
        )
      None => None
    }
  } else if type_.args.length() == 2 {
    match @semantic.builtin_binary_type_constructor(type_.name) {
      Some(make_type) =>
        Some(
          make_type(
            resolve_type_with_params_and_self(
              context,
              index,
              type_.args[0],
              type_params,
              self_type,
            ),
            resolve_type_with_params_and_self(
              context,
              index,
              type_.args[1],
              type_params,
              self_type,
            ),
          ),
        )
      None => None
    }
  } else {
    None
  }
}

///|
