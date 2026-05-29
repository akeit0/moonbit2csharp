namespace MoonBit2CSharp.VNext.Backend;

public sealed record VNextEmitterOptions(
    string GeneratedNamespace = "Generated.MoonBit",
    string RuntimeNamespace = "MoonBit.Runtime",
    bool UpperPascalCaseNames = false,
    bool EmitEntryPoint = false,
    int IndentSize = 4,
    string NewLine = "\n",
    bool FinalNewLine = true
);
