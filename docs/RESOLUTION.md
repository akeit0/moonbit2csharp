# vnext self-trainspile resolution notes

## Incident summary

The vnext pipeline log shows a short set of root causes that are primarily **resolution-layer mismatches** in the vnext frontend context:

1. **Container constructor resolution mismatch**: `Set([])` / `Map([])` is valid source syntax, but resolution is failing in this build path.
2. **Core/stdlib surface mismatch**: `@env.now`, `String`/`StringView` primitives, and helper methods are resolving through different names/signatures in current toolchain usage.
3. **`binding` helper contract mismatch**: `@binding.*` references in `semantic_core` are resolving to unexpected forms in this frontend run.

These appear to be the first-order blockers; remaining `None`/trait resolution errors should reduce significantly after they are fixed.

## Proposed resolution strategy

### 1) Keep container notation, fix symbol resolution

- Do not change `Set([])` / `Map([])` usage.
- Verify whether the failure is caused by:
  - missing module import (`moon.pkg`) for container/type-helper namespaces,
  - missing qualification (`@set.Set`, `@map.Map`) in the vnext compile context,
  - or changed exported symbol shape between toolchain/compiler versions.
- Add a minimal reproduction file and compile in the same pipeline mode to isolate which symbol table differs.

### 2) `env.now` migration

- Treat `env.now` as a resolution contract issue first: confirm the active env namespace/API in this pipeline mode.
- Keep timestamp call shape localized in one helper function in `pipeline`.
- If `env` is no longer the expected namespace, switch only the import/qualified call path rather than algorithm changes.

### 3) String/`StringView` primitive migration

- Introduce/adjust helper wrappers for:
  - index access (`unsafe_get`-style)
  - safe/explicit slicing
  - numeric conversion helpers if required by upstream changes
- Replace direct index/slice expressions in `syntax/lexer`, `syntax/parser`, `syntax/expr_parser`, and `json/writer` with helper-backed operations.
- Keep behavior unchanged: tokenization and JSON escaping should preserve existing semantics.

### 4) `binding` constructor resolution

- Keep the current `builtin_types` intent unchanged.
- Confirm whether `@binding.*` entries are:
  - values,
  - functions,
  - or names requiring qualification/import adjustment in this frontend invocation.
- Update references in the same behavior while matching the actual resolved symbol form.
- Preserve all fallback behavior in constructor lookup.

### 5) Follow-on typing cleanup (after P0 passes)

- Rerun the pipeline and isolate secondary failures.
- Fix `None` handling and trait method resolution in parser/sema only if still present after API migrations.
- Reclassify these as either:
  - P1 follow-on cleanup, or
  - separate compatibility issues if they remain isolated after migration.

## Verification steps

1. Reproduce a clean vnext pipeline run and save fresh output.
2. Confirm P0 issues disappear in `artifacts\vnext_pipeline\build.log`.
3. Re-run pipeline for a second pass and resolve P1 items only if they still reproduce.

## Notes for implementation review

- TODO/RESOLUTION should track issue buckets, not raw line dumps.
- Keep `Set([])` / `Map([])` untouched unless upstream confirms they become invalid.
- Keep notes focused on:
  - what changed,
  - which resolution contract was corrected (imports/namespace/call shape),
  - and residual failures after each pass.
