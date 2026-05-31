using System.Reflection;
using MoonBit.Runtime;
using MoonBit2CSharp.VNext.Backend;
using Xunit;

namespace MoonBit2CSharp.Tests;

public sealed partial class VNextSemanticEmitterTests
{
    [Fact]
    public void EmitsConstantEnumMatchAsSwitchExpression()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var relationType = """
            {
              "kind": "Declared",
              "symbol": { "id": "type:pkg:Demo:Demo:Relation", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Relation" },
              "args": []
            }
            """;
        var relationParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:rank:r", "name": "r", "type": {{relationType}} }""";
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
                  "symbolId": "fn:Demo:rank",
                  "name": "rank",
                  "typeParams": [],
                  "params": [
                    { "symbolId": "param:fn:Demo:rank:r", "name": "r", "type": {{relationType}} }
                  ],
                  "returnType": {{intType}},
                  "body": {
                    "kind": "Match",
                    "target": {{relationParam}},
                    "arms": [
                      {
                        "pattern": {
                          "kind": "EnumCase",
                          "typeId": "type:pkg:Demo:Demo:Relation",
                          "variantId": "type:pkg:Demo:Demo:Relation:variant:Smaller",
                          "name": "Smaller",
                          "payloads": []
                        },
                        "body": { "kind": "IntLiteral", "value": "1", "type": {{intType}} }
                      },
                      {
                        "pattern": { "kind": "Wildcard" },
                        "body": { "kind": "IntLiteral", "value": "2", "type": {{intType}} }
                      }
                    ],
                    "type": {{intType}}
                  }
                }
              ],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);
        Assert.Contains("switch", code);
        Assert.Contains("Relation.Smaller", code);
        var assembly = Compile(code);
        var type = assembly.GetType("Generated.MoonBit.Demo", true)!;
        var relation = GeneratedType(assembly, "Relation", "Demo");

        Assert.Equal(1, type.GetMethod("rank")!.Invoke(null, [Enum.Parse(relation, "Smaller")]));
        Assert.Equal(2, type.GetMethod("rank")!.Invoke(null, [Enum.Parse(relation, "Greater")]));
    }

    [Fact]
    public void EmitsDiscardFallbackForFullyNamedEnumSwitchExpression()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var relationType = """
            {
              "kind": "Declared",
              "symbol": { "id": "type:pkg:Demo:Demo:Relation", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Relation" },
              "args": []
            }
            """;
        var relationParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:rank:r", "name": "r", "type": {{relationType}} }""";
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
                  "symbolId": "fn:Demo:rank",
                  "name": "rank",
                  "typeParams": [],
                  "params": [
                    { "symbolId": "param:fn:Demo:rank:r", "name": "r", "type": {{relationType}} }
                  ],
                  "returnType": {{intType}},
                  "body": {
                    "kind": "Match",
                    "target": {{relationParam}},
                    "arms": [
                      {
                        "pattern": {
                          "kind": "EnumCase",
                          "typeId": "type:pkg:Demo:Demo:Relation",
                          "variantId": "type:pkg:Demo:Demo:Relation:variant:Smaller",
                          "name": "Smaller",
                          "payloads": []
                        },
                        "body": { "kind": "IntLiteral", "value": "1", "type": {{intType}} }
                      },
                      {
                        "pattern": {
                          "kind": "EnumCase",
                          "typeId": "type:pkg:Demo:Demo:Relation",
                          "variantId": "type:pkg:Demo:Demo:Relation:variant:Greater",
                          "name": "Greater",
                          "payloads": []
                        },
                        "body": { "kind": "IntLiteral", "value": "2", "type": {{intType}} }
                      }
                    ],
                    "type": {{intType}}
                  }
                }
              ],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);
        Assert.Contains("_ => throw new System.Diagnostics.UnreachableException()", code);
        Compile(code, "namespace Generated.MoonBit.Runtime { }");
    }

    [Fact]
    public void EmitsPayloadEnumMatchAsTagSwitch()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var boolType = """{ "kind": "Builtin", "name": "Bool" }""";
        var lstType = """
            {
              "kind": "Declared",
              "symbol": { "id": "type:pkg:Demo:Demo:Lst", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Lst" },
              "args": []
            }
            """;
        var xsParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:head:xs", "name": "xs", "type": {{lstType}} }""";
        var guardedXsParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:head_guarded:xs", "name": "xs", "type": {{lstType}} }""";
        var keepParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:head_guarded:keep", "name": "keep", "type": {{boolType}} }""";
        var json = $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [
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
              "traits": [],
              "functions": [
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:head",
                  "name": "head",
                  "typeParams": [],
                  "params": [
                    { "symbolId": "param:fn:Demo:head:xs", "name": "xs", "type": {{lstType}} }
                  ],
                  "returnType": {{intType}},
                  "body": {
                    "kind": "Match",
                    "target": {{xsParam}},
                    "arms": [
                      {
                        "pattern": {
                          "kind": "EnumCase",
                          "typeId": "type:pkg:Demo:Demo:Lst",
                          "variantId": "type:pkg:Demo:Demo:Lst:variant:Cons",
                          "name": "Cons",
                          "payloads": [
                            { "kind": "IntLiteral", "value": "1" },
                            { "kind": "Wildcard" }
                          ]
                        },
                        "body": { "kind": "IntLiteral", "value": "10", "type": {{intType}} }
                      },
                      {
                        "pattern": {
                          "kind": "EnumCase",
                          "typeId": "type:pkg:Demo:Demo:Lst",
                          "variantId": "type:pkg:Demo:Demo:Lst:variant:Cons",
                          "name": "Cons",
                          "payloads": [
                            { "kind": "Binding", "symbol": { "id": "local:fn:Demo:head:x", "kind": "Local", "name": "x", "type": {{intType}} } },
                            { "kind": "Wildcard" }
                          ]
                        },
                        "body": { "kind": "Name", "symbolId": "local:fn:Demo:head:x", "name": "x", "type": {{intType}} }
                      },
                      {
                        "pattern": {
                          "kind": "EnumCase",
                          "typeId": "type:pkg:Demo:Demo:Lst",
                          "variantId": "type:pkg:Demo:Demo:Lst:variant:Nil",
                          "name": "Nil",
                          "payloads": []
                        },
                        "body": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                      }
                    ],
                    "type": {{intType}}
                  }
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:head_guarded",
                  "name": "head_guarded",
                  "typeParams": [],
                  "params": [
                    { "symbolId": "param:fn:Demo:head_guarded:xs", "name": "xs", "type": {{lstType}} },
                    { "symbolId": "param:fn:Demo:head_guarded:keep", "name": "keep", "type": {{boolType}} }
                  ],
                  "returnType": {{intType}},
                  "body": {
                    "kind": "Match",
                    "target": {{guardedXsParam}},
                    "arms": [
                      {
                        "pattern": { "kind": "Wildcard" },
                        "condition": {{keepParam}},
                        "body": { "kind": "IntLiteral", "value": "99", "type": {{intType}} }
                      },
                      {
                        "pattern": {
                          "kind": "EnumCase",
                          "typeId": "type:pkg:Demo:Demo:Lst",
                          "variantId": "type:pkg:Demo:Demo:Lst:variant:Cons",
                          "name": "Cons",
                          "payloads": [
                            { "kind": "Binding", "symbol": { "id": "local:fn:Demo:head_guarded:x", "kind": "Local", "name": "x", "type": {{intType}} } },
                            { "kind": "Wildcard" }
                          ]
                        },
                        "body": { "kind": "Name", "symbolId": "local:fn:Demo:head_guarded:x", "name": "x", "type": {{intType}} }
                      },
                      {
                        "pattern": {
                          "kind": "EnumCase",
                          "typeId": "type:pkg:Demo:Demo:Lst",
                          "variantId": "type:pkg:Demo:Demo:Lst:variant:Nil",
                          "name": "Nil",
                          "payloads": []
                        },
                        "body": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                      }
                    ],
                    "type": {{intType}}
                  }
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:classify",
                  "name": "classify",
                  "typeParams": [],
                  "params": [
                    { "symbolId": "param:fn:Demo:classify:xs", "name": "xs", "type": {{lstType}} }
                  ],
                  "returnType": {{intType}},
                  "body": {
                    "kind": "Match",
                    "target": { "kind": "Name", "symbolId": "param:fn:Demo:classify:xs", "name": "xs", "type": {{lstType}} },
                    "arms": [
                      {
                        "pattern": {
                          "kind": "Or",
                          "alternatives": [
                            {
                              "kind": "EnumCase",
                              "typeId": "type:pkg:Demo:Demo:Lst",
                              "variantId": "type:pkg:Demo:Demo:Lst:variant:Nil",
                              "name": "Nil",
                              "payloads": []
                            },
                            {
                              "kind": "EnumCase",
                              "typeId": "type:pkg:Demo:Demo:Lst",
                              "variantId": "type:pkg:Demo:Demo:Lst:variant:Cons",
                              "name": "Cons",
                              "payloads": [
                                { "kind": "IntLiteral", "value": "0" },
                                { "kind": "Wildcard" }
                              ]
                            }
                          ]
                        },
                        "body": { "kind": "IntLiteral", "value": "42", "type": {{intType}} }
                      },
                      {
                        "pattern": {
                          "kind": "EnumCase",
                          "typeId": "type:pkg:Demo:Demo:Lst",
                          "variantId": "type:pkg:Demo:Demo:Lst:variant:Cons",
                          "name": "Cons",
                          "payloads": [
                            { "kind": "Binding", "symbol": { "id": "local:fn:Demo:classify:x", "kind": "Local", "name": "x", "type": {{intType}} } },
                            { "kind": "Wildcard" }
                          ]
                        },
                        "body": { "kind": "Name", "symbolId": "local:fn:Demo:classify:x", "name": "x", "type": {{intType}} }
                      }
                    ],
                    "type": {{intType}}
                  }
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:classify_local",
                  "name": "classify_local",
                  "typeParams": [],
                  "params": [
                    { "symbolId": "param:fn:Demo:classify_local:xs", "name": "xs", "type": {{lstType}} }
                  ],
                  "returnType": {{intType}},
                  "body": {
                    "kind": "LocalLet",
                    "local": {
                      "symbolId": "local:fn:Demo:classify_local:r",
                      "name": "r",
                      "type": {{intType}},
                      "value": {
                        "kind": "Match",
                        "target": { "kind": "Name", "symbolId": "param:fn:Demo:classify_local:xs", "name": "xs", "type": {{lstType}} },
                        "arms": [
                          {
                            "pattern": {
                              "kind": "Or",
                              "alternatives": [
                                {
                                  "kind": "EnumCase",
                                  "typeId": "type:pkg:Demo:Demo:Lst",
                                  "variantId": "type:pkg:Demo:Demo:Lst:variant:Nil",
                                  "name": "Nil",
                                  "payloads": []
                                },
                                {
                                  "kind": "EnumCase",
                                  "typeId": "type:pkg:Demo:Demo:Lst",
                                  "variantId": "type:pkg:Demo:Demo:Lst:variant:Cons",
                                  "name": "Cons",
                                  "payloads": [
                                    { "kind": "IntLiteral", "value": "0" },
                                    { "kind": "Wildcard" }
                                  ]
                                }
                              ]
                            },
                            "body": { "kind": "IntLiteral", "value": "42", "type": {{intType}} }
                          },
                          {
                            "pattern": {
                              "kind": "EnumCase",
                              "typeId": "type:pkg:Demo:Demo:Lst",
                              "variantId": "type:pkg:Demo:Demo:Lst:variant:Cons",
                              "name": "Cons",
                              "payloads": [
                                { "kind": "Binding", "symbol": { "id": "local:fn:Demo:classify_local:x", "kind": "Local", "name": "x", "type": {{intType}} } },
                                { "kind": "Wildcard" }
                              ]
                            },
                            "body": { "kind": "Name", "symbolId": "local:fn:Demo:classify_local:x", "name": "x", "type": {{intType}} }
                          }
                        ],
                        "type": {{intType}}
                      }
                    },
                    "body": { "kind": "Name", "symbolId": "local:fn:Demo:classify_local:r", "name": "r", "type": {{intType}} },
                    "type": {{intType}}
                  }
                }
              ],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);
        Assert.Contains("switch", code);
        Assert.Contains(".Kind", code);
        Assert.Contains("System.Runtime.CompilerServices.Unsafe.As<", code);
        Assert.Contains("Lst.ConsVariant>", code);
        Assert.DoesNotContain("System.Func", code);
        var assembly = Compile(code, "namespace Generated.MoonBit.Runtime { }");
        var module = GeneratedType(assembly, "Demo", "Demo");
        var lst = GeneratedType(assembly, "Lst", "Demo");
        var nil = lst.GetField("Nil")!.GetValue(null);
        var cons = lst.GetMethod("Cons")!.Invoke(null, [7, nil]);
        var consOne = lst.GetMethod("Cons")!.Invoke(null, [1, nil]);
        var consZero = lst.GetMethod("Cons")!.Invoke(null, [0, nil]);
        var head = module.GetMethod(
            "head",
            BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static
        )!;
        var headGuarded = module.GetMethod(
            "head_guarded",
            BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static
        )!;
        var classify = module.GetMethod(
            "classify",
            BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static
        )!;
        var classifyLocal = module.GetMethod(
            "classify_local",
            BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static
        )!;

        Assert.Equal(7, head.Invoke(null, [cons]));
        Assert.Equal(10, head.Invoke(null, [consOne]));
        Assert.Equal(0, head.Invoke(null, [nil]));
        Assert.Equal(99, headGuarded.Invoke(null, [cons, true]));
        Assert.Equal(7, headGuarded.Invoke(null, [cons, false]));
        Assert.Equal(99, headGuarded.Invoke(null, [nil, true]));
        Assert.Equal(0, headGuarded.Invoke(null, [nil, false]));
        Assert.Equal(42, classify.Invoke(null, [nil]));
        Assert.Equal(42, classify.Invoke(null, [consZero]));
        Assert.Equal(7, classify.Invoke(null, [cons]));
        Assert.Equal(42, classifyLocal.Invoke(null, [nil]));
        Assert.Equal(42, classifyLocal.Invoke(null, [consZero]));
        Assert.Equal(7, classifyLocal.Invoke(null, [cons]));
    }

    [Fact]
    public void EmitsMatchArmBlockExpressionAsSwitchStatement()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var xParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:rank:x", "name": "x", "type": {{intType}} }""";
        var yName =
            $$"""{ "kind": "Name", "symbolId": "local:fn:Demo:rank:y", "name": "y", "type": {{intType}} }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:rank",
              "name": "rank",
              "typeParams": [],
              "params": [
                { "symbolId": "param:fn:Demo:rank:x", "name": "x", "type": {{intType}} }
              ],
              "returnType": {{intType}},
              "body": {
                "kind": "Match",
                "target": {{xParam}},
                "arms": [
                  {
                    "pattern": { "kind": "IntLiteral", "value": "1" },
                    "body": {
                      "kind": "LocalLet",
                      "local": {
                        "symbolId": "local:fn:Demo:rank:y",
                        "name": "y",
                        "type": {{intType}},
                        "value": { "kind": "IntLiteral", "value": "2", "type": {{intType}} }
                      },
                      "body": {{yName}},
                      "type": {{intType}}
                    }
                  },
                  {
                    "pattern": { "kind": "Wildcard" },
                    "body": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                  }
                ],
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("switch (", code);
        Assert.Contains("default:", code);
        Assert.DoesNotContain("case var _:", code);
        Assert.DoesNotContain("non-exhaustive MoonBit match", code);
        Assert.DoesNotContain("UnreachableException", code);
        Assert.Equal(1, code.Split("switch (").Length - 1);
        Assert.DoesNotContain("System.Func", code);
        var assembly = Compile(code);
        var module = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(2, module.GetMethod("rank")!.Invoke(null, [1]));
        Assert.Equal(0, module.GetMethod("rank")!.Invoke(null, [3]));
    }

    [Fact]
    public void EmitsLiteralMatchAsSwitchExpression()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var stringType = """{ "kind": "Builtin", "name": "String" }""";
        var boolType = """{ "kind": "Builtin", "name": "Bool" }""";
        var intParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:int_rank:x", "name": "x", "type": {{intType}} }""";
        var stringParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:string_rank:x", "name": "x", "type": {{stringType}} }""";
        var boolParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:bool_rank:x", "name": "x", "type": {{boolType}} }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:int_rank",
              "name": "int_rank",
              "typeParams": [],
              "params": [{ "symbolId": "param:fn:Demo:int_rank:x", "name": "x", "type": {{intType}} }],
              "returnType": {{intType}},
              "body": {
                "kind": "Match",
                "target": {{intParam}},
                "arms": [
                  { "pattern": { "kind": "IntLiteral", "value": "0" }, "body": { "kind": "IntLiteral", "value": "10", "type": {{intType}} } },
                  { "pattern": { "kind": "IntLiteral", "value": "1" }, "body": { "kind": "IntLiteral", "value": "11", "type": {{intType}} } },
                  { "pattern": { "kind": "Wildcard" }, "body": { "kind": "IntLiteral", "value": "12", "type": {{intType}} } }
                ],
                "type": {{intType}}
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:string_rank",
              "name": "string_rank",
              "typeParams": [],
              "params": [{ "symbolId": "param:fn:Demo:string_rank:x", "name": "x", "type": {{stringType}} }],
              "returnType": {{intType}},
              "body": {
                "kind": "Match",
                "target": {{stringParam}},
                "arms": [
                  { "pattern": { "kind": "StringLiteral", "value": "a" }, "body": { "kind": "IntLiteral", "value": "1", "type": {{intType}} } },
                  { "pattern": { "kind": "Wildcard" }, "body": { "kind": "IntLiteral", "value": "0", "type": {{intType}} } }
                ],
                "type": {{intType}}
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:bool_rank",
              "name": "bool_rank",
              "typeParams": [],
              "params": [{ "symbolId": "param:fn:Demo:bool_rank:x", "name": "x", "type": {{boolType}} }],
              "returnType": {{intType}},
              "body": {
                "kind": "Match",
                "target": {{boolParam}},
                "arms": [
                  { "pattern": { "kind": "BoolLiteral", "value": true }, "body": { "kind": "IntLiteral", "value": "1", "type": {{intType}} } },
                  { "pattern": { "kind": "BoolLiteral", "value": false }, "body": { "kind": "IntLiteral", "value": "0", "type": {{intType}} } }
                ],
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("switch", code);
        Assert.Contains("\"a\"", code);
        var assembly = Compile(code);
        var module = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(10, module.GetMethod("int_rank")!.Invoke(null, [0]));
        Assert.Equal(12, module.GetMethod("int_rank")!.Invoke(null, [2]));
        Assert.Equal(1, module.GetMethod("string_rank")!.Invoke(null, ["a"]));
        Assert.Equal(0, module.GetMethod("string_rank")!.Invoke(null, ["b"]));
        Assert.Equal(1, module.GetMethod("bool_rank")!.Invoke(null, [true]));
        Assert.Equal(0, module.GetMethod("bool_rank")!.Invoke(null, [false]));
    }

    [Fact]
    public void EmitsRangeMatchAndIsPatternAsRelationalPatterns()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var boolType = """{ "kind": "Builtin", "name": "Bool" }""";
        var xParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:rank:x", "name": "x", "type": {{intType}} }""";
        var smallParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:small:x", "name": "x", "type": {{intType}} }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:rank",
              "name": "rank",
              "typeParams": [],
              "params": [{ "symbolId": "param:fn:Demo:rank:x", "name": "x", "type": {{intType}} }],
              "returnType": {{intType}},
              "body": {
                "kind": "Match",
                "target": {{xParam}},
                "arms": [
                  { "pattern": { "kind": "Range", "start": null, "end": "0", "inclusive": true }, "body": { "kind": "IntLiteral", "value": "1", "type": {{intType}} } },
                  { "pattern": { "kind": "Range", "start": "1", "end": "4", "inclusive": false }, "body": { "kind": "IntLiteral", "value": "2", "type": {{intType}} } },
                  { "pattern": { "kind": "Range", "start": "5", "end": null, "inclusive": false }, "body": { "kind": "IntLiteral", "value": "3", "type": {{intType}} } },
                  { "pattern": { "kind": "Wildcard" }, "body": { "kind": "IntLiteral", "value": "0", "type": {{intType}} } }
                ],
                "type": {{intType}}
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:small",
              "name": "small",
              "typeParams": [],
              "params": [{ "symbolId": "param:fn:Demo:small:x", "name": "x", "type": {{intType}} }],
              "returnType": {{boolType}},
              "body": {
                "kind": "IsPattern",
                "target": {{smallParam}},
                "pattern": { "kind": "Range", "start": "-3", "end": "3", "inclusive": true },
                "type": {{boolType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("<= 0", code);
        Assert.Contains(">= 1 and < 4", code);
        Assert.Contains("x is >= -3 and <= 3", code);
        var assembly = Compile(code);
        var module = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(1, module.GetMethod("rank")!.Invoke(null, [0]));
        Assert.Equal(2, module.GetMethod("rank")!.Invoke(null, [2]));
        Assert.Equal(0, module.GetMethod("rank")!.Invoke(null, [4]));
        Assert.Equal(3, module.GetMethod("rank")!.Invoke(null, [5]));
        Assert.Equal(true, module.GetMethod("small")!.Invoke(null, [-3]));
        Assert.Equal(false, module.GetMethod("small")!.Invoke(null, [4]));
    }

    [Fact]
    public void EmitsOptionMatchAsSwitchExpression()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var optionIntType =
            $$"""{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "Option" }, "args": [{{intType}}] }""";
        var xParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:value:x", "name": "x", "type": {{optionIntType}} }""";
        var oneParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:one:x", "name": "x", "type": {{optionIntType}} }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:value",
              "name": "value",
              "typeParams": [],
              "params": [{ "symbolId": "param:fn:Demo:value:x", "name": "x", "type": {{optionIntType}} }],
              "returnType": {{intType}},
              "body": {
                "kind": "Match",
                "target": {{xParam}},
                "arms": [
                  {
                    "pattern": {
                      "kind": "OptionSome",
                      "payload": {
                        "kind": "Binding",
                        "symbol": { "id": "local:fn:Demo:value:v", "kind": "Local", "name": "v", "type": {{intType}} }
                      }
                    },
                    "body": { "kind": "Name", "symbolId": "local:fn:Demo:value:v", "name": "v", "type": {{intType}} }
                  },
                  {
                    "pattern": { "kind": "OptionNone" },
                    "body": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                  }
                ],
                "type": {{intType}}
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:one",
              "name": "one",
              "typeParams": [],
              "params": [{ "symbolId": "param:fn:Demo:one:x", "name": "x", "type": {{optionIntType}} }],
              "returnType": {{intType}},
              "body": {
                "kind": "Match",
                "target": {{oneParam}},
                "arms": [
                  {
                    "pattern": {
                      "kind": "OptionSome",
                      "payload": { "kind": "IntLiteral", "value": "1" }
                    },
                    "body": { "kind": "IntLiteral", "value": "10", "type": {{intType}} }
                  },
                  {
                    "pattern": {
                      "kind": "OptionSome",
                      "payload": { "kind": "Wildcard" }
                    },
                    "body": { "kind": "IntLiteral", "value": "1", "type": {{intType}} }
                  },
                  {
                    "pattern": { "kind": "OptionNone" },
                    "body": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                  }
                ],
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("switch", code);
        Assert.Contains("{ IsSome: true, Value: var v }", code);
        Assert.Contains("{ IsSome: true, Value: 1 }", code);
        Assert.Contains("{ IsNone: true }", code);
        var assembly = Compile(code);
        var module = assembly.GetType("Generated.MoonBit.Demo", true)!;
        var some = typeof(MoonBitOption<int>).GetMethod("Some")!.Invoke(null, [7]);
        var someOne = typeof(MoonBitOption<int>).GetMethod("Some")!.Invoke(null, [1]);
        var none = typeof(MoonBitOption<int>).GetMethod("None")!.Invoke(null, []);

        Assert.Equal(7, module.GetMethod("value")!.Invoke(null, [some]));
        Assert.Equal(0, module.GetMethod("value")!.Invoke(null, [none]));
        Assert.Equal(10, module.GetMethod("one")!.Invoke(null, [someOne]));
        Assert.Equal(1, module.GetMethod("one")!.Invoke(null, [some]));
        Assert.Equal(0, module.GetMethod("one")!.Invoke(null, [none]));
    }

    [Fact]
    public void EmitsTupleMatchAsSwitchExpression()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var tupleType = $$"""{ "kind": "Tuple", "items": [{{intType}}, {{intType}}] }""";
        var pairParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:pick:pair", "name": "pair", "type": {{tupleType}} }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:pick",
              "name": "pick",
              "typeParams": [],
              "params": [{ "symbolId": "param:fn:Demo:pick:pair", "name": "pair", "type": {{tupleType}} }],
              "returnType": {{intType}},
              "body": {
                "kind": "Match",
                "target": {{pairParam}},
                "arms": [
                  {
                    "pattern": {
                      "kind": "Tuple",
                      "items": [
                        { "kind": "IntLiteral", "value": "0" },
                        {
                          "kind": "Binding",
                          "symbol": { "id": "local:fn:Demo:pick:y", "kind": "Local", "name": "y", "type": {{intType}} }
                        }
                      ]
                    },
                    "body": { "kind": "Name", "symbolId": "local:fn:Demo:pick:y", "name": "y", "type": {{intType}} }
                  },
                  {
                    "pattern": {
                      "kind": "Tuple",
                      "items": [
                        {
                          "kind": "Binding",
                          "symbol": { "id": "local:fn:Demo:pick:x", "kind": "Local", "name": "x", "type": {{intType}} }
                        },
                        { "kind": "Wildcard" }
                      ]
                    },
                    "body": { "kind": "Name", "symbolId": "local:fn:Demo:pick:x", "name": "x", "type": {{intType}} }
                  }
                ],
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("switch", code);
        Assert.Contains("(0, var y)", code);
        var assembly = Compile(code);
        var module = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(9, module.GetMethod("pick")!.Invoke(null, [ValueTuple.Create(0, 9)]));
        Assert.Equal(4, module.GetMethod("pick")!.Invoke(null, [ValueTuple.Create(4, 9)]));
    }

    [Fact]
    public void EmitsArrayMatchAsSwitchExpression()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var fixedArrayType =
            $$"""{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "FixedArray" }, "args": [{{intType}}] }""";
        var xsParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:pick:xs", "name": "xs", "type": {{fixedArrayType}} }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:pick",
              "name": "pick",
              "typeParams": [],
              "params": [{ "symbolId": "param:fn:Demo:pick:xs", "name": "xs", "type": {{fixedArrayType}} }],
              "returnType": {{intType}},
              "body": {
                "kind": "Match",
                "target": {{xsParam}},
                "arms": [
                  {
                    "pattern": { "kind": "Array", "items": [] },
                    "body": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                  },
                  {
                    "pattern": {
                      "kind": "Array",
                      "items": [
                        {
                          "kind": "Binding",
                          "symbol": { "id": "local:fn:Demo:pick:x", "kind": "Local", "name": "x", "type": {{intType}} }
                        }
                      ]
                    },
                    "body": { "kind": "Name", "symbolId": "local:fn:Demo:pick:x", "name": "x", "type": {{intType}} }
                  },
                  {
                    "pattern": {
                      "kind": "Array",
                      "items": [
                        {
                          "kind": "Binding",
                          "symbol": { "id": "local:fn:Demo:pick:x2", "kind": "Local", "name": "x", "type": {{intType}} }
                        },
                        {
                          "kind": "Binding",
                          "symbol": { "id": "local:fn:Demo:pick:y", "kind": "Local", "name": "y", "type": {{intType}} }
                        }
                      ]
                    },
                    "body": {
                      "kind": "Binary",
                      "op": "+",
                      "left": { "kind": "Name", "symbolId": "local:fn:Demo:pick:x2", "name": "x", "type": {{intType}} },
                      "right": { "kind": "Name", "symbolId": "local:fn:Demo:pick:y", "name": "y", "type": {{intType}} },
                      "selectedFunctionId": "core:Int::op_add",
                      "selectedIntrinsic": "%i32_add",
                      "type": {{intType}}
                    }
                  },
                  {
                    "pattern": { "kind": "Wildcard" },
                    "body": { "kind": "IntLiteral", "value": "-1", "type": {{intType}} }
                  }
                ],
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("[]", code);
        Assert.Contains("[var x]", code);
        var assembly = Compile(code);
        var module = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(0, module.GetMethod("pick")!.Invoke(null, [Array.Empty<int>()]));
        Assert.Equal(7, module.GetMethod("pick")!.Invoke(null, [new[] { 7 }]));
        Assert.Equal(11, module.GetMethod("pick")!.Invoke(null, [new[] { 4, 7 }]));
        Assert.Equal(-1, module.GetMethod("pick")!.Invoke(null, [new[] { 1, 2, 3 }]));
    }

    [Fact]
    public void EmitsArrayRestPatternsAsListPatterns()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var boolType = """{ "kind": "Builtin", "name": "Bool" }""";
        var fixedArrayType =
            $$"""{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "FixedArray" }, "args": [{{intType}}] }""";
        var arrayViewType =
            $$"""{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "ArrayView" }, "args": [{{intType}}] }""";
        var xsHead =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:head:xs", "name": "xs", "type": {{fixedArrayType}} }""";
        var xsLast =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:last:xs", "name": "xs", "type": {{fixedArrayType}} }""";
        var xsEdges =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:edges:xs", "name": "xs", "type": {{fixedArrayType}} }""";
        var xsHasTail =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:has_tail:xs", "name": "xs", "type": {{fixedArrayType}} }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:head",
              "name": "head",
              "typeParams": [],
              "params": [{ "symbolId": "param:fn:Demo:head:xs", "name": "xs", "type": {{fixedArrayType}} }],
              "returnType": {{intType}},
              "body": {
                "kind": "Match",
                "target": {{xsHead}},
                "arms": [
                  {
                    "pattern": {
                      "kind": "Array",
                      "items": [
                        {
                          "kind": "Binding",
                          "symbol": { "id": "local:fn:Demo:head:x", "kind": "Local", "name": "x", "type": {{intType}} }
                        }
                      ],
                      "rest": { "symbol": null },
                      "suffix": []
                    },
                    "body": { "kind": "Name", "symbolId": "local:fn:Demo:head:x", "name": "x", "type": {{intType}} }
                  },
                  {
                    "pattern": { "kind": "Wildcard" },
                    "body": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                  }
                ],
                "type": {{intType}}
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:last",
              "name": "last",
              "typeParams": [],
              "params": [{ "symbolId": "param:fn:Demo:last:xs", "name": "xs", "type": {{fixedArrayType}} }],
              "returnType": {{intType}},
              "body": {
                "kind": "Match",
                "target": {{xsLast}},
                "arms": [
                  {
                    "pattern": {
                      "kind": "Array",
                      "items": [],
                      "rest": { "symbol": null },
                      "suffix": [
                        {
                          "kind": "Binding",
                          "symbol": { "id": "local:fn:Demo:last:x", "kind": "Local", "name": "x", "type": {{intType}} }
                        }
                      ]
                    },
                    "body": { "kind": "Name", "symbolId": "local:fn:Demo:last:x", "name": "x", "type": {{intType}} }
                  },
                  {
                    "pattern": { "kind": "Wildcard" },
                    "body": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                  }
                ],
                "type": {{intType}}
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:edges",
              "name": "edges",
              "typeParams": [],
              "params": [{ "symbolId": "param:fn:Demo:edges:xs", "name": "xs", "type": {{fixedArrayType}} }],
              "returnType": {{intType}},
              "body": {
                "kind": "Match",
                "target": {{xsEdges}},
                "arms": [
                  {
                    "pattern": {
                      "kind": "Array",
                      "items": [
                        {
                          "kind": "Binding",
                          "symbol": { "id": "local:fn:Demo:edges:x", "kind": "Local", "name": "x", "type": {{intType}} }
                        }
                      ],
                      "rest": {
                        "symbol": {
                          "id": "local:fn:Demo:edges:rest",
                          "kind": "Local",
                          "name": "rest",
                          "type": {{arrayViewType}}
                        }
                      },
                      "suffix": [
                        {
                          "kind": "Binding",
                          "symbol": { "id": "local:fn:Demo:edges:y", "kind": "Local", "name": "y", "type": {{intType}} }
                        }
                      ]
                    },
                    "body": {
                      "kind": "Binary",
                      "op": "+",
                      "left": { "kind": "Name", "symbolId": "local:fn:Demo:edges:x", "name": "x", "type": {{intType}} },
                      "right": { "kind": "Name", "symbolId": "local:fn:Demo:edges:y", "name": "y", "type": {{intType}} },
                      "selectedFunctionId": "core:Int::op_add",
                      "selectedIntrinsic": "%i32_add",
                      "type": {{intType}}
                    }
                  },
                  {
                    "pattern": { "kind": "Wildcard" },
                    "body": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                  }
                ],
                "type": {{intType}}
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:has_tail",
              "name": "has_tail",
              "typeParams": [],
              "params": [{ "symbolId": "param:fn:Demo:has_tail:xs", "name": "xs", "type": {{fixedArrayType}} }],
              "returnType": {{boolType}},
              "body": {
                "kind": "IsPattern",
                "target": {{xsHasTail}},
                "pattern": {
                  "kind": "Array",
                  "items": [{ "kind": "Wildcard" }],
                  "rest": {
                    "symbol": {
                      "id": "local:fn:Demo:has_tail:rest",
                      "kind": "Local",
                      "name": "rest",
                      "type": {{arrayViewType}}
                    }
                  },
                  "suffix": []
                },
                "type": {{boolType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("[var x, ..]", code);
        Assert.Contains("[.., var x]", code);
        Assert.Contains("[var x, .., var y]", code);
        Assert.Contains("xs is [_, ..]", code);
        var assembly = Compile(code);
        var module = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(0, module.GetMethod("head")!.Invoke(null, [Array.Empty<int>()]));
        Assert.Equal(7, module.GetMethod("head")!.Invoke(null, [new[] { 7 }]));
        Assert.Equal(7, module.GetMethod("head")!.Invoke(null, [new[] { 7, 8 }]));
        Assert.Equal(0, module.GetMethod("last")!.Invoke(null, [Array.Empty<int>()]));
        Assert.Equal(8, module.GetMethod("last")!.Invoke(null, [new[] { 7, 8 }]));
        Assert.Equal(0, module.GetMethod("edges")!.Invoke(null, [new[] { 7 }]));
        Assert.Equal(15, module.GetMethod("edges")!.Invoke(null, [new[] { 7, 1, 8 }]));
        Assert.Equal(false, module.GetMethod("has_tail")!.Invoke(null, [Array.Empty<int>()]));
        Assert.Equal(true, module.GetMethod("has_tail")!.Invoke(null, [new[] { 1 }]));
    }

    [Fact]
    public void EmitsArrayRestBindingAsArrayViewInSwitchStatement()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var fixedArrayType =
            $$"""{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "FixedArray" }, "args": [{{intType}}] }""";
        var arrayViewType =
            $$"""{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "ArrayView" }, "args": [{{intType}}] }""";
        var xsParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:tail:xs", "name": "xs", "type": {{fixedArrayType}} }""";
        var restName =
            $$"""{ "kind": "Name", "symbolId": "local:fn:Demo:tail:rest", "name": "rest", "type": {{arrayViewType}} }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:keep",
              "name": "keep",
              "typeParams": [],
              "params": [{ "symbolId": "param:fn:Demo:keep:rest", "name": "rest", "type": {{arrayViewType}} }],
              "returnType": { "kind": "Builtin", "name": "Bool" },
              "body": { "kind": "BoolLiteral", "value": true, "type": { "kind": "Builtin", "name": "Bool" } }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:tail",
              "name": "tail",
              "typeParams": [],
              "params": [{ "symbolId": "param:fn:Demo:tail:xs", "name": "xs", "type": {{fixedArrayType}} }],
              "returnType": {{arrayViewType}},
              "body": {
                "kind": "Match",
                "target": {{xsParam}},
                "arms": [
                  {
                    "pattern": {
                      "kind": "Array",
                      "items": [],
                      "rest": {
                        "symbol": {
                          "id": "local:fn:Demo:tail:rest",
                          "kind": "Local",
                          "name": "rest",
                          "type": {{arrayViewType}}
                        }
                      },
                      "suffix": []
                    },
                    "condition": {
                      "kind": "Call",
                      "functionId": "fn:Demo:keep",
                      "args": [{{restName}}],
                      "type": { "kind": "Builtin", "name": "Bool" }
                    },
                    "body": {
                      "kind": "Name",
                      "symbolId": "local:fn:Demo:tail:rest",
                      "name": "rest",
                      "type": {{arrayViewType}}
                    }
                  },
                  {
                    "pattern": {
                      "kind": "Array",
                      "items": [],
                      "rest": {
                        "symbol": {
                          "id": "local:fn:Demo:tail:rest",
                          "kind": "Local",
                          "name": "rest",
                          "type": {{arrayViewType}}
                        }
                      },
                      "suffix": []
                    },
                    "body": {
                      "kind": "Name",
                      "symbolId": "local:fn:Demo:tail:rest",
                      "name": "rest",
                      "type": {{arrayViewType}}
                    }
                  }
                ],
                "type": {{arrayViewType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("switch (__moonbitMatch", code);
        Assert.Contains("case [..]:", code);
        Assert.Contains(
            "new MoonBitArrayView<int>(__moonbitMatch0, 0, __moonbitMatch0.Length - 0)",
            code
        );
        Assert.Contains("if (Demo.keep(rest))", code);
        var assembly = Compile(code);
        var module = assembly.GetType("Generated.MoonBit.Demo", true)!;

        var result = module.GetMethod("tail")!.Invoke(null, [new[] { 1, 2, 3 }])!;
        Assert.Equal(3, result.GetType().GetProperty("Length")!.GetValue(result));
    }

    [Fact]
    public void EmitsUnaryMinusAndIsPatternExpressions()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var boolType = """{ "kind": "Builtin", "name": "Bool" }""";
        var fixedArrayType =
            $$"""{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "FixedArray" }, "args": [{{intType}}] }""";
        var xParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:is_one:x", "name": "x", "type": {{intType}} }""";
        var xsParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:is_single:xs", "name": "xs", "type": {{fixedArrayType}} }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:neg_one",
              "name": "neg_one",
              "typeParams": [],
              "params": [],
              "returnType": {{intType}},
              "body": {
                "kind": "Unary",
                "op": "-",
                "value": { "kind": "IntLiteral", "value": "1", "type": {{intType}} },
                "selectedFunctionId": "builtin:trait:moonbitlang/core/builtin:Neg:neg:Int",
                "selectedIntrinsic": "%i32_neg",
                "type": {{intType}}
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:is_one",
              "name": "is_one",
              "typeParams": [],
              "params": [{ "symbolId": "param:fn:Demo:is_one:x", "name": "x", "type": {{intType}} }],
              "returnType": {{boolType}},
              "body": {
                "kind": "IsPattern",
                "target": {{xParam}},
                "pattern": { "kind": "IntLiteral", "value": "1" },
                "type": {{boolType}}
              }
            },
            {
              "kind": "Function",
              "symbolId": "fn:Demo:is_single",
              "name": "is_single",
              "typeParams": [],
              "params": [{ "symbolId": "param:fn:Demo:is_single:xs", "name": "xs", "type": {{fixedArrayType}} }],
              "returnType": {{boolType}},
              "body": {
                "kind": "IsPattern",
                "target": {{xsParam}},
                "pattern": {
                  "kind": "Array",
                  "items": [
                    {
                      "kind": "Binding",
                      "symbol": { "id": "local:fn:Demo:is_single:x", "kind": "Local", "name": "x", "type": {{intType}} }
                    }
                  ]
                },
                "type": {{boolType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("(-1)", code);
        Assert.Contains("x is 1", code);
        Assert.Contains("xs is [var x]", code);
        var assembly = Compile(code);
        var module = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(-1, module.GetMethod("neg_one")!.Invoke(null, []));
        Assert.Equal(true, module.GetMethod("is_one")!.Invoke(null, [1]));
        Assert.Equal(false, module.GetMethod("is_one")!.Invoke(null, [2]));
        Assert.Equal(true, module.GetMethod("is_single")!.Invoke(null, [new[] { 7 }]));
        Assert.Equal(false, module.GetMethod("is_single")!.Invoke(null, [new[] { 7, 8 }]));
    }

    [Fact]
    public void EmitsNestedBinaryPatternTestsWithPreservedPrecedence()
    {
        var boolType = """{ "kind": "Builtin", "name": "Bool" }""";
        var tokenKindType = """
            {
              "kind": "Declared",
              "symbol": {
                "id": "type:pkg:Demo:Demo:TokenKind",
                "packageId": "pkg:Demo",
                "modulePath": "Demo",
                "name": "TokenKind"
              },
              "args": []
            }
            """;
        var firstParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:is_struct:first", "name": "first", "type": {{tokenKindType}} }""";
        var secondParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:is_struct:second", "name": "second", "type": {{tokenKindType}} }""";
        var json = $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [
                {
                  "kind": "Enum",
                  "symbol": {
                    "id": "type:pkg:Demo:Demo:TokenKind",
                    "packageId": "pkg:Demo",
                    "modulePath": "Demo",
                    "name": "TokenKind"
                  },
                  "typeParams": [],
                  "variants": [
                    { "id": "type:pkg:Demo:Demo:TokenKind:variant:Identifier", "name": "Identifier", "payloads": [] },
                    { "id": "type:pkg:Demo:Demo:TokenKind:variant:Colon", "name": "Colon", "payloads": [] },
                    { "id": "type:pkg:Demo:Demo:TokenKind:variant:Comma", "name": "Comma", "payloads": [] },
                    { "id": "type:pkg:Demo:Demo:TokenKind:variant:RBrace", "name": "RBrace", "payloads": [] }
                  ]
                }
              ],
              "traits": [],
              "functions": [
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:is_struct",
                  "name": "is_struct",
                  "typeParams": [],
                  "params": [
                    { "symbolId": "param:fn:Demo:is_struct:first", "name": "first", "type": {{tokenKindType}} },
                    { "symbolId": "param:fn:Demo:is_struct:second", "name": "second", "type": {{tokenKindType}} }
                  ],
                  "returnType": {{boolType}},
                  "body": {
                    "kind": "Binary",
                    "op": "&&",
                    "left": {
                      "kind": "IsPattern",
                      "target": {{firstParam}},
                      "pattern": {
                        "kind": "EnumCase",
                        "typeId": "type:pkg:Demo:Demo:TokenKind",
                        "name": "Identifier",
                        "payloads": []
                      },
                      "type": {{boolType}}
                    },
                    "right": {
                      "kind": "IsPattern",
                      "target": {{secondParam}},
                      "pattern": {
                        "kind": "Or",
                        "alternatives": [
                          { "kind": "EnumCase", "typeId": "type:pkg:Demo:Demo:TokenKind", "name": "Colon", "payloads": [] },
                          { "kind": "EnumCase", "typeId": "type:pkg:Demo:Demo:TokenKind", "name": "Comma", "payloads": [] },
                          { "kind": "EnumCase", "typeId": "type:pkg:Demo:Demo:TokenKind", "name": "RBrace", "payloads": [] }
                        ]
                      },
                      "type": {{boolType}}
                    },
                    "type": {{boolType}}
                  }
                }
              ],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);
        var assembly = Compile(code, "namespace Generated.MoonBit.Runtime { }");
        var tokenKind = assembly.GetTypes().Single(type => type.Name == "TokenKind");
        var method = assembly
            .GetTypes()
            .Select(type =>
                type.GetMethod(
                    "is_struct",
                    BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static
                )
            )
            .First(method => method is not null)!;

        var identifier = Enum.Parse(tokenKind, "Identifier");
        var colon = Enum.Parse(tokenKind, "Colon");
        var rBrace = Enum.Parse(tokenKind, "RBrace");

        Assert.Equal(true, method.Invoke(null, [identifier, colon]));
        Assert.Equal(true, method.Invoke(null, [identifier, rBrace]));
        Assert.Equal(false, method.Invoke(null, [colon, rBrace]));
    }

    [Fact]
    public void EmitsPayloadEnumIsPatternAsDirectTagAndPayloadTest()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var boolType = """{ "kind": "Builtin", "name": "Bool" }""";
        var lstType = """
            {
              "kind": "Declared",
              "symbol": {
                "id": "type:pkg:Demo:Demo:Lst",
                "packageId": "pkg:Demo",
                "modulePath": "Demo",
                "name": "Lst"
              },
              "args": []
            }
            """;
        var xsParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:is_cons_one:xs", "name": "xs", "type": {{lstType}} }""";
        var json = $$"""
            {
              "schema": "moonbit2csharp.vnext.semantic-ir/0.1",
              "module": { "name": "Demo" },
              "symbols": [],
              "types": [
                {
                  "kind": "Enum",
                  "symbol": {
                    "id": "type:pkg:Demo:Demo:Lst",
                    "packageId": "pkg:Demo",
                    "modulePath": "Demo",
                    "name": "Lst"
                  },
                  "typeParams": [],
                  "variants": [
                    { "id": "type:pkg:Demo:Demo:Lst:variant:Nil", "name": "Nil", "payloads": [] },
                    { "id": "type:pkg:Demo:Demo:Lst:variant:Cons", "name": "Cons", "payloads": [{{intType}}, {{lstType}}] }
                  ]
                }
              ],
              "traits": [],
              "functions": [
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:is_cons_one",
                  "name": "is_cons_one",
                  "typeParams": [],
                  "params": [{ "symbolId": "param:fn:Demo:is_cons_one:xs", "name": "xs", "type": {{lstType}} }],
                  "returnType": {{boolType}},
                  "body": {
                    "kind": "IsPattern",
                    "target": {{xsParam}},
                    "pattern": {
                      "kind": "EnumCase",
                      "typeId": "type:pkg:Demo:Demo:Lst",
                      "variantId": "type:pkg:Demo:Demo:Lst:variant:Cons",
                      "name": "Cons",
                      "payloads": [
                        { "kind": "IntLiteral", "value": "1" },
                        { "kind": "Wildcard" }
                      ]
                    },
                    "type": {{boolType}}
                  }
                }
              ],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);
        Assert.Contains("Kind ==", code);
        Assert.Contains("Lst.Tag.Cons", code);
        Assert.Contains("System.Runtime.CompilerServices.Unsafe.As<", code);
        Assert.Contains("Lst.ConsVariant>", code);
        var assembly = Compile(code);
        var module = assembly.GetType("Generated.MoonBit.Demo", true)!;
        var lst = GeneratedType(assembly, "Lst", "Demo");
        var nil = lst.GetField("Nil")!.GetValue(null)!;
        var cons = lst.GetMethod("Cons")!;

        Assert.Equal(
            true,
            module.GetMethod("is_cons_one")!.Invoke(null, [cons.Invoke(null, [1, nil])])
        );
        Assert.Equal(
            false,
            module.GetMethod("is_cons_one")!.Invoke(null, [cons.Invoke(null, [2, nil])])
        );
        Assert.Equal(false, module.GetMethod("is_cons_one")!.Invoke(null, [nil]));
    }

    [Fact]
    public void EmitsIfPatternBindingWithThenBranchScope()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var fixedArrayType =
            $$"""{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "FixedArray" }, "args": [{{intType}}] }""";
        var xsParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:use_array:xs", "name": "xs", "type": {{fixedArrayType}} }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:use_array",
              "name": "use_array",
              "typeParams": [],
              "params": [{ "symbolId": "param:fn:Demo:use_array:xs", "name": "xs", "type": {{fixedArrayType}} }],
              "returnType": {{intType}},
              "body": {
                "kind": "If",
                "condition": {
                  "kind": "IsPattern",
                  "target": {{xsParam}},
                  "pattern": {
                    "kind": "Array",
                    "items": [
                      {
                        "kind": "Binding",
                        "symbol": { "id": "local:fn:Demo:use_array:x", "kind": "Local", "name": "x", "type": {{intType}} }
                      }
                    ]
                  },
                  "type": { "kind": "Builtin", "name": "Bool" }
                },
                "then": { "kind": "Name", "symbolId": "local:fn:Demo:use_array:x", "name": "x", "type": {{intType}} },
                "else": { "kind": "IntLiteral", "value": "0", "type": {{intType}} },
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("xs is [var x] ? x : 0", code);
        var assembly = Compile(code);
        var module = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(7, module.GetMethod("use_array")!.Invoke(null, [new[] { 7 }]));
        Assert.Equal(0, module.GetMethod("use_array")!.Invoke(null, [new[] { 7, 8 }]));
    }

    [Fact]
    public void EmitsOrMatchAsSwitchExpression()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var relationType = """
            {
              "kind": "Declared",
              "symbol": { "id": "type:pkg:Demo:Demo:Relation", "packageId": "pkg:Demo", "modulePath": "Demo", "name": "Relation" },
              "args": []
            }
            """;
        var relationParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:rank:r", "name": "r", "type": {{relationType}} }""";
        var intParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:int_rank:x", "name": "x", "type": {{intType}} }""";
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
                    { "id": "type:pkg:Demo:Demo:Relation:variant:Greater", "name": "Greater", "payloads": [] },
                    { "id": "type:pkg:Demo:Demo:Relation:variant:Equal", "name": "Equal", "payloads": [] }
                  ]
                }
              ],
              "traits": [],
              "functions": [
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:rank",
                  "name": "rank",
                  "typeParams": [],
                  "params": [{ "symbolId": "param:fn:Demo:rank:r", "name": "r", "type": {{relationType}} }],
                  "returnType": {{intType}},
                  "body": {
                    "kind": "Match",
                    "target": {{relationParam}},
                    "arms": [
                      {
                        "pattern": {
                          "kind": "Or",
                          "alternatives": [
                            {
                              "kind": "EnumCase",
                              "typeId": "type:pkg:Demo:Demo:Relation",
                              "variantId": "type:pkg:Demo:Demo:Relation:variant:Smaller",
                              "name": "Smaller",
                              "payloads": []
                            },
                            {
                              "kind": "EnumCase",
                              "typeId": "type:pkg:Demo:Demo:Relation",
                              "variantId": "type:pkg:Demo:Demo:Relation:variant:Equal",
                              "name": "Equal",
                              "payloads": []
                            }
                          ]
                        },
                        "body": { "kind": "IntLiteral", "value": "1", "type": {{intType}} }
                      },
                      {
                        "pattern": { "kind": "Wildcard" },
                        "body": { "kind": "IntLiteral", "value": "2", "type": {{intType}} }
                      }
                    ],
                    "type": {{intType}}
                  }
                },
                {
                  "kind": "Function",
                  "symbolId": "fn:Demo:int_rank",
                  "name": "int_rank",
                  "typeParams": [],
                  "params": [{ "symbolId": "param:fn:Demo:int_rank:x", "name": "x", "type": {{intType}} }],
                  "returnType": {{intType}},
                  "body": {
                    "kind": "Match",
                    "target": {{intParam}},
                    "arms": [
                      {
                        "pattern": {
                          "kind": "Or",
                          "alternatives": [
                            { "kind": "IntLiteral", "value": "0" },
                            { "kind": "IntLiteral", "value": "1" }
                          ]
                        },
                        "body": { "kind": "IntLiteral", "value": "10", "type": {{intType}} }
                      },
                      {
                        "pattern": { "kind": "Wildcard" },
                        "body": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                      }
                    ],
                    "type": {{intType}}
                  }
                }
              ],
              "globals": [],
              "diagnostics": []
            }
            """;

        var code = VNextBackend.Emit(json);
        Assert.Contains("Relation.Smaller", code);
        Assert.Contains("Relation.Equal", code);
        Assert.Contains("0 or 1", code);
        var assembly = Compile(code);
        var module = assembly.GetType("Generated.MoonBit.Demo", true)!;
        var relation = GeneratedType(assembly, "Relation", "Demo");

        Assert.Equal(1, module.GetMethod("rank")!.Invoke(null, [Enum.Parse(relation, "Smaller")]));
        Assert.Equal(1, module.GetMethod("rank")!.Invoke(null, [Enum.Parse(relation, "Equal")]));
        Assert.Equal(2, module.GetMethod("rank")!.Invoke(null, [Enum.Parse(relation, "Greater")]));
        Assert.Equal(10, module.GetMethod("int_rank")!.Invoke(null, [0]));
        Assert.Equal(10, module.GetMethod("int_rank")!.Invoke(null, [1]));
        Assert.Equal(0, module.GetMethod("int_rank")!.Invoke(null, [2]));
    }

    [Fact]
    public void EmitsMatchArmConditionAsSwitchWhen()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var boolType = """{ "kind": "Builtin", "name": "Bool" }""";
        var xParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:f:x", "name": "x", "type": {{intType}} }""";
        var keepParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:f:keep", "name": "keep", "type": {{boolType}} }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:f",
              "name": "f",
              "typeParams": [],
              "params": [
                { "symbolId": "param:fn:Demo:f:x", "name": "x", "type": {{intType}} },
                { "symbolId": "param:fn:Demo:f:keep", "name": "keep", "type": {{boolType}} }
              ],
              "returnType": {{intType}},
              "body": {
                "kind": "Match",
                "target": {{xParam}},
                "arms": [
                  {
                    "pattern": {
                      "kind": "Binding",
                      "symbol": { "id": "local:fn:Demo:f:y", "kind": "Local", "name": "y", "type": {{intType}} }
                    },
                    "condition": {{keepParam}},
                    "body": {
                      "kind": "LocalLet",
                      "local": {
                        "symbolId": "local:fn:Demo:f:z",
                        "name": "z",
                        "type": {{intType}},
                        "value": { "kind": "Name", "symbolId": "local:fn:Demo:f:y", "name": "y", "type": {{intType}} }
                      },
                      "body": { "kind": "Name", "symbolId": "local:fn:Demo:f:z", "name": "z", "type": {{intType}} },
                      "type": {{intType}}
                    }
                  },
                  {
                    "pattern": { "kind": "Wildcard" },
                    "body": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                  }
                ],
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("var y when keep", code);
        Assert.Equal(1, code.Split("switch (").Length - 1);
        Assert.DoesNotContain("System.Func", code);
        var assembly = Compile(code);
        var module = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(7, module.GetMethod("f")!.Invoke(null, [7, true]));
        Assert.Equal(0, module.GetMethod("f")!.Invoke(null, [7, false]));
    }

    [Fact]
    public void EmitsGuardedWildcardMatchAsSwitchWhen()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var boolType = """{ "kind": "Builtin", "name": "Bool" }""";
        var xParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:f:x", "name": "x", "type": {{intType}} }""";
        var keepParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:f:keep", "name": "keep", "type": {{boolType}} }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:f",
              "name": "f",
              "typeParams": [],
              "params": [
                { "symbolId": "param:fn:Demo:f:x", "name": "x", "type": {{intType}} },
                { "symbolId": "param:fn:Demo:f:keep", "name": "keep", "type": {{boolType}} }
              ],
              "returnType": {{intType}},
              "body": {
                "kind": "Match",
                "target": {{xParam}},
                "arms": [
                  {
                    "pattern": { "kind": "Wildcard" },
                    "condition": {{keepParam}},
                    "body": {
                      "kind": "LocalLet",
                      "local": {
                        "symbolId": "local:fn:Demo:f:one",
                        "name": "one",
                        "type": {{intType}},
                        "value": { "kind": "IntLiteral", "value": "1", "type": {{intType}} }
                      },
                      "body": { "kind": "Name", "symbolId": "local:fn:Demo:f:one", "name": "one", "type": {{intType}} },
                      "type": {{intType}}
                    }
                  },
                  {
                    "pattern": { "kind": "Wildcard" },
                    "body": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                  }
                ],
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("case var _ when keep", code);
        Assert.Equal(1, code.Split("switch (").Length - 1);
        var assembly = Compile(code);
        var module = assembly.GetType("Generated.MoonBit.Demo", true)!;

        Assert.Equal(1, module.GetMethod("f")!.Invoke(null, [7, true]));
        Assert.Equal(0, module.GetMethod("f")!.Invoke(null, [7, false]));
    }

    [Fact]
    public void SuffixesDuplicatePatternBindingsAcrossNestedScopes()
    {
        var intType = """{ "kind": "Builtin", "name": "Int" }""";
        var optionIntType =
            $$"""{ "kind": "Apply", "constructor": { "kind": "Builtin", "name": "Option" }, "args": [{{intType}}] }""";
        var xParam =
            $$"""{ "kind": "Name", "symbolId": "param:fn:Demo:f:x", "name": "x", "type": {{optionIntType}} }""";
        var json = ModuleJson(
            $$"""
            {
              "kind": "Function",
              "symbolId": "fn:Demo:f",
              "name": "f",
              "typeParams": [],
              "params": [
                { "symbolId": "param:fn:Demo:f:x", "name": "x", "type": {{optionIntType}} }
              ],
              "returnType": {{intType}},
              "body": {
                "kind": "Match",
                "target": {{xParam}},
                "arms": [
                  {
                    "pattern": {
                      "kind": "OptionSome",
                      "payload": {
                        "kind": "Binding",
                        "symbol": { "id": "local:fn:Demo:f:outer:symbol", "kind": "Local", "name": "symbol", "type": {{intType}} }
                      }
                    },
                    "body": {
                      "kind": "Match",
                      "target": {{xParam}},
                      "arms": [
                        {
                          "pattern": {
                            "kind": "OptionSome",
                            "payload": {
                              "kind": "Binding",
                              "symbol": { "id": "local:fn:Demo:f:inner:symbol", "kind": "Local", "name": "symbol", "type": {{intType}} }
                            }
                          },
                          "body": { "kind": "Name", "symbolId": "local:fn:Demo:f:inner:symbol", "name": "symbol", "type": {{intType}} }
                        },
                        {
                          "pattern": { "kind": "Wildcard" },
                          "body": { "kind": "Name", "symbolId": "local:fn:Demo:f:outer:symbol", "name": "symbol", "type": {{intType}} }
                        }
                      ],
                      "type": {{intType}}
                    }
                  },
                  {
                    "pattern": { "kind": "Wildcard" },
                    "body": { "kind": "IntLiteral", "value": "0", "type": {{intType}} }
                  }
                ],
                "type": {{intType}}
              }
            }
            """
        );

        var code = VNextBackend.Emit(json);
        Assert.Contains("symbol__", code, StringComparison.Ordinal);
        Assert.DoesNotContain("var symbol =", code, StringComparison.Ordinal);
    }
}
