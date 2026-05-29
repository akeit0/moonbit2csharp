///|
test "declaration index resolves imported alias and detects duplicate local type" {
  let diagnostics : Array[Diagnostic] = []
  let span = @common.source_span("main.mbt", 0, 1, 1, 1)
  let index = declaration_index(
    "pkg:main",
    "Main",
    [{ alias_name: "dep", package_id: "pkg:dep", module_path: "dep" }],
    diagnostics,
  )
  let dep_symbol = @binding.make_type_symbol("pkg:dep", "dep", "Box")
  add_imported_type_definitions(index, [
    @binding.TypeDefinition::Struct({
      symbol: dep_symbol,
      type_params: ["T"],
      fields: [],
      derives: [],
    }),
  ])
  assert_true(find_visible_type_header(index, Some("dep"), "Box") is Some(_))
  assert_true(find_visible_type_header(index, None, "Box") is None)

  let local_symbol = @binding.make_type_symbol("pkg:main", "Main", "Thing")
  declare_type_header(index, local_symbol, [], span)
  declare_type_header(index, local_symbol, [], span)
  assert_true(diagnostics.length() == 1)
  assert_true(diagnostics[0].code == "VNX2000")
}

///|
test "declaration index stores imported callables without local name lookup" {
  let diagnostics : Array[Diagnostic] = []
  let span = @common.source_span("main.mbt", 0, 1, 1, 1)
  let index = declaration_index(
    "pkg:main",
    "Main",
    [{ alias_name: "dep", package_id: "pkg:dep", module_path: "dep" }],
    diagnostics,
  )
  let imported : @binding.FunctionSignature = {
    function_id: "fn:pkg:dep:dep:make",
    package_id: "pkg:dep",
    module_path: "dep",
    name: "make",
    receiver_type: None,
    type_params: [],
    parameters: [],
    return_type: @binding.int_type(),
    effect: @binding.no_raise(),
    aliases: [],
    intrinsic: None,
    is_public: true,
    span,
  }
  add_imported_functions(index, [imported])
  assert_true(find_function(index, imported.function_id) is Some(_))
  assert_true(find_functions_by_name(index, "make").length() == 0)
}

///|
test "moon pkg imports expose imported receiver methods" {
  let diagnostics : Array[Diagnostic] = []
  let span = @common.source_span("main.mbt", 0, 1, 1, 1)
  let index = declaration_index(
    "pkg:main",
    "Main",
    [{ alias_name: "sem", package_id: "pkg:sem", module_path: "sem" }],
    diagnostics,
  )
  let receiver_symbol = @binding.make_type_symbol(
    "pkg:sem", "sem", "DeclarationIndex",
  )
  let receiver_type = TypeRef::Declared(receiver_symbol, [])
  let imported : @binding.FunctionSignature = {
    function_id: "fn:pkg:sem:sem:DeclarationIndex::error",
    package_id: "pkg:sem",
    module_path: "sem",
    name: "DeclarationIndex::error",
    receiver_type: Some(receiver_type),
    type_params: [],
    parameters: [],
    return_type: @binding.unit_type(),
    effect: @binding.no_raise(),
    aliases: [],
    intrinsic: None,
    is_public: true,
    span,
  }
  add_imported_functions(index, [imported])
  assert_true(
    find_receiver_functions(index, receiver_type, "error").length() == 1,
  )
  assert_true(
    find_static_receiver_functions(index, "DeclarationIndex", "error").length() ==
    1,
  )
}

///|
test "declaration index exposes builtin Add operator through impl evidence" {
  let diagnostics : Array[Diagnostic] = []
  let index = declaration_index("pkg:main", "Main", [], diagnostics)
  declare_intrinsic_impl_method(
    index,
    "Add",
    @binding.int_type(),
    "add",
    "%i32_add",
    @common.source_span("intrinsics.mbt", 0, 1, 1, 1),
  )
  let key = match binary_operator_key_from_token("+") {
    Some(key) => key
    None => fail("missing + operator key")
  }
  let candidate = match
    find_operator_candidate(index, key, @binding.int_type()) {
    Some(candidate) => candidate
    None => fail("missing builtin Add operator candidate")
  }
  assert_true(
    candidate.signature.function_id ==
    "fn:pkg:main:Main:impl:moonbitlang/core/builtin:Add:Int:add",
  )
  assert_true(candidate.evidence.trait_ref.trait_.name == "Add")
  assert_true(candidate.evidence.source is ImplEvidenceSource::BuiltinImpl(_))
  assert_true(candidate.method_body is ImplMethodBody::Intrinsic("%i32_add"))
}

///|
test "declaration index stores intrinsic-backed Double operator impls" {
  let diagnostics : Array[Diagnostic] = []
  let index = declaration_index("pkg:main", "Main", [], diagnostics)
  declare_intrinsic_impl_method(
    index,
    "Add",
    @binding.double_type(),
    "add",
    "%f64_add",
    @common.source_span("intrinsics.mbt", 0, 1, 1, 1),
  )
  let key = match binary_operator_key_from_token("+") {
    Some(key) => key
    None => fail("missing + operator key")
  }
  let candidate = match
    find_operator_candidate(index, key, @binding.double_type()) {
    Some(candidate) => candidate
    None => fail("missing builtin Double Add operator candidate")
  }
  assert_true(candidate.evidence.trait_ref.trait_.name == "Add")
  assert_true(candidate.method_body is ImplMethodBody::Intrinsic("%f64_add"))
}

///|
test "operator impls inherit default trait operator methods" {
  let diagnostics : Array[Diagnostic] = []
  let span = @common.source_span("intrinsics.mbt", 0, 1, 1, 1)
  let index = declaration_index(
    "pkg:moonbitlang/core/builtin",
    "moonbitlang/core/builtin",
    [],
    diagnostics,
  )
  let eq_symbol = @binding.make_type_symbol(
    "pkg:moonbitlang/core/builtin", "moonbitlang/core/builtin", "Eq",
  )
  declare_trait(index, {
    symbol: eq_symbol,
    type_params: [],
    methods: [
      {
        method_id: "trait-method:" + eq_symbol.id + ":equal",
        name: "equal",
        parameters: [
          {
            label: None,
            type_: @binding.string_type(),
            optional: false,
            has_default: false,
          },
          {
            label: None,
            type_: @binding.string_type(),
            optional: false,
            has_default: false,
          },
        ],
        return_type: @binding.bool_type(),
        has_default: false,
        default_function_id: None,
        span,
      },
      {
        method_id: "trait-method:" + eq_symbol.id + ":not_equal",
        name: "not_equal",
        parameters: [
          {
            label: None,
            type_: @binding.string_type(),
            optional: false,
            has_default: false,
          },
          {
            label: None,
            type_: @binding.string_type(),
            optional: false,
            has_default: false,
          },
        ],
        return_type: @binding.bool_type(),
        has_default: true,
        default_function_id: None,
        span,
      },
    ],
    span,
  })
  declare_intrinsic_impl_method(
    index,
    "Eq",
    @binding.string_type(),
    "equal",
    "%string_eq",
    span,
  )
  let key = match binary_operator_key_from_token("!=") {
    Some(key) => key
    None => fail("missing != operator key")
  }
  let candidate = match
    find_operator_candidate(index, key, @binding.string_type()) {
    Some(candidate) => candidate
    None => fail("missing default String not_equal operator candidate")
  }
  assert_true(candidate.signature.name == "not_equal")
  assert_true(candidate.method_body is ImplMethodBody::DefaultMethod)
  assert_true(diagnostics.length() == 0)
}

///|
test "inference conversion solves array to arrayview item type" {
  let typing = typing_context()
  let item = inference_type("test:item")
  let conversion = classify_conversion_with_inference(
    typing,
    @binding.array_view_type(item),
    @binding.array_type(@binding.string_type()),
  )
  assert_true(conversion == ConversionKind::ArrayToArrayView)
  assert_true(
    @binding.type_equal(
      resolve_inferred_type(typing, item),
      @binding.string_type(),
    ),
  )
}

///|
test "default trait method function id is generic" {
  let trait_id = "type:pkg:demo:Demo:Show2"
  assert_eq(
    default_trait_method_function_id(trait_id, "to_string2"),
    "default-trait:" + trait_id + ":to_string2",
  )
}

///|
test "executable validation rejects error expressions and missing struct definitions" {
  let span = @common.source_span("main.mbt", 0, 1, 1, 1)
  let missing_symbol = @binding.make_type_symbol("pkg:main", "Main", "Missing")
  let module_ : BoundModule = {
    schema: "moonbit2csharp.vnext.semantic-ir/0.1",
    module_name: "Main",
    symbols: [],
    types: [],
    traits: [],
    used_trait_impls: [],
    functions: [],
    globals: [
      {
        symbol_id: "global:Main:m",
        name: "m",
        type_: TypeRef::Declared(missing_symbol, []),
        value: BoundExpr::StructLiteral(
          missing_symbol.id,
          [],
          TypeRef::Declared(missing_symbol, []),
          span,
        ),
        span,
      },
    ],
    default_arguments: [],
    diagnostics: [],
  }
  validate_executable_module(module_)
  let mut has_missing_type = false
  let mut has_missing_struct_literal_type = false
  for diagnostic in module_.diagnostics {
    if diagnostic.code == "VNX3102" {
      has_missing_type = true
    }
    if diagnostic.code == "VNX3000" {
      has_missing_struct_literal_type = true
    }
  }
  assert_true(has_missing_type)
  assert_true(has_missing_struct_literal_type)
}

///|
test "executable validation rejects invalid field access and assignment" {
  let span = @common.source_span("main.mbt", 0, 1, 1, 1)
  let struct_symbol = @binding.make_type_symbol("pkg:main", "Main", "Box")
  let box_type = TypeRef::Declared(struct_symbol, [])
  let target = BoundExpr::Name("local:b:1", "b", box_type, span)
  let field_id = "field:" + struct_symbol.id + ":value"
  let module_ : BoundModule = {
    schema: "moonbit2csharp.vnext.semantic-ir/0.1",
    module_name: "Main",
    symbols: [],
    types: [
      @binding.TypeDefinition::Struct({
        symbol: struct_symbol,
        type_params: [],
        fields: [
          {
            id: field_id,
            name: "value",
            mutable: false,
            type_: @binding.int_type(),
          },
        ],
        derives: [],
      }),
    ],
    traits: [],
    used_trait_impls: [],
    functions: [],
    globals: [
      {
        symbol_id: "global:pkg:main:Main:bad_read",
        name: "bad_read",
        type_: @binding.int_type(),
        value: BoundExpr::FieldAccess(
          target,
          {
            owner_type_id: struct_symbol.id,
            field_id: "field:" + struct_symbol.id + ":missing",
            name: "missing",
            mutable: false,
            type_: @binding.int_type(),
          },
          @binding.int_type(),
          span,
        ),
        span,
      },
      {
        symbol_id: "global:pkg:main:Main:bad_write",
        name: "bad_write",
        type_: @binding.unit_type(),
        value: BoundExpr::FieldAssign(
          target,
          {
            owner_type_id: struct_symbol.id,
            field_id,
            name: "value",
            mutable: false,
            type_: @binding.int_type(),
          },
          BoundExpr::IntLiteral("1", @binding.int_type(), span),
          @binding.unit_type(),
          span,
        ),
        span,
      },
    ],
    default_arguments: [],
    diagnostics: [],
  }
  validate_executable_module(module_)
  let mut has_missing_field = false
  let mut has_immutable_field = false
  for diagnostic in module_.diagnostics {
    if diagnostic.code == "VNX3006" {
      has_missing_field = true
    }
    if diagnostic.code == "VNX3007" {
      has_immutable_field = true
    }
  }
  assert_true(has_missing_field)
  assert_true(has_immutable_field)
}

///|
test "resolved conversion classifies implicit view conversions" {
  assert_true(
    classify_conversion(@binding.string_view_type(), @binding.string_type()) ==
    ConversionKind::StringToStringView,
  )
  assert_true(
    classify_conversion(
      @binding.array_view_type(@binding.int_type()),
      @binding.array_type(@binding.int_type()),
    ) ==
    ConversionKind::ArrayToArrayView,
  )
  assert_true(
    classify_conversion(
      @binding.array_view_type(@binding.int_type()),
      @binding.fixed_array_type(@binding.int_type()),
    ) ==
    ConversionKind::FixedArrayToArrayView,
  )
  assert_true(
    resolved_type_has_invalid_or_unknown(
      resolved_type_from_type_ref(TypeRef::Unknown("test")),
    ),
  )
}

///|
test "resolved conversion treats char and code unit types as compatible" {
  assert_true(
    classify_conversion(@binding.char_code_unit_type(), @binding.char_type()) ==
    ConversionKind::Identity,
  )
  assert_true(
    classify_conversion(@binding.char_type(), @binding.char_code_unit_type()) ==
    ConversionKind::Identity,
  )
  assert_true(
    unify_types(
      typing_context(),
      @binding.char_code_unit_type(),
      @binding.char_type(),
    ),
  )
}

///|
test "conversion classification solves array view element inference" {
  let typing = typing_context()
  let item = inference_type("array-view-item")
  let conversion = classify_conversion_with_inference(
    typing,
    @binding.array_view_type(item),
    @binding.array_type(@binding.int_type()),
  )
  assert_true(conversion == ConversionKind::ArrayToArrayView)
  assert_true(resolve_inferred_type(typing, item) == @binding.int_type())
}

///|
test "typing context keeps declared type parameters rigid and solves local inference variables" {
  let typing = typing_context()
  let type_param = TypeRef::TypeParameter("T", "type-param:T")
  assert_false(unify_types(typing, type_param, @binding.int_type()))
  assert_true(resolve_inferred_type(typing, type_param) == type_param)

  let local_type = local_inference_type("local:x:1")
  assert_true(unify_types(typing, local_type, @binding.string_view_type()))
  assert_true(
    resolve_inferred_type(typing, local_type) == @binding.string_view_type(),
  )
}

///|
test "typing context rejects recursive inference substitutions" {
  let typing = typing_context()
  let variable = inference_type("recursive")
  assert_false(unify_types(typing, variable, @binding.array_type(variable)))
  assert_true(resolve_inferred_type(typing, variable) == variable)
}
