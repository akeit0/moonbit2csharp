using System.Text.Json;
using System.Text.Json.Serialization;
using ImportRef = moonbit2csharp.frontend.vnext.binding.ImportRef;
using PackageSource = moonbit2csharp.frontend.vnext.package.PackageSource;
using Pipeline = moonbit2csharp.frontend.vnext.pipeline._;
using SourceUnit = moonbit2csharp.frontend.vnext.package.SourceUnit;

if (args.Length != 1)
{
    Console.Error.WriteLine("usage: MoonBit2CSharp.VNextFrontendRunner <request.json>");
    return 2;
}

var request =
    JsonSerializer.Deserialize(
        File.ReadAllText(args[0]),
        VNextFrontendJsonContext.Default.VNextFrontendRequest
    ) ?? throw new InvalidOperationException("missing vnext frontend request");

var result = Pipeline.compile_package_sources_with_manifests_to_json(
    new MoonBit.Runtime.Array<SourceUnit>(
        request.Sources.Select(item => new SourceUnit(item.FilePath, item.Source)).ToArray()
    ),
    request.ModuleName,
    request.MoonPkgSource,
    request.MoonPkgPath,
    new MoonBit.Runtime.Array<PackageSource>(
        request.ImportedSources.Select(ToPackageSource).ToArray()
    ),
    new MoonBit.Runtime.Array<PackageSource>(
        request.ImportedDeclarationSources.Select(ToPackageSource).ToArray()
    ),
    new MoonBit.Runtime.Array<SourceUnit>(
        request
            .ImportedManifestSources.Select(item => new SourceUnit(item.FilePath, item.Source))
            .ToArray()
    )
);
Console.Write(result);
return 0;

static PackageSource ToPackageSource(VNextPackageSource source) =>
    new(
        new ImportRef(
            source.ImportRef.AliasName,
            source.ImportRef.PackageId,
            source.ImportRef.ModulePath
        ),
        source.FilePath,
        source.Source
    );

sealed record VNextFrontendRequest(
    IReadOnlyList<VNextSourceUnit> Sources,
    string ModuleName,
    string MoonPkgSource,
    string MoonPkgPath,
    IReadOnlyList<VNextPackageSource> ImportedSources,
    IReadOnlyList<VNextPackageSource> ImportedDeclarationSources,
    IReadOnlyList<VNextSourceUnit> ImportedManifestSources
);

sealed record VNextSourceUnit(string FilePath, string Source);

sealed record VNextPackageSource(VNextImportRef ImportRef, string FilePath, string Source);

sealed record VNextImportRef(string AliasName, string PackageId, string ModulePath);

[JsonSerializable(typeof(VNextFrontendRequest))]
[JsonSourceGenerationOptions(PropertyNamingPolicy = JsonKnownNamingPolicy.Unspecified)]
partial class VNextFrontendJsonContext : JsonSerializerContext;
