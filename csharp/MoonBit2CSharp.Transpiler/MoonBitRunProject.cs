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
    public string GeneratedNamespace { get; init; } = "Generated.MoonBit";
    public string RuntimeNamespace { get; init; } = "MoonBit2CSharp.Runtime";
    public IReadOnlyList<string> AdditionalUsings { get; init; } = [];
    public IReadOnlyList<string> AdditionalProjectReferences { get; init; } = [];
    public bool CacheEnabled { get; init; } = true;
    public string CacheDirectory { get; init; } = "";
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
                TrimApplicationOutput = true,
            }
        );

        return new(outputDir, Path.Combine(outputDir, projectName + ".csproj"), result.WrittenFiles)
        {
            CacheHit = result.CacheHit,
        };
    }
}
