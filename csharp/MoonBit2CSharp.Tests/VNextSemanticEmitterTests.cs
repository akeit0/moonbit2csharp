using System.Reflection;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using MoonBit.Runtime;
using MoonBit2CSharp.VNext.Backend;
using Xunit;

namespace MoonBit2CSharp.Tests;

public sealed partial class VNextSemanticEmitterTests
{
    [Fact]
    public void EmitsExecutableCSharpForDemoFunctionIr()
    {
        var json = ModuleJson(
            """
            {
              "kind": "Function",
              "symbolId": "fn:Demo:demo_func",
              "name": "demo_func",
              "params": [
                { "symbolId": "fn:Demo:demo_func:param:a", "name": "a", "type": { "kind": "Builtin", "name": "Int" } },
                { "symbolId": "fn:Demo:demo_func:param:b", "name": "b", "type": { "kind": "Builtin", "name": "Int" } }
              ],
              "returnType": { "kind": "Builtin", "name": "Int" },
              "body": {
                "kind": "Binary",
                "op": "+",
                "left": { "kind": "Name", "symbolId": "fn:Demo:demo_func:param:a", "name": "a", "type": { "kind": "Builtin", "name": "Int" } },
                "right": { "kind": "Name", "symbolId": "fn:Demo:demo_func:param:b", "name": "b", "type": { "kind": "Builtin", "name": "Int" } },
                "selectedFunctionId": "core:Int::op_add",
                "selectedIntrinsic": "%i32_add",
                "type": { "kind": "Builtin", "name": "Int" }
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        var result = type.GetMethod("demo_func")!.Invoke(null, [3, 4]);

        Assert.Equal(7, result);
    }

    [Fact]
    public void EmitsExternCSharpFunctionBodies()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:answer",
              "name": "answer",
              "params": [],
              "returnType": {{intType}},
              "external": { "target": "csharp", "body": "return 42;" },
              "body": { "kind": "UnitLiteral", "type": {{unitType}} }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:call",
              "name": "call",
              "params": [],
              "returnType": {{intType}},
              "body": {
                "kind": "Call",
                "functionId": "fn:Demo:answer",
                "args": [],
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Contains("public static int answer()", code, StringComparison.Ordinal);
        Assert.Contains("return 42;", code, StringComparison.Ordinal);
        Assert.Equal(42, type.GetMethod("call")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsUnavailableExternalTargetsAsRuntimeStubs()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:js_only",
              "name": "js_only",
              "params": [],
              "returnType": {{intType}},
              "external": { "target": "js", "body": "x => x" },
              "body": { "kind": "UnitLiteral", "type": {{unitType}} }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        var error = Assert.Throws<TargetInvocationException>(() =>
            type.GetMethod("js_only")!.Invoke(null, [])
        );
        var inner = Assert.IsType<NotImplementedException>(error.InnerException);
        Assert.Contains(
            "extern target is not linked for C#: js",
            inner.Message,
            StringComparison.Ordinal
        );
    }

    [Fact]
    public void RejectsUnlinkedFunctionCallBeforeCSharpEmission()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:call",
              "name": "call",
              "params": [],
              "returnType": {{intType}},
              "body": {
                "kind": "Call",
                "functionId": "fn:pkg:Demo:Demo:missing",
                "args": [],
                "type": {{intType}}
              }
            }
            """
        );

        var error = Assert.Throws<InvalidOperationException>(() => VNextBackend.Emit(json));

        Assert.Contains("VNXB001", error.Message, StringComparison.Ordinal);
        Assert.Contains("fn:pkg:Demo:Demo:missing", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void EmitsCoreBuiltinTypesInTypeDefinitions()
    {
        var json = """
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [
                {
                  "kind": "Struct",
                  "symbol": { "id": "type:pkg:demo:Demo:CoreBox", "packageId": "pkg:demo", "modulePath": "Demo", "name": "CoreBox" },
                  "typeParams": [],
                  "fields": [
                    { "name": "b", "mutable": false, "type": { "kind": "Builtin", "name": "Byte" } },
                    { "name": "u64", "mutable": false, "type": { "kind": "Builtin", "name": "UInt64" } },
                    { "name": "loc", "mutable": false, "type": { "kind": "Builtin", "name": "SourceLoc" } },
                    { "name": "bytes", "mutable": false, "type": { "kind": "Builtin", "name": "Bytes" } },
                    { "name": "view", "mutable": false, "type": { "kind": "Builtin", "name": "BytesView" } },
                    { "name": "mutView", "mutable": false, "type": { "kind": "Apply", "constructor": { "kind": "Builtin", "name": "MutArrayView" }, "args": [{ "kind": "Builtin", "name": "Int" }] } },
                    { "name": "iter", "mutable": false, "type": { "kind": "Apply", "constructor": { "kind": "Builtin", "name": "Iter" }, "args": [{ "kind": "Builtin", "name": "String" }] } },
                    { "name": "result", "mutable": false, "type": { "kind": "Apply", "constructor": { "kind": "Builtin", "name": "Result" }, "args": [{ "kind": "Builtin", "name": "Int" }, { "kind": "Builtin", "name": "String" }] } },
                    { "name": "raw", "mutable": false, "type": { "kind": "Apply", "constructor": { "kind": "Builtin", "name": "UninitializedArray" }, "args": [{ "kind": "Builtin", "name": "Byte" }] } }
                  ]
                }
              ],
              "traits": [],
              "functions": [],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);

        Assert.Contains("public byte b", code, StringComparison.Ordinal);
        Assert.Contains("public ulong u64", code, StringComparison.Ordinal);
        Assert.Contains("public MoonBitSourceLoc loc", code, StringComparison.Ordinal);
        Assert.Contains("public byte[] bytes", code, StringComparison.Ordinal);
        Assert.Contains("public MoonBitBytesView view", code, StringComparison.Ordinal);
        Assert.Contains("public MoonBitMutArrayView<int> mutView", code, StringComparison.Ordinal);
        Assert.Contains("public MoonBitIter<string> iter", code, StringComparison.Ordinal);
        Assert.Contains("public MoonBitResult<int, string> result", code, StringComparison.Ordinal);
        Assert.Contains("public byte[] raw", code, StringComparison.Ordinal);
        Compile(code);
    }

    [Fact]
    public void EmitsIntrinsicBackedBinaryOperator()
    {
        var json = ModuleJson(
            """
            {
              "kind": "Function",
              "symbolId": "fn:Demo:sub",
              "name": "sub",
              "params": [
                { "symbolId": "fn:Demo:sub:param:a", "name": "a", "type": { "kind": "Builtin", "name": "Int" } },
                { "symbolId": "fn:Demo:sub:param:b", "name": "b", "type": { "kind": "Builtin", "name": "Int" } }
              ],
              "returnType": { "kind": "Builtin", "name": "Int" },
              "body": {
                "kind": "Binary",
                "op": "-",
                "left": { "kind": "Name", "symbolId": "fn:Demo:sub:param:a", "name": "a", "type": { "kind": "Builtin", "name": "Int" } },
                "right": { "kind": "Name", "symbolId": "fn:Demo:sub:param:b", "name": "b", "type": { "kind": "Builtin", "name": "Int" } },
                "selectedFunctionId": "builtin:trait:moonbitlang/core/builtin:Sub:sub:Int",
                "selectedIntrinsic": "%i32_sub",
                "type": { "kind": "Builtin", "name": "Int" }
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(3, type.GetMethod("sub")!.Invoke(null, [7, 4]));
    }

    [Fact]
    public void EmitsInt64IntrinsicBackedOperators()
    {
        var int64Type = """{ "kind": "Builtin", "name": "Int64" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:mix",
              "name": "mix",
              "params": [
                { "symbolId": "fn:Demo:mix:param:a", "name": "a", "type": {{int64Type}} },
                { "symbolId": "fn:Demo:mix:param:b", "name": "b", "type": {{int64Type}} }
              ],
              "returnType": {{int64Type}},
              "body": {
                "kind": "Binary",
                "op": "|",
                "left": {
                  "kind": "Binary",
                  "op": "+",
                  "left": { "kind": "Name", "symbolId": "fn:Demo:mix:param:a", "name": "a", "type": {{int64Type}} },
                  "right": { "kind": "Name", "symbolId": "fn:Demo:mix:param:b", "name": "b", "type": {{int64Type}} },
                  "selectedFunctionId": "builtin:trait:moonbitlang/core/builtin:Add:add:Int64",
                  "selectedIntrinsic": "%i64_add",
                  "type": {{int64Type}}
                },
                "right": {
                  "kind": "Binary",
                  "op": "<<",
                  "left": { "kind": "Name", "symbolId": "fn:Demo:mix:param:a", "name": "a", "type": {{int64Type}} },
                  "right": { "kind": "IntLiteral", "value": "1", "type": { "kind": "Builtin", "name": "Int" } },
                  "selectedFunctionId": "builtin:trait:moonbitlang/core/builtin:Shl:shl:Int64",
                  "selectedIntrinsic": "%i64_shl",
                  "type": {{int64Type}}
                },
                "selectedFunctionId": "builtin:trait:moonbitlang/core/builtin:BitOr:lor:Int64",
                "selectedIntrinsic": "%i64_lor",
                "type": {{int64Type}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(15L, type.GetMethod("mix")!.Invoke(null, [5L, 2L]));
    }

    [Fact]
    public void EmitsSelectedUnaryFunctionWhenNoIntrinsicIsPresent()
    {
        var int16Type = """{ "kind": "Builtin", "name": "Int16" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:impl:Neg:Int16:neg",
              "name": "neg",
              "params": [
                { "symbolId": "param:neg:self", "name": "self", "type": {{int16Type}} }
              ],
              "returnType": {{int16Type}},
              "external": { "target": "csharp", "body": "return (short)(-self);" },
              "body": { "kind": "UnitLiteral", "type": { "kind": "Builtin", "name": "Unit" } }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:neg16",
              "name": "neg16",
              "params": [
                { "symbolId": "fn:Demo:neg16:param:a", "name": "a", "type": {{int16Type}} }
              ],
              "returnType": {{int16Type}},
              "body": {
                "kind": "Unary",
                "op": "-",
                "value": { "kind": "Name", "symbolId": "fn:Demo:neg16:param:a", "name": "a", "type": {{int16Type}} },
                "selectedFunctionId": "fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:impl:Neg:Int16:neg",
                "selectedIntrinsic": null,
                "type": {{int16Type}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains(".neg(a)", code, StringComparison.Ordinal);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal((short)-7, type.GetMethod("neg16")!.Invoke(null, [(short)7]));
    }

    [Fact]
    public void EmitsResolvedPrimitiveEqualityWithoutIntrinsic()
    {
        var uint16Type = """{ "kind": "Builtin", "name": "UInt16" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:same",
              "name": "same",
              "params": [
                { "symbolId": "fn:Demo:same:param:a", "name": "a", "type": {{uint16Type}} },
                { "symbolId": "fn:Demo:same:param:b", "name": "b", "type": {{uint16Type}} }
              ],
              "returnType": { "kind": "Builtin", "name": "Bool" },
              "body": {
                "kind": "Binary",
                "op": "==",
                "left": { "kind": "Name", "symbolId": "fn:Demo:same:param:a", "name": "a", "type": {{uint16Type}} },
                "right": { "kind": "Name", "symbolId": "fn:Demo:same:param:b", "name": "b", "type": {{uint16Type}} },
                "selectedFunctionId": "builtin:trait:moonbitlang/core/builtin:Eq:equal:UInt16",
                "selectedIntrinsic": null,
                "type": { "kind": "Builtin", "name": "Bool" }
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("(a == b)", code, StringComparison.Ordinal);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(true, type.GetMethod("same")!.Invoke(null, [(ushort)7, (ushort)7]));
        Assert.Equal(false, type.GetMethod("same")!.Invoke(null, [(ushort)7, (ushort)8]));
    }

    [Fact]
    public void EmitsResolvedStringInequalityWithoutIntrinsic()
    {
        var stringType = """{ "kind": "Builtin", "name": "String" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:different",
              "name": "different",
              "params": [
                { "symbolId": "fn:Demo:different:param:a", "name": "a", "type": {{stringType}} },
                { "symbolId": "fn:Demo:different:param:b", "name": "b", "type": {{stringType}} }
              ],
              "returnType": { "kind": "Builtin", "name": "Bool" },
              "body": {
                "kind": "Binary",
                "op": "!=",
                "left": { "kind": "Name", "symbolId": "fn:Demo:different:param:a", "name": "a", "type": {{stringType}} },
                "right": { "kind": "Name", "symbolId": "fn:Demo:different:param:b", "name": "b", "type": {{stringType}} },
                "selectedFunctionId": "default-trait:type:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Eq:not_equal",
                "selectedIntrinsic": null,
                "type": { "kind": "Builtin", "name": "Bool" }
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("(a != b)", code, StringComparison.Ordinal);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(false, type.GetMethod("different")!.Invoke(null, ["a", "a"]));
        Assert.Equal(true, type.GetMethod("different")!.Invoke(null, ["a", "b"]));
    }

    [Fact]
    public void EmitsResolvedStringViewEqualityWithoutIntrinsic()
    {
        var stringViewType = """{ "kind": "Builtin", "name": "StringView" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:same_view",
              "name": "same_view",
              "params": [
                { "symbolId": "fn:Demo:same_view:param:a", "name": "a", "type": {{stringViewType}} },
                { "symbolId": "fn:Demo:same_view:param:b", "name": "b", "type": {{stringViewType}} }
              ],
              "returnType": { "kind": "Builtin", "name": "Bool" },
              "body": {
                "kind": "Binary",
                "op": "==",
                "left": { "kind": "Name", "symbolId": "fn:Demo:same_view:param:a", "name": "a", "type": {{stringViewType}} },
                "right": { "kind": "Name", "symbolId": "fn:Demo:same_view:param:b", "name": "b", "type": {{stringViewType}} },
                "selectedFunctionId": "builtin:trait:moonbitlang/core/builtin:Eq:equal:StringView",
                "selectedIntrinsic": null,
                "type": { "kind": "Builtin", "name": "Bool" }
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("(a == b)", code, StringComparison.Ordinal);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(
            true,
            type.GetMethod("same_view")!
                .Invoke(
                    null,
                    [new MoonBitStringView("same", 0, 4), new MoonBitStringView("same", 0, 4)]
                )
        );
        Assert.Equal(
            false,
            type.GetMethod("same_view")!
                .Invoke(
                    null,
                    [new MoonBitStringView("same", 0, 4), new MoonBitStringView("same", 0, 3)]
                )
        );
    }

    [Fact]
    public void EmitsPrefixedIntegerLiterals()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:hex",
              "name": "hex",
              "params": [],
              "returnType": {{intType}},
              "body": { "kind": "IntLiteral", "value": "0x21", "type": {{intType}} }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(33, type.GetMethod("hex")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsContextualUInt64LiteralForShiftOperand()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var u64Type = """{ "kind": "Builtin", "name": "UInt64" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:set_bit",
              "name": "set_bit",
              "params": [
                { "symbolId": "param:fn:Demo:set_bit:run_mask", "name": "run_mask", "type": {{u64Type}} },
                { "symbolId": "param:fn:Demo:set_bit:current_run", "name": "current_run", "type": {{intType}} }
              ],
              "returnType": {{u64Type}},
              "body": {
                "kind": "Binary",
                "op": "|",
                "left": { "kind": "Name", "symbolId": "param:fn:Demo:set_bit:run_mask", "name": "run_mask", "type": {{u64Type}} },
                "right": {
                  "kind": "Binary",
                  "op": "<<",
                  "left": { "kind": "IntLiteral", "value": "1", "type": {{u64Type}} },
                  "right": { "kind": "Name", "symbolId": "param:fn:Demo:set_bit:current_run", "name": "current_run", "type": {{intType}} },
                  "selectedFunctionId": "builtin:trait:moonbitlang/core/builtin:Shl:shl:UInt64",
                  "selectedIntrinsic": "%u64.shl",
                  "type": {{u64Type}}
                },
                "selectedFunctionId": "builtin:trait:moonbitlang/core/builtin:BitOr:lor:UInt64",
                "selectedIntrinsic": "%u64.bitor",
                "type": {{u64Type}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("1UL << current_run", code, StringComparison.Ordinal);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(10UL, type.GetMethod("set_bit")!.Invoke(null, [2UL, 3]));
    }

    [Fact]
    public void EmitsBinaryWithStatementLoweredOperand()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:f",
              "name": "f",
              "params": [],
              "returnType": {{intType}},
              "body": {
                "kind": "LocalLet",
                "local": {
                  "symbolId": "local:fn:Demo:f:x",
                  "name": "x",
                  "type": {{intType}},
                  "value": {
                    "kind": "Binary",
                    "op": "+",
                    "left": {
                      "kind": "LocalLet",
                      "local": {
                        "symbolId": "local:fn:Demo:f:y",
                        "name": "y",
                        "type": {{intType}},
                        "value": { "kind": "IntLiteral", "value": "2", "type": {{intType}} }
                      },
                      "body": { "kind": "Name", "symbolId": "local:fn:Demo:f:y", "name": "y", "type": {{intType}} },
                      "type": {{intType}}
                    },
                    "right": { "kind": "IntLiteral", "value": "3", "type": {{intType}} },
                    "selectedFunctionId": "core:Int::op_add",
                    "selectedIntrinsic": "%i32_add",
                    "type": {{intType}}
                  }
                },
                "body": { "kind": "Name", "symbolId": "local:fn:Demo:f:x", "name": "x", "type": {{intType}} },
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(5, type.GetMethod("f")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsOptionEqualityThroughElementEqEvidence()
    {
        var stringType = """{ "kind": "Builtin", "name": "String" }""";
        var optionStringType =
            $$"""{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "Option" }, "args": [{{stringType}}] }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:eq_some",
              "name": "eq_some",
              "params": [],
              "returnType": { "kind": "Builtin", "name": "Bool" },
              "body": {
                "kind": "Binary",
                "op": "==",
                "left": {
                  "kind": "OptionSome",
                  "value": { "kind": "StringLiteral", "value": "a", "type": {{stringType}} },
                  "type": {{optionStringType}}
                },
                "right": {
                  "kind": "OptionSome",
                  "value": { "kind": "StringLiteral", "value": "a", "type": {{stringType}} },
                  "type": {{optionStringType}}
                },
                "selectedFunctionId": "builtin:option:==",
                "selectedIntrinsic": "%option_eq",
                "type": { "kind": "Builtin", "name": "Bool" }
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("MoonBitOptionEq.Equal<string", code);
        Assert.Contains("MoonBitEq.StringEqImpl", code);
        Assert.DoesNotContain("MoonBit2CSharp.GeneratedCore", code);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(true, type.GetMethod("eq_some")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsOptionEqualityForDeclaredDerivedEqElement()
    {
        var markerType = """
            {
              "kind": "Declared",
              "symbol": { "id": "type:pkg:Demo:Demo:Marker", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Marker" },
              "args": []
            }
            """;
        var optionMarkerType =
            $$"""{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "Option" }, "args": [{{markerType}}] }""";
        var json = $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [
                {
                  "kind": "Enum",
                  "symbol": { "id": "type:pkg:Demo:Demo:Marker", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Marker" },
                  "typeParams": [],
                  "variants": [
                    { "id": "type:pkg:Demo:Demo:Marker:variant:Dash", "name": "Dash", "payloads": [] },
                    { "id": "type:pkg:Demo:Demo:Marker:variant:Plus", "name": "Plus", "payloads": [] }
                  ],
                  "derives": ["Eq"]
                }
              ],
              "traits": [],
              "functions": [
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:eq_marker",
                  "name": "eq_marker",
                  "params": [],
                  "returnType": { "kind": "Builtin", "name": "Bool" },
                  "body": {
                    "kind": "Binary",
                    "op": "==",
                    "left": {
                      "kind": "OptionSome",
                      "value": {
                        "kind": "EnumCase",
                        "typeId": "type:pkg:Demo:Demo:Marker",
                        "name": "Dash",
                        "args": [],
                        "type": {{markerType}}
                      },
                      "type": {{optionMarkerType}}
                    },
                    "right": {
                      "kind": "OptionSome",
                      "value": {
                        "kind": "EnumCase",
                        "typeId": "type:pkg:Demo:Demo:Marker",
                        "name": "Dash",
                        "args": [],
                        "type": {{markerType}}
                      },
                      "type": {{optionMarkerType}}
                    },
                    "selectedFunctionId": "builtin:option:==",
                    "selectedIntrinsic": "%option_eq",
                    "type": { "kind": "Builtin", "name": "Bool" }
                  }
                }
              ],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);
        Assert.Contains("MoonBit.Runtime.MoonBitEq.DefaultEqImpl<", code, StringComparison.Ordinal);
        Assert.Contains("Marker>", code, StringComparison.Ordinal);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(true, type.GetMethod("eq_marker")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsCoreHashSupportAndDerivedHashImpl()
    {
        var json = """
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [
                {
                  "kind": "Struct",
                  "symbol": { "id": "type:pkg:Demo:Demo:Point", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Point" },
                  "typeParams": [],
                  "fields": [
                    { "id": "type:pkg:Demo:Demo:Point:field:x", "name": "x", "mutable": false, "type": { "kind": "Builtin", "name": "Int" } }
                  ],
                  "derives": ["Hash"]
                }
              ],
              "traits": [
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
              ],
              "usedTraitImpls": [
                {
                  "trait": { "symbol": { "id": "type:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Hash", "packageId": "pkg:moonbitlang/core/builtin", "modulePath": "moonbitlang/core/builtin", "name": "Hash" }, "args": [] },
                  "selfType": { "kind": "Declared", "symbol": { "id": "type:pkg:Demo:Demo:Point", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Point" }, "args": [] }
                }
              ],
              "functions": [],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);

        Assert.Contains("public interface IHashImpl<T, TImpl>", code, StringComparison.Ordinal);
        Assert.Contains("public sealed class Hasher", code, StringComparison.Ordinal);
        Assert.Contains("public sealed class PointHashImpl", code, StringComparison.Ordinal);
        Compile(code);
    }

    [Fact]
    public void EmitsConstantEnumEquality()
    {
        var relationType = """
            {
              "kind": "Declared",
              "symbol": { "id": "type:pkg:Demo:Demo:Relation", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Relation" },
              "args": []
            }
            """;
        var json = $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [
                {
                  "kind": "Enum",
                  "symbol": { "id": "type:pkg:Demo:Demo:Relation", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Relation" },
                  "typeParams": [],
                  "variants": [
                    { "id": "type:pkg:Demo:Demo:Relation:variant:Smaller", "name": "Smaller", "payloads": [] },
                    { "id": "type:pkg:Demo:Demo:Relation:variant:Greater", "name": "Greater", "payloads": [] }
                  ]
                }
              ],
              "traits": [],
              "functions": [
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:eq",
                  "name": "eq",
                  "params": [
                    { "symbolId": "fn:Demo:eq:param:left", "name": "left", "type": {{relationType}} },
                    { "symbolId": "fn:Demo:eq:param:right", "name": "right", "type": {{relationType}} }
                  ],
                  "returnType": { "kind": "Builtin", "name": "Bool" },
                  "body": {
                    "kind": "Binary",
                    "op": "==",
                    "left": { "kind": "Name", "symbolId": "fn:Demo:eq:param:left", "name": "left", "type": {{relationType}} },
                    "right": { "kind": "Name", "symbolId": "fn:Demo:eq:param:right", "name": "right", "type": {{relationType}} },
                    "selectedFunctionId": "derived:trait:type:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Eq:Relation:equal",
                    "selectedIntrinsic": null,
                    "type": { "kind": "Builtin", "name": "Bool" }
                  }
                }
              ],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);
        Assert.Contains("(left == right)", code);
        var assembly = Compile(code);
        var demo = assembly.GetType("Generated.MoonBit.Demo", true)!;
        var relation = GeneratedType(assembly, "Relation", "Demo");
        var smaller = Enum.Parse(relation, "Smaller");
        var greater = Enum.Parse(relation, "Greater");

        Assert.Equal(true, demo.GetMethod("eq")!.Invoke(null, [smaller, smaller]));
        Assert.Equal(false, demo.GetMethod("eq")!.Invoke(null, [smaller, greater]));
    }

    [Fact]
    public void EmitsPanicAsThrow()
    {
        var json = ModuleJson(
            """
            {
              "kind": "Function",
              "symbolId": "fn:Demo:unreachable",
              "name": "unreachable",
              "params": [],
              "returnType": { "kind": "Builtin", "name": "Int" },
              "body": {
                "kind": "Panic",
                "type": { "kind": "Builtin", "name": "Int" }
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("throw new MoonBitPanic()", code);
        var assembly = Compile(code);
        var demo = assembly.GetType("Generated.MoonBit.Demo", true)!;
        var ex = Assert.Throws<TargetInvocationException>(() =>
            demo.GetMethod("unreachable")!.Invoke(null, [])
        );

        Assert.IsType<MoonBitPanic>(ex.InnerException);
    }

    [Fact]
    public void EmitsFunctionCallsAndArrayShapes()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var arrayIntType =
            """{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "Array" }, "args": [{ "kind": "Builtin", "name": "Int" }] }""";
        var fixedArrayIntType =
            """{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "FixedArray" }, "args": [{ "kind": "Builtin", "name": "Int" }] }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:add",
              "name": "add",
              "params": [
                { "symbolId": "fn:Demo:add:param:a", "name": "a", "type": {{intType}} },
                { "symbolId": "fn:Demo:add:param:b", "name": "b", "type": {{intType}} }
              ],
              "returnType": {{intType}},
              "body": {
                "kind": "Binary",
                "op": "+",
                "left": { "kind": "Name", "symbolId": "fn:Demo:add:param:a", "name": "a", "type": {{intType}} },
                "right": { "kind": "Name", "symbolId": "fn:Demo:add:param:b", "name": "b", "type": {{intType}} },
                "selectedFunctionId": "core:Int::op_add",
                "selectedIntrinsic": "%i32_add",
                "type": {{intType}}
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:call",
              "name": "call",
              "params": [],
              "returnType": {{intType}},
              "body": {
                "kind": "Call",
                "functionId": "fn:Demo:add",
                "args": [
                  { "kind": "IntLiteral", "value": "1", "type": {{intType}} },
                  { "kind": "IntLiteral", "value": "2", "type": {{intType}} }
                ],
                "type": {{intType}}
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:Thing::new",
              "name": "Thing::new",
              "params": [],
              "returnType": {{intType}},
              "body": { "kind": "IntLiteral", "value": "9", "type": {{intType}} }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:call_new",
              "name": "call_new",
              "params": [],
              "returnType": {{intType}},
              "body": {
                "kind": "Call",
                "functionId": "fn:Demo:Thing::new",
                "args": [],
                "type": {{intType}}
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:array",
              "name": "array",
              "params": [],
              "returnType": {{arrayIntType}},
              "body": {
                "kind": "ArrayLiteral",
                "items": [
                  { "kind": "Value", "value": { "kind": "IntLiteral", "value": "1", "type": {{intType}} } },
                  { "kind": "Value", "value": { "kind": "IntLiteral", "value": "2", "type": {{intType}} } }
                ],
                "type": {{arrayIntType}}
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:empty_array",
              "name": "empty_array",
              "params": [],
              "returnType": {{arrayIntType}},
              "body": {
                "kind": "ArrayLiteral",
                "items": [],
                "type": {{arrayIntType}}
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:fixed",
              "name": "fixed",
              "params": [],
              "returnType": {{fixedArrayIntType}},
              "body": {
                "kind": "ArrayLiteral",
                "items": [
                  { "kind": "Value", "value": { "kind": "IntLiteral", "value": "3", "type": {{intType}} } },
                  { "kind": "Value", "value": { "kind": "IntLiteral", "value": "4", "type": {{intType}} } }
                ],
                "type": {{fixedArrayIntType}}
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:empty_fixed",
              "name": "empty_fixed",
              "params": [],
              "returnType": {{fixedArrayIntType}},
              "body": {
                "kind": "ArrayLiteral",
                "items": [],
                "type": {{fixedArrayIntType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("public static int @new()", code, StringComparison.Ordinal);
        Assert.DoesNotContain("Thing__new", code, StringComparison.Ordinal);
        Assert.Contains("Array.Empty<int>()", code, StringComparison.Ordinal);
        Assert.DoesNotContain("new int[] {  }", code, StringComparison.Ordinal);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(3, type.GetMethod("call")!.Invoke(null, []));
        Assert.Equal(9, type.GetMethod("new")!.Invoke(null, []));
        Assert.Equal(9, type.GetMethod("call_new")!.Invoke(null, []));
        var array = type.GetMethod("array")!.Invoke(null, []);
        Assert.Equal(2, (int)array!.GetType().GetField("Length")!.GetValue(array)!);
        var emptyArray = type.GetMethod("empty_array")!.Invoke(null, []);
        Assert.Equal(0, (int)emptyArray!.GetType().GetField("Length")!.GetValue(emptyArray)!);
        var fixedArray = Assert.IsType<int[]>(type.GetMethod("fixed")!.Invoke(null, []));
        Assert.Equal([3, 4], fixedArray);
        var emptyFixedArray = Assert.IsType<int[]>(type.GetMethod("empty_fixed")!.Invoke(null, []));
        Assert.Empty(emptyFixedArray);
    }

    [Fact]
    public void EmitsImportedGenericStructAndGlobalLiteral()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var typeParam = """{ "kind": "TypeParameter", "name": "T", "symbolId": "type-param:T" }""";
        var arrayOfT =
            $$"""{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "Array" }, "args": [{{typeParam}}] }""";
        var arrayOfInt =
            $$"""{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "Array" }, "args": [{{intType}}] }""";
        var declaredMyStruct = $$"""
            {
              "kind": "Declared",
              "symbol": {
                "id": "type:pkg:my/pkg:my/pkg:MyStruct",
                "packageId": "pkg:my/pkg",
                "modulePath": "my/pkg",
                "name": "MyStruct"
              },
              "args": [{{intType}}]
            }
            """;
        var json = $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Main" },
              "symbols": [],
              "types": [
                {
                  "symbol": {
                    "id": "type:pkg:my/pkg:my/pkg:MyStruct",
                    "packageId": "pkg:my/pkg",
                    "modulePath": "my/pkg",
                    "name": "MyStruct"
                  },
                  "typeParams": ["T"],
                  "fields": [
                    {
                      "id": "type:pkg:my/pkg:my/pkg:MyStruct:field:a",
                      "name": "a",
                      "mutable": true,
                      "type": {{arrayOfT}}
                    }
                  ]
                }
              ],
              "traits": [],
              "functions": [],
              "globals": [
                {
                  "kind": "GlobalLet",
                  "symbolId": "global:Main:m",
                  "name": "m",
                  "type": {{declaredMyStruct}},
                  "value": {
                    "kind": "StructLiteral",
                    "typeId": "type:pkg:my/pkg:my/pkg:MyStruct",
                    "fields": [
                      {
                        "name": "a",
                        "value": {
                          "kind": "ArrayLiteral",
                          "items": [
                            { "kind": "Value", "value": { "kind": "IntLiteral", "value": "2", "type": {{intType}} } }
                          ],
                          "type": {{arrayOfInt}}
                        }
                      }
                    ],
                    "type": {{declaredMyStruct}}
                  }
                }
              ],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);
        var assembly = Compile(code);
        var moduleType = assembly.GetType("Generated.MoonBit.Main", true)!;
        var structType = GeneratedType(assembly, "MyStruct`1", "my/pkg");

        var value = moduleType.GetProperty("m")!.GetValue(null);
        Assert.Equal(structType.MakeGenericType(typeof(int)), value!.GetType());
        var array = value.GetType().GetProperty("a")!.GetValue(value);
        Assert.Equal(1, (int)array!.GetType().GetField("Length")!.GetValue(array)!);
    }

    [Fact]
    public void EmitsFunctionTypedStructFields()
    {
        var stringType = """{ "kind": "Builtin", "name": "String" }""";
        var codeBlockInfoType = """
            {
              "kind": "Declared",
              "symbol": {
                "id": "type:pkg:mizchi/markdown:mizchi/markdown:CodeBlockInfo",
                "packageId": "pkg:mizchi/markdown",
                "modulePath": "mizchi/markdown",
                "name": "CodeBlockInfo"
              },
              "args": []
            }
            """;
        var functionType = $$"""
            {
              "kind": "Function",
              "params": [
                { "label": null, "type": {{codeBlockInfoType}}, "optional": false, "hasDefault": false },
                { "label": null, "type": {{stringType}}, "optional": false, "hasDefault": false }
              ],
              "return": {{stringType}},
              "effect": { "kind": "NoRaise" }
            }
            """;
        var optionFunctionType =
            $$"""{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "Option" }, "args": [{{functionType}}] }""";
        var json = $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Main" },
              "symbols": [],
              "types": [
                {
                  "kind": "Struct",
                  "symbol": { "id": "type:pkg:mizchi/markdown:mizchi/markdown:CodeBlockInfo", "packageId": "pkg:mizchi/markdown", "modulePath": "mizchi/markdown", "name": "CodeBlockInfo" },
                  "typeParams": [],
                  "fields": [{ "id": "type:pkg:mizchi/markdown:mizchi/markdown:CodeBlockInfo:field:lang", "name": "lang", "mutable": false, "type": {{stringType}} }]
                },
                {
                  "kind": "Struct",
                  "symbol": { "id": "type:pkg:mizchi/markdown:mizchi/markdown:RenderOptions", "packageId": "pkg:mizchi/markdown", "modulePath": "mizchi/markdown", "name": "RenderOptions" },
                  "typeParams": [],
                  "fields": [{ "id": "type:pkg:mizchi/markdown:mizchi/markdown:RenderOptions:field:code_highlighter", "name": "code_highlighter", "mutable": false, "type": {{optionFunctionType}} }]
                }
              ],
              "traits": [],
              "functions": [],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);

        Assert.Contains(
            "System.Func<CodeBlockInfo, string, string>",
            code,
            StringComparison.Ordinal
        );
        Compile(code);
    }

    [Fact]
    public void EmitsMoonBitCharAsUnicodeCodePointInt()
    {
        var charType = """{ "kind": "Builtin", "name": "Char" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:id_char",
              "name": "id_char",
              "params": [{ "symbolId": "fn:Demo:id_char:param:value", "name": "value", "type": {{charType}} }],
              "returnType": {{charType}},
              "body": { "kind": "Name", "symbolId": "fn:Demo:id_char:param:value", "name": "value", "type": {{charType}} }
            }
            """
        );

        var code = VNextBackend.Emit(json);

        Assert.Contains("public static int id_char(int value)", code, StringComparison.Ordinal);
        Compile(code);
    }

    [Fact]
    public void ResolvesPackageFunctionCallsThroughSymbolIdsWhenDisplayNamesCollide()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:pkg:a:a:make",
              "name": "make",
              "params": [],
              "returnType": {{intType}},
              "body": { "kind": "IntLiteral", "value": "1", "type": {{intType}} }
            },
            {
              "kind": "Function",
              "symbolId": "fn:pkg:b:b:make",
              "name": "make",
              "params": [],
              "returnType": {{intType}},
              "body": { "kind": "IntLiteral", "value": "2", "type": {{intType}} }
            },
            {
              "kind": "Function",
              "symbolId": "fn:pkg:main:main:main",
              "name": "main",
              "params": [],
              "returnType": {{intType}},
              "body": {
                "kind": "Binary",
                "op": "+",
                "left": { "kind": "Call", "functionId": "fn:pkg:a:a:make", "args": [], "type": {{intType}} },
                "right": { "kind": "Call", "functionId": "fn:pkg:b:b:make", "args": [], "type": {{intType}} },
                "selectedFunctionId": "builtin:trait:moonbitlang/core/builtin:Add:add:Int",
                "selectedIntrinsic": "%i32_add",
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        var files = VNextBackend.EmitFiles(json);
        Assert.Contains(files, file => file.RelativePath == "a.g.cs");
        Assert.Contains(files, file => file.RelativePath == "b.g.cs");
        Assert.Contains(files, file => file.RelativePath == "main.g.cs");
        Assert.Contains(
            files,
            file =>
                file.RelativePath == "a.g.cs"
                && file.Code.Contains(
                    "namespace Generated.MoonBit.Packages.a;",
                    StringComparison.Ordinal
                )
        );
        var assembly = Compile(code);
        var type = GeneratedType(assembly, "main_module", "main");

        Assert.Equal(3, type.GetMethod("main")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsFloatConversionsAndLocalLetStructBody()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var floatType = """{ "kind": "Builtin", "name": "Float" }""";
        var stringType = """{ "kind": "Builtin", "name": "String" }""";
        var stringViewType = """{ "kind": "Builtin", "name": "StringView" }""";
        var arrayIntType =
            """{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "Array" }, "args": [{ "kind": "Builtin", "name": "Int" }] }""";
        var arrayViewIntType =
            """{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "ArrayView" }, "args": [{ "kind": "Builtin", "name": "Int" }] }""";
        var myStructType = """
            {
              "kind": "Declared",
              "symbol": { "id": "type:pkg:Demo:Demo:MyStruct", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "MyStruct" },
              "args": []
            }
            """;
        var json = $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [
                {
                  "symbol": { "id": "type:pkg:Demo:Demo:MyStruct", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "MyStruct" },
                  "typeParams": [],
                  "fields": [{ "id": "type:pkg:Demo:Demo:MyStruct:field:val", "name": "val", "mutable": false, "type": {{intType}} }]
                }
              ],
              "functions": [
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:float_id",
                  "name": "float_id",
                  "params": [{ "symbolId": "fn:Demo:float_id:param:f", "name": "f", "type": {{floatType}} }],
                  "returnType": {{floatType}},
                  "body": { "kind": "Name", "symbolId": "fn:Demo:float_id:param:f", "name": "f", "type": {{floatType}} }
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:call_float",
                  "name": "call_float",
                  "params": [],
                  "returnType": {{floatType}},
                  "body": {
                    "kind": "Call",
                    "functionId": "fn:Demo:float_id",
                    "args": [{ "kind": "FloatLiteral", "value": "1.0f", "type": {{floatType}} }],
                    "type": {{floatType}}
                  }
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:view",
                  "name": "view",
                  "params": [{ "symbolId": "fn:Demo:view:param:s", "name": "s", "type": {{stringViewType}} }],
                  "returnType": {{stringViewType}},
                  "body": { "kind": "Name", "symbolId": "fn:Demo:view:param:s", "name": "s", "type": {{stringViewType}} }
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:call_view",
                  "name": "call_view",
                  "params": [],
                  "returnType": {{stringViewType}},
                  "body": {
                    "kind": "Call",
                    "functionId": "fn:Demo:view",
                    "args": [{ "kind": "Conversion", "conversion": "StringToStringView", "value": { "kind": "StringLiteral", "value": "x", "type": {{stringType}} }, "type": {{stringViewType}} }],
                    "type": {{stringViewType}}
                  }
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:array_view",
                  "name": "array_view",
                  "params": [{ "symbolId": "fn:Demo:array_view:param:a", "name": "a", "type": {{arrayViewIntType}} }],
                  "returnType": {{arrayViewIntType}},
                  "body": { "kind": "Name", "symbolId": "fn:Demo:array_view:param:a", "name": "a", "type": {{arrayViewIntType}} }
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:call_array_view",
                  "name": "call_array_view",
                  "params": [],
                  "returnType": {{arrayViewIntType}},
                  "body": {
                    "kind": "Call",
                    "functionId": "fn:Demo:array_view",
                    "args": [{ "kind": "Conversion", "conversion": "ArrayToArrayView", "value": { "kind": "ArrayLiteral", "items": [{ "kind": "Value", "value": { "kind": "IntLiteral", "value": "1", "type": {{intType}} } }], "type": {{arrayIntType}} }, "type": {{arrayViewIntType}} }],
                    "type": {{arrayViewIntType}}
                  }
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:make",
                  "name": "make",
                  "params": [],
                  "returnType": {{myStructType}},
                  "body": {
                    "kind": "LocalLet",
                    "local": {
                      "symbolId": "local:s:1",
                      "name": "s",
                      "type": {{myStructType}},
                      "value": {
                        "kind": "StructLiteral",
                        "typeId": "type:pkg:Demo:Demo:MyStruct",
                        "fields": [{ "name": "val", "value": { "kind": "IntLiteral", "value": "2", "type": {{intType}} } }],
                        "type": {{myStructType}}
                      }
                    },
                    "body": { "kind": "Name", "symbolId": "local:s:1", "name": "s", "type": {{myStructType}} },
                    "type": {{myStructType}}
                  }
                }
              ],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);
        Assert.Contains("1.0f", code);
        Assert.DoesNotContain("1.0f f", code, StringComparison.Ordinal);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(1.0f, type.GetMethod("call_float")!.Invoke(null, []));
        Assert.Equal("x", type.GetMethod("call_view")!.Invoke(null, [])!.ToString());
        Assert.Equal(
            1,
            (int)
                type.GetMethod("call_array_view")!
                    .Invoke(null, [])!
                    .GetType()
                    .GetProperty("Length")!
                    .GetValue(type.GetMethod("call_array_view")!.Invoke(null, []))!
        );
        var value = type.GetMethod("make")!.Invoke(null, []);
        Assert.Equal(2, value!.GetType().GetProperty("val")!.GetValue(value));
    }

    [Fact]
    public void EmitsGenericFunctionsFromVNextTypeParams()
    {
        var typeParam = """{ "kind": "TypeParameter", "name": "T", "symbolId": "type-param:T" }""";
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:id",
              "name": "id",
              "typeParams": ["T"],
              "params": [{ "symbolId": "fn:Demo:id:param:x", "name": "x", "type": {{typeParam}} }],
              "returnType": {{typeParam}},
              "body": { "kind": "Name", "symbolId": "fn:Demo:id:param:x", "name": "x", "type": {{typeParam}} }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:call_int",
              "name": "call_int",
              "typeParams": [],
              "params": [],
              "returnType": {{intType}},
              "body": {
                "kind": "Call",
                "functionId": "fn:Demo:id",
                "args": [{ "kind": "IntLiteral", "value": "42", "type": {{intType}} }],
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("static T id<T>(T x)", code);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(42, type.GetMethod("call_int")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsRangeForLoopStatements()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        var counterType = """
            {
              "kind": "Declared",
              "symbol": { "id": "type:pkg:Demo:Demo:Counter", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Counter" },
              "args": []
            }
            """;
        var counterName =
            $$"""{ "kind": "Name", "symbolId": "local:fn:Demo:sum:counter", "name": "counter", "type": {{counterType}} }""";
        var indexName =
            $$"""{ "kind": "Name", "symbolId": "local:fn:Demo:sum:i", "name": "i", "type": {{intType}} }""";
        var counterValField = $$"""
            {
              "ownerTypeId": "type:pkg:Demo:Demo:Counter",
              "fieldId": "type:pkg:Demo:Demo:Counter:field:val",
              "name": "val",
              "mutable": true,
              "type": {{intType}}
            }
            """;
        var counterVal =
            $$"""{ "kind": "FieldAccess", "target": {{counterName}}, "field": {{counterValField}}, "type": {{intType}} }""";
        var json = $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [
                {
                  "kind": "Struct",
                  "symbol": { "id": "type:pkg:Demo:Demo:Counter", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Counter" },
                  "typeParams": [],
                  "fields": [
                    {
                      "id": "type:pkg:Demo:Demo:Counter:field:val",
                      "name": "val",
                      "mutable": true,
                      "type": {{intType}}
                    }
                  ]
                }
              ],
              "traits": [],
              "functions": [
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:sum",
                  "name": "sum",
                  "typeParams": [],
                  "params": [],
                  "returnType": {{intType}},
                  "body": {
                    "kind": "LocalLet",
                    "local": {
                      "symbolId": "local:fn:Demo:sum:counter",
                      "name": "counter",
                      "type": {{counterType}},
                      "value": {
                        "kind": "StructLiteral",
                        "typeId": "type:pkg:Demo:Demo:Counter",
                        "fields": [
                          { "name": "val", "value": { "kind": "IntLiteral", "value": "0", "type": {{intType}} } }
                        ],
                        "type": {{counterType}}
                      }
                    },
                    "body": {
                      "kind": "Sequence",
                      "first": {
                        "kind": "ForRange",
                        "symbolId": "local:fn:Demo:sum:i",
                        "name": "i",
                        "start": { "kind": "IntLiteral", "value": "0", "type": {{intType}} },
                        "end": { "kind": "IntLiteral", "value": "4", "type": {{intType}} },
                        "inclusive": false,
                        "reverse": false,
                        "excludeStart": false,
                        "body": {
                          "kind": "FieldAssign",
                          "target": {{counterName}},
                          "field": {{counterValField}},
                          "value": {
                            "kind": "Binary",
                            "op": "+",
                            "left": {{counterVal}},
                            "right": {{indexName}},
                            "selectedFunctionId": "core:Int::op_add",
                            "selectedIntrinsic": "%i32_add",
                            "type": {{intType}}
                          },
                          "type": {{unitType}}
                        },
                        "type": {{unitType}}
                      },
                      "body": {{counterVal}},
                      "type": {{intType}}
                    },
                    "type": {{intType}}
                  }
                }
              ],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);
        Assert.Contains("for (int i = 0; i < 4; i++)", code);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(6, type.GetMethod("sum")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsWhileStatements()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var boolType = """{ "kind": "Builtin", "name": "Bool" }""";
        var unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        var iName =
            $$"""{ "kind": "Name", "symbolId": "local:fn:Demo:count:i", "name": "i", "type": {{intType}} }""";
        var increment = $$"""
            {
              "kind": "Assign",
              "symbolId": "local:fn:Demo:count:i",
              "name": "i",
              "value": {
                "kind": "Binary",
                "op": "+",
                "left": {{iName}},
                "right": { "kind": "IntLiteral", "value": "1", "type": {{intType}} },
                "selectedFunctionId": "core:Int::op_add",
                "selectedIntrinsic": "%i32_add",
                "type": {{intType}}
              },
              "type": {{unitType}}
            }
            """;
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:count",
              "name": "count",
              "params": [],
              "returnType": {{intType}},
              "body": {
                "kind": "LocalLet",
                "local": {
                  "symbolId": "local:fn:Demo:count:i",
                  "name": "i",
                  "type": {{intType}},
                  "value": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                },
                "body": {
                  "kind": "Sequence",
                  "first": {
                    "kind": "While",
                    "condition": {
                      "kind": "Binary",
                      "op": "&&",
                      "left": {
                        "kind": "Binary",
                        "op": "<",
                        "left": {{iName}},
                        "right": { "kind": "IntLiteral", "value": "3", "type": {{intType}} },
                        "selectedFunctionId": "builtin:trait:moonbitlang/core/builtin:Compare:op_lt:Int",
                        "selectedIntrinsic": "%i32.lt",
                        "type": {{boolType}}
                      },
                      "right": {
                        "kind": "Unary",
                        "op": "!",
                        "value": { "kind": "BoolLiteral", "value": false, "type": {{boolType}} },
                        "selectedFunctionId": "",
                        "selectedIntrinsic": "%bool_not",
                        "type": {{boolType}}
                      },
                      "type": {{boolType}}
                    },
                    "body": {{increment}},
                    "type": {{unitType}}
                  },
                  "body": {{iName}},
                  "type": {{intType}}
                },
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Contains("while", code, StringComparison.Ordinal);
        Assert.Equal(3, type.GetMethod("count")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsCStyleForLoopBreakContinueAndLocalUpdates()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        var counterType = """
            {
              "kind": "Declared",
              "symbol": { "id": "type:pkg:Demo:Demo:Counter", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Counter" },
              "args": []
            }
            """;
        var counterName =
            $$"""{ "kind": "Name", "symbolId": "local:fn:Demo:loop:counter", "name": "counter", "type": {{counterType}} }""";
        var indexName =
            $$"""{ "kind": "Name", "symbolId": "local:fn:Demo:loop:i", "name": "i", "type": {{intType}} }""";
        var counterValField = $$"""
            {
              "ownerTypeId": "type:pkg:Demo:Demo:Counter",
              "fieldId": "type:pkg:Demo:Demo:Counter:field:val",
              "name": "val",
              "mutable": true,
              "type": {{intType}}
            }
            """;
        var counterVal =
            $$"""{ "kind": "FieldAccess", "target": {{counterName}}, "field": {{counterValField}}, "type": {{intType}} }""";
        var update = $$"""
            {
              "kind": "Assign",
              "symbolId": "local:fn:Demo:loop:i",
              "name": "i",
              "value": {
                "kind": "Binary",
                "op": "+",
                "left": {{indexName}},
                "right": { "kind": "IntLiteral", "value": "1", "type": {{intType}} },
                "selectedFunctionId": "core:Int::op_add",
                "selectedIntrinsic": "%i32_add",
                "type": {{intType}}
              },
              "type": {{unitType}}
            }
            """;
        var addIndexToCounter = $$"""
            {
              "kind": "FieldAssign",
              "target": {{counterName}},
              "field": {{counterValField}},
              "value": {
                "kind": "Binary",
                "op": "+",
                "left": {{counterVal}},
                "right": {{indexName}},
                "selectedFunctionId": "core:Int::op_add",
                "selectedIntrinsic": "%i32_add",
                "type": {{intType}}
              },
              "type": {{unitType}}
            }
            """;
        var json = $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [
                {
                  "kind": "Struct",
                  "symbol": { "id": "type:pkg:Demo:Demo:Counter", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Counter" },
                  "typeParams": [],
                  "fields": [
                    {
                      "id": "type:pkg:Demo:Demo:Counter:field:val",
                      "name": "val",
                      "mutable": true,
                      "type": {{intType}}
                    }
                  ]
                }
              ],
              "traits": [],
              "functions": [
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:loop",
                  "name": "loop",
                  "typeParams": [],
                  "params": [],
                  "returnType": {{intType}},
                  "body": {
                    "kind": "LocalLet",
                    "local": {
                      "symbolId": "local:fn:Demo:loop:counter",
                      "name": "counter",
                      "type": {{counterType}},
                      "value": {
                        "kind": "StructLiteral",
                        "typeId": "type:pkg:Demo:Demo:Counter",
                        "fields": [
                          { "name": "val", "value": { "kind": "IntLiteral", "value": "0", "type": {{intType}} } }
                        ],
                        "type": {{counterType}}
                      }
                    },
                    "body": {
                      "kind": "Sequence",
                      "first": {
                        "kind": "ForLoop",
                        "bindings": [
                          {
                            "symbolId": "local:fn:Demo:loop:i",
                            "name": "i",
                            "type": {{intType}},
                            "value": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                          }
                        ],
                        "condition": {
                          "kind": "Binary",
                          "op": "<",
                          "left": {{indexName}},
                          "right": { "kind": "IntLiteral", "value": "4", "type": {{intType}} },
                          "selectedFunctionId": "core:Int::op_lt",
                          "selectedIntrinsic": "%i32.lt",
                          "type": { "kind": "Builtin", "name": "Bool" }
                        },
                        "updates": [{{update}}],
                        "body": {
                          "kind": "Sequence",
                          "first": {{addIndexToCounter}},
                          "body": { "kind": "Break", "type": {{unitType}} },
                          "type": {{unitType}}
                        },
                        "type": {{unitType}}
                      },
                      "body": {{counterVal}},
                      "type": {{intType}}
                    },
                    "type": {{intType}}
                  }
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:skip",
                  "name": "skip",
                  "typeParams": [],
                  "params": [],
                  "returnType": {{unitType}},
                  "body": {
                    "kind": "ForLoop",
                    "bindings": [
                      {
                        "symbolId": "local:fn:Demo:skip:i",
                        "name": "i",
                        "type": {{intType}},
                        "value": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                      }
                    ],
                    "condition": {
                      "kind": "Binary",
                      "op": "<",
                      "left": { "kind": "Name", "symbolId": "local:fn:Demo:skip:i", "name": "i", "type": {{intType}} },
                      "right": { "kind": "IntLiteral", "value": "1", "type": {{intType}} },
                      "selectedFunctionId": "core:Int::op_lt",
                      "selectedIntrinsic": "%i32.lt",
                      "type": { "kind": "Builtin", "name": "Bool" }
                    },
                    "updates": [{{update.Replace("local:fn:Demo:loop:i", "local:fn:Demo:skip:i")}}],
                    "body": { "kind": "Continue", "type": {{unitType}} },
                    "type": {{unitType}}
                  }
                }
              ],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);
        Assert.Contains("while", code);
        Assert.Contains("break;", code);
        Assert.Contains("continue;", code);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(0, type.GetMethod("loop")!.Invoke(null, []));
        type.GetMethod("skip")!.Invoke(null, []);
    }

    [Fact]
    public void EmitsStatementIfWithLoopControlBranches()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var boolType = """{ "kind": "Builtin", "name": "Bool" }""";
        var unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:f",
              "name": "f",
              "typeParams": [],
              "params": [],
              "returnType": {{unitType}},
              "body": {
                "kind": "ForRange",
                "name": "i",
                "symbolId": "local:fn:Demo:f:i",
                "start": { "kind": "IntLiteral", "value": "0", "type": {{intType}} },
                "end": { "kind": "IntLiteral", "value": "3", "type": {{intType}} },
                "inclusive": false,
                "reverse": false,
                "excludeStart": false,
                "body": {
                  "kind": "If",
                  "condition": { "kind": "BoolLiteral", "value": true, "type": {{boolType}} },
                  "then": { "kind": "Break", "type": {{unitType}} },
                  "else": { "kind": "Continue", "type": {{unitType}} },
                  "type": {{unitType}}
                },
                "type": {{unitType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("if (true)", code, StringComparison.Ordinal);
        Assert.Contains("break;", code, StringComparison.Ordinal);
        Assert.Contains("continue;", code, StringComparison.Ordinal);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        type.GetMethod("f")!.Invoke(null, []);
    }

    [Fact]
    public void EmitsStatementMatchWithReturnArms()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var boolType = """{ "kind": "Builtin", "name": "Bool" }""";
        var unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:f",
              "name": "f",
              "typeParams": [],
              "params": [],
              "returnType": {{intType}},
              "body": {
                "kind": "Sequence",
                "first": {
                  "kind": "Match",
                  "target": { "kind": "BoolLiteral", "value": true, "type": {{boolType}} },
                  "arms": [
                    {
                      "pattern": { "kind": "BoolLiteral", "value": true },
                      "body": {
                        "kind": "Return",
                        "value": { "kind": "IntLiteral", "value": "1", "type": {{intType}} },
                        "type": {{unitType}}
                      }
                    },
                    {
                      "pattern": { "kind": "Wildcard" },
                      "body": {
                        "kind": "Return",
                        "value": { "kind": "IntLiteral", "value": "2", "type": {{intType}} },
                        "type": {{unitType}}
                      }
                    }
                  ],
                  "type": {{unitType}}
                },
                "body": { "kind": "IntLiteral", "value": "3", "type": {{intType}} },
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.DoesNotContain("__moonbitMatched", code, StringComparison.Ordinal);
        Assert.Contains("else", code, StringComparison.Ordinal);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(1, type.GetMethod("f")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsAssignmentMatchWithReturnArm()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var boolType = """{ "kind": "Builtin", "name": "Bool" }""";
        var unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:f",
              "name": "f",
              "typeParams": [],
              "params": [],
              "returnType": {{intType}},
              "body": {
                "kind": "LocalLet",
                "local": {
                  "symbolId": "local:fn:Demo:f:x",
                  "name": "x",
                  "type": {{intType}},
                  "value": {
                    "kind": "Match",
                    "target": { "kind": "BoolLiteral", "value": true, "type": {{boolType}} },
                    "arms": [
                      {
                        "pattern": { "kind": "BoolLiteral", "value": true },
                        "body": {
                          "kind": "Return",
                          "value": { "kind": "IntLiteral", "value": "7", "type": {{intType}} },
                          "type": {{unitType}}
                        }
                      },
                      {
                        "pattern": { "kind": "Wildcard" },
                        "body": { "kind": "IntLiteral", "value": "9", "type": {{intType}} }
                      }
                    ],
                    "type": {{intType}}
                  }
                },
                "body": {
                  "kind": "Name",
                  "symbolId": "local:fn:Demo:f:x",
                  "name": "x",
                  "type": {{intType}}
                },
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(7, type.GetMethod("f")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsLoopBodyMatchWithReturnArm()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var boolType = """{ "kind": "Builtin", "name": "Bool" }""";
        var unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:f",
              "name": "f",
              "typeParams": [],
              "params": [],
              "returnType": {{intType}},
              "body": {
                "kind": "Sequence",
                "first": {
                  "kind": "ForLoop",
                  "bindings": [],
                  "condition": { "kind": "BoolLiteral", "value": true, "type": {{boolType}} },
                  "updates": [],
                  "body": {
                    "kind": "Match",
                    "target": { "kind": "BoolLiteral", "value": true, "type": {{boolType}} },
                    "arms": [
                      {
                        "pattern": { "kind": "BoolLiteral", "value": true },
                        "body": {
                          "kind": "Return",
                          "value": { "kind": "IntLiteral", "value": "5", "type": {{intType}} },
                          "type": {{unitType}}
                        }
                      },
                      {
                        "pattern": { "kind": "Wildcard" },
                        "body": { "kind": "UnitLiteral", "type": {{unitType}} }
                      }
                    ],
                    "type": {{unitType}}
                  },
                  "type": {{unitType}}
                },
                "body": { "kind": "IntLiteral", "value": "0", "type": {{intType}} },
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(5, type.GetMethod("f")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsEmptyLoopBodiesWithoutInvalidUnitStatements()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var boolType = """{ "kind": "Builtin", "name": "Bool" }""";
        var unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        var loopIndex =
            $$"""{ "kind": "Name", "symbolId": "local:fn:Demo:f:i", "name": "i", "type": {{intType}} }""";
        var update = $$"""
            {
              "kind": "Assign",
              "symbolId": "local:fn:Demo:f:i",
              "name": "i",
              "value": {
                "kind": "Binary",
                "op": "+",
                "left": {{loopIndex}},
                "right": { "kind": "IntLiteral", "value": "1", "type": {{intType}} },
                "selectedFunctionId": "core:Int::op_add",
                "selectedIntrinsic": "%i32_add",
                "type": {{intType}}
              },
              "type": {{unitType}}
            }
            """;
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:f",
              "name": "f",
              "typeParams": [],
              "params": [],
              "returnType": {{unitType}},
              "body": {
                "kind": "Sequence",
                "first": {
                  "kind": "ForRange",
                  "symbolId": "local:fn:Demo:f:range_i",
                  "name": "range_i",
                  "start": { "kind": "IntLiteral", "value": "0", "type": {{intType}} },
                  "end": { "kind": "IntLiteral", "value": "10", "type": {{intType}} },
                  "inclusive": false,
                  "reverse": false,
                  "excludeStart": false,
                  "body": { "kind": "UnitLiteral", "type": {{unitType}} },
                  "type": {{unitType}}
                },
                "body": {
                  "kind": "ForLoop",
                  "bindings": [
                    {
                      "symbolId": "local:fn:Demo:f:i",
                      "name": "i",
                      "type": {{intType}},
                      "value": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                    }
                  ],
                  "condition": {
                    "kind": "Binary",
                    "op": "<",
                    "left": {{loopIndex}},
                    "right": { "kind": "IntLiteral", "value": "10", "type": {{intType}} },
                    "selectedFunctionId": "core:Int::op_lt",
                    "selectedIntrinsic": "%i32.lt",
                    "type": {{boolType}}
                  },
                  "updates": [{{update}}],
                  "body": { "kind": "UnitLiteral", "type": {{unitType}} },
                  "type": {{unitType}}
                },
                "type": {{unitType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);

        Assert.DoesNotContain(
            "\n            MoonBitUnit.Value;",
            code.Replace("\r\n", "\n", StringComparison.Ordinal)
        );
        Compile(code);
    }

    [Fact]
    public void EmitsMapLiteralThroughLocalMapConstructor()
    {
        var stringType = """{ "kind": "Builtin", "name": "String" }""";
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var mapType =
            $$"""{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "Map" }, "args": [{{stringType}}, {{intType}}] }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:literal",
              "name": "literal",
              "typeParams": [],
              "params": [],
              "returnType": {{mapType}},
              "body": {
                "kind": "MapLiteral",
                "entries": [
                  {
                    "key": { "kind": "StringLiteral", "value": "a", "type": {{stringType}} },
                    "value": { "kind": "IntLiteral", "value": "2", "type": {{intType}} }
                  },
                  {
                    "key": { "kind": "StringLiteral", "value": "b", "type": {{stringType}} },
                    "value": { "kind": "IntLiteral", "value": "3", "type": {{intType}} }
                  }
                ],
                "type": {{mapType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);

        Assert.DoesNotContain("MoonBit2CSharp.GeneratedCore", code, StringComparison.Ordinal);
        Assert.Contains(
            "new global::Generated.MoonBit.Packages.moonbitlang.core.builtin.Map<string, int>",
            code,
            StringComparison.Ordinal
        );
    }

    [Fact]
    public void EmitsBoolAndUnitLiterals()
    {
        var boolType = """{ "kind": "Builtin", "name": "Bool" }""";
        var unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:yes",
              "name": "yes",
              "typeParams": [],
              "params": [],
              "returnType": {{boolType}},
              "body": { "kind": "BoolLiteral", "value": true, "type": {{boolType}} }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:unit",
              "name": "unit",
              "typeParams": [],
              "params": [],
              "returnType": {{unitType}},
              "body": { "kind": "UnitLiteral", "type": {{unitType}} }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(true, type.GetMethod("yes")!.Invoke(null, []));
        Assert.NotNull(type.GetMethod("unit")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsOptionExpressionsAndOptionalParameterDefaults()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var optionIntType =
            $$"""{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "Option" }, "args": [{{intType}}] }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:some",
              "name": "some",
              "typeParams": [],
              "params": [],
              "returnType": {{optionIntType}},
              "body": {
                "kind": "OptionSome",
                "value": { "kind": "IntLiteral", "value": "1", "type": {{intType}} },
                "type": {{optionIntType}}
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:none",
              "name": "none",
              "typeParams": [],
              "params": [],
              "returnType": {{optionIntType}},
              "body": { "kind": "OptionNone", "type": {{optionIntType}} }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:question",
              "name": "question",
              "typeParams": [],
              "params": [
                {
                  "symbolId": "fn:Demo:question:param:a",
                  "name": "a",
                  "label": "a",
                  "optional": true,
                  "hasDefault": false,
                  "type": {{optionIntType}}
                }
              ],
              "returnType": {{optionIntType}},
              "body": {
                "kind": "Name",
                "symbolId": "fn:Demo:question:param:a",
                "name": "a",
                "type": {{optionIntType}}
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:call_question",
              "name": "call_question",
              "typeParams": [],
              "params": [],
              "returnType": {{optionIntType}},
              "body": {
                "kind": "Call",
                "functionId": "fn:Demo:question",
                "args": [{ "kind": "OptionNone", "type": {{optionIntType}} }],
                "type": {{optionIntType}}
              }
            }
            ,
            {
              "kind": "Function",
              "symbolId": "fn:Demo:call_question_given",
              "name": "call_question_given",
              "typeParams": [],
              "params": [],
              "returnType": {{optionIntType}},
              "body": {
                "kind": "Call",
                "functionId": "fn:Demo:question",
                "args": [
                  {
                    "kind": "OptionSome",
                    "value": { "kind": "IntLiteral", "value": "2", "type": {{intType}} },
                    "type": {{optionIntType}}
                  }
                ],
                "type": {{optionIntType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("MoonBitOption<int>.Some(1)", code);
        Assert.Contains("MoonBitOption<int>.None()", code);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        var some = type.GetMethod("some")!.Invoke(null, [])!;
        Assert.True((bool)some.GetType().GetProperty("IsSome")!.GetValue(some)!);
        Assert.Equal(1, some.GetType().GetProperty("Value")!.GetValue(some));
        Assert.Equal("None", type.GetMethod("none")!.Invoke(null, [])!.ToString());
        Assert.Equal("None", type.GetMethod("call_question")!.Invoke(null, [])!.ToString());
        var supplied = type.GetMethod("call_question_given")!.Invoke(null, [])!;
        Assert.True((bool)supplied.GetType().GetProperty("IsSome")!.GetValue(supplied)!);
        Assert.Equal(2, supplied.GetType().GetProperty("Value")!.GetValue(supplied));
    }

    [Fact]
    public void EmitsMutableFieldAssignmentAndCallSiteDefaults()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        var counterType = """
            {
              "kind": "Declared",
              "symbol": {
                "id": "type:pkg:Demo:Demo:Counter",
                "packageId": "pkg:Demo",
                "modulePath": "Demo",
                "name": "Counter"
              },
              "args": []
            }
            """;
        var counterLiteral = $$"""
            {
              "kind": "StructLiteral",
              "typeId": "type:pkg:Demo:Demo:Counter",
              "fields": [
                { "name": "val", "value": { "kind": "IntLiteral", "value": "0", "type": {{intType}} } }
              ],
              "type": {{counterType}}
            }
            """;
        var counterName =
            $$"""{ "kind": "Name", "symbolId": "fn:Demo:incr:param:counter", "name": "counter", "type": {{counterType}} }""";
        var counterValField = $$"""
            {
              "ownerTypeId": "type:pkg:Demo:Demo:Counter",
              "fieldId": "type:pkg:Demo:Demo:Counter:field:val",
              "name": "val",
              "mutable": true,
              "type": {{intType}}
            }
            """;
        var counterVal =
            $$"""{ "kind": "FieldAccess", "target": {{counterName}}, "field": {{counterValField}}, "type": {{intType}} }""";
        var json = $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [
                {
                  "symbol": {
                    "id": "type:pkg:Demo:Demo:Counter",
                    "packageId": "pkg:Demo",
                    "modulePath": "Demo",
                    "name": "Counter"
                  },
                  "typeParams": [],
                  "fields": [
                    {
                      "id": "type:pkg:Demo:Demo:Counter:field:val",
                      "name": "val",
                      "mutable": true,
                      "type": {{intType}}
                    }
                  ]
                }
              ],
              "functions": [
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:incr",
                  "name": "incr",
                  "typeParams": [],
                  "params": [
                    {
                      "symbolId": "fn:Demo:incr:param:counter",
                      "name": "counter",
                      "label": "counter",
                      "optional": true,
                      "hasDefault": true,
                      "type": {{counterType}}
                    }
                  ],
                  "returnType": {{intType}},
                  "body": {
                    "kind": "Sequence",
                    "first": {
                      "kind": "FieldAssign",
                      "target": {{counterName}},
                      "field": {{counterValField}},
                      "value": {
                        "kind": "Binary",
                        "op": "+",
                        "left": {{counterVal}},
                        "right": { "kind": "IntLiteral", "value": "1", "type": {{intType}} },
                        "selectedFunctionId": "core:Int::op_add",
                        "selectedIntrinsic": "%i32_add",
                        "type": {{intType}}
                      },
                      "type": {{unitType}}
                    },
                    "body": {{counterVal}},
                    "type": {{intType}}
                  }
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:call_default",
                  "name": "call_default",
                  "typeParams": [],
                  "params": [],
                  "returnType": {{intType}},
                  "body": {
                    "kind": "Call",
                    "functionId": "fn:Demo:incr",
                    "args": [{{counterLiteral}}],
                    "type": {{intType}}
                  }
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:call_given",
                  "name": "call_given",
                  "typeParams": [],
                  "params": [],
                  "returnType": {{intType}},
                  "body": {
                    "kind": "LocalLet",
                    "local": {
                      "symbolId": "local:counter:1",
                      "name": "counter",
                      "type": {{counterType}},
                      "value": {{counterLiteral}}
                    },
                    "body": {
                      "kind": "Call",
                      "functionId": "fn:Demo:incr",
                      "args": [
                        { "kind": "Name", "symbolId": "local:counter:1", "name": "counter", "type": {{counterType}} }
                      ],
                      "type": {{intType}}
                    },
                    "type": {{intType}}
                  }
                }
              ],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);
        Assert.Contains("counter.val = (counter.val + 1);", code);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(1, type.GetMethod("call_default")!.Invoke(null, []));
        Assert.Equal(1, type.GetMethod("call_default")!.Invoke(null, []));
        Assert.Equal(1, type.GetMethod("call_given")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsGenericMutableStructDefaultsWithAliasSemantics()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        var typeParam = """{ "kind": "TypeParameter", "name": "T", "symbolId": "type-param:T" }""";
        var refIntType = """
            {
              "kind": "Declared",
              "symbol": {
                "id": "type:pkg:Demo:Demo:Ref",
                "packageId": "pkg:Demo",
                "modulePath": "Demo",
                "name": "Ref"
              },
              "args": [{ "kind": "Builtin", "name": "Int" }]
            }
            """;
        var refLiteral = $$"""
            {
              "kind": "StructLiteral",
              "typeId": "type:pkg:Demo:Demo:Ref",
              "fields": [
                { "name": "val", "value": { "kind": "IntLiteral", "value": "0", "type": {{intType}} } }
              ],
              "type": {{refIntType}}
            }
            """;
        var counterName =
            $$"""{ "kind": "Name", "symbolId": "fn:Demo:incr:param:counter", "name": "counter", "type": {{refIntType}} }""";
        var refIntValField = $$"""
            {
              "ownerTypeId": "type:pkg:Demo:Demo:Ref",
              "fieldId": "type:pkg:Demo:Demo:Ref:field:val",
              "name": "val",
              "mutable": true,
              "type": {{intType}}
            }
            """;
        var counterVal =
            $$"""{ "kind": "FieldAccess", "target": {{counterName}}, "field": {{refIntValField}}, "type": {{intType}} }""";
        var counter2Name =
            $$"""{ "kind": "Name", "symbolId": "fn:Demo:incr_2:param:counter", "name": "counter", "type": {{refIntType}} }""";
        var counter2Val =
            $$"""{ "kind": "FieldAccess", "target": {{counter2Name}}, "field": {{refIntValField}}, "type": {{intType}} }""";
        var incrementBody = $$"""
            {
              "kind": "Sequence",
              "first": {
                "kind": "FieldAssign",
                "target": {{counterName}},
                "field": {{refIntValField}},
                "value": {
                  "kind": "Binary",
                  "op": "+",
                  "left": {{counterVal}},
                  "right": { "kind": "IntLiteral", "value": "1", "type": {{intType}} },
                  "selectedFunctionId": "core:Int::op_add",
                  "selectedIntrinsic": "%i32_add",
                  "type": {{intType}}
                },
                "type": {{unitType}}
              },
              "body": {{counterName}},
              "type": {{refIntType}}
            }
            """;
        var increment2Body = $$"""
            {
              "kind": "Sequence",
              "first": {
                "kind": "FieldAssign",
                "target": {{counter2Name}},
                "field": {{refIntValField}},
                "value": {
                  "kind": "Binary",
                  "op": "+",
                  "left": {{counter2Val}},
                  "right": { "kind": "IntLiteral", "value": "1", "type": {{intType}} },
                  "selectedFunctionId": "core:Int::op_add",
                  "selectedIntrinsic": "%i32_add",
                  "type": {{intType}}
                },
                "type": {{unitType}}
              },
              "body": {{counter2Val}},
              "type": {{intType}}
            }
            """;
        var json = $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [
                {
                  "symbol": {
                    "id": "type:pkg:Demo:Demo:Ref",
                    "packageId": "pkg:Demo",
                    "modulePath": "Demo",
                    "name": "Ref"
                  },
                  "typeParams": ["T"],
                  "fields": [
                    {
                      "id": "type:pkg:Demo:Demo:Ref:field:val",
                      "name": "val",
                      "mutable": true,
                      "type": {{typeParam}}
                    }
                  ]
                }
              ],
              "functions": [
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:incr",
                  "name": "incr",
                  "typeParams": [],
                  "params": [
                    {
                      "symbolId": "fn:Demo:incr:param:counter",
                      "name": "counter",
                      "label": "counter",
                      "optional": true,
                      "hasDefault": true,
                      "type": {{refIntType}}
                    }
                  ],
                  "returnType": {{refIntType}},
                  "body": {{incrementBody}}
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:incr_2",
                  "name": "incr_2",
                  "typeParams": [],
                  "params": [
                    {
                      "symbolId": "fn:Demo:incr_2:param:counter",
                      "name": "counter",
                      "label": "counter",
                      "optional": true,
                      "hasDefault": true,
                      "type": {{refIntType}}
                    }
                  ],
                  "returnType": {{intType}},
                  "body": {{increment2Body}}
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:call_default",
                  "name": "call_default",
                  "typeParams": [],
                  "params": [],
                  "returnType": {{intType}},
                  "body": {
                    "kind": "FieldAccess",
                    "target": {
                      "kind": "Call",
                      "functionId": "fn:Demo:incr",
                      "args": [{{refLiteral}}],
                      "type": {{refIntType}}
                    },
                    "field": {{refIntValField}},
                    "type": {{intType}}
                  }
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:call_global_default",
                  "name": "call_global_default",
                  "typeParams": [],
                  "params": [],
                  "returnType": {{intType}},
                  "body": {
                    "kind": "Call",
                    "functionId": "fn:Demo:incr_2",
                    "args": [
                      {
                        "kind": "Name",
                        "symbolId": "global:Demo:default_counter",
                        "name": "default_counter",
                        "type": {{refIntType}}
                      }
                    ],
                    "type": {{intType}}
                  }
                }
              ],
              "globals": [
                {
                  "kind": "GlobalLet",
                  "symbolId": "global:Demo:default_counter",
                  "name": "default_counter",
                  "type": {{refIntType}},
                  "value": {{refLiteral}}
                }
              ],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(1, type.GetMethod("call_default")!.Invoke(null, []));
        Assert.Equal(1, type.GetMethod("call_default")!.Invoke(null, []));
        Assert.Equal(1, type.GetMethod("call_global_default")!.Invoke(null, []));
        Assert.Equal(2, type.GetMethod("call_global_default")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsEnumCases()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var relationType = """
            {
              "kind": "Declared",
              "symbol": { "id": "type:pkg:Demo:Demo:Relation", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Relation" },
              "args": []
            }
            """;
        var lstType = """
            {
              "kind": "Declared",
              "symbol": { "id": "type:pkg:Demo:Demo:Lst", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Lst" },
              "args": []
            }
            """;
        var json = $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [
                {
                  "kind": "Enum",
                  "symbol": { "id": "type:pkg:Demo:Demo:Relation", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Relation" },
                  "typeParams": [],
                  "variants": [
                    { "id": "type:pkg:Demo:Demo:Relation:variant:Smaller", "name": "Smaller", "payloads": [] },
                    { "id": "type:pkg:Demo:Demo:Relation:variant:Greater", "name": "Greater", "payloads": [] }
                  ]
                },
                {
                  "kind": "Enum",
                  "symbol": { "id": "type:pkg:Demo:Demo:Lst", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Lst" },
                  "typeParams": [],
                  "variants": [
                    { "id": "type:pkg:Demo:Demo:Lst:variant:Nil", "name": "Nil", "payloads": [] },
                    { "id": "type:pkg:Demo:Demo:Lst:variant:Cons", "name": "Cons", "payloads": [{{intType}}, {{lstType}}] }
                  ]
                }
              ],
              "functions": [
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:smaller",
                  "name": "smaller",
                  "typeParams": [],
                  "params": [],
                  "returnType": {{relationType}},
                  "body": {
                    "kind": "EnumCase",
                    "typeId": "type:pkg:Demo:Demo:Relation",
                    "variantId": "type:pkg:Demo:Demo:Relation:variant:Smaller",
                    "name": "Smaller",
                    "args": [],
                    "type": {{relationType}}
                  }
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:cons",
                  "name": "cons",
                  "typeParams": [],
                  "params": [],
                  "returnType": {{lstType}},
                  "body": {
                    "kind": "EnumCase",
                    "typeId": "type:pkg:Demo:Demo:Lst",
                    "variantId": "type:pkg:Demo:Demo:Lst:variant:Cons",
                    "name": "Cons",
                    "args": [
                      { "kind": "IntLiteral", "value": "1", "type": {{intType}} },
                      {
                        "kind": "EnumCase",
                        "typeId": "type:pkg:Demo:Demo:Lst",
                        "variantId": "type:pkg:Demo:Demo:Lst:variant:Nil",
                        "name": "Nil",
                        "args": [],
                        "type": {{lstType}}
                      }
                    ],
                    "type": {{lstType}}
                  }
                }
              ],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);
        Assert.Contains("public enum Relation", code);
        Assert.Contains("public abstract class Lst", code);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal("Smaller", type.GetMethod("smaller")!.Invoke(null, [])!.ToString());
        var cons = type.GetMethod("cons")!.Invoke(null, [])!;
        Assert.Equal("ConsVariant", cons.GetType().Name);
        Assert.Equal(1, cons.GetType().GetProperty("Item0")!.GetValue(cons));
    }

    [Fact]
    public void EmitsEnumVariantWhenSourceVariantNameMatchesTypeName()
    {
        var stringType = """{ "kind": "Builtin", "name": "String" }""";
        var failureType = """
            {
              "kind": "Declared",
              "symbol": { "id": "type:pkg:Demo:Demo:Failure", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Failure" },
              "args": []
            }
            """;
        var json = $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [
                {
                  "kind": "Enum",
                  "symbol": { "id": "type:pkg:Demo:Demo:Failure", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Failure" },
                  "typeParams": [],
                  "variants": [
                    { "id": "type:pkg:Demo:Demo:Failure:variant:Failure", "name": "Failure", "payloads": [{{stringType}}] }
                  ]
                }
              ],
              "traits": [],
              "functions": [
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:make",
                  "name": "make",
                  "typeParams": [],
                  "params": [],
                  "returnType": {{failureType}},
                  "body": {
                    "kind": "EnumCase",
                    "typeId": "type:pkg:Demo:Demo:Failure",
                    "variantId": "type:pkg:Demo:Demo:Failure:variant:Failure",
                    "name": "Failure",
                    "args": [
                      { "kind": "StringLiteral", "value": "x", "type": {{stringType}} }
                    ],
                    "type": {{failureType}}
                  }
                }
              ],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);

        Assert.Contains("FailureCase", code, StringComparison.Ordinal);
        Assert.DoesNotContain("static Failure Failure(", code, StringComparison.Ordinal);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;
        Assert.Equal(
            "FailureCaseVariant",
            type.GetMethod("make")!.Invoke(null, [])!.GetType().Name
        );
    }

    [Fact]
    public void EmitsTraitObjectAndStaticTraitConstraintShape()
    {
        var animalType = """
            {
              "kind": "TraitObject",
              "trait": {
                "symbol": { "id": "type:Demo:Animal", "packageId": "", "modulePath": "Demo", "name": "Animal" },
                "args": []
              }
            }
            """;
        var typeParam = """{ "kind": "TypeParameter", "name": "T", "symbolId": "type-param:T" }""";
        var json = $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [],
              "traits": [
                {
                  "kind": "Trait",
                  "symbol": { "id": "type:Demo:Animal", "packageId": "", "modulePath": "Demo", "name": "Animal" },
                  "methods": [
                    {
                      "name": "speak",
                      "parameters": [{ "kind": "Builtin", "name": "Self" }],
                      "returnType": { "kind": "Builtin", "name": "String" }
                    }
                  ]
                }
              ],
              "functions": [
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:keep",
                  "name": "keep",
                  "typeParams": [{ "name": "T", "constraints": ["Animal"] }],
                  "params": [
                    { "symbolId": "fn:Demo:keep:param:x", "name": "x", "type": {{typeParam}} }
                  ],
                  "returnType": {{typeParam}},
                  "body": {
                    "kind": "Name",
                    "symbolId": "fn:Demo:keep:param:x",
                    "name": "x",
                    "type": {{typeParam}}
                  }
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:animal",
                  "name": "animal",
                  "typeParams": [],
                  "params": [
                    { "symbolId": "fn:Demo:animal:param:x", "name": "x", "type": {{animalType}} }
                  ],
                  "returnType": {{animalType}},
                  "body": {
                    "kind": "Name",
                    "symbolId": "fn:Demo:animal:param:x",
                    "name": "x",
                    "type": {{animalType}}
                  }
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:speak_bound",
                  "name": "speak_bound",
                  "typeParams": [{ "name": "T", "constraints": ["Animal"] }],
                  "params": [
                    { "symbolId": "fn:Demo:speak_bound:param:x", "name": "x", "type": {{typeParam}} }
                  ],
                  "returnType": { "kind": "Builtin", "name": "String" },
                  "body": {
                    "kind": "TraitMethodCall",
                    "receiver": {
                      "kind": "Name",
                      "symbolId": "fn:Demo:speak_bound:param:x",
                      "name": "x",
                      "type": {{typeParam}}
                    },
                    "trait": {
                      "symbol": { "id": "type:Demo:Animal", "packageId": "", "modulePath": "Demo", "name": "Animal" },
                      "args": []
                    },
                    "methodId": "trait-method:type:Demo:Animal:speak",
                    "name": "speak",
                    "args": [],
                    "dispatch": { "kind": "TypeParamBound", "implTypeParam": "TAnimalImpl" },
                    "type": { "kind": "Builtin", "name": "String" }
                  }
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:animal_speak",
                  "name": "animal_speak",
                  "typeParams": [],
                  "params": [
                    { "symbolId": "fn:Demo:animal_speak:param:x", "name": "x", "type": {{animalType}} }
                  ],
                  "returnType": { "kind": "Builtin", "name": "String" },
                  "body": {
                    "kind": "TraitMethodCall",
                    "receiver": {
                      "kind": "Name",
                      "symbolId": "fn:Demo:animal_speak:param:x",
                      "name": "x",
                      "type": {{animalType}}
                    },
                    "trait": {
                      "symbol": { "id": "type:Demo:Animal", "packageId": "", "modulePath": "Demo", "name": "Animal" },
                      "args": []
                    },
                    "methodId": "trait-method:type:Demo:Animal:speak",
                    "name": "speak",
                    "args": [],
                    "dispatch": { "kind": "TraitObject" },
                    "type": { "kind": "Builtin", "name": "String" }
                  }
                }
              ],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);

        Assert.Contains("public readonly record struct AnimalObject", code);
        Assert.Contains("public interface IAnimalImpl", code);
        Assert.Contains("static abstract string speak", code);
        Assert.Contains("where TAnimalImpl : IAnimalImpl<T, TAnimalImpl>", code);
        Assert.Contains("AnimalTrait.speak<T, TAnimalImpl>(x)", code);
        Assert.Contains("x.Impl.speak(x.Self)", code);
        Compile(code);
    }

    [Fact]
    public void EmitsConcreteIntrinsicTraitMethodCall()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var json = $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [],
              "traits": [
                {
                  "kind": "Trait",
                  "symbol": { "id": "type:pkg:Demo:Demo:Flip", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Flip" },
                  "methods": [
                    {
                      "name": "flip",
                      "parameters": [{ "kind": "Builtin", "name": "Self" }],
                      "returnType": { "kind": "Builtin", "name": "Self" }
                    }
                  ]
                }
              ],
              "functions": [
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:f",
                  "name": "f",
                  "typeParams": [],
                  "params": [
                    { "symbolId": "fn:Demo:f:param:a", "name": "a", "type": {{intType}} }
                  ],
                  "returnType": {{intType}},
                  "body": {
                    "kind": "TraitMethodCall",
                    "receiver": {
                      "kind": "Name",
                      "symbolId": "fn:Demo:f:param:a",
                      "name": "a",
                      "type": {{intType}}
                    },
                    "trait": {
                      "symbol": { "id": "type:pkg:Demo:Demo:Flip", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Flip" },
                      "args": []
                    },
                    "methodId": "trait-method:type:pkg:Demo:Demo:Flip:flip",
                    "name": "flip",
                    "args": [],
                    "dispatch": {
                      "kind": "ConcreteImpl",
                      "functionId": "impl-fn:type:pkg:Demo:Demo:Flip:Int:flip",
                      "selectedIntrinsic": "%i32_neg"
                    },
                    "type": {{intType}}
                  }
                }
              ],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);

        Assert.Contains("return -a;", code, StringComparison.Ordinal);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;
        Assert.Equal(-4, type.GetMethod("f")!.Invoke(null, [4]));
    }

    [Fact]
    public void ReportsVNextDiagnosticsWithSourcePosition()
    {
        var json = """
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [],
              "traits": [],
              "functions": [],
              "globals": [],
              "diagnostics": [
                {
                  "severity": "error",
                  "code": "VNX1201",
                  "message": "no operator implementation",
                  "span": {
                    "file": "src/demo.mbt",
                    "start": 42,
                    "end": 45,
                    "line": 7,
                    "column": 12
                  }
                }
              ]
            }
            """;

        var error = Assert.Throws<InvalidOperationException>(() => VNextBackend.Emit(json));

        Assert.Contains("src/demo.mbt:7:12: VNX1201: no operator implementation", error.Message);
    }

    [Fact]
    public void EmitsGuardAsEarlyReturn()
    {
        var json = ModuleJson(
            """
            {
              "kind": "Function",
              "symbolId": "fn:Demo:guarded",
              "name": "guarded",
              "params": [
                { "symbolId": "fn:Demo:guarded:param:ok", "name": "ok", "type": { "kind": "Builtin", "name": "Bool" } },
                { "symbolId": "fn:Demo:guarded:param:value", "name": "value", "type": { "kind": "Builtin", "name": "Int" } }
              ],
              "returnType": { "kind": "Builtin", "name": "Int" },
              "body": {
                "kind": "Sequence",
                "first": {
                  "kind": "Guard",
                  "condition": { "kind": "Name", "symbolId": "fn:Demo:guarded:param:ok", "name": "ok", "type": { "kind": "Builtin", "name": "Bool" } },
                  "else": { "kind": "IntLiteral", "value": "-1", "type": { "kind": "Builtin", "name": "Int" } },
                  "type": { "kind": "Builtin", "name": "Unit" }
                },
                "body": { "kind": "Name", "symbolId": "fn:Demo:guarded:param:value", "name": "value", "type": { "kind": "Builtin", "name": "Int" } },
                "type": { "kind": "Builtin", "name": "Int" }
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("if (!(ok))", code);
        Assert.Contains("return -1;", code);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(42, type.GetMethod("guarded")!.Invoke(null, [true, 42]));
        Assert.Equal(-1, type.GetMethod("guarded")!.Invoke(null, [false, 42]));
    }

    [Fact]
    public void EmitsTupleLiteralAndTupleGet()
    {
        const string intType = """{ "kind": "Builtin", "name": "Int" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:pick",
              "name": "pick",
              "params": [],
              "returnType": {{intType}},
              "body": {
                "kind": "TupleGet",
                "target": {
                  "kind": "TupleLiteral",
                  "items": [
                    { "kind": "IntLiteral", "value": "7", "type": {{intType}} },
                    { "kind": "IntLiteral", "value": "9", "type": {{intType}} }
                  ],
                  "type": { "kind": "Tuple", "items": [{{intType}}, {{intType}}] }
                },
                "index": 1,
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("(7, 9).Item2", code);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(9, type.GetMethod("pick")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsIndexGetAndIndexAssign()
    {
        const string intType = """{ "kind": "Builtin", "name": "Int" }""";
        const string arrayType =
            """{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "FixedArray" }, "args": [{ "kind": "Builtin", "name": "Int" }] }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:first",
              "name": "first",
              "params": [
                { "symbolId": "fn:Demo:first:param:xs", "name": "xs", "type": {{arrayType}} }
              ],
              "returnType": {{intType}},
              "body": {
                "kind": "IndexGet",
                "target": { "kind": "Name", "symbolId": "fn:Demo:first:param:xs", "name": "xs", "type": {{arrayType}} },
                "index": { "kind": "IntLiteral", "value": "0", "type": {{intType}} },
                "type": {{intType}}
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:set_first",
              "name": "set_first",
              "params": [
                { "symbolId": "fn:Demo:set_first:param:xs", "name": "xs", "type": {{arrayType}} }
              ],
              "returnType": { "kind": "Builtin", "name": "Unit" },
              "body": {
                "kind": "IndexAssign",
                "target": { "kind": "Name", "symbolId": "fn:Demo:set_first:param:xs", "name": "xs", "type": {{arrayType}} },
                "index": { "kind": "IntLiteral", "value": "0", "type": {{intType}} },
                "value": { "kind": "IntLiteral", "value": "11", "type": {{intType}} },
                "type": { "kind": "Builtin", "name": "Unit" }
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;
        var values = new[] { 7, 9 };

        Assert.Equal(7, type.GetMethod("first")!.Invoke(null, [values]));
        type.GetMethod("set_first")!.Invoke(null, [values]);
        Assert.Equal(11, values[0]);
    }

    [Fact]
    public void EmitsForInOverIterator()
    {
        const string intType = """{ "kind": "Builtin", "name": "Int" }""";
        const string unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        const string iterType =
            """{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "Iter" }, "args": [{ "kind": "Builtin", "name": "Int" }] }""";
        var totalName =
            $$"""{ "kind": "Name", "symbolId": "local:fn:Demo:sum:total", "name": "total", "type": {{intType}} }""";
        var itemName =
            $$"""{ "kind": "Name", "symbolId": "local:fn:Demo:sum:x", "name": "x", "type": {{intType}} }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:sum",
              "name": "sum",
              "params": [
                { "symbolId": "fn:Demo:sum:param:xs", "name": "xs", "type": {{iterType}} }
              ],
              "returnType": {{intType}},
              "body": {
                "kind": "LocalLet",
                "local": {
                  "symbolId": "local:fn:Demo:sum:total",
                  "name": "total",
                  "type": {{intType}},
                  "value": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                },
                "body": {
                  "kind": "Sequence",
                  "first": {
                    "kind": "ForIn",
                    "valueSymbols": [{ "symbolId": "local:fn:Demo:sum:x", "name": "x", "type": {{intType}} }],
                    "iterator": { "kind": "Name", "symbolId": "fn:Demo:sum:param:xs", "name": "xs", "type": {{iterType}} },
                    "bindings": [],
                    "body": {
                      "kind": "Assign",
                      "symbolId": "local:fn:Demo:sum:total",
                      "name": "total",
                      "value": {
                        "kind": "Binary",
                        "op": "+",
                        "left": {{totalName}},
                        "right": {{itemName}},
                        "selectedIntrinsic": "%i32_add",
                        "type": {{intType}}
                      },
                      "type": {{unitType}}
                    },
                    "noBreak": null,
                    "type": {{unitType}}
                  },
                  "body": {{totalName}},
                  "type": {{intType}}
                },
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("while (true)", code, StringComparison.Ordinal);
        Assert.Contains("var __mbt_for_in_next", code, StringComparison.Ordinal);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;
        var items = new[] { 1, 2, 3 };
        var index = 0;
        var iter = new MoonBitIter<int>(() =>
            index < items.Length
                ? MoonBitOption<int>.Some(items[index++])
                : MoonBitOption<int>.None()
        );

        Assert.Equal(6, type.GetMethod("sum")!.Invoke(null, [iter]));
    }

    [Fact]
    public void EmitsForInOverArrayAsIndexedLoop()
    {
        const string intType = """{ "kind": "Builtin", "name": "Int" }""";
        const string unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        const string arrayType =
            """{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "Array" }, "args": [{ "kind": "Builtin", "name": "Int" }] }""";
        const string iterType =
            """{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "Iter" }, "args": [{ "kind": "Builtin", "name": "Int" }] }""";
        var totalName =
            $$"""{ "kind": "Name", "symbolId": "local:fn:Demo:sum_array:total", "name": "total", "type": {{intType}} }""";
        var itemName =
            $$"""{ "kind": "Name", "symbolId": "local:fn:Demo:sum_array:x", "name": "x", "type": {{intType}} }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:sum_array",
              "name": "sum_array",
              "params": [
                { "symbolId": "fn:Demo:sum_array:param:xs", "name": "xs", "type": {{arrayType}} }
              ],
              "returnType": {{intType}},
              "body": {
                "kind": "LocalLet",
                "local": {
                  "symbolId": "local:fn:Demo:sum_array:total",
                  "name": "total",
                  "type": {{intType}},
                  "value": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                },
                "body": {
                  "kind": "Sequence",
                  "first": {
                    "kind": "ForIn",
                    "valueSymbols": [{ "symbolId": "local:fn:Demo:sum_array:x", "name": "x", "type": {{intType}} }],
                    "iterator": {
                      "kind": "Call",
                      "functionId": "fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Array::iter",
                      "typeArgs": [{{intType}}],
                      "args": [{ "kind": "Name", "symbolId": "fn:Demo:sum_array:param:xs", "name": "xs", "type": {{arrayType}} }],
                      "type": {{iterType}}
                    },
                    "bindings": [],
                    "body": {
                      "kind": "Assign",
                      "symbolId": "local:fn:Demo:sum_array:total",
                      "name": "total",
                      "value": {
                        "kind": "Binary",
                        "op": "+",
                        "left": {{totalName}},
                        "right": {{itemName}},
                        "selectedIntrinsic": "%i32_add",
                        "type": {{intType}}
                      },
                      "type": {{unitType}}
                    },
                    "noBreak": null,
                    "type": {{unitType}}
                  },
                  "body": {{totalName}},
                  "type": {{intType}}
                },
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("for (int __mbt_for_in_offset", code, StringComparison.Ordinal);
        Assert.DoesNotContain("Iter__next", code, StringComparison.Ordinal);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(
            6,
            type.GetMethod("sum_array")!.Invoke(null, [new MoonBitArray<int>([1, 2, 3])])
        );
    }

    [Fact]
    public void EmitsForInOverStringAsUnicodeCodePointLoop()
    {
        const string intType = """{ "kind": "Builtin", "name": "Int" }""";
        const string unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        const string stringType = """{ "kind": "Builtin", "name": "String" }""";
        const string iterType =
            """{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "Iter" }, "args": [{ "kind": "Builtin", "name": "Char" }] }""";
        var totalName =
            $$"""{ "kind": "Name", "symbolId": "local:fn:Demo:sum_chars:total", "name": "total", "type": {{intType}} }""";
        var charName =
            $$"""{ "kind": "Name", "symbolId": "local:fn:Demo:sum_chars:c", "name": "c", "type": {{intType}} }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:sum_chars",
              "name": "sum_chars",
              "params": [
                { "symbolId": "fn:Demo:sum_chars:param:s", "name": "s", "type": {{stringType}} }
              ],
              "returnType": {{intType}},
              "body": {
                "kind": "LocalLet",
                "local": {
                  "symbolId": "local:fn:Demo:sum_chars:total",
                  "name": "total",
                  "type": {{intType}},
                  "value": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                },
                "body": {
                  "kind": "Sequence",
                  "first": {
                    "kind": "ForIn",
                    "valueSymbols": [{ "symbolId": "local:fn:Demo:sum_chars:c", "name": "c", "type": {{intType}} }],
                    "iterator": {
                      "kind": "Call",
                      "functionId": "fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:String::iter",
                      "typeArgs": [],
                      "args": [{ "kind": "Name", "symbolId": "fn:Demo:sum_chars:param:s", "name": "s", "type": {{stringType}} }],
                      "type": {{iterType}}
                    },
                    "bindings": [],
                    "body": {
                      "kind": "Assign",
                      "symbolId": "local:fn:Demo:sum_chars:total",
                      "name": "total",
                      "value": {
                        "kind": "Binary",
                        "op": "+",
                        "left": {{totalName}},
                        "right": {{charName}},
                        "selectedIntrinsic": "%i32_add",
                        "type": {{intType}}
                      },
                      "type": {{unitType}}
                    },
                    "noBreak": null,
                    "type": {{unitType}}
                  },
                  "body": {{totalName}},
                  "type": {{intType}}
                },
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("char.ConvertToUtf32", code, StringComparison.Ordinal);
        Assert.DoesNotContain("Iter__next", code, StringComparison.Ordinal);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(97 + 128512 + 98, type.GetMethod("sum_chars")!.Invoke(null, ["a😀b"]));
    }

    [Fact]
    public void EmitsForInOverBytesAsIndexedLoop()
    {
        const string intType = """{ "kind": "Builtin", "name": "Int" }""";
        const string byteType = """{ "kind": "Builtin", "name": "Byte" }""";
        const string unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        const string bytesType = """{ "kind": "Builtin", "name": "Bytes" }""";
        const string iterType =
            """{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "Iter" }, "args": [{ "kind": "Builtin", "name": "Byte" }] }""";
        var totalName =
            $$"""{ "kind": "Name", "symbolId": "local:fn:Demo:sum_bytes:total", "name": "total", "type": {{intType}} }""";
        var itemName =
            $$"""{ "kind": "Name", "symbolId": "local:fn:Demo:sum_bytes:b", "name": "b", "type": {{byteType}} }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:sum_bytes",
              "name": "sum_bytes",
              "params": [
                { "symbolId": "fn:Demo:sum_bytes:param:xs", "name": "xs", "type": {{bytesType}} }
              ],
              "returnType": {{intType}},
              "body": {
                "kind": "LocalLet",
                "local": {
                  "symbolId": "local:fn:Demo:sum_bytes:total",
                  "name": "total",
                  "type": {{intType}},
                  "value": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                },
                "body": {
                  "kind": "Sequence",
                  "first": {
                    "kind": "ForIn",
                    "valueSymbols": [{ "symbolId": "local:fn:Demo:sum_bytes:b", "name": "b", "type": {{byteType}} }],
                    "iterator": {
                      "kind": "Call",
                      "functionId": "fn:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Bytes::iter",
                      "typeArgs": [],
                      "args": [{ "kind": "Name", "symbolId": "fn:Demo:sum_bytes:param:xs", "name": "xs", "type": {{bytesType}} }],
                      "type": {{iterType}}
                    },
                    "bindings": [],
                    "body": {
                      "kind": "Assign",
                      "symbolId": "local:fn:Demo:sum_bytes:total",
                      "name": "total",
                      "value": {
                        "kind": "Binary",
                        "op": "+",
                        "left": {{totalName}},
                        "right": {{itemName}},
                        "selectedIntrinsic": "%i32_add",
                        "type": {{intType}}
                      },
                      "type": {{unitType}}
                    },
                    "noBreak": null,
                    "type": {{unitType}}
                  },
                  "body": {{totalName}},
                  "type": {{intType}}
                },
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("for (int __mbt_for_in_offset", code, StringComparison.Ordinal);
        Assert.DoesNotContain("Iter__next", code, StringComparison.Ordinal);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(6, type.GetMethod("sum_bytes")!.Invoke(null, [new byte[] { 1, 2, 3 }]));
    }

    [Fact]
    public void EmitsExplicitReturnControl()
    {
        const string intType = """{ "kind": "Builtin", "name": "Int" }""";
        const string unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:keep",
              "name": "keep",
              "params": [
                { "symbolId": "fn:Demo:keep:param:x", "name": "x", "type": {{intType}} }
              ],
              "returnType": {{intType}},
              "body": {
                "kind": "Return",
                "value": { "kind": "Name", "symbolId": "fn:Demo:keep:param:x", "name": "x", "type": {{intType}} },
                "type": {{unitType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("return x;", code);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(9, type.GetMethod("keep")!.Invoke(null, [9]));
    }

    [Fact]
    public void EmitsFunctionalForLoopBreakValueAndContinueArguments()
    {
        const string intType = """{ "kind": "Builtin", "name": "Int" }""";
        const string boolType = """{ "kind": "Builtin", "name": "Bool" }""";
        const string unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        var iName =
            $$"""{ "kind": "Name", "symbolId": "local:fn:Demo:first_hit:i", "name": "i", "type": {{intType}} }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:first_hit",
              "name": "first_hit",
              "params": [],
              "returnType": {{intType}},
              "body": {
                "kind": "ForLoop",
                "bindings": [
                  {
                    "symbolId": "local:fn:Demo:first_hit:i",
                    "name": "i",
                    "type": {{intType}},
                    "value": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                  }
                ],
                "condition": null,
                "updates": [],
                "body": {
                  "kind": "If",
                  "condition": {
                    "kind": "Binary",
                    "op": "==",
                    "left": {{iName}},
                    "right": { "kind": "IntLiteral", "value": "4", "type": {{intType}} },
                    "selectedIntrinsic": "%i32_eq",
                    "type": {{boolType}}
                  },
                  "then": {
                    "kind": "Break",
                    "value": {{iName}},
                    "type": {{unitType}}
                  },
                  "else": {
                    "kind": "Continue",
                    "args": [
                      {
                        "kind": "Binary",
                        "op": "+",
                        "left": {{iName}},
                        "right": { "kind": "IntLiteral", "value": "1", "type": {{intType}} },
                        "selectedIntrinsic": "%i32_add",
                        "type": {{intType}}
                      }
                    ],
                    "type": {{unitType}}
                  },
                  "type": {{intType}}
                },
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("__mbt_loop_result0 = i;", code);
        Assert.Contains("__mbt_continue", code);
        Assert.Contains("i = __mbt_continue", code);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(4, type.GetMethod("first_hit")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsFunctionalForLoopValueInsideReturnedBinaryExpression()
    {
        const string intType = """{ "kind": "Builtin", "name": "Int" }""";
        const string boolType = """{ "kind": "Builtin", "name": "Bool" }""";
        const string unitType = """{ "kind": "Builtin", "name": "Unit" }""";
        var iName =
            $$"""{ "kind": "Name", "symbolId": "local:fn:Demo:sum_loop:i", "name": "i", "type": {{intType}} }""";
        var loop = $$"""
            {
              "kind": "ForLoop",
              "bindings": [
                {
                  "symbolId": "local:fn:Demo:sum_loop:i",
                  "name": "i",
                  "type": {{intType}},
                  "value": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                }
              ],
              "condition": null,
              "updates": [],
              "body": {
                "kind": "If",
                "condition": {
                  "kind": "Binary",
                  "op": "==",
                  "left": {{iName}},
                  "right": { "kind": "IntLiteral", "value": "2", "type": {{intType}} },
                  "selectedIntrinsic": "%i32_eq",
                  "type": {{boolType}}
                },
                "then": { "kind": "Break", "value": {{iName}}, "type": {{unitType}} },
                "else": {
                  "kind": "Continue",
                  "args": [
                    {
                      "kind": "Binary",
                      "op": "+",
                      "left": {{iName}},
                      "right": { "kind": "IntLiteral", "value": "1", "type": {{intType}} },
                      "selectedIntrinsic": "%i32_add",
                      "type": {{intType}}
                    }
                  ],
                  "type": {{unitType}}
                },
                "type": {{intType}}
              },
              "type": {{intType}}
            }
            """;
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:sum_loop",
              "name": "sum_loop",
              "params": [],
              "returnType": {{intType}},
              "body": {
                "kind": "Binary",
                "op": "+",
                "left": {{loop}},
                "right": { "kind": "IntLiteral", "value": "5", "type": {{intType}} },
                "selectedIntrinsic": "%i32_add",
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.DoesNotContain("System.Func", code, StringComparison.Ordinal);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(7, type.GetMethod("sum_loop")!.Invoke(null, []));
    }

    [Fact]
    public void EmitsStaticVirtualTraitDefaultFromIr()
    {
        var json = """
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [],
              "traits": [
                {
                  "kind": "Trait",
                  "symbol": {
                    "id": "type:pkg:Demo:Demo:Show2",
                    "name": "Show2",
                    "packageId": "pkg:Demo",
                    "modulePath": "Demo"
                  },
                  "methods": [
                    {
                      "name": "to_string2",
                      "parameters": [{ "kind": "Builtin", "name": "Self" }],
                      "returnType": { "kind": "Builtin", "name": "String" },
                      "hasDefault": true,
                      "defaultFunctionId": "default-trait:type:pkg:Demo:Demo:Show2:to_string2"
                    }
                  ]
                }
              ],
              "functions": [
                {
                  "kind": "Function",
                  "symbolId": "default-trait:type:pkg:Demo:Demo:Show2:to_string2",
                  "name": "to_string2",
                  "typeParams": [{ "name": "T", "constraints": ["Show2"] }],
                  "params": [
                    {
                      "symbolId": "default-trait:type:pkg:Demo:Demo:Show2:to_string2:param:self",
                      "name": "self",
                      "type": {
                        "kind": "TypeParameter",
                        "name": "T",
                        "symbolId": "type-param:default-trait:type:pkg:Demo:Demo:Show2:T"
                      }
                    }
                  ],
                  "returnType": { "kind": "Builtin", "name": "String" },
                  "body": {
                    "kind": "StringLiteral",
                    "value": "ok",
                    "type": { "kind": "Builtin", "name": "String" }
                  }
                }
              ],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);

        Assert.Contains("static virtual", code, StringComparison.Ordinal);
        Assert.Contains(
            "static virtual string to_string2(T self) => \"ok\";",
            code,
            StringComparison.Ordinal
        );
        Assert.DoesNotContain("Demo.to_string2", code, StringComparison.Ordinal);
    }

    private static string ModuleJson(string functions)
    {
        return $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [],
              "traits": [],
              "functions": [
                {{functions}}
              ],
              "globals": [],
              "diagnostics": []
            }
            """;
    }

    private static Assembly Compile(string source)
    {
        var parseOptions = CSharpParseOptions.Default.WithLanguageVersion(LanguageVersion.Preview);
        var syntaxTree = CSharpSyntaxTree.ParseText(source, parseOptions);
        var trustedPlatformAssemblies = (
            (string?)AppContext.GetData("TRUSTED_PLATFORM_ASSEMBLIES")
        )!
            .Split(Path.PathSeparator)
            .Select(path => MetadataReference.CreateFromFile(path));
        var loadedAssemblies = AppDomain
            .CurrentDomain.GetAssemblies()
            .Where(assembly => !assembly.IsDynamic && !string.IsNullOrEmpty(assembly.Location))
            .Select(assembly => MetadataReference.CreateFromFile(assembly.Location));
        var references = trustedPlatformAssemblies
            .Concat(loadedAssemblies)
            .DistinctBy(reference => reference.Display);
        var compilation = CSharpCompilation.Create(
            "GeneratedMoonBitVNextTests",
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

    private static Type GeneratedType(Assembly assembly, string name, string packageName = "")
    {
        var candidates = new List<string> { "Generated.MoonBit." + name };
        if (!string.IsNullOrWhiteSpace(packageName))
            candidates.Insert(
                0,
                "Generated.MoonBit.Packages." + SafeNamespacePath(packageName) + "." + name
            );

        foreach (var candidate in candidates)
        {
            var type = assembly.GetType(candidate, false);
            if (type is not null)
                return type;
        }

        return assembly.GetType(candidates[0], true)!;
    }

    private static string SafeNamespacePath(string packageName)
    {
        return string.Join(
            ".",
            packageName
                .Split('/', StringSplitOptions.RemoveEmptyEntries)
                .Select(SafeNamespaceSegment)
        );
    }

    private static string SafeNamespaceSegment(string segment)
    {
        return new(
            segment
                .Select(
                    (ch, index) =>
                        index == 0
                            ? char.IsLetter(ch) || ch == '_'
                                ? ch
                                : '_'
                            : char.IsLetterOrDigit(ch) || ch == '_'
                                ? ch
                                : '_'
                )
                .ToArray()
        );
    }
}
