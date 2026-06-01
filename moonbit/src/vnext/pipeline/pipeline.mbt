///|
pub fn compile_source_to_json(
  source : String,
  file_path : String,
  module_name : String,
) -> String {
  let file = @text.source_file(file_path, normalize_source_newlines(source))
  let parsed = @syntax.parse_source(file)
  let bound = @sema.bind_module(parsed.module_, module_name, parsed.diagnostics)
  @json.write_module_json(bound)
}

///|
pub fn compile_package_source_to_json(
  source : String,
  file_path : String,
  module_name : String,
  moon_pkg_source : String,
  moon_pkg_path : String,
  imported_sources : Array[@package.PackageSource],
) -> String {
  compile_package_sources_to_json(
    [{ file_path, source }],
    module_name,
    moon_pkg_source,
    moon_pkg_path,
    imported_sources,
  )
}

///|
pub fn compile_package_sources_to_json(
  sources : Array[@package.SourceUnit],
  module_name : String,
  moon_pkg_source : String,
  moon_pkg_path : String,
  imported_sources : Array[@package.PackageSource],
) -> String {
  compile_package_sources_with_declarations_to_json(
    sources,
    module_name,
    moon_pkg_source,
    moon_pkg_path,
    imported_sources,
    [],
  )
}

///|
pub fn compile_package_sources_with_declarations_to_json(
  sources : Array[@package.SourceUnit],
  module_name : String,
  moon_pkg_source : String,
  moon_pkg_path : String,
  imported_sources : Array[@package.PackageSource],
  imported_declaration_sources : Array[@package.PackageSource],
) -> String {
  compile_package_sources_with_manifests_to_json(
    sources,
    module_name,
    moon_pkg_source,
    moon_pkg_path,
    imported_sources,
    imported_declaration_sources,
    [],
  )
}

///|
pub fn compile_package_sources_with_manifests_to_json(
  sources : Array[@package.SourceUnit],
  module_name : String,
  moon_pkg_source : String,
  moon_pkg_path : String,
  imported_sources : Array[@package.PackageSource],
  imported_declaration_sources : Array[@package.PackageSource],
  imported_manifest_sources : Array[@package.SourceUnit],
) -> String {
  compile_package_sources_with_manifests_to_json_profiled(
    sources, module_name, moon_pkg_source, moon_pkg_path, imported_sources, imported_declaration_sources,
    imported_manifest_sources,
  ).ir_json
}

///|
pub(all) struct ProfiledCompileResult {
  ir_json : String
  profile_json : String
}

///|
pub fn compile_package_sources_with_manifests_to_json_profiled(
  sources : Array[@package.SourceUnit],
  module_name : String,
  moon_pkg_source : String,
  moon_pkg_path : String,
  imported_sources : Array[@package.PackageSource],
  imported_declaration_sources : Array[@package.PackageSource],
  imported_manifest_sources : Array[@package.SourceUnit],
) -> ProfiledCompileResult {
  let profiler = new_pipeline_profiler()
  let total_start = profile_start(profiler)
  let manifest_start = profile_start(profiler)
  let manifest = @package.parse_moon_pkg(moon_pkg_source, moon_pkg_path)
  profile_event(profiler, "manifest.parse", manifest_start)
  let diagnostics = manifest.diagnostics
  let imported_types : Array[@binding.TypeDefinition] = []
  let imported_functions : Array[@binding.FunctionSignature] = []
  let imported_globals : Array[@binding.GlobalSignature] = []
  let imported_traits : Array[@semantic.TraitDefinition] = []
  let imported_impls : Array[@semantic.ImplDefinition] = []
  let imported_default_arguments : Array[@binding.DefaultArgument] = []
  let declaration_imports_start = profile_start(profiler)
  let declaration_imports = declaration_import_refs(
    manifest.imports,
    imported_sources,
    imported_declaration_sources,
    imported_manifest_sources,
  )
  profile_event(profiler, "declaration.imports", declaration_imports_start)
  let emitted_symbols : Array[@binding.Symbol] = []
  let emitted_types : Array[@binding.TypeDefinition] = []
  let emitted_traits : Array[@ir.BoundTrait] = []
  let emitted_functions : Array[@ir.BoundFunction] = []
  let emitted_globals : Array[@ir.BoundGlobal] = []
  let declaration_groups_start = profile_start(profiler)
  let imported_declaration_groups = group_imported_sources(
    imported_declaration_sources,
  )
  let extern_declaration_groups : Array[ImportedPackageGroup] = []
  profile_event_with_count(
    profiler,
    "imports.declaration.group",
    declaration_groups_start,
    imported_declaration_groups.length(),
  )
  for imported_group in imported_declaration_groups {
    let parse_start = profile_start(profiler)
    let imported_parsed = parse_declaration_package_sources(
      imported_group.sources,
      diagnostics,
    )
    profile_event_with_count(
      profiler,
      "imports.declaration.parse:" + imported_group.import_ref.package_id,
      parse_start,
      imported_group.sources.length(),
    )
    let collect_start = profile_start(profiler)
    let imported_bound = @sema.collect_semantic_declarations_with_package_id(
      imported_parsed,
      imported_group.import_ref.module_path,
      imported_group.import_ref.package_id,
      declaration_imports,
      imported_types,
      imported_functions,
      imported_globals,
      imported_traits,
      imported_impls,
      diagnostics,
    )
    profile_event(
      profiler,
      "imports.declaration.collect:" + imported_group.import_ref.package_id,
      collect_start,
    )
    for type_def in imported_bound.types {
      imported_types.push(type_def)
    }
    for function in imported_bound.functions {
      push_function_signature_unique(imported_functions, function)
    }
    for default_arg in imported_bound.default_arguments {
      push_default_argument_unique(imported_default_arguments, default_arg)
    }
    for trait_def in imported_bound.traits {
      push_trait_definition_unique(imported_traits, trait_def)
    }
    for impl_def in imported_bound.impls {
      push_impl_definition_unique(imported_impls, impl_def)
    }
    let extern_sources = external_declaration_sources(imported_group.sources)
    if extern_sources.length() > 0 {
      push_imported_group_unique(extern_declaration_groups, {
        import_ref: imported_group.import_ref,
        sources: extern_sources,
      })
    }
  }
  let imported_groups_start = profile_start(profiler)
  let imported_groups = group_imported_sources(imported_sources)
  profile_event_with_count(
    profiler,
    "imports.implementation.group",
    imported_groups_start,
    imported_groups.length(),
  )
  for imported_group in imported_groups {
    let parse_start = profile_start(profiler)
    let imported_parsed = parse_package_sources(
      imported_group.sources,
      diagnostics,
    )
    profile_event_with_count(
      profiler,
      "imports.implementation.parse-decls:" +
      imported_group.import_ref.package_id,
      parse_start,
      imported_group.sources.length(),
    )
    let collect_start = profile_start(profiler)
    let imported_bound = @sema.collect_semantic_declarations_with_package_id(
      imported_parsed,
      imported_group.import_ref.module_path,
      imported_group.import_ref.package_id,
      declaration_imports,
      imported_types,
      imported_functions,
      imported_globals,
      imported_traits,
      imported_impls,
      diagnostics,
    )
    profile_event(
      profiler,
      "imports.implementation.collect:" + imported_group.import_ref.package_id,
      collect_start,
    )
    for type_def in imported_bound.types {
      push_type_definition_unique(imported_types, type_def)
      push_type_definition_unique(emitted_types, type_def)
    }
    for function in imported_bound.functions {
      push_function_signature_unique(imported_functions, function)
    }
    for global in imported_bound.globals {
      push_global_signature_unique(imported_globals, global)
    }
    for default_arg in imported_bound.default_arguments {
      push_default_argument_unique(imported_default_arguments, default_arg)
    }
    for trait_def in imported_bound.traits {
      push_trait_definition_unique(imported_traits, trait_def)
    }
    for impl_def in imported_bound.impls {
      push_impl_definition_unique(imported_impls, impl_def)
    }
    if should_emit_imported_group(imported_group) {
      for symbol in imported_bound.symbols {
        push_symbol_unique(emitted_symbols, symbol)
      }
    }
  }
  let local_parse_start = profile_start(profiler)
  let parsed = parse_source_units(sources, diagnostics)
  profile_event_with_count(
    profiler,
    "local.parse",
    local_parse_start,
    sources.length(),
  )
  let local_bind_start = profile_start(profiler)
  let bound = @sema.bind_module_with_package_id_and_default_arguments(
    parsed,
    module_name,
    "pkg:" + module_name,
    manifest.imports,
    imported_types,
    imported_functions,
    imported_globals,
    imported_traits,
    imported_impls,
    imported_default_arguments,
    diagnostics,
  )
  profile_event(profiler, "local.bind", local_bind_start)
  let reachable_start = profile_start(profiler)
  complete_reachable_declaration_source_functions(
    reachable_imported_groups(extern_declaration_groups, imported_groups),
    emitted_functions,
    emitted_globals,
    bound,
    declaration_imports,
    imported_types,
    imported_functions,
    imported_globals,
    imported_traits,
    imported_impls,
    imported_default_arguments,
    diagnostics,
    profiler,
  )
  profile_event(profiler, "reachable.complete", reachable_start)
  let merge_start = profile_start(profiler)
  let merged = merge_imported_implementations(bound, {
    symbols: emitted_symbols,
    types: emitted_types,
    traits: emitted_traits,
    functions: emitted_functions,
    globals: emitted_globals,
  })
  profile_event(profiler, "ir.merge", merge_start)
  let json_start = profile_start(profiler)
  let ir_json = @json.write_module_json(merged)
  profile_event(profiler, "json.write", json_start)
  profile_event(profiler, "total", total_start)
  { ir_json, profile_json: write_profile_json(profiler) }
}

///|
fn complete_reachable_declaration_source_functions(
  imported_declaration_groups : Array[ImportedPackageGroup],
  emitted_functions : Array[@ir.BoundFunction],
  emitted_globals : Array[@ir.BoundGlobal],
  local_bound : @ir.BoundModule,
  declaration_imports : Array[@binding.ImportRef],
  imported_types : Array[@binding.TypeDefinition],
  imported_functions : Array[@binding.FunctionSignature],
  imported_globals : Array[@binding.GlobalSignature],
  imported_traits : Array[@semantic.TraitDefinition],
  imported_impls : Array[@semantic.ImplDefinition],
  imported_default_arguments : Array[@binding.DefaultArgument],
  diagnostics : Array[@common.Diagnostic],
  profiler : PipelineProfiler,
) -> Unit {
  let sessions_start = profile_start(profiler)
  let sessions = reachable_package_sessions(
    imported_declaration_groups, declaration_imports, imported_types, imported_functions,
    imported_globals, imported_traits, imported_impls, imported_default_arguments,
    diagnostics, profiler,
  )
  profile_event_with_count(
    profiler,
    "reachable.sessions",
    sessions_start,
    sessions.length(),
  )
  let reachability_index = build_reachability_index(sessions)
  let collect_start = profile_start(profiler)
  let reachable = reachable_function_worklist()
  let reachable_globals = reachable_global_worklist()
  collect_module_called_function_ids(local_bound, reachability_index, reachable)
  collect_module_referenced_global_ids(
    local_bound, reachability_index, reachable_globals,
  )
  for function in emitted_functions {
    collect_function_called_function_ids(
      function, reachability_index, reachable,
    )
    collect_function_referenced_global_ids(
      function, reachability_index, reachable_globals,
    )
  }
  for global in emitted_globals {
    collect_expr_referenced_global_ids(
      global.value,
      reachability_index,
      reachable_globals,
    )
  }
  profile_event_with_count(
    profiler,
    "reachable.initial-collect",
    collect_start,
    reachable.items.length(),
  )
  let processed_reachable : Set[String] = Set([])
  let emitted_function_ids = emitted_function_id_set(emitted_functions)
  let emitted_global_ids = emitted_global_id_set(emitted_globals)
  let mut changed = true
  while changed {
    changed = false
    for session in sessions {
      let select_start = profile_start(profiler)
      let selected = selected_reachable_function_ids(
        reachable,
        emitted_function_ids,
        processed_reachable,
        session.binding_session,
      )
      let selected_globals = selected_reachable_global_ids(
        reachable_globals,
        emitted_global_ids,
        session.binding_session,
      )
      profile_event_with_count(
        profiler,
        "reachable.select:" + session.import_ref.package_id,
        select_start,
        selected.length(),
      )
      if selected.length() > 0 {
        if session.has_implementation {
          let diagnostic_start = session.diagnostics.length()
          let bind_start = profile_start(profiler)
          for selected_function_id in selected {
            ignore(set_try_add(processed_reachable, selected_function_id))
          }
          let bound = @sema.bind_selected_functions_from_session(
            session.binding_session,
            selected,
          )
          profile_event_with_count(
            profiler,
            "reachable.bind-functions:" + session.import_ref.package_id,
            bind_start,
            bound.functions.length(),
          )
          let new_diagnostics = diagnostics_after(
            session.diagnostics,
            diagnostic_start,
          )
          if !has_error_diagnostics(new_diagnostics) {
            for diagnostic in new_diagnostics {
              diagnostics.push(diagnostic)
            }
            for function in bound.functions {
              if set_try_add(emitted_function_ids, function.symbol_id) {
                emitted_functions.push(function)
                collect_function_called_function_ids(
                  function, reachability_index, reachable,
                )
                collect_function_referenced_global_ids(
                  function, reachability_index, reachable_globals,
                )
                changed = true
              }
            }
          } else {
            for diagnostic in new_diagnostics {
              diagnostics.push(diagnostic)
            }
          }
        }
      }
      if selected_globals.length() > 0 && session.has_implementation {
        let diagnostic_start = session.diagnostics.length()
        let bind_start = profile_start(profiler)
        let bound = @sema.bind_selected_globals_from_session(
          session.binding_session,
          selected_globals,
        )
        profile_event(
          profiler,
          "reachable.bind-globals:" + session.import_ref.package_id,
          bind_start,
        )
        let new_diagnostics = diagnostics_after(
          session.diagnostics,
          diagnostic_start,
        )
        if !has_error_diagnostics(new_diagnostics) {
          for diagnostic in new_diagnostics {
            diagnostics.push(diagnostic)
          }
          for global in bound.globals {
            if set_try_add(emitted_global_ids, global.symbol_id) {
              emitted_globals.push(global)
              collect_expr_called_function_ids(
                global.value,
                reachability_index,
                reachable,
              )
              collect_expr_referenced_global_ids(
                global.value,
                reachability_index,
                reachable_globals,
              )
              changed = true
            }
          }
        } else {
          for diagnostic in new_diagnostics {
            diagnostics.push(diagnostic)
          }
        }
      }
    }
  }
}

///|
priv struct ReachablePackageSession {
  import_ref : @binding.ImportRef
  binding_session : @sema.PackageBindingSession
  diagnostics : Array[@common.Diagnostic]
  has_implementation : Bool
}

///|
priv struct ReachableFunctionRef {
  function_id : String
  package_id : String
}

///|
priv struct ReachableGlobalRef {
  symbol_id : String
  package_id : String
}

///|
priv struct ReachableFunctionWorklist {
  items : Array[ReachableFunctionRef]
  seen : Set[String]
  by_package : Map[String, Array[String]]
}

///|
priv struct ReachableGlobalWorklist {
  items : Array[ReachableGlobalRef]
  seen : Set[String]
  by_package : Map[String, Array[String]]
}

///|
fn reachable_function_worklist() -> ReachableFunctionWorklist {
  { items: [], seen: Set([]), by_package: Map([]) }
}

///|
fn reachable_global_worklist() -> ReachableGlobalWorklist {
  { items: [], seen: Set([]), by_package: Map([]) }
}

///|
priv struct ReachabilityIndex {
  function_packages : Map[String, String]
  global_packages : Map[String, String]
  default_impl_method_functions : Map[String, Array[String]]
}

///|
fn build_reachability_index(
  sessions : Array[ReachablePackageSession],
) -> ReachabilityIndex {
  let function_packages : Map[String, String] = Map([])
  let global_packages : Map[String, String] = Map([])
  let default_impl_method_functions : Map[String, Array[String]] = Map([])
  for session in sessions {
    index_function_packages(
      function_packages,
      session.binding_session.index.functions,
    )
    index_function_packages(
      function_packages,
      session.binding_session.index.builtin_functions,
    )
    index_function_packages(
      function_packages,
      session.binding_session.index.imported_functions,
    )
    for global in session.binding_session.index.globals {
      put_string_if_absent(
        global_packages,
        global.id,
        session.binding_session.package_id,
      )
    }
    for global in session.binding_session.index.imported_globals {
      put_string_if_absent(global_packages, global.symbol.id, global.package_id)
    }
    index_default_impl_method_functions(
      default_impl_method_functions,
      session.binding_session.index.impls,
    )
  }
  { function_packages, global_packages, default_impl_method_functions }
}

///|
fn index_default_impl_method_functions(
  items : Map[String, Array[String]],
  impls : Array[@semantic.ImplDefinition],
) -> Unit {
  for impl_ in impls {
    for impl_method in impl_.methods {
      match impl_method.body {
        @semantic.ImplMethodBody::DefaultMethod =>
          push_map_array_string_unique(
            items,
            impl_.trait_ref.trait_.id,
            impl_method.function_id,
          )
        _ => ()
      }
    }
  }
}

///|
fn push_map_array_string_unique(
  map : Map[String, Array[String]],
  key : String,
  value : String,
) -> Unit {
  match map.get(key) {
    Some(items) => push_string_unique(items, value)
    None => map[key] = [value]
  }
}

///|
fn index_function_packages(
  packages : Map[String, String],
  functions : Array[@binding.FunctionSignature],
) -> Unit {
  for function in functions {
    put_string_if_absent(packages, function.function_id, function.package_id)
  }
}

///|
fn put_string_if_absent(
  map : Map[String, String],
  key : String,
  value : String,
) -> Unit {
  match map.get(key) {
    Some(_) => ()
    None => map[key] = value
  }
}

///|
fn reachable_package_sessions(
  imported_groups : Array[ImportedPackageGroup],
  declaration_imports : Array[@binding.ImportRef],
  imported_types : Array[@binding.TypeDefinition],
  imported_functions : Array[@binding.FunctionSignature],
  imported_globals : Array[@binding.GlobalSignature],
  imported_traits : Array[@semantic.TraitDefinition],
  imported_impls : Array[@semantic.ImplDefinition],
  imported_default_arguments : Array[@binding.DefaultArgument],
  diagnostics : Array[@common.Diagnostic],
  profiler : PipelineProfiler,
) -> Array[ReachablePackageSession] {
  let sessions : Array[ReachablePackageSession] = []
  for imported_group in imported_groups {
    let impl_sources = implementation_sources(imported_group.sources)
    let local_diagnostics : Array[@common.Diagnostic] = []
    let parse_start = profile_start(profiler)
    let parsed = parse_package_sources(impl_sources, diagnostics)
    profile_event_with_count(
      profiler,
      "reachable.parse-session:" + imported_group.import_ref.package_id,
      parse_start,
      impl_sources.length(),
    )
    let visible_types = imported_types
    let visible_functions = imported_functions
    let visible_globals = imported_globals
    let visible_traits = imported_traits
    let visible_impls = imported_impls
    let session_start = profile_start(profiler)
    let binding_session = @sema.package_binding_session_with_default_arguments(
      parsed,
      imported_group.import_ref.module_path,
      imported_group.import_ref.package_id,
      declaration_imports,
      visible_types,
      visible_functions,
      visible_globals,
      visible_traits,
      visible_impls,
      imported_default_arguments,
      local_diagnostics,
    )
    profile_event(
      profiler,
      "reachable.build-session:" + imported_group.import_ref.package_id,
      session_start,
    )
    for diagnostic in local_diagnostics {
      diagnostics.push(diagnostic)
    }
    sessions.push({
      import_ref: imported_group.import_ref,
      binding_session,
      diagnostics: local_diagnostics,
      has_implementation: impl_sources.length() > 0,
    })
  }
  sessions
}

///|
fn diagnostics_after(
  diagnostics : Array[@common.Diagnostic],
  start : Int,
) -> Array[@common.Diagnostic] {
  let result : Array[@common.Diagnostic] = []
  let mut i = start
  while i < diagnostics.length() {
    result.push(diagnostics[i])
    i = i + 1
  }
  result
}

///|
priv struct PipelineProfileEvent {
  name : String
  elapsed_ms : UInt64
  count : Int
}

///|
priv struct PipelineProfiler {
  events : Array[PipelineProfileEvent]
}

///|
fn new_pipeline_profiler() -> PipelineProfiler {
  { events: [] }
}

///|
fn profile_start(_profiler : PipelineProfiler) -> UInt64 {
  @env.now()
}

///|
fn profile_event(
  profiler : PipelineProfiler,
  name : String,
  start_ms : UInt64,
) -> Unit {
  profile_event_with_count(profiler, name, start_ms, -1)
}

///|
fn profile_event_with_count(
  profiler : PipelineProfiler,
  name : String,
  start_ms : UInt64,
  count : Int,
) -> Unit {
  profiler.events.push({ name, elapsed_ms: @env.now() - start_ms, count })
}

///|
fn write_profile_json(profiler : PipelineProfiler) -> String {
  let out = StringBuilder::new()
  out.write_string(
    "{\"schema\":\"moonbit2csharp.vnext.profile.v1\",\"events\":[",
  )
  for i = 0; i < profiler.events.length(); i = i + 1 {
    if i > 0 {
      out.write_string(",")
    }
    write_profile_event(out, profiler.events[i])
  }
  out.write_string("]}")
  out.to_string()
}

///|
fn write_profile_event(
  out : StringBuilder,
  event : PipelineProfileEvent,
) -> Unit {
  out.write_string("{\"name\":")
  write_profile_string(out, event.name)
  out.write_string(",\"elapsedMs\":")
  out.write_string(event.elapsed_ms.to_string())
  if event.count >= 0 {
    out.write_string(",\"count\":")
    out.write_string(event.count.to_string())
  }
  out.write_string("}")
}

///|
fn write_profile_string(out : StringBuilder, value : String) -> Unit {
  out.write_string("\"")
  let mut i = 0
  while i < value.length() {
    let ch = value[i]
    match ch {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      _ => out.write_stringview(value[i:i + 1])
    }
    i = i + 1
  }
  out.write_string("\"")
}

///|
fn has_error_diagnostics(diagnostics : Array[@common.Diagnostic]) -> Bool {
  for diagnostic in diagnostics {
    if diagnostic.severity == "error" {
      return true
    }
  }
  false
}

///|
fn external_declaration_sources(
  sources : Array[@package.PackageSource],
) -> Array[@package.PackageSource] {
  let result : Array[@package.PackageSource] = []
  for source in sources {
    let parsed = @syntax.parse_declaration_source(
      @text.source_file(source.file_path, normalize_source_newlines(source.source)),
    )
    for function in parsed.module_.functions {
      match function.external {
        Some(extern_decl) =>
          if extern_decl.body is Some(_) {
            result.push(source)
            break
          }
        None => ()
      }
    }
  }
  result
}

///|
fn implementation_sources(
  sources : Array[@package.PackageSource],
) -> Array[@package.PackageSource] {
  let result : Array[@package.PackageSource] = []
  for source in sources {
    if !source.file_path.has_suffix(".mbti") {
      result.push(source)
    }
  }
  result
}

///|
fn selected_reachable_function_ids(
  reachable : ReachableFunctionWorklist,
  emitted_function_ids : Set[String],
  processed_reachable : Set[String],
  session : @sema.PackageBindingSession,
) -> Array[String] {
  let selected : Array[String] = []
  match reachable.by_package.get(session.package_id) {
    Some(function_ids) =>
      for function_id in function_ids {
        if !emitted_function_ids.contains(function_id) &&
          !processed_reachable.contains(function_id) {
          selected.push(function_id)
        }
      }
    None => ()
  }
  selected
}

///|
fn emitted_function_id_set(functions : Array[@ir.BoundFunction]) -> Set[String] {
  let result : Set[String] = Set([])
  for function in functions {
    result.add(function.symbol_id)
  }
  result
}

///|
fn emitted_global_id_set(globals : Array[@ir.BoundGlobal]) -> Set[String] {
  let result : Set[String] = Set([])
  for global in globals {
    result.add(global.symbol_id)
  }
  result
}

///|
fn push_reachable_function_by_package(
  result : ReachableFunctionWorklist,
  function_ref : ReachableFunctionRef,
) -> Unit {
  match result.by_package.get(function_ref.package_id) {
    Some(function_ids) => function_ids.push(function_ref.function_id)
    None =>
      result.by_package[function_ref.package_id] = [function_ref.function_id]
  }
}

///|
fn push_reachable_global_by_package(
  result : ReachableGlobalWorklist,
  global_ref : ReachableGlobalRef,
) -> Unit {
  match result.by_package.get(global_ref.package_id) {
    Some(global_ids) => global_ids.push(global_ref.symbol_id)
    None => result.by_package[global_ref.package_id] = [global_ref.symbol_id]
  }
}

///|
fn resolve_reachable_function_ref(
  index : ReachabilityIndex,
  function_id : String,
) -> ReachableFunctionRef? {
  match index.function_packages.get(function_id) {
    Some(package_id) => Some({ function_id, package_id })
    None => None
  }
}

///|
fn push_reachable_function_unique(
  result : ReachableFunctionWorklist,
  index : ReachabilityIndex,
  function_id : String,
) -> Unit {
  if result.seen.contains(function_id) {
    return
  }
  match resolve_reachable_function_ref(index, function_id) {
    Some(function_ref) => {
      result.seen.add(function_id)
      result.items.push(function_ref)
      push_reachable_function_by_package(result, function_ref)
    }
    None => ()
  }
}

///|
fn resolve_reachable_global_ref(
  index : ReachabilityIndex,
  symbol_id : String,
) -> ReachableGlobalRef? {
  match index.global_packages.get(symbol_id) {
    Some(package_id) => Some({ symbol_id, package_id })
    None => None
  }
}

///|
fn push_reachable_global_unique(
  result : ReachableGlobalWorklist,
  index : ReachabilityIndex,
  symbol_id : String,
) -> Unit {
  if result.seen.contains(symbol_id) {
    return
  }
  match resolve_reachable_global_ref(index, symbol_id) {
    Some(global_ref) => {
      result.seen.add(symbol_id)
      result.items.push(global_ref)
      push_reachable_global_by_package(result, global_ref)
    }
    None => ()
  }
}

///|
fn selected_reachable_global_ids(
  reachable : ReachableGlobalWorklist,
  emitted_global_ids : Set[String],
  session : @sema.PackageBindingSession,
) -> Array[String] {
  let selected : Array[String] = []
  match reachable.by_package.get(session.package_id) {
    Some(global_ids) =>
      for global_id in global_ids {
        if !emitted_global_ids.contains(global_id) {
          selected.push(global_id)
        }
      }
    None => ()
  }
  selected
}

///|
fn set_try_add(set : Set[String], item : String) -> Bool {
  let before = set.length()
  set.add(item)
  set.length() != before
}

///|
fn collect_module_called_function_ids(
  module_ : @ir.BoundModule,
  index : ReachabilityIndex,
  result : ReachableFunctionWorklist,
) -> Unit {
  for function in module_.functions {
    collect_function_called_function_ids(function, index, result)
  }
  for global in module_.globals {
    collect_expr_called_function_ids(global.value, index, result)
  }
}

///|
fn collect_module_referenced_global_ids(
  module_ : @ir.BoundModule,
  index : ReachabilityIndex,
  result : ReachableGlobalWorklist,
) -> Unit {
  for function in module_.functions {
    collect_function_referenced_global_ids(function, index, result)
  }
  for global in module_.globals {
    collect_expr_referenced_global_ids(global.value, index, result)
  }
}

///|
fn collect_function_referenced_global_ids(
  function : @ir.BoundFunction,
  index : ReachabilityIndex,
  result : ReachableGlobalWorklist,
) -> Unit {
  collect_expr_referenced_global_ids(function.body, index, result)
}

///|
fn collect_expr_referenced_global_ids(
  expr : @ir.BoundExpr,
  index : ReachabilityIndex,
  result : ReachableGlobalWorklist,
) -> Unit {
  match expr {
    @ir.BoundExpr::Name(symbol_id, _, _, _) =>
      if symbol_id.has_prefix("global:") {
        push_reachable_global_unique(result, index, symbol_id)
      }
    @ir.BoundExpr::FunctionRef(_, _, _, _)
    | @ir.BoundExpr::IntLiteral(_, _, _)
    | @ir.BoundExpr::FloatLiteral(_, _, _)
    | @ir.BoundExpr::CharLiteral(_, _, _)
    | @ir.BoundExpr::StringLiteral(_, _, _)
    | @ir.BoundExpr::BytesLiteral(_, _, _)
    | @ir.BoundExpr::BoolLiteral(_, _, _)
    | @ir.BoundExpr::UnitLiteral(_, _)
    | @ir.BoundExpr::OptionNone(_, _)
    | @ir.BoundExpr::Panic(_, _)
    | @ir.BoundExpr::Error(_, _, _) => ()
    @ir.BoundExpr::TupleLiteral(items, _, _) =>
      for item in items {
        collect_expr_referenced_global_ids(item, index, result)
      }
    @ir.BoundExpr::LocalFunction(local_function, body, _, _) => {
      collect_expr_referenced_global_ids(local_function.body, index, result)
      collect_expr_referenced_global_ids(body, index, result)
    }
    @ir.BoundExpr::ArrayLiteral(items, _, _) =>
      for item in items {
        collect_array_element_referenced_global_ids(item, index, result)
      }
    @ir.BoundExpr::TupleGet(target, _, _, _)
    | @ir.BoundExpr::OptionSome(target, _, _)
    | @ir.BoundExpr::Conversion(_, target, _, _)
    | @ir.BoundExpr::Unary(_, target, _, _, _, _) =>
      collect_expr_referenced_global_ids(target, index, result)
    @ir.BoundExpr::LocalLet(local_binding, body, _, _) => {
      collect_expr_referenced_global_ids(local_binding.value, index, result)
      collect_expr_referenced_global_ids(body, index, result)
    }
    @ir.BoundExpr::Sequence(first, body, _, _) => {
      collect_expr_referenced_global_ids(first, index, result)
      collect_expr_referenced_global_ids(body, index, result)
    }
    @ir.BoundExpr::Call(_, _, _, args, _, _, _) =>
      for arg in args {
        collect_expr_referenced_global_ids(arg, index, result)
      }
    @ir.BoundExpr::FunctionValueCall(callee, args, _, _) => {
      collect_expr_referenced_global_ids(callee, index, result)
      for arg in args {
        collect_expr_referenced_global_ids(arg, index, result)
      }
    }
    @ir.BoundExpr::Lambda(_, body, _, _) =>
      collect_expr_referenced_global_ids(body, index, result)
    @ir.BoundExpr::IndexGet(target, index_expr, _, _) => {
      collect_expr_referenced_global_ids(target, index, result)
      collect_expr_referenced_global_ids(index_expr, index, result)
    }
    @ir.BoundExpr::EnumCase(_, _, _, args, _, _) =>
      for arg in args {
        collect_expr_referenced_global_ids(arg, index, result)
      }
    @ir.BoundExpr::FieldAccess(target, _, _, _) =>
      collect_expr_referenced_global_ids(target, index, result)
    @ir.BoundExpr::FieldAssign(target, _, value, _, _) => {
      collect_expr_referenced_global_ids(target, index, result)
      collect_expr_referenced_global_ids(value, index, result)
    }
    @ir.BoundExpr::Assign(_, value, _, _) =>
      collect_expr_referenced_global_ids(value, index, result)
    @ir.BoundExpr::IndexAssign(target, index_expr, value, _, _) => {
      collect_expr_referenced_global_ids(target, index, result)
      collect_expr_referenced_global_ids(index_expr, index, result)
      collect_expr_referenced_global_ids(value, index, result)
    }
    @ir.BoundExpr::If(condition, then_expr, else_expr, _, _) => {
      collect_expr_referenced_global_ids(condition, index, result)
      collect_expr_referenced_global_ids(then_expr, index, result)
      collect_expr_referenced_global_ids(else_expr, index, result)
    }
    @ir.BoundExpr::TraitMethodCall(receiver, _, _, _, args, _, _, _) => {
      collect_expr_referenced_global_ids(receiver, index, result)
      for arg in args {
        collect_expr_referenced_global_ids(arg, index, result)
      }
    }
    @ir.BoundExpr::MapLiteral(entries, _, _) =>
      for entry in entries {
        collect_expr_referenced_global_ids(entry.key, index, result)
        collect_expr_referenced_global_ids(entry.value, index, result)
      }
    @ir.BoundExpr::StructLiteral(_, fields, _, _)
    | @ir.BoundExpr::StructUpdate(_, _, fields, _, _) =>
      for field in fields {
        collect_expr_referenced_global_ids(field.value, index, result)
      }
    @ir.BoundExpr::Binary(_, left, right, _, _, _, _, _, _) => {
      collect_expr_referenced_global_ids(left, index, result)
      collect_expr_referenced_global_ids(right, index, result)
    }
    @ir.BoundExpr::IsPattern(value, _, _, _) =>
      collect_expr_referenced_global_ids(value, index, result)
    @ir.BoundExpr::Match(value, arms, _, _) => {
      collect_expr_referenced_global_ids(value, index, result)
      for arm in arms {
        match arm.condition {
          Some(condition) =>
            collect_expr_referenced_global_ids(condition, index, result)
          None => ()
        }
        collect_expr_referenced_global_ids(arm.body, index, result)
      }
    }
    @ir.BoundExpr::Raise(value, _, _, _) =>
      collect_expr_referenced_global_ids(value, index, result)
    @ir.BoundExpr::TryCatch(body, arms, _, _) => {
      collect_expr_referenced_global_ids(body, index, result)
      for arm in arms {
        collect_expr_referenced_global_ids(arm.body, index, result)
      }
    }
    @ir.BoundExpr::Guard(condition, else_expr, _, _) => {
      collect_expr_referenced_global_ids(condition, index, result)
      collect_expr_referenced_global_ids(else_expr, index, result)
    }
    @ir.BoundExpr::While(condition, body, _, _) => {
      collect_expr_referenced_global_ids(condition, index, result)
      collect_expr_referenced_global_ids(body, index, result)
    }
    @ir.BoundExpr::ForRange(loop_, _, _) => {
      collect_expr_referenced_global_ids(loop_.start, index, result)
      collect_expr_referenced_global_ids(loop_.end_, index, result)
      collect_expr_referenced_global_ids(loop_.body, index, result)
    }
    @ir.BoundExpr::ForIn(loop_, _, _) => {
      collect_expr_referenced_global_ids(loop_.iterator, index, result)
      for binding in loop_.bindings {
        collect_expr_referenced_global_ids(binding.value, index, result)
      }
      collect_expr_referenced_global_ids(loop_.body, index, result)
      match loop_.no_break {
        Some(no_break) =>
          collect_expr_referenced_global_ids(no_break, index, result)
        None => ()
      }
    }
    @ir.BoundExpr::ForLoop(loop_, _, _) => {
      for binding in loop_.bindings {
        collect_expr_referenced_global_ids(binding.value, index, result)
      }
      match loop_.condition {
        Some(condition) =>
          collect_expr_referenced_global_ids(condition, index, result)
        None => ()
      }
      for update in loop_.updates {
        collect_expr_referenced_global_ids(update, index, result)
      }
      collect_expr_referenced_global_ids(loop_.body, index, result)
    }
    @ir.BoundExpr::Break(value, _, _) | @ir.BoundExpr::Return(value, _, _) =>
      match value {
        Some(item) => collect_expr_referenced_global_ids(item, index, result)
        None => ()
      }
    @ir.BoundExpr::Continue(values, _, _) =>
      for value in values {
        collect_expr_referenced_global_ids(value, index, result)
      }
  }
}

///|
fn collect_function_called_function_ids(
  function : @ir.BoundFunction,
  index : ReachabilityIndex,
  result : ReachableFunctionWorklist,
) -> Unit {
  collect_expr_called_function_ids(function.body, index, result)
}

///|
fn collect_array_element_referenced_global_ids(
  item : @ir.BoundArrayElement,
  index : ReachabilityIndex,
  result : ReachableGlobalWorklist,
) -> Unit {
  match item {
    @ir.BoundArrayElement::Value(value)
    | @ir.BoundArrayElement::Spread(value) =>
      collect_expr_referenced_global_ids(value, index, result)
  }
}

///|
fn collect_array_element_called_function_ids(
  item : @ir.BoundArrayElement,
  index : ReachabilityIndex,
  result : ReachableFunctionWorklist,
) -> Unit {
  match item {
    @ir.BoundArrayElement::Value(value)
    | @ir.BoundArrayElement::Spread(value) =>
      collect_expr_called_function_ids(value, index, result)
  }
}

///|
fn collect_expr_called_function_ids(
  expr : @ir.BoundExpr,
  index : ReachabilityIndex,
  result : ReachableFunctionWorklist,
) -> Unit {
  match expr {
    @ir.BoundExpr::Name(_, _, _, _)
    | @ir.BoundExpr::IntLiteral(_, _, _)
    | @ir.BoundExpr::FloatLiteral(_, _, _)
    | @ir.BoundExpr::CharLiteral(_, _, _)
    | @ir.BoundExpr::StringLiteral(_, _, _)
    | @ir.BoundExpr::BytesLiteral(_, _, _)
    | @ir.BoundExpr::BoolLiteral(_, _, _)
    | @ir.BoundExpr::UnitLiteral(_, _)
    | @ir.BoundExpr::OptionNone(_, _)
    | @ir.BoundExpr::Panic(_, _)
    | @ir.BoundExpr::Error(_, _, _) => ()
    @ir.BoundExpr::FunctionRef(function_id, _, _, _) =>
      push_reachable_function_unique(result, index, function_id)
    @ir.BoundExpr::TupleLiteral(items, _, _) =>
      for item in items {
        collect_expr_called_function_ids(item, index, result)
      }
    @ir.BoundExpr::LocalFunction(local_function, body, _, _) => {
      collect_expr_called_function_ids(local_function.body, index, result)
      collect_expr_called_function_ids(body, index, result)
    }
    @ir.BoundExpr::ArrayLiteral(items, _, _) =>
      for item in items {
        collect_array_element_called_function_ids(item, index, result)
      }
    @ir.BoundExpr::TupleGet(target, _, _, _)
    | @ir.BoundExpr::OptionSome(target, _, _) =>
      collect_expr_called_function_ids(target, index, result)
    @ir.BoundExpr::Conversion(conversion, target, type_, _) => {
      collect_expr_called_function_ids(target, index, result)
      if conversion == "ConcreteToTraitObject" {
        collect_default_impl_method_function_ids(
          @ir.expr_type(target),
          type_,
          index,
          result,
        )
      }
    }
    @ir.BoundExpr::Unary(_, target, selected_function_id, _, _, _) => {
      if selected_function_id.length() > 0 {
        push_reachable_function_unique(result, index, selected_function_id)
      }
      collect_expr_called_function_ids(target, index, result)
    }
    @ir.BoundExpr::LocalLet(local_binding, body, _, _) => {
      collect_expr_called_function_ids(local_binding.value, index, result)
      collect_expr_called_function_ids(body, index, result)
    }
    @ir.BoundExpr::Sequence(first, body, _, _) => {
      collect_expr_called_function_ids(first, index, result)
      collect_expr_called_function_ids(body, index, result)
    }
    @ir.BoundExpr::Call(function_id, _, _, args, _, _, _) => {
      push_reachable_function_unique(result, index, function_id)
      for arg in args {
        collect_expr_called_function_ids(arg, index, result)
      }
    }
    @ir.BoundExpr::FunctionValueCall(callee, args, _, _) => {
      collect_expr_called_function_ids(callee, index, result)
      for arg in args {
        collect_expr_called_function_ids(arg, index, result)
      }
    }
    @ir.BoundExpr::Lambda(_, body, _, _) =>
      collect_expr_called_function_ids(body, index, result)
    @ir.BoundExpr::IndexGet(target, index_expr, _, _) => {
      collect_expr_called_function_ids(target, index, result)
      collect_expr_called_function_ids(index_expr, index, result)
    }
    @ir.BoundExpr::EnumCase(_, _, _, args, _, _) =>
      for arg in args {
        collect_expr_called_function_ids(arg, index, result)
      }
    @ir.BoundExpr::FieldAccess(target, _, _, _) =>
      collect_expr_called_function_ids(target, index, result)
    @ir.BoundExpr::FieldAssign(target, _, value, _, _) => {
      collect_expr_called_function_ids(target, index, result)
      collect_expr_called_function_ids(value, index, result)
    }
    @ir.BoundExpr::Assign(_, value, _, _) =>
      collect_expr_called_function_ids(value, index, result)
    @ir.BoundExpr::IndexAssign(target, index_expr, value, _, _) => {
      collect_expr_called_function_ids(target, index, result)
      collect_expr_called_function_ids(index_expr, index, result)
      collect_expr_called_function_ids(value, index, result)
    }
    @ir.BoundExpr::If(condition, then_expr, else_expr, _, _) => {
      collect_expr_called_function_ids(condition, index, result)
      collect_expr_called_function_ids(then_expr, index, result)
      collect_expr_called_function_ids(else_expr, index, result)
    }
    @ir.BoundExpr::TraitMethodCall(receiver, _, _, _, args, dispatch, _, _) => {
      collect_expr_called_function_ids(receiver, index, result)
      for arg in args {
        collect_expr_called_function_ids(arg, index, result)
      }
      match dispatch {
        @ir.BoundTraitDispatch::ConcreteImpl(function_id, _) =>
          push_reachable_function_unique(result, index, function_id)
        _ => ()
      }
    }
    @ir.BoundExpr::MapLiteral(entries, _, _) =>
      for entry in entries {
        collect_expr_called_function_ids(entry.key, index, result)
        collect_expr_called_function_ids(entry.value, index, result)
      }
    @ir.BoundExpr::StructLiteral(_, fields, _, _) =>
      for field in fields {
        collect_expr_called_function_ids(field.value, index, result)
      }
    @ir.BoundExpr::StructUpdate(_, base, fields, _, _) => {
      collect_expr_called_function_ids(base, index, result)
      for field in fields {
        collect_expr_called_function_ids(field.value, index, result)
      }
    }
    @ir.BoundExpr::Binary(_, left, right, selected_function_id, _, _, _, _, _) => {
      if selected_function_id.length() > 0 {
        push_reachable_function_unique(result, index, selected_function_id)
      }
      collect_expr_called_function_ids(left, index, result)
      collect_expr_called_function_ids(right, index, result)
    }
    @ir.BoundExpr::IsPattern(value, _, _, _) =>
      collect_expr_called_function_ids(value, index, result)
    @ir.BoundExpr::Match(value, arms, _, _) => {
      collect_expr_called_function_ids(value, index, result)
      for arm in arms {
        match arm.condition {
          Some(condition) =>
            collect_expr_called_function_ids(condition, index, result)
          None => ()
        }
        collect_expr_called_function_ids(arm.body, index, result)
      }
    }
    @ir.BoundExpr::Raise(value, _, _, _) =>
      collect_expr_called_function_ids(value, index, result)
    @ir.BoundExpr::TryCatch(body, arms, _, _) => {
      collect_expr_called_function_ids(body, index, result)
      for arm in arms {
        collect_expr_called_function_ids(arm.body, index, result)
      }
    }
    @ir.BoundExpr::Guard(condition, else_expr, _, _) => {
      collect_expr_called_function_ids(condition, index, result)
      collect_expr_called_function_ids(else_expr, index, result)
    }
    @ir.BoundExpr::While(condition, body, _, _) => {
      collect_expr_called_function_ids(condition, index, result)
      collect_expr_called_function_ids(body, index, result)
    }
    @ir.BoundExpr::ForRange(loop_, _, _) => {
      collect_expr_called_function_ids(loop_.start, index, result)
      collect_expr_called_function_ids(loop_.end_, index, result)
      collect_expr_called_function_ids(loop_.body, index, result)
    }
    @ir.BoundExpr::ForIn(loop_, _, _) => {
      collect_expr_called_function_ids(loop_.iterator, index, result)
      for binding in loop_.bindings {
        collect_expr_called_function_ids(binding.value, index, result)
      }
      collect_expr_called_function_ids(loop_.body, index, result)
      match loop_.no_break {
        Some(no_break) =>
          collect_expr_called_function_ids(no_break, index, result)
        None => ()
      }
    }
    @ir.BoundExpr::ForLoop(loop_, _, _) => {
      for binding in loop_.bindings {
        collect_expr_called_function_ids(binding.value, index, result)
      }
      match loop_.condition {
        Some(condition) =>
          collect_expr_called_function_ids(condition, index, result)
        None => ()
      }
      for update in loop_.updates {
        collect_expr_called_function_ids(update, index, result)
      }
      collect_expr_called_function_ids(loop_.body, index, result)
    }
    @ir.BoundExpr::Break(value, _, _) =>
      match value {
        Some(expr) => collect_expr_called_function_ids(expr, index, result)
        None => ()
      }
    @ir.BoundExpr::Continue(values, _, _) =>
      for value in values {
        collect_expr_called_function_ids(value, index, result)
      }
    @ir.BoundExpr::Return(value, _, _) =>
      match value {
        Some(expr) => collect_expr_called_function_ids(expr, index, result)
        None => ()
      }
  }
}

///|
fn collect_default_impl_method_function_ids(
  _self_type : @binding.TypeRef,
  target_type : @binding.TypeRef,
  index : ReachabilityIndex,
  result : ReachableFunctionWorklist,
) -> Unit {
  match target_type {
    @binding.TypeRef::TraitObject(trait_ref) =>
      match index.default_impl_method_functions.get(trait_ref.trait_.id) {
        Some(function_ids) =>
          for function_id in function_ids {
            push_reachable_function_unique(result, index, function_id)
          }
        None => ()
      }
    _ => ()
  }
}

///|
priv struct ImportedPackageGroup {
  import_ref : @binding.ImportRef
  sources : Array[@package.PackageSource]
}

///|
priv struct EmittedPackageItems {
  symbols : Array[@binding.Symbol]
  types : Array[@binding.TypeDefinition]
  traits : Array[@ir.BoundTrait]
  functions : Array[@ir.BoundFunction]
  globals : Array[@ir.BoundGlobal]
}

///|
fn group_imported_sources(
  imported_sources : Array[@package.PackageSource],
) -> Array[ImportedPackageGroup] {
  let groups : Array[ImportedPackageGroup] = []
  for source in imported_sources {
    match find_imported_group(groups, source.import_ref) {
      Some(index) => groups[index].sources.push(source)
      None => groups.push({ import_ref: source.import_ref, sources: [source] })
    }
  }
  groups
}

///|
fn reachable_imported_groups(
  extern_declaration_groups : Array[ImportedPackageGroup],
  implementation_groups : Array[ImportedPackageGroup],
) -> Array[ImportedPackageGroup] {
  let groups : Array[ImportedPackageGroup] = []
  for group in implementation_groups {
    push_imported_group_unique(groups, group)
  }
  for group in extern_declaration_groups {
    push_imported_group_unique(groups, group)
  }
  groups
}

///|
fn push_imported_group_unique(
  groups : Array[ImportedPackageGroup],
  group : ImportedPackageGroup,
) -> Unit {
  match find_imported_group(groups, group.import_ref) {
    Some(index) =>
      for source in group.sources {
        if !has_package_source(groups[index].sources, source.file_path) {
          groups[index].sources.push(source)
        }
      }
    None => groups.push(group)
  }
}

///|
fn has_package_source(
  sources : Array[@package.PackageSource],
  file_path : String,
) -> Bool {
  for source in sources {
    if source.file_path == file_path {
      return true
    }
  }
  false
}

///|
fn declaration_import_refs(
  manifest_imports : Array[@binding.ImportRef],
  imported_sources : Array[@package.PackageSource],
  imported_declaration_sources : Array[@package.PackageSource],
  imported_manifest_sources : Array[@package.SourceUnit],
) -> Array[@binding.ImportRef] {
  let imports : Array[@binding.ImportRef] = []
  for import_ref in manifest_imports {
    push_import_ref_unique(imports, import_ref)
  }
  for source in imported_manifest_sources {
    let manifest = @package.parse_moon_pkg(source.source, source.file_path)
    for import_ref in manifest.imports {
      push_import_ref_unique(imports, import_ref)
    }
  }
  for source in imported_declaration_sources {
    push_import_ref_unique(imports, source.import_ref)
  }
  for source in imported_sources {
    push_import_ref_unique(imports, source.import_ref)
  }
  imports
}

///|
fn push_import_ref_unique(
  imports : Array[@binding.ImportRef],
  import_ref : @binding.ImportRef,
) -> Unit {
  for existing in imports {
    if existing.alias_name == import_ref.alias_name &&
      existing.package_id == import_ref.package_id &&
      existing.module_path == import_ref.module_path {
      return
    }
  }
  imports.push(import_ref)
}

///|
fn find_imported_group(
  groups : Array[ImportedPackageGroup],
  import_ref : @binding.ImportRef,
) -> Int? {
  for i in 0..<groups.length() {
    let existing = groups[i].import_ref
    if existing.package_id == import_ref.package_id &&
      existing.module_path == import_ref.module_path {
      return Some(i)
    }
  }
  None
}

///|
fn parse_package_sources(
  sources : Array[@package.PackageSource],
  diagnostics : Array[@common.Diagnostic],
) -> @ast.Module {
  let module_ = empty_module()
  for source in sources {
    let file = @text.source_file(source.file_path, normalize_source_newlines(source.source))
    let parsed = @syntax.parse_source(file)
    for diagnostic in parsed.diagnostics {
      diagnostics.push(diagnostic)
    }
    append_module(module_, parsed.module_)
  }
  module_
}

///|
fn parse_declaration_package_sources(
  sources : Array[@package.PackageSource],
  diagnostics : Array[@common.Diagnostic],
) -> @ast.Module {
  let module_ = empty_module()
  for source in sources {
    let file = @text.source_file(source.file_path, normalize_source_newlines(source.source))
    let parsed = @syntax.parse_declaration_source(file)
    for diagnostic in parsed.diagnostics {
      diagnostics.push(diagnostic)
    }
    append_module(module_, parsed.module_)
  }
  module_
}

///|
fn parse_source_units(
  sources : Array[@package.SourceUnit],
  diagnostics : Array[@common.Diagnostic],
) -> @ast.Module {
  let module_ = empty_module()
  for source in sources {
    let file = @text.source_file(source.file_path, normalize_source_newlines(source.source))
    let parsed = @syntax.parse_source(file)
    for diagnostic in parsed.diagnostics {
      diagnostics.push(diagnostic)
    }
    append_module(module_, parsed.module_)
  }
  module_
}

///|
fn normalize_source_newlines(source : String) -> String {
  let mut i = 0
  let mut start = 0
  let len = source.length()
  let out = StringBuilder::new()
  let mut changed = false
  while i < len {
    if source[i] == '\r' {
      changed = true
      if start < i {
        out.write_stringview(source[start:i])
      }
      out.write_string("\n")
      i = if i + 1 < len && source[i + 1] == '\n' { i + 2 } else { i + 1 }
      start = i
    } else {
      i += 1
    }
  }
  if !changed {
    source
  } else {
    if start < len {
      out.write_stringview(source[start:])
    }
    out.to_string()
  }
}

///|
fn empty_module() -> @ast.Module {
  {
    usings: [],
    functions: [],
    structs: [],
    opaque_types: [],
    enums: [],
    traits: [],
    impls: [],
    globals: [],
  }
}

///|
fn append_module(target : @ast.Module, source : @ast.Module) -> Unit {
  for item in source.usings {
    target.usings.push(item)
  }
  for item in source.functions {
    target.functions.push(item)
  }
  for item in source.structs {
    target.structs.push(item)
  }
  for item in source.opaque_types {
    target.opaque_types.push(item)
  }
  for item in source.enums {
    target.enums.push(item)
  }
  for item in source.traits {
    target.traits.push(item)
  }
  for item in source.impls {
    target.impls.push(item)
  }
  for item in source.globals {
    target.globals.push(item)
  }
}

///|
fn should_emit_imported_group(imported : ImportedPackageGroup) -> Bool {
  for source in imported.sources {
    if !source.file_path.has_suffix(".mbti") {
      return true
    }
  }
  false
}

///|
fn merge_imported_implementations(
  bound : @ir.BoundModule,
  imported : EmittedPackageItems,
) -> @ir.BoundModule {
  for symbol in bound.symbols {
    push_symbol_unique(imported.symbols, symbol)
  }
  for type_def in bound.types {
    push_type_definition_unique(imported.types, type_def)
  }
  for trait_def in bound.traits {
    push_trait_unique(imported.traits, trait_def)
  }
  for function in bound.functions {
    push_function_unique(imported.functions, function)
  }
  for global in bound.globals {
    push_global_unique(imported.globals, global)
  }
  {
    schema: bound.schema,
    module_name: bound.module_name,
    symbols: imported.symbols,
    types: imported.types,
    traits: imported.traits,
    used_trait_impls: bound.used_trait_impls,
    functions: imported.functions,
    globals: imported.globals,
    default_arguments: bound.default_arguments,
    diagnostics: bound.diagnostics,
  }
}

///|
fn push_symbol_unique(
  items : Array[@binding.Symbol],
  item : @binding.Symbol,
) -> Unit {
  for existing in items {
    if existing.id == item.id {
      return
    }
  }
  items.push(item)
}

///|
fn push_type_definition_unique(
  items : Array[@binding.TypeDefinition],
  item : @binding.TypeDefinition,
) -> Unit {
  let (symbol, _) = @binding.type_definition_header(item)
  for i in 0..<items.length() {
    let existing = items[i]
    let (existing_symbol, _) = @binding.type_definition_header(existing)
    if existing_symbol.id == symbol.id {
      if type_definition_rank(item) > type_definition_rank(existing) {
        items[i] = item
      }
      return
    }
  }
  items.push(item)
}

///|
fn type_definition_rank(type_def : @binding.TypeDefinition) -> Int {
  match type_def {
    @binding.TypeDefinition::Struct(def) => 3 + def.fields.length()
    @binding.TypeDefinition::Enum(def) => 3 + def.variants.length()
    @binding.TypeDefinition::Opaque(_) => 1
  }
}

///|
fn push_trait_unique(
  items : Array[@ir.BoundTrait],
  item : @ir.BoundTrait,
) -> Unit {
  for existing in items {
    if existing.symbol.id == item.symbol.id {
      return
    }
  }
  items.push(item)
}

///|
fn push_trait_definition_unique(
  items : Array[@semantic.TraitDefinition],
  item : @semantic.TraitDefinition,
) -> Unit {
  for existing in items {
    if existing.symbol.id == item.symbol.id {
      return
    }
  }
  items.push(item)
}

///|
fn push_impl_definition_unique(
  items : Array[@semantic.ImplDefinition],
  item : @semantic.ImplDefinition,
) -> Unit {
  for i in 0..<items.length() {
    if items[i].impl_id == item.impl_id {
      for impl_method in item.methods {
        merge_imported_impl_method(items[i].methods, impl_method)
      }
      return
    }
  }
  items.push(item)
}

///|
fn merge_imported_impl_method(
  methods : Array[@semantic.ImplMethodSignature],
  impl_method : @semantic.ImplMethodSignature,
) -> Unit {
  for i in 0..<methods.length() {
    if methods[i].name != impl_method.name {
      continue
    }
    if methods[i].function_id == impl_method.function_id {
      return
    }
    if methods[i].body is @semantic.ImplMethodBody::DefaultMethod &&
      !(impl_method.body is @semantic.ImplMethodBody::DefaultMethod) {
      methods[i] = impl_method
      return
    }
    if !(methods[i].body is @semantic.ImplMethodBody::DefaultMethod) &&
      impl_method.body is @semantic.ImplMethodBody::DefaultMethod {
      return
    }
  }
  for existing in methods {
    if existing.name == impl_method.name &&
      existing.function_id == impl_method.function_id {
      return
    }
  }
  methods.push(impl_method)
}

///|
fn push_function_signature_unique(
  items : Array[@binding.FunctionSignature],
  item : @binding.FunctionSignature,
) -> Unit {
  for i in 0..<items.length() {
    let existing = items[i]
    if existing.function_id == item.function_id {
      if function_signature_rank(item) > function_signature_rank(existing) {
        items[i] = item
      }
      return
    }
  }
  items.push(item)
}

///|
fn function_signature_rank(signature : @binding.FunctionSignature) -> Int {
  match signature.intrinsic {
    Some(_) => 2
    None => 1
  }
}

///|
fn push_function_unique(
  items : Array[@ir.BoundFunction],
  item : @ir.BoundFunction,
) -> Unit {
  for existing in items {
    if existing.symbol_id == item.symbol_id {
      return
    }
  }
  items.push(item)
}

///|
fn push_string_unique(items : Array[String], item : String) -> Unit {
  for existing in items {
    if existing == item {
      return
    }
  }
  items.push(item)
}

///|
fn push_global_unique(
  items : Array[@ir.BoundGlobal],
  item : @ir.BoundGlobal,
) -> Unit {
  for existing in items {
    if existing.symbol_id == item.symbol_id {
      return
    }
  }
  items.push(item)
}

///|
fn push_global_signature_unique(
  items : Array[@binding.GlobalSignature],
  item : @binding.GlobalSignature,
) -> Unit {
  for existing in items {
    if existing.symbol.id == item.symbol.id {
      return
    }
  }
  items.push(item)
}

///|
fn push_default_argument_unique(
  items : Array[@binding.DefaultArgument],
  item : @binding.DefaultArgument,
) -> Unit {
  for existing in items {
    if existing.id == item.id {
      return
    }
  }
  items.push(item)
}
