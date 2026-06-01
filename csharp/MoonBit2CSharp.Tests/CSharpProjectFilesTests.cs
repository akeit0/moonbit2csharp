using MoonBit2CSharp.Backend;
using Xunit;

namespace MoonBit2CSharp.Tests;

public sealed class CSharpProjectFilesTests
{
    [Fact]
    public void BuildProjectFileEmitsExplicitExeOutputType()
    {
        var project = CSharpProjectFiles.BuildProjectFile(
            outputDir: ".",
            runtimeProjectPath: "MoonBit.Runtime.csproj",
            referenceRuntime: false,
            executable: true
        );

        Assert.Contains("<OutputType>Exe</OutputType>", project, StringComparison.Ordinal);
        Assert.DoesNotContain("<OutputType>Library</OutputType>", project, StringComparison.Ordinal);
    }

    [Fact]
    public void BuildProjectFileEmitsExplicitLibraryOutputType()
    {
        var project = CSharpProjectFiles.BuildProjectFile(
            outputDir: ".",
            runtimeProjectPath: "MoonBit.Runtime.csproj",
            referenceRuntime: false,
            executable: false
        );

        Assert.Contains("<OutputType>Library</OutputType>", project, StringComparison.Ordinal);
        Assert.DoesNotContain("<OutputType>Exe</OutputType>", project, StringComparison.Ordinal);
    }
}
