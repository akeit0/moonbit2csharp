namespace MoonBit2CSharp.Backend;

public static class CSharpBackend
{
    public static string EmitRuntime(CSharpEmitterOptions? options = null)
    {
        options ??= new();
        return CSharpRuntimeSource.Emit(
            options.RuntimeNamespace,
            options.NewLine,
            options.FinalNewLine
        );
    }
}
