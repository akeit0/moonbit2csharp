using System.Text;
using System.Text.RegularExpressions;

namespace MoonBit2CSharp.Transpiler;

internal static class VNextRuntimeSupportRenderer
{
    private static readonly string[] KnownDeclarations =
    [
        "Unit",
        "Panic",
        "SourceLoc",
        "ArgsLoc",
        "Option",
        "Error",
        "Result",
        "Logger",
        "ILoggerImpl",
        "StringBuilderAsLogger",
        "ShowObject",
        "IShowImpl",
        "Show",
        "ShowImplObject",
        "ShowSupport",
        "ConsoleUtility",
        "CompareSupport",
        "OptionEq",
        "OptionEqImpl",
        "NullableOptionEqImpl",
        "IEqImpl",
        "Eq",
        "EqImplObject",
        "BuiltinEq",
        "Iter",
        "Array",
        "ArrayUtility",
        "IterArrayExtensions",
        "ArrayViewBounds",
        "ArrayView",
        "MutArrayView",
        "BytesView",
        "FixedArray",
        "StringBuilder",
        "StringExtensions",
        "StringView",
    ];

    private static readonly Dictionary<string, string[]> Dependencies = new(StringComparer.Ordinal)
    {
        ["ArgsLoc"] = ["Option", "SourceLoc"],
        ["Error"] = ["IShowImpl", "ShowImplObject", "Logger", "Unit"],
        ["Logger"] = ["ILoggerImpl", "StringView", "Unit"],
        ["StringBuilderAsLogger"] = ["ILoggerImpl", "StringBuilder", "StringView", "Unit"],
        ["ShowObject"] = ["IShowImpl"],
        ["IShowImpl"] = ["Unit", "Logger", "ShowSupport"],
        ["Show"] = ["IShowImpl", "Unit", "Logger"],
        ["ShowImplObject"] = ["IShowImpl", "Unit", "Logger"],
        ["ShowSupport"] = ["Unit", "Logger", "StringBuilder", "StringBuilderAsLogger", "IShowImpl"],
        ["ConsoleUtility"] = ["Unit", "IShowImpl"],
        ["OptionEq"] = ["Option", "Eq"],
        ["OptionEqImpl"] = ["Option", "OptionEq", "IEqImpl"],
        ["NullableOptionEqImpl"] = ["OptionEq", "IEqImpl"],
        ["Eq"] = ["IEqImpl"],
        ["EqImplObject"] = ["IEqImpl"],
        ["BuiltinEq"] = ["IEqImpl", "Eq"],
        ["Array"] = ["ArrayUtility", "ArrayView"],
        ["ArrayUtility"] = ["Array", "ArrayView", "Option", "Unit", "Panic"],
        ["ArrayView"] = ["Array", "ArrayViewBounds"],
        ["MutArrayView"] = ["Array", "ArrayView", "ArrayViewBounds"],
        ["BytesView"] = ["ArrayViewBounds"],
        ["FixedArray"] = ["Option", "Unit"],
        ["StringBuilder"] = ["Unit", "StringView", "Logger", "StringBuilderAsLogger"],
        ["StringExtensions"] = ["StringView", "Option"],
        ["StringView"] = ["Option"],
    };

    private static readonly Dictionary<string, string[]> IntrinsicDependencies = new(
        StringComparer.Ordinal
    )
    {
        ["ArrayRemove"] = ["Array", "Panic"],
        ["ArrayMake"] = ["Array"],
        ["ArrayLast"] = ["Array", "Option"],
        ["ArrayFilter"] = ["Array", "ArrayUtility"],
        ["ArraySortBy"] = ["Array", "Unit"],
        ["Ignore"] = ["Unit"],
        ["PrintlnString"] = ["Unit"],
        ["StringViewFind"] = ["StringView", "Option"],
        ["StringViewView"] = ["StringView", "Option"],
        ["StringGetChar"] = ["Option"],
        ["StringViewGetChar"] = ["StringView", "Option"],
        ["StringToArray"] = ["StringView", "Array"],
        ["StringContainsChar"] = ["StringView"],
        ["StringCharLength"] = ["StringView"],
        ["StringMake"] = [],
        ["StringViewTrim"] = ["StringView"],
        ["StringViewTrimStart"] = ["StringView"],
        ["StringViewTrimEnd"] = ["StringView"],
    };

    private static readonly Dictionary<string, string[]> IntrinsicMethodDependencies = new(
        StringComparer.Ordinal
    )
    {
        ["StringViewGetChar"] = ["StringGetChar"],
        ["StringViewTrim"] = ["StringViewTrimStart", "StringViewTrimEnd"],
    };

    public static string Render(
        string template,
        string runtimeNamespace,
        IEnumerable<string> generatedCode
    )
    {
        template = template.Replace(
            "__MOONBIT_RUNTIME_NAMESPACE__",
            runtimeNamespace,
            StringComparison.Ordinal
        );
        var required = RequiredRuntimeDeclarations(runtimeNamespace, generatedCode);
        var declarations = ExtractTopLevelDeclarations(template);
        var intrinsicMethods = ExtractIntrinsicMethods(template);

        var output = new StringBuilder();
        AppendHeader(template, output);
        foreach (var name in KnownDeclarations)
        {
            if (name == "IterArrayExtensions")
                continue;
            if (
                required.Declarations.Contains(name)
                && declarations.TryGetValue(name, out var sources)
            )
                foreach (var source in sources)
                    output.AppendLine(source.TrimEnd()).AppendLine();
        }

        if (required.Intrinsics.Count > 0)
        {
            output.AppendLine("public static partial class Intrinsics");
            output.AppendLine("{");
            foreach (var method in required.Intrinsics.Order(StringComparer.Ordinal))
            {
                if (intrinsicMethods.TryGetValue(method, out var source))
                    output.AppendLine(Indent(source.TrimEnd(), "    "));
            }
            output.AppendLine("}");
            output.AppendLine();
        }

        return output.ToString().TrimEnd() + Environment.NewLine;
    }

    private static RuntimeRequirements RequiredRuntimeDeclarations(
        string runtimeNamespace,
        IEnumerable<string> generatedCode
    )
    {
        var declarations = new HashSet<string>(StringComparer.Ordinal);
        var intrinsics = new HashSet<string>(StringComparer.Ordinal);
        var runtimePrefix = Regex.Escape(runtimeNamespace + ".");
        foreach (var code in generatedCode)
        {
            foreach (
                Match match in Regex.Matches(
                    code,
                    runtimePrefix + @"(?<name>[A-Za-z_][A-Za-z0-9_]*)"
                )
            )
            {
                var name = match.Groups["name"].Value;
                if (name == "Intrinsics")
                    continue;
                declarations.Add(name);
            }

            foreach (
                Match match in Regex.Matches(
                    code,
                    runtimePrefix + @"Intrinsics\.(?<name>[A-Za-z_][A-Za-z0-9_]*)"
                )
            )
                intrinsics.Add(match.Groups["name"].Value);

            if (code.Contains(".View(", StringComparison.Ordinal))
                declarations.Add("StringExtensions");
            if (Regex.IsMatch(code, @"\bIShowImpl\b"))
                declarations.Add("IShowImpl");
            if (Regex.IsMatch(code, @"\bIEqImpl\b"))
                declarations.Add("IEqImpl");
        }

        foreach (var method in intrinsics)
        {
            if (IntrinsicDependencies.TryGetValue(method, out var deps))
                foreach (var dep in deps)
                    declarations.Add(dep);
        }
        CloseIntrinsics(intrinsics, declarations);

        CloseDeclarations(declarations);
        return new(declarations, intrinsics);
    }

    private static void CloseIntrinsics(HashSet<string> intrinsics, HashSet<string> declarations)
    {
        var changed = true;
        while (changed)
        {
            changed = false;
            foreach (var method in intrinsics.ToArray())
            {
                if (IntrinsicMethodDependencies.TryGetValue(method, out var methodDeps))
                    foreach (var dep in methodDeps)
                        changed |= intrinsics.Add(dep);
                if (IntrinsicDependencies.TryGetValue(method, out var declarationDeps))
                    foreach (var dep in declarationDeps)
                        declarations.Add(dep);
            }
        }
    }

    private static void CloseDeclarations(HashSet<string> declarations)
    {
        var changed = true;
        while (changed)
        {
            changed = false;
            foreach (var declaration in declarations.ToArray())
            {
                if (!Dependencies.TryGetValue(declaration, out var deps))
                    continue;
                foreach (var dep in deps)
                    changed |= declarations.Add(dep);
            }
        }
    }

    private static Dictionary<string, List<string>> ExtractTopLevelDeclarations(string source)
    {
        var result = new Dictionary<string, List<string>>(StringComparer.Ordinal);
        foreach (
            Match match in Regex.Matches(
                source,
                @"(?m)^public\s+(?:(?:readonly|sealed|static|partial|class|interface|struct|record)\s+)*(?:record\s+struct\s+|class\s+|struct\s+|interface\s+)?(?<name>[A-Za-z_][A-Za-z0-9_]*)"
            )
        )
        {
            var name = match.Groups["name"].Value;
            if (name == "Intrinsics")
                continue;
            var end = DeclarationEnd(source, match.Index);
            if (end <= match.Index)
                continue;
            if (!result.TryGetValue(name, out var sources))
            {
                sources = [];
                result[name] = sources;
            }
            sources.Add(source[match.Index..end].TrimEnd());
        }

        return result;
    }

    private static Dictionary<string, string> ExtractIntrinsicMethods(string source)
    {
        var result = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var block in ExtractIntrinsicBlocks(source))
        {
            foreach (
                Match match in Regex.Matches(
                    block,
                    @"(?m)^\s{4}public\s+static\s+(?:[^\r\n(=]+?\s+)?(?<name>[A-Za-z_][A-Za-z0-9_]*)\s*(?:<[^>\r\n]+>)?\s*\("
                )
            )
            {
                var name = match.Groups["name"].Value;
                var end = MemberEnd(block, match.Index);
                if (end > match.Index)
                    result[name] = block[match.Index..end].Trim();
            }
        }

        return result;
    }

    private static IEnumerable<string> ExtractIntrinsicBlocks(string source)
    {
        foreach (
            Match match in Regex.Matches(
                source,
                @"(?m)^public\s+static\s+partial\s+class\s+Intrinsics\b"
            )
        )
        {
            var end = DeclarationEnd(source, match.Index);
            if (end > match.Index)
                yield return source[match.Index..end];
        }
    }

    private static int DeclarationEnd(string source, int start)
    {
        var semicolon = source.IndexOf(';', start);
        var open = source.IndexOf('{', start);
        if (semicolon >= 0 && (open < 0 || semicolon < open))
            return semicolon + 1;
        if (open < 0)
            return source.Length;
        return MatchingBraceEnd(source, open) + 1;
    }

    private static int MemberEnd(string source, int start)
    {
        var semicolon = source.IndexOf(';', start);
        var open = source.IndexOf('{', start);
        if (semicolon >= 0 && (open < 0 || semicolon < open))
            return semicolon + 1;
        if (open < 0)
            return source.Length;
        return MatchingBraceEnd(source, open) + 1;
    }

    private static int MatchingBraceEnd(string source, int open)
    {
        var depth = 0;
        var inString = false;
        var inChar = false;
        var escaped = false;
        for (var i = open; i < source.Length; i++)
        {
            var ch = source[i];
            if (inString || inChar)
            {
                if (escaped)
                    escaped = false;
                else if (ch == '\\')
                    escaped = true;
                else if (inString && ch == '"')
                    inString = false;
                else if (inChar && ch == '\'')
                    inChar = false;
                continue;
            }

            if (ch == '"')
            {
                inString = true;
                continue;
            }
            if (ch == '\'')
            {
                inChar = true;
                continue;
            }
            if (ch == '{')
                depth++;
            else if (ch == '}')
            {
                depth--;
                if (depth == 0)
                    return i;
            }
        }

        return source.Length - 1;
    }

    private static void AppendHeader(string template, StringBuilder output)
    {
        var namespaceIndex = template.IndexOf("namespace ", StringComparison.Ordinal);
        var namespaceEnd = template.IndexOf(';', namespaceIndex);
        output.Append(template[..(namespaceEnd + 1)].TrimEnd()).AppendLine().AppendLine();
    }

    private static string Indent(string source, string indent)
    {
        using var reader = new StringReader(source);
        var builder = new StringBuilder();
        string? line;
        while ((line = reader.ReadLine()) is not null)
            builder.Append(indent).AppendLine(line);
        return builder.ToString().TrimEnd();
    }

    private sealed record RuntimeRequirements(
        HashSet<string> Declarations,
        HashSet<string> Intrinsics
    );
}
