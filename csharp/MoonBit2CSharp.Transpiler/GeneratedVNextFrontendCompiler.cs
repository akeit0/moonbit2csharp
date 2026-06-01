using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace MoonBit2CSharp.Transpiler;

internal sealed record VNextFrontendRequest(
    IReadOnlyList<VNextSourceUnit> Sources,
    string ModuleName,
    string MoonPkgSource,
    string MoonPkgPath,
    IReadOnlyList<VNextPackageSource> ImportedSources,
    IReadOnlyList<VNextPackageSource> ImportedDeclarationSources,
    IReadOnlyList<VNextSourceUnit> ImportedManifestSources
);

internal sealed record VNextSourceUnit(string FilePath, string Source);

internal sealed record VNextPackageSource(
    VNextImportRef ImportRef,
    string FilePath,
    string Source
);

internal sealed record VNextImportRef(
    string AliasName,
    string PackageId,
    string ModulePath
);

internal static class GeneratedVNextFrontendCompiler
{
    public static string Compile(
        VNextFrontendRequest request,
        string frontendPath,
        string cacheDirectory
    )
    {
        var fullFrontendPath = Path.GetFullPath(frontendPath);
        if (!File.Exists(fullFrontendPath))
            throw new FileNotFoundException(
                "C# vnext frontend path not found",
                fullFrontendPath
            );

        var requestPath = RequestPath(fullFrontendPath, cacheDirectory);
        File.WriteAllText(requestPath, JsonSerializer.Serialize(request));

        var extension = Path.GetExtension(fullFrontendPath).ToLowerInvariant();
        return extension switch
        {
            ".exe" => RunFrontendProcess(fullFrontendPath, requestPath),
            ".dll" => RunDotnetFrontend(fullFrontendPath, requestPath),
            ".csproj" => CompileWithProjectFrontend(fullFrontendPath, requestPath, cacheDirectory),
            _ => throw new ArgumentException(
                "C# vnext frontend must be an .exe, .dll, or .csproj: " + fullFrontendPath
            ),
        };
    }

    private static string CompileWithProjectFrontend(
        string generatedProjectPath,
        string requestPath,
        string cacheDirectory
    )
    {
        var hostDirectory = HostDirectory(generatedProjectPath, cacheDirectory);
        WriteHost(hostDirectory, generatedProjectPath);

        var projectPath = Path.Combine(hostDirectory, "GeneratedVNextFrontendHost.csproj");
        var hostDllPath = HostDllPath(hostDirectory);
        if (!HostBuildFresh(hostDllPath, hostDirectory, generatedProjectPath))
            RunHostBuild(projectPath);

        return RunDotnetFrontend(hostDllPath, requestPath);
    }

    private static string RunFrontendProcess(string executablePath, string requestPath)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = executablePath,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
            WorkingDirectory = Path.GetDirectoryName(executablePath) ?? Environment.CurrentDirectory,
        };
        startInfo.ArgumentList.Add(requestPath);
        return RunFrontendProcess(startInfo);
    }

    private static string RunDotnetFrontend(string assemblyPath, string requestPath)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = "dotnet",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
            WorkingDirectory = Path.GetDirectoryName(assemblyPath) ?? Environment.CurrentDirectory,
        };
        startInfo.ArgumentList.Add(assemblyPath);
        startInfo.ArgumentList.Add(requestPath);
        return RunFrontendProcess(startInfo);
    }

    private static string RunFrontendProcess(ProcessStartInfo startInfo)
    {
        using var process =
            Process.Start(startInfo)
            ?? throw new InvalidOperationException("failed to start C# vnext frontend");
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
            $"C# vnext frontend failed with exit code {process.ExitCode}:{Environment.NewLine}{output}"
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

    private static string RequestPath(string frontendPath, string cacheDirectory)
    {
        var root = string.IsNullOrWhiteSpace(cacheDirectory)
            ? Path.Combine(Path.GetTempPath(), "moonbit2csharp-cache")
            : Path.GetFullPath(cacheDirectory);
        var hash = Convert
            .ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(Path.GetFullPath(frontendPath))))[
                ..16
            ]
            .ToLowerInvariant();
        var directory = Path.Combine(root, "vnext-frontend-requests", hash);
        Directory.CreateDirectory(directory);
        return Path.Combine(directory, "request.json");
    }

    private static string HostDllPath(string hostDirectory) =>
        Path.Combine(
            hostDirectory,
            "bin",
            "Debug",
            "net10.0",
            "GeneratedVNextFrontendHost.dll"
        );

    private static bool HostBuildFresh(
        string hostDllPath,
        string hostDirectory,
        string generatedProjectPath
    )
    {
        if (!File.Exists(hostDllPath))
            return false;

        var outputTime = File.GetLastWriteTimeUtc(hostDllPath);
        foreach (
            var file in Directory
                .EnumerateFiles(hostDirectory, "*", SearchOption.TopDirectoryOnly)
                .Concat(GeneratedProjectDependencyFiles(generatedProjectPath))
        )
            if (File.GetLastWriteTimeUtc(file) > outputTime)
                return false;

        return true;
    }

    private static IEnumerable<string> GeneratedProjectDependencyFiles(string generatedProjectPath)
    {
        yield return generatedProjectPath;
        var directory = Path.GetDirectoryName(Path.GetFullPath(generatedProjectPath));
        if (string.IsNullOrWhiteSpace(directory) || !Directory.Exists(directory))
            yield break;

        foreach (var file in Directory.EnumerateFiles(directory, "*", SearchOption.AllDirectories))
        {
            var parts = file.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            if (parts.Any(part => part is ".git" or "bin" or "obj"))
                continue;
            yield return file;
        }
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

            var request = JsonSerializer.Deserialize<VNextFrontendRequest>(
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

            static PackageSource ToPackageSource(VNextPackageSource source) =>
                new(
                    new ImportRef(
                        source.ImportRef.AliasName,
                        source.ImportRef.PackageId,
                        source.ImportRef.ModulePath
                    ),
                    source.FilePath,
                    source.Source
                );

            sealed record VNextFrontendRequest(
                IReadOnlyList<VNextSourceUnit> Sources,
                string ModuleName,
                string MoonPkgSource,
                string MoonPkgPath,
                IReadOnlyList<VNextPackageSource> ImportedSources,
                IReadOnlyList<VNextPackageSource> ImportedDeclarationSources,
                IReadOnlyList<VNextSourceUnit> ImportedManifestSources
            );

            sealed record VNextSourceUnit(string FilePath, string Source);

            sealed record VNextPackageSource(
                VNextImportRef ImportRef,
                string FilePath,
                string Source
            );

            sealed record VNextImportRef(
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
