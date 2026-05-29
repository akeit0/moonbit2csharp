namespace MoonBit2CSharp.Backend;

public sealed record CSharpEmitterOptions(
    bool UpperPascalCaseNames = false,
    string GeneratedNamespace = "Generated.MoonBit",
    string RuntimeNamespace = "MoonBit2CSharp.Runtime",
    int IndentSize = 4,
    string NewLine = "\n",
    bool FinalNewLine = true,
    IReadOnlyList<string>? AdditionalUsings = null,
    IReadOnlySet<string>? ImplementedCoreBuiltins = null,
    IReadOnlySet<string>? ExternalCoreTypes = null,
    IReadOnlySet<string>? ExternalCoreErrorTypes = null,
    IReadOnlyDictionary<string, string>? ExternalCoreTypeNames = null,
    IReadOnlyDictionary<string, string>? ExternalCoreTypeMappings = null,
    IReadOnlyDictionary<string, string>? ExternalCoreFunctions = null,
    IReadOnlyDictionary<string, string>? ExternalCoreFunctionMethods = null,
    IReadOnlySet<string>? RuntimeFeatures = null
);
