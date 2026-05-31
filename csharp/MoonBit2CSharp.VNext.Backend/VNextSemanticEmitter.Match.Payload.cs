using System.Globalization;
using System.Text;
using System.Text.Json;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using static Microsoft.CodeAnalysis.CSharp.SyntaxFactory;

namespace MoonBit2CSharp.VNext.Backend;

public sealed partial class VNextSemanticEmitter
{
    private void EmitPayloadEnumMatchAsReturn(
        string target,
        JsonElement targetType,
        JsonElement[] arms,
        List<StatementSyntax> statements
    )
    {
        var targetTypeName = EmitType(targetType).NormalizeWhitespace().ToFullString();
        if (
            !TryGetDeclaredTypeId(targetType, out var targetTypeId)
            || !typeDefinitions.TryGetValue(targetTypeId, out var targetTypeDefinition)
        )
            throw new NotSupportedException("vnext payload enum match target type is not declared");

        var matchName = "__moonbitMatch" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
        statements.Add(ParseStatement($"var {matchName} = {target};"));
        var builder = new StringBuilder("switch (".Length + matchName.Length + ".Kind) { ".Length);
        builder.Append("switch (").Append(matchName).Append(".Kind) { ");
        var variants = targetTypeDefinition.GetProperty("variants").EnumerateArray().ToArray();
        for (var variantIndex = 0; variantIndex < variants.Length; variantIndex++)
        {
            var variant = variants[variantIndex];
            var sourceVariantName = variant.GetProperty("name").GetString() ?? "";
            var variantName = EnumVariantMemberName(targetTypeName, sourceVariantName);
            AppendPayloadEnumSwitchCaseHeader(
                builder,
                targetTypeName,
                variantName,
                variantIndex == variants.Length - 1
            );
            var payloadTypes = variant.GetProperty("payloads").EnumerateArray().ToArray();
            var payloadName = "";
            if (payloadTypes.Length > 0)
            {
                payloadName =
                    "__moonbitPayload" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
                builder
                    .Append("var ")
                    .Append(payloadName)
                    .Append(" = System.Runtime.CompilerServices.Unsafe.As<")
                    .Append(PayloadVariantTypeName(targetTypeName, variantName))
                    .Append(">(")
                    .Append(matchName)
                    .Append("); ");
            }

            var caseReturns = false;
            foreach (var arm in arms)
            {
                var pattern = arm.GetProperty("pattern");
                var kind = pattern.GetProperty("kind").GetString();
                if (kind == "Wildcard")
                {
                    caseReturns = EmitPayloadEnumArmReturn(
                        builder,
                        arm.GetProperty("body"),
                        "",
                        MatchArmConditionExpression(arm),
                        "",
                        []
                    );
                    if (caseReturns)
                        break;

                    continue;
                }

                if (kind == "Or")
                {
                    caseReturns = EmitPayloadEnumOrArmReturn(
                        builder,
                        arm,
                        sourceVariantName,
                        payloadName,
                        payloadTypes
                    );
                    if (caseReturns)
                        break;
                    continue;
                }

                if (
                    kind != "EnumCase"
                    || !string.Equals(
                        pattern.GetProperty("name").GetString(),
                        sourceVariantName,
                        StringComparison.Ordinal
                    )
                )
                    continue;

                var payloads = pattern.GetProperty("payloads").EnumerateArray().ToArray();
                var condition = PayloadPatternsCondition(payloadName, payloadTypes, payloads);
                if (
                    EmitPayloadEnumArmReturn(
                        builder,
                        arm.GetProperty("body"),
                        condition,
                        MatchArmConditionExpression(arm),
                        payloadName,
                        payloads
                    )
                )
                {
                    caseReturns = true;
                    break;
                }
            }

            if (!caseReturns)
                builder.Append("break; ");

            builder.Append("} ");
        }

        builder.Append("}");
        statements.Add(ParseStatement(builder.ToString()));
    }

    private void EmitPayloadEnumMatchAsAssignment(
        string target,
        JsonElement targetType,
        JsonElement[] arms,
        string destination,
        List<StatementSyntax> statements
    )
    {
        var targetTypeName = EmitType(targetType).NormalizeWhitespace().ToFullString();
        if (
            !TryGetDeclaredTypeId(targetType, out var targetTypeId)
            || !typeDefinitions.TryGetValue(targetTypeId, out var targetTypeDefinition)
        )
            throw new NotSupportedException("vnext payload enum match target type is not declared");

        var matchName = "__moonbitMatch" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
        var doneLabel =
            "__moonbitMatchDone" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
        statements.Add(ParseStatement($"var {matchName} = {target};"));
        var builder = new StringBuilder();
        builder.Append("switch (").Append(matchName).Append(".Kind) { ");
        var variants = targetTypeDefinition.GetProperty("variants").EnumerateArray().ToArray();
        for (var variantIndex = 0; variantIndex < variants.Length; variantIndex++)
        {
            var variant = variants[variantIndex];
            var sourceVariantName = variant.GetProperty("name").GetString() ?? "";
            var variantName = EnumVariantMemberName(targetTypeName, sourceVariantName);
            AppendPayloadEnumSwitchCaseHeader(
                builder,
                targetTypeName,
                variantName,
                variantIndex == variants.Length - 1
            );
            var payloadTypes = variant.GetProperty("payloads").EnumerateArray().ToArray();
            var payloadName = "";
            if (payloadTypes.Length > 0)
            {
                payloadName =
                    "__moonbitPayload" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
                builder
                    .Append("var ")
                    .Append(payloadName)
                    .Append(" = System.Runtime.CompilerServices.Unsafe.As<")
                    .Append(PayloadVariantTypeName(targetTypeName, variantName))
                    .Append(">(")
                    .Append(matchName)
                    .Append("); ");
            }

            var caseAssigns = false;
            foreach (var arm in arms)
            {
                var pattern = arm.GetProperty("pattern");
                var kind = pattern.GetProperty("kind").GetString();
                if (kind == "Wildcard")
                {
                    caseAssigns = EmitPayloadEnumArmAssignment(
                        builder,
                        arm.GetProperty("body"),
                        "",
                        MatchArmConditionExpression(arm),
                        "",
                        [],
                        destination,
                        doneLabel
                    );
                    if (caseAssigns)
                        break;

                    continue;
                }

                if (kind == "Or")
                {
                    caseAssigns = EmitPayloadEnumOrArmAssignment(
                        builder,
                        arm,
                        sourceVariantName,
                        payloadName,
                        payloadTypes,
                        destination,
                        doneLabel
                    );
                    if (caseAssigns)
                        break;
                    continue;
                }

                if (
                    kind != "EnumCase"
                    || !string.Equals(
                        pattern.GetProperty("name").GetString(),
                        sourceVariantName,
                        StringComparison.Ordinal
                    )
                )
                    continue;

                var payloads = pattern.GetProperty("payloads").EnumerateArray().ToArray();
                var condition = PayloadPatternsCondition(payloadName, payloadTypes, payloads);
                if (
                    EmitPayloadEnumArmAssignment(
                        builder,
                        arm.GetProperty("body"),
                        condition,
                        MatchArmConditionExpression(arm),
                        payloadName,
                        payloads,
                        destination,
                        doneLabel
                    )
                )
                {
                    caseAssigns = true;
                    break;
                }
            }

            if (!caseAssigns)
                builder.Append("break; ");

            builder.Append("} ");
        }

        builder.Append("}");
        statements.Add(ParseStatement(builder.ToString()));
        statements.Add(ParseStatement(doneLabel + ": ;"));
    }

    private void EmitPayloadEnumMatchAsStatement(
        string target,
        JsonElement targetType,
        JsonElement[] arms,
        List<StatementSyntax> statements
    )
    {
        var targetTypeName = EmitType(targetType).NormalizeWhitespace().ToFullString();
        if (
            !TryGetDeclaredTypeId(targetType, out var targetTypeId)
            || !typeDefinitions.TryGetValue(targetTypeId, out var targetTypeDefinition)
        )
            throw new NotSupportedException("vnext payload enum match target type is not declared");

        var matchName = "__moonbitMatch" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
        var matchedName =
            "__moonbitMatched" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
        var builder = new StringBuilder();
        builder.Append("var ").Append(matchName).Append(" = ").Append(target).Append("; ");
        builder.Append("var ").Append(matchedName).Append(" = false; ");
        foreach (var arm in arms)
            AppendPayloadEnumStatementArm(
                builder,
                targetType,
                targetTypeName,
                targetTypeDefinition,
                matchName,
                matchedName,
                arm
            );

        statements.Add(ParseStatement("{ " + builder + " }"));
    }

    private static void AppendPayloadEnumSwitchCaseHeader(
        StringBuilder builder,
        string targetTypeName,
        string variantName,
        bool useDefault
    )
    {
        if (useDefault)
        {
            builder.Append("default: { ");
            return;
        }

        builder
            .Append("case ")
            .Append(targetTypeName)
            .Append(".Tag.")
            .Append(variantName)
            .Append(": { ");
    }

    private bool EmitPayloadEnumOrArmReturn(
        StringBuilder builder,
        JsonElement arm,
        string sourceVariantName,
        string payloadName,
        JsonElement[] payloadTypes
    )
    {
        foreach (
            var alternative in arm.GetProperty("pattern")
                .GetProperty("alternatives")
                .EnumerateArray()
        )
        {
            var condition = PayloadEnumAlternativeCondition(
                alternative,
                sourceVariantName,
                payloadName,
                payloadTypes,
                out var alternativePayloads
            );
            if (condition is null)
                continue;

            if (
                EmitPayloadEnumArmReturn(
                    builder,
                    arm.GetProperty("body"),
                    condition,
                    MatchArmConditionExpression(arm),
                    payloadName,
                    alternativePayloads
                )
            )
                return true;
        }

        return false;
    }

    private bool EmitPayloadEnumOrArmAssignment(
        StringBuilder builder,
        JsonElement arm,
        string sourceVariantName,
        string payloadName,
        JsonElement[] payloadTypes,
        string destination,
        string doneLabel
    )
    {
        foreach (
            var alternative in arm.GetProperty("pattern")
                .GetProperty("alternatives")
                .EnumerateArray()
        )
        {
            var condition = PayloadEnumAlternativeCondition(
                alternative,
                sourceVariantName,
                payloadName,
                payloadTypes,
                out var alternativePayloads
            );
            if (condition is null)
                continue;

            if (
                EmitPayloadEnumArmAssignment(
                    builder,
                    arm.GetProperty("body"),
                    condition,
                    MatchArmConditionExpression(arm),
                    payloadName,
                    alternativePayloads,
                    destination,
                    doneLabel
                )
            )
                return true;
        }

        return false;
    }

    private string? PayloadEnumAlternativeCondition(
        JsonElement alternative,
        string sourceVariantName,
        string payloadName,
        JsonElement[] payloadTypes,
        out JsonElement[] payloads
    )
    {
        payloads = [];
        var kind = alternative.GetProperty("kind").GetString();
        if (kind is "Wildcard" or "Binding")
            return "true";

        if (
            kind != "EnumCase"
            || !string.Equals(
                alternative.GetProperty("name").GetString(),
                sourceVariantName,
                StringComparison.Ordinal
            )
        )
            return null;

        payloads = alternative.GetProperty("payloads").EnumerateArray().ToArray();
        return PayloadPatternsCondition(payloadName, payloadTypes, payloads);
    }

    private void AppendPayloadEnumStatementArm(
        StringBuilder builder,
        JsonElement targetType,
        string targetTypeName,
        JsonElement targetTypeDefinition,
        string matchName,
        string matchedName,
        JsonElement arm
    )
    {
        var pattern = arm.GetProperty("pattern");
        var kind = pattern.GetProperty("kind").GetString();
        if (kind == "Wildcard")
        {
            AppendPayloadEnumStatementArmBody(
                builder,
                matchedName,
                MatchArmConditionExpression(arm),
                "",
                [],
                arm.GetProperty("body")
            );
            return;
        }

        if (kind == "Or")
        {
            foreach (var alternative in pattern.GetProperty("alternatives").EnumerateArray())
                AppendPayloadEnumStatementPatternArm(
                    builder,
                    targetTypeDefinition,
                    targetTypeName,
                    matchName,
                    matchedName,
                    alternative,
                    arm
                );
            return;
        }

        AppendPayloadEnumStatementPatternArm(
            builder,
            targetTypeDefinition,
            targetTypeName,
            matchName,
            matchedName,
            pattern,
            arm
        );
    }

    private void AppendPayloadEnumStatementPatternArm(
        StringBuilder builder,
        JsonElement targetTypeDefinition,
        string targetTypeName,
        string matchName,
        string matchedName,
        JsonElement pattern,
        JsonElement arm
    )
    {
        var kind = pattern.GetProperty("kind").GetString();
        if (kind != "EnumCase")
            return;

        var variant = FindVariantDefinition(
            targetTypeDefinition,
            pattern.GetProperty("name").GetString() ?? ""
        );
        if (variant.ValueKind == JsonValueKind.Undefined)
            return;

        var variantName = EnumVariantMemberName(
            targetTypeName,
            pattern.GetProperty("name").GetString() ?? ""
        );
        var payloadTypes = variant.GetProperty("payloads").EnumerateArray().ToArray();
        var payloads = pattern.GetProperty("payloads").EnumerateArray().ToArray();
        builder
            .Append("if (!")
            .Append(matchedName)
            .Append(" && ")
            .Append(matchName)
            .Append(".Kind == ")
            .Append(targetTypeName)
            .Append(".Tag.")
            .Append(variantName)
            .Append(") { ");
        var payloadName = "";
        if (payloadTypes.Length > 0)
        {
            payloadName =
                "__moonbitPayload" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
            builder
                .Append("var ")
                .Append(payloadName)
                .Append(" = System.Runtime.CompilerServices.Unsafe.As<")
                .Append(PayloadVariantTypeName(targetTypeName, variantName))
                .Append(">(")
                .Append(matchName)
                .Append("); ");
        }

        var payloadCondition = PayloadPatternsCondition(payloadName, payloadTypes, payloads);
        var armCondition = MatchArmConditionExpression(arm);
        var condition = payloadCondition;
        if (!string.IsNullOrWhiteSpace(armCondition))
            condition = condition == "true" ? armCondition : condition + " && " + armCondition;
        AppendPayloadEnumStatementArmBody(
            builder,
            matchedName,
            condition,
            payloadName,
            payloads,
            arm.GetProperty("body")
        );
        builder.Append("} ");
    }

    private void AppendPayloadEnumStatementArmBody(
        StringBuilder builder,
        string matchedName,
        string condition,
        string payloadName,
        JsonElement[] payloads,
        JsonElement body
    )
    {
        builder.Append("if (!").Append(matchedName);
        if (!string.IsNullOrWhiteSpace(condition))
            builder.Append(" && ").Append(condition);
        builder.Append(") { ");
        builder.Append(matchedName).Append(" = true; ");
        EmitPayloadPatternBindings(builder, payloadName, payloads);
        AppendStatementBody(builder, body);
        builder.Append("} ");
    }

    private static void RejectArrayRestBindingsThatNeedExpressionMaterialization(JsonElement[] arms)
    {
        foreach (var arm in arms)
        {
            var pattern = arm.GetProperty("pattern");
            var restSymbols = BoundArrayRestSymbolIds(pattern);
            if (
                ExprReferencesAnySymbol(arm.GetProperty("body"), restSymbols)
                || (
                    arm.TryGetProperty("condition", out var condition)
                    && ExprReferencesAnySymbol(condition, restSymbols)
                )
            )
                throw new NotSupportedException(
                    "vnext array rest pattern binding requires ArrayView materialization"
                );
        }
    }

    private ExpressionSyntax EmitIsPatternExpression(JsonElement expr)
    {
        var target = EmitExpr(expr.GetProperty("target")).NormalizeWhitespace().ToFullString();
        var targetType = expr.GetProperty("target").GetProperty("type");
        var pattern = expr.GetProperty("pattern");
        return ParseExpression(IsPatternCondition(target, targetType, pattern));
    }

    private void EmitPatternGuard(
        JsonElement condition,
        List<StatementSyntax> elseStatements,
        List<StatementSyntax> statements
    )
    {
        var target = condition.GetProperty("target");
        var targetType = target.GetProperty("type");
        var pattern = condition.GetProperty("pattern");
        var targetName = "__moonbitGuard" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
        statements.Add(
            LocalDeclarationStatement(
                VariableDeclaration(EmitType(targetType))
                    .WithVariables(
                        SingletonSeparatedList(
                            VariableDeclarator(targetName)
                                .WithInitializer(EqualsValueClause(EmitExpr(target)))
                        )
                    )
            )
        );
        statements.Add(
            IfStatement(
                PrefixUnaryExpression(
                    SyntaxKind.LogicalNotExpression,
                    ParenthesizedExpression(
                        ParseExpression(
                            IsPatternCondition(
                                targetName,
                                targetType,
                                pattern,
                                suppressBindings: true
                            )
                        )
                    )
                ),
                Block(elseStatements)
            )
        );

        var builder = new StringBuilder();
        EmitPatternBindings(builder, targetName, pattern);
        var bindingText = builder.ToString();
        if (bindingText.Length == 0)
            return;

        statements.AddRange(((BlockSyntax)ParseStatement("{ " + bindingText + " }")).Statements);
    }

    private string IsPatternCondition(
        string target,
        JsonElement targetType,
        JsonElement pattern,
        bool suppressBindings = false
    )
    {
        if (pattern.GetProperty("kind").GetString() == "Or")
            return "("
                + string.Join(
                    ") || (",
                    pattern
                        .GetProperty("alternatives")
                        .EnumerateArray()
                        .Select(alternative =>
                            IsPatternCondition(target, targetType, alternative, suppressBindings)
                        )
                )
                + ")";

        if (!IsPayloadEnumPattern(targetType, pattern))
            return target
                + " is "
                + (
                    suppressBindings
                        ? MatchConditionPatternExpression(targetType, pattern)
                        : MatchTestPatternExpression(targetType, pattern)
                );

        var targetTypeName = EmitType(targetType).NormalizeWhitespace().ToFullString();
        var variantName = EnumVariantMemberName(
            targetTypeName,
            pattern.GetProperty("name").GetString() ?? ""
        );
        var condition = PayloadEnumIsPatternCondition(target, targetTypeName, variantName, pattern);
        return "("
            + target
            + ".Kind == "
            + targetTypeName
            + ".Tag."
            + variantName
            + ")"
            + (condition == "true" ? "" : " && (" + condition + ")");
    }

    private bool IsPayloadEnumPattern(JsonElement targetType, JsonElement pattern)
    {
        if (pattern.GetProperty("kind").GetString() != "EnumCase")
            return false;

        return TryGetDeclaredTypeId(targetType, out var targetTypeId)
            && typeDefinitions.TryGetValue(targetTypeId, out var typeDefinition)
            && !IsAllConstantEnum(typeDefinition);
    }

    private string PayloadEnumIsPatternCondition(
        string targetName,
        string targetTypeName,
        string variantName,
        JsonElement pattern
    )
    {
        if (
            !typeDefinitions.TryGetValue(
                pattern.GetProperty("typeId").GetString() ?? "",
                out var typeDefinition
            )
        )
            return "true";

        var variant = FindVariantDefinition(
            typeDefinition,
            pattern.GetProperty("name").GetString() ?? ""
        );
        if (variant.ValueKind == JsonValueKind.Undefined)
            return "true";

        var payloads = pattern.GetProperty("payloads").EnumerateArray().ToArray();
        if (payloads.Length == 0)
            return "true";

        var payloadTypes = variant.GetProperty("payloads").EnumerateArray().ToArray();
        var payloadAccess =
            "System.Runtime.CompilerServices.Unsafe.As<"
            + PayloadVariantTypeName(targetTypeName, variantName)
            + ">("
            + targetName
            + ")";
        return PayloadPatternsCondition(payloadAccess, payloadTypes, payloads);
    }

    private bool CanEmitPayloadEnumTagSwitch(JsonElement targetType, JsonElement[] arms)
    {
        if (!TryGetDeclaredTypeId(targetType, out var targetTypeId))
            return false;

        if (
            !typeDefinitions.TryGetValue(targetTypeId, out var targetTypeDefinition)
            || IsAllConstantEnum(targetTypeDefinition)
        )
            return false;

        foreach (var arm in arms)
        {
            var pattern = arm.GetProperty("pattern");
            var kind = pattern.GetProperty("kind").GetString();
            if (kind == "Wildcard")
                continue;

            if (kind == "Or" && PayloadEnumOrPatternUsesTargetType(pattern, targetTypeId))
                continue;

            if (kind != "EnumCase")
                return false;

            if (
                !string.Equals(
                    pattern.GetProperty("typeId").GetString(),
                    targetTypeId,
                    StringComparison.Ordinal
                )
            )
                return false;
        }

        return true;
    }

    private static bool PayloadEnumOrPatternUsesTargetType(JsonElement pattern, string targetTypeId)
    {
        foreach (var alternative in pattern.GetProperty("alternatives").EnumerateArray())
        {
            var kind = alternative.GetProperty("kind").GetString();
            if (kind == "Wildcard")
                continue;

            if (kind == "Or")
            {
                if (!PayloadEnumOrPatternUsesTargetType(alternative, targetTypeId))
                    return false;
                continue;
            }

            if (
                kind != "EnumCase"
                || !string.Equals(
                    alternative.GetProperty("typeId").GetString(),
                    targetTypeId,
                    StringComparison.Ordinal
                )
            )
                return false;
        }

        return true;
    }

    private bool EmitPayloadEnumArmReturn(
        StringBuilder builder,
        JsonElement body,
        string payloadCondition,
        string armCondition,
        string payloadName,
        JsonElement[] payloads
    )
    {
        var payloadIsUnconditional =
            string.IsNullOrWhiteSpace(payloadCondition) || payloadCondition == "true";
        var armIsUnconditional = string.IsNullOrWhiteSpace(armCondition);
        if (!payloadIsUnconditional)
            builder.Append("if (").Append(payloadCondition).Append(") { ");

        EmitPayloadPatternBindings(builder, payloadName, payloads);
        if (!armIsUnconditional)
            builder.Append("if (").Append(armCondition).Append(") { ");
        AppendReturnBody(builder, body);

        if (!armIsUnconditional)
            builder.Append("} ");

        if (!payloadIsUnconditional)
            builder.Append("} ");

        return payloadIsUnconditional && armIsUnconditional;
    }

    private void AppendReturnBody(StringBuilder builder, JsonElement body)
    {
        if (!ExprNeedsReturnStatementLowering(body))
        {
            builder
                .Append("return ")
                .Append(EmitExpr(body).NormalizeWhitespace().ToFullString())
                .Append("; ");
            return;
        }

        var statements = new List<StatementSyntax>();
        EmitExprAsReturn(body, statements);
        AppendStatements(builder, statements);
    }

    private void AppendAssignmentBody(
        StringBuilder builder,
        JsonElement body,
        string destination,
        string doneLabel
    )
    {
        var statements = new List<StatementSyntax>();
        EmitExprAsAssignment(body, destination, statements);
        AppendStatements(builder, statements);
        if (!StatementListTerminates(statements))
            builder.Append("goto ").Append(doneLabel).Append("; ");
    }

    private void AppendStatementBody(StringBuilder builder, JsonElement body)
    {
        var statements = new List<StatementSyntax>();
        EmitExprAsStatement(body, statements);
        AppendStatements(builder, statements);
    }

    private static void AppendStatements(
        StringBuilder builder,
        IReadOnlyList<StatementSyntax> statements
    )
    {
        foreach (var statement in statements)
        {
            builder.Append(statement.NormalizeWhitespace().ToFullString()).Append(' ');
            if (StatementTerminates(statement))
                break;
        }
    }

    private bool EmitPayloadEnumArmAssignment(
        StringBuilder builder,
        JsonElement body,
        string payloadCondition,
        string armCondition,
        string payloadName,
        JsonElement[] payloads,
        string destination,
        string doneLabel
    )
    {
        var payloadIsUnconditional =
            string.IsNullOrWhiteSpace(payloadCondition) || payloadCondition == "true";
        var armIsUnconditional = string.IsNullOrWhiteSpace(armCondition);
        if (!payloadIsUnconditional)
            builder.Append("if (").Append(payloadCondition).Append(") { ");

        EmitPayloadPatternBindings(builder, payloadName, payloads);
        if (!armIsUnconditional)
            builder.Append("if (").Append(armCondition).Append(") { ");
        AppendAssignmentBody(builder, body, destination, doneLabel);

        if (!armIsUnconditional)
            builder.Append("} ");

        if (!payloadIsUnconditional)
            builder.Append("} ");

        return payloadIsUnconditional && armIsUnconditional;
    }
}
