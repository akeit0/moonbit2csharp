///|
pub fn write_module_json(module_ : @ir.BoundModule) -> String {
  let out = StringBuilder::new()
  out.write_string("{\"schema\":")
  write_string(out, module_.schema)
  out.write_string(",\"module\":{\"name\":")
  write_string(out, module_.module_name)
  out.write_string("},\"symbols\":[")
  for i in 0..<module_.symbols.length() {
    comma(out, i)
    write_symbol(out, module_.symbols[i])
  }
  out.write_string("],\"types\":[")
  for i in 0..<module_.types.length() {
    comma(out, i)
    write_type_definition(out, module_.types[i])
  }
  out.write_string("],\"traits\":[")
  for i in 0..<module_.traits.length() {
    comma(out, i)
    write_trait(out, module_.traits[i])
  }
  out.write_string("],\"usedTraitImpls\":[")
  for i in 0..<module_.used_trait_impls.length() {
    comma(out, i)
    write_used_trait_impl(out, module_.used_trait_impls[i])
  }
  out.write_string("],\"functions\":[")
  for i in 0..<module_.functions.length() {
    comma(out, i)
    write_function(out, module_.functions[i])
  }
  out.write_string("],\"globals\":[")
  for i in 0..<module_.globals.length() {
    comma(out, i)
    write_global(out, module_.globals[i])
  }
  out.write_string("],\"diagnostics\":[")
  for i in 0..<module_.diagnostics.length() {
    comma(out, i)
    write_diagnostic(out, module_.diagnostics[i])
  }
  out.write_string("]}")
  out.to_string()
}

///|
fn write_used_trait_impl(
  out : StringBuilder,
  usage : @binding.UsedTraitImpl,
) -> Unit {
  out.write_string("{\"trait\":")
  write_trait_ref(out, usage.trait_ref)
  out.write_string(",\"selfType\":")
  write_type(out, usage.self_type)
  out.write_string("}")
}

///|
fn write_trait(out : StringBuilder, trait_def : @ir.BoundTrait) -> Unit {
  out.write_string("{\"kind\":\"Trait\",\"symbol\":")
  write_type_symbol(out, trait_def.symbol)
  out.write_string(",\"methods\":[")
  for i in 0..<trait_def.methods.length() {
    comma(out, i)
    write_trait_method(out, trait_def.methods[i])
  }
  out.write_string("]}")
}

///|
fn write_trait_method(
  out : StringBuilder,
  trait_method : @ir.BoundTraitMethod,
) -> Unit {
  out.write_string("{\"name\":")
  write_string(out, trait_method.name)
  out.write_string(",\"parameters\":[")
  for i in 0..<trait_method.parameters.length() {
    comma(out, i)
    write_type(out, trait_method.parameters[i])
  }
  out.write_string("],\"returnType\":")
  write_type(out, trait_method.return_type)
  out.write_string(",\"hasDefault\":")
  out.write_string(if trait_method.has_default { "true" } else { "false" })
  match trait_method.default_function_id {
    Some(function_id) => {
      out.write_string(",\"defaultFunctionId\":")
      write_string(out, function_id)
    }
    None => ()
  }
  out.write_string("}")
}

///|
fn write_type_definition(
  out : StringBuilder,
  type_def : @binding.TypeDefinition,
) -> Unit {
  match type_def {
    @binding.TypeDefinition::Opaque(opaque_def) => {
      out.write_string("{\"kind\":\"Opaque\",\"symbol\":")
      write_type_symbol(out, opaque_def.symbol)
      out.write_string(",\"typeParams\":[")
      for i in 0..<opaque_def.type_params.length() {
        comma(out, i)
        write_string(out, opaque_def.type_params[i])
      }
      out.write_string("]}")
    }
    @binding.TypeDefinition::Struct(struct_def) => {
      out.write_string("{\"kind\":\"Struct\",\"symbol\":")
      write_type_symbol(out, struct_def.symbol)
      out.write_string(",\"typeParams\":[")
      for i in 0..<struct_def.type_params.length() {
        comma(out, i)
        write_string(out, struct_def.type_params[i])
      }
      out.write_string("],\"fields\":[")
      for i in 0..<struct_def.fields.length() {
        comma(out, i)
        write_field_def(out, struct_def.fields[i])
      }
      out.write_string("],\"derives\":")
      write_derives(out, struct_def.derives)
      out.write_string("}")
    }
    @binding.TypeDefinition::Enum(enum_def) => {
      out.write_string("{\"kind\":\"Enum\",\"symbol\":")
      write_type_symbol(out, enum_def.symbol)
      out.write_string(",\"typeParams\":[")
      for i in 0..<enum_def.type_params.length() {
        comma(out, i)
        write_string(out, enum_def.type_params[i])
      }
      out.write_string("],\"variants\":[")
      for i in 0..<enum_def.variants.length() {
        comma(out, i)
        write_variant_def(out, enum_def.variants[i])
      }
      out.write_string("],\"derives\":")
      write_derives(out, enum_def.derives)
      out.write_string("}")
    }
  }
}

///|
fn write_derives(out : StringBuilder, derives : Array[String]) -> Unit {
  out.write_string("[")
  for i in 0..<derives.length() {
    comma(out, i)
    write_string(out, derives[i])
  }
  out.write_string("]")
}

///|
fn write_field_def(out : StringBuilder, field : @binding.FieldDef) -> Unit {
  out.write_string("{\"id\":")
  write_string(out, field.id)
  out.write_string(",\"name\":")
  write_string(out, field.name)
  out.write_string(",\"mutable\":")
  out.write_string(if field.mutable { "true" } else { "false" })
  out.write_string(",\"type\":")
  write_type(out, field.type_)
  out.write_string("}")
}

///|
fn write_variant_def(
  out : StringBuilder,
  variant : @binding.EnumVariantDef,
) -> Unit {
  out.write_string("{\"id\":")
  write_string(out, variant.id)
  out.write_string(",\"name\":")
  write_string(out, variant.name)
  out.write_string(",\"payloads\":[")
  for i in 0..<variant.payloads.length() {
    comma(out, i)
    out.write_string("{\"label\":")
    match variant.payloads[i].label {
      Some(label) => write_string(out, label)
      None => out.write_string("null")
    }
    out.write_string(",\"type\":")
    write_type(out, variant.payloads[i].type_)
    out.write_string("}")
  }
  out.write_string("]}")
}

///|
fn write_global(out : StringBuilder, global : @ir.BoundGlobal) -> Unit {
  out.write_string("{\"kind\":\"GlobalLet\",\"symbolId\":")
  write_string(out, global.symbol_id)
  out.write_string(",\"name\":")
  write_string(out, global.name)
  out.write_string(",\"isPublic\":")
  out.write_string(if global.is_public { "true" } else { "false" })
  out.write_string(",\"type\":")
  write_type(out, global.type_)
  out.write_string(",\"value\":")
  write_expr(out, global.value)
  out.write_string("}")
}

///|
fn write_function(out : StringBuilder, function : @ir.BoundFunction) -> Unit {
  out.write_string("{\"kind\":\"Function\",\"symbolId\":")
  write_string(out, function.symbol_id)
  out.write_string(",\"name\":")
  write_string(out, function.name)
  out.write_string(",\"isPublic\":")
  out.write_string(if function.is_public { "true" } else { "false" })
  out.write_string(",\"typeParams\":[")
  for i in 0..<function.type_params.length() {
    comma(out, i)
    write_type_param(out, function.type_params[i])
  }
  out.write_string("],\"params\":[")
  for i in 0..<function.params.length() {
    comma(out, i)
    write_param(out, function.params[i])
  }
  out.write_string("],\"returnType\":")
  write_type(out, function.return_type)
  out.write_string(",\"effect\":")
  write_effect(out, function.effect)
  out.write_string(",\"external\":")
  match function.external {
    Some(extern_) => {
      out.write_string("{\"target\":")
      write_string(out, extern_.target)
      out.write_string(",\"body\":")
      write_string(out, extern_.body)
      out.write_string("}")
    }
    None => out.write_string("null")
  }
  out.write_string(",\"body\":")
  write_expr(out, function.body)
  out.write_string("}")
}

///|
fn write_type_param(out : StringBuilder, param : @ir.BoundTypeParam) -> Unit {
  out.write_string("{\"name\":")
  write_string(out, param.name)
  out.write_string(",\"constraints\":[")
  for i in 0..<param.constraints.length() {
    comma(out, i)
    write_string(out, param.constraints[i])
  }
  out.write_string("]}")
}

///|
fn write_param(out : StringBuilder, param : @ir.BoundParam) -> Unit {
  out.write_string("{\"symbolId\":")
  write_string(out, param.symbol_id)
  out.write_string(",\"name\":")
  write_string(out, param.name)
  out.write_string(",\"label\":")
  match param.label {
    Some(label) => write_string(out, label)
    None => out.write_string("null")
  }
  out.write_string(",\"optional\":")
  out.write_string(if param.optional { "true" } else { "false" })
  out.write_string(",\"hasDefault\":")
  out.write_string(if param.has_default { "true" } else { "false" })
  out.write_string(",\"type\":")
  write_type(out, param.type_)
  out.write_string("}")
}

///|
fn write_expr(out : StringBuilder, expr : @ir.BoundExpr) -> Unit {
  match expr {
    @ir.BoundExpr::Name(symbol_id, name, type_, _) => {
      out.write_string("{\"kind\":\"Name\",\"symbolId\":")
      write_string(out, symbol_id)
      out.write_string(",\"name\":")
      write_string(out, name)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::FunctionRef(function_id, name, type_, _) => {
      out.write_string("{\"kind\":\"FunctionRef\",\"functionId\":")
      write_string(out, function_id)
      out.write_string(",\"name\":")
      write_string(out, name)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::IntLiteral(value, type_, _) => {
      out.write_string("{\"kind\":\"IntLiteral\",\"value\":")
      write_string(out, value)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::FloatLiteral(value, type_, _) => {
      out.write_string("{\"kind\":\"FloatLiteral\",\"value\":")
      write_string(out, value)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::CharLiteral(value, type_, _) => {
      out.write_string("{\"kind\":\"CharLiteral\",\"value\":")
      write_string(out, value)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::StringLiteral(value, type_, _) => {
      out.write_string("{\"kind\":\"StringLiteral\",\"value\":")
      write_string(out, value)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::BytesLiteral(value, type_, _) => {
      out.write_string("{\"kind\":\"BytesLiteral\",\"value\":")
      write_string(out, value)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::BoolLiteral(value, type_, _) => {
      out.write_string("{\"kind\":\"BoolLiteral\",\"value\":")
      out.write_string(if value { "true" } else { "false" })
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::UnitLiteral(type_, _) => {
      out.write_string("{\"kind\":\"UnitLiteral\",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::TupleLiteral(items, type_, _) => {
      out.write_string("{\"kind\":\"TupleLiteral\",\"items\":[")
      for i in 0..<items.length() {
        comma(out, i)
        write_expr(out, items[i])
      }
      out.write_string("],\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::TupleGet(target, index, type_, _) => {
      out.write_string("{\"kind\":\"TupleGet\",\"target\":")
      write_expr(out, target)
      out.write_string(",\"index\":")
      out.write_string(index.to_string())
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::LocalLet(local_binding, body, type_, _) => {
      out.write_string("{\"kind\":\"LocalLet\",\"local\":{\"symbolId\":")
      write_string(out, local_binding.symbol_id)
      out.write_string(",\"name\":")
      write_string(out, local_binding.name)
      out.write_string(",\"type\":")
      write_type(out, local_binding.type_)
      out.write_string(",\"value\":")
      write_expr(out, local_binding.value)
      out.write_string("},\"body\":")
      write_expr(out, body)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::LocalFunction(local_function, body, type_, _) => {
      out.write_string(
        "{\"kind\":\"LocalFunction\",\"function\":{\"symbolId\":",
      )
      write_string(out, local_function.symbol.id)
      out.write_string(",\"name\":")
      write_string(out, local_function.symbol.name)
      out.write_string(",\"type\":")
      write_type(out, local_function.symbol.type_)
      out.write_string(",\"params\":[")
      for i in 0..<local_function.params.length() {
        comma(out, i)
        out.write_string("{\"symbolId\":")
        write_string(out, local_function.params[i].id)
        out.write_string(",\"name\":")
        write_string(out, local_function.params[i].name)
        out.write_string(",\"type\":")
        write_type(out, local_function.params[i].type_)
        out.write_string("}")
      }
      out.write_string("],\"returnType\":")
      write_type(out, local_function.return_type)
      out.write_string(",\"body\":")
      write_expr(out, local_function.body)
      out.write_string("},\"body\":")
      write_expr(out, body)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::Sequence(first, body, type_, _) => {
      out.write_string("{\"kind\":\"Sequence\",\"first\":")
      write_expr(out, first)
      out.write_string(",\"body\":")
      write_expr(out, body)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::Call(
      function_id,
      type_args,
      trait_evidence,
      args,
      intrinsic,
      type_,
      _
    ) => {
      out.write_string("{\"kind\":\"Call\",\"functionId\":")
      write_string(out, function_id)
      out.write_string(",\"typeArgs\":[")
      for i in 0..<type_args.length() {
        comma(out, i)
        write_type(out, type_args[i])
      }
      out.write_string("],\"traitEvidence\":[")
      for i in 0..<trait_evidence.length() {
        comma(out, i)
        write_impl_evidence(out, trait_evidence[i])
      }
      out.write_string("],\"args\":[")
      for i in 0..<args.length() {
        comma(out, i)
        write_expr(out, args[i])
      }
      out.write_string("]")
      match intrinsic {
        Some(name) => {
          out.write_string(",\"selectedIntrinsic\":")
          write_string(out, name)
        }
        None => ()
      }
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::Lambda(params, body, type_, _) => {
      out.write_string("{\"kind\":\"Lambda\",\"params\":[")
      for i in 0..<params.length() {
        comma(out, i)
        out.write_string("{\"symbolId\":")
        write_string(out, params[i].id)
        out.write_string(",\"name\":")
        write_string(out, params[i].name)
        out.write_string(",\"type\":")
        write_type(out, params[i].type_)
        out.write_string("}")
      }
      out.write_string("],\"body\":")
      write_expr(out, body)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::FunctionValueCall(callee, args, type_, _) => {
      out.write_string("{\"kind\":\"FunctionValueCall\",\"callee\":")
      write_expr(out, callee)
      out.write_string(",\"args\":[")
      for i in 0..<args.length() {
        comma(out, i)
        write_expr(out, args[i])
      }
      out.write_string("],\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::IndexGet(target, index, type_, _) => {
      out.write_string("{\"kind\":\"IndexGet\",\"target\":")
      write_expr(out, target)
      out.write_string(",\"index\":")
      write_expr(out, index)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::EnumCase(type_id, variant_id, name, args, type_, _) => {
      out.write_string("{\"kind\":\"EnumCase\",\"typeId\":")
      write_string(out, type_id)
      out.write_string(",\"variantId\":")
      write_string(out, variant_id)
      out.write_string(",\"name\":")
      write_string(out, name)
      out.write_string(",\"args\":[")
      for i in 0..<args.length() {
        comma(out, i)
        write_expr(out, args[i])
      }
      out.write_string("],\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::FieldAccess(target, field_ref, type_, _) => {
      out.write_string("{\"kind\":\"FieldAccess\",\"target\":")
      write_expr(out, target)
      out.write_string(",\"field\":")
      write_field_ref(out, field_ref)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::FieldAssign(target, field_ref, value, type_, _) => {
      out.write_string("{\"kind\":\"FieldAssign\",\"target\":")
      write_expr(out, target)
      out.write_string(",\"field\":")
      write_field_ref(out, field_ref)
      out.write_string(",\"value\":")
      write_expr(out, value)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::Assign(symbol, value, type_, _) => {
      out.write_string("{\"kind\":\"Assign\",\"symbolId\":")
      write_string(out, symbol.id)
      out.write_string(",\"name\":")
      write_string(out, symbol.name)
      out.write_string(",\"value\":")
      write_expr(out, value)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::IndexAssign(target, index, value, type_, _) => {
      out.write_string("{\"kind\":\"IndexAssign\",\"target\":")
      write_expr(out, target)
      out.write_string(",\"index\":")
      write_expr(out, index)
      out.write_string(",\"value\":")
      write_expr(out, value)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::If(condition, then_, else_, type_, _) => {
      out.write_string("{\"kind\":\"If\",\"condition\":")
      write_expr(out, condition)
      out.write_string(",\"then\":")
      write_expr(out, then_)
      out.write_string(",\"else\":")
      write_expr(out, else_)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::TraitMethodCall(
      receiver,
      trait_ref,
      method_id,
      name,
      args,
      dispatch,
      type_,
      _
    ) => {
      out.write_string("{\"kind\":\"TraitMethodCall\",\"receiver\":")
      write_expr(out, receiver)
      out.write_string(",\"trait\":")
      write_trait_ref(out, trait_ref)
      out.write_string(",\"methodId\":")
      write_string(out, method_id)
      out.write_string(",\"name\":")
      write_string(out, name)
      out.write_string(",\"args\":[")
      for i in 0..<args.length() {
        comma(out, i)
        write_expr(out, args[i])
      }
      out.write_string("],\"dispatch\":")
      write_trait_dispatch(out, dispatch)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::OptionSome(value, type_, _) => {
      out.write_string("{\"kind\":\"OptionSome\",\"value\":")
      write_expr(out, value)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::OptionNone(type_, _) => {
      out.write_string("{\"kind\":\"OptionNone\",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::Panic(type_, _) => {
      out.write_string("{\"kind\":\"Panic\",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::ArrayLiteral(items, type_, _) => {
      out.write_string("{\"kind\":\"ArrayLiteral\",\"items\":[")
      for i in 0..<items.length() {
        comma(out, i)
        write_array_element(out, items[i])
      }
      out.write_string("],\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::MapLiteral(entries, type_, _) => {
      out.write_string("{\"kind\":\"MapLiteral\",\"entries\":[")
      for i in 0..<entries.length() {
        comma(out, i)
        write_bound_map_entry(out, entries[i])
      }
      out.write_string("],\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::StructLiteral(type_id, fields, type_, _) => {
      out.write_string("{\"kind\":\"StructLiteral\",\"typeId\":")
      write_string(out, type_id)
      out.write_string(",\"fields\":[")
      for i in 0..<fields.length() {
        comma(out, i)
        write_bound_field_value(out, fields[i])
      }
      out.write_string("],\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::StructUpdate(type_id, base, fields, type_, _) => {
      out.write_string("{\"kind\":\"StructUpdate\",\"typeId\":")
      write_string(out, type_id)
      out.write_string(",\"base\":")
      write_expr(out, base)
      out.write_string(",\"fields\":[")
      for i in 0..<fields.length() {
        comma(out, i)
        write_bound_field_value(out, fields[i])
      }
      out.write_string("],\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::Conversion(kind, value, type_, _) => {
      out.write_string("{\"kind\":\"Conversion\",\"conversion\":")
      write_string(out, kind)
      out.write_string(",\"value\":")
      write_expr(out, value)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::Unary(op, value, selected, selected_intrinsic, type_, _) => {
      out.write_string("{\"kind\":\"Unary\",\"op\":")
      write_string(out, op)
      out.write_string(",\"value\":")
      write_expr(out, value)
      out.write_string(",\"selectedFunctionId\":")
      write_string(out, selected)
      out.write_string(",\"selectedIntrinsic\":")
      match selected_intrinsic {
        Some(intrinsic) => write_string(out, intrinsic)
        None => out.write_string("null")
      }
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::Binary(
      op,
      left,
      right,
      selected,
      type_args,
      trait_evidence,
      selected_intrinsic,
      type_,
      _
    ) => {
      out.write_string("{\"kind\":\"Binary\",\"op\":")
      write_string(out, op)
      out.write_string(",\"left\":")
      write_expr(out, left)
      out.write_string(",\"right\":")
      write_expr(out, right)
      out.write_string(",\"selectedFunctionId\":")
      write_string(out, selected)
      out.write_string(",\"typeArgs\":[")
      for i in 0..<type_args.length() {
        comma(out, i)
        write_type(out, type_args[i])
      }
      out.write_string("],\"traitEvidence\":[")
      for i in 0..<trait_evidence.length() {
        comma(out, i)
        write_impl_evidence(out, trait_evidence[i])
      }
      out.write_string("]")
      out.write_string(",\"selectedIntrinsic\":")
      match selected_intrinsic {
        Some(intrinsic) => write_string(out, intrinsic)
        None => out.write_string("null")
      }
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::IsPattern(target, pattern, type_, _) => {
      out.write_string("{\"kind\":\"IsPattern\",\"target\":")
      write_expr(out, target)
      out.write_string(",\"pattern\":")
      write_match_pattern(out, pattern)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::Match(target, arms, type_, _) => {
      out.write_string("{\"kind\":\"Match\",\"target\":")
      write_expr(out, target)
      out.write_string(",\"arms\":[")
      for i in 0..<arms.length() {
        comma(out, i)
        write_match_arm(out, arms[i])
      }
      out.write_string("],\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::Raise(value, show_object, type_, _) => {
      out.write_string("{\"kind\":\"Raise\",\"value\":")
      write_expr(out, value)
      out.write_string(",\"showObject\":")
      write_optional_expr(out, show_object)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::TryCatch(body, arms, type_, _) => {
      out.write_string("{\"kind\":\"TryCatch\",\"body\":")
      write_expr(out, body)
      out.write_string(",\"arms\":[")
      for i in 0..<arms.length() {
        comma(out, i)
        write_match_arm(out, arms[i])
      }
      out.write_string("],\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::Guard(condition, else_, type_, _) => {
      out.write_string("{\"kind\":\"Guard\",\"condition\":")
      write_expr(out, condition)
      out.write_string(",\"else\":")
      write_expr(out, else_)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::While(condition, body, type_, _) => {
      out.write_string("{\"kind\":\"While\",\"condition\":")
      write_expr(out, condition)
      out.write_string(",\"body\":")
      write_expr(out, body)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::ForRange(range_loop, type_, _) => {
      out.write_string("{\"kind\":\"ForRange\",\"symbolId\":")
      write_string(out, range_loop.symbol_id)
      out.write_string(",\"name\":")
      write_string(out, range_loop.name)
      out.write_string(",\"start\":")
      write_expr(out, range_loop.start)
      out.write_string(",\"end\":")
      write_expr(out, range_loop.end_)
      out.write_string(",\"inclusive\":")
      out.write_string(if range_loop.inclusive { "true" } else { "false" })
      out.write_string(",\"reverse\":")
      out.write_string(if range_loop.reverse { "true" } else { "false" })
      out.write_string(",\"excludeStart\":")
      out.write_string(if range_loop.exclude_start { "true" } else { "false" })
      out.write_string(",\"body\":")
      write_expr(out, range_loop.body)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::ForIn(for_in, type_, _) => {
      out.write_string("{\"kind\":\"ForIn\",\"valueSymbols\":[")
      for i in 0..<for_in.value_symbols.length() {
        comma(out, i)
        write_local_symbol(out, for_in.value_symbols[i])
      }
      out.write_string("],\"iterator\":")
      write_expr(out, for_in.iterator)
      out.write_string(",\"bindings\":[")
      for i in 0..<for_in.bindings.length() {
        comma(out, i)
        write_for_loop_binding(out, for_in.bindings[i])
      }
      out.write_string("],\"body\":")
      write_expr(out, for_in.body)
      out.write_string(",\"noBreak\":")
      write_optional_expr(out, for_in.no_break)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::ForLoop(for_loop, type_, _) => {
      out.write_string("{\"kind\":\"ForLoop\",\"bindings\":[")
      for i in 0..<for_loop.bindings.length() {
        comma(out, i)
        write_for_loop_binding(out, for_loop.bindings[i])
      }
      out.write_string("],\"condition\":")
      match for_loop.condition {
        Some(condition) => write_expr(out, condition)
        None => out.write_string("null")
      }
      out.write_string(",\"updates\":[")
      for i in 0..<for_loop.updates.length() {
        comma(out, i)
        write_expr(out, for_loop.updates[i])
      }
      out.write_string("],\"body\":")
      write_expr(out, for_loop.body)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::Break(value, type_, _) => {
      out.write_string("{\"kind\":\"Break\",\"value\":")
      write_optional_expr(out, value)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::Continue(args, type_, _) => {
      out.write_string("{\"kind\":\"Continue\",\"args\":[")
      for i in 0..<args.length() {
        comma(out, i)
        write_expr(out, args[i])
      }
      out.write_string("],\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::Return(value, type_, _) => {
      out.write_string("{\"kind\":\"Return\",\"value\":")
      write_optional_expr(out, value)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
    @ir.BoundExpr::Error(reason, type_, _) => {
      out.write_string("{\"kind\":\"Error\",\"reason\":")
      write_string(out, reason)
      out.write_string(",\"type\":")
      write_type(out, type_)
      out.write_string("}")
    }
  }
}

///|
fn write_impl_evidence(
  out : StringBuilder,
  evidence : @ir.BoundTraitEvidence,
) -> Unit {
  out.write_string("{\"evidenceId\":")
  write_string(out, evidence.evidence_id)
  out.write_string(",\"trait\":")
  write_trait_ref(out, evidence.trait_ref)
  out.write_string(",\"selfType\":")
  write_type(out, evidence.self_type)
  out.write_string(",\"typeArgs\":[")
  for i in 0..<evidence.type_args.length() {
    comma(out, i)
    write_type(out, evidence.type_args[i])
  }
  out.write_string("]}")
}

///|
fn write_optional_expr(out : StringBuilder, expr : @ir.BoundExpr?) -> Unit {
  match expr {
    Some(value) => write_expr(out, value)
    None => out.write_string("null")
  }
}

///|
fn write_match_arm(out : StringBuilder, arm : @ir.BoundMatchArm) -> Unit {
  out.write_string("{\"pattern\":")
  write_match_pattern(out, arm.pattern)
  match arm.condition {
    Some(condition) => {
      out.write_string(",\"condition\":")
      write_expr(out, condition)
    }
    None => ()
  }
  out.write_string(",\"body\":")
  write_expr(out, arm.body)
  out.write_string("}")
}

///|
fn write_match_pattern(out : StringBuilder, pattern : @ir.BoundPattern) -> Unit {
  match pattern {
    @ir.BoundPattern::Wildcard => out.write_string("{\"kind\":\"Wildcard\"}")
    @ir.BoundPattern::Binding(symbol) => {
      out.write_string("{\"kind\":\"Binding\",\"symbol\":")
      write_symbol(out, symbol)
      out.write_string("}")
    }
    @ir.BoundPattern::IntLiteral(value) => {
      out.write_string("{\"kind\":\"IntLiteral\",\"value\":")
      write_string(out, value)
      out.write_string("}")
    }
    @ir.BoundPattern::CharLiteral(value) => {
      out.write_string("{\"kind\":\"CharLiteral\",\"value\":")
      write_string(out, value)
      out.write_string("}")
    }
    @ir.BoundPattern::StringLiteral(value) => {
      out.write_string("{\"kind\":\"StringLiteral\",\"value\":")
      write_string(out, value)
      out.write_string("}")
    }
    @ir.BoundPattern::BoolLiteral(value) => {
      out.write_string("{\"kind\":\"BoolLiteral\",\"value\":")
      out.write_string(if value { "true" } else { "false" })
      out.write_string("}")
    }
    @ir.BoundPattern::Range(start, end_, inclusive) => {
      out.write_string("{\"kind\":\"Range\",\"start\":")
      write_nullable_string(out, start)
      out.write_string(",\"end\":")
      write_nullable_string(out, end_)
      out.write_string(",\"inclusive\":")
      out.write_string(if inclusive { "true" } else { "false" })
      out.write_string("}")
    }
    @ir.BoundPattern::Tuple(items) => {
      out.write_string("{\"kind\":\"Tuple\",\"items\":[")
      for i, item in items {
        if i > 0 {
          out.write_string(",")
        }
        write_match_pattern(out, item)
      }
      out.write_string("]}")
    }
    @ir.BoundPattern::Array(prefix, rest, suffix) => {
      out.write_string("{\"kind\":\"Array\",\"items\":[")
      for i, item in prefix {
        if i > 0 {
          out.write_string(",")
        }
        write_match_pattern(out, item)
      }
      out.write_string("],\"rest\":")
      write_array_pattern_rest(out, rest)
      out.write_string(",\"suffix\":[")
      for i, item in suffix {
        if i > 0 {
          out.write_string(",")
        }
        write_match_pattern(out, item)
      }
      out.write_string("]")
      out.write_string("}")
    }
    @ir.BoundPattern::Struct(type_id, fields) => {
      out.write_string("{\"kind\":\"Struct\",\"typeId\":")
      write_string(out, type_id)
      out.write_string(",\"fields\":[")
      for i, field in fields {
        if i > 0 {
          out.write_string(",")
        }
        out.write_string("{\"field\":")
        write_field_ref(out, field.field)
        out.write_string(",\"pattern\":")
        write_match_pattern(out, field.pattern)
        out.write_string("}")
      }
      out.write_string("]}")
    }
    @ir.BoundPattern::Or(alternatives) => {
      out.write_string("{\"kind\":\"Or\",\"alternatives\":[")
      for i, alternative in alternatives {
        if i > 0 {
          out.write_string(",")
        }
        write_match_pattern(out, alternative)
      }
      out.write_string("]}")
    }
    @ir.BoundPattern::OptionNone =>
      out.write_string("{\"kind\":\"OptionNone\"}")
    @ir.BoundPattern::OptionSome(payload) => {
      out.write_string("{\"kind\":\"OptionSome\",\"payload\":")
      write_match_pattern(out, payload)
      out.write_string("}")
    }
    @ir.BoundPattern::EnumCase(type_id, variant_id, name, payloads) => {
      out.write_string("{\"kind\":\"EnumCase\",\"typeId\":")
      write_string(out, type_id)
      out.write_string(",\"variantId\":")
      write_string(out, variant_id)
      out.write_string(",\"name\":")
      write_string(out, name)
      out.write_string(",\"payloads\":[")
      for i in 0..<payloads.length() {
        comma(out, i)
        write_match_pattern(out, payloads[i])
      }
      out.write_string("]")
      out.write_string("}")
    }
  }
}

///|
fn write_array_pattern_rest(
  out : StringBuilder,
  rest : @ir.BoundArrayPatternRest?,
) -> Unit {
  match rest {
    Some(rest_pattern) => {
      out.write_string("{\"symbol\":")
      match rest_pattern.symbol {
        Some(symbol) => write_symbol(out, symbol)
        None => out.write_string("null")
      }
      out.write_string("}")
    }
    None => out.write_string("null")
  }
}

///|
fn write_for_loop_binding(
  out : StringBuilder,
  binding : @ir.BoundForLoopBinding,
) -> Unit {
  out.write_string("{\"symbolId\":")
  write_string(out, binding.symbol.id)
  out.write_string(",\"name\":")
  write_string(out, binding.symbol.name)
  out.write_string(",\"type\":")
  write_type(out, binding.symbol.type_)
  out.write_string(",\"value\":")
  write_expr(out, binding.value)
  out.write_string("}")
}

///|
fn write_local_symbol(out : StringBuilder, symbol : @binding.Symbol) -> Unit {
  out.write_string("{\"symbolId\":")
  write_string(out, symbol.id)
  out.write_string(",\"name\":")
  write_string(out, symbol.name)
  out.write_string(",\"type\":")
  write_type(out, symbol.type_)
  out.write_string("}")
}

///|
fn write_bound_map_entry(
  out : StringBuilder,
  entry : @ir.BoundMapEntry,
) -> Unit {
  out.write_string("{\"key\":")
  write_expr(out, entry.key)
  out.write_string(",\"value\":")
  write_expr(out, entry.value)
  out.write_string("}")
}

///|
fn write_bound_field_value(
  out : StringBuilder,
  field : @ir.BoundFieldValue,
) -> Unit {
  out.write_string("{\"name\":")
  write_string(out, field.name)
  out.write_string(",\"value\":")
  write_expr(out, field.value)
  out.write_string("}")
}

///|
fn write_field_ref(out : StringBuilder, field_ref : @binding.FieldRef) -> Unit {
  out.write_string("{\"ownerTypeId\":")
  write_string(out, field_ref.owner_type_id)
  out.write_string(",\"fieldId\":")
  write_string(out, field_ref.field_id)
  out.write_string(",\"name\":")
  write_string(out, field_ref.name)
  out.write_string(",\"mutable\":")
  out.write_string(if field_ref.mutable { "true" } else { "false" })
  out.write_string(",\"type\":")
  write_type(out, field_ref.type_)
  out.write_string("}")
}

///|
fn write_trait_dispatch(
  out : StringBuilder,
  dispatch : @ir.BoundTraitDispatch,
) -> Unit {
  match dispatch {
    @ir.BoundTraitDispatch::TraitObject =>
      out.write_string("{\"kind\":\"TraitObject\"}")
    @ir.BoundTraitDispatch::TypeParamBound(impl_type_param) => {
      out.write_string("{\"kind\":\"TypeParamBound\",\"implTypeParam\":")
      write_string(out, impl_type_param)
      out.write_string("}")
    }
    @ir.BoundTraitDispatch::ConcreteImpl(function_id, intrinsic) => {
      out.write_string("{\"kind\":\"ConcreteImpl\",\"functionId\":")
      write_string(out, function_id)
      out.write_string(",\"selectedIntrinsic\":")
      match intrinsic {
        Some(value) => write_string(out, value)
        None => out.write_string("null")
      }
      out.write_string("}")
    }
  }
}

///|
fn write_symbol(out : StringBuilder, symbol : @binding.Symbol) -> Unit {
  out.write_string("{\"id\":")
  write_string(out, symbol.id)
  out.write_string(",\"kind\":")
  write_string(out, symbol_kind_text(symbol.kind))
  out.write_string(",\"name\":")
  write_string(out, symbol.name)
  out.write_string(",\"type\":")
  write_type(out, symbol.type_)
  out.write_string("}")
}

///|
fn symbol_kind_text(kind : @binding.SymbolKind) -> String {
  match kind {
    Module => "Module"
    Type => "Type"
    Trait => "Trait"
    TypeParameter => "TypeParameter"
    Function => "Function"
    Parameter => "Parameter"
    Local => "Local"
    Global => "Global"
    Field => "Field"
    EnumVariant => "EnumVariant"
  }
}

///|
fn write_array_element(
  out : StringBuilder,
  item : @ir.BoundArrayElement,
) -> Unit {
  match item {
    @ir.BoundArrayElement::Value(value) => {
      out.write_string("{\"kind\":\"Value\",\"value\":")
      write_expr(out, value)
      out.write_string("}")
    }
    @ir.BoundArrayElement::Spread(value) => {
      out.write_string("{\"kind\":\"Spread\",\"value\":")
      write_expr(out, value)
      out.write_string("}")
    }
  }
}

///|
fn write_type(out : StringBuilder, type_ : @binding.TypeRef) -> Unit {
  match type_ {
    @binding.TypeRef::Builtin(name) => {
      out.write_string("{\"kind\":\"Builtin\",\"name\":")
      write_string(out, name)
      out.write_string("}")
    }
    @binding.TypeRef::Declared(symbol, args) => {
      out.write_string("{\"kind\":\"Declared\",\"symbol\":")
      write_type_symbol(out, symbol)
      out.write_string(",\"args\":[")
      for i in 0..<args.length() {
        comma(out, i)
        write_type(out, args[i])
      }
      out.write_string("]}")
    }
    @binding.TypeRef::TypeParameter(name, symbol_id) => {
      out.write_string("{\"kind\":\"TypeParameter\",\"name\":")
      write_string(out, name)
      out.write_string(",\"symbolId\":")
      write_string(out, symbol_id)
      out.write_string("}")
    }
    @binding.TypeRef::Tuple(items) => {
      out.write_string("{\"kind\":\"Tuple\",\"items\":[")
      for i in 0..<items.length() {
        comma(out, i)
        write_type(out, items[i])
      }
      out.write_string("]}")
    }
    @binding.TypeRef::Function(params, return_type, effect) => {
      out.write_string("{\"kind\":\"Function\",\"params\":[")
      for i in 0..<params.length() {
        comma(out, i)
        write_param_type(out, params[i])
      }
      out.write_string("],\"return\":")
      write_type(out, return_type)
      out.write_string(",\"effect\":")
      write_effect(out, effect)
      out.write_string("}")
    }
    @binding.TypeRef::Apply(type_constructor, args) => {
      out.write_string("{\"kind\":\"Apply\",\"constructor\":")
      write_constructor(out, type_constructor)
      out.write_string(",\"args\":[")
      for i in 0..<args.length() {
        comma(out, i)
        write_type(out, args[i])
      }
      out.write_string("]}")
    }
    @binding.TypeRef::TraitObject(trait_ref) => {
      out.write_string("{\"kind\":\"TraitObject\",\"trait\":")
      write_trait_ref(out, trait_ref)
      out.write_string("}")
    }
    @binding.TypeRef::Unknown(reason) => {
      out.write_string("{\"kind\":\"Unknown\",\"reason\":")
      write_string(out, reason)
      out.write_string("}")
    }
    @binding.TypeRef::Error(reason) => {
      out.write_string("{\"kind\":\"Error\",\"reason\":")
      write_string(out, reason)
      out.write_string("}")
    }
  }
}

///|
fn write_constructor(
  out : StringBuilder,
  type_constructor : @binding.TypeConstructorRef,
) -> Unit {
  match type_constructor {
    @binding.TypeConstructorRef::Builtin(name) => {
      out.write_string("{\"kind\":\"Builtin\",\"name\":")
      write_string(out, name)
      out.write_string("}")
    }
    @binding.TypeConstructorRef::Declared(symbol) => {
      out.write_string("{\"kind\":\"Declared\",\"symbol\":")
      write_type_symbol(out, symbol)
      out.write_string("}")
    }
    @binding.TypeConstructorRef::TypeParameter(name, symbol_id) => {
      out.write_string("{\"kind\":\"TypeParameter\",\"name\":")
      write_string(out, name)
      out.write_string(",\"symbolId\":")
      write_string(out, symbol_id)
      out.write_string("}")
    }
  }
}

///|
fn write_type_symbol(
  out : StringBuilder,
  symbol : @binding.TypeSymbolRef,
) -> Unit {
  out.write_string("{\"id\":")
  write_string(out, symbol.id)
  out.write_string(",\"packageId\":")
  write_string(out, symbol.package_id)
  out.write_string(",\"modulePath\":")
  write_string(out, symbol.module_path)
  out.write_string(",\"name\":")
  write_string(out, symbol.name)
  out.write_string("}")
}

///|
fn write_param_type(out : StringBuilder, param : @binding.ParamTypeRef) -> Unit {
  out.write_string("{\"label\":")
  match param.label {
    Some(label) => write_string(out, label)
    None => out.write_string("null")
  }
  out.write_string(",\"type\":")
  write_type(out, param.type_)
  out.write_string(",\"optional\":")
  out.write_string(if param.optional { "true" } else { "false" })
  out.write_string(",\"hasDefault\":")
  out.write_string(if param.has_default { "true" } else { "false" })
  out.write_string("}")
}

///|
fn write_effect(out : StringBuilder, effect : @binding.EffectRef) -> Unit {
  match effect {
    @binding.EffectRef::NoRaise => out.write_string("{\"kind\":\"NoRaise\"}")
    @binding.EffectRef::Raises(error_type) => {
      out.write_string("{\"kind\":\"Raises\",\"error\":")
      write_type(out, error_type)
      out.write_string("}")
    }
    @binding.EffectRef::RaisePolymorphic(symbol) => {
      out.write_string("{\"kind\":\"RaisePolymorphic\",\"symbolId\":")
      match symbol {
        Some(id) => write_string(out, id)
        None => out.write_string("null")
      }
      out.write_string("}")
    }
    @binding.EffectRef::UnknownEffect(reason) => {
      out.write_string("{\"kind\":\"Unknown\",\"reason\":")
      write_string(out, reason)
      out.write_string("}")
    }
  }
}

///|
fn write_trait_ref(out : StringBuilder, trait_ref : @binding.TraitRef) -> Unit {
  out.write_string("{\"symbol\":")
  write_type_symbol(out, trait_ref.trait_)
  out.write_string(",\"args\":[")
  for i in 0..<trait_ref.args.length() {
    comma(out, i)
    write_type(out, trait_ref.args[i])
  }
  out.write_string("]}")
}

///|
fn write_diagnostic(
  out : StringBuilder,
  diagnostic : @common.Diagnostic,
) -> Unit {
  out.write_string("{\"severity\":")
  write_string(out, diagnostic.severity)
  out.write_string(",\"code\":")
  write_string(out, diagnostic.code)
  out.write_string(",\"message\":")
  write_string(out, diagnostic.message)
  out.write_string(",\"span\":")
  write_span(out, diagnostic.span)
  out.write_string("}")
}

///|
fn write_span(out : StringBuilder, span : @common.SourceSpan) -> Unit {
  out.write_string("{\"file\":")
  write_string(out, span.file)
  out.write_string(",\"start\":")
  out.write_string(span.start.to_string())
  out.write_string(",\"end\":")
  out.write_string(span.end.to_string())
  out.write_string(",\"line\":")
  out.write_string(span.line.to_string())
  out.write_string(",\"column\":")
  out.write_string(span.column.to_string())
  out.write_string("}")
}

///|
fn comma(out : StringBuilder, index : Int) -> Unit {
  if index > 0 {
    out.write_string(",")
  }
}

///|
fn write_string(out : StringBuilder, value : String) -> Unit {
  out.write_string("\"")
  out.write_string(escape_json(value))
  out.write_string("\"")
}

///|
fn write_nullable_string(out : StringBuilder, value : String?) -> Unit {
  match value {
    Some(text) => write_string(out, text)
    None => out.write_string("null")
  }
}

///|
fn escape_json(value : String) -> String {
  let escaped = StringBuilder::new()
  let mut i = 0
  while i < value.length() {
    let ch = value[i]
    match ch {
      '"' => escaped.write_string("\\\"")
      '\\' => escaped.write_string("\\\\")
      '\n' => escaped.write_string("\\n")
      '\r' => escaped.write_string("\\r")
      '\t' => escaped.write_string("\\t")
      _ =>
        if ch < ' ' {
          write_json_control_escape(escaped, ch.to_int())
        } else {
          escaped.write_stringview(value[i:i + 1])
        }
    }
    i = i + 1
  }
  escaped.to_string()
}

///|
fn write_json_control_escape(out : StringBuilder, code : Int) -> Unit {
  if code == 8 {
    out.write_string("\\b")
  } else if code == 12 {
    out.write_string("\\f")
  } else {
    out.write_string("\\u00")
    out.write_char(hex_digit((code >> 4) & 0xF))
    out.write_char(hex_digit(code & 0xF))
  }
}

///|
fn hex_digit(value : Int) -> Char {
  if value < 10 {
    (48 + value).unsafe_to_char()
  } else {
    (87 + value).unsafe_to_char()
  }
}
