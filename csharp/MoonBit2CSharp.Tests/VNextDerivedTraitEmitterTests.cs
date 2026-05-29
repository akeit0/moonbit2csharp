using System.Reflection;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using MoonBit2CSharp.VNext.Backend;
using Xunit;

namespace MoonBit2CSharp.Tests;

public sealed class VNextDerivedTraitEmitterTests
{
    [Fact]
    public void EmitsDerivedStructEqualityAndComparison()
    {
        var pointType = PointTypeJson();
        var json = ModuleJson(
            $$"""
            "types": [{{pointType}}],
            "functions": [
              {
                "kind": "Function",
                "symbolId": "fn:pkg:Demo:Demo:eq",
                "name": "eq",
                "typeParams": [],
                "params": [
                  { "symbolId": "fn:pkg:Demo:Demo:eq:param:left", "name": "left", "label": null, "optional": false, "hasDefault": false, "type": {{PointTypeRef()}} },
                  { "symbolId": "fn:pkg:Demo:Demo:eq:param:right", "name": "right", "label": null, "optional": false, "hasDefault": false, "type": {{PointTypeRef()}} }
                ],
                "returnType": { "kind": "Builtin", "name": "Bool" },
                "external": null,
                "body": {{Binary("==", "left", "right", "Eq", "equal")}}
              },
              {
                "kind": "Function",
                "symbolId": "fn:pkg:Demo:Demo:neq",
                "name": "neq",
                "typeParams": [],
                "params": [
                  { "symbolId": "fn:pkg:Demo:Demo:neq:param:left", "name": "left", "label": null, "optional": false, "hasDefault": false, "type": {{PointTypeRef()}} },
                  { "symbolId": "fn:pkg:Demo:Demo:neq:param:right", "name": "right", "label": null, "optional": false, "hasDefault": false, "type": {{PointTypeRef()}} }
                ],
                "returnType": { "kind": "Builtin", "name": "Bool" },
                "external": null,
                "body": {{Binary("!=", "left", "right", "Eq", "not_equal")}}
              },
              {
                "kind": "Function",
                "symbolId": "fn:pkg:Demo:Demo:lt",
                "name": "lt",
                "typeParams": [],
                "params": [
                  { "symbolId": "fn:pkg:Demo:Demo:lt:param:left", "name": "left", "label": null, "optional": false, "hasDefault": false, "type": {{PointTypeRef()}} },
                  { "symbolId": "fn:pkg:Demo:Demo:lt:param:right", "name": "right", "label": null, "optional": false, "hasDefault": false, "type": {{PointTypeRef()}} }
                ],
                "returnType": { "kind": "Builtin", "name": "Bool" },
                "external": null,
                "body": {{Binary("<", "left", "right", "Compare", "op_lt")}}
              }
            ]
            """
        );

        var assembly = Compile(VNextBackend.Emit(json));
        var demo = assembly.GetType("Generated.MoonBit.Packages.Demo.Demo", true)!;
        var point = assembly.GetType("Generated.MoonBit.Packages.Demo.Point", true)!;
        var p12 = Activator.CreateInstance(point, 1, 2);
        var p21 = Activator.CreateInstance(point, 2, 1);
        var p12b = Activator.CreateInstance(point, 1, 2);

        Assert.Equal(true, demo.GetMethod("eq")!.Invoke(null, [p12, p12b]));
        Assert.Equal(false, demo.GetMethod("eq")!.Invoke(null, [p12, p21]));
        Assert.Equal(true, demo.GetMethod("neq")!.Invoke(null, [p12, p21]));
        Assert.Equal(true, demo.GetMethod("lt")!.Invoke(null, [p12, p21]));
    }

    [Fact]
    public void EmitsDerivedPayloadEnumEqualityAndComparison()
    {
        var choiceType = ChoiceTypeJson();
        var json = ModuleJson(
            $$"""
            "types": [{{choiceType}}],
            "functions": [
              {
                "kind": "Function",
                "symbolId": "fn:pkg:Demo:Demo:eq",
                "name": "eq",
                "typeParams": [],
                "params": [
                  { "symbolId": "fn:pkg:Demo:Demo:eq:param:left", "name": "left", "label": null, "optional": false, "hasDefault": false, "type": {{ChoiceTypeRef()}} },
                  { "symbolId": "fn:pkg:Demo:Demo:eq:param:right", "name": "right", "label": null, "optional": false, "hasDefault": false, "type": {{ChoiceTypeRef()}} }
                ],
                "returnType": { "kind": "Builtin", "name": "Bool" },
                "external": null,
                "body": {{EnumBinary("==", "left", "right", "Eq", "equal")}}
              },
              {
                "kind": "Function",
                "symbolId": "fn:pkg:Demo:Demo:lt",
                "name": "lt",
                "typeParams": [],
                "params": [
                  { "symbolId": "fn:pkg:Demo:Demo:lt:param:left", "name": "left", "label": null, "optional": false, "hasDefault": false, "type": {{ChoiceTypeRef()}} },
                  { "symbolId": "fn:pkg:Demo:Demo:lt:param:right", "name": "right", "label": null, "optional": false, "hasDefault": false, "type": {{ChoiceTypeRef()}} }
                ],
                "returnType": { "kind": "Builtin", "name": "Bool" },
                "external": null,
                "body": {{EnumBinary("<", "left", "right", "Compare", "op_lt")}}
              },
              {
                "kind": "Function",
                "symbolId": "fn:pkg:Demo:Demo:default_choice",
                "name": "default_choice",
                "typeParams": [],
                "params": [],
                "returnType": {{ChoiceTypeRef()}},
                "external": null,
                "body": { "kind": "Call", "functionId": "derived:trait:type:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Default:Choice:default", "typeArgs": [], "traitEvidence": [], "args": [], "selectedIntrinsic": null, "type": {{ChoiceTypeRef()}} }
              }
            ]
            """
        );

        var assembly = Compile(VNextBackend.Emit(json));
        var demo = assembly.GetType("Generated.MoonBit.Packages.Demo.Demo", true)!;
        var choice = assembly.GetType("Generated.MoonBit.Packages.Demo.Choice", true)!;
        var a = choice.GetMethod("A")!;
        var b = choice.GetMethod("B")!;
        var c = choice.GetField("C")!.GetValue(null);
        var a42 = a.Invoke(null, [42]);
        var a43 = a.Invoke(null, [43]);
        var bHello = b.Invoke(null, ["hello"]);
        var bWorld = b.Invoke(null, ["world"]);

        Assert.Equal(true, demo.GetMethod("eq")!.Invoke(null, [a42, a.Invoke(null, [42])]));
        Assert.Equal(false, demo.GetMethod("eq")!.Invoke(null, [a42, a43]));
        Assert.Equal(true, demo.GetMethod("lt")!.Invoke(null, [a42, a43]));
        Assert.Equal(true, demo.GetMethod("lt")!.Invoke(null, [a42, bHello]));
        Assert.Equal(true, demo.GetMethod("lt")!.Invoke(null, [bHello, bWorld]));
        Assert.Equal(true, demo.GetMethod("lt")!.Invoke(null, [bHello, c]));
        Assert.Equal(c, demo.GetMethod("default_choice")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsDerivedDebugWithEnumPayloadLabels()
    {
        var code = VNextBackend.Emit(
            ModuleJson(
                $$"""
                "types": [{{choiceTypeJsonWithDebug()}}],
                "usedTraitImpls": [
                  {
                    "trait": { "symbol": { "id": "type:pkg:moonbitlang/core/debug:moonbitlang/core/debug:Debug", "packageId": "pkg:moonbitlang/core/debug", "modulePath": "moonbitlang/core/debug", "name": "Debug" }, "args": [] },
                    "selfType": {{ChoiceTypeRef()}}
                  }
                ],
                "functions": [
                  {
                    "kind": "Function",
                    "symbolId": "fn:pkg:Demo:Demo:repr",
                    "name": "repr",
                    "typeParams": [],
                    "params": [
                      { "symbolId": "fn:pkg:Demo:Demo:repr:param:value", "name": "value", "label": null, "optional": false, "hasDefault": false, "type": {{ChoiceTypeRef()}} }
                    ],
                    "returnType": {{ReprTypeRef()}},
                    "external": null,
                    "body": {
                      "kind": "TraitMethodCall",
                      "receiver": { "kind": "Name", "symbolId": "fn:pkg:Demo:Demo:repr:param:value", "name": "value", "type": {{ChoiceTypeRef()}} },
                      "trait": { "symbol": { "id": "type:pkg:moonbitlang/core/debug:moonbitlang/core/debug:Debug", "packageId": "pkg:moonbitlang/core/debug", "modulePath": "moonbitlang/core/debug", "name": "Debug" }, "args": [] },
                      "methodId": "trait-method:type:pkg:moonbitlang/core/debug:moonbitlang/core/debug:Debug:to_repr",
                      "name": "to_repr",
                      "args": [],
                      "dispatch": { "kind": "ConcreteImpl", "functionId": "derived:trait:type:pkg:moonbitlang/core/debug:moonbitlang/core/debug:Debug:Choice:to_repr", "selectedIntrinsic": null },
                      "type": {{ReprTypeRef()}}
                    }
                  }
                ]
                """
            )
        );

        Assert.Contains("EnumLabeledArg(\"label\"", code, StringComparison.Ordinal);
        Assert.Contains("public sealed class ChoiceDebugImpl", code, StringComparison.Ordinal);
        Assert.Contains(
            ": global::Generated.MoonBit.Packages.moonbitlang.core.debug.IDebugImpl<Choice, ChoiceDebugImpl>",
            code,
            StringComparison.Ordinal
        );
        Assert.Contains(
            "DebugTrait.to_repr<Choice, ChoiceDebugImpl>(value)",
            code,
            StringComparison.Ordinal
        );
        Assert.DoesNotContain("new Choice.", code, StringComparison.Ordinal);

        static string choiceTypeJsonWithDebug()
        {
            return ChoiceTypeJson()
                .Replace(
                    "\"derives\": [\"Eq\", \"Compare\", \"Default\"]",
                    "\"derives\": [\"Debug\"]",
                    StringComparison.Ordinal
                );
        }
    }

    [Fact]
    public void EmitsDerivedHashForPayloadEnumStructurally()
    {
        var json = ModuleJson(
                $$"""
                  "types": [{{ChoiceTypeJson().Replace(
                    "\"derives\": [\"Eq\", \"Compare\", \"Default\"]",
                    "\"derives\": [\"Hash\"]",
                    StringComparison.Ordinal
                )}}],
                  "usedTraitImpls": [
                    {
                      "trait": { "symbol": { "id": "type:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Hash", "packageId": "pkg:moonbitlang/core/builtin", "modulePath": "moonbitlang/core/builtin", "name": "Hash" }, "args": [] },
                      "selfType": {{ChoiceTypeRef()}}
                    }
                  ],
                  "functions": []
                  """
            )
            .Replace(
                "\"traits\": []",
                $"\"traits\": [{HashTraitJson()}]",
                StringComparison.Ordinal
            );

        var assembly = Compile(VNextBackend.Emit(json));
        var choice = assembly.GetType("Generated.MoonBit.Packages.Demo.Choice", true)!;
        var hashImpl = assembly.GetType("Generated.MoonBit.Packages.Demo.ChoiceHashImpl", true)!;
        var hashTrait = assembly.GetTypes().Single(type => type.Name == "HashTrait");
        var hash = hashTrait.GetMethod("Hash")!.MakeGenericMethod(choice, hashImpl);
        var a = choice.GetMethod("A")!;
        var b = choice.GetMethod("B")!;
        var a42 = a.Invoke(null, [42]);
        var a42b = a.Invoke(null, [42]);
        var a43 = a.Invoke(null, [43]);
        var bHello = b.Invoke(null, ["hello"]);

        Assert.Equal(hash.Invoke(null, [a42]), hash.Invoke(null, [a42b]));
        Assert.NotEqual(hash.Invoke(null, [a42]), hash.Invoke(null, [a43]));
        Assert.NotEqual(hash.Invoke(null, [a42]), hash.Invoke(null, [bHello]));
    }

    private static string ModuleJson(string members)
    {
        return $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "traits": [],
              "usedTraitImpls": [],
              "globals": [],
              "diagnostics": [],
              {{members}}
            }
            """;
    }

    private static string PointTypeJson()
    {
        return """
            {
              "kind": "Struct",
              "symbol": { "id": "type:pkg:Demo:Demo:Point", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Point" },
              "typeParams": [],
              "fields": [
                { "id": "type:pkg:Demo:Demo:Point:field:x", "name": "x", "mutable": false, "type": { "kind": "Builtin", "name": "Int" } },
                { "id": "type:pkg:Demo:Demo:Point:field:y", "name": "y", "mutable": false, "type": { "kind": "Builtin", "name": "Int" } }
              ],
              "derives": ["Eq", "Compare", "Default"]
            }
            """;
    }

    private static string ChoiceTypeJson()
    {
        return """
            {
              "kind": "Enum",
              "symbol": { "id": "type:pkg:Demo:Demo:Choice", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Choice" },
              "typeParams": [],
              "variants": [
                { "id": "type:pkg:Demo:Demo:Choice:variant:A", "name": "A", "payloads": [{ "label": null, "type": { "kind": "Builtin", "name": "Int" } }] },
                { "id": "type:pkg:Demo:Demo:Choice:variant:B", "name": "B", "payloads": [{ "label": "label", "type": { "kind": "Builtin", "name": "String" } }] },
                { "id": "type:pkg:Demo:Demo:Choice:variant:C", "name": "C", "payloads": [] }
              ],
              "derives": ["Eq", "Compare", "Default"]
            }
            """;
    }

    private static string PointTypeRef()
    {
        return """{ "kind": "Declared", "symbol": { "id": "type:pkg:Demo:Demo:Point", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Point" }, "args": [] }""";
    }

    private static string ChoiceTypeRef()
    {
        return """{ "kind": "Declared", "symbol": { "id": "type:pkg:Demo:Demo:Choice", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Choice" }, "args": [] }""";
    }

    private static string ReprTypeRef()
    {
        return """{ "kind": "Declared", "symbol": { "id": "type:pkg:moonbitlang/core/debug:moonbitlang/core/debug:Repr", "packageId": "pkg:moonbitlang/core/debug", "modulePath": "moonbitlang/core/debug", "name": "Repr" }, "args": [] }""";
    }

    private static string HashTraitJson()
    {
        return """
            {
              "kind": "Trait",
              "symbol": { "id": "type:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Hash", "packageId": "pkg:moonbitlang/core/builtin", "modulePath": "moonbitlang/core/builtin", "name": "Hash" },
              "methods": [
                {
                  "name": "hash_combine",
                  "params": [
                    { "label": null, "type": { "kind": "Builtin", "name": "Self" }, "optional": false, "hasDefault": false },
                    { "label": null, "type": { "kind": "Declared", "symbol": { "id": "type:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Hasher", "packageId": "pkg:moonbitlang/core/builtin", "modulePath": "moonbitlang/core/builtin", "name": "Hasher" }, "args": [] }, "optional": false, "hasDefault": false }
                  ],
                  "returnType": { "kind": "Builtin", "name": "Unit" }
                }
              ]
            }
            """;
    }

    private static string Binary(string op, string left, string right, string trait, string method)
    {
        var functionName = op switch
        {
            "<" => "lt",
            "==" => "eq",
            _ => "neq",
        };
        return $$"""
            {
              "kind": "Binary",
              "op": "{{op}}",
              "left": { "kind": "Name", "symbolId": "fn:pkg:Demo:Demo:{{functionName}}:param:left", "name": "{{left}}", "type": {{PointTypeRef()}} },
              "right": { "kind": "Name", "symbolId": "fn:pkg:Demo:Demo:{{functionName}}:param:right", "name": "{{right}}", "type": {{PointTypeRef()}} },
              "selectedFunctionId": "derived:trait:type:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:{{trait}}:Point:{{method}}",
              "typeArgs": [],
              "traitEvidence": [],
              "selectedIntrinsic": null,
              "type": { "kind": "Builtin", "name": "Bool" }
            }
            """;
    }

    private static string EnumBinary(
        string op,
        string left,
        string right,
        string trait,
        string method
    )
    {
        return Binary(op, left, right, trait, method)
            .Replace(PointTypeRef(), ChoiceTypeRef(), StringComparison.Ordinal)
            .Replace(":Point:", ":Choice:", StringComparison.Ordinal);
    }

    private static Assembly Compile(string source)
    {
        var syntaxTree = CSharpSyntaxTree.ParseText(
            source,
            CSharpParseOptions.Default.WithLanguageVersion(LanguageVersion.Preview)
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
            "GeneratedMoonBitVNextDerivedTraitTests",
            [syntaxTree],
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
