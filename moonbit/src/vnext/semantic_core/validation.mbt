///|

///|
priv struct ValidationContext {
  module_ : BoundModule
  type_ids : Set[String]
}

///|
fn validation_context(module_ : BoundModule) -> ValidationContext {
  let type_ids : Set[String] = Set([])
  for type_def in module_.types {
    let (symbol, _) = @binding.type_definition_header(type_def)
    type_ids.add(symbol.id)
  }
  for trait_def in module_.traits {
    type_ids.add(trait_def.symbol.id)
  }
  { module_, type_ids }
}

///|
pub fn validate_executable_module(module_ : BoundModule) -> Unit {
  let context = validation_context(module_)
  for symbol in module_.symbols {
    validate_type(context, symbol.type_, symbol.span)
  }
  for type_def in module_.types {
    match type_def {
      @binding.TypeDefinition::Opaque(_) => ()
      @binding.TypeDefinition::Struct(struct_def) =>
        for field in struct_def.fields {
          validate_type(context, field.type_, source_span("", 0, 0, 1, 1))
        }
      @binding.TypeDefinition::Enum(enum_def) =>
        for variant in enum_def.variants {
          for payload in variant.payloads {
            validate_type(context, payload.type_, source_span("", 0, 0, 1, 1))
          }
        }
    }
  }
  for function in module_.functions {
    validate_type(context, function.return_type, function.span)
    match function.external {
      Some(extern_) =>
        validate_external_function(module_, extern_, function.span)
      None => validate_expr(context, function.body)
    }
  }
  for global in module_.globals {
    validate_type(context, global.type_, global.span)
    validate_expr(context, global.value)
  }
}

///|
fn validate_external_function(
  module_ : BoundModule,
  extern_ : @ir.BoundExternalFunction,
  span : SourceSpan,
) -> Unit {
  if extern_.target != "csharp" && extern_.target != "interface" {
    module_.diagnostics.push({
      severity: "error",
      code: "VNX3050",
      message: "unsupported external function target: " + extern_.target,
      span,
    })
  }
}

///|
fn validate_expr(context : ValidationContext, expr : BoundExpr) -> Unit {
  let module_ = context.module_
  match expr {
    BoundExpr::Name(_, _, type_, span) => validate_type(context, type_, span)
    BoundExpr::FunctionRef(_, _, type_, span) =>
      validate_type(context, type_, span)
    BoundExpr::IntLiteral(_, type_, span) => validate_type(context, type_, span)
    BoundExpr::FloatLiteral(_, type_, span) =>
      validate_type(context, type_, span)
    BoundExpr::CharLiteral(_, type_, span) =>
      validate_type(context, type_, span)
    BoundExpr::StringLiteral(_, type_, span) =>
      validate_type(context, type_, span)
    BoundExpr::BytesLiteral(_, type_, span) =>
      validate_type(context, type_, span)
    BoundExpr::BoolLiteral(_, type_, span) =>
      validate_type(context, type_, span)
    BoundExpr::UnitLiteral(type_, span) => validate_type(context, type_, span)
    BoundExpr::TupleLiteral(items, type_, span) => {
      validate_type(context, type_, span)
      for item in items {
        validate_expr(context, item)
      }
      match type_ {
        TypeRef::Tuple(item_types) =>
          if item_types.length() != items.length() {
            module_.diagnostics.push({
              severity: "error",
              code: "VNX3038",
              message: "tuple literal item count does not match tuple type",
              span,
            })
          }
        _ =>
          module_.diagnostics.push({
            severity: "error",
            code: "VNX3039",
            message: "tuple literal expression type must be Tuple",
            span,
          })
      }
    }
    BoundExpr::TupleGet(target, index, type_, span) => {
      validate_expr(context, target)
      validate_type(context, type_, span)
      match @ir.expr_type(target) {
        TypeRef::Tuple(item_types) =>
          if index < 0 || index >= item_types.length() {
            module_.diagnostics.push({
              severity: "error",
              code: "VNX3040",
              message: "tuple get index out of range",
              span,
            })
          }
        _ =>
          module_.diagnostics.push({
            severity: "error",
            code: "VNX3041",
            message: "tuple get target must be Tuple",
            span,
          })
      }
    }
    BoundExpr::LocalLet(local_binding, body, type_, span) => {
      validate_type(context, local_binding.type_, span)
      validate_expr(context, local_binding.value)
      validate_expr(context, body)
      validate_type(context, type_, span)
    }
    BoundExpr::LocalFunction(local_function, body, type_, span) => {
      validate_type(context, local_function.symbol.type_, span)
      for param in local_function.params {
        validate_type(context, param.type_, span)
      }
      validate_type(context, local_function.return_type, span)
      validate_expr(context, local_function.body)
      validate_expr(context, body)
      validate_type(context, type_, span)
    }
    BoundExpr::Sequence(first, body, type_, span) => {
      validate_expr(context, first)
      validate_expr(context, body)
      validate_type(context, type_, span)
    }
    BoundExpr::Call(_, _, _, args, _, type_, span) => {
      validate_type(context, type_, span)
      for arg in args {
        validate_expr(context, arg)
      }
    }
    BoundExpr::Lambda(params, body, type_, span) => {
      validate_type(context, type_, span)
      for param in params {
        validate_type(context, param.type_, param.span)
      }
      validate_expr(context, body)
    }
    BoundExpr::FunctionValueCall(callee, args, type_, span) => {
      validate_expr(context, callee)
      validate_type(context, type_, span)
      for arg in args {
        validate_expr(context, arg)
      }
    }
    BoundExpr::IndexGet(target, index, type_, span) => {
      validate_expr(context, target)
      validate_expr(context, index)
      validate_type(context, type_, span)
      if !@binding.type_equal(@ir.expr_type(index), @binding.int_type()) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3042",
          message: "index expression index must be Int",
          span,
        })
      }
    }
    BoundExpr::EnumCase(type_id, variant_id, _, args, type_, span) => {
      validate_type(context, type_, span)
      if !module_has_type(context, type_id) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3003",
          message: "enum case references missing type definition: " + type_id,
          span,
        })
      }
      if !module_type_has_variant(module_, type_id, variant_id) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3004",
          message: "enum case references missing variant: " + variant_id,
          span,
        })
      }
      for arg in args {
        validate_expr(context, arg)
      }
    }
    BoundExpr::FieldAccess(target, field_ref, type_, span) => {
      validate_expr(context, target)
      validate_type(context, type_, span)
      validate_type(context, field_ref.type_, span)
      match module_field_info(module_, @ir.expr_type(target), field_ref.name) {
        Some(field) => {
          if field.field_id != field_ref.field_id ||
            field.owner_type_id != field_ref.owner_type_id {
            module_.diagnostics.push({
              severity: "error",
              code: "VNX3005",
              message: "field access reference does not match field definition: " +
              field_ref.name,
              span,
            })
          }
          if !@binding.type_equal(field.type_, type_) ||
            !@binding.type_equal(field.type_, field_ref.type_) {
            module_.diagnostics.push({
              severity: "error",
              code: "VNX3005",
              message: "field access type does not match field definition: " +
              field_ref.name,
              span,
            })
          }
        }
        None =>
          module_.diagnostics.push({
            severity: "error",
            code: "VNX3006",
            message: "field access references missing field: " + field_ref.name,
            span,
          })
      }
    }
    BoundExpr::FieldAssign(target, field_ref, value, type_, span) => {
      validate_expr(context, target)
      validate_expr(context, value)
      validate_type(context, type_, span)
      validate_type(context, field_ref.type_, span)
      match module_field_info(module_, @ir.expr_type(target), field_ref.name) {
        Some(field) => {
          if field.field_id != field_ref.field_id ||
            field.owner_type_id != field_ref.owner_type_id {
            module_.diagnostics.push({
              severity: "error",
              code: "VNX3009",
              message: "field assignment reference does not match field definition: " +
              field_ref.name,
              span,
            })
          }
          if !field.mutable || !field_ref.mutable {
            module_.diagnostics.push({
              severity: "error",
              code: "VNX3007",
              message: "field assignment targets immutable field: " +
              field_ref.name,
              span,
            })
          }
          if !@binding.type_equal(field.type_, @ir.expr_type(value)) ||
            !@binding.type_equal(field.type_, field_ref.type_) {
            module_.diagnostics.push({
              severity: "error",
              code: "VNX3008",
              message: "field assignment value type does not match field definition: " +
              field_ref.name,
              span,
            })
          }
        }
        None =>
          module_.diagnostics.push({
            severity: "error",
            code: "VNX3009",
            message: "field assignment references missing field: " +
            field_ref.name,
            span,
          })
      }
    }
    BoundExpr::Assign(symbol, value, type_, span) => {
      validate_type(context, symbol.type_, span)
      validate_expr(context, value)
      validate_type(context, type_, span)
      if !@binding.type_equal(type_, @binding.unit_type()) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3015",
          message: "assignment expression type must be Unit",
          span,
        })
      }
    }
    BoundExpr::IndexAssign(target, index, value, type_, span) => {
      validate_expr(context, target)
      validate_expr(context, index)
      validate_expr(context, value)
      validate_type(context, type_, span)
      if !@binding.type_equal(@ir.expr_type(index), @binding.int_type()) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3043",
          message: "index assignment index must be Int",
          span,
        })
      }
      if !@binding.type_equal(type_, @binding.unit_type()) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3044",
          message: "index assignment type must be Unit",
          span,
        })
      }
    }
    BoundExpr::If(condition, then_, else_, type_, span) => {
      validate_expr(context, condition)
      validate_expr(context, then_)
      validate_expr(context, else_)
      validate_type(context, type_, span)
      if !@binding.type_equal(@ir.expr_type(condition), @binding.bool_type()) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3034",
          message: "if condition must be Bool",
          span,
        })
      }
      if !branch_type_matches(then_, type_) ||
        !branch_type_matches(else_, type_) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3035",
          message: "if branch type does not match if expression type",
          span,
        })
      }
    }
    BoundExpr::TraitMethodCall(receiver, trait_ref, _, _, args, _, type_, span) => {
      validate_expr(context, receiver)
      for arg in args {
        validate_expr(context, arg)
      }
      validate_trait_ref(context, trait_ref, span)
      validate_type(context, type_, span)
    }
    BoundExpr::OptionSome(value, type_, span) => {
      validate_expr(context, value)
      validate_type(context, type_, span)
    }
    BoundExpr::OptionNone(type_, span) => validate_type(context, type_, span)
    BoundExpr::Panic(type_, span) => validate_type(context, type_, span)
    BoundExpr::ArrayLiteral(items, type_, span) => {
      validate_type(context, type_, span)
      for item in items {
        validate_array_element(context, item)
      }
    }
    BoundExpr::MapLiteral(entries, type_, span) => {
      validate_type(context, type_, span)
      match type_ {
        TypeRef::Apply(
          TypeConstructorRef::Builtin("Map"),
          [key_type, value_type]
        ) =>
          for entry in entries {
            validate_expr(context, entry.key)
            validate_expr(context, entry.value)
            if !@binding.type_equal(@ir.expr_type(entry.key), key_type) {
              module_.diagnostics.push({
                severity: "error",
                code: "VNX3012",
                message: "map literal key type does not match map type",
                span,
              })
            }
            if !@binding.type_equal(@ir.expr_type(entry.value), value_type) {
              module_.diagnostics.push({
                severity: "error",
                code: "VNX3013",
                message: "map literal value type does not match map type",
                span,
              })
            }
          }
        _ =>
          module_.diagnostics.push({
            severity: "error",
            code: "VNX3014",
            message: "map literal type must be Map",
            span,
          })
      }
    }
    BoundExpr::StructLiteral(type_id, fields, type_, span) => {
      validate_type(context, type_, span)
      if !module_has_type(context, type_id) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3000",
          message: "struct literal references missing type definition: " +
          type_id,
          span,
        })
      }
      for field in fields {
        if !module_type_has_field(module_, type_id, field.name) {
          module_.diagnostics.push({
            severity: "error",
            code: "VNX3001",
            message: "struct literal references missing field: " + field.name,
            span,
          })
        }
        validate_expr(context, field.value)
      }
    }
    BoundExpr::StructUpdate(type_id, base, fields, type_, span) => {
      validate_type(context, type_, span)
      validate_expr(context, base)
      if !module_has_type(context, type_id) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3048",
          message: "struct update type is not declared: " + type_id,
          span,
        })
      }
      for field in fields {
        match module_field_info(module_, @ir.expr_type(base), field.name) {
          Some(field_info) =>
            if !@binding.type_equal(
                field_info.type_,
                @ir.expr_type(field.value),
              ) {
              module_.diagnostics.push({
                severity: "error",
                code: "VNX3049",
                message: "struct update field value type mismatch",
                span,
              })
            }
          None =>
            module_.diagnostics.push({
              severity: "error",
              code: "VNX3050",
              message: "struct update field does not exist: " + field.name,
              span,
            })
        }
        validate_expr(context, field.value)
      }
    }
    BoundExpr::Conversion(_, value, type_, span) => {
      validate_expr(context, value)
      validate_type(context, type_, span)
    }
    BoundExpr::Unary(_, value, _, _, type_, span) => {
      validate_expr(context, value)
      validate_type(context, type_, span)
    }
    BoundExpr::Binary(
      _,
      left,
      right,
      _,
      type_args,
      trait_evidence,
      _,
      type_,
      span
    ) => {
      validate_type(context, type_, span)
      for type_arg in type_args {
        validate_type(context, type_arg, span)
      }
      for evidence in trait_evidence {
        validate_trait_ref(context, evidence.trait_ref, span)
        validate_type(context, evidence.self_type, span)
        for type_arg in evidence.type_args {
          validate_type(context, type_arg, span)
        }
      }
      validate_expr(context, left)
      validate_expr(context, right)
    }
    BoundExpr::IsPattern(target, pattern, type_, span) => {
      validate_expr(context, target)
      validate_match_pattern(context, pattern, @ir.expr_type(target), span)
      validate_type(context, type_, span)
      if !@binding.type_equal(type_, @binding.bool_type()) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3033",
          message: "is pattern expression type must be Bool",
          span,
        })
      }
    }
    BoundExpr::Match(target, arms, type_, span) => {
      validate_expr(context, target)
      validate_type(context, type_, span)
      for arm in arms {
        validate_match_pattern(
          context,
          arm.pattern,
          @ir.expr_type(target),
          span,
        )
        match arm.condition {
          Some(condition) => {
            validate_expr(context, condition)
            if !@binding.type_equal(
                @ir.expr_type(condition),
                @binding.bool_type(),
              ) {
              module_.diagnostics.push({
                severity: "error",
                code: "VNX3031",
                message: "match arm condition must be Bool",
                span,
              })
            }
          }
          None => ()
        }
        validate_expr(context, arm.body)
        if !branch_type_matches(arm.body, type_) {
          module_.diagnostics.push({
            severity: "error",
            code: "VNX3020",
            message: "match arm body type does not match match expression type",
            span,
          })
        }
      }
    }
    BoundExpr::Raise(value, _, type_, span) => {
      validate_expr(context, value)
      validate_type(context, type_, span)
    }
    BoundExpr::TryCatch(body, arms, type_, span) => {
      validate_expr(context, body)
      validate_type(context, type_, span)
      for arm in arms {
        validate_expr(context, arm.body)
      }
    }
    BoundExpr::Guard(condition, else_, type_, span) => {
      validate_expr(context, condition)
      validate_expr(context, else_)
      validate_type(context, type_, span)
      if !@binding.type_equal(@ir.expr_type(condition), @binding.bool_type()) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3036",
          message: "guard condition must be Bool",
          span,
        })
      }
      if !@binding.type_equal(type_, @binding.unit_type()) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3037",
          message: "guard expression type must be Unit",
          span,
        })
      }
    }
    BoundExpr::While(condition, body, type_, span) => {
      validate_expr(context, condition)
      validate_expr(context, body)
      validate_type(context, type_, span)
      if !@binding.type_equal(@ir.expr_type(condition), @binding.bool_type()) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3047",
          message: "while condition must be Bool",
          span,
        })
      }
      if !@binding.type_equal(@ir.expr_type(body), @binding.unit_type()) ||
        !@binding.type_equal(type_, @binding.unit_type()) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3048",
          message: "while body and expression type must be Unit",
          span,
        })
      }
    }
    BoundExpr::ForRange(range_loop, type_, span) => {
      let start_type = @ir.expr_type(range_loop.start)
      let end_type = @ir.expr_type(range_loop.end_)
      let body_type = @ir.expr_type(range_loop.body)
      validate_type(context, start_type, span)
      validate_type(context, end_type, span)
      validate_expr(context, range_loop.start)
      validate_expr(context, range_loop.end_)
      validate_expr(context, range_loop.body)
      validate_type(context, type_, span)
      if !@binding.type_equal(start_type, @binding.int_type()) ||
        !@binding.type_equal(end_type, @binding.int_type()) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3010",
          message: "range loop bounds must be Int",
          span,
        })
      }
      if !@binding.type_equal(body_type, @binding.unit_type()) ||
        !@binding.type_equal(type_, @binding.unit_type()) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3011",
          message: "range loop body and expression type must be Unit",
          span,
        })
      }
    }
    BoundExpr::ForIn(for_in, type_, span) => {
      for symbol in for_in.value_symbols {
        validate_type(context, symbol.type_, span)
      }
      validate_expr(context, for_in.iterator)
      for binding in for_in.bindings {
        validate_type(context, binding.symbol.type_, span)
        validate_expr(context, binding.value)
      }
      if for_in.value_symbols.length() == 2 {
        match @binding.iter2_item_types(@ir.expr_type(for_in.iterator)) {
          Some((first, second)) =>
            if !@binding.type_equal(for_in.value_symbols[0].type_, first) ||
              !@binding.type_equal(for_in.value_symbols[1].type_, second) {
              module_.diagnostics.push({
                severity: "error",
                code: "VNX3047",
                message: "for-in value symbols do not match Iter2 item types",
                span,
              })
            }
          None =>
            module_.diagnostics.push({
              severity: "error",
              code: "VNX3047",
              message: "for-in iterator expression must have Iter2 type",
              span,
            })
        }
      } else {
        match @binding.iter_item_type(@ir.expr_type(for_in.iterator)) {
          Some(item) =>
            if for_in.value_symbols.length() != 1 ||
              !@binding.type_equal(for_in.value_symbols[0].type_, item) {
              module_.diagnostics.push({
                severity: "error",
                code: "VNX3047",
                message: "for-in value symbol does not match Iter item type",
                span,
              })
            }
          None =>
            module_.diagnostics.push({
              severity: "error",
              code: "VNX3047",
              message: "for-in iterator expression must have Iter type",
              span,
            })
        }
      }
      validate_expr(context, for_in.body)
      match for_in.no_break {
        Some(no_break) => validate_expr(context, no_break)
        None => ()
      }
      validate_type(context, type_, span)
      if !@binding.type_equal(@ir.expr_type(for_in.body), @binding.unit_type()) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3046",
          message: "for-in body type must be Unit",
          span,
        })
      }
      match for_in.no_break {
        Some(no_break) =>
          if !branch_type_matches(no_break, type_) {
            module_.diagnostics.push({
              severity: "error",
              code: "VNX3046",
              message: "for-in nobreak type does not match loop expression type",
              span,
            })
          }
        None =>
          if !@binding.type_equal(type_, @binding.unit_type()) {
            module_.diagnostics.push({
              severity: "error",
              code: "VNX3046",
              message: "for-in expression type must be Unit without nobreak",
              span,
            })
          }
      }
    }
    BoundExpr::ForLoop(for_loop, type_, span) => {
      for binding in for_loop.bindings {
        validate_type(context, binding.symbol.type_, span)
        validate_expr(context, binding.value)
      }
      match for_loop.condition {
        Some(condition) => {
          validate_expr(context, condition)
          if !@binding.type_equal(
              @ir.expr_type(condition),
              @binding.bool_type(),
            ) {
            module_.diagnostics.push({
              severity: "error",
              code: "VNX3016",
              message: "for loop condition must be Bool",
              span,
            })
          }
        }
        None => ()
      }
      for update in for_loop.updates {
        validate_expr(context, update)
        if !@binding.type_equal(@ir.expr_type(update), @binding.unit_type()) {
          module_.diagnostics.push({
            severity: "error",
            code: "VNX3017",
            message: "for loop update must be Unit",
            span,
          })
        }
      }
      validate_expr(context, for_loop.body)
      validate_type(context, type_, span)
      if !@binding.type_equal(
          @ir.expr_type(for_loop.body),
          @binding.unit_type(),
        ) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3018",
          message: "for loop body type must be Unit",
          span,
        })
      }
    }
    BoundExpr::Break(value, type_, span) => {
      match value {
        Some(expr) => validate_expr(context, expr)
        None => ()
      }
      validate_type(context, type_, span)
      if !@binding.type_equal(type_, @binding.unit_type()) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3019",
          message: "loop control expression type must be Unit",
          span,
        })
      }
    }
    BoundExpr::Continue(args, type_, span) => {
      for arg in args {
        validate_expr(context, arg)
      }
      validate_type(context, type_, span)
      if !@binding.type_equal(type_, @binding.unit_type()) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3019",
          message: "loop control expression type must be Unit",
          span,
        })
      }
    }
    BoundExpr::Return(value, type_, span) => {
      match value {
        Some(expr) => validate_expr(context, expr)
        None => ()
      }
      validate_type(context, type_, span)
      if !@binding.type_equal(type_, @binding.unit_type()) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3045",
          message: "return expression type must be Unit",
          span,
        })
      }
    }
    BoundExpr::Error(reason, _, span) =>
      module_.diagnostics.push({
        severity: "error",
        code: "VNX3002",
        message: "executable IR contains error expression: " + reason,
        span,
      })
  }
}

///|
fn validate_array_element(
  context : ValidationContext,
  item : @ir.BoundArrayElement,
) -> Unit {
  match item {
    @ir.BoundArrayElement::Value(value)
    | @ir.BoundArrayElement::Spread(value) => validate_expr(context, value)
  }
}

///|
fn validate_type(
  context : ValidationContext,
  type_ : TypeRef,
  span : SourceSpan,
) -> Unit {
  let module_ = context.module_
  match type_ {
    TypeRef::Unknown(reason) =>
      module_.diagnostics.push({
        severity: "error",
        code: "VNX3100",
        message: "executable IR contains unknown type: " + reason,
        span,
      })
    TypeRef::Error(reason) =>
      module_.diagnostics.push({
        severity: "error",
        code: "VNX3101",
        message: "executable IR contains error type: " + reason,
        span,
      })
    TypeRef::Declared(symbol, args) => {
      if !module_has_type(context, symbol.id) &&
        symbol.package_id != "pkg:moonbitlang/core/builtin" {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3102",
          message: "executable IR references missing type definition: " +
          symbol.id,
          span,
        })
      }
      for arg in args {
        validate_type(context, arg, span)
      }
    }
    TypeRef::Tuple(items) =>
      for item in items {
        validate_type(context, item, span)
      }
    TypeRef::Function(params, return_type, effect) => {
      for param in params {
        validate_type(context, param.type_, span)
      }
      validate_type(context, return_type, span)
      validate_effect(context, effect, span)
    }
    TypeRef::Apply(_, args) =>
      for arg in args {
        validate_type(context, arg, span)
      }
    TypeRef::TraitObject(trait_ref) => {
      if !module_has_type(context, trait_ref.trait_.id) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3103",
          message: "executable IR references missing trait definition: " +
          trait_ref.trait_.id,
          span,
        })
      }
      for arg in trait_ref.args {
        validate_type(context, arg, span)
      }
    }
    _ => ()
  }
}

///|
fn validate_effect(
  context : ValidationContext,
  effect : EffectRef,
  span : SourceSpan,
) -> Unit {
  let module_ = context.module_
  match effect {
    EffectRef::Raises(error_type) => validate_type(context, error_type, span)
    EffectRef::UnknownEffect(reason) =>
      module_.diagnostics.push({
        severity: "error",
        code: "VNX3104",
        message: "executable IR contains unknown effect: " + reason,
        span,
      })
    _ => ()
  }
}

///|
fn validate_trait_ref(
  context : ValidationContext,
  trait_ref : TraitRef,
  span : SourceSpan,
) -> Unit {
  let module_ = context.module_
  if !module_has_type(context, trait_ref.trait_.id) {
    module_.diagnostics.push({
      severity: "error",
      code: "VNX3103",
      message: "executable IR references missing trait definition: " +
      trait_ref.trait_.id,
      span,
    })
  }
  for arg in trait_ref.args {
    validate_type(context, arg, span)
  }
}

///|
fn module_has_type(context : ValidationContext, type_id : String) -> Bool {
  context.type_ids.contains(type_id)
}

///|
fn validate_match_pattern(
  context : ValidationContext,
  pattern : @ir.BoundPattern,
  target_type : TypeRef,
  span : SourceSpan,
) -> Unit {
  let module_ = context.module_
  match pattern {
    @ir.BoundPattern::Wildcard => ()
    @ir.BoundPattern::Binding(symbol) =>
      validate_type(context, symbol.type_, symbol.span)
    @ir.BoundPattern::IntLiteral(_) =>
      validate_literal_pattern_type(
        context,
        target_type,
        @binding.int_type(),
        "int",
        span,
      )
    @ir.BoundPattern::CharLiteral(_) =>
      validate_literal_pattern_type(
        context,
        target_type,
        @binding.char_type(),
        "char",
        span,
      )
    @ir.BoundPattern::StringLiteral(_) =>
      validate_literal_pattern_type(
        context,
        target_type,
        @binding.string_type(),
        "string",
        span,
      )
    @ir.BoundPattern::BoolLiteral(_) =>
      validate_literal_pattern_type(
        context,
        target_type,
        @binding.bool_type(),
        "bool",
        span,
      )
    @ir.BoundPattern::Range(start, end_, _) => {
      let pattern_type = if @binding.is_char_like_type(target_type) {
        @binding.char_literal_pattern_type(target_type)
      } else {
        @binding.int_type()
      }
      validate_literal_pattern_type(
        context, target_type, pattern_type, "range", span,
      )
      if start is None && end_ is None {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3036",
          message: "range match pattern must have at least one bound",
          span,
        })
      }
    }
    @ir.BoundPattern::Tuple(items) =>
      match target_type {
        TypeRef::Tuple(item_types) => {
          if item_types.length() != items.length() {
            module_.diagnostics.push({
              severity: "error",
              code: "VNX3028",
              message: "tuple match pattern arity does not match target tuple type",
              span,
            })
          }
          let limit = if item_types.length() < items.length() {
            item_types.length()
          } else {
            items.length()
          }
          for i in 0..<limit {
            validate_match_pattern(context, items[i], item_types[i], span)
          }
        }
        _ =>
          module_.diagnostics.push({
            severity: "error",
            code: "VNX3029",
            message: "tuple match pattern target is not tuple type",
            span,
          })
      }
    @ir.BoundPattern::Array(prefix, rest, suffix) =>
      match array_pattern_item_type(target_type) {
        Some(item_type) => {
          for item in prefix {
            validate_match_pattern(context, item, item_type, span)
          }
          for item in suffix {
            validate_match_pattern(context, item, item_type, span)
          }
          validate_array_pattern_rest(
            context,
            rest,
            item_type,
            target_type~,
            span,
          )
        }
        None =>
          module_.diagnostics.push({
            severity: "error",
            code: "VNX3031",
            message: "array match pattern target is not array type",
            span,
          })
      }
    @ir.BoundPattern::Struct(type_id, fields) =>
      match target_type {
        TypeRef::Declared(symbol, _) => {
          if symbol.id != type_id {
            module_.diagnostics.push({
              severity: "error",
              code: "VNX3037",
              message: "struct match pattern type does not match target type",
              span,
            })
          }
          for field in fields {
            validate_type(context, field.field.type_, span)
            validate_match_pattern(
              context,
              field.pattern,
              field.field.type_,
              span,
            )
          }
        }
        _ =>
          module_.diagnostics.push({
            severity: "error",
            code: "VNX3038",
            message: "struct match pattern target is not struct type",
            span,
          })
      }
    @ir.BoundPattern::Or(alternatives) => {
      if alternatives.length() == 0 {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3030",
          message: "or match pattern must have at least one alternative",
          span,
        })
      }
      for alternative in alternatives {
        validate_match_pattern(context, alternative, target_type, span)
      }
    }
    @ir.BoundPattern::OptionNone =>
      match option_item_type(target_type) {
        Some(_) => ()
        None =>
          module_.diagnostics.push({
            severity: "error",
            code: "VNX3026",
            message: "None match pattern target is not Option type",
            span,
          })
      }
    @ir.BoundPattern::OptionSome(payload) =>
      match option_item_type(target_type) {
        Some(item_type) =>
          validate_match_pattern(context, payload, item_type, span)
        None =>
          module_.diagnostics.push({
            severity: "error",
            code: "VNX3027",
            message: "Some match pattern target is not Option type",
            span,
          })
      }
    @ir.BoundPattern::EnumCase(type_id, variant_id, _, bindings) => {
      match target_type {
        TypeRef::Declared(symbol, _) =>
          if symbol.id != type_id {
            module_.diagnostics.push({
              severity: "error",
              code: "VNX3021",
              message: "enum match pattern type does not match target type",
              span,
            })
          }
        _ =>
          module_.diagnostics.push({
            severity: "error",
            code: "VNX3022",
            message: "enum match pattern target is not declared enum type",
            span,
          })
      }
      if !module_type_has_variant(module_, type_id, variant_id) {
        module_.diagnostics.push({
          severity: "error",
          code: "VNX3023",
          message: "enum match pattern references missing variant",
          span,
        })
      }
      match
        module_enum_variant_payload_types(
          module_, type_id, variant_id, target_type,
        ) {
        Some(payload_types) => {
          if payload_types.length() != bindings.length() {
            module_.diagnostics.push({
              severity: "error",
              code: "VNX3024",
              message: "enum match pattern binding count does not match variant payload count",
              span,
            })
          }
          let limit = if payload_types.length() < bindings.length() {
            payload_types.length()
          } else {
            bindings.length()
          }
          for i in 0..<limit {
            validate_match_pattern(context, bindings[i], payload_types[i], span)
          }
        }
        None => ()
      }
    }
  }
}

///|
fn array_pattern_item_type(type_ : TypeRef) -> TypeRef? {
  match @binding.type_constructor_name(type_) {
    Some(("Array", [item]))
    | Some(("FixedArray", [item]))
    | Some(("ArrayView", [item])) => Some(item)
    _ =>
      match type_ {
        TypeRef::Builtin("String") | TypeRef::Builtin("StringView") =>
          Some(@binding.char_code_unit_type())
        _ => None
      }
  }
}

///|
fn validate_array_pattern_rest(
  context : ValidationContext,
  rest : @ir.BoundArrayPatternRest?,
  item_type : TypeRef,
  target_type? : TypeRef = @binding.array_view_type(item_type),
  span : @common.SourceSpan,
) -> Unit {
  let module_ = context.module_
  match rest {
    Some(rest_pattern) =>
      match rest_pattern.symbol {
        Some(symbol) => {
          let expected = if @binding.type_equal(
              target_type,
              @binding.string_type(),
            ) ||
            @binding.type_equal(target_type, @binding.string_view_type()) {
            @binding.string_view_type()
          } else {
            @binding.array_view_type(item_type)
          }
          if !@binding.type_equal(symbol.type_, expected) {
            module_.diagnostics.push({
              severity: "error",
              code: "VNX3037",
              message: "array rest match binding must be ArrayView of item type",
              span,
            })
          }
        }
        None => ()
      }
    None => ()
  }
}

///|
fn validate_literal_pattern_type(
  context : ValidationContext,
  target_type : TypeRef,
  pattern_type : TypeRef,
  name : String,
  span : SourceSpan,
) -> Unit {
  let module_ = context.module_
  if !@binding.literal_match_pattern_types_compatible(target_type, pattern_type) {
    module_.diagnostics.push({
      severity: "error",
      code: "VNX3025",
      message: name + " match pattern type does not match target type",
      span,
    })
  }
}

///|
fn module_type_has_field(
  module_ : BoundModule,
  type_id : String,
  field_name : String,
) -> Bool {
  for type_def in module_.types {
    match type_def {
      @binding.TypeDefinition::Struct(struct_def) =>
        if struct_def.symbol.id == type_id {
          for field in struct_def.fields {
            if field.name == field_name {
              return true
            }
          }
        }
      @binding.TypeDefinition::Opaque(_) | @binding.TypeDefinition::Enum(_) =>
        ()
    }
  }
  false
}

///|
fn module_field_info(
  module_ : BoundModule,
  receiver_type : TypeRef,
  field_name : String,
) -> @binding.FieldRef? {
  match receiver_type {
    TypeRef::Apply(TypeConstructorRef::Builtin("Ref"), [item_type]) =>
      if field_name == "val" {
        return Some({
          owner_type_id: "builtin:Ref",
          field_id: "builtin:Ref:field:val",
          name: "val",
          mutable: true,
          type_: item_type,
        })
      }
    TypeRef::Declared(symbol, args) =>
      for type_def in module_.types {
        match type_def {
          @binding.TypeDefinition::Struct(struct_def) =>
            if struct_def.symbol.id == symbol.id {
              for field in struct_def.fields {
                if field.name == field_name {
                  return Some({
                    owner_type_id: struct_def.symbol.id,
                    field_id: field.id,
                    name: field.name,
                    mutable: field.mutable,
                    type_: substitute_type(
                      struct_def.type_params,
                      args,
                      field.type_,
                    ),
                  })
                }
              }
            }
          @binding.TypeDefinition::Opaque(_)
          | @binding.TypeDefinition::Enum(_) => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn module_type_has_variant(
  module_ : BoundModule,
  type_id : String,
  variant_id : String,
) -> Bool {
  match module_enum_variant_payload_count(module_, type_id, variant_id) {
    Some(_) => true
    None => false
  }
}

///|
fn module_enum_variant_payload_count(
  module_ : BoundModule,
  type_id : String,
  variant_id : String,
) -> Int? {
  for type_def in module_.types {
    match type_def {
      @binding.TypeDefinition::Enum(enum_def) =>
        if enum_def.symbol.id == type_id {
          for variant in enum_def.variants {
            if variant.id == variant_id {
              return Some(variant.payloads.length())
            }
          }
        }
      @binding.TypeDefinition::Opaque(_) | @binding.TypeDefinition::Struct(_) =>
        ()
    }
  }
  None
}

///|
fn module_enum_variant_payload_types(
  module_ : BoundModule,
  type_id : String,
  variant_id : String,
  target_type : TypeRef,
) -> FixedArray[TypeRef]? {
  let args = match target_type {
    TypeRef::Declared(symbol, args) =>
      if symbol.id == type_id {
        args
      } else {
        []
      }
    _ => []
  }
  for type_def in module_.types {
    match type_def {
      @binding.TypeDefinition::Enum(enum_def) =>
        if enum_def.symbol.id == type_id {
          for variant in enum_def.variants {
            if variant.id == variant_id {
              let payloads = FixedArray::make(
                variant.payloads.length(),
                @binding.unresolved_type_ref(),
              )
              for i in 0..<variant.payloads.length() {
                payloads[i] = substitute_type(
                  enum_def.type_params,
                  args,
                  variant.payloads[i].type_,
                )
              }
              return Some(payloads)
            }
          }
        }
      @binding.TypeDefinition::Opaque(_) | @binding.TypeDefinition::Struct(_) =>
        ()
    }
  }
  None
}

///|
fn branch_type_matches(expr : BoundExpr, type_ : TypeRef) -> Bool {
  control_transfer_expr(expr) || @binding.type_equal(@ir.expr_type(expr), type_)
}

///|
fn control_transfer_expr(expr : BoundExpr) -> Bool {
  match expr {
    BoundExpr::Break(_, _, _)
    | BoundExpr::Continue(_, _, _)
    | BoundExpr::Return(_, _, _) => true
    BoundExpr::If(_, then_, else_, _, _) =>
      control_transfer_expr(then_) && control_transfer_expr(else_)
    _ => false
  }
}

///|
fn option_item_type(type_ : TypeRef) -> TypeRef? {
  match type_ {
    TypeRef::Apply(TypeConstructorRef::Builtin("Option"), [item]) => Some(item)
    _ => None
  }
}
