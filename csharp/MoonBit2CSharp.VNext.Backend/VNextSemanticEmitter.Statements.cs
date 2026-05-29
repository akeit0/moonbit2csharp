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
    private BlockSyntax EmitFunctionBody(JsonElement body)
    {
        tempNameIndex = 0;
        var statements = new List<StatementSyntax>();
        EmitExprAsReturn(body, statements);
        return Block(statements);
    }

    private void EmitExprAsReturn(JsonElement expr, List<StatementSyntax> statements)
    {
        var kind = expr.GetProperty("kind").GetString();
        switch (kind)
        {
            case "LocalLet":
            {
                var local = expr.GetProperty("local");
                EmitLocalDeclaration(local, statements);
                EmitExprAsReturn(expr.GetProperty("body"), statements);
                break;
            }
            case "LocalFunction":
                EmitLocalFunctionDeclaration(expr.GetProperty("function"), statements);
                EmitExprAsReturn(expr.GetProperty("body"), statements);
                break;

            case "Sequence":
                EmitExprAsStatement(expr.GetProperty("first"), statements);
                EmitExprAsReturn(expr.GetProperty("body"), statements);
                break;
            case "ForRange":
                statements.Add(EmitForRange(expr));
                statements.Add(ReturnStatement(ParseExpression("MoonBitUnit.Value")));
                break;
            case "While":
                statements.Add(EmitWhile(expr));
                statements.Add(ReturnStatement(ParseExpression("MoonBitUnit.Value")));
                break;
            case "Guard":
                EmitGuardAsStatement(expr, statements);
                statements.Add(ReturnStatement(ParseExpression("MoonBitUnit.Value")));
                break;
            case "IndexAssign":
                statements.Add(ExpressionStatement(EmitExpr(expr)));
                statements.Add(ReturnStatement(ParseExpression("MoonBitUnit.Value")));
                break;
            case "Assign":
            case "FieldAssign":
                statements.Add(ExpressionStatement(EmitExpr(expr)));
                statements.Add(ReturnStatement(ParseExpression("MoonBitUnit.Value")));
                break;
            case "Return":
                statements.Add(ReturnStatement(ReturnValueOrUnit(expr)));
                break;
            case "Panic":
                statements.Add(ThrowStatement(NewMoonBitPanicExpression()));
                break;
            case "Raise":
                statements.Add(ReturnStatement(EmitRaise(expr)));
                break;
            case "TryCatch":
                EmitTryCatchAsReturn(expr, statements);
                break;
            case "ForLoop":
            {
                if (IsUnitType(expr.GetProperty("type")))
                {
                    statements.Add(EmitForLoop(expr));
                    statements.Add(ReturnStatement(ParseExpression("MoonBitUnit.Value")));
                }
                else
                {
                    var resultName =
                        "__mbt_loop_result"
                        + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
                    statements.Add(
                        LocalDeclarationStatement(
                            VariableDeclaration(EmitType(expr.GetProperty("type")))
                                .WithVariables(
                                    SingletonSeparatedList(
                                        VariableDeclarator(resultName)
                                            .WithInitializer(EqualsValueClause(DefaultLiteral()))
                                    )
                                )
                        )
                    );
                    statements.Add(EmitForLoop(expr, resultName));
                    statements.Add(ReturnStatement(IdentifierName(resultName)));
                }

                break;
            }

            case "ForIn":
            {
                if (IsUnitType(expr.GetProperty("type")))
                {
                    statements.Add(EmitForIn(expr));
                    statements.Add(ReturnStatement(ParseExpression("MoonBitUnit.Value")));
                }
                else
                {
                    var resultName =
                        "__mbt_loop_result"
                        + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
                    statements.Add(
                        LocalDeclarationStatement(
                            VariableDeclaration(EmitType(expr.GetProperty("type")))
                                .WithVariables(
                                    SingletonSeparatedList(
                                        VariableDeclarator(resultName)
                                            .WithInitializer(EqualsValueClause(DefaultLiteral()))
                                    )
                                )
                        )
                    );
                    statements.Add(EmitForIn(expr, resultName));
                    statements.Add(ReturnStatement(IdentifierName(resultName)));
                }

                break;
            }
            case "Match" when MatchNeedsStatementLowering(expr):
                EmitMatchAsReturn(expr, statements);
                break;
            case "If" when IfNeedsReturnStatementLowering(expr):
                EmitIfAsReturn(expr, statements);
                break;
            case "Binary" when BinaryNeedsAssignmentStatementLowering(expr):
            {
                var resultName =
                    "__mbt_expr" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
                statements.Add(
                    LocalDeclarationStatement(
                        VariableDeclaration(EmitType(expr.GetProperty("type")))
                            .WithVariables(SingletonSeparatedList(VariableDeclarator(resultName)))
                    )
                );
                EmitBinaryAsAssignment(expr, resultName, statements);
                statements.Add(ReturnStatement(IdentifierName(resultName)));
                break;
            }
            default:
                if (EmitRaisingExprAsReturn(expr, statements))
                    break;
                statements.Add(
                    ReturnStatement(ReturnExpression(EmitExpr(expr), expr.GetProperty("type")))
                );
                break;
        }
    }

    private void EmitExprAsStatement(JsonElement expr, List<StatementSyntax> statements)
    {
        var kind = expr.GetProperty("kind").GetString();
        switch (kind)
        {
            case "Sequence":
                EmitExprAsStatement(expr.GetProperty("first"), statements);
                if (!StatementListTerminates(statements))
                    EmitExprAsStatement(expr.GetProperty("body"), statements);
                break;
            case "LocalLet":
            {
                var local = expr.GetProperty("local");
                EmitLocalDeclaration(local, statements);
                EmitExprAsStatement(expr.GetProperty("body"), statements);
                break;
            }
            case "LocalFunction":
                EmitLocalFunctionDeclaration(expr.GetProperty("function"), statements);
                EmitExprAsStatement(expr.GetProperty("body"), statements);
                break;

            case "ForRange":
                statements.Add(EmitForRange(expr));
                break;
            case "While":
                statements.Add(EmitWhile(expr));
                break;
            case "ForLoop":
                statements.Add(EmitForLoop(expr));
                break;
            case "ForIn":
                statements.Add(EmitForIn(expr));
                break;
            case "Guard":
                EmitGuardAsStatement(expr, statements);
                break;
            case "Match":
                EmitMatchAsStatement(expr, statements);
                break;
            case "If":
                EmitIfAsStatement(expr, statements);
                break;
            case "IndexAssign":
                statements.Add(ExpressionStatement(EmitExpr(expr)));
                break;
            case "Assign":
            case "FieldAssign":
                statements.Add(ExpressionStatement(EmitExpr(expr)));
                break;
            case "Break":
                EmitBreakStatement(expr, statements);
                break;
            case "Continue":
                EmitContinueStatement(expr, statements);
                break;
            case "Return":
                statements.Add(ReturnStatement(ReturnValueOrUnit(expr)));
                break;
            case "Panic":
                statements.Add(ThrowStatement(NewMoonBitPanicExpression()));
                break;
            case "TryCatch":
                EmitTryCatchAsStatement(expr, statements);
                break;
            case "UnitLiteral":
                return;
            default:
                if (EmitRaisingExprAsStatement(expr, statements))
                    break;
                statements.Add(ExpressionStatement(EmitExpr(expr)));
                break;
        }
    }

    private static ObjectCreationExpressionSyntax NewMoonBitPanicExpression()
    {
        return ObjectCreationExpression(IdentifierName("MoonBitPanic"))
            .WithArgumentList(ArgumentList());
    }

    private void EmitLocalDeclaration(JsonElement local, List<StatementSyntax> statements)
    {
        var value = local.GetProperty("value");
        var name = LocalIdentifier(local);
        if (ExprNeedsAssignmentStatementLowering(value))
        {
            statements.Add(
                LocalDeclarationStatement(
                    VariableDeclaration(EmitType(local.GetProperty("type")))
                        .WithVariables(
                            SingletonSeparatedList(
                                VariableDeclarator(Identifier(name))
                                    .WithInitializer(EqualsValueClause(DefaultLiteral()))
                            )
                        )
                )
            );
            EmitExprAsAssignment(value, name, statements);
            return;
        }

        if (ExprMayRaise(value))
        {
            statements.Add(
                LocalDeclarationStatement(
                    VariableDeclaration(EmitType(local.GetProperty("type")))
                        .WithVariables(
                            SingletonSeparatedList(
                                VariableDeclarator(Identifier(name))
                                    .WithInitializer(EqualsValueClause(DefaultLiteral()))
                            )
                        )
                )
            );
            EmitExprAsAssignment(value, name, statements);
            return;
        }

        statements.Add(
            LocalDeclarationStatement(
                VariableDeclaration(EmitType(local.GetProperty("type")))
                    .WithVariables(
                        SingletonSeparatedList(
                            VariableDeclarator(Identifier(name))
                                .WithInitializer(EqualsValueClause(EmitExpr(value)))
                        )
                    )
            )
        );
    }

    private static ExpressionSyntax DefaultLiteral()
    {
        return ParseExpression("default!");
    }

    private static bool StatementListTerminates(IReadOnlyList<StatementSyntax> statements)
    {
        return statements.Count > 0 && StatementTerminates(statements[^1]);
    }

    private static bool StatementTerminates(StatementSyntax statement)
    {
        return statement
            is ReturnStatementSyntax
                or BreakStatementSyntax
                or ContinueStatementSyntax
                or ThrowStatementSyntax
                or GotoStatementSyntax;
    }

    private void EmitLocalFunctionDeclaration(
        JsonElement function,
        List<StatementSyntax> statements
    )
    {
        var bodyStatements = new List<StatementSyntax>();
        EmitExprAsReturn(function.GetProperty("body"), bodyStatements);
        var declaration = LocalFunctionStatement(
                EmitType(function.GetProperty("returnType")),
                LocalIdentifier(
                    function.GetProperty("name").GetString() ?? "",
                    function.GetProperty("symbolId").GetString() ?? ""
                )
            )
            .WithParameterList(
                ParameterList(
                    SeparatedList(
                        function
                            .GetProperty("params")
                            .EnumerateArray()
                            .Select(param =>
                                Parameter(Identifier(LocalIdentifier(param)))
                                    .WithType(EmitType(param.GetProperty("type")))
                            )
                    )
                )
            )
            .WithBody(Block(bodyStatements));
        statements.Add(declaration);
    }

    private bool ExprNeedsReturnStatementLowering(JsonElement expr)
    {
        return expr.GetProperty("kind").GetString() switch
        {
            "LocalLet"
            or "LocalFunction"
            or "Sequence"
            or "While"
            or "ForRange"
            or "ForLoop"
            or "ForIn" => true,
            "Return" or "Break" or "Continue" => true,
            "Guard" => true,
            "Assign" or "FieldAssign" or "IndexAssign" => true,
            "TryCatch" => true,
            "Match" => MatchNeedsStatementLowering(expr),
            "If" => IfNeedsReturnStatementLowering(expr),
            _ => false,
        };
    }

    private bool ExprNeedsAssignmentStatementLowering(JsonElement expr)
    {
        return expr.GetProperty("kind").GetString() switch
        {
            "LocalLet"
            or "LocalFunction"
            or "Sequence"
            or "While"
            or "ForRange"
            or "ForLoop"
            or "ForIn" => true,
            "Return" or "Break" or "Continue" => true,
            "Guard" => true,
            "Assign" or "FieldAssign" or "IndexAssign" => true,
            "TryCatch" => true,
            "Match" => MatchNeedsStatementLowering(expr),
            "If" => IfNeedsAssignmentStatementLowering(expr),
            "Binary" => BinaryNeedsAssignmentStatementLowering(expr),
            _ => false,
        };
    }

    private bool IfNeedsReturnStatementLowering(JsonElement expr)
    {
        return ExprNeedsReturnStatementLowering(expr.GetProperty("then"))
            || ExprNeedsReturnStatementLowering(expr.GetProperty("else"));
    }

    private bool IfNeedsAssignmentStatementLowering(JsonElement expr)
    {
        return ExprNeedsAssignmentStatementLowering(expr.GetProperty("then"))
            || ExprNeedsAssignmentStatementLowering(expr.GetProperty("else"));
    }

    private bool BinaryNeedsAssignmentStatementLowering(JsonElement expr)
    {
        return ExprNeedsAssignmentStatementLowering(expr.GetProperty("left"))
            || ExprNeedsAssignmentStatementLowering(expr.GetProperty("right"));
    }

    private void EmitIfAsReturn(JsonElement expr, List<StatementSyntax> statements)
    {
        var thenStatements = new List<StatementSyntax>();
        EmitExprAsReturn(expr.GetProperty("then"), thenStatements);
        var elseStatements = new List<StatementSyntax>();
        EmitExprAsReturn(expr.GetProperty("else"), elseStatements);
        statements.Add(
            IfStatement(
                EmitExpr(expr.GetProperty("condition")),
                Block(thenStatements),
                ElseClauseIfNotEmpty(elseStatements)
            )
        );
    }

    private void EmitIfAsStatement(JsonElement expr, List<StatementSyntax> statements)
    {
        var thenStatements = new List<StatementSyntax>();
        EmitExprAsStatement(expr.GetProperty("then"), thenStatements);
        var elseStatements = new List<StatementSyntax>();
        EmitExprAsStatement(expr.GetProperty("else"), elseStatements);
        statements.Add(
            IfStatement(
                EmitExpr(expr.GetProperty("condition")),
                Block(thenStatements),
                ElseClauseIfNotEmpty(elseStatements)
            )
        );
    }

    private void EmitExprAsAssignment(
        JsonElement expr,
        string destination,
        List<StatementSyntax> statements
    )
    {
        var kind = expr.GetProperty("kind").GetString();
        switch (kind)
        {
            case "LocalLet":
            {
                var local = expr.GetProperty("local");
                EmitLocalDeclaration(local, statements);
                EmitExprAsAssignment(expr.GetProperty("body"), destination, statements);
                return;
            }
            case "LocalFunction":
                EmitLocalFunctionDeclaration(expr.GetProperty("function"), statements);
                EmitExprAsAssignment(expr.GetProperty("body"), destination, statements);
                return;

            case "Sequence":
                EmitExprAsStatement(expr.GetProperty("first"), statements);
                if (!StatementListTerminates(statements))
                    EmitExprAsAssignment(expr.GetProperty("body"), destination, statements);
                return;
            case "ForRange":
                statements.Add(EmitForRange(expr));
                statements.Add(
                    ExpressionStatement(
                        AssignmentExpression(
                            SyntaxKind.SimpleAssignmentExpression,
                            IdentifierName(destination),
                            ParseExpression("MoonBitUnit.Value")
                        )
                    )
                );
                return;
            case "While":
                statements.Add(EmitWhile(expr));
                statements.Add(
                    ExpressionStatement(
                        AssignmentExpression(
                            SyntaxKind.SimpleAssignmentExpression,
                            IdentifierName(destination),
                            ParseExpression("MoonBitUnit.Value")
                        )
                    )
                );
                return;
            case "ForLoop":
                statements.Add(EmitForLoop(expr, destination));
                return;
            case "ForIn":
                statements.Add(EmitForIn(expr, destination));
                return;
            case "Guard":
                EmitGuardAsStatement(expr, statements);
                return;
            case "Return":
                statements.Add(ReturnStatement(ReturnValueOrUnit(expr)));
                return;
            case "Panic":
                statements.Add(ThrowStatement(NewMoonBitPanicExpression()));
                return;
            case "TryCatch":
                EmitTryCatchAsAssignment(expr, destination, statements);
                return;
            case "Match" when MatchNeedsStatementLowering(expr):
                EmitMatchAsAssignment(expr, destination, statements);
                return;
            case "If" when IfNeedsAssignmentStatementLowering(expr):
                EmitIfAsAssignment(expr, destination, statements);
                return;
            case "Binary" when BinaryNeedsAssignmentStatementLowering(expr):
                EmitBinaryAsAssignment(expr, destination, statements);
                return;
        }

        if (EmitRaisingExprAsAssignment(expr, destination, statements))
            return;

        statements.Add(
            ExpressionStatement(
                AssignmentExpression(
                    SyntaxKind.SimpleAssignmentExpression,
                    IdentifierName(destination),
                    EmitExpr(expr)
                )
            )
        );
    }

    private bool EmitRaisingExprAsStatement(JsonElement expr, List<StatementSyntax> statements)
    {
        if (!ExprMayRaise(expr))
            return false;

        if (TryGetRaisingCall(expr, out var errorType, out var errorTypeNode))
        {
            var callResult = EmitRaisingCallResult(expr, errorType, statements);
            statements.Add(
                IfStatement(
                    PrefixUnaryExpression(
                        SyntaxKind.LogicalNotExpression,
                        MemberAccessExpression(
                            SyntaxKind.SimpleMemberAccessExpression,
                            IdentifierName(callResult),
                            IdentifierName("IsOk")
                        )
                    ),
                    Block(ReturnPropagatedErrorStatement(callResult, errorType, errorTypeNode))
                )
            );
            return true;
        }

        var lowered = EmitExprWithRaisingArguments(expr, statements);
        if (!IsUnitValueExpression(lowered))
            statements.Add(ExpressionStatement(lowered));
        return true;
    }

    private bool EmitRaisingExprAsReturn(JsonElement expr, List<StatementSyntax> statements)
    {
        if (!ExprMayRaise(expr))
            return false;

        if (TryGetRaisingCall(expr, out var errorType, out var errorTypeNode))
        {
            var callResult = EmitRaisingCallResult(expr, errorType, statements);
            statements.Add(
                IfStatement(
                    MemberAccessExpression(
                        SyntaxKind.SimpleMemberAccessExpression,
                        IdentifierName(callResult),
                        IdentifierName("IsOk")
                    ),
                    Block(
                        ReturnStatement(
                            ReturnExpression(
                                ParseExpression($"{callResult}.Value!"),
                                expr.GetProperty("type")
                            )
                        )
                    ),
                    ElseClause(
                        Block(ReturnPropagatedErrorStatement(callResult, errorType, errorTypeNode))
                    )
                )
            );
            return true;
        }

        statements.Add(
            ReturnStatement(
                ReturnExpression(
                    EmitExprWithRaisingArguments(expr, statements),
                    expr.GetProperty("type")
                )
            )
        );
        return true;
    }

    private bool EmitRaisingExprAsAssignment(
        JsonElement expr,
        string destination,
        List<StatementSyntax> statements
    )
    {
        if (!ExprMayRaise(expr))
            return false;

        if (TryGetRaisingCall(expr, out var errorType, out var errorTypeNode))
        {
            var callResult = EmitRaisingCallResult(expr, errorType, statements);
            statements.Add(
                IfStatement(
                    MemberAccessExpression(
                        SyntaxKind.SimpleMemberAccessExpression,
                        IdentifierName(callResult),
                        IdentifierName("IsOk")
                    ),
                    Block(
                        ExpressionStatement(
                            AssignmentExpression(
                                SyntaxKind.SimpleAssignmentExpression,
                                IdentifierName(destination),
                                ParseExpression($"{callResult}.Value!")
                            )
                        )
                    ),
                    ElseClause(
                        Block(ReturnPropagatedErrorStatement(callResult, errorType, errorTypeNode))
                    )
                )
            );
            return true;
        }

        statements.Add(
            ExpressionStatement(
                AssignmentExpression(
                    SyntaxKind.SimpleAssignmentExpression,
                    IdentifierName(destination),
                    EmitExprWithRaisingArguments(expr, statements)
                )
            )
        );
        return true;
    }

    private void EmitBinaryAsAssignment(
        JsonElement expr,
        string destination,
        List<StatementSyntax> statements
    )
    {
        if (
            (expr.GetProperty("op").GetString() ?? "") == "&&"
            && expr.GetProperty("left").GetProperty("kind").GetString() == "IsPattern"
        )
        {
            EmitPatternAndAsAssignment(
                expr.GetProperty("left"),
                expr.GetProperty("right"),
                destination,
                statements
            );
            return;
        }

        var left = EmitExprAsStatementValue(expr.GetProperty("left"), statements);
        var right = EmitExprAsStatementValue(expr.GetProperty("right"), statements);
        statements.Add(
            ExpressionStatement(
                AssignmentExpression(
                    SyntaxKind.SimpleAssignmentExpression,
                    IdentifierName(destination),
                    EmitBinary(expr, left, right)
                )
            )
        );
    }

    private void EmitPatternAndAsAssignment(
        JsonElement isPattern,
        JsonElement right,
        string destination,
        List<StatementSyntax> statements
    )
    {
        var target = isPattern.GetProperty("target");
        var targetType = target.GetProperty("type");
        var pattern = isPattern.GetProperty("pattern");
        var targetName = "__moonbitIs" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
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

        var trueStatements = new List<StatementSyntax>();
        var bindingBuilder = new StringBuilder();
        EmitPatternBindings(bindingBuilder, targetName, pattern);
        var bindingText = bindingBuilder.ToString();
        if (bindingText.Length > 0)
            trueStatements.AddRange(
                ((BlockSyntax)ParseStatement("{ " + bindingText + " }")).Statements
            );
        EmitExprAsAssignment(right, destination, trueStatements);

        statements.Add(
            IfStatement(
                ParseExpression(IsPatternCondition(targetName, targetType, pattern)),
                Block(trueStatements),
                ElseClause(
                    Block(
                        ExpressionStatement(
                            AssignmentExpression(
                                SyntaxKind.SimpleAssignmentExpression,
                                IdentifierName(destination),
                                LiteralExpression(SyntaxKind.FalseLiteralExpression)
                            )
                        )
                    )
                )
            )
        );
    }

    private ExpressionSyntax EmitExprAsStatementValue(
        JsonElement expr,
        List<StatementSyntax> statements
    )
    {
        if (!ExprNeedsAssignmentStatementLowering(expr) && !ExprMayRaise(expr))
            return EmitExpr(expr);

        var tempName = "__mbt_expr" + tempNameIndex++.ToString(CultureInfo.InvariantCulture);
        statements.Add(
            LocalDeclarationStatement(
                VariableDeclaration(EmitType(expr.GetProperty("type")))
                    .WithVariables(SingletonSeparatedList(VariableDeclarator(tempName)))
            )
        );
        EmitExprAsAssignment(expr, tempName, statements);
        return IdentifierName(tempName);
    }

    private void EmitIfAsAssignment(
        JsonElement expr,
        string destination,
        List<StatementSyntax> statements
    )
    {
        var thenStatements = new List<StatementSyntax>();
        EmitExprAsAssignment(expr.GetProperty("then"), destination, thenStatements);
        var elseStatements = new List<StatementSyntax>();
        EmitExprAsAssignment(expr.GetProperty("else"), destination, elseStatements);
        statements.Add(
            IfStatement(
                EmitExpr(expr.GetProperty("condition")),
                Block(thenStatements),
                ElseClauseIfNotEmpty(elseStatements)
            )
        );
    }

    private static ElseClauseSyntax? ElseClauseIfNotEmpty(
        IReadOnlyCollection<StatementSyntax> statements
    )
    {
        return statements.Count == 0 ? null : ElseClause(Block(statements));
    }

    private void EmitGuardAsStatement(JsonElement expr, List<StatementSyntax> statements)
    {
        var elseStatements = new List<StatementSyntax>();
        EmitGuardElseAsStatement(expr.GetProperty("else"), elseStatements);
        var condition = expr.GetProperty("condition");
        if (condition.GetProperty("kind").GetString() == "IsPattern")
        {
            EmitPatternGuard(condition, elseStatements, statements);
            return;
        }

        statements.Add(
            IfStatement(
                PrefixUnaryExpression(
                    SyntaxKind.LogicalNotExpression,
                    ParenthesizedExpression(EmitExpr(condition))
                ),
                Block(elseStatements)
            )
        );
    }

    private void EmitGuardElseAsStatement(JsonElement expr, List<StatementSyntax> statements)
    {
        switch (expr.GetProperty("kind").GetString())
        {
            case "Return":
                statements.Add(ReturnStatement(ReturnValueOrUnit(expr)));
                break;
            case "Break":
                EmitBreakStatement(expr, statements);
                break;
            case "Continue":
                EmitContinueStatement(expr, statements);
                break;
            case "Panic":
                statements.Add(ThrowStatement(NewMoonBitPanicExpression()));
                break;
            default:
                if (ExprNeedsReturnStatementLowering(expr))
                    EmitExprAsReturn(expr, statements);
                else
                    statements.Add(ReturnStatement(EmitExpr(expr)));
                break;
        }
    }

    private StatementSyntax EmitWhile(JsonElement expr)
    {
        var bodyStatements = new List<StatementSyntax>();
        EmitExprAsStatement(expr.GetProperty("body"), bodyStatements);
        return WhileStatement(EmitExpr(expr.GetProperty("condition")), Block(bodyStatements));
    }

    private void EmitContinueStatement(JsonElement expr, List<StatementSyntax> statements)
    {
        if (currentForLoops.Count > 0)
            EmitForLoopContinueAssignments(expr, currentForLoops.Peek().Loop, statements);
        statements.Add(ContinueStatement());
    }

    private void EmitBreakStatement(JsonElement expr, List<StatementSyntax> statements)
    {
        if (currentForLoops.Count > 0 && currentForLoops.Peek().BreakFlagName is { } breakFlag)
            statements.Add(
                ExpressionStatement(
                    AssignmentExpression(
                        SyntaxKind.SimpleAssignmentExpression,
                        IdentifierName(breakFlag),
                        LiteralExpression(SyntaxKind.TrueLiteralExpression)
                    )
                )
            );

        if (
            currentForLoops.Count > 0
            && currentForLoops.Peek().ResultDestination is { } destination
            && expr.TryGetProperty("value", out var value)
            && value.ValueKind != JsonValueKind.Null
        )
            statements.Add(
                ExpressionStatement(
                    AssignmentExpression(
                        SyntaxKind.SimpleAssignmentExpression,
                        IdentifierName(destination),
                        EmitExpr(value)
                    )
                )
            );

        statements.Add(BreakStatement());
    }

    private ExpressionSyntax ReturnValueOrUnit(JsonElement expr)
    {
        var value = expr.GetProperty("value");
        var result =
            value.ValueKind == JsonValueKind.Null
                ? ParseExpression("MoonBitUnit.Value")
                : EmitExpr(value);
        var type =
            value.ValueKind == JsonValueKind.Null
                ? expr.GetProperty("type")
                : value.GetProperty("type");
        return ReturnExpression(result, type);
    }

    private ExpressionSyntax ReturnExpression(ExpressionSyntax value, JsonElement okType)
    {
        if (!currentFunctionRaises)
            return value;

        var okTypeName = EmitType(okType).NormalizeWhitespace().ToFullString();
        return ParseExpression(
            $"MoonBitResult<{okTypeName}, {currentFunctionErrorType}>.Ok({value.NormalizeWhitespace()})"
        );
    }

    private void EmitTryCatchAsReturn(JsonElement expr, List<StatementSyntax> statements)
    {
        var resultName = FreshEmitterTempName("__mbt_try_value");
        statements.Add(
            LocalDeclarationStatement(
                VariableDeclaration(EmitType(expr.GetProperty("type")))
                    .WithVariables(SingletonSeparatedList(VariableDeclarator(resultName)))
            )
        );
        EmitTryCatchAsAssignment(expr, resultName, statements);
        statements.Add(
            ReturnStatement(ReturnExpression(IdentifierName(resultName), expr.GetProperty("type")))
        );
    }

    private void EmitTryCatchAsAssignment(
        JsonElement expr,
        string destination,
        List<StatementSyntax> statements
    )
    {
        if (TryGetRaisingCall(expr.GetProperty("body"), out var directErrorType))
        {
            EmitDirectTryCatchAsAssignment(expr, destination, directErrorType, statements);
            return;
        }

        var errorType = TryGetTryBodyErrorType(expr.GetProperty("body"), out var inferredErrorType)
            ? inferredErrorType
            : "object";
        var errorName = FreshEmitterTempName("__mbt_try_error");
        var catchLabel = FreshEmitterTempName("__mbt_try_catch");
        var afterLabel = FreshEmitterTempName("__mbt_try_after");
        statements.Add(
            LocalDeclarationStatement(
                VariableDeclaration(ParseTypeName(errorType))
                    .WithVariables(
                        SingletonSeparatedList(
                            VariableDeclarator(errorName)
                                .WithInitializer(EqualsValueClause(DefaultLiteral()))
                        )
                    )
            )
        );
        EmitTryBody(
            expr.GetProperty("body"),
            destination,
            errorName,
            errorType,
            catchLabel,
            statements
        );
        statements.Add(GotoStatement(SyntaxKind.GotoStatement, IdentifierName(afterLabel)));
        statements.Add(
            LabeledStatement(
                catchLabel,
                Block(EmitCatchArmStatements(expr, destination, errorName, errorType, false))
            )
        );
        statements.Add(LabeledStatement(afterLabel, EmptyStatement()));
    }

    private void EmitDirectTryCatchAsAssignment(
        JsonElement expr,
        string destination,
        string errorType,
        List<StatementSyntax> statements
    )
    {
        var body = expr.GetProperty("body");
        var callResult = FreshEmitterTempName("__mbt_try_result");
        var okType = EmitType(body.GetProperty("type")).NormalizeWhitespace().ToFullString();
        statements.Add(
            LocalDeclarationStatement(
                VariableDeclaration(ParseTypeName($"MoonBitResult<{okType}, {errorType}>"))
                    .WithVariables(
                        SingletonSeparatedList(
                            VariableDeclarator(callResult)
                                .WithInitializer(EqualsValueClause(EmitExpr(body)))
                        )
                    )
            )
        );

        var okStatements = new List<StatementSyntax>
        {
            ExpressionStatement(
                AssignmentExpression(
                    SyntaxKind.SimpleAssignmentExpression,
                    IdentifierName(destination),
                    ParseExpression($"{callResult}.Value!")
                )
            ),
        };
        var catchStatements = EmitCatchArmStatements(
            expr,
            destination,
            $"{callResult}.Error!",
            errorType,
            false
        );

        statements.Add(
            IfStatement(
                MemberAccessExpression(
                    SyntaxKind.SimpleMemberAccessExpression,
                    IdentifierName(callResult),
                    IdentifierName("IsOk")
                ),
                Block(okStatements),
                ElseClause(Block(catchStatements))
            )
        );
    }

    private void EmitTryCatchAsStatement(JsonElement expr, List<StatementSyntax> statements)
    {
        var errorType = TryGetTryBodyErrorType(expr.GetProperty("body"), out var inferredErrorType)
            ? inferredErrorType
            : "object";
        var errorName = FreshEmitterTempName("__mbt_try_error");
        var catchLabel = FreshEmitterTempName("__mbt_try_catch");
        var afterLabel = FreshEmitterTempName("__mbt_try_after");
        statements.Add(
            LocalDeclarationStatement(
                VariableDeclaration(ParseTypeName(errorType))
                    .WithVariables(
                        SingletonSeparatedList(
                            VariableDeclarator(errorName)
                                .WithInitializer(EqualsValueClause(DefaultLiteral()))
                        )
                    )
            )
        );
        EmitTryBody(expr.GetProperty("body"), null, errorName, errorType, catchLabel, statements);
        statements.Add(GotoStatement(SyntaxKind.GotoStatement, IdentifierName(afterLabel)));
        statements.Add(
            LabeledStatement(
                catchLabel,
                Block(EmitCatchArmStatements(expr, "", errorName, errorType, true))
            )
        );
        statements.Add(LabeledStatement(afterLabel, EmptyStatement()));
    }

    private void EmitTryBody(
        JsonElement expr,
        string? destination,
        string errorName,
        string tryErrorType,
        string catchLabel,
        List<StatementSyntax> statements
    )
    {
        if (expr.GetProperty("kind").GetString() == "Sequence")
        {
            EmitTryBody(
                expr.GetProperty("first"),
                destination,
                errorName,
                tryErrorType,
                catchLabel,
                statements
            );
            EmitTryBody(
                expr.GetProperty("body"),
                destination,
                errorName,
                tryErrorType,
                catchLabel,
                statements
            );
            return;
        }

        if (TryGetRaisingCall(expr, out var errorType, out var errorTypeNode))
        {
            var callResult = FreshEmitterTempName("__mbt_try_result");
            var okType = EmitType(expr.GetProperty("type")).NormalizeWhitespace().ToFullString();
            statements.Add(
                LocalDeclarationStatement(
                    VariableDeclaration(ParseTypeName($"MoonBitResult<{okType}, {errorType}>"))
                        .WithVariables(
                            SingletonSeparatedList(
                                VariableDeclarator(callResult)
                                    .WithInitializer(EqualsValueClause(EmitExpr(expr)))
                            )
                        )
                )
            );
            statements.Add(
                destination is null
                    ? IfStatement(
                        PrefixUnaryExpression(
                            SyntaxKind.LogicalNotExpression,
                            MemberAccessExpression(
                                SyntaxKind.SimpleMemberAccessExpression,
                                IdentifierName(callResult),
                                IdentifierName("IsOk")
                            )
                        ),
                        Block(
                            ExpressionStatement(
                                AssignmentExpression(
                                    SyntaxKind.SimpleAssignmentExpression,
                                    IdentifierName(errorName),
                                    TryErrorExpression(
                                        $"{callResult}.Error!",
                                        errorType,
                                        errorTypeNode,
                                        tryErrorType
                                    )
                                )
                            ),
                            GotoStatement(SyntaxKind.GotoStatement, IdentifierName(catchLabel))
                        )
                    )
                    : IfStatement(
                        MemberAccessExpression(
                            SyntaxKind.SimpleMemberAccessExpression,
                            IdentifierName(callResult),
                            IdentifierName("IsOk")
                        ),
                        Block(
                            ExpressionStatement(
                                AssignmentExpression(
                                    SyntaxKind.SimpleAssignmentExpression,
                                    IdentifierName(destination),
                                    ParseExpression($"{callResult}.Value!")
                                )
                            )
                        ),
                        ElseClause(
                            Block(
                                ExpressionStatement(
                                    AssignmentExpression(
                                        SyntaxKind.SimpleAssignmentExpression,
                                        IdentifierName(errorName),
                                        TryErrorExpression(
                                            $"{callResult}.Error!",
                                            errorType,
                                            errorTypeNode,
                                            tryErrorType
                                        )
                                    )
                                ),
                                GotoStatement(SyntaxKind.GotoStatement, IdentifierName(catchLabel))
                            )
                        )
                    )
            );
            return;
        }

        if (ExprMayRaise(expr))
        {
            var lowered = EmitExprWithTryRaisingArguments(
                expr,
                errorName,
                tryErrorType,
                catchLabel,
                statements
            );
            if (destination is null)
            {
                if (!IsUnitValueExpression(lowered))
                    statements.Add(ExpressionStatement(lowered));
            }
            else
            {
                statements.Add(
                    ExpressionStatement(
                        AssignmentExpression(
                            SyntaxKind.SimpleAssignmentExpression,
                            IdentifierName(destination),
                            lowered
                        )
                    )
                );
            }

            return;
        }

        if (destination is null)
            EmitExprAsStatement(expr, statements);
        else
            EmitExprAsAssignment(expr, destination, statements);
    }

    private List<StatementSyntax> EmitCatchArmStatements(
        JsonElement expr,
        string destination,
        string errorName,
        string errorType,
        bool asStatement
    )
    {
        var statements = new List<StatementSyntax>();
        var arms = expr.GetProperty("arms").EnumerateArray().ToArray();
        if (arms.Length == 0)
            return statements;

        EmitCatchPatternBinding(arms[0].GetProperty("pattern"), errorName, errorType, statements);
        if (asStatement)
            EmitExprAsStatement(arms[0].GetProperty("body"), statements);
        else
            EmitExprAsAssignment(arms[0].GetProperty("body"), destination, statements);

        return statements;
    }

    private void EmitCatchPatternBinding(
        JsonElement pattern,
        string errorName,
        string errorType,
        List<StatementSyntax> statements
    )
    {
        if (
            pattern.TryGetProperty("kind", out var kind)
            && kind.GetString() == "Binding"
            && pattern.TryGetProperty("symbol", out var symbol)
        )
        {
            var declaredSymbolType = EmitType(symbol.GetProperty("type"));
            var declaredSymbolTypeText = declaredSymbolType.NormalizeWhitespace().ToFullString();
            var symbolType =
                string.Equals(
                    declaredSymbolTypeText,
                    CoreBuiltinTypeName("Error"),
                    StringComparison.Ordinal
                ) && !string.Equals(errorType, declaredSymbolTypeText, StringComparison.Ordinal)
                    ? ParseTypeName(errorType)
                    : declaredSymbolType;
            var symbolTypeText = symbolType.NormalizeWhitespace().ToFullString();
            var initializer =
                errorName.EndsWith("!", StringComparison.Ordinal) ? ParseExpression(errorName)
                : string.Equals(errorType, symbolTypeText, StringComparison.Ordinal)
                    ? IdentifierName(errorName)
                : CastExpression(symbolType, IdentifierName(errorName));
            statements.Add(
                LocalDeclarationStatement(
                    VariableDeclaration(symbolType)
                        .WithVariables(
                            SingletonSeparatedList(
                                VariableDeclarator(LocalIdentifier(symbol))
                                    .WithInitializer(EqualsValueClause(initializer))
                            )
                        )
                )
            );
        }
    }

    private bool TryGetRaisingCall(JsonElement expr, out string errorType)
    {
        return TryGetRaisingCall(expr, out errorType, out _);
    }

    private bool TryGetRaisingCall(
        JsonElement expr,
        out string errorType,
        out JsonElement errorTypeNode
    )
    {
        errorType = "object";
        errorTypeNode = default;
        if (expr.GetProperty("kind").GetString() != "Call")
            return false;

        var functionId = expr.GetProperty("functionId").GetString() ?? "";
        if (
            functionEffects.TryGetValue(functionId, out var effect)
            && effect.TryGetProperty("kind", out var kind)
            && kind.GetString() == "Raises"
            && effect.TryGetProperty("error", out var error)
        )
        {
            errorTypeNode = error;
            errorType = EmitType(error).NormalizeWhitespace().ToFullString();
            return true;
        }

        return false;
    }

    private bool ExprMayRaise(JsonElement expr)
    {
        if (TryGetRaisingCall(expr, out _))
            return true;

        return expr.GetProperty("kind").GetString() switch
        {
            "Call" => expr.GetProperty("args").EnumerateArray().Any(ExprMayRaise),
            "TraitMethodCall" => ExprMayRaise(expr.GetProperty("receiver"))
                || expr.GetProperty("args").EnumerateArray().Any(ExprMayRaise),
            "FunctionValueCall" => ExprMayRaise(expr.GetProperty("callee"))
                || expr.GetProperty("args").EnumerateArray().Any(ExprMayRaise),
            "ArrayLiteral" => expr.GetProperty("items")
                .EnumerateArray()
                .Any(item => item.TryGetProperty("value", out var value) && ExprMayRaise(value)),
            "TupleLiteral" => expr.GetProperty("items").EnumerateArray().Any(ExprMayRaise),
            "StructLiteral" => expr.GetProperty("fields")
                .EnumerateArray()
                .Any(field => ExprMayRaise(field.GetProperty("value"))),
            "Conversion" => ExprMayRaise(expr.GetProperty("value")),
            "OptionSome" => ExprMayRaise(expr.GetProperty("value")),
            "FieldAccess" or "TupleGet" => ExprMayRaise(expr.GetProperty("target")),
            "Binary" => ExprMayRaise(expr.GetProperty("left"))
                || ExprMayRaise(expr.GetProperty("right")),
            "Unary" => ExprMayRaise(expr.GetProperty("value")),
            _ => false,
        };
    }

    private string EmitRaisingCallResult(
        JsonElement expr,
        string errorType,
        List<StatementSyntax> statements
    )
    {
        var callResult = FreshEmitterTempName("__mbt_raise_result");
        var okType = EmitType(expr.GetProperty("type")).NormalizeWhitespace().ToFullString();
        statements.Add(
            LocalDeclarationStatement(
                VariableDeclaration(ParseTypeName($"MoonBitResult<{okType}, {errorType}>"))
                    .WithVariables(
                        SingletonSeparatedList(
                            VariableDeclarator(callResult)
                                .WithInitializer(
                                    EqualsValueClause(
                                        EmitExprWithRaisingArguments(expr, statements)
                                    )
                                )
                        )
                    )
            )
        );
        return callResult;
    }

    private ReturnStatementSyntax ReturnPropagatedErrorStatement(
        string callResult,
        string errorType,
        JsonElement errorTypeNode
    )
    {
        return ReturnStatement(
            ParseExpression(
                $"MoonBitResult<{EmitType(currentFunctionReturnType).NormalizeWhitespace()}, {currentFunctionErrorType}>.Err({PropagatedErrorExpression($"{callResult}.Error!", errorType, errorTypeNode).NormalizeWhitespace()})"
            )
        );
    }

    private ExpressionSyntax PropagatedErrorExpression(
        string errorExpression,
        string errorType,
        JsonElement errorTypeNode
    )
    {
        if (string.Equals(errorType, currentFunctionErrorType, StringComparison.Ordinal))
            return ParseExpression(errorExpression);

        if (currentFunctionErrorType == CoreBuiltinTypeName("Error"))
        {
            var displayName = MoonBitTypeDisplayName(errorTypeNode);
            var displayExpression = TryEnumErrorNameExpression(
                errorTypeNode,
                errorExpression,
                out var enumDisplayExpression
            )
                ? enumDisplayExpression.NormalizeWhitespace().ToFullString()
                : Literal(displayName).NormalizeWhitespace().ToFullString();
            var valueTypeName = EmitType(errorTypeNode).NormalizeWhitespace().ToFullString();
            if (
                staticTraitImplAdapterTypes.ContainsKey(
                    StaticTraitImplAdapterKey("Show", errorTypeNode)
                )
            )
            {
                var implObjectType = QualifyPackageTypeName(
                    "type:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Show",
                    "ShowImplObject"
                );
                var implType = TraitEvidenceTypeArgument(errorTypeNode, "Show");
                return ParseExpression(
                    $"{CoreBuiltinTypeName("Error")}.FromObject({errorExpression}, {displayExpression}, {implObjectType}<{valueTypeName}, {implType}>.Instance)"
                );
            }

            return ParseExpression(
                $"{CoreBuiltinTypeName("Error")}.FromObject({errorExpression}, {displayExpression})"
            );
        }

        return CastExpression(
            ParseTypeName(currentFunctionErrorType),
            ParseExpression(errorExpression)
        );
    }

    private ExpressionSyntax EmitExprWithRaisingArguments(
        JsonElement expr,
        List<StatementSyntax> statements
    )
    {
        if (expr.GetProperty("kind").GetString() != "Call")
            return EmitExpr(expr);

        var args = expr.GetProperty("args").EnumerateArray().ToArray();
        if (!args.Any(ExprMayRaise))
            return EmitExpr(expr);

        var loweredArgs = args.Select(arg => EmitExprAsStatementValue(arg, statements)).ToArray();
        return EmitCallWithArguments(expr, loweredArgs);
    }

    private ExpressionSyntax TryErrorExpression(
        string errorExpression,
        string sourceErrorType,
        JsonElement sourceErrorTypeNode,
        string tryErrorType
    )
    {
        if (string.Equals(sourceErrorType, tryErrorType, StringComparison.Ordinal))
            return ParseExpression(errorExpression);

        if (tryErrorType == CoreBuiltinTypeName("Error"))
        {
            var displayName = MoonBitTypeDisplayName(sourceErrorTypeNode);
            var displayExpression = TryEnumErrorNameExpression(
                sourceErrorTypeNode,
                errorExpression,
                out var enumDisplayExpression
            )
                ? enumDisplayExpression.NormalizeWhitespace().ToFullString()
                : Literal(displayName).NormalizeWhitespace().ToFullString();
            var valueTypeName = EmitType(sourceErrorTypeNode).NormalizeWhitespace().ToFullString();
            if (
                staticTraitImplAdapterTypes.ContainsKey(
                    StaticTraitImplAdapterKey("Show", sourceErrorTypeNode)
                )
            )
            {
                var implObjectType = QualifyPackageTypeName(
                    "type:pkg:moonbitlang/core/builtin:moonbitlang/core/builtin:Show",
                    "ShowImplObject"
                );
                var implType = TraitEvidenceTypeArgument(sourceErrorTypeNode, "Show");
                return ParseExpression(
                    $"{CoreBuiltinTypeName("Error")}.FromObject({errorExpression}, {displayExpression}, {implObjectType}<{valueTypeName}, {implType}>.Instance)"
                );
            }

            return ParseExpression(
                $"{CoreBuiltinTypeName("Error")}.FromObject({errorExpression}, {displayExpression})"
            );
        }

        return CastExpression(ParseTypeName(tryErrorType), ParseExpression(errorExpression));
    }

    private ExpressionSyntax EmitExprWithTryRaisingArguments(
        JsonElement expr,
        string errorName,
        string tryErrorType,
        string catchLabel,
        List<StatementSyntax> statements
    )
    {
        if (expr.GetProperty("kind").GetString() != "Call")
            return EmitExpr(expr);

        var args = expr.GetProperty("args").EnumerateArray().ToArray();
        if (!args.Any(ExprMayRaise))
            return EmitExpr(expr);

        var loweredArgs = args.Select(arg =>
                EmitExprAsTryStatementValue(arg, errorName, tryErrorType, catchLabel, statements)
            )
            .ToArray();
        return EmitCallWithArguments(expr, loweredArgs);
    }

    private ExpressionSyntax EmitExprAsTryStatementValue(
        JsonElement expr,
        string errorName,
        string tryErrorType,
        string catchLabel,
        List<StatementSyntax> statements
    )
    {
        if (TryGetRaisingCall(expr, out var errorType, out var errorTypeNode))
        {
            var callResult = FreshEmitterTempName("__mbt_try_result");
            var okType = EmitType(expr.GetProperty("type")).NormalizeWhitespace().ToFullString();
            statements.Add(
                LocalDeclarationStatement(
                    VariableDeclaration(ParseTypeName($"MoonBitResult<{okType}, {errorType}>"))
                        .WithVariables(
                            SingletonSeparatedList(
                                VariableDeclarator(callResult)
                                    .WithInitializer(
                                        EqualsValueClause(
                                            EmitExprWithTryRaisingArguments(
                                                expr,
                                                errorName,
                                                tryErrorType,
                                                catchLabel,
                                                statements
                                            )
                                        )
                                    )
                            )
                        )
                )
            );
            statements.Add(
                IfStatement(
                    PrefixUnaryExpression(
                        SyntaxKind.LogicalNotExpression,
                        MemberAccessExpression(
                            SyntaxKind.SimpleMemberAccessExpression,
                            IdentifierName(callResult),
                            IdentifierName("IsOk")
                        )
                    ),
                    Block(
                        ExpressionStatement(
                            AssignmentExpression(
                                SyntaxKind.SimpleAssignmentExpression,
                                IdentifierName(errorName),
                                TryErrorExpression(
                                    $"{callResult}.Error!",
                                    errorType,
                                    errorTypeNode,
                                    tryErrorType
                                )
                            )
                        ),
                        GotoStatement(SyntaxKind.GotoStatement, IdentifierName(catchLabel))
                    )
                )
            );
            return ParseExpression($"{callResult}.Value!");
        }

        if (!ExprNeedsAssignmentStatementLowering(expr) && !ExprMayRaise(expr))
            return EmitExpr(expr);

        var tempName = FreshEmitterTempName("__mbt_expr");
        statements.Add(
            LocalDeclarationStatement(
                VariableDeclaration(EmitType(expr.GetProperty("type")))
                    .WithVariables(SingletonSeparatedList(VariableDeclarator(tempName)))
            )
        );
        EmitTryBody(expr, tempName, errorName, tryErrorType, catchLabel, statements);
        return IdentifierName(tempName);
    }

    private static bool IsUnitValueExpression(ExpressionSyntax expr)
    {
        return expr.NormalizeWhitespace().ToFullString() == "MoonBitUnit.Value";
    }

    private bool TryGetTryBodyErrorType(JsonElement expr, out string errorType)
    {
        if (TryGetRaisingCall(expr, out errorType))
            return true;

        if (expr.GetProperty("kind").GetString() == "Sequence")
            return TryGetTryBodyErrorType(expr.GetProperty("first"), out errorType)
                || TryGetTryBodyErrorType(expr.GetProperty("body"), out errorType);

        errorType = "object";
        return false;
    }

    private static bool IsUnitType(JsonElement type)
    {
        return type.GetProperty("kind").GetString() == "Builtin"
            && type.GetProperty("name").GetString() == "Unit";
    }
}
