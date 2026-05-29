using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace MoonBit2CSharp.Backend;

public static class IrReader
{
    private static readonly JsonDocumentOptions DocumentOptions = new() { MaxDepth = 256 };

    public static ModuleIr ReadModule(string jsonText)
    {
        var json =
            JsonNode.Parse(jsonText, documentOptions: DocumentOptions)
            ?? throw new InvalidOperationException("invalid JSON");
        var schema =
            json["schema"]?.GetValue<string>()
            ?? throw new InvalidOperationException("missing IR schema");
        if (schema != "moonbit-csharp-ir/0.3")
            throw new NotSupportedException($"IR schema not supported: {schema}");

        RejectErrorDiagnostics(json["diagnostics"]);
        var module = json["module"] ?? throw new InvalidOperationException("missing module");
        var name = module["name"]!.GetValue<string>();
        var decls = json["declarations"]!.AsArray().Select(ReadDecl).ToList();
        return new(name, decls);
    }

    private static void RejectErrorDiagnostics(JsonNode? diagnostics)
    {
        if (diagnostics is null)
            throw new InvalidOperationException("missing diagnostics");

        foreach (var diagnostic in diagnostics.AsArray())
            if (diagnostic?["severity"]?.GetValue<string>() == "error")
            {
                var code = diagnostic["code"]?.GetValue<string>() ?? "typed-ir.error";
                var message = diagnostic["message"]?.GetValue<string>() ?? "";
                throw new InvalidOperationException(
                    $"IR contains error diagnostic {code}: {message}"
                );
            }
    }

    public static ModuleIr ReadModule(JsonNode node)
    {
        RejectErrorDiagnostics(node["diagnostics"]);
        var module = node["module"] ?? throw new InvalidOperationException("missing module");
        var name = module["name"]!.GetValue<string>();
        var decls = node["declarations"]!.AsArray().Select(ReadDecl).ToList();
        return new(name, decls);
    }

    private static DeclIr ReadDecl(JsonNode? node)
    {
        if (node is null)
            throw new InvalidOperationException("null decl");

        var kind = node["kind"]!.GetValue<string>();
        return kind switch
        {
            "GlobalLetDecl" => new GlobalLetDeclIr(
                ReadSymbol(node["symbol"]!, "Global"),
                node["mutable"]?.GetValue<bool>() ?? false,
                ReadType(node["declaredType"]!),
                ReadExpr(node["value"]!)
            ),
            "FnDecl" => new FnDeclIr(
                ReadSymbol(node["symbol"]!, "Function"),
                ReadTypeParams(node["typeParams"]),
                node["parameters"]!.AsArray().Select(ReadParam).ToList(),
                ReadType(node["returnType"]!),
                ReadExpr(node["body"]!),
                node["raises"]?.GetValue<bool>() ?? false,
                node["errorType"] is { } fnErrorType ? ReadType(fnErrorType) : null
            ),
            "ExternDecl" => new ExternDeclIr(
                ReadSymbol(node["symbol"]!, "Function"),
                ReadTypeParams(node["typeParams"]),
                node["parameters"]!.AsArray().Select(ReadParam).ToList(),
                ReadType(node["returnType"]!),
                node["externalName"]!.GetValue<string>(),
                node["raises"]?.GetValue<bool>() ?? false,
                node["language"]?.GetValue<string>() ?? "intrinsic",
                node["errorType"] is { } externErrorType ? ReadType(externErrorType) : null
            ),
            "StructDecl" => new StructDeclIr(
                ReadSymbol(node["symbol"]!, "Struct"),
                node["typeParams"]?.AsArray().Select(x => x!.GetValue<string>()).ToList() ?? [],
                node["fields"]!.AsArray().Select(ReadField).ToList(),
                ReadStringArray(node["derives"])
            ),
            "EnumDecl" => new EnumDeclIr(
                ReadSymbol(node["symbol"]!, "Enum"),
                node["typeParams"]?.AsArray().Select(x => x!.GetValue<string>()).ToList() ?? [],
                node["variants"]!.AsArray().Select(ReadEnumVariant).ToList(),
                ReadStringArray(node["derives"]),
                node["isError"]?.GetValue<bool>() ?? false
            ),
            "ExternalTypeDecl" => new ExternalTypeDeclIr(
                ReadSymbol(node["symbol"]!, "Type"),
                node["typeParams"]?.AsArray().Select(x => x!.GetValue<string>()).ToList() ?? [],
                node["language"]?.GetValue<string>() ?? "",
                node["externalName"]?.GetValue<string>() ?? ""
            ),
            "TraitDecl" => new TraitDeclIr(
                ReadSymbol(node["symbol"]!, "Trait"),
                node["methods"]!.AsArray().Select(ReadTraitMethod).ToList()
            ),
            "TraitImplDecl" => new TraitImplDeclIr(
                ReadSymbol(node["impl"]!, "Impl"),
                node["traitName"]!.GetValue<string>(),
                ReadType(node["receiverType"]!),
                node["methodName"]!.GetValue<string>(),
                ReadSymbol(node["function"]!, "Function"),
                ReadType(node["returnType"]!),
                node["externalName"]?.GetValue<string>() ?? "",
                ReadTypeParams(node["typeParams"]),
                node["isDefault"]?.GetValue<bool>() ?? false
            ),
            _ => throw new NotSupportedException($"decl kind not supported: {kind}"),
        };
    }

    private static IReadOnlyList<TypeParamIr> ReadTypeParams(JsonNode? node)
    {
        if (node is null)
            return [];

        return node.AsArray().Select(ReadTypeParam).ToList();
    }

    private static TypeParamIr ReadTypeParam(JsonNode? node)
    {
        if (node is null)
            throw new InvalidOperationException("null type parameter");

        if (node is JsonValue value)
        {
            var text = value.GetValue<string>();
            var colon = text.IndexOf(':', StringComparison.Ordinal);
            if (colon < 0)
                return new(text.Trim(), []);

            return new(
                text[..colon].Trim(),
                text[(colon + 1)..]
                    .Split(
                        ['&', '+'],
                        StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries
                    )
                    .ToList()
            );
        }

        return new(
            node["name"]!.GetValue<string>(),
            node["constraints"]?.AsArray().Select(x => x!.GetValue<string>()).ToList() ?? []
        );
    }

    private static TraitMethodIr ReadTraitMethod(JsonNode? node)
    {
        if (node is null)
            throw new InvalidOperationException("null trait method");

        return new(
            node["name"]!.GetValue<string>(),
            node["parameterTypes"]?.AsArray().Select(x => ReadType(x!)).ToList() ?? [],
            ReadType(node["returnType"]!)
        );
    }

    private static FieldIr ReadField(JsonNode? node)
    {
        if (node is null)
            throw new InvalidOperationException("null field");

        return new(
            ReadSymbol(node["symbol"]!, "Field"),
            ReadType(node["type"]!),
            node["mutable"]?.GetValue<bool>() ?? false
        );
    }

    private static EnumVariantIr ReadEnumVariant(JsonNode? node)
    {
        if (node is null)
            throw new InvalidOperationException("null enum variant");

        return new(
            ReadSymbol(node["symbol"]!, "EnumVariant"),
            ReadStringArray(node["payloadNames"]),
            ReadBoolArray(node["payloadMutables"]),
            node["payload"]!.AsArray().Select(x => ReadType(x!)).ToList()
        );
    }

    private static IReadOnlyList<bool> ReadBoolArray(JsonNode? node)
    {
        return node is null ? [] : node.AsArray().Select(x => x!.GetValue<bool>()).ToList();
    }

    private static IReadOnlyList<string> ReadStringArray(JsonNode? node)
    {
        return node?.AsArray().Select(x => x!.GetValue<string>()).ToList() ?? [];
    }

    private static ParamIr ReadParam(JsonNode? node)
    {
        if (node is null)
            throw new InvalidOperationException("null param");

        return new(
            ReadSymbol(node["symbol"]!, "Parameter"),
            ReadType(node["type"]!),
            node["default"] is { } defaultNode ? ReadExpr(defaultNode) : null
        );
    }

    private static SymbolIr ReadSymbol(JsonNode node, params string[] expectedKinds)
    {
        var kind = node["kind"]!.GetValue<string>();
        if (expectedKinds.Length > 0 && !expectedKinds.Contains(kind))
            throw new InvalidOperationException(
                $"expected {string.Join(" or ", expectedKinds)} symbol, got {kind}"
            );

        return new(kind, node["id"]!.GetValue<string>(), node["name"]!.GetValue<string>());
    }

    private static TypeRefIr ReadType(JsonNode node)
    {
        var kind = node["kind"]!.GetValue<string>();
        return kind switch
        {
            "Named" => ReadNamedType(node),
            "Tuple" => new("Tuple", node["elements"]!.AsArray().Select(x => ReadType(x!)).ToList()),
            "Function" => ReadFunctionType(node),
            "Array" => new("Array", Element: ReadType(node["element"]!)),
            "FixedArray" => new("FixedArray", Element: ReadType(node["element"]!)),
            "ReadOnlyArray" => new("FixedArray", Element: ReadType(node["element"]!)),
            "UninitializedArray" => new("FixedArray", Element: ReadType(node["element"]!)),
            "Iter" => new("Iter", Element: ReadType(node["element"]!)),
            "ArrayView" => new("ArrayView", Element: ReadType(node["element"]!)),
            "MutArrayView" => new("MutArrayView", Element: ReadType(node["element"]!)),
            "Map" => new("Map", Key: ReadType(node["key"]!), Value: ReadType(node["value"]!)),
            "Option" => new("Option", Element: ReadType(node["element"]!)),
            "Result" => new(
                "Result",
                Element: ReadType(node["ok"]!),
                Error: ReadType(node["error"]!)
            ),
            "TraitObject" => new("TraitObject", Element: new(node["name"]!.GetValue<string>())),
            _ => throw new NotSupportedException($"type kind not supported: {kind}"),
        };
    }

    private static TypeRefIr ReadFunctionType(JsonNode node)
    {
        var returnType = ReadType(node["return"]!);
        if (node["raises"]?.GetValue<bool>() == true)
            returnType = new(
                "Result",
                Element: returnType,
                Error: node["error"] is { } error ? ReadType(error) : new("Error")
            );

        return new(
            "Function",
            node["params"]!.AsArray().Select(x => ReadType(x!)).ToList(),
            returnType
        );
    }

    private static TypeRefIr ReadNamedType(JsonNode node)
    {
        var name = node["name"]!.GetValue<string>();
        var args = node["args"]?.AsArray().Select(x => ReadType(x!)).ToList();
        return name switch
        {
            "Array" when args is [var element] => new("Array", Element: element),
            "FixedArray" when args is [var element] => new("FixedArray", Element: element),
            "ReadOnlyArray" when args is [var element] => new("FixedArray", Element: element),
            "UninitializedArray" when args is [var element] => new("FixedArray", Element: element),
            "Iter" when args is [var element] => new("Iter", Element: element),
            "ArrayView" when args is [var element] => new("ArrayView", Element: element),
            "MutArrayView" when args is [var element] => new("MutArrayView", Element: element),
            "Option" when args is [var element] => new("Option", Element: element),
            _ => new(name, args),
        };
    }

    private static ExprIr ReadExpr(JsonNode node)
    {
        return node["kind"]!.GetValue<string>() switch
        {
            "IntLiteral" => new IntLiteralIr(
                ReadIntegerLiteralText(node["value"]!),
                ReadType(node["type"]!)
            ),
            "DoubleLiteral" => new DoubleLiteralIr(
                node["value"]!.GetValue<double>(),
                ReadType(node["type"]!)
            ),
            "StringLiteral" => new StringLiteralIr(
                node["value"]!.GetValue<string>(),
                ReadType(node["type"]!)
            ),
            "CharLiteral" => new CharLiteralIr(
                node["value"]!.GetValue<string>(),
                ReadType(node["type"]!)
            ),
            "ByteLiteral" => new ByteLiteralIr(
                node["value"]!.GetValue<string>(),
                ReadType(node["type"]!)
            ),
            "BytesLiteral" => new BytesLiteralIr(
                node["value"]!.GetValue<string>(),
                ReadType(node["type"]!)
            ),
            "BoolLiteral" => new BoolLiteralIr(
                node["value"]!.GetValue<bool>(),
                ReadType(node["type"]!)
            ),
            "SourceLoc" => new SourceLocIr(
                node["repr"]!.GetValue<string>(),
                ReadType(node["type"]!)
            ),
            "ArgsLoc" => new ArgsLocIr(
                node["items"]!.AsArray().Select(x => x!.GetValue<string>()).ToList(),
                ReadType(node["type"]!)
            ),
            "Unsupported" => new UnsupportedExprIr(
                node["reason"]!.GetValue<string>(),
                ReadType(node["type"]!),
                node["sourceSpan"] is { } sourceSpan ? ReadSourceSpan(sourceSpan) : null
            ),
            "Var" => new VarIr(
                ReadSymbol(node["symbol"]!, "Local", "Parameter", "Global"),
                ReadType(node["type"]!)
            ),
            "PackageRef" => new PackageRefIr(
                node["package"]!.GetValue<string>(),
                node["packageId"]?.GetValue<string>()
                    ?? "pkg:" + node["package"]!.GetValue<string>(),
                ReadType(node["type"]!)
            ),
            "PackageValue" => new PackageValueIr(
                node["package"]!.GetValue<string>(),
                node["member"]!.GetValue<string>(),
                ReadType(node["type"]!)
            ),
            "FunctionRef" => new FunctionRefIr(
                ReadSymbol(node["symbol"]!, "Function"),
                ReadType(node["type"]!)
            ),
            "StaticTypeRef" => new StaticTypeRefIr(
                node["typeName"]!.GetValue<string>(),
                ReadType(node["type"]!)
            ),
            "StaticValue" => new StaticValueIr(
                node["typeName"]!.GetValue<string>(),
                node["member"]!.GetValue<string>(),
                node["externalName"]?.GetValue<string>() ?? "",
                ReadType(node["type"]!)
            ),
            "Binary" => new BinaryIr(
                node["op"]!.GetValue<string>(),
                ReadExpr(node["left"]!),
                ReadExpr(node["right"]!),
                ReadType(node["type"]!)
            ),
            "TraitOperatorCall" => new TraitOperatorCallIr(
                node["traitName"]!.GetValue<string>(),
                node["impl"] is { } implNode ? ReadSymbol(implNode, "Impl") : null,
                node["methodName"]!.GetValue<string>(),
                node["arguments"]!.AsArray().Select(x => ReadExpr(x!)).ToList(),
                ReadType(node["type"]!)
            ),
            "Is" => new IsIr(
                ReadExpr(node["target"]!),
                ReadIsPattern(node["pattern"]!),
                ReadType(node["type"]!)
            ),
            "Call" => new CallIr(
                ReadCallee(node["callee"]!),
                node["arguments"]!.AsArray().Select(x => ReadExpr(x!)).ToList(),
                ReadType(node["type"]!),
                ReadTraitArguments(node["traitArguments"])
            ),
            "DelegateCall" => new DelegateCallIr(
                ReadExpr(node["target"]!),
                node["arguments"]!.AsArray().Select(x => ReadExpr(x!)).ToList(),
                ReadType(node["type"]!)
            ),
            "Lambda" => new LambdaIr(
                node["parameters"]!.AsArray().Select(ReadLambdaParameter).ToList(),
                ReadExpr(node["body"]!),
                ReadType(node["type"]!)
            ),
            "LocalFunction" => new LocalFunctionIr(
                ReadSymbol(node["symbol"]!, "Function"),
                node["parameters"]!.AsArray().Select(ReadParam).ToList(),
                ReadType(node["returnType"]!),
                ReadExpr(node["body"]!),
                ReadType(node["type"]!)
            ),
            "Some" => new SomeIr(ReadExpr(node["value"]!), ReadType(node["type"]!)),
            "None" => new NoneIr(ReadType(node["type"]!)),
            "ResultOk" => new ResultOkIr(ReadExpr(node["value"]!), ReadType(node["type"]!)),
            "ResultErr" => new ResultErrIr(ReadExpr(node["value"]!), ReadType(node["type"]!)),
            "Let" => new LetIr(
                ReadSymbol(node["symbol"]!, "Local"),
                ReadExpr(node["value"]!),
                ReadExpr(node["then"]!),
                ReadType(node["type"]!)
            ),
            "VarDecl" => new VarDeclIr(
                ReadSymbol(node["symbol"]!, "Local"),
                node["mutable"]?.GetValue<bool>() ?? false,
                ReadType(node["declaredType"]!),
                ReadExpr(node["value"]!),
                ReadType(node["type"]!)
            ),
            "Assign" => new AssignIr(
                ReadSymbol(node["symbol"]!, "Local"),
                ReadExpr(node["value"]!),
                ReadType(node["type"]!)
            ),
            "FieldAssign" => new FieldAssignIr(
                ReadExpr(node["target"]!),
                node["name"]!.GetValue<string>(),
                ReadExpr(node["value"]!),
                ReadType(node["type"]!)
            ),
            "IndexAssign" => new IndexAssignIr(
                ReadExpr(node["target"]!),
                ReadExpr(node["index"]!),
                ReadExpr(node["value"]!),
                ReadType(node["type"]!)
            ),
            "TupleLiteral" => new TupleLiteralIr(
                node["items"]!.AsArray().Select(x => ReadExpr(x!)).ToList(),
                ReadType(node["type"]!)
            ),
            "TupleGet" => new TupleGetIr(
                ReadExpr(node["target"]!),
                node["index"]!.GetValue<int>(),
                ReadType(node["type"]!)
            ),
            "LetTuple" => new LetTupleIr(
                node["bindings"]!.AsArray().Select(ReadLetTupleBinding).ToList(),
                ReadExpr(node["value"]!),
                ReadType(node["type"]!)
            ),
            "ArrayLiteral" => new ArrayLiteralIr(
                node["items"]!.AsArray().Select(x => ReadExpr(x!)).ToList(),
                ReadType(node["type"]!)
            ),
            "MapLiteral" => new MapLiteralIr(
                node["entries"]!.AsArray().Select(ReadMapLiteralEntry).ToList(),
                ReadType(node["type"]!)
            ),
            "IndexGet" => new IndexGetIr(
                ReadExpr(node["target"]!),
                ReadExpr(node["index"]!),
                ReadType(node["type"]!)
            ),
            "NewStruct" => new NewStructIr(
                node["name"]!.GetValue<string>(),
                node["arguments"]!.AsArray().Select(x => ReadExpr(x!)).ToList(),
                ReadType(node["type"]!)
            ),
            "RecordUpdate" => new RecordUpdateIr(
                ReadExpr(node["target"]!),
                node["fields"]!.AsArray().Select(ReadRecordUpdateField).ToList(),
                ReadType(node["type"]!)
            ),
            "EnumCase" => new EnumCaseIr(
                node["enumName"]!.GetValue<string>(),
                node["variantName"]!.GetValue<string>(),
                node["arguments"]!.AsArray().Select(x => ReadExpr(x!)).ToList(),
                ReadType(node["type"]!)
            ),
            "FieldGet" => new FieldGetIr(
                ReadExpr(node["target"]!),
                node["name"]!.GetValue<string>(),
                ReadType(node["type"]!)
            ),
            "MemberCall" => new MemberCallIr(
                ReadExpr(node["target"]!),
                node["name"]!.GetValue<string>(),
                node["arguments"]!.AsArray().Select(x => ReadExpr(x!)).ToList(),
                node["argumentLabels"]
                    ?.AsArray()
                    .Select(x => x is null ? null : x.GetValue<string>())
                    .ToList()
                    ?? [],
                ReadType(node["type"]!),
                ReadTraitArguments(node["traitArguments"]),
                ReadTraitMethodEvidence(node["traitEvidence"])
            ),
            "TraitObject" => new TraitObjectIr(
                node["traitName"]!.GetValue<string>(),
                node["selfType"]!.GetValue<string>(),
                node["impl"] is null ? null : ReadSymbol(node["impl"]!, "Impl"),
                ReadExpr(node["self"]!),
                ReadType(node["type"]!)
            ),
            "InterpolatedString" => new InterpolatedStringIr(
                node["parts"]!.AsArray().Select(ReadInterpolatedStringPart).ToList(),
                ReadType(node["type"]!)
            ),
            "ForRange" => new ForRangeIr(
                ReadSymbol(node["symbol"]!, "Local"),
                ReadExpr(node["start"]!),
                ReadExpr(node["end"]!),
                node["inclusive"]!.GetValue<bool>(),
                node["reverse"]?.GetValue<bool>() ?? false,
                node["excludeStart"]?.GetValue<bool>() ?? false,
                node["bindings"]?.AsArray().Select(ReadForLoopBinding).ToList() ?? [],
                ReadExpr(node["body"]!),
                node["nobreak"] is null ? null : ReadExpr(node["nobreak"]!),
                ReadType(node["type"]!)
            ),
            "ForLoop" => new ForLoopIr(
                node["bindings"]!.AsArray().Select(ReadForLoopBinding).ToList(),
                ReadExpr(node["condition"]!),
                node["updates"]!.AsArray().Select(ReadForLoopUpdate).ToList(),
                ReadExpr(node["body"]!),
                ReadType(node["type"]!)
            ),
            "FunctionalFor" => new FunctionalForIr(
                node["bindings"]!.AsArray().Select(ReadForLoopBinding).ToList(),
                ReadExpr(node["condition"]!),
                node["updates"]!.AsArray().Select(ReadForLoopUpdate).ToList(),
                ReadExpr(node["body"]!),
                ReadExpr(node["nobreak"]!),
                ReadType(node["type"]!)
            ),
            "While" => new WhileIr(
                ReadExpr(node["condition"]!),
                ReadExpr(node["body"]!),
                ReadType(node["type"]!),
                node["nobreak"] is { } noBreak ? ReadExpr(noBreak) : null
            ),
            "ForEach" => new ForEachIr(
                node["indexSymbol"] is null ? null : ReadSymbol(node["indexSymbol"]!, "Local"),
                ReadSymbol(node["valueSymbol"]!, "Local"),
                ReadExpr(node["target"]!),
                node["bindings"]?.AsArray().Select(ReadForLoopBinding).ToList() ?? [],
                ReadExpr(node["body"]!),
                node["nobreak"] is null ? null : ReadExpr(node["nobreak"]!),
                ReadType(node["type"]!)
            ),
            "Break" => new BreakIr(ReadType(node["type"]!)),
            "Continue" => new ContinueIr(
                node["values"]?.AsArray().Select(x => ReadExpr(x!)).ToList() ?? [],
                ReadType(node["type"]!)
            ),
            "Guard" => new GuardIr(
                ReadExpr(node["condition"]!),
                ReadExpr(node["else"]!),
                ReadType(node["type"]!)
            ),
            "Return" => new ReturnIr(ReadExpr(node["value"]!), ReadType(node["type"]!)),
            "Block" => new BlockIr(
                node["items"]!.AsArray().Select(x => ReadExpr(x!)).ToList(),
                ReadType(node["type"]!)
            ),
            "If" => new IfIr(
                ReadExpr(node["condition"]!),
                ReadExpr(node["then"]!),
                ReadExpr(node["else"]!),
                ReadType(node["type"]!)
            ),
            "Match" => new MatchIr(
                ReadExpr(node["target"]!),
                node["arms"]!.AsArray().Select(ReadMatchArm).ToList(),
                ReadType(node["type"]!)
            ),
            "Fail" => new FailIr(
                ReadExpr(node["message"]!),
                node["source"]?.GetValue<string>(),
                ReadType(node["type"]!)
            ),
            "Panic" => new PanicIr(ReadType(node["type"]!)),
            "TryCatch" => new TryCatchIr(
                ReadExpr(node["body"]!),
                node["catches"]!.AsArray().Select(ReadCatchClause).ToList(),
                ReadType(node["type"]!)
            ),
            "TryResult" => new TryResultIr(ReadExpr(node["body"]!), ReadType(node["type"]!)),
            var k => throw new NotSupportedException($"expr kind not supported: {k}"),
        };
    }

    private static SourceSpanIr ReadSourceSpan(JsonNode node)
    {
        return new(
            node["file"]?.GetValue<string>(),
            node["start"]!.GetValue<int>(),
            node["end"]!.GetValue<int>(),
            node["startLine"]!.GetValue<int>(),
            node["startColumn"]!.GetValue<int>(),
            node["endLine"]!.GetValue<int>(),
            node["endColumn"]!.GetValue<int>()
        );
    }

    private static MatchArmIr ReadMatchArm(JsonNode? node)
    {
        if (node is null)
            throw new InvalidOperationException("null match arm");

        return new(
            ReadMatchPattern(node["pattern"]!),
            ReadExpr(node["body"]!),
            node["guard"] is { } guard ? ReadExpr(guard) : null
        );
    }

    private static MatchPatternIr ReadMatchPattern(JsonNode node)
    {
        return node["kind"]!.GetValue<string>() switch
        {
            "Wildcard" => new WildcardMatchPatternIr(),
            "Binding" => new BindingMatchPatternIr(ReadSymbol(node["binding"]!, "Local")),
            "None" => new NoneMatchPatternIr(),
            "Some" => new SomeMatchPatternIr(
                ReadOptionalBindingSymbol(node["binding"]),
                node["payload"] is { } payload ? ReadMatchPattern(payload) : null
            ),
            "Ok" => new OkMatchPatternIr(
                ReadOptionalBindingSymbol(node["binding"]),
                node["payload"] is { } payload ? ReadMatchPattern(payload) : null
            ),
            "Err" => new ErrMatchPatternIr(
                ReadOptionalBindingSymbol(node["binding"]),
                node["payload"] is { } payload ? ReadMatchPattern(payload) : null
            ),
            "Tuple" => new TupleMatchPatternIr(
                node["items"]!.AsArray().Select(x => ReadMatchPattern(x!)).ToList()
            ),
            "Array" => new ArrayMatchPatternIr(ReadArrayPatternSegments(node)),
            "Range" => new RangeMatchPatternIr(
                ReadExpr(node["start"]!),
                ReadExpr(node["end"]!),
                node["inclusive"]!.GetValue<bool>(),
                ReadOptionalBindingSymbol(node["binding"])
            ),
            "Literal" => new LiteralMatchPatternIr(ReadExpr(node["value"]!)),
            "Or" => new OrMatchPatternIr(
                node["alternatives"]!.AsArray().Select(x => ReadMatchPattern(x!)).ToList(),
                ReadOptionalBindingSymbol(node["binding"])
            ),
            "Enum" => new EnumMatchPatternIr(
                node["enumName"]!.GetValue<string>(),
                node["variantName"]!.GetValue<string>(),
                node["bindings"]?.AsArray().Select(x => ReadSymbol(x!, "Local")).ToList() ?? [],
                node["payload"] is { } payload ? ReadMatchPattern(payload) : null
            ),
            var k => throw new NotSupportedException($"match pattern kind not supported: {k}"),
        };
    }

    private static IReadOnlyList<ArrayPatternSegmentIr> ReadArrayPatternSegments(JsonNode node)
    {
        if (node["segments"] is { } segmentsNode)
            return segmentsNode.AsArray().Select(ReadArrayPatternSegment).ToList();

        var segments = new List<ArrayPatternSegmentIr>();
        foreach (var item in node["prefix"]!.AsArray())
            segments.Add(new ArrayElementPatternSegmentIr(ReadMatchPattern(item!)));

        if (node["hasRest"]?.GetValue<bool>() ?? node["restBinding"] is not null)
            segments.Add(
                new ArrayRestPatternSegmentIr(ReadOptionalBindingSymbol(node["restBinding"]))
            );

        foreach (var item in node["suffix"]!.AsArray())
            segments.Add(new ArrayElementPatternSegmentIr(ReadMatchPattern(item!)));

        return segments;
    }

    private static ArrayPatternSegmentIr ReadArrayPatternSegment(JsonNode? node)
    {
        if (node is null)
            throw new InvalidOperationException("null array pattern segment");

        return node["kind"]!.GetValue<string>() switch
        {
            "Element" => new ArrayElementPatternSegmentIr(ReadMatchPattern(node["pattern"]!)),
            "Rest" => new ArrayRestPatternSegmentIr(ReadOptionalBindingSymbol(node["binding"])),
            "FixedSpread" => new ArrayFixedSpreadPatternSegmentIr(ReadExpr(node["value"]!)),
            "BitField" => new ArrayBitFieldPatternSegmentIr(
                node["signed"]!.GetValue<bool>(),
                node["endian"]!.GetValue<string>(),
                node["width"]!.GetValue<int>(),
                ReadOptionalBindingSymbol(node["binding"]),
                node["value"] is { } value ? ReadExpr(value) : null
            ),
            var k => throw new NotSupportedException(
                $"array pattern segment kind not supported: {k}"
            ),
        };
    }

    private static CatchClauseIr ReadCatchClause(JsonNode? node)
    {
        if (node is null)
            throw new InvalidOperationException("null catch clause");

        return new(ReadCatchPattern(node["pattern"]!), ReadExpr(node["body"]!));
    }

    private static CatchPatternIr ReadCatchPattern(JsonNode node)
    {
        return node["kind"]!.GetValue<string>() switch
        {
            "Failure" => new FailureCatchPatternIr(ReadOptionalBindingSymbol(node["binding"])),
            "Wildcard" => new WildcardCatchPatternIr(),
            "Match" => new MatchCatchPatternIr(
                ReadType(node["errorType"]!),
                ReadMatchPattern(node["pattern"]!)
            ),
            var k => throw new NotSupportedException($"catch pattern kind not supported: {k}"),
        };
    }

    private static IsPatternIr ReadIsPattern(JsonNode node)
    {
        return node["kind"]!.GetValue<string>() switch
        {
            "None" => new NoneIsPatternIr(),
            "Some" => new SomeIsPatternIr(
                ReadOptionalBindingSymbol(node["binding"]),
                node["payload"] is null ? null : ReadMatchPattern(node["payload"]!)
            ),
            "Ok" => new OkIsPatternIr(
                ReadOptionalBindingSymbol(node["binding"]),
                node["payload"] is null ? null : ReadMatchPattern(node["payload"]!)
            ),
            "Err" => new ErrIsPatternIr(
                ReadOptionalBindingSymbol(node["binding"]),
                node["payload"] is null ? null : ReadMatchPattern(node["payload"]!)
            ),
            "Value" => new ValueIsPatternIr(ReadExpr(node["value"]!)),
            "Literal" => new ValueIsPatternIr(ReadExpr(node["value"]!)),
            "Or" => new OrIsPatternIr(
                node["alternatives"]!.AsArray().Select(x => ReadIsPattern(x!)).ToList()
            ),
            "Wildcard" => new MatchIsPatternIr(ReadMatchPattern(node)),
            "Binding" => new MatchIsPatternIr(ReadMatchPattern(node)),
            "Tuple" => new MatchIsPatternIr(ReadMatchPattern(node)),
            "Array" => new MatchIsPatternIr(ReadMatchPattern(node)),
            "Range" => new MatchIsPatternIr(ReadMatchPattern(node)),
            "Enum" => new EnumIsPatternIr(
                node["enumName"]!.GetValue<string>(),
                node["variantName"]!.GetValue<string>(),
                node["bindings"]?.AsArray().Select(x => ReadSymbol(x!, "Local")).ToList() ?? [],
                node["payload"] is null ? null : ReadMatchPattern(node["payload"]!)
            ),
            var k => throw new NotSupportedException($"is pattern kind not supported: {k}"),
        };
    }

    private static SymbolIr? ReadOptionalBindingSymbol(JsonNode? node)
    {
        return node is null ? null : ReadSymbol(node, "Local");
    }

    private static LetTupleBindingIr ReadLetTupleBinding(JsonNode? node)
    {
        if (node is null)
            throw new InvalidOperationException("null tuple binding");

        return new(ReadSymbol(node["symbol"]!, "Local"), ReadType(node["type"]!));
    }

    private static MapLiteralEntryIr ReadMapLiteralEntry(JsonNode? node)
    {
        if (node is null)
            throw new InvalidOperationException("null map literal entry");

        return new(ReadExpr(node["key"]!), ReadExpr(node["value"]!));
    }

    private static RecordUpdateFieldIr ReadRecordUpdateField(JsonNode? node)
    {
        if (node is null)
            throw new InvalidOperationException("null record update field");

        return new(node["name"]!.GetValue<string>(), ReadExpr(node["value"]!));
    }

    private static LambdaParameterIr ReadLambdaParameter(JsonNode? node)
    {
        if (node is null)
            throw new InvalidOperationException("null lambda parameter");

        return new(ReadSymbol(node["symbol"]!, "Local"), ReadType(node["type"]!));
    }

    private static ForLoopBindingIr ReadForLoopBinding(JsonNode? node)
    {
        if (node is null)
            throw new InvalidOperationException("null for loop binding");

        return new(
            ReadSymbol(node["symbol"]!, "Local"),
            ReadType(node["type"]!),
            ReadExpr(node["initial"]!)
        );
    }

    private static ForLoopUpdateIr ReadForLoopUpdate(JsonNode? node)
    {
        if (node is null)
            throw new InvalidOperationException("null for loop update");

        return new(ReadSymbol(node["symbol"]!, "Local"), ReadExpr(node["value"]!));
    }

    private static InterpolatedStringPartIr ReadInterpolatedStringPart(JsonNode? node)
    {
        if (node is null)
            throw new InvalidOperationException("null interpolated string part");

        return node["kind"]!.GetValue<string>() switch
        {
            "Text" => new(node["value"]!.GetValue<string>(), null),
            "Expr" => new(null, ReadExpr(node["value"]!)),
            var k => throw new NotSupportedException(
                $"interpolated string part kind not supported: {k}"
            ),
        };
    }

    private static string ReadIntegerLiteralText(JsonNode node)
    {
        if (node is JsonValue value && value.TryGetValue<long>(out var signed))
            return signed.ToString(CultureInfo.InvariantCulture);

        if (node is JsonValue unsignedValue && unsignedValue.TryGetValue<ulong>(out var unsigned))
            return unsigned.ToString(CultureInfo.InvariantCulture);

        return node.ToJsonString();
    }

    private static CalleeIr ReadCallee(JsonNode node)
    {
        return node["kind"]!.GetValue<string>() switch
        {
            "Builtin" => new BuiltinCalleeIr(node["name"]!.GetValue<string>()),
            "Function" => new FunctionCalleeIr(ReadSymbol(node["symbol"]!, "Function")),
            "Intrinsic" => new IntrinsicCalleeIr(
                node["externalName"]!.GetValue<string>(),
                ReadSymbol(node["symbol"]!, "Function")
            ),
            "CSharpExtern" => new CSharpExternCalleeIr(
                node["externalName"]!.GetValue<string>(),
                ReadSymbol(node["symbol"]!, "Function")
            ),
            var k => throw new NotSupportedException($"callee kind not supported: {k}"),
        };
    }

    private static IReadOnlyList<TraitArgumentIr>? ReadTraitArguments(JsonNode? node)
    {
        if (node is null)
            return null;

        return node.AsArray().Select(ReadTraitArgument).ToList();
    }

    private static TraitArgumentIr ReadTraitArgument(JsonNode? node)
    {
        if (node is null)
            throw new InvalidOperationException("null trait argument");

        return new(
            node["traitName"]!.GetValue<string>(),
            ReadType(node["type"]!),
            node["function"] is null ? null : ReadSymbol(node["function"]!, "Function"),
            node["impl"] is null ? null : ReadSymbol(node["impl"]!, "Impl")
        );
    }

    private static TraitMethodEvidenceIr? ReadTraitMethodEvidence(JsonNode? node)
    {
        if (node is null)
            return null;

        return new(
            node["traitName"]!.GetValue<string>(),
            ReadSymbol(node["trait"]!, "Trait"),
            node["methodName"]!.GetValue<string>(),
            ReadSymbol(node["method"]!, "TraitMethod"),
            node["impl"] is null ? null : ReadSymbol(node["impl"]!, "Impl")
        );
    }
}
