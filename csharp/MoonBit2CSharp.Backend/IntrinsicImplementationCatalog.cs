using System.Text.Json;
using System.Text.Json.Serialization;

namespace MoonBit2CSharp.Backend;

public sealed record IntrinsicImplementationMetadata(
    string ExternalName,
    string Mode,
    IReadOnlyList<string> RuntimeFeatures,
    string SemanticTestFamily
);

public static class IntrinsicImplementationCatalog
{
    private static readonly Lazy<IntrinsicImplementationCatalogData> Data = new(Load);

    public static string Version => Data.Value.Version;

    internal static IReadOnlyList<IntrinsicBindingSpec> BindingSpecs => Data.Value.Bindings;

    public static IReadOnlySet<string> GeneratedAdapterExternalNames { get; } =
        Data
            .Value.Bindings.Where(binding =>
                BindingMode(binding.ExternalName) == "GeneratedAdapter"
            )
            .Select(binding => binding.ExternalName)
            .ToHashSet(StringComparer.Ordinal);

    public static IReadOnlySet<string> FrameworkCallExternalNames { get; } =
        Data
            .Value.Bindings.Where(binding => BindingMode(binding.ExternalName) == "FrameworkCall")
            .Select(binding => binding.ExternalName)
            .ToHashSet(StringComparer.Ordinal);

    public static IntrinsicImplementationMetadata MetadataFor(string externalName)
    {
        var rule = FindRule(Data.Value.Rules, externalName);
        if (rule is null)
            throw new InvalidOperationException(
                $"intrinsic implementation metadata missing for {externalName}"
            );

        return new(externalName, rule.Mode, rule.RuntimeFeatures, rule.SemanticTestFamily);
    }

    public static IReadOnlyList<IntrinsicImplementationMetadata> MetadataForSupportedIntrinsics()
    {
        return IntrinsicBindings
            .SupportedExternalNames.Select(MetadataFor)
            .OrderBy(metadata => metadata.ExternalName, StringComparer.Ordinal)
            .ToArray();
    }

    private static IntrinsicImplementationCatalogData Load()
    {
        var assembly = typeof(IntrinsicImplementationCatalog).Assembly;
        var resourceName =
            assembly
                .GetManifestResourceNames()
                .SingleOrDefault(name =>
                    name.EndsWith("IntrinsicImplementationCatalog.json", StringComparison.Ordinal)
                )
            ?? throw new InvalidOperationException(
                "embedded intrinsic implementation catalog is missing"
            );
        using var stream =
            assembly.GetManifestResourceStream(resourceName)
            ?? throw new InvalidOperationException(
                $"embedded intrinsic implementation catalog cannot be opened: {resourceName}"
            );
        var data =
            JsonSerializer.Deserialize(
                stream,
                IntrinsicJsonContext.Default.IntrinsicImplementationCatalogData
            ) ?? throw new InvalidOperationException("intrinsic implementation catalog is empty");
        if (data.Rules.Count == 0)
            throw new InvalidOperationException("intrinsic implementation catalog has no rules");

        var duplicateBinding = data
            .Bindings.GroupBy(binding => binding.ExternalName, StringComparer.Ordinal)
            .FirstOrDefault(group => group.Count() > 1);
        if (duplicateBinding is not null)
            throw new InvalidOperationException(
                $"intrinsic implementation catalog has duplicate declarative binding: {duplicateBinding.Key}"
            );

        foreach (var binding in data.Bindings)
        {
            var rule =
                FindRule(data.Rules, binding.ExternalName)
                ?? throw new InvalidOperationException(
                    $"intrinsic implementation metadata missing for declarative binding {binding.ExternalName}"
                );
            if (rule.Mode is not ("GeneratedAdapter" or "FrameworkCall"))
                throw new InvalidOperationException(
                    $"intrinsic declarative binding {binding.ExternalName} is declared with non-declarative mode {rule.Mode}"
                );
        }

        return data;
    }

    private static IntrinsicImplementationRule? FindRule(
        IReadOnlyList<IntrinsicImplementationRule> rules,
        string externalName
    )
    {
        return rules
            .Where(rule => rule.Matches(externalName))
            .OrderByDescending(rule => rule.Match?.Length ?? rule.MatchPrefix?.Length ?? 0)
            .FirstOrDefault();
    }

    private static string BindingMode(string externalName)
    {
        return MetadataFor(externalName).Mode;
    }
}

internal sealed record IntrinsicImplementationCatalogData(
    string Version,
    IReadOnlyList<IntrinsicBindingSpec> Bindings,
    IReadOnlyList<IntrinsicImplementationRule> Rules
);

internal sealed record IntrinsicBindingSpec(
    string ExternalName,
    IReadOnlyList<string> ParameterTypes,
    IntrinsicExpressionSpec? Expression,
    IntrinsicMethodSpec? Method,
    IntrinsicFunctionValueSpec? FunctionValue
);

internal sealed record IntrinsicExpressionSpec(
    string Kind,
    int? ArgumentIndex,
    string? Operator,
    string? Template
);

internal sealed record IntrinsicFunctionValueSpec(
    string MethodName,
    string ReturnType,
    string Signature,
    string Body
);

internal sealed record IntrinsicMethodSpec(
    string MethodName,
    string ReturnType,
    string Signature,
    string Body
);

internal sealed record IntrinsicImplementationRule(
    string? Match,
    string? MatchPrefix,
    string Mode,
    IReadOnlyList<string> RuntimeFeatures,
    string SemanticTestFamily
)
{
    public bool Matches(string externalName)
    {
        return string.Equals(Match, externalName, StringComparison.Ordinal)
            || (
                MatchPrefix is not null
                && externalName.StartsWith(MatchPrefix, StringComparison.Ordinal)
            );
    }
}

[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase)]
[JsonSerializable(typeof(IntrinsicImplementationCatalogData))]
internal sealed partial class IntrinsicJsonContext : JsonSerializerContext;
