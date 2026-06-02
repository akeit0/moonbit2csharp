using System.Diagnostics;
using System.Text;
using MoonBit2CSharp.Backend;

namespace MoonBit2CSharp.Transpiler;

public sealed record MoonBitRunProjectRequest(IReadOnlyList<string> Inputs)
{
    public string? OutputDirectory { get; init; }
    public string? MoonModPath { get; init; }
    public string? ProjectName { get; init; }
    public string SingleFileName { get; init; } = "";

    public string RuntimeProjectPath { get; init; } =
        MoonBitSourceTranspiler.DefaultRuntimeProjectPath;

    public bool ReferenceRuntime { get; init; }
    public bool IncludeMainPackages { get; init; }
    public bool UpperPascalCaseNames { get; init; }
    public string GeneratedNamespace { get; init; } = "";
    public string RuntimeNamespace { get; init; } = "MoonBit2CSharp.Runtime";
    public IReadOnlyList<string> AdditionalUsings { get; init; } = [];
    public IReadOnlyList<string> AdditionalProjectReferences { get; init; } = [];
    public bool CacheEnabled { get; init; } = true;
    public string CacheDirectory { get; init; } = "";
    public string VNextFrontend { get; init; } = "";
}

public sealed record MoonBitRunProjectResult(
    string OutputDirectory,
    string ProjectPath,
    IReadOnlyList<string> WrittenFiles
)
{
    public bool CacheHit { get; init; }
}

public static class MoonBitRunProject
{
    private const string CacheMarkerFileName = ".moonbit2csharp.run.cache";

    public static MoonBitRunProjectResult Prepare(MoonBitRunProjectRequest request)
    {
        var inputs = request.Inputs.Count == 0 ? [Directory.GetCurrentDirectory()] : request.Inputs;
        var fullInputs = inputs.Select(Path.GetFullPath).ToArray();
        var moonModPath = request.MoonModPath;
        if (string.IsNullOrWhiteSpace(moonModPath))
            moonModPath = fullInputs
                .Select(MoonBitSourceTranspiler.FindMoonMod)
                .FirstOrDefault(path => !string.IsNullOrWhiteSpace(path));

        var outputDir = Path.GetFullPath(
            string.IsNullOrWhiteSpace(request.OutputDirectory)
                ? MoonBitSourceTranspiler.DefaultCSharpBuildDirectory(fullInputs, moonModPath)
                : request.OutputDirectory
        );
        var projectName = request.ProjectName;
        if (string.IsNullOrWhiteSpace(projectName))
            projectName = !string.IsNullOrWhiteSpace(moonModPath)
                ? CSharpProjectFiles.ProjectNameFromMoonMod(moonModPath)
                : "MoonBitProject";

        var projectPath = Path.Combine(outputDir, projectName + ".csproj");
        if (
            request.CacheEnabled
            && RunProjectCacheFresh(
                outputDir,
                projectPath,
                fullInputs,
                moonModPath,
                request.VNextFrontend
            )
        )
        {
            return new(outputDir, projectPath, ExistingGeneratedFiles(outputDir, projectPath))
            {
                CacheHit = true,
            };
        }

        RunMoonCheckForInputs(fullInputs, moonModPath);

        var result = MoonBitSourceTranspiler.WriteProject(
            new(outputDir, fullInputs)
            {
                SingleFileName = request.SingleFileName,
                ProjectName = projectName,
                MoonModPath = moonModPath ?? "",
                RuntimeProjectPath = request.RuntimeProjectPath,
                ReferenceRuntime = request.ReferenceRuntime,
                Executable = true,
                IncludeMainPackages = request.IncludeMainPackages,
                UpperPascalCaseNames = request.UpperPascalCaseNames,
                GeneratedNamespace = request.GeneratedNamespace,
                RuntimeNamespace = request.RuntimeNamespace,
                AdditionalUsings = request.AdditionalUsings,
                AdditionalProjectReferences = request.AdditionalProjectReferences,
                CacheEnabled = request.CacheEnabled,
                CacheDirectory = request.CacheDirectory,
                VNextFrontend = request.VNextFrontend,
                TrimApplicationOutput = true,
            }
        );

        if (request.CacheEnabled)
            WriteRunProjectCacheMarker(outputDir, fullInputs, moonModPath, request.VNextFrontend);

        return new(outputDir, projectPath, result.WrittenFiles) { CacheHit = result.CacheHit };
    }

    private static bool RunProjectCacheFresh(
        string outputDir,
        string projectPath,
        IReadOnlyList<string> fullInputs,
        string? moonModPath,
        string vNextFrontend
    )
    {
        var markerPath = CacheMarkerPath(outputDir);
        if (!File.Exists(markerPath) || !File.Exists(projectPath))
            return false;
        if (!RunProjectCacheMarkerMatches(markerPath, vNextFrontend))
            return false;

        var markerTime = File.GetLastWriteTimeUtc(markerPath);
        foreach (
            var path in CacheDependencyFiles(fullInputs, moonModPath, outputDir, vNextFrontend)
        )
            if (File.GetLastWriteTimeUtc(path) > markerTime)
                return false;

        return true;
    }

    private static IReadOnlyList<string> ExistingGeneratedFiles(
        string outputDir,
        string projectPath
    )
    {
        var files = new List<string>();
        if (Directory.Exists(outputDir))
            files.AddRange(
                Directory.EnumerateFiles(outputDir, "*.g.cs", SearchOption.TopDirectoryOnly)
            );
        if (File.Exists(projectPath))
            files.Add(projectPath);
        return files;
    }

    private static void WriteRunProjectCacheMarker(
        string outputDir,
        IReadOnlyList<string> fullInputs,
        string? moonModPath,
        string vNextFrontend
    )
    {
        Directory.CreateDirectory(outputDir);
        var builder = new StringBuilder();
        builder.AppendLine("version=2");
        builder.AppendLine("moonMod=" + (moonModPath ?? ""));
        builder.AppendLine("vNextFrontend=" + NormalizeVNextFrontendForCache(vNextFrontend));
        foreach (var input in fullInputs)
            builder.AppendLine("input=" + input);
        File.WriteAllText(CacheMarkerPath(outputDir), builder.ToString());
    }

    private static bool RunProjectCacheMarkerMatches(string markerPath, string vNextFrontend)
    {
        var expected = "vNextFrontend=" + NormalizeVNextFrontendForCache(vNextFrontend);
        var lines = File.ReadLines(markerPath).ToHashSet(StringComparer.Ordinal);
        return lines.Contains("version=2") && lines.Contains(expected);
    }

    private static string CacheMarkerPath(string outputDir) =>
        Path.Combine(outputDir, CacheMarkerFileName);

    private static IReadOnlyList<string> CacheDependencyFiles(
        IReadOnlyList<string> fullInputs,
        string? moonModPath,
        string outputDir,
        string vNextFrontend
    )
    {
        var dependencies = new List<string>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var root in CacheDependencyRoots(fullInputs, moonModPath))
        {
            if (File.Exists(root))
            {
                AddIfDependency(root);
                continue;
            }

            if (!Directory.Exists(root))
                continue;

            foreach (var file in Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories))
                AddIfDependency(file);
        }

        foreach (var assembly in Directory.EnumerateFiles(AppContext.BaseDirectory, "*.dll"))
        {
            var fullPath = Path.GetFullPath(assembly);
            if (seen.Add(fullPath))
                dependencies.Add(fullPath);
        }

        if (VNextFrontendCSharpPath(vNextFrontend) is { } csharpFrontendPath)
        {
            var frontendPath = Path.GetFullPath(csharpFrontendPath);
            if (File.Exists(frontendPath))
                AddGeneratedPipelineDependency(frontendPath);
            if (
                Path.GetExtension(frontendPath)
                    .Equals(".csproj", StringComparison.OrdinalIgnoreCase)
            )
            {
                var generatedProjectDirectory = Path.GetDirectoryName(frontendPath);
                if (!string.IsNullOrWhiteSpace(generatedProjectDirectory))
                    foreach (
                        var file in Directory.EnumerateFiles(
                            generatedProjectDirectory,
                            "*",
                            SearchOption.AllDirectories
                        )
                    )
                        AddGeneratedPipelineDependency(file);
            }
        }

        return dependencies;

        static string? VNextFrontendCSharpPath(string frontend)
        {
            const string csharpPrefix = "csharp:";
            if (!frontend.StartsWith(csharpPrefix, StringComparison.OrdinalIgnoreCase))
                return null;
            var path = frontend[csharpPrefix.Length..];
            return string.IsNullOrWhiteSpace(path) ? null : path;
        }

        void AddIfDependency(string path)
        {
            var fullPath = Path.GetFullPath(path);
            if (!IsCacheDependencyFile(fullPath, outputDir) || !seen.Add(fullPath))
                return;

            dependencies.Add(fullPath);
        }

        void AddGeneratedPipelineDependency(string path)
        {
            var fullPath = Path.GetFullPath(path);
            var parts = fullPath.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            if (parts.Any(part => part is ".git" or "bin" or "obj"))
                return;
            if (!seen.Add(fullPath))
                return;

            dependencies.Add(fullPath);
        }
    }

    private static IEnumerable<string> CacheDependencyRoots(
        IReadOnlyList<string> fullInputs,
        string? moonModPath
    )
    {
        if (!string.IsNullOrWhiteSpace(moonModPath))
        {
            var moduleRoot = Path.GetDirectoryName(Path.GetFullPath(moonModPath));
            if (!string.IsNullOrWhiteSpace(moduleRoot))
                yield return moduleRoot;
            foreach (var root in BuiltinDependencyRoots())
                yield return root;
            yield break;
        }

        foreach (var input in fullInputs)
        {
            var moonMod = MoonBitSourceTranspiler.FindMoonMod(input);
            if (!string.IsNullOrWhiteSpace(moonMod))
            {
                var moduleRoot = Path.GetDirectoryName(Path.GetFullPath(moonMod));
                if (!string.IsNullOrWhiteSpace(moduleRoot))
                    yield return moduleRoot;
            }
            else
            {
                yield return Directory.Exists(input)
                    ? input
                    : Path.GetDirectoryName(input) ?? input;
            }
        }

        foreach (var root in BuiltinDependencyRoots())
            yield return root;
    }

    private static string NormalizeVNextFrontendForCache(string vNextFrontend)
    {
        const string csharpPrefix = "csharp:";
        if (string.IsNullOrWhiteSpace(vNextFrontend))
            return "";
        if (vNextFrontend.Equals("moon", StringComparison.OrdinalIgnoreCase))
            return "moon";
        if (vNextFrontend.StartsWith(csharpPrefix, StringComparison.OrdinalIgnoreCase))
        {
            var path = vNextFrontend[csharpPrefix.Length..];
            return string.IsNullOrWhiteSpace(path)
                ? csharpPrefix
                : csharpPrefix + Path.GetFullPath(path);
        }

        return vNextFrontend;
    }

    private static IEnumerable<string> BuiltinDependencyRoots()
    {
        var repositoryRoot = RepositoryRootOrNull();
        if (repositoryRoot is null)
            yield break;

        foreach (
            var relative in new[]
            {
                Path.Combine("moonbitlang", "core", "builtin"),
                Path.Combine("moonbit", "overrides"),
                Path.Combine("moonbit", "overrides"),
            }
        )
        {
            var root = Path.Combine(repositoryRoot, relative);
            if (Directory.Exists(root))
                yield return root;
        }
    }

    private static string? RepositoryRootOrNull()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            if (Directory.Exists(Path.Combine(directory.FullName, "moonbit")))
                return directory.FullName;

            directory = directory.Parent;
        }

        return null;
    }

    private static bool IsCacheDependencyFile(string path, string outputDir)
    {
        var fileName = Path.GetFileName(path);
        if (fileName is CacheMarkerFileName)
            return false;

        var fullOutputDir = Path.GetFullPath(outputDir)
            .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        if (
            path.StartsWith(
                fullOutputDir + Path.DirectorySeparatorChar,
                StringComparison.OrdinalIgnoreCase
            )
            || path.StartsWith(
                fullOutputDir + Path.AltDirectorySeparatorChar,
                StringComparison.OrdinalIgnoreCase
            )
        )
            return false;

        if (
            path.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
                .Any(part => part is ".git" or "_build" or "target" or "bin" or "obj")
        )
            return false;

        return fileName.Equals("moon.mod", StringComparison.OrdinalIgnoreCase)
            || fileName.Equals("moon.mod.json", StringComparison.OrdinalIgnoreCase)
            || fileName.Equals("moon.pkg", StringComparison.OrdinalIgnoreCase)
            || fileName.Equals("moon.pkg.json", StringComparison.OrdinalIgnoreCase)
            || path.EndsWith(".mbt", StringComparison.OrdinalIgnoreCase)
            || path.EndsWith(".mbti", StringComparison.OrdinalIgnoreCase)
            || path.EndsWith(".mbtx", StringComparison.OrdinalIgnoreCase)
            || path.EndsWith(".dll", StringComparison.OrdinalIgnoreCase);
    }

    private static void RunMoonCheckForInputs(IReadOnlyList<string> inputPaths, string? moonModPath)
    {
        var moonProjectPath = ResolveMoonCheckPath(inputPaths, moonModPath);
        if (moonProjectPath is null)
            return;

        var startInfo = new ProcessStartInfo(FindMoonCommand())
        {
            UseShellExecute = false,
            WorkingDirectory = moonProjectPath,
        };
        startInfo.ArgumentList.Add("check");

        using var process =
            Process.Start(startInfo) ?? throw new InvalidOperationException("failed to start moon");
        process.WaitForExit();
        if (process.ExitCode is not 0)
            throw new InvalidOperationException($"moon check failed for {moonProjectPath}");
    }

    private static string? ResolveMoonCheckPath(
        IReadOnlyList<string> inputPaths,
        string? moonModPath
    )
    {
        if (!string.IsNullOrWhiteSpace(moonModPath))
            return Path.GetDirectoryName(Path.GetFullPath(moonModPath));

        foreach (var input in inputPaths)
        {
            var moonMod = MoonBitSourceTranspiler.FindMoonMod(input);
            if (!string.IsNullOrWhiteSpace(moonMod))
                return Path.GetDirectoryName(Path.GetFullPath(moonMod));
        }

        return null;
    }

    private static string FindMoonCommand()
    {
        var userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var moonPath = Path.Combine(
            userProfile,
            ".moon",
            "bin",
            OperatingSystem.IsWindows() ? "moon.exe" : "moon"
        );
        return File.Exists(moonPath) ? moonPath : "moon";
    }
}
