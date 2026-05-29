using System.Text;
using System.Text.Json;

namespace MoonBit2CSharp.Backend;

public static class CSharpProjectFiles
{
    public static string BuildProjectFile(
        string outputDir,
        string runtimeProjectPath,
        bool referenceRuntime,
        bool executable,
        IReadOnlyList<string>? additionalProjectReferences = null,
        string compileInclude = "*.cs",
        CSharpEmitterOptions? formattingOptions = null
    )
    {
        var options = formattingOptions ?? new CSharpEmitterOptions();
        var newLine = options.NewLine is "\r\n" or "\n" ? options.NewLine : "\n";
        var indent = new string(' ', Math.Max(0, options.IndentSize));
        var indent2 = indent + indent;
        var projectReferences = new List<string>();
        if (referenceRuntime)
            projectReferences.Add(runtimeProjectPath);

        if (additionalProjectReferences is not null)
            projectReferences.AddRange(additionalProjectReferences);

        var builder = new StringBuilder();
        builder.Append("<Project Sdk=\"Microsoft.NET.Sdk\">").Append(newLine);
        builder.Append(indent).Append("<PropertyGroup>").Append(newLine);
        if (executable)
            builder.Append(indent2).Append("<OutputType>Exe</OutputType>").Append(newLine);

        builder
            .Append(indent2)
            .Append("<TargetFramework>net10.0</TargetFramework>")
            .Append(newLine);
        builder.Append(indent2).Append("<ImplicitUsings>enable</ImplicitUsings>").Append(newLine);
        builder.Append(indent2).Append("<Nullable>enable</Nullable>").Append(newLine);
        builder.Append(indent2).Append("<LangVersion>preview</LangVersion>").Append(newLine);
        builder
            .Append(indent2)
            .Append("<NoWarn>$(NoWarn);CS8981;CS8509;CS8846</NoWarn>")
            .Append(newLine);
        builder
            .Append(indent2)
            .Append("<EnableDefaultCompileItems>false</EnableDefaultCompileItems>")
            .Append(newLine);
        builder.Append(indent).Append("</PropertyGroup>").Append(newLine);
        if (projectReferences.Count > 0)
        {
            builder.Append(indent).Append("<ItemGroup>").Append(newLine);
            foreach (var path in projectReferences)
                builder
                    .Append(indent2)
                    .Append("<ProjectReference Include=\"")
                    .Append(
                        Path.GetRelativePath(Path.GetFullPath(outputDir), Path.GetFullPath(path))
                            .Replace('\\', '/')
                    )
                    .Append("\" />")
                    .Append(newLine);

            builder.Append(indent).Append("</ItemGroup>").Append(newLine);
        }

        builder.Append(indent).Append("<ItemGroup>").Append(newLine);
        builder
            .Append(indent2)
            .Append("<Compile Include=\"")
            .Append(compileInclude)
            .Append("\" />")
            .Append(newLine);
        builder.Append(indent).Append("</ItemGroup>").Append(newLine);
        builder.Append("</Project>");
        return options.FinalNewLine ? builder.Append(newLine).ToString() : builder.ToString();
    }

    public static string ProjectNameFromMoonMod(string moonModPath)
    {
        using var doc = JsonDocument.Parse(File.ReadAllText(moonModPath));
        var name =
            doc.RootElement.TryGetProperty("name", out var nameElement)
            && nameElement.ValueKind == JsonValueKind.String
                ? nameElement.GetString()
                : null;
        var leaf = string.IsNullOrWhiteSpace(name)
            ? Path.GetFileName(Path.GetDirectoryName(moonModPath))
            : name.Split('/', '\\').LastOrDefault();
        var safeName = SanitizeProjectName(
            string.IsNullOrWhiteSpace(leaf) ? "MoonBitProject" : leaf!
        );
        return safeName == "" ? "MoonBitProject" : safeName;
    }

    private static string SanitizeProjectName(string name)
    {
        var chars = name.Select(ch =>
                char.IsLetterOrDigit(ch) || ch is '_' or '-' or '.' ? ch : '_'
            )
            .ToArray();
        return new string(chars).Trim('.', '_', '-');
    }
}
