using System.Text.Json;

namespace MoonBit2CSharp.Transpiler;

internal enum VNextCoreSourceStage
{
    Declaration,
    Implementation,
}

internal sealed record VNextCoreOverrideManifest(
    IReadOnlyDictionary<VNextCoreSourceStage, IReadOnlyList<string>> Seeds,
    IReadOnlySet<string> BackendRequiredPackages,
    IReadOnlyList<VNextCorePackageRule> Packages
);

internal sealed record VNextCorePackageRule(
    VNextCoreSourceStage Stage,
    string ModulePath,
    string Alias,
    bool Official,
    IReadOnlySet<string> Exclude,
    IReadOnlyList<string> Add,
    IReadOnlyList<string> ReplaceAll
);

internal static class VNextCoreOverrideManifestLoader
{
    private const string ManifestResourceName =
        "MoonBit2CSharp.Transpiler.CoreOverrideManifest.json";

    private static readonly Lazy<VNextCoreOverrideManifest> Cached = new(LoadCore);

    public static VNextCoreOverrideManifest Load()
    {
        return Cached.Value;
    }

    private static VNextCoreOverrideManifest LoadCore()
    {
        using var stream =
            typeof(VNextCoreOverrideManifestLoader).Assembly.GetManifestResourceStream(
                ManifestResourceName
            )
            ?? throw new InvalidOperationException(
                $"Embedded vnext core override manifest not found: {ManifestResourceName}"
            );
        using var document = JsonDocument.Parse(stream);
        var root = document.RootElement;
        var version = root.GetProperty("version").GetString();
        if (version != "moonbit2csharp-vnext-core-overrides-v1")
            throw new InvalidOperationException(
                $"Unsupported vnext core override manifest: {version}"
            );

        var seeds = ReadSeeds(root.GetProperty("seeds"));
        var backendRequiredPackages = root.TryGetProperty(
            "backendRequiredPackages",
            out var backendRequiredPackagesElement
        )
            ? ReadStringArray(backendRequiredPackagesElement).ToHashSet(StringComparer.Ordinal)
            : new HashSet<string>(StringComparer.Ordinal);
        var packages = new List<VNextCorePackageRule>();
        foreach (var package in root.GetProperty("packages").EnumerateArray())
        {
            var stage = ParseEnum<VNextCoreSourceStage>(package, "stage");
            var modulePath = RequiredString(package, "modulePath");
            var alias = RequiredString(package, "alias");
            var official =
                package.TryGetProperty("official", out var officialElement)
                && officialElement.ValueKind == JsonValueKind.True;
            var exclude = package.TryGetProperty("exclude", out var excludeElement)
                ? ReadStringArray(excludeElement).ToHashSet(StringComparer.OrdinalIgnoreCase)
                : new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var add = package.TryGetProperty("add", out var addElement)
                ? ReadStringArray(addElement)
                : [];
            var replaceAll = package.TryGetProperty("replaceAll", out var replaceAllElement)
                ? ReadStringArray(replaceAllElement)
                : [];

            if (!official && replaceAll.Count == 0)
                throw new InvalidOperationException(
                    $"Core override package rule has neither official source nor replaceAll: {modulePath}/{stage}"
                );
            if (official && replaceAll.Count != 0)
                throw new InvalidOperationException(
                    $"Core override package rule cannot combine official and replaceAll: {modulePath}/{stage}"
                );

            packages.Add(new(stage, modulePath, alias, official, exclude, add, replaceAll));
        }

        if (packages.Count == 0)
            throw new InvalidOperationException(
                "Vnext core override manifest has no package rules."
            );

        return new VNextCoreOverrideManifest(seeds, backendRequiredPackages, packages);
    }

    private static IReadOnlyDictionary<VNextCoreSourceStage, IReadOnlyList<string>> ReadSeeds(
        JsonElement seeds
    )
    {
        var result = new Dictionary<VNextCoreSourceStage, IReadOnlyList<string>>();
        foreach (var stage in Enum.GetValues<VNextCoreSourceStage>())
        {
            result[stage] = seeds.TryGetProperty(stage.ToString(), out var stageSeeds)
                ? ReadStringArray(stageSeeds)
                : [];
        }

        return result;
    }

    private static T ParseEnum<T>(JsonElement node, string propertyName)
        where T : struct
    {
        var value = RequiredString(node, propertyName);
        if (Enum.TryParse<T>(value, ignoreCase: false, out var result))
            return result;
        throw new InvalidOperationException(
            $"Invalid vnext core override manifest {propertyName}: {value}"
        );
    }

    private static IReadOnlyList<string> ReadStringArray(JsonElement array)
    {
        if (array.ValueKind != JsonValueKind.Array)
            throw new InvalidOperationException(
                "Expected JSON array in vnext core override manifest."
            );
        return array.EnumerateArray().Select(item =>
        {
            if (item.ValueKind != JsonValueKind.String)
                throw new InvalidOperationException(
                    "Expected JSON string entry in vnext core override manifest array."
                );

            var value = item.GetString();
            if (string.IsNullOrWhiteSpace(value))
                throw new InvalidOperationException(
                    "Expected non-empty JSON string entry in vnext core override manifest array."
                );

            return value;
        }).ToArray();
    }

    private static string RequiredString(JsonElement node, string propertyName)
    {
        var value = node.GetProperty(propertyName).GetString();
        if (!string.IsNullOrWhiteSpace(value))
            return value;
        throw new InvalidOperationException(
            $"Missing vnext core override manifest property: {propertyName}"
        );
    }
}
