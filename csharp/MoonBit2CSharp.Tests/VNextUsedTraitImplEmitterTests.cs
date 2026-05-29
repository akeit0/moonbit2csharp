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
}
