///|
fn declare_struct_headers(
  context : BindingContext,
  index : DeclarationIndex,
  ast : Module,
) -> Unit {
  for decl in ast.structs {
    let symbol = @binding.local_type_symbol(context, decl.name)
    @semantic.declare_type_header(index, symbol, decl.type_params, decl.span)
  }
}

///|
fn declare_opaque_type_headers(
  context : BindingContext,
  index : DeclarationIndex,
  ast : Module,
) -> Unit {
  for decl in ast.opaque_types {
    let symbol = @binding.local_type_symbol(context, decl.name)
    @semantic.declare_type_header(index, symbol, decl.type_params, decl.span)
  }
}

///|
fn declare_enum_headers(
  context : BindingContext,
  index : DeclarationIndex,
  ast : Module,
) -> Unit {
  for decl in ast.enums {
    let symbol = @binding.local_type_symbol(context, decl.name)
    @semantic.declare_type_header(index, symbol, decl.type_params, decl.span)
  }
}

///|
fn collect_opaque_types(
  context : BindingContext,
  index : DeclarationIndex,
  ast : Module,
) -> Unit {
  for decl in ast.opaque_types {
    let symbol = @binding.local_type_symbol(context, decl.name)
    let def : TypeDefinition = TypeDefinition::Opaque({
      symbol,
      type_params: decl.type_params,
    })
    context.types.push(def)
    @semantic.define_type(index, def)
    context.symbols.push({
      id: symbol.id,
      kind: SymbolKind::Type,
      name: decl.name,
      type_: TypeRef::Declared(symbol, []),
      span: decl.span,
    })
  }
}

///|
fn collect_structs(
  context : BindingContext,
  index : DeclarationIndex,
  ast : Module,
) -> Unit {
  for decl in ast.structs {
    let symbol = @binding.local_type_symbol(context, decl.name)
    let fields : Array[FieldDef] = []
    for field in decl.fields {
      fields.push({
        id: symbol.id + ":field:" + field.name,
        name: field.name,
        mutable: field.mutable,
        type_: resolve_type_with_params(
          context,
          index,
          field.type_,
          decl.type_params,
        ),
      })
    }
    let def : TypeDefinition = TypeDefinition::Struct({
      symbol,
      type_params: decl.type_params,
      fields,
      derives: decl.derives,
      valtype: decl.valtype,
    })
    context.types.push(def)
    @semantic.define_type(index, def)
    declare_struct_derives(
      index,
      symbol,
      decl.type_params,
      decl.derives,
      decl.span,
    )
    context.symbols.push({
      id: symbol.id,
      kind: SymbolKind::Type,
      name: decl.name,
      type_: TypeRef::Declared(symbol, []),
      span: decl.span,
    })
  }
}

///|
fn declare_struct_derives(
  index : @semantic.DeclarationIndex,
  symbol : @binding.TypeSymbolRef,
  type_params : Array[String],
  derives : Array[String],
  span : SourceSpan,
) -> Unit {
  let self_type = declared_type_with_params(symbol, type_params)
  if has_derive(derives, "Eq") {
    @semantic.declare_derived_eq_operator_impls(index, self_type, span)
  }
  if has_derive(derives, "Compare") {
    @semantic.declare_derived_eq_operator_impls(index, self_type, span)
    @semantic.declare_derived_compare_operator_impls(index, self_type, span)
  }
  if has_derive(derives, "Hash") {
    @semantic.declare_derived_hash_impl(index, self_type, type_params, span)
  }
  if has_derive(derives, "Default") {
    @semantic.declare_derived_default_impl(index, self_type, type_params, span)
  }
  if has_derive(derives, "Debug") {
    @semantic.declare_derived_debug_impl(index, self_type, type_params, span)
  }
}

///|
fn collect_enums(
  context : BindingContext,
  index : DeclarationIndex,
  ast : Module,
) -> Unit {
  for decl in ast.enums {
    let symbol = @binding.local_type_symbol(context, decl.name)
    let variants : Array[EnumVariantDef] = []
    for variant in decl.variants {
      let payloads : Array[@binding.EnumPayloadDef] = []
      for payload in variant.payloads {
        payloads.push({
          label: payload.label,
          type_: resolve_type_with_params(
            context,
            index,
            payload.type_,
            decl.type_params,
          ),
        })
      }
      variants.push({
        id: symbol.id + ":variant:" + variant.name,
        name: variant.name,
        payloads,
      })
    }
    let def : TypeDefinition = TypeDefinition::Enum({
      symbol,
      type_params: decl.type_params,
      variants,
      derives: decl.derives,
    })
    context.types.push(def)
    @semantic.define_type(index, def)
    declare_enum_derives(
      index,
      symbol,
      decl.type_params,
      variants,
      decl.derives,
      decl.span,
    )
    context.symbols.push({
      id: symbol.id,
      kind: SymbolKind::Type,
      name: decl.name,
      type_: TypeRef::Declared(symbol, []),
      span: decl.span,
    })
  }
}

///|
fn declare_enum_derives(
  index : @semantic.DeclarationIndex,
  symbol : @binding.TypeSymbolRef,
  type_params : Array[String],
  variants : Array[EnumVariantDef],
  derives : Array[String],
  span : SourceSpan,
) -> Unit {
  let self_type = declared_type_with_params(symbol, type_params)
  if has_derive(derives, "Eq") {
    @semantic.declare_derived_eq_operator_impls(index, self_type, span)
  }
  if has_derive(derives, "Compare") {
    @semantic.declare_derived_eq_operator_impls(index, self_type, span)
    @semantic.declare_derived_compare_operator_impls(index, self_type, span)
  }
  if has_derive(derives, "Hash") {
    @semantic.declare_derived_hash_impl(index, self_type, type_params, span)
  }
  if has_derive(derives, "Default") {
    match single_constant_variant(variants) {
      Some(_) =>
        @semantic.declare_derived_default_impl(
          index, self_type, type_params, span,
        )
      None =>
        index.error(
          "VNX4078",
          default_derive_error_message(symbol.name, variants),
          span,
        )
    }
  }
  if has_derive(derives, "Debug") {
    @semantic.declare_derived_debug_impl(index, self_type, type_params, span)
  }
}

///|
fn single_constant_variant(variants : Array[EnumVariantDef]) -> EnumVariantDef? {
  let mut found : EnumVariantDef? = None
  for variant in variants {
    if variant.payloads.length() == 0 {
      match found {
        Some(_) => return None
        None => found = Some(variant)
      }
    }
  }
  found
}

///|
fn default_derive_error_message(
  type_name : String,
  variants : Array[EnumVariantDef],
) -> String {
  let constants : Array[String] = []
  for variant in variants {
    if variant.payloads.length() == 0 {
      constants.push(variant.name)
    }
  }
  if constants.length() == 0 {
    "Cannot derive trait Default for type " +
    type_name +
    ": cannot find a constant constructor as default"
  } else {
    "Cannot derive trait Default for type " +
    type_name +
    ": " +
    constants.join(" and ") +
    " are both candidates as default constructor"
  }
}

///|
fn declared_type_with_params(
  symbol : @binding.TypeSymbolRef,
  type_params : Array[String],
) -> TypeRef {
  let args : Array[TypeRef] = []
  for param in type_params {
    args.push(
      TypeRef::TypeParameter(param, "type-param:" + symbol.id + ":" + param),
    )
  }
  TypeRef::Declared(symbol, args)
}

///|
fn has_derive(derives : Array[String], name : String) -> Bool {
  for item in derives {
    if item == name {
      return true
    }
  }
  false
}
