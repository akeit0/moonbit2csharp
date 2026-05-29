# vnext self-trainspile blocker list (from `artifacts\vnext_pipeline\build.log`)

## P0 blockers (must fix first)

- [ ] **Fix collection constructor resolution (`Set` / `Map`) without changing syntax**
  - Impacted areas: `pipeline`, `binding/model`, `semantic_core/model`, `sema/argument_planning`.
  - Root problem is symbol resolution in vnext frontend mode (the notation is valid MoonBit), not source syntax.
  - Failure signals: unresolved call and arity/type errors during frontend resolution.

- [ ] **Align time API in `pipeline`**
  - Impacted area: `pipeline`.
  - Root problem: `env.now` package call no longer resolves in current toolchain.
  - Failure signals: unresolved package call + `UInt64` type mismatch at subtraction sites.

- [ ] **Align `String`/`StringView` primitive usage**
  - Impacted areas: `syntax/lexer`, `syntax/parser`, `syntax/expr_parser`, `semantic_core/index`, `json/writer`.
  - Root problem: index/slice and trait helper usage is using an older compatibility shape.
  - Failure signals: unsupported index target / unsupported binary operator / char pattern mismatches / invalid branch typing.

- [ ] **Align `binding` type-constructor references**
  - Impacted area: `semantic_core/builtin_types`.
  - Root problem: `@binding.array_type`-style package values are no longer accepted directly in this position.
  - Failure signals: unknown package values for `array_type`, `fixed_array_type`, `array_view_type`, `option_type`, `map_type`.

## P1 blockers (likely follow-on)

- [ ] **Reconcile parser/semantic `None`/`Error` typing**
  - Impacted areas: `syntax/parser`, `syntax/expr_parser`, `sema/expr_binding`, `sema/match_binding`.
  - Root problem: downstream type-shape erosion after earlier API mismatches.

- [ ] **Reconcile trait-method and type-resolution surfaces**
  - Impacted areas: `sema/using_declarations`, `sema/trait_method_binding`, `sema/type_resolution`, `sema/type_declarations`.
  - Root problem: trait signatures and helper resolution are inconsistent with current APIs after the above breaks.

## Working rule

- Resolve all P0 blockers before rerunning `artifacts\vnext_pipeline\build.log`.
- Re-scan diagnostics and keep this file updated as issues move from root-cause to resolved/cascade.
