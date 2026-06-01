using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace MoonBit2CSharp.Transpiler;

internal sealed record GeneratedVNextFrontendRequest(
    IReadOnlyList<GeneratedVNextSourceUnit> Sources,
    string ModuleName,
    string MoonPkgSource,
    string MoonPkgPath,
    IReadOnlyList<GeneratedVNextPackageSource> ImportedSources,
    IReadOnlyList<GeneratedVNextPackageSource> ImportedDeclarationSources,
    IReadOnlyList<GeneratedVNextSourceUnit> ImportedManifestSources
);

internal sealed record GeneratedVNextSourceUnit(string FilePath, string Source);

internal sealed record GeneratedVNextPackageSource(
    GeneratedVNextImportRef ImportRef,
    string FilePath,
    string Source
);

internal sealed record GeneratedVNextImportRef(
    string AliasName,
    string PackageId,
    string ModulePath
);

internal static class GeneratedVNextFrontendCompiler
{
    public static string Compile(
        GeneratedVNextFrontendRequest request,
        string generatedProjectPath,
        string cacheDirectory
    )
    {
        if (!File.Exists(generatedProjectPath))
            throw new FileNotFoundException(
                "generated vnext pipeline project not found",
                generatedProjectPath
            );

        var hostDirectory = HostDirectory(generatedProjectPath, cacheDirectory);
        WriteHost(hostDirectory, generatedProjectPath);

        var requestPath = Path.Combine(hostDirectory, "request.json");
        File.WriteAllText(requestPath, JsonSerializer.Serialize(request));

        var projectPath = Path.Combine(hostDirectory, "GeneratedVNextFrontendHost.csproj");
        RunHostBuild(projectPath);

        var startInfo = new ProcessStartInfo
        {
            FileName = "dotnet",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
        };
        startInfo.ArgumentList.Add("run");
        startInfo.ArgumentList.Add("--no-build");
        startInfo.ArgumentList.Add("--project");
        startInfo.ArgumentList.Add(projectPath);
        startInfo.ArgumentList.Add("--");
        startInfo.ArgumentList.Add(requestPath);

        using var process =
            Process.Start(startInfo)
            ?? throw new InvalidOperationException("failed to start generated vnext frontend host");
        var stdoutTask = process.StandardOutput.ReadToEndAsync();
        var stderrTask = process.StandardError.ReadToEndAsync();
        process.WaitForExit();
        Task.WaitAll(stdoutTask, stderrTask);
        if (process.ExitCode == 0)
            return stdoutTask.Result;

        var output = string.Join(
            Environment.NewLine,
            new[] { stdoutTask.Result, stderrTask.Result }.Where(text =>
                !string.IsNullOrWhiteSpace(text)
            )
        );
        throw new InvalidOperationException(
            $"generated vnext frontend failed with exit code {process.ExitCode}:{Environment.NewLine}{output}"
        );
    }

    private static void RunHostBuild(string projectPath)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "dotnet",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
        };
        startInfo.ArgumentList.Add("build");
        startInfo.ArgumentList.Add(projectPath);

        using var process =
            Process.Start(startInfo)
            ?? throw new InvalidOperationException("failed to build generated vnext frontend host");
        var stdoutTask = process.StandardOutput.ReadToEndAsync();
        var stderrTask = process.StandardError.ReadToEndAsync();
        process.WaitForExit();
        Task.WaitAll(stdoutTask, stderrTask);
        if (process.ExitCode == 0)
            return;

        var output = string.Join(
            Environment.NewLine,
            new[] { stdoutTask.Result, stderrTask.Result }.Where(text =>
                !string.IsNullOrWhiteSpace(text)
            )
        );
        throw new InvalidOperationException(
            $"generated vnext frontend host build failed with exit code {process.ExitCode}:{Environment.NewLine}{output}"
        );
    }

    private static string HostDirectory(string generatedProjectPath, string cacheDirectory)
    {
        var root = string.IsNullOrWhiteSpace(cacheDirectory)
            ? Path.Combine(Path.GetTempPath(), "moonbit2csharp-cache")
            : Path.GetFullPath(cacheDirectory);
        var hash = Convert
            .ToHexString(
                SHA256.HashData(Encoding.UTF8.GetBytes(Path.GetFullPath(generatedProjectPath)))
            )[..16]
            .ToLowerInvariant();
        return Path.Combine(root, "generated-vnext-frontend-host", hash);
    }

    private static void WriteHost(string hostDirectory, string generatedProjectPath)
    {
        Directory.CreateDirectory(hostDirectory);
        WriteAllTextIfChanged(
            Path.Combine(hostDirectory, "GeneratedVNextFrontendHost.csproj"),
            $$"""
            <Project Sdk="Microsoft.NET.Sdk">
              <PropertyGroup>
                <OutputType>Exe</OutputType>
                <TargetFramework>net10.0</TargetFramework>
                <ImplicitUsings>enable</ImplicitUsings>
                <Nullable>enable</Nullable>
              </PropertyGroup>
              <ItemGroup>
                <ProjectReference Include="{{EscapeXmlAttribute(
                Path.GetFullPath(generatedProjectPath)
            )}}" />
              </ItemGroup>
            </Project>
            """
        );
        WriteAllTextIfChanged(
            Path.Combine(hostDirectory, "Program.cs"),
            """
            using System.Text.Json;
            using ImportRef = Generated.MoonBit.Packages.moonbit2csharp.frontend.vnext.binding.ImportRef;
            using PackageSource = Generated.MoonBit.Packages.moonbit2csharp.frontend.vnext.package.PackageSource;
            using Pipeline = Generated.MoonBit.Packages.moonbit2csharp.frontend.vnext.pipeline.pipeline;
            using SourceUnit = Generated.MoonBit.Packages.moonbit2csharp.frontend.vnext.package.SourceUnit;

            var request = JsonSerializer.Deserialize<GeneratedVNextFrontendRequest>(
                File.ReadAllText(args[0])
            ) ?? throw new InvalidOperationException("missing generated vnext frontend request");

            var result = Pipeline.compile_package_sources_with_manifests_to_json(
                new Generated.MoonBit.Runtime.Array<SourceUnit>(
                    request.Sources.Select(item => new SourceUnit(item.FilePath, item.Source)).ToArray()
                ),
                request.ModuleName,
                request.MoonPkgSource,
                request.MoonPkgPath,
                new Generated.MoonBit.Runtime.Array<PackageSource>(
                    request.ImportedSources.Select(ToPackageSource).ToArray()
                ),
                new Generated.MoonBit.Runtime.Array<PackageSource>(
                    request.ImportedDeclarationSources.Select(ToPackageSource).ToArray()
                ),
                new Generated.MoonBit.Runtime.Array<SourceUnit>(
                    request.ImportedManifestSources
                        .Select(item => new SourceUnit(item.FilePath, item.Source))
                        .ToArray()
                )
            );
            Console.Write(result);

            static PackageSource ToPackageSource(GeneratedVNextPackageSource source) =>
                new(
                    new ImportRef(
                        source.ImportRef.AliasName,
                        source.ImportRef.PackageId,
                        source.ImportRef.ModulePath
                    ),
                    source.FilePath,
                    source.Source
                );

            sealed record GeneratedVNextFrontendRequest(
                IReadOnlyList<GeneratedVNextSourceUnit> Sources,
                string ModuleName,
                string MoonPkgSource,
                string MoonPkgPath,
                IReadOnlyList<GeneratedVNextPackageSource> ImportedSources,
                IReadOnlyList<GeneratedVNextPackageSource> ImportedDeclarationSources,
                IReadOnlyList<GeneratedVNextSourceUnit> ImportedManifestSources
            );

            sealed record GeneratedVNextSourceUnit(string FilePath, string Source);

            sealed record GeneratedVNextPackageSource(
                GeneratedVNextImportRef ImportRef,
                string FilePath,
                string Source
            );

            sealed record GeneratedVNextImportRef(
                string AliasName,
                string PackageId,
                string ModulePath
            );
            """
        );
    }

    private static void WriteAllTextIfChanged(string path, string text)
    {
        if (File.Exists(path) && File.ReadAllText(path) == text)
            return;

        File.WriteAllText(path, text, Encoding.UTF8);
    }

    private static string EscapeXmlAttribute(string value) =>
        value
            .Replace("&", "&amp;")
            .Replace("\"", "&quot;")
            .Replace("<", "&lt;")
            .Replace(">", "&gt;");
}
