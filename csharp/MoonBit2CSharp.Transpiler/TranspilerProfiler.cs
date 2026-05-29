using System.Diagnostics;

namespace MoonBit2CSharp.Transpiler;

internal static class TranspilerProfiler
{
    public static bool Enabled =>
        Environment.GetEnvironmentVariable("MOONBIT2CSHARP_PROFILE") is "1" or "true" or "TRUE";

    public static IDisposable Measure(string name)
    {
        return Enabled ? new Scope(name) : NullScope.Instance;
    }

    public static void Log(string message)
    {
        if (Enabled)
            Console.Error.WriteLine("profile: " + message);
    }

    private sealed class Scope(string name) : IDisposable
    {
        private readonly Stopwatch stopwatch = Stopwatch.StartNew();

        public void Dispose()
        {
            Console.Error.WriteLine($"profile: {name}: {stopwatch.Elapsed.TotalSeconds:n3}s");
        }
    }

    private sealed class NullScope : IDisposable
    {
        public static readonly NullScope Instance = new();

        public void Dispose() { }
    }
}
