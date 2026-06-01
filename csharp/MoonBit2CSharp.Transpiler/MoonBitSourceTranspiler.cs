using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using MoonBit2CSharp.Backend;
using MoonBit2CSharp.VNext.Backend;

namespace MoonBit2CSharp.Transpiler;

public sealed record MoonBitIrInput(string Path, string Json);

internal sealed record MoonBitPackageInput(
    string PackageRoot,
    string? EnvPackageName,
    string? SourceLocationPackageName,
    bool EmitOutput
);

internal sealed record VNextDeclarationSource(
    string Alias,
    string PackageId,
    string ModulePath,
    string Path
);

public sealed record MoonBitProjectTranspileRequest(
    string OutputDirectory,
    IReadOnlyList<string> Inputs
)
{
    public string? SingleFileName { get; init; }
    public string? ProjectName { get; init; }
    public string? MoonModPath { get; init; }

    public string RuntimeProjectPath { get; init; } =
        MoonBitSourceTranspiler.DefaultRuntimeProjectPath;

    public bool ReferenceRuntime { get; init; }
    public bool Executable { get; init; }
    public bool IncludeMainPackages { get; init; }
    public bool UpperPascalCaseNames { get; init; }
    public bool WriteProjectFile { get; init; } = true;
    public string GeneratedNamespace { get; init; } = "Generated.MoonBit";
    public string RuntimeNamespace { get; init; } = "MoonBit2CSharp.Runtime";
    public IReadOnlyList<string> AdditionalUsings { get; init; } = [];
    public IReadOnlyList<string> AdditionalProjectReferences { get; init; } = [];

    public IReadOnlySet<string> ImplementedCoreBuiltins { get; init; } =
        new HashSet<string>(StringComparer.Ordinal);

    public bool CacheEnabled { get; init; } = true;
    public string CacheDirectory { get; init; } = "";
    public bool TrimApplicationOutput { get; init; }
    public string VNextFrontend { get; init; } = "";
}

public sealed record MoonBitProjectTranspileResult(IReadOnlyList<string> WrittenFiles)
{
    public bool CacheHit { get; init; }
}

public static class MoonBitSourceTranspiler
{
    public const string DefaultVNextRuntimeNamespace = "MoonBit.Runtime";

    private static readonly string[] OfficialCoreNumericImplementationPackages =
    [
        "byte",
        "double",
        "float",
        "int",
        "int16",
        "int64",
        "uint",
        "uint16",
        "uint64",
    ];

    private static readonly string[] MoonModFileNames = ["moon.mod", "moon.mod.json"];

    public static string DefaultRuntimeProjectPath { get; } =
        Path.GetFullPath(
            Path.Combine(
                AppContext.BaseDirectory,
                "..",
                "..",
                "..",
                "..",
                "MoonBitRuntime",
                "MoonBitRuntime.csproj"
            )
        );

    public static string DefaultVNextRuntimeProjectPath { get; } =
        Path.GetFullPath(
            Path.Combine(
                AppContext.BaseDirectory,
                "..",
                "..",
                "..",
                "..",
                "MoonBit.Runtime",
                "MoonBit.Runtime.csproj"
            )
        );

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

    private static bool IsMoonModFileName(string path)
    {
        return MoonModFileNames.Contains(Path.GetFileName(path), StringComparer.OrdinalIgnoreCase);
    }

    private static string? FindMoonModInDirectory(string directory)
    {
        foreach (var moonModFileName in MoonModFileNames)
        {
            var candidate = Path.Combine(directory, moonModFileName);
            if (File.Exists(candidate))
                return candidate;
        }

        return null;
    }

    private static string RepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            if (Directory.Exists(Path.Combine(directory.FullName, "moonbit")))
                return directory.FullName;

            directory = directory.Parent;
        }

        throw new DirectoryNotFoundException("could not find repository root containing moonbit");
    }

    private static IReadOnlyList<string> OfficialCorePackageSourceFilesForTarget(
        string packagePath,
        string target
    )
    {
        var excluded = OfficialCoreFilesExcludedForSourceTarget(packagePath, target);
        return PackageSourceFiles(packagePath)
            .Where(path => !excluded.Contains(Path.GetFileName(path)))
            .Select(Path.GetFullPath)
            .ToArray();
    }

    private static HashSet<string> OfficialCoreFilesExcludedForSourceTarget(
        string packagePath,
        string target
    )
    {
        var excluded = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var moonPkgPath = Path.Combine(packagePath, "moon.pkg");
        if (!File.Exists(moonPkgPath))
            return excluded;

        var source = File.ReadAllText(moonPkgPath);
        foreach (
            Match match in Regex.Matches(
                source,
                "\"(?<file>[^\"]+\\.mbt)\"\\s*:\\s*\\[(?<targets>[^\\]]*)\\]"
            )
        )
        {
            var fileName = match.Groups["file"].Value;
            var targets = Regex
                .Matches(match.Groups["targets"].Value, "\"(?<target>[^\"]+)\"")
                .Select(item => item.Groups["target"].Value)
                .ToArray();
            if (!OfficialCoreTargetSpecAllowsSourceTarget(targets, target))
                excluded.Add(fileName);
        }

        return excluded;
    }

    private static bool OfficialCoreTargetSpecAllowsSourceTarget(
        IReadOnlyList<string> targets,
        string target
    )
    {
        if (targets.Count == 0)
            return true;

        if (targets.Contains("not", StringComparer.Ordinal))
            return !targets.Contains(target, StringComparer.Ordinal);

        return targets.Contains(target, StringComparer.Ordinal);
    }

    private static bool IsVirtualPackage(string packagePath)
    {
        foreach (var fileName in new[] { "moon.pkg", "moon.pkg.json" })
        {
            var path = Path.Combine(packagePath, fileName);
            if (!File.Exists(path))
                continue;

            var source = File.ReadAllText(path);
            if (fileName.EndsWith(".json", StringComparison.OrdinalIgnoreCase))
            {
                if (JsonMoonPkgHasVirtualOption(source))
                    return true;
            }
            else if (TextMoonPkgHasVirtualOption(source))
            {
                return true;
            }
        }

        return false;
    }

    public static MoonBitProjectTranspileResult WriteProject(MoonBitProjectTranspileRequest request)
    {
        using var projectProfile = TranspilerProfiler.Measure("write project total");
        var outputDir = Path.GetFullPath(request.OutputDirectory);
        Directory.CreateDirectory(outputDir);
        return WriteVNextProject(request, outputDir);
    }

    private static MoonBitProjectTranspileResult WriteVNextProject(
        MoonBitProjectTranspileRequest request,
        string outputDir
    )
    {
        var runtimeProjectPath =
            request.RuntimeProjectPath == DefaultRuntimeProjectPath
                ? DefaultVNextRuntimeProjectPath
                : request.RuntimeProjectPath;
        var runtimeNamespace =
            request.RuntimeNamespace == "MoonBit2CSharp.Runtime"
                ? DefaultVNextRuntimeNamespace
                : request.RuntimeNamespace;
        var fullInputs = request.Inputs.Select(Path.GetFullPath).ToArray();
        var moonModPath = string.IsNullOrWhiteSpace(request.MoonModPath)
            ? fullInputs
                .Select(FindMoonMod)
                .FirstOrDefault(path => !string.IsNullOrWhiteSpace(path))
            : request.MoonModPath;
        var mainRoot =
            fullInputs
                .SelectMany(input => InputPackageRoots(input, true))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .FirstOrDefault(path => IsMainPackage(path))
            ?? fullInputs
                .SelectMany(input => InputPackageRoots(input, true))
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .FirstOrDefault();
        if (mainRoot is null)
            throw new InvalidOperationException("vnext project mode found no MoonBit package root");

        var mainFiles = PackageSourceFiles(mainRoot);
        if (mainFiles.Count == 0)
            throw new InvalidOperationException(
                $"vnext project mode found no source files in main package {mainRoot}"
            );

        var importedRoots = ResolveVNextImportedPackageRoots(mainRoot, moonModPath);
        var moonPkgPath =
            FindMoonPkg(mainRoot)
            ?? throw new FileNotFoundException("moon.pkg not found for vnext project", mainRoot);
        var moduleName = ModuleNameForPackage(
            mainRoot,
            SourceLocationPackageNameForPackageRoot(mainRoot, moonModPath),
            EnvPackageNameForPackageRoot(mainRoot, moonModPath)
        );
        var frontendRequest = BuildVNextFrontendRequest(
            mainFiles[0],
            moduleName,
            moonPkgPath,
            importedRoots,
            moonModPath
        );
        var irJson = VNextFrontendIsMoon(request.VNextFrontend)
            ? CompileMoonVNextSemanticIr(frontendRequest)
            : GeneratedVNextFrontendCompiler.Compile(
                frontendRequest,
                VNextFrontendCSharpPath(request.VNextFrontend),
                request.CacheDirectory
            );
        if (
            Environment.GetEnvironmentVariable("MOONBIT2CSHARP_VNEXT_IR_DUMP") is
            { Length: > 0 } dumpPath
        )
            File.WriteAllText(Path.GetFullPath(dumpPath), irJson);
        var targetExecutable = IsExecutableVNextTarget(request, fullInputs, mainRoot);
        var options = new VNextEmitterOptions(
            request.GeneratedNamespace,
            runtimeNamespace,
            request.UpperPascalCaseNames,
            targetExecutable
        );

        var projectName = request.ProjectName;
        if (string.IsNullOrWhiteSpace(projectName) && !string.IsNullOrWhiteSpace(moonModPath))
            projectName = CSharpProjectFiles.ProjectNameFromMoonMod(Path.GetFullPath(moonModPath));
        projectName = string.IsNullOrWhiteSpace(projectName) ? "MoonBitProject" : projectName;

        var writtenFiles = new List<string>();
        if (!string.IsNullOrWhiteSpace(request.SingleFileName))
        {
            var outputPaths = ProjectOutputPaths(
                outputDir,
                [new(mainFiles[0], irJson)],
                0,
                request.SingleFileName,
                false,
                request.WriteProjectFile,
                projectName,
                moonModPath ?? "",
                runtimeProjectPath,
                request.UpperPascalCaseNames
            );
            CleanUnplannedGeneratedOutputs(outputDir, outputPaths.Paths);
            var singleFilePath = outputPaths.Paths[0];
            var generatedCode = VNextBackend.Emit(irJson, options);
            WriteAllTextIfChanged(singleFilePath, generatedCode);
            writtenFiles.Add(singleFilePath);
            var supportPath = Path.Combine(outputDir, "moonbit_runtime.g.cs");
            WriteAllTextIfChanged(
                supportPath,
                VNextRuntimeSupportSource(request.GeneratedNamespace, [generatedCode])
            );
            writtenFiles.Add(supportPath);

            if (request.WriteProjectFile && !string.IsNullOrWhiteSpace(outputPaths.ProjectName))
            {
                var projectPath = outputPaths.Paths[^1];
                WriteAllTextIfChanged(
                    projectPath,
                    CSharpProjectFiles.BuildProjectFile(
                        outputDir,
                        Path.GetFullPath(runtimeProjectPath),
                        false,
                        targetExecutable,
                        request.AdditionalProjectReferences,
                        formattingOptions: new(
                            GeneratedNamespace: request.GeneratedNamespace,
                            RuntimeNamespace: runtimeNamespace,
                            AdditionalUsings: request.AdditionalUsings
                        )
                    )
                );
                writtenFiles.Add(projectPath);
            }

            return new(writtenFiles);
        }

        var generatedFiles = VNextBackend.EmitFiles(irJson, options);
        var plannedPaths = new List<string>();
        var runtimePath = Path.Combine(outputDir, "moonbit_runtime.g.cs");
        plannedPaths.Add(runtimePath);

        plannedPaths.AddRange(
            generatedFiles.Select(file => Path.Combine(outputDir, file.RelativePath))
        );
        string? projectOutputPath = null;
        if (request.WriteProjectFile && !string.IsNullOrWhiteSpace(projectName))
        {
            projectOutputPath = Path.Combine(outputDir, projectName + ".csproj");
            plannedPaths.Add(projectOutputPath);
        }

        CleanUnplannedGeneratedOutputs(outputDir, plannedPaths);

        WriteAllTextIfChanged(
            runtimePath,
            VNextRuntimeSupportSource(
                request.GeneratedNamespace,
                generatedFiles.Select(file => file.Code)
            )
        );
        writtenFiles.Add(runtimePath);

        foreach (var generatedFile in generatedFiles)
        {
            var outputPath = Path.Combine(outputDir, generatedFile.RelativePath);
            Directory.CreateDirectory(Path.GetDirectoryName(outputPath) ?? outputDir);
            WriteAllTextIfChanged(outputPath, generatedFile.Code);
            writtenFiles.Add(outputPath);
        }

        if (projectOutputPath is not null)
        {
            WriteAllTextIfChanged(
                projectOutputPath,
                CSharpProjectFiles.BuildProjectFile(
                    outputDir,
                    Path.GetFullPath(runtimeProjectPath),
                    false,
                    targetExecutable,
                    request.AdditionalProjectReferences,
                    formattingOptions: new(
                        GeneratedNamespace: request.GeneratedNamespace,
                        RuntimeNamespace: runtimeNamespace,
                        AdditionalUsings: request.AdditionalUsings
                    )
                )
            );
            writtenFiles.Add(projectOutputPath);
        }

        return new(writtenFiles);
    }

    private static string VNextRuntimeSupportSource(
        string generatedNamespace,
        IEnumerable<string> generatedCode
    )
    {
        var template = File.ReadAllText(
            Path.Combine(
                RepositoryRoot(),
                "csharp",
                "MoonBit2CSharp.Transpiler",
                "VNextRuntimeSupportTemplate.cs.txt"
            )
        );
        return VNextRuntimeSupportRenderer.Render(template, generatedNamespace, generatedCode);
    }

    private static bool IsExecutableVNextTarget(
        MoonBitProjectTranspileRequest request,
        IReadOnlyList<string> fullInputs,
        string mainRoot
    )
    {
        return !string.IsNullOrWhiteSpace(request.SingleFileName)
            || IsSingleFileInputTarget(fullInputs)
            || IsMainPackage(mainRoot);
    }

    private static bool IsSingleFileInputTarget(IReadOnlyList<string> fullInputs)
    {
        return fullInputs.Count == 1
            && File.Exists(fullInputs[0])
            && Path.GetExtension(fullInputs[0]) is ".mbt" or ".mbtx";
    }

    private static IReadOnlyList<string> ResolveVNextImportedPackageRoots(
        string mainRoot,
        string? moonModPath
    )
    {
        return ResolvePackageInputs([mainRoot], true, moonModPath)
            .Select(package => package.PackageRoot)
            .Where(root =>
                !Path.GetFullPath(root)
                    .Equals(Path.GetFullPath(mainRoot), StringComparison.OrdinalIgnoreCase)
            )
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    private static string CompileMoonVNextSemanticIr(VNextFrontendRequest request)
    {
        var moonbitDirectory = Path.Combine(RepositoryRoot(), "moonbit");
        var startInfo = new ProcessStartInfo
        {
            FileName = FindMoonCommand(),
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8,
            WorkingDirectory = moonbitDirectory,
        };
        if (TranspilerProfiler.Enabled)
            startInfo.Environment["MOONBIT2CSHARP_VNEXT_PROFILE"] = "1";
        startInfo.ArgumentList.Add("-C");
        startInfo.ArgumentList.Add(moonbitDirectory);
        startInfo.ArgumentList.Add("run");
        startInfo.ArgumentList.Add("./src/vnext_cli");
        startInfo.ArgumentList.Add("--");
        startInfo.ArgumentList.Add(request.Sources[0].FilePath);
        startInfo.ArgumentList.Add(request.ModuleName);
        startInfo.ArgumentList.Add(request.MoonPkgPath);
        foreach (var source in request.Sources.Skip(1))
        {
            startInfo.ArgumentList.Add("--source");
            startInfo.ArgumentList.Add(source.FilePath);
        }

        foreach (var manifest in request.ImportedManifestSources)
        {
            startInfo.ArgumentList.Add("--import-manifest");
            startInfo.ArgumentList.Add(manifest.FilePath);
        }

        foreach (var source in request.ImportedSources)
        {
            startInfo.ArgumentList.Add("--import-source");
            startInfo.ArgumentList.Add(source.ImportRef.AliasName);
            startInfo.ArgumentList.Add(source.ImportRef.PackageId);
            startInfo.ArgumentList.Add(source.ImportRef.ModulePath);
            startInfo.ArgumentList.Add(source.FilePath);
        }

        foreach (var source in request.ImportedDeclarationSources)
        {
            startInfo.ArgumentList.Add("--import-declaration-source");
            startInfo.ArgumentList.Add(source.ImportRef.AliasName);
            startInfo.ArgumentList.Add(source.ImportRef.PackageId);
            startInfo.ArgumentList.Add(source.ImportRef.ModulePath);
            startInfo.ArgumentList.Add(source.FilePath);
        }

        using var process =
            Process.Start(startInfo)
            ?? throw new InvalidOperationException("failed to start moon vnext semantic IR");
        var stdoutTask = process.StandardOutput.ReadToEndAsync();
        var stderrTask = process.StandardError.ReadToEndAsync();
        process.WaitForExit();
        Task.WaitAll(stdoutTask, stderrTask);
        if (process.ExitCode != 0)
        {
            var output = string.Join(
                Environment.NewLine,
                new[] { stdoutTask.Result, stderrTask.Result }.Where(text =>
                    !string.IsNullOrWhiteSpace(text)
                )
            );
            throw new InvalidOperationException(
                $"moon vnext semantic IR failed with exit code {process.ExitCode}:{Environment.NewLine}{output}"
            );
        }

        if (TranspilerProfiler.Enabled && !string.IsNullOrWhiteSpace(stderrTask.Result))
            LogVNextMoonProfile(stderrTask.Result);

        return stdoutTask.Result;
    }

    private static bool VNextFrontendIsMoon(string frontend) =>
        string.IsNullOrWhiteSpace(frontend)
        || frontend.Equals("moon", StringComparison.OrdinalIgnoreCase);

    private static string VNextFrontendCSharpPath(string frontend)
    {
        const string csharpPrefix = "csharp:";
        if (frontend.StartsWith(csharpPrefix, StringComparison.OrdinalIgnoreCase))
        {
            var path = frontend[csharpPrefix.Length..];
            if (!string.IsNullOrWhiteSpace(path))
                return path;
        }

        throw new ArgumentException(
            "unsupported vnext frontend: expected 'moon' or 'csharp:<exe|dll|csproj>'"
        );
    }

    private static VNextFrontendRequest BuildVNextFrontendRequest(
        string mainFile,
        string moduleName,
        string moonPkgPath,
        IReadOnlyList<string> importedRoots,
        string? moonModPath
    )
    {
        var moonbitDirectory = Path.Combine(RepositoryRoot(), "moonbit");
        var mainFileFullPath = Path.GetFullPath(mainFile);
        var moonPkgFullPath = Path.GetFullPath(moonPkgPath);
        var sources = new List<VNextSourceUnit>
        {
            new(
                MoonFrontendPath(moonbitDirectory, mainFileFullPath),
                File.ReadAllText(mainFileFullPath)
            ),
        };
        foreach (
            var source in PackageSourceFiles(Path.GetDirectoryName(mainFileFullPath)!)
                .Where(path =>
                    !Path.GetFullPath(path)
                        .Equals(mainFileFullPath, StringComparison.OrdinalIgnoreCase)
                )
        )
        {
            sources.Add(new(MoonFrontendPath(moonbitDirectory, source), File.ReadAllText(source)));
        }

        var importedSources = new List<VNextPackageSource>();
        var importedDeclarationSources = new List<VNextPackageSource>();
        var importedManifestSources = new List<VNextSourceUnit>();
        foreach (
            var importedRoot in SortVNextImportedRootsByDependencies(importedRoots, moonModPath)
        )
        {
            var modulePath =
                SourceLocationPackageNameForPackageRoot(importedRoot, moonModPath)
                ?? EnvPackageNameForPackageRoot(importedRoot, moonModPath)
                ?? NormalizePackageName(Path.GetFileName(importedRoot));
            var importRef = new VNextImportRef(
                DefaultMoonPkgAlias(modulePath),
                "pkg:" + modulePath,
                modulePath
            );
            if (FindMoonPkg(importedRoot) is { } importedMoonPkgPath)
                importedManifestSources.Add(
                    new(
                        MoonFrontendPath(moonbitDirectory, importedMoonPkgPath),
                        File.ReadAllText(importedMoonPkgPath)
                    )
                );

            foreach (var file in VNextImportedPackageFiles(importedRoot, modulePath))
                importedSources.Add(
                    new(importRef, MoonFrontendPath(moonbitDirectory, file), File.ReadAllText(file))
                );
        }

        foreach (var source in VNextCoreImplementationSources())
            importedSources.Add(
                new(
                    new(source.Alias, source.PackageId, source.ModulePath),
                    MoonFrontendPath(moonbitDirectory, source.Path),
                    File.ReadAllText(source.Path)
                )
            );

        foreach (var source in VNextCoreDeclarationSources())
            importedDeclarationSources.Add(
                new(
                    new(source.Alias, source.PackageId, source.ModulePath),
                    MoonFrontendPath(moonbitDirectory, source.Path),
                    File.ReadAllText(source.Path)
                )
            );

        return new VNextFrontendRequest(
            sources,
            moduleName,
            File.ReadAllText(moonPkgFullPath),
            MoonFrontendPath(moonbitDirectory, moonPkgFullPath),
            importedSources,
            importedDeclarationSources,
            importedManifestSources
        );
    }

    private static void LogVNextMoonProfile(string stderr)
    {
        foreach (var line in stderr.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries))
        {
            if (!line.StartsWith("vnext-profile:", StringComparison.Ordinal))
                continue;

            var json = line["vnext-profile:".Length..].Trim();
            try
            {
                using var document = JsonDocument.Parse(json);
                var events = document
                    .RootElement.GetProperty("events")
                    .EnumerateArray()
                    .Select(item =>
                    {
                        var name = item.GetProperty("name").GetString() ?? "";
                        var elapsedMs = item.GetProperty("elapsedMs").GetUInt64();
                        var count = item.TryGetProperty("count", out var countElement)
                            ? countElement.GetInt32()
                            : -1;
                        return (Name: name, ElapsedMs: elapsedMs, Count: count);
                    })
                    .ToArray();
                var total = events.FirstOrDefault(item => item.Name == "total");
                if (total.Name is not null)
                    TranspilerProfiler.Log(
                        "vnext moon total: "
                            + (total.ElapsedMs / 1000.0).ToString(
                                "n3",
                                CultureInfo.InvariantCulture
                            )
                            + "s"
                    );

                foreach (
                    var group in events
                        .GroupBy(item => ProfileGroupName(item.Name))
                        .OrderByDescending(group => group.Sum(item => (long)item.ElapsedMs))
                        .Take(8)
                )
                {
                    var elapsedMs = group.Sum(item => (long)item.ElapsedMs);
                    TranspilerProfiler.Log(
                        "vnext moon phase "
                            + group.Key
                            + ": "
                            + (elapsedMs / 1000.0).ToString("n3", CultureInfo.InvariantCulture)
                            + "s across "
                            + group.Count().ToString(CultureInfo.InvariantCulture)
                            + " event(s)"
                    );
                }
            }
            catch (Exception ex) when (ex is JsonException or InvalidOperationException)
            {
                TranspilerProfiler.Log("vnext moon " + line);
            }
        }
    }

    private static string ProfileGroupName(string eventName)
    {
        var colon = eventName.IndexOf(':', StringComparison.Ordinal);
        return colon < 0 ? eventName : eventName[..colon];
    }

    private static IReadOnlyList<string> SortVNextImportedRootsByDependencies(
        IReadOnlyList<string> importedRoots,
        string? moonModPath
    )
    {
        var roots = importedRoots
            .Select(Path.GetFullPath)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
        var rootSet = roots.ToHashSet(StringComparer.OrdinalIgnoreCase);
        var visited = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var visiting = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var sorted = new List<string>();

        foreach (var root in roots.Order(StringComparer.OrdinalIgnoreCase))
            Visit(root);

        return sorted;

        void Visit(string root)
        {
            if (visited.Contains(root))
                return;
            if (!visiting.Add(root))
                return;

            foreach (
                var dependency in ImportedMooncakePackageRoots(root, moonModPath)
                    .Select(Path.GetFullPath)
                    .Where(rootSet.Contains)
                    .Order(StringComparer.OrdinalIgnoreCase)
            )
                Visit(dependency);

            visiting.Remove(root);
            visited.Add(root);
            sorted.Add(root);
        }
    }

    private static IReadOnlyList<string> VNextImportedPackageFiles(
        string packageRoot,
        string modulePath
    )
    {
        if (modulePath == "moonbitlang/core/env")
        {
            var envOverride = Path.Combine(
                RepositoryRoot(),
                "moonbit",
                "builtin",
                "overrides",
                "core_env_env_csharp.mbt"
            );
            if (File.Exists(envOverride))
                return [Path.GetFullPath(envOverride)];
        }

        var sourceFiles = PackageSourceFiles(packageRoot);
        if (sourceFiles.Count > 0)
            return sourceFiles;

        foreach (var fileName in new[] { "pkg.generated.mbti", "pkg.mbti" })
        {
            var path = Path.Combine(packageRoot, fileName);
            if (File.Exists(path))
                return [Path.GetFullPath(path)];
        }

        var interfaceFiles = Directory
            .EnumerateFiles(packageRoot, "*.mbti", SearchOption.TopDirectoryOnly)
            .Order(StringComparer.Ordinal)
            .Select(Path.GetFullPath)
            .ToArray();
        return interfaceFiles.Length > 0 ? interfaceFiles : PackageSourceFiles(packageRoot);
    }

    private static string MoonFrontendPath(string moonbitDirectory, string path)
    {
        var fullPath = Path.GetFullPath(path);
        return Path.GetRelativePath(moonbitDirectory, fullPath);
    }

    private static IReadOnlyList<VNextDeclarationSource> VNextCoreDeclarationSources()
    {
        var root = RepositoryRoot();
        var result = new List<VNextDeclarationSource>();
        AddDeclarationSource(
            result,
            "abort",
            "pkg:moonbitlang/core/abort",
            "moonbitlang/core/abort",
            Path.Combine(root, "moonbitlang", "core", "abort", "abort.mbt")
        );
        AddOfficialCorePackageDeclarationSources(
            result,
            "builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbitlang", "core", "builtin")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "src", "vnext_core_csharp", "core_array.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "builtin", "overrides", "core_iterable.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "src", "vnext_core_csharp", "core_string.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "src", "vnext_core_csharp", "core_stringview.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "builtin", "overrides", "core_bytesview_csharp.mbt")
        );
        AddOfficialCorePackageDeclarationSources(
            result,
            "debug",
            "moonbitlang/core/debug",
            Path.Combine(root, "moonbitlang", "core", "debug")
        );
        AddOfficialCorePackageDeclarationSources(
            result,
            "error",
            "moonbitlang/core/error",
            Path.Combine(root, "moonbitlang", "core", "error")
        );
        AddDeclarationSource(
            result,
            "error",
            "pkg:moonbitlang/core/error",
            "moonbitlang/core/error",
            Path.Combine(root, "moonbit", "src", "vnext_core_csharp", "core_error.mbt")
        );
        AddOfficialCorePackageDeclarationSources(
            result,
            "set",
            "moonbitlang/core/set",
            Path.Combine(root, "moonbitlang", "core", "set")
        );
        AddDeclarationSource(
            result,
            "env",
            "pkg:moonbitlang/core/env",
            "moonbitlang/core/env",
            Path.Combine(root, "moonbit", "builtin", "overrides", "core_env_env_csharp.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "builtin", "overrides", "core_traits_csharp.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(
                root,
                "moonbit",
                "src",
                "vnext_core_csharp",
                "core_stringbuilder_traits.mbt"
            )
        );
        AddDeclarationSource(
            result,
            "debug",
            "pkg:moonbitlang/core/debug",
            "moonbitlang/core/debug",
            Path.Combine(root, "moonbit", "src", "vnext_core_csharp", "core_debug_show.mbt")
        );

        return result;
    }

    private static void AddOfficialCorePackageDeclarationSources(
        List<VNextDeclarationSource> result,
        string alias,
        string modulePath,
        string packageRoot
    )
    {
        foreach (var path in OfficialCorePackageSourceFilesForTarget(packageRoot, "csharp"))
        {
            if (
                modulePath == "moonbitlang/core/builtin"
                && Path.GetFileName(path)
                    .StartsWith("stringbuilder", StringComparison.OrdinalIgnoreCase)
            )
                continue;
            if (
                modulePath == "moonbitlang/core/builtin"
                && Path.GetFileName(path).Equals("iterator.mbt", StringComparison.OrdinalIgnoreCase)
            )
                continue;
            AddDeclarationSource(result, alias, "pkg:" + modulePath, modulePath, path);
        }
    }

    private static IReadOnlyList<VNextDeclarationSource> VNextCoreImplementationSources()
    {
        var root = RepositoryRoot();
        var result = new List<VNextDeclarationSource>();
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbitlang", "core", "builtin", "traits.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbitlang", "core", "builtin", "intrinsics.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "builtin", "overrides", "core_traits_csharp.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(
                root,
                "moonbit",
                "src",
                "vnext_core_csharp",
                "core_stringbuilder_traits.mbt"
            )
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "src", "vnext_core_csharp", "core_stringbuilder.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "src", "vnext_core_csharp", "core_bool.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "src", "vnext_core_csharp", "core_char.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "src", "vnext_core_csharp", "core_array.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "src", "vnext_core_csharp", "core_arrayview.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "src", "vnext_core_csharp", "core_int.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "src", "vnext_core_csharp", "core_numeric_intrinsics.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "builtin", "overrides", "core_intrinsics_csharp.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "src", "vnext_core_csharp", "core_numeric_ops.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(
                root,
                "moonbit",
                "builtin",
                "overrides",
                "core_builtin_to_string_csharp.mbt"
            )
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "builtin", "overrides", "core_iterable.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "src", "vnext_core_csharp", "core_option.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "src", "vnext_core_csharp", "core_string.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "src", "vnext_core_csharp", "core_stringview.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbit", "builtin", "overrides", "core_bytesview_csharp.mbt")
        );
        AddDeclarationSource(
            result,
            "builtin",
            "pkg:moonbitlang/core/builtin",
            "moonbitlang/core/builtin",
            Path.Combine(root, "moonbitlang", "core", "builtin", "linked_hash_map.mbt")
        );
        AddDeclarationSource(
            result,
            "debug",
            "pkg:moonbitlang/core/debug",
            "moonbitlang/core/debug",
            Path.Combine(root, "moonbit", "src", "vnext_core_csharp", "core_debug_show.mbt")
        );
        AddDeclarationSource(
            result,
            "debug",
            "pkg:moonbitlang/core/debug",
            "moonbitlang/core/debug",
            Path.Combine(root, "moonbitlang", "core", "debug", "repr.mbt")
        );
        AddDeclarationSource(
            result,
            "debug",
            "pkg:moonbitlang/core/debug",
            "moonbitlang/core/debug",
            Path.Combine(root, "moonbitlang", "core", "debug", "debug.mbt")
        );
        AddDeclarationSource(
            result,
            "debug",
            "pkg:moonbitlang/core/debug",
            "moonbitlang/core/debug",
            Path.Combine(root, "moonbitlang", "core", "debug", "printer.mbt")
        );
        AddDeclarationSource(
            result,
            "debug",
            "pkg:moonbitlang/core/debug",
            "moonbitlang/core/debug",
            Path.Combine(root, "moonbitlang", "core", "debug", "pretty_print.mbt")
        );
        AddDeclarationSource(
            result,
            "error",
            "pkg:moonbitlang/core/error",
            "moonbitlang/core/error",
            Path.Combine(root, "moonbit", "src", "vnext_core_csharp", "core_error.mbt")
        );
        AddDeclarationSource(
            result,
            "set",
            "pkg:moonbitlang/core/set",
            "moonbitlang/core/set",
            Path.Combine(root, "moonbitlang", "core", "set", "grow_heuristic.mbt")
        );
        AddDeclarationSource(
            result,
            "set",
            "pkg:moonbitlang/core/set",
            "moonbitlang/core/set",
            Path.Combine(root, "moonbitlang", "core", "set", "linked_hash_set.mbt")
        );
        AddDeclarationSource(
            result,
            "set",
            "pkg:moonbitlang/core/set",
            "moonbitlang/core/set",
            Path.Combine(root, "moonbitlang", "core", "set", "debug.mbt")
        );
        AddDeclarationSource(
            result,
            "env",
            "pkg:moonbitlang/core/env",
            "moonbitlang/core/env",
            Path.Combine(root, "moonbit", "builtin", "overrides", "core_env_env_csharp.mbt")
        );
        return result;
    }

    private static void AddDeclarationSource(
        List<VNextDeclarationSource> sources,
        string alias,
        string packageId,
        string modulePath,
        string path
    )
    {
        if (File.Exists(path))
            sources.Add(new(alias, packageId, modulePath, Path.GetFullPath(path)));
    }

    private static string? FindMoonPkg(string packageRoot)
    {
        return new[] { "moon.pkg", "moon.pkg.json" }
            .Select(name => Path.Combine(packageRoot, name))
            .FirstOrDefault(File.Exists);
    }

    private static string DefaultMoonPkgAlias(string modulePath)
    {
        var parts = modulePath.Split('/', StringSplitOptions.RemoveEmptyEntries);
        return parts.Length == 0 ? modulePath : parts[^1];
    }

    private static ProjectOutputPlan ProjectOutputPaths(
        string outputDir,
        IReadOnlyList<MoonBitIrInput> irInputs,
        int builtinModuleCount,
        string singleFileName,
        bool referenceRuntime,
        bool writeProjectFile,
        string? projectName,
        string moonModPath,
        string runtimeProjectPath,
        bool upperPascalCaseNames
    )
    {
        if (
            writeProjectFile
            && string.IsNullOrWhiteSpace(projectName)
            && !string.IsNullOrWhiteSpace(moonModPath)
        )
            projectName = CSharpProjectFiles.ProjectNameFromMoonMod(Path.GetFullPath(moonModPath));

        var paths = new List<string>();
        if (!string.IsNullOrWhiteSpace(singleFileName))
        {
            paths.Add(Path.Combine(outputDir, singleFileName));
        }
        else
        {
            if (!referenceRuntime)
                paths.Add(Path.Combine(outputDir, "MoonBitRuntime.g.cs"));

            for (var i = 0; i < builtinModuleCount; i++)
                paths.Add(
                    Path.Combine(
                        outputDir,
                        i == 0 ? "MoonBitBuiltins.g.cs" : $"MoonBitBuiltins_{i + 1}.g.cs"
                    )
                );

            var usedOutputNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var input in irInputs)
                paths.Add(
                    Path.Combine(
                        outputDir,
                        UniqueGeneratedFileName(input.Path, usedOutputNames, upperPascalCaseNames)
                    )
                );
        }

        if (writeProjectFile && !string.IsNullOrWhiteSpace(projectName))
            paths.Add(Path.Combine(outputDir, projectName + ".csproj"));

        return new(projectName ?? "", paths);
    }

    private static void CleanUnplannedGeneratedOutputs(
        string outputDir,
        IReadOnlyList<string> expectedPaths
    )
    {
        if (!Directory.Exists(outputDir))
            return;

        var expected = expectedPaths
            .Select(Path.GetFullPath)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        foreach (
            var file in Directory.EnumerateFiles(outputDir, "*.g.cs", SearchOption.TopDirectoryOnly)
        )
            if (!expected.Contains(Path.GetFullPath(file)))
                File.Delete(file);
    }

    private static void WriteAllTextIfChanged(string path, string contents)
    {
        if (File.Exists(path) && File.ReadAllText(path) == contents)
            return;

        for (var attempt = 0; ; attempt++)
            try
            {
                File.WriteAllText(path, contents);
                return;
            }
            catch (IOException) when (attempt < 5)
            {
                Thread.Sleep(100);
            }
    }

    public static string SourceFromInputFile(string path)
    {
        var source = File.ReadAllText(path);
        return IsMbtx(path) ? StripMbtxPackagePrelude(source) : source;
    }

    public static string SafeModuleName(string name)
    {
        var safe = new string(
            name.Select(ch => char.IsLetterOrDigit(ch) || ch == '_' ? ch : '_').ToArray()
        );
        return safe.Length > 0 && (char.IsLetter(safe[0]) || safe[0] == '_')
            ? safe
            : "MoonBitPackage_" + safe;
    }

    public static bool IsMbtx(string path)
    {
        return path.EndsWith(".mbtx", StringComparison.OrdinalIgnoreCase);
    }

    public static string? FindMoonMod(string input)
    {
        var path = Path.GetFullPath(input);
        var dir = Directory.Exists(path) ? path : Path.GetDirectoryName(path);
        while (!string.IsNullOrWhiteSpace(dir))
        {
            var candidate = FindMoonModInDirectory(dir);
            if (candidate is not null)
                return candidate;

            dir = Directory.GetParent(dir)?.FullName;
        }

        return null;
    }

    public static string DefaultCSharpBuildDirectory(
        IReadOnlyList<string> inputs,
        string? moonModPath = null
    )
    {
        if (!string.IsNullOrWhiteSpace(moonModPath))
            return Path.Combine(
                Path.GetDirectoryName(Path.GetFullPath(moonModPath))!,
                "_build",
                "csharp"
            );

        var firstInput =
            inputs.Count == 0 ? Directory.GetCurrentDirectory() : Path.GetFullPath(inputs[0]);
        var moonMod = FindMoonMod(firstInput);
        if (!string.IsNullOrWhiteSpace(moonMod))
            return Path.Combine(Path.GetDirectoryName(moonMod)!, "_build", "csharp");

        var root = Directory.Exists(firstInput)
            ? firstInput
            : Path.GetDirectoryName(firstInput) ?? Directory.GetCurrentDirectory();
        return Path.Combine(root, "_build", "csharp");
    }

    // static MoonBitCompilationContext CreateCompilationContext() =>
    //     new(BuiltinDeclarationModules.Value);

    // static void AddInputIr(
    //     MoonBitCompilationContext context,
    //     List<MoonBitIrInput> irInputs,
    //     Dictionary<string, List<string>> sourceFileGroups,
    //     string inputPath,
    //     bool includeMainPackages,
    //     string? moonModPath,
    //     HashSet<string> handledPackageRoots
    // )
    // {
    //     if (Path.GetFileName(inputPath).Equals("moon.mod.json", StringComparison.OrdinalIgnoreCase))
    //     {
    //         AddInputIr(
    //             context,
    //             irInputs,
    //             sourceFileGroups,
    //             Path.GetDirectoryName(inputPath)!,
    //             includeMainPackages,
    //             moonModPath,
    //             handledPackageRoots
    //         );
    //         return;
    //     }

    //     if (
    //         File.Exists(inputPath)
    //         && inputPath.EndsWith(".ir.json", StringComparison.OrdinalIgnoreCase)
    //     )
    //     {
    //         irInputs.Add(new MoonBitIrInput(inputPath, File.ReadAllText(inputPath)));
    //         return;
    //     }

    //     if (File.Exists(inputPath))
    //     {
    //         if (
    //             inputPath.EndsWith(".mbt", StringComparison.OrdinalIgnoreCase) && !IsMbtx(inputPath)
    //         )
    //         {
    //             var dir = Path.GetDirectoryName(inputPath) ?? "";
    //             if (!sourceFileGroups.TryGetValue(dir, out var files))
    //             {
    //                 files = [];
    //                 sourceFileGroups.Add(dir, files);
    //             }

    //             files.Add(inputPath);
    //         }
    //         else
    //         {
    //             irInputs.Add(context.CompileFile(inputPath));
    //         }
    //         return;
    //     }

    //     if (!Directory.Exists(inputPath))
    //     {
    //         throw new FileNotFoundException("input not found", inputPath);
    //     }

    //     var packageRoots = Directory
    //         .EnumerateDirectories(inputPath, "*", SearchOption.AllDirectories)
    //         .Where(path => !IsUnderMooncakes(path))
    //         .Where(IsPackageRoot)
    //         .Where(path => includeMainPackages || !IsMainPackage(path))
    //         .Order(StringComparer.Ordinal)
    //         .ToList();
    //     if (Directory.EnumerateFiles(inputPath, "*.mbt", SearchOption.TopDirectoryOnly).Any())
    //     {
    //         packageRoots.Insert(0, inputPath);
    //     }

    //     foreach (var packageRoot in packageRoots.Distinct(StringComparer.OrdinalIgnoreCase))
    //     {
    //         if (!handledPackageRoots.Add(Path.GetFullPath(packageRoot)))
    //         {
    //             continue;
    //         }

    //         context.AddPackageIr(
    //             irInputs,
    //             packageRoot,
    //             SourceLocationPackageNameForPackageRoot(packageRoot, moonModPath),
    //             EnvPackageNameForPackageRoot(packageRoot, moonModPath)
    //         );
    //     }
    // }

    private static string ModuleNameForPackage(
        string packageRoot,
        string? sourceLocationPackageName,
        string? envPackageName
    )
    {
        var packageName = !string.IsNullOrWhiteSpace(envPackageName)
            ? envPackageName
            : sourceLocationPackageName;
        return !string.IsNullOrWhiteSpace(packageName)
            ? packageName
            : SafeModuleName(Path.GetFileName(packageRoot));
    }

    private static IReadOnlyList<string> PackageSourceFiles(string packageRoot)
    {
        return Directory
            .EnumerateFiles(packageRoot, "*.mbt", SearchOption.TopDirectoryOnly)
            .Where(IsSourceCandidate)
            .Order(StringComparer.Ordinal)
            .Select(Path.GetFullPath)
            .ToList();
    }

    private static IReadOnlyList<MoonBitPackageInput> ResolvePackageInputs(
        IReadOnlyList<string> inputs,
        bool includeMainPackages,
        string? moonModPath
    )
    {
        var results = new List<MoonBitPackageInput>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var queued = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var queue = new Queue<string>();
        foreach (var input in inputs)
        foreach (var root in InputPackageRoots(input, includeMainPackages))
            Enqueue(root);

        while (queue.Count > 0)
        {
            var root = queue.Dequeue();
            AddPackage(root, true);
            foreach (var dependency in ImportedMooncakePackageRoots(root, moonModPath))
                Enqueue(dependency);
        }

        if (results.Count != 0)
            TranspilerProfiler.Log(
                "resolved packages: "
                    + string.Join(
                        ", ",
                        results.Select(package =>
                            package.SourceLocationPackageName
                            ?? package.EnvPackageName
                            ?? Path.GetFileName(package.PackageRoot)
                        )
                    )
            );
        return results;

        void Enqueue(string packageRoot)
        {
            var fullRoot = Path.GetFullPath(packageRoot);
            if (queued.Add(fullRoot))
                queue.Enqueue(fullRoot);
        }

        void AddPackage(string packageRoot, bool emitOutput)
        {
            var fullRoot = Path.GetFullPath(packageRoot);
            if (!seen.Add(fullRoot))
                return;

            results.Add(
                new(
                    fullRoot,
                    EnvPackageNameForPackageRoot(fullRoot, moonModPath),
                    SourceLocationPackageNameForPackageRoot(fullRoot, moonModPath),
                    emitOutput
                )
            );
        }
    }

    private static IReadOnlyList<string> InputPackageRoots(
        string inputPath,
        bool includeMainPackages
    )
    {
        if (IsMoonModFileName(inputPath))
            return InputPackageRoots(Path.GetDirectoryName(inputPath)!, includeMainPackages);

        if (!Directory.Exists(inputPath))
            return [];

        if (
            FindMoonMod(inputPath) is { } moonMod
            && Path.GetFullPath(Path.GetDirectoryName(moonMod) ?? "")
                .Equals(Path.GetFullPath(inputPath), StringComparison.OrdinalIgnoreCase)
        )
        {
            var moduleRoots = new List<string>();
            var rootPackage = PackageRootForMoonModuleRoot(inputPath);
            if (rootPackage is not null)
                moduleRoots.Add(rootPackage);

            foreach (
                var packageRoot in Directory.EnumerateDirectories(
                    inputPath,
                    "*",
                    SearchOption.TopDirectoryOnly
                )
            )
            {
                if (
                    Path.GetFileName(packageRoot)
                        .Equals(".mooncakes", StringComparison.OrdinalIgnoreCase)
                    || !IsPackageRoot(packageRoot)
                    || (!includeMainPackages && IsMainPackage(packageRoot))
                )
                    continue;

                moduleRoots.Add(packageRoot);
            }

            return moduleRoots
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .Select(Path.GetFullPath)
                .ToArray();
        }

        var roots = Directory
            .EnumerateDirectories(inputPath, "*", SearchOption.AllDirectories)
            .Where(path => !IsUnderMooncakes(path))
            .Where(IsPackageRoot)
            .Where(path => includeMainPackages || !IsMainPackage(path))
            .Order(StringComparer.Ordinal)
            .ToList();
        if (Directory.EnumerateFiles(inputPath, "*.mbt", SearchOption.TopDirectoryOnly).Any())
            roots.Insert(0, inputPath);

        return roots.Distinct(StringComparer.OrdinalIgnoreCase).Select(Path.GetFullPath).ToArray();
    }

    private static bool InputCoveredByResolvedPackages(
        string inputPath,
        bool includeMainPackages,
        HashSet<string> handledPackageRoots
    )
    {
        if (File.Exists(inputPath))
        {
            if (IsMoonModFileName(inputPath))
                inputPath = Path.GetDirectoryName(inputPath)!;
            else
                return false;
        }

        if (!Directory.Exists(inputPath))
            return false;

        foreach (var root in InputPackageRoots(inputPath, includeMainPackages))
            if (handledPackageRoots.Contains(Path.GetFullPath(root)))
                return true;

        return false;
    }

    private static IReadOnlyList<string> ImportedMooncakePackageRoots(
        string packageRoot,
        string? moonModPath
    )
    {
        var moonPkgPath = new[] { "moon.pkg", "moon.pkg.json" }
            .Select(name => Path.Combine(packageRoot, name))
            .FirstOrDefault(File.Exists);
        if (moonPkgPath is null)
            return [];

        var packageMoonModPath = FindMoonMod(packageRoot);
        var resolvedMoonModPath = !string.IsNullOrWhiteSpace(packageMoonModPath)
            ? packageMoonModPath
            : moonModPath;
        var moduleRoot = string.IsNullOrWhiteSpace(resolvedMoonModPath)
            ? ""
            : Path.GetDirectoryName(Path.GetFullPath(resolvedMoonModPath)) ?? "";
        if (string.IsNullOrWhiteSpace(moduleRoot))
            return [];

        var roots = new List<string>();
        foreach (var importPath in MoonPkgImportPaths(moonPkgPath))
        {
            if (
                importPath.StartsWith("moonbitlang/core/", StringComparison.Ordinal)
                || importPath == "moonbitlang/core"
            )
                continue;

            var candidate = ResolveMooncakePackageRoot(moduleRoot, importPath);
            if (candidate is not null)
                roots.Add(candidate);
        }

        return roots;
    }

    private static string? PackageRootForMoonModuleRoot(string moduleRoot)
    {
        var sourceRoot = MoonModuleSourceRoot(moduleRoot);
        if (Directory.Exists(sourceRoot) && IsPackageRoot(sourceRoot))
            return Path.GetFullPath(sourceRoot);

        return IsPackageRoot(moduleRoot) ? Path.GetFullPath(moduleRoot) : null;
    }

    private static string? ResolveMooncakePackageRoot(string moduleRoot, string importPath)
    {
        var sameModulePackage = ResolveSameModulePackageRoot(moduleRoot, importPath);
        if (sameModulePackage is not null)
            return sameModulePackage;

        var mooncakesRoot = Path.Combine(moduleRoot, ".mooncakes");
        if (!Directory.Exists(mooncakesRoot))
            return null;

        var parts = importPath.Split('/', StringSplitOptions.RemoveEmptyEntries);
        for (var modulePartCount = parts.Length; modulePartCount >= 2; modulePartCount--)
        {
            var candidateModule = Path.Combine(
                new[] { mooncakesRoot }.Concat(parts.Take(modulePartCount)).ToArray()
            );
            if (FindMoonModInDirectory(candidateModule) is null)
                continue;

            var sourceRoot = MoonModuleSourceRoot(candidateModule);
            var packageRoot = Path.Combine(
                new[] { sourceRoot }.Concat(parts.Skip(modulePartCount)).ToArray()
            );
            if (Directory.Exists(packageRoot) && IsPackageRoot(packageRoot))
                return Path.GetFullPath(packageRoot);
        }

        var directCandidate = Path.Combine(new[] { mooncakesRoot }.Concat(parts).ToArray());
        return Directory.Exists(directCandidate) && IsPackageRoot(directCandidate)
            ? Path.GetFullPath(directCandidate)
            : null;
    }

    private static string? ResolveSameModulePackageRoot(string moduleRoot, string importPath)
    {
        var moonModPath = FindMoonModInDirectory(moduleRoot);
        if (moonModPath is null)
            return null;

        var moduleName = MoonModuleNameFromMoonMod(moonModPath);
        if (string.IsNullOrWhiteSpace(moduleName))
            return null;

        if (!importPath.StartsWith(moduleName + "/", StringComparison.Ordinal))
            return null;

        var relative = importPath[(moduleName.Length + 1)..];
        var candidate = Path.Combine(
            new[] { MoonModuleSourceRoot(moduleRoot) }.Concat(relative.Split('/')).ToArray()
        );
        return Directory.Exists(candidate) && IsPackageRoot(candidate)
            ? Path.GetFullPath(candidate)
            : null;
    }

    // static void AddOfficialCoreEnvironmentPackages(
    //     MoonBitCompilationContext context,
    //     IReadOnlyList<string> inputs,
    //     bool includeMainPackages
    // )
    // {
    //     var coreRoot = BuiltinDeclarationLoader.FindRepositoryPath(
    //         AppContext.BaseDirectory,
    //         "moonbitlang",
    //         "core"
    //     );
    //     if (coreRoot is null || !Directory.Exists(coreRoot))
    //     {
    //         return;
    //     }

    //     var added = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    //     foreach (var input in inputs)
    //     {
    //         foreach (var packageRoot in ImportPackageRoots(input, includeMainPackages))
    //         {
    //             var moonPkgPath = new[] { "moon.pkg", "moon.pkg.json" }
    //                 .Select(name => Path.Combine(packageRoot, name))
    //                 .FirstOrDefault(File.Exists);
    //             if (moonPkgPath is null)
    //             {
    //                 continue;
    //             }

    //             foreach (var importPath in MoonPkgImportPaths(moonPkgPath))
    //             {
    //                 if (
    //                     importPath == "moonbitlang/core"
    //                     || !importPath.StartsWith("moonbitlang/core/", StringComparison.Ordinal)
    //                 )
    //                 {
    //                     continue;
    //                 }

    //                 var relative = importPath["moonbitlang/core/".Length..];
    //                 var packagePath = Path.Combine(
    //                     new[] { coreRoot }.Concat(relative.Split('/')).ToArray()
    //                 );
    //                 if (!Directory.Exists(packagePath) || !added.Add(packagePath))
    //                 {
    //                     continue;
    //                 }

    //                 var packageName = relative.Split('/').Last();
    //                 var overrideSources = OfficialCorePackageCSharpOverrideSources(relative);
    //                 if (overrideSources.Count > 0)
    //                 {
    //                     context.AddEnvironmentFiles(overrideSources, packageName);
    //                 }
    //                 else if (OfficialCorePackageHasInitializedGlobals(packagePath))
    //                 {
    //                     context.AddEnvironmentPackage(packagePath, packageName);
    //                 }
    //             }
    //         }
    //     }
    // }

    // static IReadOnlySet<string> CoreBuiltinRuntimeFeatures(CoreBuiltinImplementationPlan plan) =>
    //     plan
    //         .Metadata.SelectMany(metadata => metadata.RuntimeFeatures)
    //         .ToHashSet(StringComparer.Ordinal);

    private static IReadOnlyList<string> ImportPackageRoots(string input, bool includeMainPackages)
    {
        var roots = new SortedSet<string>(
            ResolvePackageInputs([Path.GetFullPath(input)], includeMainPackages, null)
                .Select(package => package.PackageRoot),
            StringComparer.OrdinalIgnoreCase
        );
        var directRoot = Directory.Exists(input)
            ? Path.GetFullPath(input)
            : Path.GetDirectoryName(Path.GetFullPath(input));
        if (
            !string.IsNullOrWhiteSpace(directRoot)
            && (
                File.Exists(Path.Combine(directRoot, "moon.pkg"))
                || File.Exists(Path.Combine(directRoot, "moon.pkg.json"))
            )
        )
            roots.Add(directRoot);

        return roots.ToArray();
    }

    private static bool OfficialCorePackageHasInitializedGlobals(string packagePath)
    {
        return Directory
            .EnumerateFiles(packagePath, "*.mbt", SearchOption.TopDirectoryOnly)
            .Where(IsSourceCandidate)
            .SelectMany(File.ReadLines)
            .Any(line =>
                Regex.IsMatch(
                    line,
                    @"^\s*pub\s+(?:let|const)\s+[A-Za-z_][A-Za-z0-9_]*\b.*=",
                    RegexOptions.CultureInvariant
                )
            );
    }

    private static IEnumerable<string> MoonPkgImportPaths(string moonPkgPath)
    {
        var source = File.ReadAllText(moonPkgPath);
        if (moonPkgPath.EndsWith(".json", StringComparison.OrdinalIgnoreCase))
        {
            foreach (var importPath in JsonMoonPkgImportPaths(source))
                yield return importPath;

            yield break;
        }

        foreach (var importPath in TextMoonPkgImportPaths(source))
            yield return importPath;
    }

    private static IEnumerable<string> JsonMoonPkgImportPaths(string moonPkgSource)
    {
        using var document = JsonDocument.Parse(moonPkgSource);
        if (
            !document.RootElement.TryGetProperty("import", out var imports)
            || imports.ValueKind != JsonValueKind.Array
        )
            yield break;

        foreach (var item in imports.EnumerateArray())
            if (item.ValueKind == JsonValueKind.String && item.GetString() is { } path)
                yield return path;
            else if (
                item.ValueKind == JsonValueKind.Object
                && item.TryGetProperty("path", out var pathProperty)
                && pathProperty.ValueKind == JsonValueKind.String
                && pathProperty.GetString() is { } objectPath
            )
                yield return objectPath;
    }

    private static bool JsonMoonPkgHasVirtualOption(string moonPkgSource)
    {
        using var document = JsonDocument.Parse(moonPkgSource);
        return document.RootElement.TryGetProperty("virtual", out _)
            || (
                document.RootElement.TryGetProperty("options", out var options)
                && options.ValueKind == JsonValueKind.Object
                && options.TryGetProperty("virtual", out _)
            );
    }

    private static bool JsonMoonPkgBoolOption(string moonPkgSource, string optionName)
    {
        using var document = JsonDocument.Parse(moonPkgSource);
        return JsonObjectBoolOption(document.RootElement, optionName)
            || (
                document.RootElement.TryGetProperty("options", out var options)
                && options.ValueKind == JsonValueKind.Object
                && JsonObjectBoolOption(options, optionName)
            );
    }

    private static bool JsonObjectBoolOption(JsonElement obj, string optionName)
    {
        return obj.ValueKind == JsonValueKind.Object
            && obj.TryGetProperty(optionName, out var option)
            && option.ValueKind == JsonValueKind.True;
    }

    private static IEnumerable<string> TextMoonPkgImportPaths(string moonPkgSource)
    {
        var source = RemoveMoonPkgLineComments(moonPkgSource);
        for (var index = 0; index < source.Length; )
        {
            var importIndex = IndexOfWord(source, "import", index);
            if (importIndex < 0)
                yield break;

            var braceStart = source.IndexOf('{', importIndex + "import".Length);
            if (braceStart < 0)
                yield break;

            var braceEnd = MatchingBraceEnd(source, braceStart);
            if (braceEnd < 0)
                yield break;

            foreach (var quoted in QuotedStrings(source, braceStart + 1, braceEnd))
                yield return quoted;

            index = braceEnd + 1;
        }
    }

    private static bool TextMoonPkgHasVirtualOption(string moonPkgSource)
    {
        var source = RemoveMoonPkgLineComments(moonPkgSource);
        return source.Contains("\"virtual\"", StringComparison.Ordinal)
            || IndexOfWord(source, "virtual", 0) >= 0;
    }

    private static bool TextMoonPkgBoolOption(string moonPkgSource, string optionName)
    {
        var source = RemoveMoonPkgLineComments(moonPkgSource);
        for (var index = 0; index < source.Length; )
        {
            var optionsIndex = IndexOfWord(source, "options", index);
            if (optionsIndex < 0)
                return false;

            var parenStart = source.IndexOf('(', optionsIndex + "options".Length);
            if (parenStart < 0)
                return false;

            var parenEnd = MatchingDelimitedEnd(source, parenStart, '(', ')');
            if (parenEnd < 0)
                return false;

            var body = source[(parenStart + 1)..parenEnd];
            var optionPattern =
                @"(?:"""
                + Regex.Escape(optionName)
                + @"""|"
                + Regex.Escape(optionName)
                + @")\s*:\s*true\b";
            if (Regex.IsMatch(body, optionPattern, RegexOptions.CultureInvariant))
                return true;

            index = parenEnd + 1;
        }

        return false;
    }

    private static string RemoveMoonPkgLineComments(string source)
    {
        var builder = new StringBuilder(source.Length);
        var inString = false;
        var escaped = false;
        for (var i = 0; i < source.Length; i++)
        {
            var ch = source[i];
            if (inString)
            {
                builder.Append(ch);
                if (escaped)
                    escaped = false;
                else if (ch == '\\')
                    escaped = true;
                else if (ch == '"')
                    inString = false;

                continue;
            }

            if (ch == '"')
            {
                inString = true;
                builder.Append(ch);
                continue;
            }

            if (ch == '/' && i + 1 < source.Length && source[i + 1] == '/')
            {
                while (i < source.Length && source[i] != '\r' && source[i] != '\n')
                    i++;

                if (i < source.Length)
                    builder.Append(source[i]);

                continue;
            }

            builder.Append(ch);
        }

        return builder.ToString();
    }

    private static int IndexOfWord(string source, string word, int start)
    {
        for (var index = source.IndexOf(word, start, StringComparison.Ordinal); index >= 0; )
        {
            var beforeOk = index == 0 || !IsMoonPkgIdentifierChar(source[index - 1]);
            var afterIndex = index + word.Length;
            var afterOk =
                afterIndex == source.Length || !IsMoonPkgIdentifierChar(source[afterIndex]);
            if (beforeOk && afterOk)
                return index;

            index = source.IndexOf(word, index + word.Length, StringComparison.Ordinal);
        }

        return -1;
    }

    private static bool IsMoonPkgIdentifierChar(char ch)
    {
        return char.IsAsciiLetterOrDigit(ch) || ch == '_' || ch == '-';
    }

    private static int MatchingBraceEnd(string source, int braceStart)
    {
        return MatchingDelimitedEnd(source, braceStart, '{', '}');
    }

    private static int MatchingDelimitedEnd(string source, int start, char open, char close)
    {
        var depth = 0;
        var inString = false;
        var escaped = false;
        for (var i = start; i < source.Length; i++)
        {
            var ch = source[i];
            if (inString)
            {
                if (escaped)
                    escaped = false;
                else if (ch == '\\')
                    escaped = true;
                else if (ch == '"')
                    inString = false;

                continue;
            }

            if (ch == '"')
            {
                inString = true;
            }
            else if (ch == open)
            {
                depth++;
            }
            else if (ch == close)
            {
                depth--;
                if (depth == 0)
                    return i;
            }
        }

        return -1;
    }

    private static IEnumerable<string> QuotedStrings(string source, int start, int end)
    {
        for (var i = start; i < end; i++)
        {
            if (source[i] != '"')
                continue;

            var builder = new StringBuilder();
            var escaped = false;
            for (i++; i < end; i++)
            {
                var ch = source[i];
                if (escaped)
                {
                    builder.Append(ch);
                    escaped = false;
                }
                else if (ch == '\\')
                {
                    escaped = true;
                }
                else if (ch == '"')
                {
                    yield return builder.ToString();
                    break;
                }
                else
                {
                    builder.Append(ch);
                }
            }
        }
    }

    private static string? SourceLocationPackageNameForPackageRoot(
        string packageRoot,
        string? moonModPath
    )
    {
        moonModPath = EffectiveMoonModForPackageRoot(packageRoot, moonModPath);
        if (string.IsNullOrWhiteSpace(moonModPath) || !File.Exists(moonModPath))
            return null;

        var moduleRoot = Path.GetDirectoryName(Path.GetFullPath(moonModPath));
        if (string.IsNullOrWhiteSpace(moduleRoot))
            return null;

        var moduleName = MoonModuleNameFromMoonMod(moonModPath);
        if (string.IsNullOrWhiteSpace(moduleName))
            return null;

        var fullPackageRoot = Path.GetFullPath(packageRoot);
        var sourceRoot = MoonModuleSourceRoot(moduleRoot);
        var relativeSourcePackagePath = Path.GetRelativePath(sourceRoot, fullPackageRoot);
        if (!relativeSourcePackagePath.StartsWith("..", StringComparison.Ordinal))
            return relativeSourcePackagePath is "." or ""
                ? moduleName
                : moduleName + "/" + relativeSourcePackagePath.Replace('\\', '/');

        var relativePackagePath = Path.GetRelativePath(moduleRoot, fullPackageRoot);
        if (relativePackagePath.StartsWith("..", StringComparison.Ordinal))
            return null;

        return relativePackagePath is "." or ""
            ? moduleName
            : moduleName + "/" + relativePackagePath.Replace('\\', '/');
    }

    private static string? EnvPackageNameForPackageRoot(string packageRoot, string? moonModPath)
    {
        if (MooncakeMoonModForPackageRoot(packageRoot) is null)
            return null;

        var sourceLocationName = SourceLocationPackageNameForPackageRoot(packageRoot, moonModPath);
        if (!string.IsNullOrWhiteSpace(sourceLocationName))
            return NormalizePackageName(sourceLocationName);

        return SafeModuleName(Path.GetFileName(packageRoot));
    }

    private static string NormalizePackageName(string text)
    {
        var name = text.Trim('"');
        var lastSlash = name.LastIndexOf('/');
        if (lastSlash >= 0)
            name = name[(lastSlash + 1)..];

        return SafeModuleName(name);
    }

    private static string? EffectiveMoonModForPackageRoot(string packageRoot, string? moonModPath)
    {
        var mooncakeMoonMod = MooncakeMoonModForPackageRoot(packageRoot);
        if (!string.IsNullOrWhiteSpace(mooncakeMoonMod))
            return mooncakeMoonMod;

        return moonModPath;
    }

    private static string? MooncakeMoonModForPackageRoot(string packageRoot)
    {
        var dir = new DirectoryInfo(Path.GetFullPath(packageRoot));
        var insideMooncakes = false;
        while (dir is not null)
        {
            if (dir.Name == ".mooncakes")
            {
                insideMooncakes = true;
                break;
            }

            dir = dir.Parent;
        }

        if (!insideMooncakes)
            return null;

        dir = new(Path.GetFullPath(packageRoot));
        while (dir is not null && dir.Name != ".mooncakes")
        {
            var candidate = FindMoonModInDirectory(dir.FullName);
            if (candidate is not null)
                return candidate;

            dir = dir.Parent;
        }

        return null;
    }

    private static bool IsUnderMooncakes(string path)
    {
        var dir = new DirectoryInfo(Path.GetFullPath(path));
        while (dir is not null)
        {
            if (dir.Name == ".mooncakes")
                return true;

            dir = dir.Parent;
        }

        return false;
    }

    private static string? MoonModuleNameFromMoonMod(string moonModPath)
    {
        return MoonModManifest.FieldValue(moonModPath, "name");
    }

    private static string MoonModuleSourceRoot(string moduleRoot)
    {
        var moonModPath = FindMoonModInDirectory(moduleRoot);
        if (moonModPath is null)
            return moduleRoot;

        var source = MoonModManifest.FieldValue(moonModPath, "source");
        return string.IsNullOrWhiteSpace(source)
            ? Path.GetFullPath(moduleRoot)
            : Path.GetFullPath(Path.Combine(moduleRoot, source));
    }

    // static IReadOnlyList<SyntaxModule> LoadBuiltinDeclarationModules()
    // {
    //     return BuiltinDeclarationLoader.LoadFromRepository().DeclarationModules;
    // }

    private static bool IsPackageRoot(string path)
    {
        return Directory
                .EnumerateFiles(path, "*.mbt", SearchOption.TopDirectoryOnly)
                .Any(IsSourceCandidate)
            && !path.Split(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar)
                .Any(part => part is "_build" or "target" or "artifacts" or "bin" or "obj");
    }

    public static bool IsSourceCandidate(string path)
    {
        var fileName = Path.GetFileName(path);
        return !fileName.Contains("_test", StringComparison.Ordinal)
            && !fileName.Contains("_wbtest", StringComparison.Ordinal)
            && !fileName.Equals("bench.mbt", StringComparison.Ordinal)
            && !fileName.EndsWith("_bench.mbt", StringComparison.Ordinal)
            && !fileName.EndsWith(".test.mbt", StringComparison.Ordinal)
            && !fileName.EndsWith("_js.mbt", StringComparison.Ordinal)
            && !fileName.EndsWith("_wasm.mbt", StringComparison.Ordinal)
            && !fileName.EndsWith("_native.mbt", StringComparison.Ordinal);
    }

    private static bool IsMainPackage(string path)
    {
        return new[] { "moon.pkg", "moon.pkg.json" }
            .Select(name => Path.Combine(path, name))
            .Where(File.Exists)
            .Any(MoonPkgHasMainOption);
    }

    private static bool MoonPkgHasMainOption(string moonPkgPath)
    {
        var source = File.ReadAllText(moonPkgPath);
        return Path.GetExtension(moonPkgPath).Equals(".json", StringComparison.OrdinalIgnoreCase)
            ? JsonMoonPkgBoolOption(source, "is-main")
            : TextMoonPkgBoolOption(source, "is-main");
    }

    private static void CleanGeneratedOutputs(string outputDir)
    {
        foreach (
            var file in Directory.EnumerateFiles(outputDir, "*.g.cs", SearchOption.TopDirectoryOnly)
        )
            File.Delete(file);

        var irDir = Path.Combine(outputDir, "ir");
        if (Directory.Exists(irDir))
            foreach (
                var file in Directory.EnumerateFiles(
                    irDir,
                    "*.ir.json",
                    SearchOption.TopDirectoryOnly
                )
            )
                File.Delete(file);
    }

    private static string StripMbtxPackagePrelude(string source)
    {
        using var reader = new StringReader(source);
        var output = new List<string>();
        var inPackagePrelude = true;
        var skippingBlock = false;
        var blockDepth = 0;
        string? line;
        while ((line = reader.ReadLine()) is not null)
        {
            if (!inPackagePrelude)
            {
                output.Add(line);
                continue;
            }

            if (skippingBlock)
            {
                blockDepth += MbtxDelimiterDelta(line);
                if (blockDepth <= 0)
                    skippingBlock = false;

                continue;
            }

            var trimmed = line.TrimStart();
            if (trimmed.Length == 0 || trimmed.StartsWith("//", StringComparison.Ordinal))
                continue;

            if (
                IsMbtxPackageDirective(trimmed, "import")
                || IsMbtxPackageDirective(trimmed, "options")
            )
            {
                blockDepth = MbtxDelimiterDelta(line);
                skippingBlock = blockDepth > 0;
                continue;
            }

            inPackagePrelude = false;
            output.Add(line);
        }

        return string.Join(Environment.NewLine, output);
    }

    private static bool IsMbtxPackageDirective(string trimmed, string directive)
    {
        if (!trimmed.StartsWith(directive, StringComparison.Ordinal))
            return false;

        if (trimmed.Length == directive.Length)
            return true;

        var next = trimmed[directive.Length];
        return !char.IsLetterOrDigit(next) && next != '_';
    }

    private static int MbtxDelimiterDelta(string line)
    {
        var delta = 0;
        var inString = false;
        var escaped = false;
        foreach (var ch in line)
        {
            if (inString)
            {
                if (escaped)
                {
                    escaped = false;
                    continue;
                }

                if (ch == '\\')
                {
                    escaped = true;
                    continue;
                }

                if (ch == '"')
                    inString = false;

                continue;
            }

            if (ch == '"')
                inString = true;
            else if (ch is '{' or '(')
                delta++;
            else if (ch is '}' or ')')
                delta--;
        }

        return delta;
    }

    private static string UniqueGeneratedFileName(
        string inputPath,
        HashSet<string> usedOutputNames,
        bool upperPascalCaseNames
    )
    {
        var stem = Path.GetFileNameWithoutExtension(inputPath);
        if (stem.EndsWith(".ir", StringComparison.OrdinalIgnoreCase))
            stem = stem[..^".ir".Length];

        if (upperPascalCaseNames)
            stem = ToUpperPascalCaseIdentifier(stem);

        var safeStem = string.Concat(
            stem.Select(ch => Path.GetInvalidFileNameChars().Contains(ch) ? '_' : ch)
        );
        var outputName = safeStem + ".g.cs";
        var suffix = 2;
        while (!usedOutputNames.Add(outputName))
        {
            outputName = safeStem + "_" + suffix.ToString(CultureInfo.InvariantCulture) + ".g.cs";
            suffix++;
        }

        return outputName;
    }

    private static string ToUpperPascalCaseIdentifier(string name)
    {
        var result = new StringBuilder();
        var capitalize = true;
        foreach (var ch in name)
        {
            if (ch is '_' or '-' or ' ' or '.' or '/')
            {
                capitalize = true;
                continue;
            }

            result.Append(capitalize ? char.ToUpperInvariant(ch) : ch);
            capitalize = false;
        }

        return result.Length == 0 ? name : result.ToString();
    }

    private sealed record ProjectOutputPlan(string ProjectName, IReadOnlyList<string> Paths);
}
