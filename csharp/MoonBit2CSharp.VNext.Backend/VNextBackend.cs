namespace MoonBit2CSharp.VNext.Backend;

public static class VNextBackend
{
    public static string Emit(string irJson, VNextEmitterOptions? options = null)
    {
        return new VNextSemanticEmitter(options ?? new VNextEmitterOptions()).Emit(irJson);
    }

    public static IReadOnlyList<VNextGeneratedFile> EmitFiles(
        string irJson,
        VNextEmitterOptions? options = null
    )
    {
        return new VNextSemanticEmitter(options ?? new VNextEmitterOptions()).EmitFiles(irJson);
    }
}

public sealed record VNextGeneratedFile(string RelativePath, string Code);
