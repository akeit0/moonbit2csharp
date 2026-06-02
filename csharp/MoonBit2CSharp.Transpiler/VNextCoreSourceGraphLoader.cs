using System.Reflection;
using System.Text.Json;

namespace MoonBit2CSharp.Transpiler;

internal enum VNextCoreSourceStage
{
    Declaration,
    Implementation,
}

internal enum VNextCoreSourceNodeKind
{
    File,
    OfficialPackage,
}

internal sealed record VNextCoreSourceNode(
    VNextCoreSourceStage Stage,
    VNextCoreSourceNodeKind Kind,
    string Alias,
    string ModulePath,
    string RelativePath
);

internal static class VNextCoreSourceGraphLoader
{
    private const string ManifestResourceName =
        "MoonBit2CSharp.Transpiler.CoreSourceGraph.json";

    private static readonly Lazy<IReadOnlyList<VNextCoreSourceNode>> Cached = new(LoadCore);

    public static IReadOnlyList<VNextCoreSourceNode> Load()
    {
        return Cached.Value;
    }

    private static IReadOnlyList<VNextCoreSourceNode> LoadCore()
    {
        using var stream =
            typeof(VNextCoreSourceGraphLoader).Assembly.GetManifestResourceStream(
                ManifestResourceName
            )
            ?? throw new InvalidOperationException(
                $"Embedded vnext core source graph not found: {ManifestResourceName}"
            );
        using var document = JsonDocument.Parse(stream);
        var root = document.RootElement;
        var version = root.GetProperty("version").GetString();
        if (version != "moonbit2csharp-vnext-core-source-graph-v1")
            throw new InvalidOperationException($"Unsupported vnext core source graph: {version}");

        var result = new List<VNextCoreSourceNode>();
        foreach (var node in root.GetProperty("nodes").EnumerateArray())
        {
            var stage = ParseEnum<VNextCoreSourceStage>(node, "stage");
            var kind = ParseEnum<VNextCoreSourceNodeKind>(node, "kind");
            var alias = RequiredString(node, "alias");
            var modulePath = RequiredString(node, "modulePath");
            var relativePath = RequiredString(node, "relativePath");
            result.Add(new(stage, kind, alias, modulePath, relativePath));
        }

        if (result.Count == 0)
            throw new InvalidOperationException("Vnext core source graph is empty.");

        return result;
    }

    private static T ParseEnum<T>(JsonElement node, string propertyName)
        where T : struct
    {
        var value = RequiredString(node, propertyName);
        if (Enum.TryParse<T>(value, ignoreCase: false, out var result))
            return result;
        throw new InvalidOperationException(
            $"Invalid vnext core source graph {propertyName}: {value}"
        );
    }

    private static string RequiredString(JsonElement node, string propertyName)
    {
        var value = node.GetProperty(propertyName).GetString();
        if (!string.IsNullOrWhiteSpace(value))
            return value;
        throw new InvalidOperationException(
            $"Missing vnext core source graph property: {propertyName}"
        );
    }
}
