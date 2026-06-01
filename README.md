# MoonBit2CSharp

MoonBit2CSharp is a prototype MoonBit-to-C# transpiler with a compiler-style
pipeline. The current implementation is centered on the vnext frontend and C#
backend.

```text
MoonBit source
  -> vnext MoonBit frontend
  -> semantic JSON IR
  -> C# backend emitter
  -> generated C# project
  -> dotnet build/run
```

## Repository layout

```text
csharp/
  MoonBit2CSharp.Cli/          CLI entry point
  MoonBit2CSharp.Transpiler/   project orchestration, moon check, cache, frontend bridge
  MoonBit2CSharp.VNext.Backend/ semantic IR to C# emitter
  MoonBit2CSharp.Backend/      project file helpers and legacy backend pieces
  MoonBit.Runtime/             runtime project used by generated vnext projects

moonbit/
  src/vnext/                   MoonBit frontend implementation
  src/vnext_cli/               MoonBit CLI wrapper that emits semantic JSON IR
  builtin/overrides/           C#-targeted MoonBit builtin overrides

moonbitlang/
  core/                        official MoonBit core sources used as declarations/inputs

samples/
  simple_project/              small integration sample
  moonbit-project/             larger dependency-oriented sample

scripts/
  vnext-pipeline-self-check.ps1 generated C# pipeline proof tool

artifacts/
  vnext_pipeline_csharp_dev/   generated C# version of the vnext frontend
```

## Default transpilation path

The normal CLI path uses the MoonBit implementation of the vnext frontend:

```text
MoonBit project
  -> moon check
  -> moon -C moonbit run ./src/vnext_cli
  -> semantic JSON IR
  -> MoonBit2CSharp.VNext.Backend
  -> _build/csharp
  -> dotnet build/run
```

Example:

```powershell
dotnet run --project csharp\MoonBit2CSharp.Cli -- build samples\simple_project --no-cache
dotnet run --project csharp\MoonBit2CSharp.Cli -- run samples\simple_project
```

For local development in this repository, prefer `dnrelay` for CLI runs because it
captures logs under `csharp/.dnrelay/logs`:

```powershell
dnrelay run --project csharp\MoonBit2CSharp.Cli\MoonBit2CSharp.Cli.csproj -- build samples\simple_project --no-cache
```

## Optional generated frontend path

The CLI can optionally use a generated C# version of the vnext frontend instead
of invoking `moonbit/src/vnext_cli`.

```powershell
dotnet run --project csharp\MoonBit2CSharp.Cli -- build samples\simple_project --no-cache --generated-vnext-pipeline artifacts\vnext_pipeline_csharp_dev\frontend.csproj
```

This path is intended for self-hosting work:

```text
MoonBit project
  -> moon check
  -> temporary generated frontend host
  -> artifacts/vnext_pipeline_csharp_dev/frontend.csproj
  -> semantic JSON IR
  -> MoonBit2CSharp.VNext.Backend
  -> _build/csharp
```

The generated frontend host is created under the transpiler cache directory. It
builds separately and then runs with `--no-build` so stdout remains pure JSON IR.

## Caching

`run` and `build` use a run-project cache. If source inputs, MoonBit manifests,
builtin/declaration sources, runtime assemblies, or the selected generated
frontend project have not changed, the CLI can skip `moon check` and
transpilation and run the generated project with `--no-build`.

Useful options:

```text
--no-cache
--cache-dir <dir>
--release
--generated-vnext-pipeline <frontend.csproj>
```

`--release` forwards to generated project execution/build as `-c Release`.

## Output project shape

The generated C# project is an executable only for main-package or single-file
targets. Non-main package targets are generated as libraries.

MoonBit main-package detection uses package/module metadata, including:

```moonbit
options(
  "is-main": true,
)
```

Generated projects no longer reference the old `MoonBit.Runtime` project by
default. Runtime support needed by the emitted code is generated into
`moonbit_runtime.g.cs`, and generated package/type names follow MoonBit package
structure rather than hard-coded `MoonBit*` type prefixes.

## MoonBit frontend notes

The vnext frontend resolves:

```text
source files + moon.pkg/moon.mod manifests
  -> parsed AST
  -> declarations/import index
  -> type/function/trait resolution
  -> reachable semantic IR
```

Important implementation details:

- `moon.mod` and `moon.mod.json` are both supported.
- `moon.mod` uses MoonBit manifest syntax, not JSON.
- `options(source: "src")`, `options("source": ".")`, `options("source": "")`, and JSON `source` values are handled by module/package discovery.
- C# target builtin behavior is primarily modeled in MoonBit sources and builtin overrides; C# intrinsics should remain the small boundary for operations that cannot be expressed in MoonBit.
- Attribute parsing is lexer-level generic. Parser logic interprets attributes such as `#alias`, `#intrinsic`, `#cfg`, and `#valtype`.
- CRLF attribute lines are supported; `#cfg(...)` token text must not include `\r`.

## Generated C# pipeline proof

Use the self-check script to prove that the generated C# frontend can emit the
same semantic JSON as the MoonBit `vnext_cli` for small proof cases:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\vnext-pipeline-self-check.ps1
```

The script:

- builds `artifacts/vnext_pipeline_csharp_dev/frontend.csproj`;
- creates a temporary proof runner;
- runs proof cases through the generated C# pipeline;
- runs the same cases through MoonBit `vnext_cli`;
- compares normalized JSON.

## Regenerating the generated frontend artifact

Regenerate the current development C# frontend artifact with:

```powershell
dnrelay run --project csharp\MoonBit2CSharp.Cli\MoonBit2CSharp.Cli.csproj -- --project artifacts\vnext_pipeline_csharp_dev --csproj frontend --namespace Generated.MoonBit --runtime-namespace Generated.MoonBit.Runtime --no-cache moonbit\src\vnext\pipeline
```

Then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\vnext-pipeline-self-check.ps1
dnrelay run --project csharp\MoonBit2CSharp.Cli\MoonBit2CSharp.Cli.csproj -- build samples\simple_project --no-cache --generated-vnext-pipeline artifacts\vnext_pipeline_csharp_dev\frontend.csproj
```

## Development checks

Common focused checks:

```powershell
moon test ./src/vnext/syntax
dnrelay run --project csharp\MoonBit2CSharp.Cli\MoonBit2CSharp.Cli.csproj -- build samples\simple_project --no-cache
dnrelay run --project csharp\MoonBit2CSharp.Cli\MoonBit2CSharp.Cli.csproj -- build samples\simple_project --no-cache --generated-vnext-pipeline artifacts\vnext_pipeline_csharp_dev\frontend.csproj
```

Run `moon` commands from the `moonbit/` module root when using package-relative
paths such as `./src/vnext/syntax`.

## License

MIT
