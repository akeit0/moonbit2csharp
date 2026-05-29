///|
fn bind_struct_literal(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  fields : Array[StructFieldValue],
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let expected = @semantic.resolve_inferred_type(typing, expected)
  match expected {
    TypeRef::Declared(symbol, args) =>
      match @semantic.find_type_definition(index, symbol.id) {
        Some(TypeDefinition::Struct(def)) => {
          let bound_fields : Array[BoundFieldValue] = []
          for field_def in def.fields {
            let field_type = @semantic.substitute_type(
              def.type_params,
              args,
              field_def.type_,
            )
            match find_field_value(fields, field_def.name) {
              Some(field_value) =>
                bound_fields.push({
                  name: field_def.name,
                  value: bind_expr(
                    typing,
                    context,
                    index,
                    scope,
                    field_value.value,
                    field_type,
                    ast,
                  ),
                })
              None =>
                context.error(
                  "VNX1400",
                  "missing field: " + field_def.name,
                  span,
                )
            }
          }
          apply_conversion(
            typing,
            context,
            BoundExpr::StructLiteral(symbol.id, bound_fields, expected, span),
            expected,
            span,
          )
        }
        Some(TypeDefinition::Opaque(_)) | Some(TypeDefinition::Enum(_)) => {
          context.error(
            "VNX1402", "struct literal requires struct expected type", span,
          )
          BoundExpr::Error("struct literal for enum", error_type(), span)
        }
        None => BoundExpr::Error("unknown struct", error_type(), span)
      }
    _ => {
      context.error(
        "VNX1401", "struct literal requires declared expected type", span,
      )
      BoundExpr::Error(
        "struct literal without expected type",
        error_type(),
        span,
      )
    }
  }
}

///|
fn bind_struct_update_literal(
  typing : TypingContext,
  context : BindingContext,
  index : DeclarationIndex,
  scope : Array[Symbol],
  base : Expr,
  fields : Array[StructFieldValue],
  expected : TypeRef,
  span : SourceSpan,
  ast : Module,
) -> BoundExpr {
  let bound_base = bind_expr(typing, context, index, scope, base, expected, ast)
  let base_type = @semantic.resolve_inferred_type(
    typing,
    @ir.expr_type(bound_base),
  )
  match base_type {
    TypeRef::Declared(symbol, args) =>
      match @semantic.find_type_definition(index, symbol.id) {
        Some(TypeDefinition::Struct(def)) => {
          let bound_fields : Array[BoundFieldValue] = []
          for field_value in fields {
            match find_struct_field_def(def.fields, field_value.name) {
              Some(field_def) => {
                let field_type = @semantic.substitute_type(
                  def.type_params,
                  args,
                  field_def.type_,
                )
                bound_fields.push({
                  name: field_def.name,
                  value: bind_expr(
                    typing,
                    context,
                    index,
                    scope,
                    field_value.value,
                    field_type,
                    ast,
                  ),
                })
              }
              None =>
                context.error(
                  "VNX1403",
                  "unknown struct update field: " + field_value.name,
                  field_value.span,
                )
            }
          }
          apply_conversion(
            typing,
            context,
            BoundExpr::StructUpdate(
              symbol.id,
              bound_base,
              bound_fields,
              base_type,
              span,
            ),
            expected,
            span,
          )
        }
        Some(TypeDefinition::Opaque(_)) | Some(TypeDefinition::Enum(_)) => {
          context.error(
            "VNX1404", "struct update requires struct base type", span,
          )
          BoundExpr::Error("struct update for enum", error_type(), span)
        }
        None =>
          BoundExpr::Error("unknown struct update base", error_type(), span)
      }
    _ => {
      context.error(
        "VNX1405", "struct update requires declared struct base type", span,
      )
      BoundExpr::Error("struct update without struct base", error_type(), span)
    }
  }
}

///|
fn find_field_value(
  fields : Array[StructFieldValue],
  name : String,
) -> StructFieldValue? {
  for field in fields {
    if field.name == name {
      return Some(field)
    }
  }
  None
}

///|
fn find_struct_field_def(fields : Array[FieldDef], name : String) -> FieldDef? {
  for field in fields {
    if field.name == name {
      return Some(field)
    }
  }
  None
}
