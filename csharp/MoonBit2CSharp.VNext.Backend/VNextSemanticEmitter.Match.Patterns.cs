using System.Globalization;
using System.Text;
using System.Text.Json;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using static Microsoft.CodeAnalysis.CSharp.SyntaxFactory;

namespace MoonBit2CSharp.VNext.Backend;

public sealed partial class VNextSemanticEmitter
{
    private string MatchArmCondition(JsonElement arm)
    {
        var condition = MatchArmConditionExpression(arm);
        return condition.Length == 0 ? "" : " when " + condition;
    }

    private string MatchArmConditionExpression(JsonElement arm)
    {
        return arm.TryGetProperty("condition", out var condition)
            ? EmitExpr(condition).NormalizeWhitespace().ToFullString()
            : "";
    }

    private string PayloadPatternsCondition(
        string payloadName,
        JsonElement[] payloadTypes,
        JsonElement[] payloads
    )
    {
        if (payloads.Length == 0)
            return "true";

        var conditions = payloads
            .Select(
                (payload, index) =>
                    PayloadPatternCondition(
                        payloadName + ".Item" + index.ToString(CultureInfo.InvariantCulture),
                        index < payloadTypes.Length
                            ? EnumPayloadType(payloadTypes[index])
                            : default,
                        payload
                    )
            )
            .Where(condition => condition != "true")
            .ToArray();
        return conditions.Length == 0 ? "true" : string.Join(" && ", conditions);
    }

    private string PayloadPatternCondition(string value, JsonElement type, JsonElement pattern)
    {
        var kind = pattern.GetProperty("kind").GetString();
        switch (kind)
        {
            case "Wildcard" or "Binding":
                return "true";
            case "IntLiteral":
                return value + " == " + (pattern.GetProperty("value").GetString() ?? "0");
            case "CharLiteral":
                return value
                    + " == "
                    + CharLiteralCodePoint(pattern.GetProperty("value").GetString() ?? "")
                        .ToString(CultureInfo.InvariantCulture);
            case "StringLiteral":
                return value
                    + " == "
                    + JsonSerializer.Serialize(pattern.GetProperty("value").GetString() ?? "");
            case "BoolLiteral":
                return value
                    + " == "
                    + (pattern.GetProperty("value").GetBoolean() ? "true" : "false");
            case "Range":
            {
                var conditions = new List<string>();
                if (pattern.GetProperty("start").ValueKind == JsonValueKind.String)
                    conditions.Add(
                        value
                            + " >= "
                            + RangeBoundExpression(pattern.GetProperty("start").GetString() ?? "")
                    );

                if (pattern.GetProperty("end").ValueKind == JsonValueKind.String)
                    conditions.Add(
                        value
                            + (pattern.GetProperty("inclusive").GetBoolean() ? " <= " : " < ")
                            + RangeBoundExpression(pattern.GetProperty("end").GetString() ?? "")
                    );

                return conditions.Count == 0 ? "true" : string.Join(" && ", conditions);
            }

            case "Tuple":
            {
                var conditions = pattern
                    .GetProperty("items")
                    .EnumerateArray()
                    .Select(
                        (item, index) =>
                            PayloadPatternCondition(
                                value
                                    + ".Item"
                                    + (index + 1).ToString(CultureInfo.InvariantCulture),
                                TupleItemType(type, index),
                                item
                            )
                    )
                    .Where(condition => condition != "true")
                    .ToArray();
                return conditions.Length == 0 ? "true" : string.Join(" && ", conditions);
            }

            case "Struct":
            {
                var conditions = pattern
                    .GetProperty("fields")
                    .EnumerateArray()
                    .Select(field =>
                    {
                        var fieldRef = field.GetProperty("field");
                        return PayloadPatternCondition(
                            value
                                + "."
                                + ToPublicIdentifier(
                                    fieldRef.GetProperty("name").GetString() ?? ""
                                ),
                            fieldRef.GetProperty("type"),
                            field.GetProperty("pattern")
                        );
                    })
                    .Where(condition => condition != "true")
                    .ToArray();
                return conditions.Length == 0 ? "true" : string.Join(" && ", conditions);
            }

            case "Array":
            {
                var itemType = ArrayElementType(type);
                var items = pattern.GetProperty("items").EnumerateArray().ToArray();
                var suffix = ArrayPatternSuffix(pattern);
                var hasRest = HasArrayRest(pattern);
                var requiredLength = items.Length + suffix.Length;
                var conditions = new List<string>
                {
                    value
                        + (hasRest ? ".Length >= " : ".Length == ")
                        + requiredLength.ToString(CultureInfo.InvariantCulture),
                };
                for (var i = 0; i < items.Length; i++)
                {
                    var itemCondition = PayloadPatternCondition(
                        value + "[" + i.ToString(CultureInfo.InvariantCulture) + "]",
                        itemType,
                        items[i]
                    );
                    if (itemCondition != "true")
                        conditions.Add("(" + itemCondition + ")");
                }

                for (var i = 0; i < suffix.Length; i++)
                {
                    var offset = suffix.Length - i;
                    var itemCondition = PayloadPatternCondition(
                        value
                            + "["
                            + value
                            + ".Length - "
                            + offset.ToString(CultureInfo.InvariantCulture)
                            + "]",
                        itemType,
                        suffix[i]
                    );
                    if (itemCondition != "true")
                        conditions.Add("(" + itemCondition + ")");
                }

                return string.Join(" && ", conditions);
            }

            case "Or":
            {
                var conditions = pattern
                    .GetProperty("alternatives")
                    .EnumerateArray()
                    .Select(alternative => PayloadPatternCondition(value, type, alternative))
                    .Where(condition => condition != "false")
                    .ToArray();
                if (conditions.Length == 0)
                    return "false";
                return string.Join(" || ", conditions.Select(condition => "(" + condition + ")"));
            }

            case "OptionNone":
                return value + ".IsNone";
            case "OptionSome":
            {
                var payloadCondition = PayloadPatternCondition(
                    value + ".Value",
                    OptionElementType(type),
                    pattern.GetProperty("payload")
                );
                return payloadCondition == "true"
                    ? value + ".IsSome"
                    : value + ".IsSome && " + payloadCondition;
            }

            case "EnumCase":
            {
                var typeName = EmitType(type).NormalizeWhitespace().ToFullString();
                var variantName = EnumVariantMemberName(
                    typeName,
                    pattern.GetProperty("name").GetString() ?? ""
                );
                if (
                    typeDefinitions.TryGetValue(
                        pattern.GetProperty("typeId").GetString() ?? "",
                        out var enumDefinition
                    ) && IsAllConstantEnum(enumDefinition)
                )
                    return value + " == " + typeName + "." + variantName;

                var tagCondition = value + ".Kind == " + typeName + ".Tag." + variantName;
                var payloads = pattern.GetProperty("payloads").EnumerateArray().ToArray();
                if (payloads.Length == 0)
                    return tagCondition;

                if (
                    !typeDefinitions.TryGetValue(
                        pattern.GetProperty("typeId").GetString() ?? "",
                        out var typeDefinition
                    )
                )
                    return tagCondition;

                var variant = FindVariantDefinition(
                    typeDefinition,
                    pattern.GetProperty("name").GetString() ?? ""
                );
                if (variant.ValueKind == JsonValueKind.Undefined)
                    return tagCondition;

                var payloadTypes = variant.GetProperty("payloads").EnumerateArray().ToArray();
                var payloadAccess =
                    "System.Runtime.CompilerServices.Unsafe.As<"
                    + PayloadVariantTypeName(typeName, variantName)
                    + ">("
                    + value
                    + ")";
                var nestedCondition = PayloadPatternsCondition(
                    payloadAccess,
                    payloadTypes,
                    payloads
                );
                return nestedCondition == "true"
                    ? tagCondition
                    : tagCondition + " && " + nestedCondition;
            }

            default:
                throw new NotSupportedException(
                    $"vnext payload match pattern is not supported: {kind}"
                );
        }
    }

    private void EmitPayloadPatternBindings(
        StringBuilder builder,
        string payloadName,
        JsonElement[] payloads
    )
    {
        for (var i = 0; i < payloads.Length; i++)
            EmitPatternBindings(
                builder,
                payloadName + ".Item" + i.ToString(CultureInfo.InvariantCulture),
                payloads[i]
            );
    }

    private void EmitPatternBindings(StringBuilder builder, string value, JsonElement pattern)
    {
        var kind = pattern.GetProperty("kind").GetString();
        if (kind == "Binding")
        {
            var symbol = pattern.GetProperty("symbol");
            var bindingName = symbol.GetProperty("name").GetString() ?? "";
            if (bindingName != "_")
                builder
                    .Append("var ")
                    .Append(LocalIdentifier(symbol))
                    .Append(" = ")
                    .Append(value)
                    .Append("; ");
            return;
        }

        if (kind == "OptionSome")
        {
            EmitPatternBindings(builder, value + ".Value", pattern.GetProperty("payload"));
            return;
        }

        if (kind == "Tuple")
        {
            var items = pattern.GetProperty("items").EnumerateArray().ToArray();
            for (var i = 0; i < items.Length; i++)
                EmitPatternBindings(
                    builder,
                    value + ".Item" + (i + 1).ToString(CultureInfo.InvariantCulture),
                    items[i]
                );
            return;
        }

        if (kind == "Struct")
        {
            foreach (var field in pattern.GetProperty("fields").EnumerateArray())
            {
                var fieldRef = field.GetProperty("field");
                EmitPatternBindings(
                    builder,
                    value
                        + "."
                        + ToPublicIdentifier(fieldRef.GetProperty("name").GetString() ?? ""),
                    field.GetProperty("pattern")
                );
            }

            return;
        }

        if (kind == "Array")
        {
            var items = pattern.GetProperty("items").EnumerateArray().ToArray();
            var suffix = ArrayPatternSuffix(pattern);
            for (var i = 0; i < items.Length; i++)
                EmitPatternBindings(
                    builder,
                    value + "[" + i.ToString(CultureInfo.InvariantCulture) + "]",
                    items[i]
                );
            for (var i = 0; i < suffix.Length; i++)
            {
                var offset = suffix.Length - i;
                EmitPatternBindings(
                    builder,
                    value
                        + "["
                        + value
                        + ".Length - "
                        + offset.ToString(CultureInfo.InvariantCulture)
                        + "]",
                    suffix[i]
                );
            }

            var rest = ArrayPatternRestSymbol(pattern);
            if (rest.HasValue)
            {
                var restName = rest.Value.GetProperty("name").GetString() ?? "";
                if (restName != "_")
                    builder
                        .Append("var ")
                        .Append(LocalIdentifier(rest.Value))
                        .Append(" = ")
                        .Append(
                            ArrayRestViewExpression(value, items.Length, suffix.Length, rest.Value)
                        )
                        .Append("; ");
            }

            return;
        }

        if (kind == "EnumCase")
        {
            var payloads = pattern.GetProperty("payloads").EnumerateArray().ToArray();
            if (payloads.Length == 0)
                return;

            if (
                !typeDefinitions.TryGetValue(
                    pattern.GetProperty("typeId").GetString() ?? "",
                    out var typeDefinition
                )
            )
                return;

            var typeName = ToPublicIdentifier(
                typeDefinition.GetProperty("symbol").GetProperty("name").GetString() ?? ""
            );
            var variantName = EnumVariantMemberName(
                typeName,
                pattern.GetProperty("name").GetString() ?? ""
            );
            var payloadName =
                "__moonbitPayload" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
            builder
                .Append("var ")
                .Append(payloadName)
                .Append(" = System.Runtime.CompilerServices.Unsafe.As<")
                .Append(PayloadVariantTypeName(typeName, variantName))
                .Append(">(")
                .Append(value)
                .Append("); ");
            EmitPayloadPatternBindings(builder, payloadName, payloads);
        }
    }

    private void EmitArrayRestPatternBindings(
        StringBuilder builder,
        string value,
        JsonElement pattern
    )
    {
        var kind = pattern.GetProperty("kind").GetString();
        if (kind == "OptionSome")
        {
            EmitArrayRestPatternBindings(builder, value + ".Value", pattern.GetProperty("payload"));
            return;
        }

        if (kind == "Tuple")
        {
            var items = pattern.GetProperty("items").EnumerateArray().ToArray();
            for (var i = 0; i < items.Length; i++)
                EmitArrayRestPatternBindings(
                    builder,
                    value + ".Item" + (i + 1).ToString(CultureInfo.InvariantCulture),
                    items[i]
                );
            return;
        }

        if (kind == "Struct")
        {
            foreach (var field in pattern.GetProperty("fields").EnumerateArray())
            {
                var fieldRef = field.GetProperty("field");
                EmitArrayRestPatternBindings(
                    builder,
                    value
                        + "."
                        + ToPublicIdentifier(fieldRef.GetProperty("name").GetString() ?? ""),
                    field.GetProperty("pattern")
                );
            }

            return;
        }

        if (kind == "Array")
        {
            var items = pattern.GetProperty("items").EnumerateArray().ToArray();
            var suffix = ArrayPatternSuffix(pattern);
            for (var i = 0; i < items.Length; i++)
                EmitArrayRestPatternBindings(
                    builder,
                    value + "[" + i.ToString(CultureInfo.InvariantCulture) + "]",
                    items[i]
                );
            for (var i = 0; i < suffix.Length; i++)
            {
                var offset = suffix.Length - i;
                EmitArrayRestPatternBindings(
                    builder,
                    value
                        + "["
                        + value
                        + ".Length - "
                        + offset.ToString(CultureInfo.InvariantCulture)
                        + "]",
                    suffix[i]
                );
            }

            var rest = ArrayPatternRestSymbol(pattern);
            if (rest.HasValue)
            {
                var restName = rest.Value.GetProperty("name").GetString() ?? "";
                if (restName != "_")
                    builder
                        .Append("var ")
                        .Append(LocalIdentifier(rest.Value))
                        .Append(" = ")
                        .Append(
                            ArrayRestViewExpression(value, items.Length, suffix.Length, rest.Value)
                        )
                        .Append("; ");
            }

            return;
        }

        if (kind == "EnumCase")
        {
            var payloads = pattern.GetProperty("payloads").EnumerateArray().ToArray();
            if (payloads.Length == 0)
                return;

            if (
                !typeDefinitions.TryGetValue(
                    pattern.GetProperty("typeId").GetString() ?? "",
                    out var typeDefinition
                )
            )
                return;

            var typeName = ToPublicIdentifier(
                typeDefinition.GetProperty("symbol").GetProperty("name").GetString() ?? ""
            );
            var variantName = EnumVariantMemberName(
                typeName,
                pattern.GetProperty("name").GetString() ?? ""
            );
            var payloadName =
                "__moonbitPayload" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
            builder
                .Append("var ")
                .Append(payloadName)
                .Append(" = System.Runtime.CompilerServices.Unsafe.As<")
                .Append(PayloadVariantTypeName(typeName, variantName))
                .Append(">(")
                .Append(value)
                .Append("); ");
            EmitPayloadPatternRestBindings(builder, payloadName, payloads);
        }
    }

    private void EmitPayloadPatternRestBindings(
        StringBuilder builder,
        string payloadName,
        JsonElement[] payloads
    )
    {
        for (var i = 0; i < payloads.Length; i++)
            EmitArrayRestPatternBindings(
                builder,
                payloadName + ".Item" + i.ToString(CultureInfo.InvariantCulture),
                payloads[i]
            );
    }

    private bool CanEmitSwitchExpression(JsonElement targetType, JsonElement[] arms)
    {
        foreach (var arm in arms)
        {
            var pattern = arm.GetProperty("pattern");
            var kind = pattern.GetProperty("kind").GetString();
            if (kind == "Wildcard")
                continue;

            if (
                kind
                is "IntLiteral"
                    or "CharLiteral"
                    or "StringLiteral"
                    or "BoolLiteral"
                    or "Range"
                    or "Binding"
                    or "Tuple"
                    or "Array"
                    or "Or"
                    or "OptionNone"
                    or "OptionSome"
            )
                continue;

            if (kind != "EnumCase")
                return false;

            var typeId = pattern.GetProperty("typeId").GetString() ?? "";
            if (!typeDefinitions.TryGetValue(typeId, out var typeDefinition))
                return false;

            if (!IsAllConstantEnum(typeDefinition))
                return false;
        }

        return true;
    }

    private string MatchPatternExpression(JsonElement targetType, JsonElement pattern)
    {
        var kind = pattern.GetProperty("kind").GetString();
        switch (kind)
        {
            case "Wildcard":
                return "_";
            case "Binding":
            {
                var symbol = pattern.GetProperty("symbol");
                var name = symbol.GetProperty("name").GetString() ?? "_";
                return name == "_" ? "_" : "var " + LocalIdentifier(symbol);
            }

            case "EnumCase":
            {
                var typeName = EmitType(targetType).NormalizeWhitespace().ToFullString();
                return typeName
                    + "."
                    + EnumVariantMemberName(
                        typeName,
                        pattern.GetProperty("name").GetString() ?? ""
                    );
            }
            case "IntLiteral":
                return IntegerLiteralDigits(pattern.GetProperty("value").GetString() ?? "0");
            case "CharLiteral":
                return CharPatternConstant(pattern.GetProperty("value").GetString() ?? "");
            case "StringLiteral":
                return JsonSerializer.Serialize(pattern.GetProperty("value").GetString() ?? "");
            case "BoolLiteral":
                return pattern.GetProperty("value").GetBoolean() ? "true" : "false";
            case "Range":
                return RangePatternExpression(pattern);
            case "OptionNone":
                return "{ IsNone: true }";
            case "OptionSome":
            {
                var payload = pattern.GetProperty("payload");
                var payloadPattern = MatchPatternExpression(OptionElementType(targetType), payload);
                return payloadPattern == "_"
                    ? "{ IsSome: true }"
                    : "{ IsSome: true, Value: " + payloadPattern + " }";
            }

            case "Tuple":
            {
                return "("
                    + string.Join(
                        ", ",
                        pattern
                            .GetProperty("items")
                            .EnumerateArray()
                            .Select(
                                (item, index) =>
                                    MatchPatternExpression(TupleItemType(targetType, index), item)
                            )
                    )
                    + ")";
            }

            case "Array":
            {
                var itemType = ArrayElementType(targetType);
                var itemPatterns = pattern
                    .GetProperty("items")
                    .EnumerateArray()
                    .Select(item => MatchPatternExpression(itemType, item))
                    .ToList();
                if (HasArrayRest(pattern))
                {
                    var rest = ArrayPatternRestSymbol(pattern);
                    itemPatterns.Add("..");
                }

                itemPatterns.AddRange(
                    ArrayPatternSuffix(pattern)
                        .Select(item => MatchPatternExpression(itemType, item))
                );
                return "[" + string.Join(", ", itemPatterns) + "]";
            }

            case "Or":
            {
                return string.Join(
                    " or ",
                    pattern
                        .GetProperty("alternatives")
                        .EnumerateArray()
                        .Select(alternative => MatchPatternExpression(targetType, alternative))
                );
            }

            default:
                throw new NotSupportedException($"vnext match pattern is not supported: {kind}");
        }
    }

    private string MatchTestPatternExpression(JsonElement targetType, JsonElement pattern)
    {
        var kind = pattern.GetProperty("kind").GetString();
        switch (kind)
        {
            case "Binding":
                return MatchPatternExpression(targetType, pattern);
            case "Tuple":
            {
                return "("
                    + string.Join(
                        ", ",
                        pattern
                            .GetProperty("items")
                            .EnumerateArray()
                            .Select(
                                (item, index) =>
                                    MatchTestPatternExpression(
                                        TupleItemType(targetType, index),
                                        item
                                    )
                            )
                    )
                    + ")";
            }

            case "Array":
            {
                var itemType = ArrayElementType(targetType);
                var itemPatterns = pattern
                    .GetProperty("items")
                    .EnumerateArray()
                    .Select(item => MatchTestPatternExpression(itemType, item))
                    .ToList();
                if (HasArrayRest(pattern))
                    itemPatterns.Add("..");
                itemPatterns.AddRange(
                    ArrayPatternSuffix(pattern)
                        .Select(item => MatchTestPatternExpression(itemType, item))
                );
                return "[" + string.Join(", ", itemPatterns) + "]";
            }

            case "OptionSome":
            {
                var payloadPattern = MatchTestPatternExpression(
                    OptionElementType(targetType),
                    pattern.GetProperty("payload")
                );
                return payloadPattern == "_"
                    ? "{ IsSome: true }"
                    : "{ IsSome: true, Value: " + payloadPattern + " }";
            }

            case "Or":
            {
                return string.Join(
                    " or ",
                    pattern
                        .GetProperty("alternatives")
                        .EnumerateArray()
                        .Select(alternative => MatchTestPatternExpression(targetType, alternative))
                );
            }

            default:
                return MatchPatternExpression(targetType, pattern);
        }
    }

    private string MatchConditionPatternExpression(JsonElement targetType, JsonElement pattern)
    {
        var kind = pattern.GetProperty("kind").GetString();
        switch (kind)
        {
            case "Binding":
                return "_";
            case "Tuple":
                return "("
                    + string.Join(
                        ", ",
                        pattern
                            .GetProperty("items")
                            .EnumerateArray()
                            .Select(
                                (item, index) =>
                                    MatchConditionPatternExpression(
                                        TupleItemType(targetType, index),
                                        item
                                    )
                            )
                    )
                    + ")";
            case "Array":
            {
                var itemType = ArrayElementType(targetType);
                var itemPatterns = pattern
                    .GetProperty("items")
                    .EnumerateArray()
                    .Select(item => MatchConditionPatternExpression(itemType, item))
                    .ToList();
                if (HasArrayRest(pattern))
                    itemPatterns.Add("..");
                itemPatterns.AddRange(
                    ArrayPatternSuffix(pattern)
                        .Select(item => MatchConditionPatternExpression(itemType, item))
                );
                return "[" + string.Join(", ", itemPatterns) + "]";
            }
            case "OptionSome":
            {
                var payloadPattern = MatchConditionPatternExpression(
                    OptionElementType(targetType),
                    pattern.GetProperty("payload")
                );
                return payloadPattern == "_"
                    ? "{ IsSome: true }"
                    : "{ IsSome: true, Value: " + payloadPattern + " }";
            }
            case "Or":
                return string.Join(
                    " or ",
                    pattern
                        .GetProperty("alternatives")
                        .EnumerateArray()
                        .Select(alternative =>
                            MatchConditionPatternExpression(targetType, alternative)
                        )
                );
            default:
                return MatchPatternExpression(targetType, pattern);
        }
    }

    private string MatchStatementCasePatternExpression(JsonElement targetType, JsonElement pattern)
    {
        var kind = pattern.GetProperty("kind").GetString();
        return kind is "Wildcard" or "Binding"
            ? "var _"
            : MatchTestPatternExpression(targetType, pattern);
    }

    private bool UseDefaultBranchForFinalArm(
        JsonElement targetType,
        JsonElement[] arms,
        int armIndex
    )
    {
        if (armIndex != arms.Length - 1)
            return false;

        var arm = arms[armIndex];
        if (arm.TryGetProperty("condition", out _))
            return false;

        var pattern = arm.GetProperty("pattern");
        var kind = pattern.GetProperty("kind").GetString();
        if (kind is "Wildcard" or "Binding")
            return true;

        if (IsBuiltinApply(targetType, "Option"))
            return FinalOptionArmCoversRemainder(arms, armIndex);

        if (kind == "EnumCase" && TryGetDeclaredTypeId(targetType, out var targetTypeId))
            return FinalEnumArmCoversRemainder(targetTypeId, arms, armIndex);

        if (
            kind == "Array"
            && (
                IsBuiltinType(targetType, "String")
                || IsBuiltinType(targetType, "StringView")
                || IsBuiltinApply(targetType, "Array")
                || IsBuiltinApply(targetType, "FixedArray")
                || IsBuiltinApply(targetType, "ArrayView")
            )
        )
            return ArrayPatternCoversAllLengths(pattern);

        return false;
    }

    private static bool ArrayPatternCoversAllLengths(JsonElement pattern)
    {
        return !pattern.GetProperty("items").EnumerateArray().Any()
            && ArrayPatternSuffix(pattern).Length == 0
            && HasArrayRest(pattern);
    }

    private static bool FinalOptionArmCoversRemainder(JsonElement[] arms, int finalArmIndex)
    {
        var finalPattern = arms[finalArmIndex].GetProperty("pattern");
        var finalKind = finalPattern.GetProperty("kind").GetString();
        if (finalKind == "OptionNone")
            return PreviousArmsCoverOptionSome(arms, finalArmIndex);

        if (finalKind == "OptionSome")
            return OptionSomePatternCoversAllPayloads(finalPattern)
                && PreviousArmsCoverOptionNone(arms, finalArmIndex);

        return false;
    }

    private static bool PreviousArmsCoverOptionNone(JsonElement[] arms, int beforeIndex)
    {
        for (var i = 0; i < beforeIndex; i++)
            if (
                !arms[i].TryGetProperty("condition", out _)
                && PatternCoversOptionNone(arms[i].GetProperty("pattern"))
            )
                return true;

        return false;
    }

    private static bool PreviousArmsCoverOptionSome(JsonElement[] arms, int beforeIndex)
    {
        for (var i = 0; i < beforeIndex; i++)
            if (
                !arms[i].TryGetProperty("condition", out _)
                && PatternCoversOptionSome(arms[i].GetProperty("pattern"))
            )
                return true;

        return false;
    }

    private static bool PatternCoversOptionNone(JsonElement pattern)
    {
        var kind = pattern.GetProperty("kind").GetString();
        if (kind is "Wildcard" or "Binding" or "OptionNone")
            return true;

        return kind == "Or"
            && pattern.GetProperty("alternatives").EnumerateArray().Any(PatternCoversOptionNone);
    }

    private static bool PatternCoversOptionSome(JsonElement pattern)
    {
        var kind = pattern.GetProperty("kind").GetString();
        if (kind is "Wildcard" or "Binding")
            return true;

        if (kind == "OptionSome")
            return OptionSomePatternCoversAllPayloads(pattern);

        return kind == "Or"
            && pattern.GetProperty("alternatives").EnumerateArray().Any(PatternCoversOptionSome);
    }

    private static bool OptionSomePatternCoversAllPayloads(JsonElement pattern)
    {
        return PatternCoversAllValues(pattern.GetProperty("payload"));
    }

    private static bool PatternCoversAllValues(JsonElement pattern)
    {
        var kind = pattern.GetProperty("kind").GetString();
        if (kind is "Wildcard" or "Binding")
            return true;

        if (kind == "Tuple")
            return pattern.GetProperty("items").EnumerateArray().All(PatternCoversAllValues);

        if (kind == "Array")
            return ArrayPatternCoversAllLengths(pattern);

        return kind == "Or"
            && pattern.GetProperty("alternatives").EnumerateArray().Any(PatternCoversAllValues);
    }

    private bool FinalEnumArmCoversRemainder(
        string targetTypeId,
        JsonElement[] arms,
        int finalArmIndex
    )
    {
        if (!typeDefinitions.TryGetValue(targetTypeId, out var typeDefinition))
            return false;

        var finalPattern = arms[finalArmIndex].GetProperty("pattern");
        if (
            finalPattern.GetProperty("kind").GetString() != "EnumCase"
            || !string.Equals(
                finalPattern.GetProperty("typeId").GetString(),
                targetTypeId,
                StringComparison.Ordinal
            )
        )
            return false;

        var variants = typeDefinition
            .GetProperty("variants")
            .EnumerateArray()
            .Select(variant => variant.GetProperty("name").GetString() ?? "")
            .Where(name => name.Length > 0)
            .ToHashSet(StringComparer.Ordinal);
        if (variants.Count == 0)
            return false;

        for (var i = 0; i < finalArmIndex; i++)
        {
            if (arms[i].TryGetProperty("condition", out _))
                continue;

            AddCoveredEnumVariants(arms[i].GetProperty("pattern"), targetTypeId, variants);
        }

        variants.Remove(finalPattern.GetProperty("name").GetString() ?? "");
        return variants.Count == 0;
    }

    private static void AddCoveredEnumVariants(
        JsonElement pattern,
        string targetTypeId,
        HashSet<string> uncoveredVariants
    )
    {
        var kind = pattern.GetProperty("kind").GetString();
        if (kind is "Wildcard" or "Binding")
        {
            uncoveredVariants.Clear();
            return;
        }

        if (kind == "EnumCase")
        {
            if (
                string.Equals(
                    pattern.GetProperty("typeId").GetString(),
                    targetTypeId,
                    StringComparison.Ordinal
                )
            )
                uncoveredVariants.Remove(pattern.GetProperty("name").GetString() ?? "");
            return;
        }

        if (kind != "Or")
            return;

        foreach (var alternative in pattern.GetProperty("alternatives").EnumerateArray())
            AddCoveredEnumVariants(alternative, targetTypeId, uncoveredVariants);
    }

    private static bool TryGetDeclaredTypeId(JsonElement type, out string typeId)
    {
        if (type.GetProperty("kind").GetString() == "Declared")
        {
            typeId = type.GetProperty("symbol").GetProperty("id").GetString() ?? "";
            return typeId.Length > 0;
        }

        typeId = "";
        return false;
    }

    private static JsonElement FindVariantDefinition(JsonElement typeDefinition, string name)
    {
        foreach (var variant in typeDefinition.GetProperty("variants").EnumerateArray())
            if (variant.GetProperty("name").GetString() == name)
                return variant;

        return default;
    }

    private static string PayloadVariantTypeName(string targetTypeName, string variantName)
    {
        return targetTypeName + "." + variantName + "Variant";
    }

    private static JsonElement OptionElementType(JsonElement targetType)
    {
        if (!IsBuiltinApply(targetType, "Option"))
            throw new NotSupportedException("vnext Option match pattern target must be Option[T]");

        return targetType.GetProperty("args").EnumerateArray().First();
    }

    private static string RangePatternExpression(JsonElement pattern)
    {
        var parts = new List<string>();
        if (pattern.GetProperty("start").ValueKind == JsonValueKind.String)
            parts.Add(
                ">= " + RangePatternBoundExpression(pattern.GetProperty("start").GetString() ?? "")
            );

        if (pattern.GetProperty("end").ValueKind == JsonValueKind.String)
            parts.Add(
                (pattern.GetProperty("inclusive").GetBoolean() ? "<= " : "< ")
                    + RangePatternBoundExpression(pattern.GetProperty("end").GetString() ?? "")
            );

        return parts.Count == 0 ? "_" : string.Join(" and ", parts);
    }

    private static string RangeBoundExpression(string value)
    {
        return long.TryParse(value, NumberStyles.Integer, null, out _)
            ? value
            : CharLiteralCodePoint(value).ToString(CultureInfo.InvariantCulture);
    }

    private static string RangePatternBoundExpression(string value)
    {
        return long.TryParse(value, NumberStyles.Integer, null, out _)
            ? value
            : CharPatternConstant(value);
    }

    private static string CharPatternConstant(string value)
    {
        var codePoint = CharLiteralCodePoint(value);
        if (codePoint <= char.MaxValue)
            return LiteralExpression(
                    SyntaxKind.CharacterLiteralExpression,
                    Literal((char)codePoint)
                )
                .NormalizeWhitespace()
                .ToFullString();

        return codePoint.ToString(CultureInfo.InvariantCulture);
    }

    private static JsonElement ArrayElementType(JsonElement targetType)
    {
        if (IsBuiltinType(targetType, "String") || IsBuiltinType(targetType, "StringView"))
        {
            using var document = JsonDocument.Parse("""{"kind":"Builtin","name":"Char"}""");
            return document.RootElement.Clone();
        }

        if (
            !IsBuiltinApply(targetType, "Array")
            && !IsBuiltinApply(targetType, "FixedArray")
            && !IsBuiltinApply(targetType, "ArrayView")
        )
            throw new NotSupportedException("vnext array match pattern target must be array type");

        return targetType.GetProperty("args").EnumerateArray().First();
    }

    private static bool HasArrayRest(JsonElement pattern)
    {
        return pattern.TryGetProperty("rest", out var rest)
            && rest.ValueKind == JsonValueKind.Object;
    }

    private static JsonElement? ArrayPatternRestSymbol(JsonElement pattern)
    {
        if (!HasArrayRest(pattern))
            return null;

        var symbol = pattern.GetProperty("rest").GetProperty("symbol");
        return symbol.ValueKind == JsonValueKind.Object ? symbol : null;
    }

    private static bool PatternHasBoundArrayRest(JsonElement pattern)
    {
        return BoundArrayRestSymbolIds(pattern).Count > 0;
    }

    private static HashSet<string> BoundArrayRestSymbolIds(JsonElement pattern)
    {
        var result = new HashSet<string>(StringComparer.Ordinal);
        AddBoundArrayRestSymbolIds(pattern, result);
        return result;
    }

    private static void AddBoundArrayRestSymbolIds(JsonElement pattern, HashSet<string> result)
    {
        var kind = pattern.GetProperty("kind").GetString();
        switch (kind)
        {
            case "Array":
            {
                var symbol = ArrayPatternRestSymbol(pattern);
                if (symbol.HasValue)
                {
                    var id = symbol.Value.GetProperty("id").GetString();
                    if (!string.IsNullOrEmpty(id))
                        result.Add(id);
                }

                foreach (var item in pattern.GetProperty("items").EnumerateArray())
                    AddBoundArrayRestSymbolIds(item, result);

                foreach (var item in ArrayPatternSuffix(pattern))
                    AddBoundArrayRestSymbolIds(item, result);
                return;
            }

            case "Tuple":
            {
                foreach (var item in pattern.GetProperty("items").EnumerateArray())
                    AddBoundArrayRestSymbolIds(item, result);
                return;
            }

            case "Or":
            {
                foreach (var alternative in pattern.GetProperty("alternatives").EnumerateArray())
                    AddBoundArrayRestSymbolIds(alternative, result);
                return;
            }

            case "OptionSome":
                AddBoundArrayRestSymbolIds(pattern.GetProperty("payload"), result);
                return;
            case "EnumCase":
            {
                foreach (var payload in pattern.GetProperty("payloads").EnumerateArray())
                    AddBoundArrayRestSymbolIds(payload, result);

                break;
            }
        }
    }

    private static JsonElement[] ArrayPatternSuffix(JsonElement pattern)
    {
        return pattern.TryGetProperty("suffix", out var suffix)
            ? suffix.EnumerateArray().ToArray()
            : [];
    }

    private string ArrayRestViewExpression(
        string value,
        int start,
        int suffixLength,
        JsonElement symbol
    )
    {
        var symbolType = symbol.GetProperty("type");
        if (IsBuiltinType(symbolType, "StringView"))
        {
            var source = "((MoonBitStringView)" + value + ")";
            return source
                + ".Sub("
                + start.ToString(CultureInfo.InvariantCulture)
                + ", "
                + source
                + ".Length - "
                + suffixLength.ToString(CultureInfo.InvariantCulture)
                + ")";
        }

        var elementType = ArrayElementType(symbolType);
        var elementTypeName = EmitType(elementType).NormalizeWhitespace().ToFullString();
        return "new MoonBitArrayView<"
            + elementTypeName
            + ">("
            + value
            + ", "
            + start.ToString(CultureInfo.InvariantCulture)
            + ", "
            + value
            + ".Length - "
            + suffixLength.ToString(CultureInfo.InvariantCulture)
            + ")";
    }

    private static JsonElement TupleItemType(JsonElement targetType, int index)
    {
        if (targetType.GetProperty("kind").GetString() != "Tuple")
            throw new NotSupportedException("vnext tuple match pattern target must be tuple type");

        return targetType.GetProperty("items").EnumerateArray().ElementAt(index);
    }
}
