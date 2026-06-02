using System.Text.RegularExpressions;

namespace MoonBit2CSharp.Transpiler;

internal sealed class VNextCoreSourceSelector
{
    private readonly string repositoryRoot;
    private readonly VNextCoreOverrideManifest manifest;

    public VNextCoreSourceSelector(string repositoryRoot, VNextCoreOverrideManifest manifest)
    {
        this.repositoryRoot = repositoryRoot;
        this.manifest = manifest;
    }

    public IReadOnlyList<VNextDeclarationSource> Select(VNextCoreSourceStage stage)
    {
        var selectedPackages = SelectPackages(stage);
        var result = new List<VNextDeclarationSource>();
        foreach (var rule in OrderedPackageRules(stage, selectedPackages))
        {
            if (rule.ReplaceAll.Count > 0)
            {
                foreach (var relativePath in rule.ReplaceAll)
                    AddSource(result, rule, RepositoryPath(relativePath));
            }
            else
            {
                foreach (var path in OfficialCorePackageSourceFilesForTarget(rule))
                    AddSource(result, rule, path);
                foreach (var relativePath in rule.Add)
                    AddSource(result, rule, RepositoryPath(relativePath));
            }
        }

        return result;
    }

    private IReadOnlySet<string> SelectPackages(VNextCoreSourceStage stage)
    {
        var rulesByPackage = manifest
            .Packages.Where(rule => rule.Stage == stage)
            .GroupBy(rule => rule.ModulePath, StringComparer.Ordinal)
            .ToDictionary(group => group.Key, group => group.First(), StringComparer.Ordinal);
        var selected = new HashSet<string>(StringComparer.Ordinal);
        var queue = new Queue<string>();

        foreach (var seed in manifest.Seeds.GetValueOrDefault(stage, []))
            Enqueue(seed);
        foreach (var modulePath in manifest.BackendRequiredPackages)
            if (rulesByPackage.ContainsKey(modulePath))
                Enqueue(modulePath);

        while (queue.Count > 0)
        {
            var modulePath = queue.Dequeue();
            if (!rulesByPackage.TryGetValue(modulePath, out var rule))
                continue;

            foreach (var imported in PackageImports(rule))
                if (rulesByPackage.ContainsKey(imported))
                    Enqueue(imported);
        }

        return selected;

        void Enqueue(string modulePath)
        {
            if (selected.Add(modulePath))
                queue.Enqueue(modulePath);
        }
    }

    private IReadOnlyList<VNextCorePackageRule> OrderedPackageRules(
        VNextCoreSourceStage stage,
        IReadOnlySet<string> selectedPackages
    )
    {
        var rulesByPackage = manifest
            .Packages.Where(rule => rule.Stage == stage && selectedPackages.Contains(rule.ModulePath))
            .GroupBy(rule => rule.ModulePath, StringComparer.Ordinal)
            .ToDictionary(group => group.Key, group => group.First(), StringComparer.Ordinal);
        var result = new List<VNextCorePackageRule>();
        var visiting = new HashSet<string>(StringComparer.Ordinal);
        var visited = new HashSet<string>(StringComparer.Ordinal);

        foreach (var rule in manifest.Packages.Where(rule =>
            rule.Stage == stage && selectedPackages.Contains(rule.ModulePath)
        ))
            Visit(rule.ModulePath);

        return result;

        void Visit(string modulePath)
        {
            if (visited.Contains(modulePath))
                return;
            if (!visiting.Add(modulePath))
                return;
            if (!rulesByPackage.TryGetValue(modulePath, out var rule))
                return;

            foreach (var imported in PackageImports(rule))
                if (selectedPackages.Contains(imported))
                    Visit(imported);

            visiting.Remove(modulePath);
            visited.Add(modulePath);
            result.Add(rule);
        }
    }

    private IEnumerable<string> PackageImports(VNextCorePackageRule rule)
    {
        if (rule.ReplaceAll.Count > 0)
        {
            foreach (var relativePath in rule.ReplaceAll)
            foreach (var imported in MoonPkgImportsFromSource(File.ReadAllText(RepositoryPath(relativePath))))
                yield return imported;
            if (rule.ModulePath != "moonbitlang/core/prelude")
            {
                var officialMoonPkgPath = Path.Combine(RepositoryPath(rule.ModulePath), "moon.pkg");
                if (File.Exists(officialMoonPkgPath))
                    foreach (
                        var imported in MoonPkgImportsFromSource(File.ReadAllText(officialMoonPkgPath))
                    )
                        yield return imported;
            }
            yield break;
        }

        var moonPkgPath = Path.Combine(RepositoryPath(rule.ModulePath), "moon.pkg");
        if (!File.Exists(moonPkgPath))
            yield break;

        foreach (var imported in MoonPkgImportsFromSource(File.ReadAllText(moonPkgPath)))
            yield return imported;
    }

    private IEnumerable<string> MoonPkgImportsFromSource(string source)
    {
        foreach (
            Match importBlock in Regex.Matches(
                source,
                @"import\s*\{(?<body>.*?)\}\s*(?<qualifier>for\s*""[^""]+"")?",
                RegexOptions.Singleline
            )
        )
        {
            if (importBlock.Groups["qualifier"].Success)
                continue;

            foreach (
                Match import in Regex.Matches(
                    importBlock.Groups["body"].Value,
                    @"""(?<module>moonbitlang/core/[^""]+)"""
                )
            )
                yield return import.Groups["module"].Value;
        }
    }

    private IReadOnlyList<string> OfficialCorePackageSourceFilesForTarget(
        VNextCorePackageRule rule
    )
    {
        var packagePath = RepositoryPath(rule.ModulePath);
        var excluded = OfficialCoreFilesExcludedForSourceTarget(packagePath, "csharp");
        foreach (var fileName in rule.Exclude)
            excluded.Add(fileName);

        return Directory
            .EnumerateFiles(packagePath, "*.mbt", SearchOption.TopDirectoryOnly)
            .Where(MoonBitSourceTranspiler.IsSourceCandidate)
            .Where(path => !excluded.Contains(Path.GetFileName(path)))
            .Order(StringComparer.Ordinal)
            .Select(Path.GetFullPath)
            .ToArray();
    }

    private static HashSet<string> OfficialCoreFilesExcludedForSourceTarget(
        string packagePath,
        string target
    )
    {
        var excluded = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var moonPkgPath = Path.Combine(packagePath, "moon.pkg");
        if (!File.Exists(moonPkgPath))
            return excluded;

        var source = File.ReadAllText(moonPkgPath);
        foreach (
            Match match in Regex.Matches(
                source,
                "\"(?<file>[^\"]+\\.mbt)\"\\s*:\\s*\\[(?<targets>[^\\]]*)\\]"
            )
        )
        {
            var fileName = match.Groups["file"].Value;
            var targets = Regex
                .Matches(match.Groups["targets"].Value, "\"(?<target>[^\"]+)\"")
                .Select(item => item.Groups["target"].Value)
                .ToArray();
            if (!OfficialCoreTargetSpecAllowsSourceTarget(targets, target))
                excluded.Add(fileName);
        }

        return excluded;
    }

    private static bool OfficialCoreTargetSpecAllowsSourceTarget(
        IReadOnlyList<string> targets,
        string target
    )
    {
        if (targets.Count == 0)
            return true;

        if (targets.Contains("not", StringComparer.Ordinal))
            return !targets.Contains(target, StringComparer.Ordinal);

        return targets.Contains(target, StringComparer.Ordinal);
    }

    private static void AddSource(
        List<VNextDeclarationSource> sources,
        VNextCorePackageRule rule,
        string path
    )
    {
        if (File.Exists(path))
            sources.Add(
                new(rule.Alias, "pkg:" + rule.ModulePath, rule.ModulePath, Path.GetFullPath(path))
            );
    }

    private string RepositoryPath(string relativePath)
    {
        return Path.Combine([repositoryRoot, .. relativePath.Split('/')]);
    }
}
