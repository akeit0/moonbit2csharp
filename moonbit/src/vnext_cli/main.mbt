///|
fn main {
  let args = @env.args()
  if args.length() < 2 {
    println(
      "usage: moon -C moonbit run ./src/vnext_cli -- <input.mbt> [module-name] [moon.pkg imported1.mbt ...]",
    )
  } else {
    let path = args[1]
    let module_name = if args.length() > 2 { args[2] } else { "Main" }
    let source = read_text_file(path)
    if args.length() > 3 {
      let moon_pkg_path = args[3]
      let moon_pkg_source = read_text_file(moon_pkg_path)
      let manifest = @package.parse_moon_pkg(moon_pkg_source, moon_pkg_path)
      let local_sources : Array[@package.SourceUnit] = [
        { file_path: path, source },
      ]
      let imported_sources : Array[@package.PackageSource] = []
      let imported_declaration_sources : Array[@package.PackageSource] = []
      let imported_manifest_sources : Array[@package.SourceUnit] = []
      let mut i = 4
      let mut positional_index = 0
      while i < args.length() {
        if args[i] == "--source" {
          if i + 1 >= args.length() {
            println("missing --source <file>")
            return
          }
          let source_path = args[i + 1]
          local_sources.push({
            file_path: source_path,
            source: read_text_file(source_path),
          })
          i = i + 2
          continue
        }
        if args[i] == "--import-source" {
          if i + 4 >= args.length() {
            println(
              "missing --import-source <alias> <package-id> <module-path> <file>",
            )
            return
          }
          let alias_name = args[i + 1]
          let package_id = args[i + 2]
          let module_path = args[i + 3]
          let imported_path = args[i + 4]
          imported_sources.push({
            import_ref: { alias_name, package_id, module_path },
            file_path: imported_path,
            source: read_text_file(imported_path),
          })
          i = i + 5
          continue
        }
        if args[i] == "--import-manifest" {
          if i + 1 >= args.length() {
            println("missing --import-manifest <file>")
            return
          }
          let manifest_path = args[i + 1]
          imported_manifest_sources.push({
            file_path: manifest_path,
            source: read_text_file(manifest_path),
          })
          i = i + 2
          continue
        }
        if args[i] == "--import-declaration-source" {
          if i + 4 >= args.length() {
            println(
              "missing --import-declaration-source <alias> <package-id> <module-path> <file>",
            )
            return
          }
          let alias_name = args[i + 1]
          let package_id = args[i + 2]
          let module_path = args[i + 3]
          let imported_path = args[i + 4]
          imported_declaration_sources.push({
            import_ref: { alias_name, package_id, module_path },
            file_path: imported_path,
            source: read_text_file(imported_path),
          })
          i = i + 5
          continue
        }
        let import_index = positional_index
        let imported_path = args[i]
        let imported_source = read_text_file(imported_path)
        match
          import_ref_for_source(
            manifest.imports,
            imported_source,
            imported_path,
          ) {
          Some(import_ref) =>
            imported_sources.push({
              import_ref,
              file_path: imported_path,
              source: imported_source,
            })
          None =>
            if import_index < manifest.imports.length() {
              let import_ref = manifest.imports[import_index]
              imported_sources.push({
                import_ref,
                file_path: imported_path,
                source: imported_source,
              })
            }
        }
        positional_index = positional_index + 1
        i = i + 1
      }
      emit_compile_result(
        @pipeline.compile_package_sources_with_manifests_to_json_profiled(
          local_sources, module_name, moon_pkg_source, moon_pkg_path, imported_sources,
          imported_declaration_sources, imported_manifest_sources,
        ),
      )
    } else {
      emit_compile_result(
        @pipeline.compile_package_sources_with_manifests_to_json_profiled(
          [{ file_path: path, source }],
          module_name,
          "import {\n  \"moonbitlang/core/builtin\" @builtin,\n  \"moonbitlang/core/abort\" @abort,\n}\n",
          "moon.pkg",
          [],
          default_core_declaration_sources(),
          [],
        ),
      )
    }
  }
}

///|
fn emit_compile_result(result : @pipeline.ProfiledCompileResult) -> Unit {
  match @env.get_env_var("MOONBIT2CSHARP_VNEXT_PROFILE") {
    Some(value) =>
      if value == "1" || value == "true" || value == "TRUE" {
        println("vnext-profile: " + result.profile_json)
      }
    None => ()
  }
  println(result.ir_json)
}

///|
fn read_text_file(path : String) -> String {
  @fs.read_file_to_string(path) catch {
    error => abort("failed to read file " + path + ": " + error.to_string())
  }
}

///|
fn default_core_declaration_sources() -> Array[@package.PackageSource] {
  let result : Array[@package.PackageSource] = []
  let import_ref : @binding.ImportRef = {
    alias_name: "builtin",
    package_id: "pkg:moonbitlang/core/builtin",
    module_path: "moonbitlang/core/builtin",
  }
  let abort_import_ref : @binding.ImportRef = {
    alias_name: "abort",
    package_id: "pkg:moonbitlang/core/abort",
    module_path: "moonbitlang/core/abort",
  }
  result.push({
    import_ref: abort_import_ref,
    file_path: "../moonbitlang/core/abort/pkg.mbti",
    source: read_text_file("../moonbitlang/core/abort/pkg.mbti"),
  })
  for
    path in [
      "../moonbitlang/core/builtin/traits.mbt", "../moonbitlang/core/builtin/hasher.mbt",
      "../moonbitlang/core/builtin/intrinsics.mbt", "../moonbitlang/core/builtin/console.mbt",
      "../moonbitlang/core/builtin/failure.mbt", "../moonbitlang/core/builtin/string.mbt",
      "../moonbitlang/core/builtin/char.mbt", "../moonbitlang/core/builtin/json.mbt",
      "../moonbitlang/core/builtin/uint16_char.mbt", "overrides/core_arraycore_csharp.mbt",
      "overrides/core_arrayview_csharp.mbt", "overrides/core_arrayview_intrinsics.mbt",
      "overrides/core_autoloc_csharp.mbt", "overrides/core_builtin_array_methods_csharp.mbt",
      "overrides/core_builtin_char_hash_csharp.mbt", "overrides/core_builtin_double_round_csharp.mbt",
      "overrides/core_builtin_string_methods_csharp.mbt", "overrides/core_builtin_to_string_csharp.mbt",
      "overrides/core_bytesview_csharp.mbt", "overrides/core_double.mbt",
      "overrides/core_env_env_csharp.mbt", "overrides/core_float_round_csharp.mbt",
      "overrides/core_intrinsics_csharp.mbt", "overrides/core_iterable.mbt",
      "overrides/core_linked_hash_map_csharp.mbt", "overrides/core_option_csharp.mbt",
      "overrides/core_stringbuilder_csharp.mbt", "overrides/core_stringview_csharp.mbt",
      "overrides/core_traits_csharp.mbt", "overrides/core_uint64_intrinsics_csharp.mbt",
      "overrides/core_uint64_operator_intrinsics_csharp.mbt",
    ] {
    result.push({ import_ref, file_path: path, source: read_text_file(path) })
  }
  let debug_import_ref : @binding.ImportRef = {
    alias_name: "debug",
    package_id: "pkg:moonbitlang/core/debug",
    module_path: "moonbitlang/core/debug",
  }
  result.push({
    import_ref: debug_import_ref,
    file_path: "../moonbitlang/core/debug/pkg.generated.mbti",
    source: read_text_file("../moonbitlang/core/debug/pkg.generated.mbti"),
  })
  let set_import_ref : @binding.ImportRef = {
    alias_name: "set",
    package_id: "pkg:moonbitlang/core/set",
    module_path: "moonbitlang/core/set",
  }
  result.push({
    import_ref: set_import_ref,
    file_path: "../moonbitlang/core/set/pkg.generated.mbti",
    source: read_text_file("../moonbitlang/core/set/pkg.generated.mbti"),
  })
  let ref_import_ref : @binding.ImportRef = {
    alias_name: "ref",
    package_id: "pkg:moonbitlang/core/ref",
    module_path: "moonbitlang/core/ref",
  }
  result.push({
    import_ref: ref_import_ref,
    file_path: "overrides/core_ref_csharp.mbt",
    source: read_text_file("overrides/core_ref_csharp.mbt"),
  })
  let prelude_import_ref : @binding.ImportRef = {
    alias_name: "prelude",
    package_id: "pkg:moonbitlang/core/prelude",
    module_path: "moonbitlang/core/prelude",
  }
  result.push({
    import_ref: prelude_import_ref,
    file_path: "overrides/core_prelude_csharp.mbt",
    source: read_text_file("overrides/core_prelude_csharp.mbt"),
  })
  result
}

///|
fn import_ref_for_source(
  imports : Array[@binding.ImportRef],
  source : String,
  file_path : String,
) -> @binding.ImportRef? {
  match @package.package_name_from_source(source, file_path) {
    Some(package_name) => {
      let package_id = "pkg:" + package_name
      for import_ref in imports {
        if import_ref.package_id == package_id ||
          import_ref.module_path == package_name {
          return Some(import_ref)
        }
      }
      None
    }
    None => None
  }
}
