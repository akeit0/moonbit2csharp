using System.Text.Json;

namespace MoonBit2CSharp.Backend;

public sealed record ExternalCoreManifest(
    string GeneratedNamespace,
    bool UpperPascalCaseNames,
    IReadOnlyList<string> Types,
    IReadOnlyList<string> ErrorTypes,
    IReadOnlyDictionary<string, string> TypeNames,
    IReadOnlyDictionary<string, string> TypeMappings,
    IReadOnlyDictionary<string, string> Functions,
    IReadOnlyDictionary<string, string> FunctionMethods
)
{
    public static ExternalCoreManifest Empty { get; } =
        new(
            "",
            false,
            [],
            [],
            new Dictionary<string, string>(StringComparer.Ordinal),
            new Dictionary<string, string>(StringComparer.Ordinal),
            new Dictionary<string, string>(StringComparer.Ordinal),
            new Dictionary<string, string>(StringComparer.Ordinal)
        );

    public static ExternalCoreManifest Read(string path)
    {
        var manifest =
            JsonSerializer.Deserialize<ExternalCoreManifest>(File.ReadAllText(path), JsonOptions())
            ?? throw new InvalidOperationException($"external core manifest is empty: {path}");
        return new(
            manifest.GeneratedNamespace,
            manifest.UpperPascalCaseNames,
            manifest.Types.OrderBy(type => type, StringComparer.Ordinal).ToArray(),
            (manifest.ErrorTypes ?? []).OrderBy(type => type, StringComparer.Ordinal).ToArray(),
            (manifest.TypeNames ?? new Dictionary<string, string>(StringComparer.Ordinal))
                .OrderBy(pair => pair.Key, StringComparer.Ordinal)
                .ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.Ordinal),
            (manifest.TypeMappings ?? new Dictionary<string, string>(StringComparer.Ordinal))
                .OrderBy(pair => pair.Key, StringComparer.Ordinal)
                .ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.Ordinal),
            manifest
                .Functions.OrderBy(pair => pair.Key, StringComparer.Ordinal)
                .ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.Ordinal),
            (manifest.FunctionMethods ?? new Dictionary<string, string>(StringComparer.Ordinal))
                .OrderBy(pair => pair.Key, StringComparer.Ordinal)
                .ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.Ordinal)
        );
    }

    public static string Write(ExternalCoreManifest manifest)
    {
        return JsonSerializer.Serialize(manifest, JsonOptions()) + Environment.NewLine;
    }

    private static JsonSerializerOptions JsonOptions()
    {
        return new() { WriteIndented = true, PropertyNamingPolicy = JsonNamingPolicy.CamelCase };
    }
}
