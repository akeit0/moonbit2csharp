param(
    [string]$GeneratedPipelineDirectory = "artifacts\vnext_pipeline_csharp_dev",
    [string]$WorkDirectory = "",
    [switch]$KeepWorkDirectory,
    [switch]$SkipBuild,
    [switch]$SkipMoonOracle
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Write-TextFile([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, $script:Utf8NoBom)
}

function Resolve-RepoPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

function Invoke-Checked([string]$Label, [scriptblock]$Command) {
    Write-Host "==> $Label"
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE"
    }
}

function New-ProofProject(
    [string]$Directory,
    [string]$GeneratedPipelineProject
) {
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null

    $projectSource = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <LangVersion>preview</LangVersion>
  </PropertyGroup>
  <ItemGroup>
    <ProjectReference Include="$GeneratedPipelineProject" />
  </ItemGroup>
</Project>
"@
    Write-TextFile (Join-Path $Directory "VNextPipelineProof.csproj") $projectSource

    $programSource = @'
using MbArraySource = Generated.MoonBit.Runtime.Array<Generated.MoonBit.Packages.moonbit2csharp.frontend.vnext.package.SourceUnit>;
using MbArrayPackage = Generated.MoonBit.Runtime.Array<Generated.MoonBit.Packages.moonbit2csharp.frontend.vnext.package.PackageSource>;
using SourceUnit = Generated.MoonBit.Packages.moonbit2csharp.frontend.vnext.package.SourceUnit;
using PackageSource = Generated.MoonBit.Packages.moonbit2csharp.frontend.vnext.package.PackageSource;
using Pipeline = Generated.MoonBit.Packages.moonbit2csharp.frontend.vnext.pipeline.pipeline;

if (args.Length != 3)
{
    Console.Error.WriteLine("usage: VNextPipelineProof <source.mbt> <module-name> <moon.pkg>");
    Environment.Exit(2);
}

var sourcePath = Path.GetFullPath(args[0]);
var moduleName = args[1];
var manifestPath = Path.GetFullPath(args[2]);
var source = File.ReadAllText(sourcePath);
var manifest = File.ReadAllText(manifestPath);

var json = Pipeline.compile_package_sources_with_manifests_to_json(
    new MbArraySource(new[] { new SourceUnit(sourcePath, source) }),
    moduleName,
    manifest,
    manifestPath,
    new MbArrayPackage(Array.Empty<PackageSource>()),
    new MbArrayPackage(Array.Empty<PackageSource>()),
    new MbArraySource(Array.Empty<SourceUnit>())
);

Console.Write(json);
'@
    Write-TextFile (Join-Path $Directory "Program.cs") $programSource
}

function Write-ProofCase(
    [string]$Directory,
    [string]$Name,
    [string]$Source
) {
    $caseDir = Join-Path $Directory $Name
    New-Item -ItemType Directory -Path $caseDir -Force | Out-Null
    $sourcePath = Join-Path $caseDir "$Name.mbt"
    $manifestPath = Join-Path $caseDir "moon.pkg"
    Write-TextFile $sourcePath $Source
    Write-TextFile $manifestPath ""
    [pscustomobject]@{
        Name = $Name
        SourcePath = $sourcePath
        ManifestPath = $manifestPath
        GeneratedJsonPath = Join-Path $caseDir "generated.json"
        MoonJsonPath = Join-Path $caseDir "moon.json"
    }
}

function Normalize-JsonText([string]$Path) {
    return (Get-Content -Raw -LiteralPath $Path).Trim()
}

$generatedDir = Resolve-RepoPath $GeneratedPipelineDirectory
$generatedProject = Join-Path $generatedDir "frontend.csproj"
if (!(Test-Path -LiteralPath $generatedProject)) {
    throw "generated pipeline project not found: $generatedProject"
}

if ([string]::IsNullOrWhiteSpace($WorkDirectory)) {
    $workRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("vnext-pipeline-self-check-" + [guid]::NewGuid())
} else {
    $workRoot = Resolve-RepoPath $WorkDirectory
}

New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
$succeeded = $false

try {
    if (!$SkipBuild) {
        Invoke-Checked "build generated pipeline" {
            dnrelay build $generatedProject
        }
    }

    $proofDir = Join-Path $workRoot "proof"
    New-ProofProject $proofDir $generatedProject
    $proofProject = Join-Path $proofDir "VNextPipelineProof.csproj"
    Invoke-Checked "build proof runner" {
        dnrelay build $proofProject
    }
    $proofDll = Join-Path $proofDir "bin\Debug\net10.0\VNextPipelineProof.dll"
    if (!(Test-Path -LiteralPath $proofDll)) {
        throw "proof runner output not found: $proofDll"
    }

    $casesDir = Join-Path $workRoot "cases"
    $cases = @()
    $cases += Write-ProofCase $casesDir "simple" @'
fn answer() -> Int { 42 }
'@
    $cases += Write-ProofCase $casesDir "tuple_loop" @'
fn probe(hash:Int)->Int {
  let (idx, psl) = for psl = 0, idx = hash {
    if psl > 1 { break (idx, psl) } else { continue psl + 1, idx + 1 }
  }
  idx + psl
}
'@

    foreach ($case in $cases) {
        Invoke-Checked "generated pipeline case '$($case.Name)'" {
            $output = dotnet $proofDll $case.SourcePath Demo $case.ManifestPath
            Write-TextFile $case.GeneratedJsonPath ($output -join [Environment]::NewLine)
        }

        if (!$SkipMoonOracle) {
            Invoke-Checked "moon vnext_cli oracle case '$($case.Name)'" {
                $output = moon -C moonbit run ./src/vnext_cli -- $case.SourcePath Demo $case.ManifestPath
                Write-TextFile $case.MoonJsonPath ($output -join [Environment]::NewLine)
            }

            $generatedJson = Normalize-JsonText $case.GeneratedJsonPath
            $moonJson = Normalize-JsonText $case.MoonJsonPath
            if ($generatedJson -ne $moonJson) {
                Write-Host "generated JSON differs from moon vnext_cli for case '$($case.Name)'"
                Write-Host "generated: $($case.GeneratedJsonPath)"
                Write-Host "moon:      $($case.MoonJsonPath)"
                exit 2
            }
        }
    }

    Write-Host "generated pipeline self-check passed"
    Write-Host "work directory: $workRoot"
    $succeeded = $true
} finally {
    if ($succeeded -and !$KeepWorkDirectory -and [string]::IsNullOrWhiteSpace($WorkDirectory)) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force
    }
}
