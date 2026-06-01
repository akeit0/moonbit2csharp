using System.Globalization;
using System.Text;
using System.Text.Json;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using static Microsoft.CodeAnalysis.CSharp.SyntaxFactory;

namespace MoonBit2CSharp.VNext.Backend;

public sealed partial class VNextSemanticEmitter
{
    private ExpressionSyntax EmitMatchExpression(JsonElement expr)
    {
        var target = EmitExpr(expr.GetProperty("target")).NormalizeWhitespace().ToFullString();
        var targetType = expr.GetProperty("target").GetProperty("type");
        var arms = expr.GetProperty("arms").EnumerateArray().ToArray();
        RejectArrayRestBindingsThatNeedExpressionMaterialization(arms);
        if (!CanEmitSwitchExpression(targetType, arms))
            throw new NotSupportedException("vnext match expression requires statement lowering");

        return ParseExpression(
            target + " switch { " + string.Join(", ", SwitchExpressionArms(targetType, arms)) + " }"
        );
    }

    private IEnumerable<string> SwitchExpressionArms(JsonElement targetType, JsonElement[] arms)
    {
        foreach (var arm in arms)
        {
            yield return MatchPatternExpression(targetType, arm.GetProperty("pattern"))
                + MatchArmCondition(arm)
                + " => "
                + EmitExpr(arm.GetProperty("body")).NormalizeWhitespace().ToFullString();
        }

        if (!SwitchExpressionEndsWithIrrefutableArm(targetType, arms))
            yield return "_ => throw new System.Diagnostics.UnreachableException()";
    }

    private bool SwitchExpressionEndsWithIrrefutableArm(JsonElement targetType, JsonElement[] arms)
    {
        if (arms.Length == 0)
            return false;

        var finalArm = arms[^1];
        if (finalArm.TryGetProperty("condition", out _))
            return false;

        if (IsBuiltinApply(targetType, "Option"))
            return FinalOptionArmCoversRemainder(arms, arms.Length - 1);

        return IsIrrefutableSwitchPattern(targetType, finalArm.GetProperty("pattern"));
    }

    private bool MatchNeedsStatementLowering(JsonElement expr)
    {
        var targetType = expr.GetProperty("target").GetProperty("type");
        var arms = expr.GetProperty("arms").EnumerateArray().ToArray();
        if (!CanEmitSwitchExpression(targetType, arms))
            return true;

        if (CanEmitPayloadEnumTagSwitch(targetType, arms))
            return true;

        foreach (var arm in expr.GetProperty("arms").EnumerateArray())
        {
            if (ExprNeedsReturnStatementLowering(arm.GetProperty("body")))
                return true;

            if (
                ExprReferencesAnySymbol(
                    arm.GetProperty("body"),
                    BoundArrayRestSymbolIds(arm.GetProperty("pattern"))
                )
                || (
                    arm.TryGetProperty("condition", out var condition)
                    && ExprReferencesAnySymbol(
                        condition,
                        BoundArrayRestSymbolIds(arm.GetProperty("pattern"))
                    )
                )
            )
                return true;
        }

        return false;
    }

    private void EmitMatchAsReturn(JsonElement expr, List<StatementSyntax> statements)
    {
        var target = EmitExpr(expr.GetProperty("target")).NormalizeWhitespace().ToFullString();
        var targetType = expr.GetProperty("target").GetProperty("type");
        var arms = expr.GetProperty("arms").EnumerateArray().ToArray();
        if (CanEmitPayloadEnumTagSwitch(targetType, arms))
        {
            EmitPayloadEnumMatchAsReturn(target, targetType, arms, statements);
            return;
        }

        var matchName = "__moonbitMatch" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
        statements.Add(ParseStatement($"var {matchName} = {target};"));
        if (!CanEmitSwitchExpression(targetType, arms))
        {
            EmitConditionMatchAsReturn(matchName, targetType, arms, statements);
            return;
        }

        if (CanEmitSingleSwitchStatement(arms))
        {
            EmitSingleSwitchMatchAsReturn(matchName, targetType, arms, statements);
            return;
        }

        for (var i = 0; i < arms.Length; i++)
        {
            var arm = arms[i];
            var pattern = arm.GetProperty("pattern");
            var builder = new StringBuilder();
            builder.Append("switch (").Append(matchName).Append(") { ");
            if (UseDefaultBranchForFinalArm(targetType, arms, i))
                builder.Append("default: { ");
            else
                builder
                    .Append("case ")
                    .Append(MatchStatementCasePatternExpression(targetType, pattern))
                    .Append(": { ");
            EmitPatternBindingsAfterCase(builder, matchName, targetType, arms, i, pattern);
            var condition = MatchArmConditionExpression(arm);
            if (condition.Length > 0)
                builder.Append("if (").Append(condition).Append(") { ");
            AppendReturnBody(builder, arm.GetProperty("body"));
            if (condition.Length > 0)
                builder.Append("} ");
            if (condition.Length > 0)
                builder.Append("break; ");
            builder.Append("} }");
            statements.Add(ParseStatement(builder.ToString()));
        }

        // MoonBit rejects non-exhaustive matches before executable IR reaches the backend.
        // Do not add a runtime fallback here; guarded arms that miss are frontend-invalid.
    }

    private void EmitConditionMatchAsReturn(
        string matchName,
        JsonElement targetType,
        JsonElement[] arms,
        List<StatementSyntax> statements
    )
    {
        var builder = new StringBuilder();
        foreach (var arm in arms)
        {
            var pattern = arm.GetProperty("pattern");
            if (pattern.GetProperty("kind").GetString() == "Or")
                foreach (var alternative in pattern.GetProperty("alternatives").EnumerateArray())
                    AppendReturnMatchArm(builder, matchName, targetType, alternative, arm);
            else
                AppendReturnMatchArm(builder, matchName, targetType, pattern, arm);
        }

        builder.Append(UnreachableStatementText());
        statements.Add(ParseStatement("{ " + builder + " }"));
    }

    private void AppendReturnMatchArm(
        StringBuilder builder,
        string matchName,
        JsonElement targetType,
        JsonElement pattern,
        JsonElement arm
    )
    {
        builder
            .Append("if (")
            .Append(PayloadPatternCondition(matchName, targetType, pattern))
            .Append(") { ");
        EmitPatternBindings(builder, matchName, pattern);
        var condition = MatchArmConditionExpression(arm);
        if (condition.Length > 0)
            builder.Append("if (").Append(condition).Append(") { ");
        AppendReturnBody(builder, arm.GetProperty("body"));
        if (condition.Length > 0)
            builder.Append("} ");
        builder.Append("} ");
    }

    private void EmitMatchAsAssignment(
        JsonElement expr,
        string destination,
        List<StatementSyntax> statements
    )
    {
        var target = EmitExpr(expr.GetProperty("target")).NormalizeWhitespace().ToFullString();
        var targetType = expr.GetProperty("target").GetProperty("type");
        var arms = expr.GetProperty("arms").EnumerateArray().ToArray();
        if (CanEmitPayloadEnumTagSwitch(targetType, arms))
        {
            EmitPayloadEnumMatchAsAssignment(target, targetType, arms, destination, statements);
            return;
        }

        var matchName = "__moonbitMatch" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
        var doneLabel =
            "__moonbitMatchDone" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
        statements.Add(ParseStatement($"var {matchName} = {target};"));
        if (!CanEmitSwitchExpression(targetType, arms))
        {
            EmitConditionMatchAsAssignment(
                matchName,
                targetType,
                arms,
                destination,
                doneLabel,
                statements
            );
            return;
        }

        if (CanEmitSingleSwitchStatement(arms))
        {
            EmitSingleSwitchMatchAsAssignment(
                matchName,
                targetType,
                arms,
                destination,
                doneLabel,
                statements
            );
            return;
        }

        for (var i = 0; i < arms.Length; i++)
        {
            var arm = arms[i];
            var pattern = arm.GetProperty("pattern");
            var builder = new StringBuilder();
            builder.Append("switch (").Append(matchName).Append(") { ");
            if (UseDefaultBranchForFinalArm(targetType, arms, i))
                builder.Append("default: { ");
            else
                builder
                    .Append("case ")
                    .Append(MatchStatementCasePatternExpression(targetType, pattern))
                    .Append(": { ");
            EmitPatternBindingsAfterCase(builder, matchName, targetType, arms, i, pattern);
            var condition = MatchArmConditionExpression(arm);
            if (condition.Length > 0)
                builder.Append("if (").Append(condition).Append(") { ");
            AppendAssignmentBody(builder, arm.GetProperty("body"), destination, doneLabel);
            if (condition.Length > 0)
                builder.Append("} ");
            if (condition.Length > 0)
                builder.Append("break; ");
            builder.Append("} }");
            statements.Add(ParseStatement(builder.ToString()));
        }

        statements.Add(ParseStatement(doneLabel + ": ;"));
    }

    private void EmitConditionMatchAsAssignment(
        string matchName,
        JsonElement targetType,
        JsonElement[] arms,
        string destination,
        string doneLabel,
        List<StatementSyntax> statements
    )
    {
        var builder = new StringBuilder();
        foreach (var arm in arms)
        {
            var pattern = arm.GetProperty("pattern");
            if (pattern.GetProperty("kind").GetString() == "Or")
                foreach (var alternative in pattern.GetProperty("alternatives").EnumerateArray())
                    AppendAssignmentMatchArm(
                        builder,
                        matchName,
                        targetType,
                        alternative,
                        arm,
                        destination,
                        doneLabel
                    );
            else
                AppendAssignmentMatchArm(
                    builder,
                    matchName,
                    targetType,
                    pattern,
                    arm,
                    destination,
                    doneLabel
                );
        }

        builder.Append(doneLabel).Append(": ;");
        statements.Add(ParseStatement("{ " + builder + " }"));
    }

    private void AppendAssignmentMatchArm(
        StringBuilder builder,
        string matchName,
        JsonElement targetType,
        JsonElement pattern,
        JsonElement arm,
        string destination,
        string doneLabel
    )
    {
        builder
            .Append("if (")
            .Append(PayloadPatternCondition(matchName, targetType, pattern))
            .Append(") { ");
        EmitPatternBindings(builder, matchName, pattern);
        var condition = MatchArmConditionExpression(arm);
        if (condition.Length > 0)
            builder.Append("if (").Append(condition).Append(") { ");
        AppendAssignmentBody(builder, arm.GetProperty("body"), destination, doneLabel);
        if (condition.Length > 0)
            builder.Append("} ");
        builder.Append("} ");
    }

    private void EmitMatchAsStatement(JsonElement expr, List<StatementSyntax> statements)
    {
        var target = EmitExpr(expr.GetProperty("target")).NormalizeWhitespace().ToFullString();
        var targetType = expr.GetProperty("target").GetProperty("type");
        var arms = expr.GetProperty("arms").EnumerateArray().ToArray();
        if (CanEmitPayloadEnumTagSwitch(targetType, arms))
        {
            EmitPayloadEnumMatchAsStatement(target, targetType, arms, statements);
            return;
        }

        var matchName = "__moonbitMatch" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
        if (CanEmitUnguardedStatementIfChain(arms))
        {
            EmitUnguardedStatementMatchIfChain(matchName, target, targetType, arms, statements);
            return;
        }

        var matchedName =
            "__moonbitMatched" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
        var builder = new StringBuilder();
        builder.Append("var ").Append(matchName).Append(" = ").Append(target).Append("; ");
        builder.Append("var ").Append(matchedName).Append(" = false; ");
        foreach (var arm in arms)
        {
            var pattern = arm.GetProperty("pattern");
            if (pattern.GetProperty("kind").GetString() == "Or")
                foreach (var alternative in pattern.GetProperty("alternatives").EnumerateArray())
                    AppendStatementMatchArm(
                        builder,
                        matchName,
                        matchedName,
                        targetType,
                        alternative,
                        arm
                    );
            else
                AppendStatementMatchArm(builder, matchName, matchedName, targetType, pattern, arm);
        }

        statements.Add(ParseStatement("{ " + builder + " }"));
    }

    private static bool CanEmitUnguardedStatementIfChain(JsonElement[] arms)
    {
        for (var i = 0; i < arms.Length; i++)
        {
            var arm = arms[i];
            var kind = arm.GetProperty("pattern").GetProperty("kind").GetString();
            if (arm.TryGetProperty("condition", out _))
                return false;

            if (kind == "Wildcard" && i != arms.Length - 1)
                return false;
        }

        return true;
    }

    private void EmitUnguardedStatementMatchIfChain(
        string matchName,
        string target,
        JsonElement targetType,
        JsonElement[] arms,
        List<StatementSyntax> statements
    )
    {
        var builder = new StringBuilder();
        builder.Append("var ").Append(matchName).Append(" = ").Append(target).Append("; ");
        for (var i = 0; i < arms.Length; i++)
        {
            var arm = arms[i];
            var pattern = arm.GetProperty("pattern");
            if (i > 0)
                builder.Append("else ");

            if (UseDefaultBranchForFinalArm(targetType, arms, i))
                builder.Append("{ ");
            else
                builder
                    .Append("if (")
                    .Append(PayloadPatternCondition(matchName, targetType, pattern))
                    .Append(") { ");
            EmitPatternBindings(builder, matchName, pattern);
            AppendStatementBody(builder, arm.GetProperty("body"));
            builder.Append("} ");
        }

        statements.Add(ParseStatement("{ " + builder + " }"));
    }

    private void AppendStatementMatchArm(
        StringBuilder builder,
        string matchName,
        string matchedName,
        JsonElement targetType,
        JsonElement pattern,
        JsonElement arm
    )
    {
        builder
            .Append("if (!")
            .Append(matchedName)
            .Append(" && (")
            .Append(PayloadPatternCondition(matchName, targetType, pattern))
            .Append(")) { ");
        EmitPatternBindings(builder, matchName, pattern);
        var condition = MatchArmConditionExpression(arm);
        if (condition.Length > 0)
            builder.Append("if (").Append(condition).Append(") { ");
        builder.Append(matchedName).Append(" = true; ");
        AppendStatementBody(builder, arm.GetProperty("body"));
        if (condition.Length > 0)
            builder.Append("} ");
        builder.Append("} ");
    }

    private static bool CanEmitSingleSwitchStatement(JsonElement[] arms)
    {
        foreach (var arm in arms)
            if (
                arm.TryGetProperty("condition", out _)
                && PatternHasBoundArrayRest(arm.GetProperty("pattern"))
            )
                return false;

        return true;
    }

    private void EmitSingleSwitchMatchAsReturn(
        string matchName,
        JsonElement targetType,
        JsonElement[] arms,
        List<StatementSyntax> statements
    )
    {
        var builder = new StringBuilder();
        builder.Append("switch (").Append(matchName).Append(") { ");
        for (var i = 0; i < arms.Length; i++)
        {
            var arm = arms[i];
            var pattern = arm.GetProperty("pattern");
            AppendSingleSwitchCaseHeader(builder, targetType, arms, i, pattern);
            if (!arm.TryGetProperty("condition", out _))
                EmitPatternBindingsAfterCase(builder, matchName, targetType, arms, i, pattern);
            AppendReturnBody(builder, arm.GetProperty("body"));
            builder.Append("} ");
        }

        builder.Append("}");
        statements.Add(ParseStatement(builder.ToString()));
        if (!UseDefaultBranchForFinalArm(targetType, arms, arms.Length - 1))
            statements.Add(ParseStatement(UnreachableStatementText()));
    }

    private static string UnreachableStatementText()
    {
        return "throw new System.Diagnostics.UnreachableException(); ";
    }

    private void EmitSingleSwitchMatchAsAssignment(
        string matchName,
        JsonElement targetType,
        JsonElement[] arms,
        string destination,
        string doneLabel,
        List<StatementSyntax> statements
    )
    {
        var builder = new StringBuilder();
        builder.Append("switch (").Append(matchName).Append(") { ");
        for (var i = 0; i < arms.Length; i++)
        {
            var arm = arms[i];
            var pattern = arm.GetProperty("pattern");
            AppendSingleSwitchCaseHeader(builder, targetType, arms, i, pattern);
            if (!arm.TryGetProperty("condition", out _))
                EmitPatternBindingsAfterCase(builder, matchName, targetType, arms, i, pattern);
            AppendAssignmentBody(builder, arm.GetProperty("body"), destination, doneLabel);
            builder.Append("} ");
        }

        builder.Append("}");
        statements.Add(ParseStatement(builder.ToString()));
        statements.Add(ParseStatement(doneLabel + ": ;"));
    }

    private void AppendSingleSwitchCaseHeader(
        StringBuilder builder,
        JsonElement targetType,
        JsonElement[] arms,
        int armIndex,
        JsonElement pattern
    )
    {
        var arm = arms[armIndex];
        if (arm.TryGetProperty("condition", out var condition))
        {
            builder.Append("case ");
            var patternText =
                pattern.GetProperty("kind").GetString() == "Wildcard"
                    ? "var _"
                    : MatchPatternExpression(targetType, pattern);
            builder
                .Append(patternText)
                .Append(" when ")
                .Append(EmitExpr(condition).NormalizeWhitespace().ToFullString());
        }
        else if (UseDefaultBranchForFinalArm(targetType, arms, armIndex))
        {
            builder.Append("default");
        }
        else
        {
            builder.Append("case ");
            builder.Append(MatchStatementCasePatternExpression(targetType, pattern));
        }

        builder.Append(": { ");
    }

    private void EmitPatternBindingsAfterCase(
        StringBuilder builder,
        string value,
        JsonElement targetType,
        JsonElement[] arms,
        int armIndex,
        JsonElement pattern
    )
    {
        if (UseDefaultBranchForFinalArm(targetType, arms, armIndex))
        {
            EmitPatternBindings(builder, value, pattern);
            return;
        }

        if (pattern.GetProperty("kind").GetString() is "Wildcard" or "Binding")
        {
            EmitPatternBindings(builder, value, pattern);
            return;
        }

        EmitArrayRestPatternBindings(builder, value, pattern);
    }
}
