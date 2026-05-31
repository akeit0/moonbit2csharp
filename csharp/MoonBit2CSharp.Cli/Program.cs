using System.Diagnostics;
using MoonBit2CSharp.Transpiler;

try
{
    return args switch
    {
        ["run", ..] => RunGeneratedProject(args),
        ["build", ..] => BuildGeneratedProject(args),
        ["--project", _, ..] => RunProject(args),
        //_ => RunSingle(args),
        _ => PrintUsage(),
    };
}
catch (Exception ex)
    when (ex is ArgumentException or FileNotFoundException or InvalidOperationException)
{
    Console.Error.WriteLine(ex.Message);
    return 2;
}

// static int RunSingle(string[] args)
// {
//     var singleArgs = args.Where(arg => arg is not "--pascal-case").ToArray();
//     if (singleArgs.Length is < 1 or > 2)
//     {
//         PrintUsage();
//         return 2;
//     }

//     var inputPath = Path.GetFullPath(singleArgs[0]);
//     var outputPath =
//         singleArgs.Length == 2
//             ? Path.GetFullPath(singleArgs[1])
//             : Path.ChangeExtension(inputPath, ".generated.cs");
//     var upperPascalCaseNames = args.Contains("--pascal-case", StringComparer.Ordinal);
//     MoonBitSourceTranspiler.WriteFile(inputPath, outputPath, upperPascalCaseNames);

//     Console.WriteLine(outputPath);
//     return 0;
// }

static int RunGeneratedProject(string[] args)
{
    var result = PrepareGeneratedProject(args, "run", true, out var appArgs, out var release);
    return RunDotnetProject(
        result.ProjectPath,
        appArgs,
        result.CacheHit && DotnetBuildOutputExists(result.ProjectPath, release),
        release
    );
}

static int BuildGeneratedProject(string[] args)
{
    var result = PrepareGeneratedProject(args, "build", false, out _, out var release);
    Console.Error.WriteLine(
        result.CacheHit
            ? $"generated: {result.OutputDirectory} (cache hit)"
            : $"generated: {result.OutputDirectory}"
    );
    return BuildDotnetProject(result.ProjectPath, release);
}

static MoonBitRunProjectResult PrepareGeneratedProject(
    string[] args,
    string commandName,
    bool allowAppArgs,
    out string[] appArgs,
    out bool release
)
{
    var separator = Array.IndexOf(args, "--");
    if (separator >= 0 && !allowAppArgs)
        throw new ArgumentException($"{commandName} does not accept application arguments");

    var commandArgs = separator < 0 ? args[1..] : args[1..separator];
    appArgs = separator < 0 ? [] : args[(separator + 1)..];
    var outputDir = "";
    var projectName = "";
    var singleFileName = "";
    var moonModPath = "";
    var runtimeProjectPath = MoonBitSourceTranspiler.DefaultRuntimeProjectPath;
    var referenceRuntime = false;
    var includeMainPackages = false;
    var upperPascalCaseNames = false;
    var generatedNamespace = "Generated.MoonBit";
    var runtimeNamespace = "MoonBit2CSharp.Runtime";
    var cacheDirectory = "";
    var cacheEnabled = true;
    release = false;
    var additionalUsings = new List<string>();
    var additionalProjectReferences = new List<string>();
    var inputPaths = new List<string>();

    for (var i = 0; i < commandArgs.Length; i++)
        switch (commandArgs[i])
        {
            case "--out":
            case "-o":
                outputDir = Path.GetFullPath(RequireValue(commandArgs, ref i, commandArgs[i]));
                break;
            case "--csproj":
                projectName = RequireValue(commandArgs, ref i, "--csproj");
                break;
            case "--single-file":
                singleFileName = RequireValue(commandArgs, ref i, "--single-file");
                break;
            case "--moon-mod":
                moonModPath = Path.GetFullPath(RequireValue(commandArgs, ref i, "--moon-mod"));
                break;
            case "--runtime-project":
                runtimeProjectPath = Path.GetFullPath(
                    RequireValue(commandArgs, ref i, "--runtime-project")
                );
                referenceRuntime = true;
                break;
            case "--no-reference-runtime":
                referenceRuntime = false;
                break;
            case "--include-main-packages":
                includeMainPackages = true;
                break;
            case "--pascal-case":
                upperPascalCaseNames = true;
                break;
            case "--namespace":
                generatedNamespace = RequireValue(commandArgs, ref i, "--namespace");
                break;
            case "--runtime-namespace":
                runtimeNamespace = RequireValue(commandArgs, ref i, "--runtime-namespace");
                break;
            case "--cache-dir":
                cacheDirectory = Path.GetFullPath(RequireValue(commandArgs, ref i, "--cache-dir"));
                break;
            case "--no-cache":
                cacheEnabled = false;
                break;
            case "--release":
                release = true;
                break;
            case "--using":
                additionalUsings.Add(RequireValue(commandArgs, ref i, "--using"));
                break;
            case "--project-reference":
                additionalProjectReferences.Add(
                    Path.GetFullPath(RequireValue(commandArgs, ref i, "--project-reference"))
                );
                break;
            default:
                if (commandArgs[i].StartsWith("-", StringComparison.Ordinal))
                    throw new ArgumentException($"unknown {commandName} option: {commandArgs[i]}");

                inputPaths.Add(commandArgs[i]);
                break;
        }

    if (inputPaths.Count == 0)
        inputPaths.Add(Directory.GetCurrentDirectory());

    return MoonBitRunProject.Prepare(
        new(inputPaths.Select(Path.GetFullPath).ToArray())
        {
            OutputDirectory = outputDir == "" ? null : outputDir,
            ProjectName = projectName == "" ? null : projectName,
            SingleFileName = singleFileName,
            MoonModPath = moonModPath == "" ? null : moonModPath,
            RuntimeProjectPath = runtimeProjectPath,
            ReferenceRuntime = referenceRuntime,
            IncludeMainPackages = includeMainPackages,
            UpperPascalCaseNames = upperPascalCaseNames,
            GeneratedNamespace = generatedNamespace,
            RuntimeNamespace = runtimeNamespace,
            AdditionalUsings = additionalUsings,
            AdditionalProjectReferences = additionalProjectReferences,
            CacheDirectory = cacheDirectory,
            CacheEnabled = cacheEnabled,
        }
    );
}

static int RunProject(string[] args)
{
    var outputDir = Path.GetFullPath(args[1]);
    var singleFileName = "";
    var projectName = "";
    var writeProjectFile = true;
    var referenceRuntime = false;
    var executable = false;
    var includeMainPackages = false;
    var upperPascalCaseNames = false;
    var generatedNamespace = "Generated.MoonBit";
    var runtimeNamespace = "MoonBit2CSharp.Runtime";
    var cacheDirectory = "";
    var cacheEnabled = true;
    var additionalUsings = new List<string>();
    var additionalProjectReferences = new List<string>();
    var moonModPath = "";
    var runtimeProjectPath = MoonBitSourceTranspiler.DefaultRuntimeProjectPath;
    var inputPaths = new List<string>();

    for (var i = 2; i < args.Length; i++)
        switch (args[i])
        {
            case "--single-file":
                singleFileName = RequireValue(args, ref i, "--single-file");
                break;
            case "--csproj":
                projectName = RequireValue(args, ref i, "--csproj");
                break;
            case "--no-csproj":
                writeProjectFile = false;
                break;
            case "--moon-mod":
                moonModPath = Path.GetFullPath(RequireValue(args, ref i, "--moon-mod"));
                break;
            case "--reference-runtime":
                referenceRuntime = true;
                break;
            case "--exe":
                executable = true;
                break;
            case "--include-main-packages":
                includeMainPackages = true;
                break;
            case "--pascal-case":
                upperPascalCaseNames = true;
                break;
            case "--namespace":
                generatedNamespace = RequireValue(args, ref i, "--namespace");
                break;
            case "--runtime-namespace":
                runtimeNamespace = RequireValue(args, ref i, "--runtime-namespace");
                break;
            case "--cache-dir":
                cacheDirectory = Path.GetFullPath(RequireValue(args, ref i, "--cache-dir"));
                break;
            case "--no-cache":
                cacheEnabled = false;
                break;
            case "--using":
                additionalUsings.Add(RequireValue(args, ref i, "--using"));
                break;
            case "--project-reference":
                additionalProjectReferences.Add(
                    Path.GetFullPath(RequireValue(args, ref i, "--project-reference"))
                );
                break;
            case "--runtime-project":
                runtimeProjectPath = Path.GetFullPath(
                    RequireValue(args, ref i, "--runtime-project")
                );
                referenceRuntime = true;
                break;
            default:
                inputPaths.Add(args[i]);
                break;
        }

    if (inputPaths.Count == 0)
    {
        Console.Error.WriteLine(
            "project mode requires at least one .mbt, .mbtx, .ir.json, directory, or moon.mod/moon.mod.json input"
        );
        return 2;
    }

    foreach (var input in inputPaths)
    {
        if (moonModPath != "")
            continue;

        if (IsMoonModFile(input))
        {
            moonModPath = Path.GetFullPath(input);
            continue;
        }

        var discoveredMoonMod = MoonBitSourceTranspiler.FindMoonMod(input);
        if (discoveredMoonMod is not null)
            moonModPath = discoveredMoonMod;
    }

    RunMoonCheckForInputs(inputPaths, moonModPath);

    var result = MoonBitSourceTranspiler.WriteProject(
        new(outputDir, inputPaths.Select(Path.GetFullPath).ToList())
        {
            SingleFileName = singleFileName,
            ProjectName = projectName,
            WriteProjectFile = writeProjectFile,
            MoonModPath = moonModPath,
            RuntimeProjectPath = runtimeProjectPath,
            ReferenceRuntime = referenceRuntime,
            Executable = executable,
            IncludeMainPackages = includeMainPackages,
            UpperPascalCaseNames = upperPascalCaseNames,
            GeneratedNamespace = generatedNamespace,
            RuntimeNamespace = runtimeNamespace,
            AdditionalUsings = additionalUsings,
            AdditionalProjectReferences = additionalProjectReferences,
            CacheDirectory = cacheDirectory,
            CacheEnabled = cacheEnabled,
        }
    );

    foreach (var file in result.WrittenFiles)
        Console.WriteLine(file);

    return 0;
}

static string RequireValue(string[] args, ref int index, string option)
{
    if (index + 1 >= args.Length)
        throw new ArgumentException($"{option} requires a value");

    return args[++index];
}

static int RunDotnetProject(
    string projectPath,
    IReadOnlyList<string> appArgs,
    bool noBuild,
    bool release
)
{
    var arguments = new List<string> { "run", "--project", Path.GetFullPath(projectPath) };
    if (release)
    {
        arguments.Add("-c");
        arguments.Add("Release");
    }
    if (noBuild)
        arguments.Add("--no-build");
    arguments.Add("--");
    arguments.Add("moonbit2csharp-run");
    arguments.AddRange(appArgs);

    return RunDotnetCommand(projectPath, arguments);
}

static int BuildDotnetProject(string projectPath, bool release)
{
    var arguments = new List<string> { "build", Path.GetFullPath(projectPath) };
    if (release)
    {
        arguments.Add("-c");
        arguments.Add("Release");
    }

    return RunDotnetCommand(projectPath, arguments);
}

static bool DotnetBuildOutputExists(string projectPath, bool release)
{
    var fullProjectPath = Path.GetFullPath(projectPath);
    var projectDirectory = Path.GetDirectoryName(fullProjectPath);
    if (string.IsNullOrWhiteSpace(projectDirectory))
        return false;

    var projectName = Path.GetFileNameWithoutExtension(fullProjectPath);
    var configuration = release ? "Release" : "Debug";
    var configurationDirectory = Path.Combine(projectDirectory, "bin", configuration);
    if (!Directory.Exists(configurationDirectory))
        return false;

    return Directory
            .EnumerateFiles(
                configurationDirectory,
                projectName + ".exe",
                SearchOption.AllDirectories
            )
            .Any()
        || Directory
            .EnumerateFiles(
                configurationDirectory,
                projectName + ".dll",
                SearchOption.AllDirectories
            )
            .Any();
}

static int RunDotnetCommand(string projectPath, IReadOnlyList<string> arguments)
{
    var startInfo = new ProcessStartInfo("dotnet")
    {
        UseShellExecute = false,
        WorkingDirectory = Path.GetDirectoryName(Path.GetFullPath(projectPath))!,
    };
    foreach (var argument in arguments)
        startInfo.ArgumentList.Add(argument);

    using var process =
        Process.Start(startInfo) ?? throw new InvalidOperationException("failed to start dotnet");
    process.WaitForExit();
    return process.ExitCode;
}

static void RunMoonCheckForInputs(IReadOnlyList<string> inputPaths, string explicitMoonModPath)
{
    var moonProjectPath = ResolveMoonCheckPath(inputPaths, explicitMoonModPath);
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

static string FindMoonCommand()
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

static string? ResolveMoonCheckPath(IReadOnlyList<string> inputPaths, string explicitMoonModPath)
{
    if (!string.IsNullOrWhiteSpace(explicitMoonModPath))
    {
        var explicitPath = Path.GetFullPath(explicitMoonModPath);
        if (File.Exists(explicitPath))
            return Path.GetDirectoryName(explicitPath);
        if (Directory.Exists(explicitPath))
            return explicitPath;
        var explicitDirectory = Path.GetDirectoryName(explicitPath);
        if (!string.IsNullOrWhiteSpace(explicitDirectory))
            return explicitDirectory;
        return null;
    }

    foreach (var input in inputPaths)
    {
        if (IsMoonModFile(input))
            return Path.GetDirectoryName(Path.GetFullPath(input));

        var discoveredMoonMod = MoonBitSourceTranspiler.FindMoonMod(input);
        if (!string.IsNullOrWhiteSpace(discoveredMoonMod))
            return Path.GetDirectoryName(Path.GetFullPath(discoveredMoonMod!));
    }

    return null;
}

static bool IsMoonModFile(string input)
{
    return Path.GetFileName(input).Equals("moon.mod.json", StringComparison.OrdinalIgnoreCase)
        || Path.GetFileName(input).Equals("moon.mod", StringComparison.OrdinalIgnoreCase);
}

static int PrintUsage()
{
    Console.Error.WriteLine(
        "usage: MoonBit2CSharp.Cli [--pascal-case] <input.mbt|input.mbtx> [output.cs]"
    );
    Console.Error.WriteLine(
        "   or: MoonBit2CSharp.Cli build [--release] [input.mbt|directory|moon.mod|moon.mod.json]"
    );
    Console.Error.WriteLine(
        "   or: MoonBit2CSharp.Cli run [--release] [input.mbt|directory|moon.mod|moon.mod.json] [-- app args...]"
    );
    Console.Error.WriteLine(
        "   or: MoonBit2CSharp.Cli --project <output-dir> [--single-file <name.cs>] [--csproj <name>|--no-csproj] [--moon-mod <moon.mod|moon.mod.json>] [--exe] [--reference-runtime] [--runtime-project <path>] [--project-reference <path>] [--namespace <namespace>] [--runtime-namespace <namespace>] [--using <namespace>] [--cache-dir <dir>|--no-cache] [--include-main-packages] [--pascal-case] <inputs...>"
    );
    return 1;
}
