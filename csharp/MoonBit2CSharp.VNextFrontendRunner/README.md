# MoonBit2CSharp.VNextFrontendRunner

Standalone runner project for the generated C# vnext frontend.

This project is intentionally not added to `MoonBit2CSharp.slnx` because it
depends on a generated frontend project. Pass that dependency with the
`GeneratedVNextFrontendProject` MSBuild property.

## Build JIT runner

```powershell
dotnet publish csharp\MoonBit2CSharp.VNextFrontendRunner\MoonBit2CSharp.VNextFrontendRunner.csproj `
  -c Release `
  -p:GeneratedVNextFrontendProject=$PWD\artifacts\vnext_pipeline_csharp_dev\frontend.csproj `
  -o artifacts\vnext_pipeline_runner
```

Use it from the transpiler:

```powershell
dotnet run --project csharp\MoonBit2CSharp.Cli -- run samples\moonbit-project `
  --vnext-frontend csharp:artifacts\vnext_pipeline_runner\MoonBit2CSharp.VNextFrontendRunner.dll
```

## Build NativeAOT runner

```powershell
dotnet publish csharp\MoonBit2CSharp.VNextFrontendRunner\MoonBit2CSharp.VNextFrontendRunner.csproj `
  -c Release `
  -r win-x64 `
  -p:PublishAot=true `
  -p:GeneratedVNextFrontendProject=$PWD\artifacts\vnext_pipeline_csharp_dev\frontend.csproj `
  -o artifacts\vnext_pipeline_runner_aot
```

Use it from the transpiler:

```powershell
dotnet run --project csharp\MoonBit2CSharp.Cli -- run samples\moonbit-project `
  --vnext-frontend csharp:artifacts\vnext_pipeline_runner_aot\MoonBit2CSharp.VNextFrontendRunner.exe
```
