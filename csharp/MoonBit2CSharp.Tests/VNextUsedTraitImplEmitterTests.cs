using MoonBit2CSharp.VNext.Backend;
using Xunit;

namespace MoonBit2CSharp.Tests;

public sealed class VNextUsedTraitImplEmitterTests
{
    [Fact]
    public void DoesNotEmitDerivedTraitImplsWhenUnused()
    {
        var code = VNextBackend.Emit(
            """
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [
                {
                  "kind": "Struct",
                  "symbol": { "id": "type:pkg:Demo:Demo:Span", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Span" },
                  "typeParams": [],
                  "fields": [
                    { "id": "type:pkg:Demo:Demo:Span:field:from", "name": "from", "mutable": false, "type": { "kind": "Builtin", "name": "Int" } },
                    { "id": "type:pkg:Demo:Demo:Span:field:to", "name": "to", "mutable": false, "type": { "kind": "Builtin", "name": "Int" } }
                  ],
                  "derives": ["Eq", "Hash", "Debug"]
                }
              ],
              "traits": [],
              "usedTraitImpls": [],
              "functions": [],
              "globals": [],
              "diagnostics": []
            }
            """
        );

        Assert.DoesNotContain("SpanEqImpl", code, StringComparison.Ordinal);
        Assert.DoesNotContain("SpanHashImpl", code, StringComparison.Ordinal);
        Assert.DoesNotContain("SpanDebugImpl", code, StringComparison.Ordinal);
    }

    [Fact]
    public void DerivedTraitClosureDoesNotCrossTraits()
    {
        var code = VNextBackend.Emit(
            """
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [
                {
                  "kind": "Struct",
                  "symbol": { "id": "type:pkg:Demo:Demo:Inner", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Inner" },
                  "typeParams": [],
                  "fields": [
                    { "id": "type:pkg:Demo:Demo:Inner:field:value", "name": "value", "mutable": false, "type": { "kind": "Builtin", "name": "Int" } }
                  ],
                  "derives": ["Eq", "Debug"]
                },
                {
                  "kind": "Struct",
                  "symbol": { "id": "type:pkg:Demo:Demo:Outer", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Outer" },
                  "typeParams": [],
                  "fields": [
                    {
                      "id": "type:pkg:Demo:Demo:Outer:field:inner",
                      "name": "inner",
                      "mutable": false,
                      "type": {
                        "kind": "Declared",
                        "symbol": { "id": "type:pkg:Demo:Demo:Inner", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Inner" },
                        "args": []
                      }
                    }
                  ],
                  "derives": ["Eq"]
                }
              ],
              "traits": [],
              "usedTraitImpls": [
                {
                  "trait": { "symbol": { "id": "type:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Eq", "packageId": "pkg:moonbitlang/core/builtin", "modulePath": "moonbitlang/core/builtin", "name": "Eq" }, "args": [] },
                  "selfType": {
                    "kind": "Declared",
                    "symbol": { "id": "type:pkg:Demo:Demo:Outer", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Outer" },
                    "args": []
                  }
                }
              ],
              "functions": [
                {
                  "kind": "Function",
                  "symbolId": "fn:pkg:Demo:Demo:same",
                  "name": "same",
                  "params": [
                    {
                      "symbolId": "fn:pkg:Demo:Demo:same:param:left",
                      "name": "left",
                      "type": {
                        "kind": "Declared",
                        "symbol": { "id": "type:pkg:Demo:Demo:Outer", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Outer" },
                        "args": []
                      }
                    },
                    {
                      "symbolId": "fn:pkg:Demo:Demo:same:param:right",
                      "name": "right",
                      "type": {
                        "kind": "Declared",
                        "symbol": { "id": "type:pkg:Demo:Demo:Outer", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Outer" },
                        "args": []
                      }
                    }
                  ],
                  "returnType": { "kind": "Builtin", "name": "Bool" },
                  "body": {
                    "kind": "BoolLiteral",
                    "value": true,
                    "type": { "kind": "Builtin", "name": "Bool" }
                  }
                }
              ],
              "globals": [],
              "diagnostics": []
            }
            """
        );

        Assert.Contains("OuterEqImpl", code, StringComparison.Ordinal);
        Assert.Contains("InnerEqImpl", code, StringComparison.Ordinal);
        Assert.DoesNotContain("OuterDebugImpl", code, StringComparison.Ordinal);
        Assert.DoesNotContain("InnerDebugImpl", code, StringComparison.Ordinal);
        Assert.DoesNotContain("moonbitlang.core.debug", code, StringComparison.Ordinal);
    }
}
