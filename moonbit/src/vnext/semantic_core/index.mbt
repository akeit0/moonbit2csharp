///|
using @common {source_span}

///|
pub fn binary_operator_key_from_token(op : String) -> OperatorKey? {
  match op {
    "+" => Some(arithmetic_operator_key(OperatorKind::Add))
    "-" => Some(arithmetic_operator_key(OperatorKind::Sub))
    "*" => Some(arithmetic_operator_key(OperatorKind::Mul))
    "/" => Some(arithmetic_operator_key(OperatorKind::Div))
    "%" => Some(arithmetic_operator_key(OperatorKind::Mod))
    "&" => Some(bitwise_operator_key(OperatorKind::BitAnd))
    "|" => Some(bitwise_operator_key(OperatorKind::BitOr))
    "^" => Some(bitwise_operator_key(OperatorKind::BitXOr))
    "<<" => Some(bitwise_operator_key(OperatorKind::Shl))
    ">>" => Some(bitwise_operator_key(OperatorKind::Shr))
    "==" => Some(equality_operator_key(OperatorKind::Equal))
    "!=" => Some(equality_operator_key(OperatorKind::NotEqual))
    "<" => Some(comparison_operator_key(OperatorKind::Less))
    ">" => Some(comparison_operator_key(OperatorKind::Greater))
    "<=" => Some(comparison_operator_key(OperatorKind::LessEqual))
    ">=" => Some(comparison_operator_key(OperatorKind::GreaterEqual))
    _ => None
  }
}

///|
pub fn unary_operator_key_from_token(op : String) -> OperatorKey? {
  match op {
    "-" => Some(unary_neg_operator_key())
    _ => None
  }
}

///|
pub fn find_operator_candidate(
  index : DeclarationIndex,
  key : OperatorKey,
  self_type : TypeRef,
) -> OperatorCandidate? {
  index.operator_impls_by_key.get(operator_impl_lookup_key(key, self_type))
}

///|
pub fn find_operator_candidates(
  index : DeclarationIndex,
  key : OperatorKey,
  self_type : TypeRef,
) -> Array[OperatorCandidate] {
  let result : Array[OperatorCandidate] = []
  match find_operator_candidate(index, key, self_type) {
    Some(candidate) => result.push(candidate)
    None => ()
  }
  for entry in index.operator_impls {
    if entry.key == key &&
      operator_self_type_matches(
        entry.candidate.signature.type_params,
        entry.self_type,
        self_type,
      ) {
      push_operator_candidate_once(result, entry.candidate)
    }
  }
  result
}

///|
fn push_operator_candidate_once(
  result : Array[OperatorCandidate],
  candidate : OperatorCandidate,
) -> Unit {
  for existing in result {
    if same_operator_impl_identity(existing, candidate) {
      return
    }
  }
  result.push(candidate)
}

///|
fn operator_self_type_matches(
  type_params : Array[@binding.TypeParamConstraint],
  candidate_self_type : TypeRef,
  actual_self_type : TypeRef,
) -> Bool {
  if type_params.length() == 0 {
    return @binding.type_equal(candidate_self_type, actual_self_type)
  }
  let typing = typing_context()
  let instantiated_self_type = instantiate_function_type(
    typing,
    function_type_param_names(type_params),
    candidate_self_type,
  )
  unify_types(typing, instantiated_self_type, actual_self_type)
}

///|
fn function_type_param_names(
  type_params : Array[@binding.TypeParamConstraint],
) -> Array[String] {
  let result : Array[String] = []
  for param in type_params {
    result.push(param.name)
  }
  result
}

///|
fn type_param_constraints_from_names(
  type_params : Array[String],
) -> Array[@binding.TypeParamConstraint] {
  let result : Array[@binding.TypeParamConstraint] = Array::new(
    capacity=type_params.length(),
  )
  for param in type_params {
    result.push({ name: param, constraints: [] })
  }
  result
}

///|
fn type_param_constraints_from_fixed_names(
  type_params : FixedArray[String],
) -> Array[@binding.TypeParamConstraint] {
  let result : Array[@binding.TypeParamConstraint] = Array::new(
    capacity=type_params.length(),
  )
  for param in type_params {
    result.push({ name: param, constraints: [] })
  }
  result
}

///|
pub fn add_imported_type_definitions(
  index : DeclarationIndex,
  imported_types : Array[TypeDefinition],
) -> Unit {
  for def in imported_types {
    let (symbol, type_params) = @binding.type_definition_header(def)
    index.type_headers.push({
      symbol,
      type_params,
      span: source_span("", 0, 0, 1, 1),
    })
    index.type_definitions.push(def)
  }
}

///|
pub fn declare_intrinsic_impl_method(
  index : DeclarationIndex,
  trait_name : String,
  self_type : TypeRef,
  method_name : String,
  intrinsic : String,
  span : SourceSpan,
) -> Unit {
  declare_impl_method_with_type_params(
    index,
    trait_name,
    self_type,
    [],
    method_name,
    ImplMethodBody::Intrinsic(intrinsic),
    span,
  )
}

///|
pub fn declare_impl_method(
  index : DeclarationIndex,
  trait_name : String,
  self_type : TypeRef,
  method_name : String,
  body : ImplMethodBody,
  span : SourceSpan,
) -> Unit {
  declare_impl_method_with_type_params(
    index,
    trait_name,
    self_type,
    [],
    method_name,
    body,
    span,
  )
}

///|
pub fn declare_impl_method_with_type_params(
  index : DeclarationIndex,
  trait_name : String,
  self_type : TypeRef,
  type_params : FixedArray[String],
  method_name : String,
  body : ImplMethodBody,
  span : SourceSpan,
) -> Unit {
  declare_impl_method_with_type_param_constraints(
    index,
    trait_name,
    self_type,
    type_param_constraints_from_fixed_names(type_params),
    method_name,
    body,
    span,
  )
}

///|
pub fn default_trait_method_function_id(
  trait_id : String,
  method_name : String,
) -> String {
  "default-trait:" + trait_id + ":" + method_name
}

///|
pub fn declare_default_trait_impl_method(
  index : DeclarationIndex,
  trait_name : String,
  method_name : String,
  type_params : Array[@binding.TypeParamConstraint],
  span : SourceSpan,
) -> Unit {
  let (package_alias, name) = split_qualified_trait_name(trait_name)
  match find_visible_trait(index, package_alias, name) {
    Some(trait_def) =>
      match find_trait_method_signature(trait_def, method_name) {
        Some(trait_method) => {
          let function_id = default_trait_method_function_id(
            trait_def.symbol.id,
            method_name,
          )
          let binding_type_params = default_trait_impl_type_params(
            type_params,
            trait_def.symbol.name,
          )
          let self_type = default_trait_impl_self_type(
            binding_type_params,
            trait_def.symbol.id,
          )
          let parameters = impl_method_parameters(
            function_id,
            trait_method.parameters,
            self_type,
            span,
          )
          let return_type = substitute_impl_self_type(
            trait_method.return_type,
            self_type,
          )
          ignore(
            declare_impl_method_signature_with_types(
              index, function_id, method_name, binding_type_params, parameters, return_type,
              span,
            ),
          )
          set_trait_method_default_function_id(
            index,
            trait_def.symbol.id,
            method_name,
            function_id,
          )
        }
        None =>
          index.error(
            "VNX2202",
            "impl method is not declared by trait: " + method_name,
            span,
          )
      }
    None => index.error("VNX2201", "unknown trait in impl: " + trait_name, span)
  }
}

///|
pub fn default_trait_impl_type_params(
  impl_type_params : Array[@binding.TypeParamConstraint],
  trait_name : String,
) -> Array[@binding.TypeParamConstraint] {
  if impl_type_params.length() > 0 {
    return impl_type_params
  }
  [{ name: "T", constraints: [trait_name] }]
}

///|
fn default_trait_impl_self_type(
  type_params : Array[@binding.TypeParamConstraint],
  trait_id : String,
) -> TypeRef {
  let name = type_params[0].name
  TypeRef::TypeParameter(
    name,
    "type-param:default-trait:" + trait_id + ":" + name,
  )
}

///|
fn set_trait_method_default_function_id(
  index : DeclarationIndex,
  trait_id : String,
  method_name : String,
  function_id : String,
) -> Unit {
  match index.traits_by_id.get(trait_id) {
    Some(trait_def) => {
      let methods : Array[TraitMethodSignature] = []
      for trait_method in trait_def.methods {
        if trait_method.name == method_name {
          methods.push({
            method_id: trait_method.method_id,
            name: trait_method.name,
            parameters: trait_method.parameters,
            return_type: trait_method.return_type,
            has_default: trait_method.has_default,
            default_function_id: Some(function_id),
            span: trait_method.span,
          })
        } else {
          methods.push(trait_method)
        }
      }
      replace_trait_definition(index, {
        symbol: trait_def.symbol,
        type_params: trait_def.type_params,
        methods,
        span: trait_def.span,
      })
    }
    None => ()
  }
}

///|
fn ensure_default_trait_method_signature(
  index : DeclarationIndex,
  trait_def : TraitDefinition,
  trait_method : TraitMethodSignature,
  function_id : String,
  span : SourceSpan,
) -> Unit {
  if find_function(index, function_id) is Some(_) {
    return
  }
  let type_params = default_trait_impl_type_params([], trait_def.symbol.name)
  let self_type = default_trait_impl_self_type(type_params, trait_def.symbol.id)
  ignore(
    declare_impl_method_signature_with_types(
      index,
      function_id,
      trait_method.name,
      type_params,
      impl_method_parameters(
        function_id,
        trait_method.parameters,
        self_type,
        span,
      ),
      substitute_impl_self_type(trait_method.return_type, self_type),
      span,
    ),
  )
}

///|
pub fn declare_impl_method_with_type_param_constraints(
  index : DeclarationIndex,
  trait_name : String,
  self_type : TypeRef,
  type_params : Array[@binding.TypeParamConstraint],
  method_name : String,
  body : ImplMethodBody,
  span : SourceSpan,
) -> Unit {
  let type_param_names = function_type_param_names(type_params)
  match operator_key_from_trait_method(trait_name, method_name) {
    Some(key) =>
      add_operator_trait_impl_method(
        index, key, self_type, type_param_names, method_name, body, span,
      )
    None =>
      add_trait_impl_method_with_type_param_constraints(
        index, trait_name, self_type, type_params, method_name, body, span,
      )
  }
}

///|
pub fn declare_impl_conformance(
  index : DeclarationIndex,
  trait_name : String,
  self_type : TypeRef,
  span : SourceSpan,
) -> Unit {
  ignore(try_declare_impl_conformance(index, trait_name, self_type, span))
}

///|
pub fn try_declare_impl_conformance(
  index : DeclarationIndex,
  trait_name : String,
  self_type : TypeRef,
  span : SourceSpan,
) -> Bool {
  let (package_alias, name) = split_qualified_trait_name(trait_name)
  match find_visible_trait(index, package_alias, name) {
    Some(trait_def) => {
      let evidence : ImplEvidence = {
        evidence_id: "impl:" +
        trait_def.symbol.id +
        ":" +
        @binding.type_name(self_type),
        trait_ref: { trait_: trait_def.symbol, args: [] },
        self_type,
        type_args: [],
        source: ImplEvidenceSource::ConcreteImpl("interface"),
      }
      let methods : Array[ImplMethodSignature] = []
      for trait_method in trait_def.methods {
        let function_id = impl_method_function_id_for(
          index,
          trait_def.symbol,
          self_type,
          trait_method.name,
        )
        methods.push({
          method_id: trait_method.method_id,
          name: trait_method.name,
          function_id,
          body: ImplMethodBody::Function(function_id),
          span,
        })
        ignore(
          declare_impl_method_signature(
            index, self_type, trait_method, function_id, span,
          ),
        )
      }
      add_or_merge_impl(index, {
        impl_id: evidence.evidence_id,
        trait_ref: evidence.trait_ref,
        self_type,
        methods,
        source: evidence.source,
        span,
      })
      true
    }
    None => {
      index.error("VNX2201", "unknown trait in impl: " + trait_name, span)
      false
    }
  }
}

///|
pub fn try_declare_imported_interface_impl_conformance(
  index : DeclarationIndex,
  trait_name : String,
  self_type : TypeRef,
  span : SourceSpan,
) -> Bool {
  let (package_alias, name) = split_qualified_trait_name(trait_name)
  match find_visible_trait(index, package_alias, name) {
    Some(_) => try_declare_impl_conformance(index, trait_name, self_type, span)
    None => false
  }
}

///|
pub fn declare_derived_eq_operator_impls(
  index : DeclarationIndex,
  self_type : TypeRef,
  span : SourceSpan,
) -> Unit {
  declare_derived_operator_impl(
    index,
    equality_operator_key(OperatorKind::Equal),
    self_type,
    span,
  )
  declare_derived_operator_impl(
    index,
    equality_operator_key(OperatorKind::NotEqual),
    self_type,
    span,
  )
}

///|
pub fn declare_derived_compare_operator_impls(
  index : DeclarationIndex,
  self_type : TypeRef,
  span : SourceSpan,
) -> Unit {
  declare_derived_operator_impl(
    index,
    comparison_operator_key(OperatorKind::Less),
    self_type,
    span,
  )
  declare_derived_operator_impl(
    index,
    comparison_operator_key(OperatorKind::Greater),
    self_type,
    span,
  )
  declare_derived_operator_impl(
    index,
    comparison_operator_key(OperatorKind::LessEqual),
    self_type,
    span,
  )
  declare_derived_operator_impl(
    index,
    comparison_operator_key(OperatorKind::GreaterEqual),
    self_type,
    span,
  )
}

///|
pub fn declare_derived_hash_impl(
  index : DeclarationIndex,
  self_type : TypeRef,
  type_params : FixedArray[String],
  span : SourceSpan,
) -> Unit {
  declare_derived_non_operator_impl(
    index, "Hash", "hash_combine", self_type, type_params, span,
  )
}

///|
pub fn declare_derived_default_impl(
  index : DeclarationIndex,
  self_type : TypeRef,
  type_params : FixedArray[String],
  span : SourceSpan,
) -> Unit {
  declare_derived_non_operator_impl(
    index, "Default", "default", self_type, type_params, span,
  )
}

///|
pub fn declare_derived_debug_impl(
  index : DeclarationIndex,
  self_type : TypeRef,
  type_params : FixedArray[String],
  span : SourceSpan,
) -> Unit {
  declare_derived_non_operator_impl(
    index, "Debug", "to_repr", self_type, type_params, span,
  )
}

///|
fn declare_derived_non_operator_impl(
  index : DeclarationIndex,
  trait_name : String,
  method_name : String,
  self_type : TypeRef,
  type_params : FixedArray[String],
  span : SourceSpan,
) -> Unit {
  match find_derived_trait(index, trait_name) {
    Some(trait_def) =>
      match find_trait_method_signature(trait_def, method_name) {
        Some(trait_method) => {
          let function_id = "derived:trait:" +
            trait_def.symbol.id +
            ":" +
            @binding.type_name(self_type) +
            ":" +
            method_name
          let parameters = impl_method_parameters(
            function_id,
            trait_method.parameters,
            self_type,
            span,
          )
          let return_type = substitute_impl_self_type(
            trait_method.return_type,
            self_type,
          )
          ignore(
            declare_impl_method_signature_with_types(
              index,
              function_id,
              derived_impl_function_name(trait_name, method_name, self_type),
              type_param_constraints_from_fixed_names(type_params),
              parameters,
              return_type,
              span,
            ),
          )
          let evidence : ImplEvidence = {
            evidence_id: "derived-impl:" +
            trait_def.symbol.id +
            ":" +
            @binding.type_name(self_type),
            trait_ref: { trait_: trait_def.symbol, args: [] },
            self_type,
            type_args: [],
            source: ImplEvidenceSource::ConcreteImpl("derive"),
          }
          add_or_merge_impl(index, {
            impl_id: evidence.evidence_id,
            trait_ref: evidence.trait_ref,
            self_type,
            methods: [
              {
                method_id: trait_method.method_id,
                name: method_name,
                function_id,
                body: ImplMethodBody::DefaultMethod,
                span,
              },
            ],
            source: evidence.source,
            span,
          })
        }
        None =>
          index.error(
            "VNX2202",
            trait_name + " trait does not declare " + method_name,
            span,
          )
      }
    None =>
      index.error("VNX2201", "unknown trait in derive: " + trait_name, span)
  }
}

///|
fn derived_impl_function_name(
  trait_name : String,
  method_name : String,
  self_type : TypeRef,
) -> String {
  if trait_name == "Default" && method_name == "default" {
    match self_type {
      TypeRef::Declared(symbol, _) => symbol.name + "::default"
      _ => method_name
    }
  } else {
    method_name
  }
}

///|
fn find_derived_trait(
  index : DeclarationIndex,
  trait_name : String,
) -> TraitDefinition? {
  match index.traits_by_name.get(trait_name) {
    Some(traits) => {
      for trait_def in traits {
        if derived_trait_package_matches(trait_def.symbol, trait_name) {
          return Some(trait_def)
        }
      }
      if traits.length() == 1 {
        return Some(traits[0])
      }
    }
    None => ()
  }
  None
}

///|
fn derived_trait_package_matches(
  symbol : TypeSymbolRef,
  trait_name : String,
) -> Bool {
  if trait_name == "Debug" {
    symbol.package_id == "pkg:moonbitlang/core/debug"
  } else {
    symbol.package_id == "pkg:moonbitlang/core/builtin"
  }
}

///|
fn declare_derived_operator_impl(
  index : DeclarationIndex,
  key : OperatorKey,
  self_type : TypeRef,
  span : SourceSpan,
) -> Unit {
  let binding = operator_trait_binding(key, self_type)
  let method_id = "trait-method:" +
    binding.trait_symbol.id +
    ":" +
    binding.method_name
  let function_id = "derived:trait:" +
    binding.trait_symbol.id +
    ":" +
    @binding.type_name(self_type) +
    ":" +
    binding.method_name
  let signature : FunctionSignature = {
    function_id,
    package_id: binding.trait_symbol.package_id,
    module_path: binding.trait_symbol.module_path,
    name: binding.method_name,
    receiver_type: None,
    type_params: [],
    parameters: builtin_operator_parameters(
      function_id,
      binding.parameters,
      span,
    ),
    return_type: binding.return_type,
    effect: @binding.no_raise(),
    aliases: [],
    intrinsic: None,
    is_public: true,
    span,
  }
  index.builtin_functions.push(signature)
  add_function_indexes(index, signature)
  add_impl_method_function_index(index, function_id)
  let evidence : ImplEvidence = {
    evidence_id: "derived-impl:" +
    binding.trait_symbol.id +
    ":" +
    @binding.type_name(self_type),
    trait_ref: { trait_: binding.trait_symbol, args: [] },
    self_type,
    type_args: [],
    source: ImplEvidenceSource::ConcreteImpl("derive"),
  }
  let method_body = ImplMethodBody::DefaultMethod
  add_or_merge_impl(index, {
    impl_id: evidence.evidence_id,
    trait_ref: evidence.trait_ref,
    self_type,
    methods: [
      {
        method_id,
        name: binding.method_name,
        function_id,
        body: method_body,
        span,
      },
    ],
    source: evidence.source,
    span,
  })
  add_operator_impl(
    index,
    key,
    self_type,
    { signature, evidence, method_body },
    span,
  )
}

///|
fn add_trait_impl_method_with_type_param_constraints(
  index : DeclarationIndex,
  trait_name : String,
  self_type : TypeRef,
  type_params : Array[@binding.TypeParamConstraint],
  method_name : String,
  body : ImplMethodBody,
  span : SourceSpan,
) -> Unit {
  match find_visible_trait(index, None, trait_name) {
    Some(trait_def) =>
      match find_trait_method_signature(trait_def, method_name) {
        Some(trait_method) => {
          let function_id = match body {
            ImplMethodBody::Function(id) =>
              if id.length() == 0 {
                impl_method_function_id_for(
                  index,
                  trait_def.symbol,
                  self_type,
                  method_name,
                )
              } else {
                id
              }
            ImplMethodBody::DefaultMethod =>
              default_trait_method_function_id(trait_def.symbol.id, method_name)
            _ =>
              impl_method_function_id_for(
                index,
                trait_def.symbol,
                self_type,
                method_name,
              )
          }
          let method_body = match body {
            ImplMethodBody::Function(id) =>
              if id.length() == 0 {
                ImplMethodBody::Function(function_id)
              } else {
                body
              }
            _ => body
          }
          let parameters = impl_method_parameters(
            function_id,
            trait_method.parameters,
            self_type,
            span,
          )
          let return_type = substitute_impl_self_type(
            trait_method.return_type,
            self_type,
          )
          ignore(
            declare_impl_method_signature_with_types(
              index, function_id, method_name, type_params, parameters, return_type,
              span,
            ),
          )
          let evidence : ImplEvidence = {
            evidence_id: "impl:" +
            trait_def.symbol.id +
            ":" +
            @binding.type_name(self_type),
            trait_ref: { trait_: trait_def.symbol, args: [] },
            self_type,
            type_args: [],
            source: ImplEvidenceSource::BuiltinImpl(
              "core:builtin:" + trait_def.symbol.name,
            ),
          }
          let methods : Array[ImplMethodSignature] = [
            {
              method_id: trait_method.method_id,
              name: method_name,
              function_id,
              body: method_body,
              span,
            },
          ]
          add_default_trait_methods(
            index, trait_def, self_type, method_name, span, methods,
          )
          add_or_merge_impl(index, {
            impl_id: evidence.evidence_id,
            trait_ref: evidence.trait_ref,
            self_type,
            methods,
            source: evidence.source,
            span,
          })
          declare_default_operator_methods_for_trait(
            index, trait_def, self_type, evidence, method_name, span,
          )
        }
        None =>
          index.error(
            "VNX2202",
            "impl method is not declared by trait: " + method_name,
            span,
          )
      }
    None => index.error("VNX2201", "unknown trait in impl: " + trait_name, span)
  }
}

///|
fn add_default_trait_methods(
  index : DeclarationIndex,
  trait_def : TraitDefinition,
  self_type : TypeRef,
  implemented_method_name : String,
  span : SourceSpan,
  methods : Array[ImplMethodSignature],
) -> Unit {
  for trait_method in trait_def.methods {
    if trait_method.name == implemented_method_name || !trait_method.has_default {
      continue
    }
    if impl_method_list_has_name(methods, trait_method.name) {
      continue
    }
    if impl_index_has_concrete_method(
        index,
        trait_def.symbol.id,
        self_type,
        trait_method.name,
      ) {
      continue
    }
    let function_id = match trait_method.default_function_id {
      Some(id) => id
      None =>
        default_trait_method_function_id(trait_def.symbol.id, trait_method.name)
    }
    if trait_method.default_function_id is None {
      ensure_default_trait_method_signature(
        index, trait_def, trait_method, function_id, span,
      )
    }
    methods.push({
      method_id: trait_method.method_id,
      name: trait_method.name,
      function_id,
      body: ImplMethodBody::DefaultMethod,
      span,
    })
  }
}

///|
fn declare_impl_method_signature(
  index : DeclarationIndex,
  self_type : TypeRef,
  trait_method : TraitMethodSignature,
  function_id : String,
  span : SourceSpan,
) -> FunctionSignature {
  declare_impl_method_signature_with_types(
    index,
    function_id,
    trait_method.name,
    [],
    impl_method_parameters(
      function_id,
      trait_method.parameters,
      self_type,
      span,
    ),
    substitute_impl_self_type(trait_method.return_type, self_type),
    span,
  )
}

///|
fn declare_impl_method_signature_with_types(
  index : DeclarationIndex,
  function_id : String,
  method_name : String,
  type_params : Array[@binding.TypeParamConstraint],
  parameters : Array[ParameterDef],
  return_type : TypeRef,
  span : SourceSpan,
) -> FunctionSignature {
  match find_function(index, function_id) {
    Some(existing) => return existing
    None => ()
  }
  let signature : FunctionSignature = {
    function_id,
    package_id: index.package_id,
    module_path: index.module_name,
    name: method_name,
    receiver_type: None,
    type_params,
    parameters,
    return_type,
    effect: @binding.no_raise(),
    aliases: [],
    intrinsic: None,
    is_public: true,
    span,
  }
  index.builtin_functions.push(signature)
  add_function_indexes(index, signature)
  add_impl_method_function_index(index, function_id)
  signature
}

///|
fn declare_default_operator_methods_for_trait(
  index : DeclarationIndex,
  trait_def : TraitDefinition,
  self_type : TypeRef,
  evidence : ImplEvidence,
  implemented_method_name : String,
  span : SourceSpan,
) -> Unit {
  for trait_method in trait_def.methods {
    if trait_method.name == implemented_method_name || !trait_method.has_default {
      continue
    }
    match
      operator_key_from_trait_method(trait_def.symbol.name, trait_method.name) {
      Some(key) => {
        let function_id = default_trait_method_function_id(
          trait_def.symbol.id,
          trait_method.name,
        )
        ensure_default_trait_method_signature(
          index, trait_def, trait_method, function_id, span,
        )
        let signature = match find_function(index, function_id) {
          Some(existing) => existing
          None => return
        }
        add_operator_impl(
          index,
          key,
          self_type,
          { signature, evidence, method_body: ImplMethodBody::DefaultMethod },
          span,
        )
      }
      None => ()
    }
  }
}

///|
fn add_or_merge_impl(index : DeclarationIndex, impl_ : ImplDefinition) -> Unit {
  match index.impl_slot_by_id.get(impl_.impl_id) {
    Some(i) => {
      for impl_method in impl_.methods {
        merge_impl_method(index.impls[i].methods, impl_method)
        add_impl_method_slot_index(index, impl_method.name, i)
      }
      return
    }
    None => ()
  }
  index.impls.push(impl_)
  let slot = index.impls.length() - 1
  index.impl_slot_by_id[impl_.impl_id] = slot
  add_impl_slot_indexes(index, slot)
}

///|
fn merge_impl_method(
  methods : Array[ImplMethodSignature],
  impl_method : ImplMethodSignature,
) -> Unit {
  for i in 0..<methods.length() {
    if methods[i].name != impl_method.name {
      continue
    }
    if methods[i].function_id == impl_method.function_id {
      if should_replace_impl_method_body(methods[i].body, impl_method.body) {
        methods[i] = impl_method
      }
      return
    }
    if methods[i].body is ImplMethodBody::DefaultMethod &&
      !(impl_method.body is ImplMethodBody::DefaultMethod) {
      methods[i] = impl_method
      return
    }
    if !(methods[i].body is ImplMethodBody::DefaultMethod) &&
      impl_method.body is ImplMethodBody::DefaultMethod {
      return
    }
  }
  methods.push(impl_method)
}

///|
fn impl_method_list_has_name(
  methods : Array[ImplMethodSignature],
  method_name : String,
) -> Bool {
  for impl_method in methods {
    if impl_method.name == method_name {
      return true
    }
  }
  false
}

///|
fn impl_index_has_concrete_method(
  index : DeclarationIndex,
  trait_id : String,
  self_type : TypeRef,
  method_name : String,
) -> Bool {
  for impl_def in find_impls_by_trait_self(index, trait_id, self_type) {
    for impl_method in impl_def.methods {
      if impl_method.name == method_name &&
        !(impl_method.body is ImplMethodBody::DefaultMethod) {
        return true
      }
    }
  }
  false
}

///|
fn should_replace_impl_method_body(
  existing : ImplMethodBody,
  incoming : ImplMethodBody,
) -> Bool {
  match (existing, incoming) {
    (ImplMethodBody::Intrinsic(_), _) => false
    (_, ImplMethodBody::Intrinsic(_)) => true
    (ImplMethodBody::DefaultMethod, _) => true
    _ => false
  }
}

///|
fn split_qualified_trait_name(name : String) -> (String?, String) {
  for i in 0..<name.length() {
    if name[i] == '.' {
      return (Some(name[0:i].to_owned()), name[i + 1:].to_owned())
    }
  }
  (None, name)
}

///|
fn find_trait_method_signature(
  trait_def : TraitDefinition,
  method_name : String,
) -> TraitMethodSignature? {
  for trait_method in trait_def.methods {
    if trait_method.name == method_name {
      return Some(trait_method)
    }
  }
  None
}

///|
pub fn impl_method_function_id_for(
  index : DeclarationIndex,
  trait_symbol : TypeSymbolRef,
  self_type : TypeRef,
  method_name : String,
) -> String {
  @binding.function_id(
    index.package_id,
    index.module_name,
    "impl:" +
    impl_type_symbol_key(index, trait_symbol) +
    ":" +
    impl_type_ref_key(index, self_type) +
    ":" +
    method_name,
  )
}

///|
fn impl_type_symbol_key(
  index : DeclarationIndex,
  symbol : TypeSymbolRef,
) -> String {
  if symbol.package_id == index.package_id {
    symbol.name
  } else {
    package_key(symbol.package_id) + ":" + symbol.name
  }
}

///|
fn impl_type_ref_key(index : DeclarationIndex, type_ : TypeRef) -> String {
  match type_ {
    TypeRef::Builtin(name) => name
    TypeRef::Declared(symbol, args) =>
      impl_type_symbol_key(index, symbol) + impl_type_args_key(index, args)
    TypeRef::TypeParameter(name, _) => name
    TypeRef::Apply(ctor, args) =>
      impl_type_constructor_key(index, ctor) + impl_type_args_key(index, args)
    TypeRef::Tuple(items) => "Tuple" + impl_type_args_key(index, items)
    TypeRef::Function(_, _, _) => "Function"
    TypeRef::TraitObject(trait_ref) =>
      "trait:" +
      impl_type_symbol_key(index, trait_ref.trait_) +
      impl_type_args_key(index, trait_ref.args)
    TypeRef::Unknown(reason) => "unknown:" + reason
    TypeRef::Error(reason) => "error:" + reason
  }
}

///|
fn impl_type_constructor_key(
  index : DeclarationIndex,
  ctor : TypeConstructorRef,
) -> String {
  match ctor {
    TypeConstructorRef::Builtin(name) => name
    TypeConstructorRef::Declared(symbol) => impl_type_symbol_key(index, symbol)
    TypeConstructorRef::TypeParameter(name, _) => name
  }
}

///|
fn impl_type_args_key(
  index : DeclarationIndex,
  args : FixedArray[TypeRef],
) -> String {
  if args.length() == 0 {
    return ""
  }
  let mut text = "["
  for i in 0..<args.length() {
    if i > 0 {
      text = text + ","
    }
    text = text + impl_type_ref_key(index, args[i])
  }
  text + "]"
}

///|
fn package_key(package_id : String) -> String {
  if package_id.has_prefix("pkg:") {
    package_id[4:].to_owned()
  } else {
    package_id
  }
}

///|
fn impl_method_parameters(
  function_id : String,
  parameters : Array[ParamTypeRef],
  self_type : TypeRef,
  span : SourceSpan,
) -> Array[ParameterDef] {
  let result : Array[ParameterDef] = []
  for i in 0..<parameters.length() {
    result.push(
      builtin_operator_parameter(
        function_id,
        if i == 0 {
          "self"
        } else {
          "arg" + i.to_string()
        },
        substitute_impl_self_type(parameters[i].type_, self_type),
        span,
      ),
    )
  }
  result
}

///|
fn add_operator_trait_impl_method(
  index : DeclarationIndex,
  key : OperatorKey,
  self_type : TypeRef,
  type_params : Array[String],
  method_name : String,
  body : ImplMethodBody,
  span : SourceSpan,
) -> Unit {
  let binding = operator_trait_binding(key, self_type)
  let trait_def = operator_trait_definition_or_fallback(
    index, binding, method_name, span,
  )
  guard find_trait_method_signature(trait_def, method_name)
    is Some(trait_method) else {
    index.error(
      "VNX2202",
      "impl method is not declared by trait: " + method_name,
      span,
    )
    return
  }
  let method_id = trait_method.method_id
  let function_id = impl_method_function_id_for(
    index,
    binding.trait_symbol,
    self_type,
    method_name,
  )
  let method_body = match body {
    ImplMethodBody::Function(id) =>
      if id.length() == 0 {
        ImplMethodBody::Function(function_id)
      } else {
        body
      }
    _ => body
  }
  let signature : FunctionSignature = {
    function_id,
    package_id: index.package_id,
    module_path: index.module_name,
    name: method_name,
    receiver_type: None,
    type_params: type_param_constraints_from_names(type_params),
    parameters: impl_method_parameters(
      function_id,
      trait_method.parameters,
      self_type,
      span,
    ),
    return_type: substitute_impl_self_type(trait_method.return_type, self_type),
    effect: @binding.no_raise(),
    aliases: [],
    intrinsic: None,
    is_public: true,
    span,
  }
  index.builtin_functions.push(signature)
  add_function_indexes(index, signature)
  add_impl_method_function_index(index, function_id)
  let evidence : ImplEvidence = {
    evidence_id: "impl:" +
    binding.trait_symbol.id +
    ":" +
    @binding.type_name(self_type),
    trait_ref: { trait_: binding.trait_symbol, args: [] },
    self_type,
    type_args: [],
    source: ImplEvidenceSource::BuiltinImpl(
      "core:builtin:" + trait_def.symbol.name,
    ),
  }
  let methods : Array[ImplMethodSignature] = [
    { method_id, name: method_name, function_id, body: method_body, span },
  ]
  add_default_trait_methods(
    index, trait_def, self_type, method_name, span, methods,
  )
  add_or_merge_impl(index, {
    impl_id: evidence.evidence_id,
    trait_ref: evidence.trait_ref,
    self_type,
    methods,
    source: evidence.source,
    span,
  })
  add_operator_impl(
    index,
    key,
    self_type,
    { signature, evidence, method_body },
    span,
  )
  declare_default_operator_methods_for_trait(
    index, trait_def, self_type, evidence, method_name, span,
  )
}

///|
fn operator_trait_definition_or_fallback(
  index : DeclarationIndex,
  binding : OperatorTraitBinding,
  method_name : String,
  span : SourceSpan,
) -> TraitDefinition {
  match find_trait_by_id(index, binding.trait_symbol.id) {
    Some(trait_def) => trait_def
    None => {
      let method_id = "trait-method:" +
        binding.trait_symbol.id +
        ":" +
        binding.method_name
      let trait_def : TraitDefinition = {
        symbol: binding.trait_symbol,
        type_params: [],
        methods: [
          {
            method_id,
            name: method_name,
            parameters: binding.parameters,
            return_type: binding.return_type,
            has_default: false,
            default_function_id: None,
            span,
          },
        ],
        span,
      }
      declare_trait(index, trait_def)
      trait_def
    }
  }
}

///|
fn add_operator_impl(
  index : DeclarationIndex,
  key : OperatorKey,
  self_type : TypeRef,
  candidate : OperatorCandidate,
  span : SourceSpan,
) -> Unit {
  for i in 0..<index.operator_impls.length() {
    let entry = index.operator_impls[i]
    if entry.key == key && @binding.type_equal(entry.self_type, self_type) {
      if same_operator_candidate(entry.candidate, candidate) {
        return
      }
      if same_operator_impl_identity(entry.candidate, candidate) {
        if impl_method_body_rank(candidate.method_body) >
          impl_method_body_rank(entry.candidate.method_body) {
          index.operator_impls[i] = { key, self_type, candidate }
          index.operator_impls_by_key[operator_impl_lookup_key(key, self_type)] = candidate
        }
        return
      }
      if entry.candidate.evidence.evidence_id == candidate.evidence.evidence_id {
        if impl_method_body_rank(candidate.method_body) >=
          impl_method_body_rank(entry.candidate.method_body) {
          index.operator_impls[i] = { key, self_type, candidate }
          index.operator_impls_by_key[operator_impl_lookup_key(key, self_type)] = candidate
        }
        return
      }
      if candidate.method_body is ImplMethodBody::DefaultMethod {
        return
      }
      if entry.candidate.method_body is ImplMethodBody::DefaultMethod {
        index.operator_impls[i] = { key, self_type, candidate }
        index.operator_impls_by_key[operator_impl_lookup_key(key, self_type)] = candidate
        return
      }
      index.error("VNX2200", "duplicate operator implementation", span)
      return
    }
  }
  index.operator_impls.push({ key, self_type, candidate })
  index.operator_impls_by_key[operator_impl_lookup_key(key, self_type)] = candidate
}

///|
fn same_operator_impl_identity(
  left : OperatorCandidate,
  right : OperatorCandidate,
) -> Bool {
  left.signature.function_id == right.signature.function_id &&
  left.evidence.evidence_id == right.evidence.evidence_id
}

///|
fn same_operator_candidate(
  left : OperatorCandidate,
  right : OperatorCandidate,
) -> Bool {
  left.signature.function_id == right.signature.function_id &&
  left.evidence.evidence_id == right.evidence.evidence_id &&
  left.method_body == right.method_body
}

///|
pub fn operator_trait_binding(
  key : OperatorKey,
  self_type : TypeRef,
) -> OperatorTraitBinding {
  let package_id = "pkg:moonbitlang/core/builtin"
  let module_path = "moonbitlang/core/builtin"
  let (trait_name, method_name) = match key.kind {
    OperatorKind::Add => ("Add", "add")
    OperatorKind::Sub => ("Sub", "sub")
    OperatorKind::Mul => ("Mul", "mul")
    OperatorKind::Div => ("Div", "div")
    OperatorKind::Neg => ("Neg", "neg")
    OperatorKind::Mod => ("Mod", "mod")
    OperatorKind::BitAnd => ("BitAnd", "land")
    OperatorKind::BitOr => ("BitOr", "lor")
    OperatorKind::BitXOr => ("BitXOr", "lxor")
    OperatorKind::Shl => ("Shl", "shl")
    OperatorKind::Shr => ("Shr", "shr")
    OperatorKind::Equal => ("Eq", "equal")
    OperatorKind::NotEqual => ("Eq", "not_equal")
    OperatorKind::Less => ("Compare", "op_lt")
    OperatorKind::Greater => ("Compare", "op_gt")
    OperatorKind::LessEqual => ("Compare", "op_le")
    OperatorKind::GreaterEqual => ("Compare", "op_ge")
  }
  let parameters = operator_parameters(key, self_type)
  {
    trait_symbol: @binding.make_type_symbol(package_id, module_path, trait_name),
    method_name,
    parameters,
    return_type: operator_return_type(key, self_type),
  }
}

///|
fn operator_key_from_trait_method(
  trait_name : String,
  method_name : String,
) -> OperatorKey? {
  match (trait_name, method_name) {
    ("Neg", "neg") => Some(unary_neg_operator_key())
    ("Add", "add") => Some(arithmetic_operator_key(OperatorKind::Add))
    ("Sub", "sub") => Some(arithmetic_operator_key(OperatorKind::Sub))
    ("Mul", "mul") => Some(arithmetic_operator_key(OperatorKind::Mul))
    ("Div", "div") => Some(arithmetic_operator_key(OperatorKind::Div))
    ("Mod", "mod") => Some(arithmetic_operator_key(OperatorKind::Mod))
    ("BitAnd", "land") => Some(bitwise_operator_key(OperatorKind::BitAnd))
    ("BitOr", "lor") => Some(bitwise_operator_key(OperatorKind::BitOr))
    ("BitXOr", "lxor") => Some(bitwise_operator_key(OperatorKind::BitXOr))
    ("Shl", "shl") => Some(bitwise_operator_key(OperatorKind::Shl))
    ("Shr", "shr") => Some(bitwise_operator_key(OperatorKind::Shr))
    ("Eq", "equal") => Some(equality_operator_key(OperatorKind::Equal))
    ("Eq", "not_equal") => Some(equality_operator_key(OperatorKind::NotEqual))
    ("Compare", "op_lt") => Some(comparison_operator_key(OperatorKind::Less))
    ("Compare", "op_gt") => Some(comparison_operator_key(OperatorKind::Greater))
    ("Compare", "op_le") =>
      Some(comparison_operator_key(OperatorKind::LessEqual))
    ("Compare", "op_ge") =>
      Some(comparison_operator_key(OperatorKind::GreaterEqual))
    _ => None
  }
}

///|
fn builtin_operator_parameters(
  function_id : String,
  parameters : Array[ParamTypeRef],
  span : SourceSpan,
) -> Array[ParameterDef] {
  let result : Array[ParameterDef] = []
  for i in 0..<parameters.length() {
    result.push(
      builtin_operator_parameter(
        function_id,
        if i == 0 {
          "left"
        } else {
          "right"
        },
        parameters[i].type_,
        span,
      ),
    )
  }
  result
}

///|
fn builtin_operator_parameter(
  function_id : String,
  name : String,
  type_ : TypeRef,
  span : SourceSpan,
) -> ParameterDef {
  {
    symbol: {
      id: @binding.parameter_id(function_id, name),
      kind: @binding.SymbolKind::Parameter,
      name,
      type_,
      span,
    },
    label: None,
    optional: false,
    has_default: false,
    default_ref: None,
    argument_type: type_,
  }
}

///|
fn arithmetic_operator_key(kind : OperatorKind) -> OperatorKey {
  { kind, arity: OperatorArity::Binary, family: OperatorFamily::Arithmetic }
}

///|
fn unary_neg_operator_key() -> OperatorKey {
  {
    kind: OperatorKind::Neg,
    arity: OperatorArity::Unary,
    family: OperatorFamily::Arithmetic,
  }
}

///|
fn bitwise_operator_key(kind : OperatorKind) -> OperatorKey {
  { kind, arity: OperatorArity::Binary, family: OperatorFamily::Bitwise }
}

///|
fn equality_operator_key(kind : OperatorKind) -> OperatorKey {
  { kind, arity: OperatorArity::Binary, family: OperatorFamily::Equality }
}

///|
fn comparison_operator_key(kind : OperatorKind) -> OperatorKey {
  { kind, arity: OperatorArity::Binary, family: OperatorFamily::Comparison }
}

///|
fn operator_parameters(
  key : OperatorKey,
  self_type : TypeRef,
) -> Array[ParamTypeRef] {
  match key.arity {
    OperatorArity::Unary =>
      [{ label: None, type_: self_type, optional: false, has_default: false }]
    OperatorArity::Binary => {
      let right_type = match key.kind {
        OperatorKind::Shl | OperatorKind::Shr => @binding.int_type()
        _ => self_type
      }
      [
        { label: None, type_: self_type, optional: false, has_default: false },
        { label: None, type_: right_type, optional: false, has_default: false },
      ]
    }
  }
}

///|
fn operator_return_type(key : OperatorKey, self_type : TypeRef) -> TypeRef {
  match key.family {
    OperatorFamily::Equality | OperatorFamily::Comparison =>
      @binding.bool_type()
    _ => self_type
  }
}

///|
fn substitute_impl_self_type(type_ : TypeRef, self_type : TypeRef) -> TypeRef {
  match type_ {
    TypeRef::Builtin("Self") => self_type
    TypeRef::Tuple(items) => {
      let result = FixedArray::make(items.length(), @binding.unresolved_type_ref())
      for i in 0..<items.length() {
        result[i] = substitute_impl_self_type(items[i], self_type)
      }
      TypeRef::Tuple(result)
    }
    TypeRef::Function(params, return_type, effect) => {
      let result : Array[ParamTypeRef] = []
      for param in params {
        result.push({
          label: param.label,
          type_: substitute_impl_self_type(param.type_, self_type),
          optional: param.optional,
          has_default: param.has_default,
        })
      }
      TypeRef::Function(
        result,
        substitute_impl_self_type(return_type, self_type),
        effect,
      )
    }
    TypeRef::Apply(type_constructor, args) => {
      let result = FixedArray::make(args.length(), @binding.unresolved_type_ref())
      for i in 0..<args.length() {
        result[i] = substitute_impl_self_type(args[i], self_type)
      }
      TypeRef::Apply(type_constructor, result)
    }
    TypeRef::Declared(symbol, args) => {
      let result = FixedArray::make(args.length(), @binding.unresolved_type_ref())
      for i in 0..<args.length() {
        result[i] = substitute_impl_self_type(args[i], self_type)
      }
      TypeRef::Declared(symbol, result)
    }
    TypeRef::TraitObject(trait_ref) => {
      let result = FixedArray::make(trait_ref.args.length(), @binding.unresolved_type_ref())
      for i in 0..<trait_ref.args.length() {
        result[i] = substitute_impl_self_type(trait_ref.args[i], self_type)
      }
      TypeRef::TraitObject({ trait_: trait_ref.trait_, args: result })
    }
    _ => type_
  }
}

///|
pub fn add_imported_functions(
  index : DeclarationIndex,
  imported_functions : Array[FunctionSignature],
) -> Unit {
  for function in imported_functions {
    match index.functions_by_id.get(function.function_id) {
      Some(existing) =>
        if function_signature_rank(function) > function_signature_rank(existing) {
          replace_function_signature(index.imported_functions, function)
          replace_function_indexes(index, existing, function)
        }
      None => {
        index.imported_functions.push(function)
        add_function_indexes(index, function)
      }
    }
  }
}

///|
pub fn add_imported_globals(
  index : DeclarationIndex,
  imported_globals : Array[GlobalSignature],
) -> Unit {
  for global in imported_globals {
    index.imported_globals.push(global)
  }
}

///|
pub fn add_imported_traits(
  index : DeclarationIndex,
  imported_traits : Array[TraitDefinition],
) -> Unit {
  for trait_def in imported_traits {
    declare_trait(index, trait_def)
  }
}

///|
pub fn add_imported_impls(
  index : DeclarationIndex,
  imported_impls : Array[ImplDefinition],
) -> Unit {
  for impl_ in imported_impls {
    add_imported_impl(index, impl_)
  }
}

///|
fn add_imported_impl(index : DeclarationIndex, impl_ : ImplDefinition) -> Unit {
  let mut existing_index = match index.impl_slot_by_id.get(impl_.impl_id) {
    Some(slot) => slot
    None => -1
  }
  if existing_index < 0 {
    index.impls.push({
      impl_id: impl_.impl_id,
      trait_ref: impl_.trait_ref,
      self_type: impl_.self_type,
      methods: [],
      source: impl_.source,
      span: impl_.span,
    })
    existing_index = index.impls.length() - 1
    index.impl_slot_by_id[impl_.impl_id] = existing_index
    add_impl_slot_indexes(index, existing_index)
  }
  for impl_method in impl_.methods {
    merge_impl_method(index.impls[existing_index].methods, impl_method)
    add_impl_method_slot_index(index, impl_method.name, existing_index)
    add_impl_method_function_index(index, impl_method.function_id)
    add_imported_operator_impl(index, impl_, impl_method)
  }
}

///|
fn add_imported_operator_impl(
  index : DeclarationIndex,
  impl_ : ImplDefinition,
  impl_method : ImplMethodSignature,
) -> Unit {
  guard find_trait_by_id(index, impl_.trait_ref.trait_.id) is Some(trait_def) else {
    return
  }
  guard operator_key_from_trait_method(trait_def.symbol.name, impl_method.name)
    is Some(key) else {
    return
  }
  guard find_function(index, impl_method.function_id) is Some(signature) else {
    return
  }
  add_operator_impl(
    index,
    key,
    impl_.self_type,
    {
      signature,
      evidence: {
        evidence_id: impl_.impl_id,
        trait_ref: impl_.trait_ref,
        self_type: impl_.self_type,
        type_args: [],
        source: impl_.source,
      },
      method_body: impl_method.body,
    },
    impl_.span,
  )
}

///|
pub fn add_using_item(index : DeclarationIndex, item : UsingItem) -> Unit {
  index.using_items.push(item)
}

///|
pub fn resolve_import_alias(
  index : DeclarationIndex,
  alias_name : String,
) -> String? {
  imported_package_id(index, alias_name)
}

///|
pub fn declare_type_header(
  index : DeclarationIndex,
  symbol : TypeSymbolRef,
  type_params : FixedArray[String],
  span : SourceSpan,
) -> Unit {
  match find_visible_type_header(index, None, symbol.name) {
    Some(existing) =>
      if existing.symbol.package_id == symbol.package_id {
        if same_type_header(existing, symbol, type_params, span) {
          return
        } else {
          index.error(
            "VNX2000",
            "duplicate type declaration: " + symbol.name,
            span,
          )
        }
      } else {
        index.type_headers.push({ symbol, type_params, span })
      }
    None => index.type_headers.push({ symbol, type_params, span })
  }
}

///|
fn same_type_header(
  existing : TypeHeader,
  symbol : TypeSymbolRef,
  type_params : FixedArray[String],
  span : SourceSpan,
) -> Bool {
  existing.symbol.id == symbol.id &&
  existing.span.file != span.file &&
  same_string_array(existing.type_params, type_params)
}

///|
fn same_string_array(left : FixedArray[String], right : FixedArray[String]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    if left[i] != right[i] {
      return false
    }
  }
  true
}

///|
pub fn define_type(index : DeclarationIndex, def : TypeDefinition) -> Unit {
  index.type_definitions.push(def)
}

///|
pub fn declare_function(
  index : DeclarationIndex,
  signature : FunctionSignature,
) -> Unit {
  match index.functions_by_name.get(signature.name) {
    Some(existing_functions) =>
      for existing in existing_functions {
        if existing.package_id == signature.package_id &&
          existing.name == signature.name &&
          existing.parameters.length() == signature.parameters.length() {
          if same_function_signature(existing, signature) {
            return
          }
          if interface_source_duplicate(existing, signature) {
            return
          }
          index.error(
            "VNX2001",
            "duplicate function declaration: " + signature.name,
            signature.span,
          )
          return
        }
      }
    None => ()
  }
  index.functions.push(signature)
  add_function_indexes(index, signature)
}

///|
fn interface_source_duplicate(
  left : FunctionSignature,
  right : FunctionSignature,
) -> Bool {
  (left.span.file.has_suffix(".mbti") || right.span.file.has_suffix(".mbti")) &&
  left.package_id == right.package_id &&
  left.name == right.name &&
  left.parameters.length() == right.parameters.length()
}

///|
fn same_function_signature(
  left : FunctionSignature,
  right : FunctionSignature,
) -> Bool {
  if left.package_id != right.package_id ||
    left.name != right.name ||
    left.parameters.length() != right.parameters.length() ||
    !optional_type_equal(left.receiver_type, right.receiver_type) ||
    !@binding.type_equal(left.return_type, right.return_type) {
    return false
  }
  for i in 0..<left.parameters.length() {
    if left.parameters[i].label != right.parameters[i].label ||
      left.parameters[i].optional != right.parameters[i].optional ||
      left.parameters[i].has_default != right.parameters[i].has_default ||
      !@binding.type_equal(
        left.parameters[i].argument_type,
        right.parameters[i].argument_type,
      ) {
      return false
    }
  }
  true
}

///|
fn optional_type_equal(left : TypeRef?, right : TypeRef?) -> Bool {
  match (left, right) {
    (None, None) => true
    (Some(a), Some(b)) => @binding.type_equal(a, b)
    _ => false
  }
}

///|
pub fn declare_global(index : DeclarationIndex, symbol : Symbol) -> Unit {
  match index.globals_by_name.get(symbol.name) {
    Some(existing) =>
      if existing.name == symbol.name {
        index.error(
          "VNX2002",
          "duplicate global declaration: " + symbol.name,
          symbol.span,
        )
        return
      }
    None => ()
  }
  index.globals.push(symbol)
  index.globals_by_name[symbol.name] = symbol
}

///|
pub fn declare_trait(
  index : DeclarationIndex,
  trait_def : TraitDefinition,
) -> Unit {
  match index.traits_by_id.get(trait_def.symbol.id) {
    Some(existing) => {
      if trait_definition_rank(trait_def) > trait_definition_rank(existing) {
        replace_trait_definition(index, trait_def)
      }
      return
    }
    None => ()
  }
  index.traits.push(trait_def)
  index.traits_by_id[trait_def.symbol.id] = trait_def
  add_trait_by_name(index, trait_def)
  for trait_method in trait_def.methods {
    add_trait_method_by_name(index, trait_def.symbol, trait_method)
  }
}

///|
fn replace_trait_definition(
  index : DeclarationIndex,
  trait_def : TraitDefinition,
) -> Unit {
  for i in 0..<index.traits.length() {
    if index.traits[i].symbol.id == trait_def.symbol.id {
      index.traits[i] = trait_def
      break
    }
  }
  index.traits_by_id[trait_def.symbol.id] = trait_def
  replace_trait_by_name(index, trait_def)
  for trait_method in trait_def.methods {
    add_trait_method_by_name(index, trait_def.symbol, trait_method)
  }
}

///|
fn trait_definition_rank(trait_def : TraitDefinition) -> Int {
  let mut rank = trait_def.methods.length() * 10
  for trait_method in trait_def.methods {
    rank = rank + type_ref_self_rank(trait_method.return_type)
    for parameter in trait_method.parameters {
      rank = rank + type_ref_self_rank(parameter.type_)
    }
  }
  rank
}

///|
fn type_ref_self_rank(type_ : TypeRef) -> Int {
  match type_ {
    TypeRef::Builtin(name) => if name == "Self" { 3 } else { 0 }
    TypeRef::Apply(_, args) => {
      let mut rank = 0
      for arg in args {
        rank = rank + type_ref_self_rank(arg)
      }
      rank
    }
    TypeRef::Function(params, return_type, _) => {
      let mut rank = type_ref_self_rank(return_type)
      for param in params {
        rank = rank + type_ref_self_rank(param.type_)
      }
      rank
    }
    TypeRef::Tuple(items) => {
      let mut rank = 0
      for item in items {
        rank = rank + type_ref_self_rank(item)
      }
      rank
    }
    TypeRef::TraitObject(ref_) => {
      let mut rank = 0
      for arg in ref_.args {
        rank = rank + type_ref_self_rank(arg)
      }
      rank
    }
    _ => 0
  }
}

///|
pub fn find_visible_type_header(
  index : DeclarationIndex,
  package_alias : String?,
  name : String,
) -> TypeHeader? {
  if package_alias is None {
    for header in index.type_headers {
      if header.symbol.package_id == index.package_id &&
        header.symbol.name == name {
        return Some(header)
      }
    }
  }
  for header in index.type_headers {
    let visible = match package_alias {
      Some(alias_name) =>
        imported_package_id(index, alias_name) == Some(header.symbol.package_id)
      None =>
        header.symbol.package_id == index.package_id ||
        core_prelude_type(header.symbol) ||
        type_is_imported_by_using(
          index,
          header.symbol.package_id,
          header.symbol.name,
        )
    }
    if visible && header.symbol.name == name {
      return Some(header)
    }
  }
  None
}

///|
pub fn find_visible_trait(
  index : DeclarationIndex,
  package_alias : String?,
  name : String,
) -> TraitDefinition? {
  match index.traits_by_name.get(name) {
    Some(traits) =>
      for trait_def in traits {
        if trait_is_visible(index, package_alias, trait_def.symbol) {
          return Some(trait_def)
        }
      }
    None => ()
  }
  None
}

///|
pub fn find_trait_by_id(
  index : DeclarationIndex,
  trait_id : String,
) -> TraitDefinition? {
  index.traits_by_id.get(trait_id)
}

///|
pub fn find_type_definition(
  index : DeclarationIndex,
  symbol_id : String,
) -> TypeDefinition? {
  for def in index.type_definitions {
    let (symbol, _) = @binding.type_definition_header(def)
    if symbol.id == symbol_id {
      return Some(def)
    }
  }
  None
}

///|
pub fn find_function(
  index : DeclarationIndex,
  function_id : String,
) -> FunctionSignature? {
  index.functions_by_id.get(function_id)
}

///|
pub fn find_functions_by_name(
  index : DeclarationIndex,
  name : String,
) -> Array[FunctionSignature] {
  let result : Array[FunctionSignature] = []
  let seen : @set.Set[String] = Set([])
  for function in index.functions {
    if function.name == name && function_visible_by_name(index, function) {
      push_visible_function_once(result, seen, function)
    }
  }
  for function in index.imported_functions {
    if function.name == name && function_visible_by_name(index, function) {
      push_visible_function_once(result, seen, function)
    }
  }
  for function in index.builtin_functions {
    if function.name == name && function_visible_by_name(index, function) {
      push_visible_function_once(result, seen, function)
    }
  }
  result
}

///|
fn push_visible_function_once(
  result : Array[FunctionSignature],
  seen : @set.Set[String],
  function : FunctionSignature,
) -> Unit {
  if set_try_add(seen, function.function_id) {
    result.push(function)
  }
}

///|
pub fn find_functions_by_alias(
  index : DeclarationIndex,
  alias_name : String,
) -> Array[FunctionSignature] {
  let result : Array[FunctionSignature] = []
  match index.functions_by_alias.get(alias_name) {
    Some(functions) =>
      for function in functions {
        if function_visible_by_name(index, function) {
          result.push(function)
        }
      }
    None => ()
  }
  result
}

///|
pub fn find_receiver_functions(
  index : DeclarationIndex,
  receiver_type : TypeRef,
  method_name : String,
) -> Array[FunctionSignature] {
  find_receiver_functions_with_mode(index, receiver_type, method_name, true)
}

///|
pub fn find_receiver_functions_exact(
  index : DeclarationIndex,
  receiver_type : TypeRef,
  method_name : String,
) -> Array[FunctionSignature] {
  find_receiver_functions_with_mode(index, receiver_type, method_name, false)
}

///|
fn find_receiver_functions_with_mode(
  index : DeclarationIndex,
  receiver_type : TypeRef,
  method_name : String,
  allow_receiver_conversion : Bool,
) -> Array[FunctionSignature] {
  let result : Array[FunctionSignature] = []
  match index.receiver_functions_by_method.get(method_name) {
    Some(functions) =>
      for function in functions {
        if receiver_function_visible(index, function) &&
          receiver_function_applies(
            function.receiver_type,
            receiver_type,
            allow_receiver_conversion,
          ) {
          result.push(function)
        }
      }
    None => ()
  }
  result
}

///|
pub fn find_static_receiver_functions(
  index : DeclarationIndex,
  receiver_name : String,
  member_name : String,
) -> Array[FunctionSignature] {
  let result : Array[FunctionSignature] = []
  match
    index.static_receiver_functions_by_key.get(
      static_receiver_lookup_key(receiver_name, member_name),
    ) {
    Some(functions) =>
      for function in functions {
        if receiver_function_visible(index, function) &&
          receiver_member_matches(function, member_name) {
          result.push(function)
        }
      }
    None => ()
  }
  result
}

///|
fn receiver_member_matches(
  function : FunctionSignature,
  member_name : String,
) -> Bool {
  receiver_method_name(function.name) == member_name ||
  function_has_alias(function, member_name)
}

///|
pub fn function_has_alias(
  function : FunctionSignature,
  alias_text : String,
) -> Bool {
  for item in function.aliases {
    if item == alias_text {
      return true
    }
  }
  false
}

///|
fn static_receiver_name(function_name : String) -> String {
  let mut result = ""
  for part in function_name.split("::") {
    result = part.to_owned()
    break
  }
  result
}

///|
fn static_receiver_lookup_key(
  receiver_name : String,
  member_name : String,
) -> String {
  receiver_name + "::" + member_name
}

///|
fn static_receiver_index_key(signature : FunctionSignature) -> String? {
  match signature.receiver_type {
    None => None
    Some(_) => {
      let type_name = static_receiver_name(signature.name)
      if type_name == signature.name {
        None
      } else {
        Some(
          static_receiver_lookup_key(
            type_name,
            receiver_method_name(signature.name),
          ),
        )
      }
    }
  }
}

///|
fn add_static_receiver_function_index(
  index : DeclarationIndex,
  key : String,
  signature : FunctionSignature,
) -> Unit {
  match index.static_receiver_functions_by_key.get(key) {
    Some(functions) => functions.push(signature)
    None => index.static_receiver_functions_by_key[key] = [signature]
  }
}

///|
fn add_static_receiver_alias_indexes(
  index : DeclarationIndex,
  signature : FunctionSignature,
) -> Unit {
  match signature.receiver_type {
    None => ()
    Some(_) => {
      let type_name = static_receiver_name(signature.name)
      if type_name == signature.name {
        return
      }
      let method_name = receiver_method_name(signature.name)
      for alias_name in signature.aliases {
        if alias_name != method_name {
          add_static_receiver_function_index(
            index,
            static_receiver_lookup_key(type_name, alias_name),
            signature,
          )
        }
      }
    }
  }
}

///|
fn function_visible(
  index : DeclarationIndex,
  function : FunctionSignature,
) -> Bool {
  function.package_id == index.package_id ||
  (
    function.is_public &&
    (
      core_prelude_function(function) ||
      function_is_imported_by_using(index, function)
    )
  )
}

///|
fn function_is_moon_pkg_imported(
  index : DeclarationIndex,
  function : FunctionSignature,
) -> Bool {
  for import_ref in index.imports {
    if import_ref.package_id == function.package_id {
      return true
    }
  }
  false
}

///|
fn receiver_function_visible(
  index : DeclarationIndex,
  function : FunctionSignature,
) -> Bool {
  function_visible(index, function) ||
  (
    function.is_public &&
    function.receiver_type is Some(_) &&
    function_is_moon_pkg_imported(index, function)
  )
}

///|
fn function_visible_by_name(
  index : DeclarationIndex,
  function : FunctionSignature,
) -> Bool {
  function_visible(index, function) &&
  !index.impl_method_function_ids.contains(function.function_id)
}

///|
fn core_prelude_function(function : FunctionSignature) -> Bool {
  core_prelude_package_id(function.package_id) &&
  function.function_id.has_prefix("fn:" + function.package_id + ":")
}

///|
fn core_prelude_type(symbol : TypeSymbolRef) -> Bool {
  core_prelude_package_id(symbol.package_id) &&
  symbol.id.has_prefix("type:" + symbol.package_id + ":")
}

///|
fn core_prelude_package_id(package_id : String) -> Bool {
  package_id == "pkg:moonbitlang/core/builtin" ||
  package_id == "pkg:moonbitlang/core/error" ||
  package_id == "pkg:moonbitlang/core/ref" ||
  package_id == "pkg:moonbitlang/core/debug" ||
  package_id == "pkg:moonbitlang/core/set"
}

///|
fn receiver_function_applies(
  candidate_receiver : TypeRef?,
  actual_receiver : TypeRef,
  allow_conversion : Bool,
) -> Bool {
  match candidate_receiver {
    Some(candidate) =>
      unresolved_inference_type(actual_receiver) ||
      receiver_type_shape_equal(candidate, actual_receiver) ||
      (
        allow_conversion &&
        classify_conversion(candidate, actual_receiver) !=
        ConversionKind::Incompatible
      )
    None => false
  }
}

///|
fn receiver_type_shape_equal(candidate : TypeRef, actual : TypeRef) -> Bool {
  match (candidate, actual) {
    (TypeRef::Builtin(a), TypeRef::Builtin(b)) => a == b
    (TypeRef::Declared(a, _), TypeRef::Declared(b, _)) => a.id == b.id
    (TypeRef::Apply(a, _), TypeRef::Apply(b, _)) =>
      receiver_constructor_equal(a, b)
    (
      TypeRef::Apply(TypeConstructorRef::Builtin(name), _),
      TypeRef::Declared(symbol, _),
    ) => @binding.is_core_builtin_type_symbol(symbol, name)
    (
      TypeRef::Declared(symbol, _),
      TypeRef::Apply(TypeConstructorRef::Builtin(name), _),
    ) => @binding.is_core_builtin_type_symbol(symbol, name)
    (TypeRef::TypeParameter(_, _), _) => true
    _ => @binding.type_equal(candidate, actual)
  }
}

///|
fn receiver_constructor_equal(
  left : TypeConstructorRef,
  right : TypeConstructorRef,
) -> Bool {
  match (left, right) {
    (TypeConstructorRef::Builtin(a), TypeConstructorRef::Builtin(b)) => a == b
    (TypeConstructorRef::Declared(a), TypeConstructorRef::Declared(b)) =>
      a.id == b.id
    (TypeConstructorRef::Declared(symbol), TypeConstructorRef::Builtin(name)) =>
      @binding.is_core_builtin_type_symbol(symbol, name)
    (TypeConstructorRef::Builtin(name), TypeConstructorRef::Declared(symbol)) =>
      @binding.is_core_builtin_type_symbol(symbol, name)
    (TypeConstructorRef::TypeParameter(_, _), _) => true
    (_, TypeConstructorRef::TypeParameter(_, _)) => true
  }
}

///|
pub fn find_functions_by_package_alias(
  index : DeclarationIndex,
  package_alias : String,
  name : String,
) -> Array[FunctionSignature] {
  let result : Array[FunctionSignature] = []
  match imported_package_id(index, package_alias) {
    Some(package_id) =>
      match index.functions_by_name.get(name) {
        Some(functions) =>
          for function in functions {
            if function.package_id == package_id && function.name == name {
              result.push(function)
            }
          }
        None => ()
      }
    None => ()
  }
  result
}

///|
pub fn find_global_by_name(index : DeclarationIndex, name : String) -> Symbol? {
  match index.globals_by_name.get(name) {
    Some(global) => return Some(global)
    None => ()
  }
  for global in index.imported_globals {
    if global.symbol.name == name && global_is_imported_by_using(index, global) {
      return Some(global.symbol)
    }
  }
  None
}

///|
pub fn find_trait_methods_by_name(
  index : DeclarationIndex,
  method_name : String,
) -> Array[TraitMethodLookupEntry] {
  match index.trait_methods_by_name.get(method_name) {
    Some(entries) => entries.copy()
    None => []
  }
}

///|
pub fn find_trait_method(
  index : DeclarationIndex,
  trait_id : String,
  method_name : String,
) -> TraitMethodLookupEntry? {
  index.trait_methods_by_key.get(trait_method_lookup_key(trait_id, method_name))
}

///|
pub fn find_impls_by_trait_self(
  index : DeclarationIndex,
  trait_id : String,
  self_type : TypeRef,
) -> Array[ImplDefinition] {
  let result : Array[ImplDefinition] = []
  match index.impl_indices_by_trait_id.get(trait_id) {
    Some(slots) =>
      for slot in slots {
        let impl_ = index.impls[slot]
        if @binding.type_equal(impl_.self_type, self_type) {
          result.push(impl_)
        }
      }
    None => ()
  }
  result
}

///|
pub fn find_impls_by_self_type(
  index : DeclarationIndex,
  self_type : TypeRef,
) -> Array[ImplDefinition] {
  let result : Array[ImplDefinition] = []
  match index.impl_indices_by_self_type_key.get(type_lookup_key(self_type)) {
    Some(slots) =>
      for slot in slots {
        let impl_ = index.impls[slot]
        if @binding.type_equal(impl_.self_type, self_type) {
          result.push(impl_)
        }
      }
    None => ()
  }
  result
}

///|
pub fn find_impls_by_method_name(
  index : DeclarationIndex,
  method_name : String,
) -> Array[ImplDefinition] {
  let result : Array[ImplDefinition] = []
  match index.impl_indices_by_method_name.get(method_name) {
    Some(slots) =>
      for slot in slots {
        result.push(index.impls[slot])
      }
    None => ()
  }
  result
}

///|
pub fn find_concrete_trait_method_candidate(
  index : DeclarationIndex,
  receiver_type : TypeRef,
  method_name : String,
  trait_id : String?,
) -> ConcreteTraitMethodCandidate? {
  let mut found : ConcreteTraitMethodCandidate? = None
  for impl_ in find_impls_by_method_name(index, method_name) {
    if trait_id is Some(expected_trait_id) &&
      impl_.trait_ref.trait_.id != expected_trait_id {
      continue
    }
    if receiver_type_shape_equal(impl_.self_type, receiver_type) {
      for impl_method in impl_.methods {
        if impl_method.name == method_name {
          match find_trait_by_id(index, impl_.trait_ref.trait_.id) {
            Some(trait_def) =>
              match find_trait_method_signature(trait_def, method_name) {
                Some(trait_method) =>
                  if found is Some(_) {
                    match found {
                      Some(existing) => {
                        let candidate = {
                          trait_ref: impl_.trait_ref,
                          trait_method,
                          impl_method,
                          evidence: {
                            evidence_id: impl_.impl_id,
                            trait_ref: impl_.trait_ref,
                            self_type: impl_.self_type,
                            type_args: [],
                            source: impl_.source,
                          },
                        }
                        if same_concrete_trait_method_candidate(
                            existing, candidate,
                          ) {
                          ()
                        } else if same_impl_trait_method_candidate(
                            existing, candidate,
                          ) {
                          if prefer_concrete_trait_method_candidate(
                              candidate, existing,
                            ) {
                            found = Some(candidate)
                          }
                        } else {
                          index.error(
                            "VNX2203",
                            "ambiguous concrete trait method: " + method_name,
                            impl_method.span,
                          )
                          return None
                        }
                      }
                      None => ()
                    }
                  } else {
                    found = Some({
                      trait_ref: impl_.trait_ref,
                      trait_method,
                      impl_method,
                      evidence: {
                        evidence_id: impl_.impl_id,
                        trait_ref: impl_.trait_ref,
                        self_type: impl_.self_type,
                        type_args: [],
                        source: impl_.source,
                      },
                    })
                  }
                None => ()
              }
            None => ()
          }
        }
      }
    }
  }
  found
}

///|
fn same_concrete_trait_method_candidate(
  left : ConcreteTraitMethodCandidate,
  right : ConcreteTraitMethodCandidate,
) -> Bool {
  left.trait_ref == right.trait_ref &&
  left.trait_method.method_id == right.trait_method.method_id &&
  left.impl_method.function_id == right.impl_method.function_id &&
  left.evidence.evidence_id == right.evidence.evidence_id
}

///|
fn same_impl_trait_method_candidate(
  left : ConcreteTraitMethodCandidate,
  right : ConcreteTraitMethodCandidate,
) -> Bool {
  left.trait_ref == right.trait_ref &&
  left.trait_method.method_id == right.trait_method.method_id &&
  left.evidence.evidence_id == right.evidence.evidence_id
}

///|
fn prefer_concrete_trait_method_candidate(
  candidate : ConcreteTraitMethodCandidate,
  existing : ConcreteTraitMethodCandidate,
) -> Bool {
  impl_method_body_rank(candidate.impl_method.body) >
  impl_method_body_rank(existing.impl_method.body)
}

///|
fn impl_method_body_rank(body : ImplMethodBody) -> Int {
  match body {
    ImplMethodBody::Intrinsic(_) => 3
    ImplMethodBody::Function(_) => 2
    ImplMethodBody::DefaultMethod => 1
  }
}

///|
pub fn find_global_by_package_alias(
  index : DeclarationIndex,
  package_alias : String,
  name : String,
) -> Symbol? {
  match imported_package_id(index, package_alias) {
    Some(package_id) =>
      for global in index.imported_globals {
        if global.package_id == package_id && global.symbol.name == name {
          return Some(global.symbol)
        }
      }
    None => ()
  }
  None
}

///|
fn type_is_imported_by_using(
  index : DeclarationIndex,
  package_id : String,
  name : String,
) -> Bool {
  for item in index.using_items {
    if item.kind == UsingItemKind::Type &&
      item.package_id == package_id &&
      item.name == name {
      return true
    }
  }
  false
}

///|
fn trait_is_imported_by_using(
  index : DeclarationIndex,
  package_id : String,
  name : String,
) -> Bool {
  for item in index.using_items {
    if item.kind == UsingItemKind::Type &&
      item.package_id == package_id &&
      item.name == name {
      return true
    }
  }
  false
}

///|
fn function_is_imported_by_using(
  index : DeclarationIndex,
  function : FunctionSignature,
) -> Bool {
  for item in index.using_items {
    if item.kind == UsingItemKind::Function &&
      function.package_id == item.package_id &&
      function.name == item.name {
      return true
    }
  }
  false
}

///|
fn global_is_imported_by_using(
  index : DeclarationIndex,
  global : GlobalSignature,
) -> Bool {
  for item in index.using_items {
    if item.kind == UsingItemKind::Global &&
      global.package_id == item.package_id &&
      global.symbol.name == item.name {
      return true
    }
  }
  false
}

///|
fn function_signature_rank(signature : FunctionSignature) -> Int {
  match signature.intrinsic {
    Some(_) => 2
    None => 1
  }
}

///|
fn replace_function_signature(
  items : Array[FunctionSignature],
  signature : FunctionSignature,
) -> Unit {
  for i in 0..<items.length() {
    if items[i].function_id == signature.function_id {
      items[i] = signature
      return
    }
  }
  items.push(signature)
}

///|
fn replace_indexed_function(
  items : Array[FunctionSignature],
  signature : FunctionSignature,
) -> Unit {
  for i in 0..<items.length() {
    if items[i].function_id == signature.function_id {
      items[i] = signature
      return
    }
  }
  items.push(signature)
}

///|
fn replace_function_map_entry(
  map : Map[String, Array[FunctionSignature]],
  key : String,
  signature : FunctionSignature,
) -> Unit {
  match map.get(key) {
    Some(items) => replace_indexed_function(items, signature)
    None => map[key] = [signature]
  }
}

///|
fn replace_function_indexes(
  index : DeclarationIndex,
  existing : FunctionSignature,
  signature : FunctionSignature,
) -> Unit {
  index.functions_by_id[signature.function_id] = signature
  replace_function_map_entry(index.functions_by_name, signature.name, signature)
  for alias_name in existing.aliases {
    replace_function_map_entry(index.functions_by_alias, alias_name, signature)
  }
  for alias_name in signature.aliases {
    replace_function_map_entry(index.functions_by_alias, alias_name, signature)
  }
  match existing.receiver_type {
    Some(_) =>
      replace_function_map_entry(
        index.receiver_functions_by_method,
        receiver_method_name(existing.name),
        signature,
      )
    None => ()
  }
  match static_receiver_index_key(existing) {
    Some(key) =>
      replace_function_map_entry(
        index.static_receiver_functions_by_key,
        key,
        signature,
      )
    None => ()
  }
  match signature.receiver_type {
    Some(_) => {
      let method_name = receiver_method_name(signature.name)
      replace_function_map_entry(
        index.receiver_functions_by_method,
        method_name,
        signature,
      )
      for alias_name in signature.aliases {
        if alias_name != method_name {
          replace_function_map_entry(
            index.receiver_functions_by_method,
            alias_name,
            signature,
          )
        }
      }
    }
    None => ()
  }
  match static_receiver_index_key(signature) {
    Some(key) =>
      replace_function_map_entry(
        index.static_receiver_functions_by_key,
        key,
        signature,
      )
    None => ()
  }
  add_static_receiver_alias_indexes(index, signature)
}

///|
fn add_function_indexes(
  index : DeclarationIndex,
  signature : FunctionSignature,
) -> Unit {
  index.functions_by_id[signature.function_id] = signature
  match index.functions_by_name.get(signature.name) {
    Some(functions) => functions.push(signature)
    None => index.functions_by_name[signature.name] = [signature]
  }
  for alias_name in signature.aliases {
    add_function_alias_index(index, alias_name, signature)
  }
  match signature.receiver_type {
    Some(_) => {
      let method_name = receiver_method_name(signature.name)
      add_receiver_function_index(index, method_name, signature)
      for alias_name in signature.aliases {
        if alias_name != method_name {
          add_receiver_function_index(index, alias_name, signature)
        }
      }
      match static_receiver_index_key(signature) {
        Some(key) => add_static_receiver_function_index(index, key, signature)
        None => ()
      }
      add_static_receiver_alias_indexes(index, signature)
    }
    None => ()
  }
}

///|
fn add_impl_method_function_index(
  index : DeclarationIndex,
  function_id : String,
) -> Unit {
  let before = index.impl_method_function_ids.length()
  index.impl_method_function_ids.add(function_id)
  ignore(index.impl_method_function_ids.length() != before)
}

///|
fn add_impl_slot_indexes(index : DeclarationIndex, slot : Int) -> Unit {
  let impl_ = index.impls[slot]
  add_impl_slot_index(
    index.impl_indices_by_trait_id,
    impl_.trait_ref.trait_.id,
    slot,
  )
  add_impl_slot_index(
    index.impl_indices_by_self_type_key,
    type_lookup_key(impl_.self_type),
    slot,
  )
  for impl_method in impl_.methods {
    add_impl_method_slot_index(index, impl_method.name, slot)
  }
}

///|
fn add_impl_method_slot_index(
  index : DeclarationIndex,
  method_name : String,
  slot : Int,
) -> Unit {
  add_impl_slot_index(index.impl_indices_by_method_name, method_name, slot)
}

///|
fn add_impl_slot_index(
  map : Map[String, Array[Int]],
  key : String,
  slot : Int,
) -> Unit {
  match map.get(key) {
    Some(slots) => {
      for existing in slots {
        if existing == slot {
          return
        }
      }
      slots.push(slot)
    }
    None => map[key] = [slot]
  }
}

///|
fn set_try_add(set : @set.Set[String], item : String) -> Bool {
  let before = set.length()
  set.add(item)
  set.length() != before
}

///|
fn add_function_alias_index(
  index : DeclarationIndex,
  alias_name : String,
  signature : FunctionSignature,
) -> Unit {
  match index.functions_by_alias.get(alias_name) {
    Some(functions) => functions.push(signature)
    None => index.functions_by_alias[alias_name] = [signature]
  }
}

///|
fn add_receiver_function_index(
  index : DeclarationIndex,
  method_name : String,
  signature : FunctionSignature,
) -> Unit {
  match index.receiver_functions_by_method.get(method_name) {
    Some(functions) => functions.push(signature)
    None => index.receiver_functions_by_method[method_name] = [signature]
  }
}

///|
fn receiver_method_name(function_name : String) -> String {
  let parts = function_name.split("::")
  let mut result = function_name
  for part in parts {
    result = part.to_owned()
  }
  result
}

///|
fn add_trait_by_name(
  index : DeclarationIndex,
  trait_def : TraitDefinition,
) -> Unit {
  match index.traits_by_name.get(trait_def.symbol.name) {
    Some(traits) => traits.push(trait_def)
    None => index.traits_by_name[trait_def.symbol.name] = [trait_def]
  }
}

///|
fn replace_trait_by_name(
  index : DeclarationIndex,
  trait_def : TraitDefinition,
) -> Unit {
  match index.traits_by_name.get(trait_def.symbol.name) {
    Some(traits) => {
      for i in 0..<traits.length() {
        if traits[i].symbol.id == trait_def.symbol.id {
          traits[i] = trait_def
          return
        }
      }
      traits.push(trait_def)
    }
    None => index.traits_by_name[trait_def.symbol.name] = [trait_def]
  }
}

///|
fn add_trait_method_by_name(
  index : DeclarationIndex,
  trait_symbol : TypeSymbolRef,
  trait_method : TraitMethodSignature,
) -> Unit {
  let entry = { trait_symbol, trait_method }
  index.trait_methods_by_key[trait_method_lookup_key(
    trait_symbol.id,
    trait_method.name,
  )] = entry
  match index.trait_methods_by_name.get(trait_method.name) {
    Some(entries) => entries.push(entry)
    None => index.trait_methods_by_name[trait_method.name] = [entry]
  }
}

///|
fn trait_method_lookup_key(trait_id : String, method_name : String) -> String {
  trait_id + ":" + method_name
}

///|
fn trait_is_visible(
  index : DeclarationIndex,
  package_alias : String?,
  symbol : TypeSymbolRef,
) -> Bool {
  match package_alias {
    Some(alias_name) =>
      imported_package_id(index, alias_name) == Some(symbol.package_id)
    None =>
      symbol.package_id == index.package_id ||
      core_prelude_trait(symbol) ||
      trait_is_imported_by_using(index, symbol.package_id, symbol.name)
  }
}

///|
fn core_prelude_trait(symbol : TypeSymbolRef) -> Bool {
  (
    symbol.package_id == "pkg:moonbitlang/core/builtin" &&
    symbol.id.has_prefix("type:pkg:moonbitlang/core/builtin:")
  ) ||
  (symbol.package_id == "pkg:moonbitlang/core/debug" && symbol.name == "Debug")
}

///|
fn operator_impl_lookup_key(key : OperatorKey, self_type : TypeRef) -> String {
  operator_key_text(key) + ":" + type_lookup_key(self_type)
}

///|
fn operator_key_text(key : OperatorKey) -> String {
  operator_family_text(key.family) +
  ":" +
  operator_arity_text(key.arity) +
  ":" +
  operator_kind_text(key.kind)
}

///|
fn operator_family_text(family : OperatorFamily) -> String {
  match family {
    OperatorFamily::Arithmetic => "arithmetic"
    OperatorFamily::Bitwise => "bitwise"
    OperatorFamily::Equality => "equality"
    OperatorFamily::Comparison => "comparison"
  }
}

///|
fn operator_arity_text(arity : OperatorArity) -> String {
  match arity {
    OperatorArity::Unary => "unary"
    OperatorArity::Binary => "binary"
  }
}

///|
fn operator_kind_text(kind : OperatorKind) -> String {
  match kind {
    OperatorKind::Add => "add"
    OperatorKind::Sub => "sub"
    OperatorKind::Mul => "mul"
    OperatorKind::Div => "div"
    OperatorKind::Neg => "neg"
    OperatorKind::Mod => "mod"
    OperatorKind::BitAnd => "bitand"
    OperatorKind::BitOr => "bitor"
    OperatorKind::BitXOr => "bitxor"
    OperatorKind::Shl => "shl"
    OperatorKind::Shr => "shr"
    OperatorKind::Equal => "equal"
    OperatorKind::NotEqual => "not_equal"
    OperatorKind::Less => "less"
    OperatorKind::Greater => "greater"
    OperatorKind::LessEqual => "less_equal"
    OperatorKind::GreaterEqual => "greater_equal"
  }
}

///|
fn type_lookup_key(type_ : TypeRef) -> String {
  match type_ {
    TypeRef::Builtin(name) => "builtin:" + name
    TypeRef::Declared(symbol, args) =>
      symbol.id + "[" + type_array_lookup_key(args) + "]"
    TypeRef::TypeParameter(name, symbol_id) =>
      "type-param:" + symbol_id + ":" + name
    TypeRef::Tuple(items) => "tuple:" + type_array_lookup_key(items)
    TypeRef::Function(params, return_type, effect) =>
      "fn:" +
      param_type_array_lookup_key(params) +
      "->" +
      type_lookup_key(return_type) +
      ":" +
      effect_lookup_key(effect)
    TypeRef::Apply(type_constructor, args) =>
      type_constructor_lookup_key(type_constructor) +
      "[" +
      type_array_lookup_key(args) +
      "]"
    TypeRef::TraitObject(trait_ref) =>
      "trait-object:" +
      trait_ref.trait_.id +
      "[" +
      type_array_lookup_key(trait_ref.args) +
      "]"
    TypeRef::Unknown(reason) => "unknown:" + reason
    TypeRef::Error(reason) => "error:" + reason
  }
}

///|
fn type_array_lookup_key(types : FixedArray[TypeRef]) -> String {
  let mut text = ""
  for i in 0..<types.length() {
    if i > 0 {
      text = text + ","
    }
    text = text + type_lookup_key(types[i])
  }
  text
}

///|
fn param_type_array_lookup_key(params : Array[ParamTypeRef]) -> String {
  let mut text = ""
  for i in 0..<params.length() {
    if i > 0 {
      text = text + ","
    }
    text = text + param_type_lookup_key(params[i])
  }
  text
}

///|
fn param_type_lookup_key(param : ParamTypeRef) -> String {
  let label = match param.label {
    Some(name) => name
    None => ""
  }
  label +
  ":" +
  type_lookup_key(param.type_) +
  ":" +
  param.optional.to_string() +
  ":" +
  param.has_default.to_string()
}

///|
fn type_constructor_lookup_key(type_constructor : TypeConstructorRef) -> String {
  match type_constructor {
    TypeConstructorRef::Builtin(name) => "builtin:" + name
    TypeConstructorRef::Declared(symbol) => "declared:" + symbol.id
    TypeConstructorRef::TypeParameter(name, symbol_id) =>
      "type-param:" + symbol_id + ":" + name
  }
}

///|
fn effect_lookup_key(effect : EffectRef) -> String {
  match effect {
    EffectRef::NoRaise => "noraise"
    EffectRef::Raises(type_) => "raises:" + type_lookup_key(type_)
    EffectRef::RaisePolymorphic(symbol_id) =>
      "raise-poly:" +
      (match symbol_id {
        Some(id) => id
        None => ""
      })
    EffectRef::UnknownEffect(reason) => "unknown:" + reason
  }
}

///|
pub fn selected_callable_from_signature(
  signature : FunctionSignature,
) -> SelectedCallable {
  {
    function_id: signature.function_id,
    receiver_type: None,
    type_args: [],
    parameters: signature.parameters,
    return_type: signature.return_type,
    effect: signature.effect,
    function_intrinsic: signature.intrinsic,
    trait_evidence: [],
    method_body: None,
  }
}

///|
fn imported_package_id(
  index : DeclarationIndex,
  alias_name : String,
) -> String? {
  for import_ref in index.imports {
    if import_ref.alias_name == alias_name {
      return Some(import_ref.package_id)
    }
  }
  None
}
