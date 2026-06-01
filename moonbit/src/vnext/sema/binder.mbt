///|
using @common {source_span, type Diagnostic, type SourceSpan}

///|
using @ast {
  expr_span,
  type CallArg,
  type Expr,
  type Function,
  type GlobalLet,
  type ImplDecl,
  type MapEntry,
  type Module,
  type StructFieldValue,
  type TypeSyntax,
}

///|
using @binding {
  bool_type,
  array_view_type,
  default_argument_id,
  double_type,
  error_type,
  float_type,
  function_id,
  global_id,
  int_type,
  local_id,
  no_raise,
  parameter_id,
  string_type,
  string_view_type,
  type_equal,
  unit_type,
  type BindingContext,
  type EnumVariantDef,
  type FieldDef,
  type FunctionSignature,
  type GlobalSignature,
  type ImportRef,
  type ParameterDef,
  type Symbol,
  type SymbolKind,
  type TraitRef,
  type TypeParamConstraint,
  type TypeConstructorRef,
  type TypeDefinition,
  type TypeRef,
}

///|
using @ir {
  type BoundArrayElement,
  type BoundExpr,
  type BoundExternalFunction,
  type BoundFunction,
  type BoundGlobal,
  type BoundModule,
  type BoundParam,
  type BoundFieldValue,
  type BoundMapEntry,
  type BoundTraitDispatch,
}

///|
using @semantic {
  type DeclarationIndex,
  type TypeSubstitution,
  type TypingContext,
}

///|
priv struct CallableProbe {
  callable : @semantic.SelectedCallable
  argument_plan : ArgumentPlan
  substitutions : Array[TypeSubstitution]
}

///|
priv struct TraitMethodSelection {
  trait_ref : TraitRef
  method_id : String
  parameters : Array[@binding.ParamTypeRef]
  return_type : TypeRef
  self_type : TypeRef
  dispatch : BoundTraitDispatch
  impl_type_param_usages : Array[@binding.UsedTraitImpl]
}

///|
priv struct ArgumentPlan {
  items : Array[ArgumentPlanItem]
}

///|
pub(all) struct CollectedDeclarations {
  symbols : Array[Symbol]
  types : Array[TypeDefinition]
  traits : Array[@semantic.TraitDefinition]
  functions : Array[FunctionSignature]
  globals : Array[GlobalSignature]
  impls : Array[@semantic.ImplDefinition]
  default_arguments : Array[@binding.DefaultArgument]
  bound_traits : Array[@ir.BoundTrait]
  function_stubs : Array[@ir.BoundFunction]
  diagnostics : Array[Diagnostic]
}

///|
priv enum ArgumentPlanItem {
  Supplied(ParameterDef, CallArg)
  Defaulted(ParameterDef, @binding.DefaultArgument)
  OptionalNone(ParameterDef, SourceSpan)
}

///|
pub(all) struct PackageBindingSession {
  ast : Module
  module_name : String
  package_id : String
  context : BindingContext
  index : DeclarationIndex
  source_functions_by_id : Map[String, Function]
  source_globals_by_id : Map[String, GlobalLet]
  diagnostics : Array[Diagnostic]
}

///|
pub fn bind_module(
  ast : Module,
  module_name : String,
  diagnostics : Array[Diagnostic],
) -> BoundModule {
  bind_module_with_package_id(
    ast,
    module_name,
    "pkg:" + module_name,
    [],
    [],
    [],
    [],
    [],
    [],
    diagnostics,
  )
}

///|
pub fn bind_module_with_imports(
  ast : Module,
  module_name : String,
  imports : Array[ImportRef],
  imported_types : Array[TypeDefinition],
  imported_functions : Array[FunctionSignature],
  imported_globals : Array[GlobalSignature],
  diagnostics : Array[Diagnostic],
) -> BoundModule {
  bind_module_with_package_id(
    ast,
    module_name,
    "pkg:" + module_name,
    imports,
    imported_types,
    imported_functions,
    imported_globals,
    [],
    [],
    diagnostics,
  )
}

///|
pub fn bind_module_with_package_id(
  ast : Module,
  module_name : String,
  package_id : String,
  imports : Array[ImportRef],
  imported_types : Array[TypeDefinition],
  imported_functions : Array[FunctionSignature],
  imported_globals : Array[GlobalSignature],
  imported_traits : Array[@semantic.TraitDefinition],
  imported_impls : Array[@semantic.ImplDefinition],
  diagnostics : Array[Diagnostic],
) -> BoundModule {
  bind_module_with_package_id_and_default_arguments(
    ast,
    module_name,
    package_id,
    imports,
    imported_types,
    imported_functions,
    imported_globals,
    imported_traits,
    imported_impls,
    [],
    diagnostics,
  )
}

///|
pub fn bind_module_with_package_id_and_default_arguments(
  ast : Module,
  module_name : String,
  package_id : String,
  imports : Array[ImportRef],
  imported_types : Array[TypeDefinition],
  imported_functions : Array[FunctionSignature],
  imported_globals : Array[GlobalSignature],
  imported_traits : Array[@semantic.TraitDefinition],
  imported_impls : Array[@semantic.ImplDefinition],
  imported_default_arguments : Array[@binding.DefaultArgument],
  diagnostics : Array[Diagnostic],
) -> BoundModule {
  let context = @binding.binding_context_with_imports(
    module_name, package_id, imports, imported_types, imported_functions, imported_globals,
    diagnostics,
  )
  @binding.add_default_arguments(context, imported_default_arguments)
  let index = @semantic.declaration_index(
    package_id,
    module_name,
    imports,
    context.diagnostics,
  )
  @semantic.add_imported_type_definitions(index, imported_types)
  @semantic.add_imported_functions(index, imported_functions)
  @semantic.add_imported_globals(index, imported_globals)
  @semantic.add_imported_traits(index, imported_traits)
  @semantic.add_imported_impls(index, imported_impls)
  declare_usings(index, ast)
  declare_opaque_type_headers(context, index, ast)
  declare_struct_headers(context, index, ast)
  declare_enum_headers(context, index, ast)
  collect_opaque_types(context, index, ast)
  collect_structs(context, index, ast)
  collect_enums(context, index, ast)
  collect_traits(context, index, ast)
  collect_functions(context, index, ast)
  let core_builtin_functions : Array[BoundFunction] = []
  collect_globals(context, index, ast)
  collect_impls(context, index, ast)
  let functions : Array[BoundFunction] = core_builtin_functions
  for function in ast.functions {
    match function.external {
      Some(extern_decl) =>
        match extern_decl.body {
          Some(body) =>
            functions.push(
              bind_external_function(
                context,
                index,
                function,
                extern_decl.target,
                body,
              ),
            )
          None =>
            if extern_decl.target == "interface" {
              functions.push(
                bind_external_function(
                  context, index, function, "interface", "",
                ),
              )
            }
        }
      None =>
        if function.intrinsic is None {
          functions.push(bind_function_body(context, index, ast, function))
        }
    }
  }
  append_bound_functions(
    functions,
    bind_impl_method_bodies(context, index, ast),
  )
  let globals : Array[BoundGlobal] = []
  for global in ast.globals {
    globals.push(bind_global(context, index, ast, global))
  }
  let module_ : BoundModule = {
    schema: "moonbit2csharp.vnext.semantic-ir/0.1",
    module_name,
    symbols: context.symbols,
    types: context.types,
    traits: bound_traits(index.traits),
    used_trait_impls: context.used_trait_impls,
    functions,
    globals,
    default_arguments: context.default_arguments,
    diagnostics: context.diagnostics,
  }
  validate_executable_module_if_clean(module_)
  module_
}

///|
pub fn bind_selected_functions_with_package_id_and_default_arguments(
  ast : Module,
  module_name : String,
  package_id : String,
  imports : Array[ImportRef],
  imported_types : Array[TypeDefinition],
  imported_functions : Array[FunctionSignature],
  imported_globals : Array[GlobalSignature],
  imported_traits : Array[@semantic.TraitDefinition],
  imported_impls : Array[@semantic.ImplDefinition],
  imported_default_arguments : Array[@binding.DefaultArgument],
  selected_function_ids : Array[String],
  diagnostics : Array[Diagnostic],
) -> BoundModule {
  let session = package_binding_session_with_default_arguments(
    ast, module_name, package_id, imports, imported_types, imported_functions, imported_globals,
    imported_traits, imported_impls, imported_default_arguments, diagnostics,
  )
  bind_selected_functions_from_session(session, selected_function_ids)
}

///|
pub fn package_binding_session_with_default_arguments(
  ast : Module,
  module_name : String,
  package_id : String,
  imports : Array[ImportRef],
  imported_types : Array[TypeDefinition],
  imported_functions : Array[FunctionSignature],
  imported_globals : Array[GlobalSignature],
  imported_traits : Array[@semantic.TraitDefinition],
  imported_impls : Array[@semantic.ImplDefinition],
  imported_default_arguments : Array[@binding.DefaultArgument],
  diagnostics : Array[Diagnostic],
) -> PackageBindingSession {
  let context = @binding.binding_context_with_imports(
    module_name, package_id, imports, imported_types, imported_functions, imported_globals,
    diagnostics,
  )
  @binding.add_default_arguments(context, imported_default_arguments)
  let index = @semantic.declaration_index(
    package_id,
    module_name,
    imports,
    context.diagnostics,
  )
  @semantic.add_imported_type_definitions(index, imported_types)
  @semantic.add_imported_functions(index, imported_functions)
  @semantic.add_imported_globals(index, imported_globals)
  @semantic.add_imported_traits(index, imported_traits)
  @semantic.add_imported_impls(index, imported_impls)
  declare_usings(index, ast)
  declare_opaque_type_headers(context, index, ast)
  declare_struct_headers(context, index, ast)
  declare_enum_headers(context, index, ast)
  collect_opaque_types(context, index, ast)
  collect_structs(context, index, ast)
  collect_enums(context, index, ast)
  collect_traits(context, index, ast)
  collect_functions(context, index, ast)
  collect_globals(context, index, ast)
  collect_impls(context, index, ast)
  {
    ast,
    module_name,
    package_id,
    context,
    index,
    source_functions_by_id: source_function_index(ast, package_id, module_name),
    source_globals_by_id: source_global_index(ast, package_id, module_name),
    diagnostics,
  }
}

///|
pub fn bind_selected_functions_from_session(
  session : PackageBindingSession,
  selected_function_ids : Array[String],
) -> BoundModule {
  let functions : Array[BoundFunction] = []
  for fid in selected_function_ids {
    match session.source_functions_by_id.get(fid) {
      Some(function) =>
        match function.external {
          Some(extern_decl) =>
            match extern_decl.body {
              Some(body) =>
                functions.push(
                  bind_external_function(
                    session.context,
                    session.index,
                    function,
                    extern_decl.target,
                    body,
                  ),
                )
              None =>
                if extern_decl.target == "interface" {
                  functions.push(
                    bind_external_function(
                      session.context,
                      session.index,
                      function,
                      "interface",
                      "",
                    ),
                  )
                }
            }
          None =>
            if function.intrinsic is None {
              functions.push(
                bind_function_body(
                  session.context,
                  session.index,
                  session.ast,
                  function,
                ),
              )
            }
        }
      None => ()
    }
  }
  append_bound_functions(
    functions,
    bind_selected_impl_method_bodies(
      session.context,
      session.index,
      session.ast,
      selected_function_ids,
    ),
  )
  append_bound_functions(
    functions,
    bind_missing_selected_impl_method_bodies(
      session, functions, selected_function_ids,
    ),
  )
  let module_ : BoundModule = {
    schema: "moonbit2csharp.vnext.semantic-ir/0.1",
    module_name: session.module_name,
    symbols: session.context.symbols,
    types: session.context.types,
    traits: bound_traits(session.index.traits),
    used_trait_impls: session.context.used_trait_impls,
    functions,
    globals: [],
    default_arguments: session.context.default_arguments,
    diagnostics: session.context.diagnostics,
  }
  validate_executable_module_if_clean(module_)
  module_
}

///|
fn bind_missing_selected_impl_method_bodies(
  session : PackageBindingSession,
  existing_functions : Array[BoundFunction],
  selected_function_ids : Array[String],
) -> Array[BoundFunction] {
  let missing : Array[String] = []
  let existing_function_ids : Set[String] = Set([])
  for function in existing_functions {
    existing_function_ids.add(function.symbol_id)
  }
  for function_id in selected_function_ids {
    if !existing_function_ids.contains(function_id) {
      missing.push(function_id)
    }
  }
  if missing.length() == 0 {
    return []
  }
  let missing_set = binder_string_set(missing)
  let diagnostics : Array[Diagnostic] = []
  let context : BindingContext = {
    module_name: session.context.module_name,
    package_id: session.context.package_id,
    imports: session.context.imports,
    current_type_params: session.context.current_type_params,
    symbols: session.context.symbols,
    types: session.context.types,
    functions: session.context.functions,
    imported_functions: session.context.imported_functions,
    imported_globals: session.context.imported_globals,
    default_arguments: session.context.default_arguments,
    default_arguments_by_id: session.context.default_arguments_by_id,
    current_return_type: session.context.current_return_type,
    current_owner_id: session.context.current_owner_id,
    current_effect: session.context.current_effect,
    loop_depth: session.context.loop_depth,
    loop_break_expected_types: session.context.loop_break_expected_types,
    used_trait_impls: session.context.used_trait_impls,
    used_trait_impl_keys: session.context.used_trait_impl_keys,
    trait_default_context: session.context.trait_default_context,
    diagnostics,
    suppress_diagnostics: session.context.suppress_diagnostics,
  }
  let result : Array[BoundFunction] = []
  for
    function in bind_all_impl_method_bodies(
      context,
      session.index,
      session.ast,
      missing,
    ) {
    if missing_set.contains(function.symbol_id) {
      result.push(function)
    }
  }
  result
}

///|
pub fn bind_selected_globals_from_session(
  session : PackageBindingSession,
  selected_global_ids : Array[String],
) -> BoundModule {
  let globals : Array[BoundGlobal] = []
  for gid in selected_global_ids {
    match session.source_globals_by_id.get(gid) {
      Some(global) =>
        globals.push(
          bind_global(session.context, session.index, session.ast, global),
        )
      None => ()
    }
  }
  let module_ : BoundModule = {
    schema: "moonbit2csharp.vnext.semantic-ir/0.1",
    module_name: session.module_name,
    symbols: session.context.symbols,
    types: session.context.types,
    traits: bound_traits(session.index.traits),
    used_trait_impls: session.context.used_trait_impls,
    functions: [],
    globals,
    default_arguments: session.context.default_arguments,
    diagnostics: session.context.diagnostics,
  }
  validate_executable_module_if_clean(module_)
  module_
}

///|
fn validate_executable_module_if_clean(module_ : BoundModule) -> Unit {
  if !has_error_diagnostic(module_.diagnostics) {
    @semantic.validate_executable_module(module_)
  }
}

///|
fn has_error_diagnostic(diagnostics : Array[Diagnostic]) -> Bool {
  for diagnostic in diagnostics {
    if diagnostic.severity == "error" {
      return true
    }
  }
  false
}

///|
fn binder_string_set(items : Array[String]) -> Set[String] {
  let result : Set[String] = Set([])
  for item in items {
    result.add(item)
  }
  result
}

///|
fn source_function_index(
  ast : Module,
  package_id : String,
  module_name : String,
) -> Map[String, Function] {
  let result : Map[String, Function] = Map([])
  for function in ast.functions {
    result[function_id(package_id, module_name, function_decl_name(function))] = function
  }
  result
}

///|
fn source_global_index(
  ast : Module,
  package_id : String,
  module_name : String,
) -> Map[String, GlobalLet] {
  let result : Map[String, GlobalLet] = Map([])
  for global in ast.globals {
    result[global_id(package_id, module_name, global.name)] = global
  }
  result
}

///|
pub fn collect_module_declarations_with_package_id(
  ast : Module,
  module_name : String,
  package_id : String,
  imports : Array[ImportRef],
  imported_types : Array[TypeDefinition],
  imported_functions : Array[FunctionSignature],
  imported_globals : Array[GlobalSignature],
  diagnostics : Array[Diagnostic],
) -> BoundModule {
  let collected = collect_semantic_declarations_with_package_id(
    ast,
    module_name,
    package_id,
    imports,
    imported_types,
    imported_functions,
    imported_globals,
    [],
    [],
    diagnostics,
  )
  {
    schema: "moonbit2csharp.vnext.semantic-ir/0.1",
    module_name,
    symbols: collected.symbols,
    types: collected.types,
    traits: collected.bound_traits,
    used_trait_impls: [],
    functions: collected.function_stubs,
    globals: [],
    default_arguments: collected.default_arguments,
    diagnostics: collected.diagnostics,
  }
}

///|
pub fn collect_semantic_declarations_with_package_id(
  ast : Module,
  module_name : String,
  package_id : String,
  imports : Array[ImportRef],
  imported_types : Array[TypeDefinition],
  imported_functions : Array[FunctionSignature],
  imported_globals : Array[GlobalSignature],
  imported_traits : Array[@semantic.TraitDefinition],
  imported_impls : Array[@semantic.ImplDefinition],
  diagnostics : Array[Diagnostic],
) -> CollectedDeclarations {
  let context = @binding.binding_context_with_imports(
    module_name, package_id, imports, imported_types, imported_functions, imported_globals,
    diagnostics,
  )
  let index = @semantic.declaration_index(
    package_id,
    module_name,
    imports,
    context.diagnostics,
  )
  @semantic.add_imported_type_definitions(index, imported_types)
  @semantic.add_imported_functions(index, imported_functions)
  @semantic.add_imported_globals(index, imported_globals)
  @semantic.add_imported_traits(index, imported_traits)
  @semantic.add_imported_impls(index, imported_impls)
  declare_usings(index, ast)
  declare_opaque_type_headers(context, index, ast)
  declare_struct_headers(context, index, ast)
  declare_enum_headers(context, index, ast)
  collect_opaque_types(context, index, ast)
  collect_structs(context, index, ast)
  collect_enums(context, index, ast)
  collect_traits(context, index, ast)
  collect_functions(context, index, ast)
  collect_globals(context, index, ast)
  collect_impls(context, index, ast)
  let functions : Array[BoundFunction] = []
  for signature in context.functions {
    functions.push(signature_to_bound_function_stub(signature, ast))
  }
  for signature in index.builtin_functions {
    functions.push(signature_to_bound_function_stub(signature, ast))
  }
  let signatures : Array[FunctionSignature] = []
  for signature in context.functions {
    signatures.push(signature)
  }
  for signature in index.builtin_functions {
    signatures.push(signature)
  }
  {
    symbols: context.symbols,
    types: context.types,
    traits: index.traits,
    functions: signatures,
    globals: collected_global_signatures(context),
    impls: index.impls,
    bound_traits: bound_traits(index.traits),
    function_stubs: functions,
    default_arguments: context.default_arguments,
    diagnostics: context.diagnostics,
  }
}

///|
fn collected_global_signatures(
  context : BindingContext,
) -> Array[GlobalSignature] {
  let globals : Array[GlobalSignature] = []
  for symbol in context.symbols {
    if symbol.kind == SymbolKind::Global {
      globals.push({
        symbol,
        package_id: context.package_id,
        module_path: context.module_name,
      })
    }
  }
  globals
}

///|
fn append_bound_functions(
  target : Array[BoundFunction],
  source : Array[BoundFunction],
) -> Unit {
  for function in source {
    target.push(function)
  }
}

///|
fn signature_to_bound_function_stub(
  signature : FunctionSignature,
  ast : Module,
) -> BoundFunction {
  let params : Array[BoundParam] = []
  for parameter in signature.parameters {
    params.push({
      symbol_id: parameter.symbol.id,
      name: parameter.symbol.name,
      label: parameter.label,
      optional: parameter.optional,
      has_default: parameter.has_default,
      default_ref: parameter.default_ref,
      type_: parameter.symbol.type_,
    })
  }
  let external = match find_function_external_body(ast, signature.name) {
    Some(external_body) => Some(external_body)
    None => None
  }
  {
    symbol_id: signature.function_id,
    name: signature.name,
    is_public: signature.is_public,
    type_params: signature.type_params,
    params,
    return_type: signature.return_type,
    effect: signature.effect,
    external,
    body: BoundExpr::UnitLiteral(@binding.unit_type(), signature.span),
    span: signature.span,
  }
}

///|
fn find_function_external_body(
  ast : Module,
  name : String,
) -> BoundExternalFunction? {
  for function in ast.functions {
    if function_decl_name(function) == name {
      match function.external {
        Some(extern_decl) =>
          match extern_decl.body {
            Some(body) => return Some({ target: extern_decl.target, body })
            None => ()
          }
        None => ()
      }
    }
  }
  None
}

///|
pub fn bound_function_signature(
  function : BoundFunction,
  package_id : String,
  module_path : String,
) -> FunctionSignature {
  let parameters : Array[ParameterDef] = []
  for param in function.params {
    parameters.push(bound_parameter_def(param))
  }
  {
    function_id: function.symbol_id,
    package_id,
    module_path,
    name: function.name,
    receiver_type: bound_function_receiver_type(function),
    type_params: function.type_params,
    parameters,
    return_type: function.return_type,
    effect: function.effect,
    aliases: [],
    intrinsic: None,
    is_public: function.is_public,
    span: function.span,
  }
}

///|
fn bound_function_receiver_type(function : BoundFunction) -> TypeRef? {
  if !function.name.contains("::") || function.params.length() == 0 {
    return None
  }
  Some(function.params[0].type_)
}

///|
pub fn bound_global_signature(
  global : BoundGlobal,
  package_id : String,
  module_path : String,
) -> GlobalSignature {
  { symbol: bound_global_symbol(global), package_id, module_path }
}

///|
fn bound_global_symbol(global : BoundGlobal) -> Symbol {
  {
    id: global.symbol_id,
    kind: SymbolKind::Global,
    name: global.name,
    type_: global.type_,
    span: global.span,
  }
}

///|
fn bound_parameter_def(param : BoundParam) -> ParameterDef {
  let argument_type = if param.optional && !param.has_default {
    match option_item_type(param.type_) {
      Some(item) => item
      None => param.type_
    }
  } else {
    param.type_
  }
  {
    symbol: {
      id: param.symbol_id,
      kind: SymbolKind::Parameter,
      name: param.name,
      type_: param.type_,
      span: source_span("", 0, 0, 1, 1),
    },
    label: param.label,
    optional: param.optional,
    has_default: param.has_default,
    default_ref: param.default_ref,
    argument_type,
  }
}

///|
