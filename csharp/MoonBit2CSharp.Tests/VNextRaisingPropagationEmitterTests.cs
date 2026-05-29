using System.Reflection;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using MoonBit2CSharp.VNext.Backend;
using Xunit;

namespace MoonBit2CSharp.Tests;

public sealed class VNextRaisingPropagationEmitterTests
{
    [Fact]
    public void PropagatesRaisingArgumentWithCurrentConcreteErrorType()
    {
        var code = VNextBackend.Emit(ModuleJson(PropagatingArgumentFunctions()));

        Assert.Contains("\"Demo.TestError.\" + __mbt_raise_result", code);
        Assert.Contains(".Error!.ToString()", code);
        Assert.DoesNotContain("TestErrorMoonBitNames", code);
        Assert.Contains("MoonBitResult<MoonBitUnit, TestError>.Err(__mbt_raise_result", code);
        Assert.DoesNotContain("MoonBitResult<MoonBitUnit, object>.Err", code);
        Assert.DoesNotContain(
            "MoonBitResult<MoonBitUnit, global::Generated.MoonBit.Packages.moonbitlang.core.builtin.Error>.Err",
            code
        );

        Compile(code);
    }

    [Fact]
    public void TryBodyRaisingArgumentBranchesToCatchLabel()
    {
        var code = VNextBackend.Emit(
            ModuleJson(
                PropagatingArgumentFunctions()
                    + """
                    ,
                    {
                      "kind": "Function",
                      "symbolId": "fn:pkg:Demo:Demo:main",
                      "name": "main",
                      "typeParams": [],
                      "params": [],
                      "returnType": { "kind": "Builtin", "name": "Unit" },
                      "body": {
                        "kind": "TryCatch",
                        "body": {
                          "kind": "Call",
                          "functionId": "fn:pkg:Demo:Demo:consume_string",
                          "args": [
                            {
                              "kind": "Call",
                              "functionId": "fn:pkg:Demo:Demo:raise_error",
                              "args": [],
                              "type": { "kind": "Builtin", "name": "String" }
                            }
                          ],
                          "type": { "kind": "Builtin", "name": "Unit" }
                        },
                        "arms": [
                          {
                            "pattern": {
                              "kind": "Binding",
                              "symbol": {
                                "symbolId": "fn:pkg:Demo:Demo:main:catch:e",
                                "name": "e",
                                "type": { "kind": "Declared", "symbol": { "id": "type:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Error", "packageId": "pkg:moonbitlang/core/builtin", "modulePath": "moonbitlang/core/builtin", "name": "Error" }, "args": [] }
                              }
                            },
                            "body": { "kind": "UnitLiteral", "type": { "kind": "Builtin", "name": "Unit" } }
                          }
                        ],
                        "type": { "kind": "Builtin", "name": "Unit" }
                      }
                    }
                    """
            )
        );

        Assert.Contains("goto __mbt_try_catch", code);
        Assert.Contains(".Error!.ToString()", code);
        Assert.DoesNotContain("TestErrorMoonBitNames", code);
        Assert.DoesNotContain("return MoonBitResult<MoonBitUnit, object>.Err", code);
        Assert.DoesNotContain(
            "return MoonBitResult<MoonBitUnit, global::Generated.MoonBit.Packages.moonbitlang.core.builtin.Error>.Err",
            code
        );

        Compile(code);
    }

    private static string PropagatingArgumentFunctions()
    {
        return $$"""
            {
              "kind": "Function",
              "symbolId": "fn:pkg:Demo:Demo:consume_string",
              "name": "consume_string",
              "typeParams": [],
              "params": [
                { "symbolId": "fn:pkg:Demo:Demo:consume_string:param:value", "name": "value", "type": { "kind": "Builtin", "name": "String" } }
              ],
              "returnType": { "kind": "Builtin", "name": "Unit" },
              "external": { "target": "csharp", "body": "return MoonBitUnit.Value;" },
              "body": { "kind": "UnitLiteral", "type": { "kind": "Builtin", "name": "Unit" } }
            },
            {
              "kind": "Function",
              "symbolId": "fn:pkg:Demo:Demo:raise_test_error",
              "name": "raise_test_error",
              "typeParams": [],
              "params": [],
              "returnType": { "kind": "Builtin", "name": "String" },
              "effect": { "kind": "Raises", "error": {{TestErrorTypeRef()}} },
              "body": {
                "kind": "Raise",
                "value": {
                  "kind": "EnumCase",
                  "typeId": "type:pkg:Demo:Demo:TestError",
                  "variantId": "type:pkg:Demo:Demo:TestError:variant:Example",
                  "name": "Example",
                  "args": [],
                  "type": {{TestErrorTypeRef()}}
                },
                "type": { "kind": "Builtin", "name": "String" }
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:pkg:Demo:Demo:consume_raising_string",
              "name": "consume_raising_string",
              "typeParams": [],
              "params": [],
              "returnType": { "kind": "Builtin", "name": "Unit" },
              "effect": { "kind": "Raises", "error": {{TestErrorTypeRef()}} },
              "body": {
                "kind": "Call",
                "functionId": "fn:pkg:Demo:Demo:consume_string",
                "args": [
                  {
                    "kind": "Call",
                    "functionId": "fn:pkg:Demo:Demo:raise_test_error",
                    "args": [],
                    "type": { "kind": "Builtin", "name": "String" }
                  }
                ],
                "type": { "kind": "Builtin", "name": "Unit" }
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:pkg:Demo:Demo:raise_error",
              "name": "raise_error",
              "typeParams": [],
              "params": [],
              "returnType": { "kind": "Builtin", "name": "String" },
              "effect": { "kind": "Raises", "error": {{CoreErrorTypeRef()}} },
              "body": {
                "kind": "Sequence",
                "first": {
                  "kind": "Call",
                  "functionId": "fn:pkg:Demo:Demo:consume_string",
                  "args": [
                    {
                      "kind": "Call",
                      "functionId": "fn:pkg:Demo:Demo:raise_test_error",
                      "args": [],
                      "type": { "kind": "Builtin", "name": "String" }
                    }
                  ],
                  "type": { "kind": "Builtin", "name": "Unit" }
                },
                "body": { "kind": "StringLiteral", "value": "will not be returned", "type": { "kind": "Builtin", "name": "String" } },
                "type": { "kind": "Builtin", "name": "String" }
              }
            }
            """;
    }

    private static string ModuleJson(string functions)
    {
        return $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [
                {
                  "kind": "Enum",
                  "symbol": { "id": "type:pkg:Demo:Demo:TestError", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "TestError" },
                  "typeParams": [],
                  "variants": [
                    { "id": "type:pkg:Demo:Demo:TestError:variant:Example", "name": "Example", "payloads": [] }
                  ]
                }
              ],
              "traits": [
                {
                  "kind": "Trait",
                  "symbol": { "id": "type:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Show", "packageId": "pkg:moonbitlang/core/builtin", "modulePath": "moonbitlang/core/builtin", "name": "Show" },
                  "methods": [
                    {
                      "name": "to_string",
                      "params": [
                        { "label": null, "type": { "kind": "Builtin", "name": "Self" }, "optional": false, "hasDefault": false }
                      ],
                      "returnType": { "kind": "Builtin", "name": "String" }
                    }
                  ]
                }
              ],
              "functions": [
                {{functions}}
              ],
              "globals": [],
              "diagnostics": []
            }
            """;
    }

    private static string TestErrorTypeRef()
    {
        return """{ "kind": "Declared", "symbol": { "id": "type:pkg:Demo:Demo:TestError", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "TestError" }, "args": [] }""";
    }

    private static string CoreErrorTypeRef()
    {
        return """{ "kind": "Declared", "symbol": { "id": "type:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Error", "packageId": "pkg:moonbitlang/core/builtin", "modulePath": "moonbitlang/core/builtin", "name": "Error" }, "args": [] }""";
    }

    private static Assembly Compile(string source)
    {
        var parseOptions = CSharpParseOptions.Default.WithLanguageVersion(LanguageVersion.Preview);
        var syntaxTree = CSharpSyntaxTree.ParseText(source, parseOptions);
        var coreSupportTree = CSharpSyntaxTree.ParseText(
            """
            namespace Generated.MoonBit.Packages.moonbitlang.core.builtin;

            public sealed class Error
            {
                public object Self { get; }
                public string DisplayName { get; }

                private Error(object self, string displayName)
                {
                    Self = self;
                    DisplayName = displayName;
                }

                public static Error FromObject(object value, string displayName) =>
                    new(value, displayName);

                public override string ToString() => DisplayName;
            }
            """,
            parseOptions
        );
        var references = ((string?)AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES"))!
            .Split(Path.PathSeparator)
            .Select(path => MetadataReference.CreateFromFile(path))
            .Concat(
                AppDomain
                    .CurrentDomain.GetAssemblies()
                    .Where(assembly =>
                        !assembly.IsDynamic && !string.IsNullOrEmpty(assembly.Location)
                    )
                    .Select(assembly => MetadataReference.CreateFromFile(assembly.Location))
            )
            .DistinctBy(reference => reference.Display);
        var compilation = CSharpCompilation.Create(
            "GeneratedMoonBitVNextRaisingPropagationTests",
            [syntaxTree, coreSupportTree],
            references,
            new(OutputKind.DynamicallyLinkedLibrary)
        );

        using var stream = new MemoryStream();
        var result = compilation.Emit(stream);
        if (!result.Success)
            throw new InvalidOperationException(
                string.Join(Environment.NewLine, result.Diagnostics.Select(d => d.ToString()))
            );

        stream.Position = 0;
        return Assembly.Load(stream.ToArray());
    }
}
