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
        var name = MoonModManifest.FieldValue(moonModPath, "name");
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

public static class MoonModManifest
{
    public static string? FieldValue(string moonModPath, string fieldName)
    {
        if (Path.GetExtension(moonModPath).Equals(".json", StringComparison.OrdinalIgnoreCase))
        {
            using var doc = JsonDocument.Parse(File.ReadAllText(moonModPath));
            return
                doc.RootElement.TryGetProperty(fieldName, out var element)
                && element.ValueKind == JsonValueKind.String
                ? element.GetString()
                : null;
        }

        return new Parser(File.ReadAllText(moonModPath)).FieldValue(fieldName);
    }

    private sealed class Parser(string text)
    {
        private int position;

        public string? FieldValue(string fieldName)
        {
            while (true)
            {
                SkipTrivia();
                if (AtEnd)
                    return null;

                if (!TryReadIdentifier(out var name))
                {
                    position++;
                    continue;
                }

                SkipTrivia();
                if (TryReadChar('='))
                {
                    SkipTrivia();
                    if (name == fieldName && TryReadString(out var value))
                        return value;

                    SkipExpr();
                    continue;
                }

                if (TryReadChar('('))
                {
                    if (name == "options")
                    {
                        if (TryReadApplyStringArgument(fieldName, out var value))
                            return value;
                        continue;
                    }

                    SkipBalancedBody('(', ')');
                }
            }
        }

        private bool TryReadApplyStringArgument(string fieldName, out string? value)
        {
            value = null;
            while (true)
            {
                SkipTrivia();
                if (AtEnd || TryReadChar(')'))
                    return false;

                var argumentStart = position;
                string? key = null;
                if (!TryReadIdentifier(out key))
                    TryReadString(out key);

                SkipTrivia();
                if (key is null || !TryReadChar(':'))
                {
                    position = argumentStart;
                    SkipExpr();
                    TryReadChar(',');
                    continue;
                }

                SkipTrivia();
                if (key == fieldName && TryReadString(out value))
                    return true;

                SkipExpr();
                TryReadChar(',');
            }
        }

        private void SkipExpr()
        {
            SkipTrivia();
            if (AtEnd)
                return;

            if (TryReadString(out _))
                return;

            if (TryReadChar('['))
            {
                SkipBalancedBody('[', ']');
                return;
            }

            if (TryReadChar('{'))
            {
                SkipBalancedBody('{', '}');
                return;
            }

            if (TryReadIdentifier(out _))
            {
                SkipTrivia();
                if (TryReadChar('('))
                    SkipBalancedBody('(', ')');
                return;
            }

            while (
                !AtEnd && !char.IsWhiteSpace(Current) && Current is not ',' and not ')' and not ']'
            )
                position++;
        }

        private void SkipBalancedBody(char open, char close)
        {
            var depth = 1;
            while (!AtEnd && depth > 0)
            {
                if (TryReadString(out _))
                    continue;

                var ch = Current;
                position++;
                if (ch == open)
                    depth++;
                else if (ch == close)
                    depth--;
            }
        }

        private bool TryReadIdentifier(out string? value)
        {
            value = null;
            if (AtEnd || !(char.IsLetter(Current) || Current == '_'))
                return false;

            var start = position++;
            while (!AtEnd && (char.IsLetterOrDigit(Current) || Current == '_' || Current == '-'))
                position++;

            value = text[start..position];
            return true;
        }

        private bool TryReadString(out string? value)
        {
            value = null;
            if (!TryReadChar('"'))
                return false;

            var builder = new StringBuilder();
            while (!AtEnd)
            {
                var ch = Current;
                position++;
                if (ch == '"')
                {
                    value = builder.ToString();
                    return true;
                }

                if (ch == '\\' && !AtEnd)
                {
                    var escaped = Current;
                    position++;
                    builder.Append(
                        escaped switch
                        {
                            '"' => '"',
                            '\\' => '\\',
                            'n' => '\n',
                            'r' => '\r',
                            't' => '\t',
                            _ => escaped,
                        }
                    );
                    continue;
                }

                builder.Append(ch);
            }

            value = builder.ToString();
            return true;
        }

        private bool TryReadChar(char ch)
        {
            if (AtEnd || Current != ch)
                return false;

            position++;
            return true;
        }

        private void SkipTrivia()
        {
            while (!AtEnd)
            {
                if (char.IsWhiteSpace(Current))
                {
                    position++;
                    continue;
                }

                if (Current == '/' && position + 1 < text.Length && text[position + 1] == '/')
                {
                    position += 2;
                    while (!AtEnd && Current is not '\r' and not '\n')
                        position++;
                    continue;
                }

                break;
            }
        }

        private bool AtEnd => position >= text.Length;
        private char Current => text[position];
    }
}
