using static Microsoft.CodeAnalysis.CSharp.SyntaxFactory;

namespace MoonBit2CSharp.Backend;

public static partial class IntrinsicBindings
{
    private static readonly IntrinsicBinding[] Bindings = GeneratedAdapterBindings()
        .Concat(FrameworkCallBindings())
        .Concat(HandwrittenRuntimeBindings())
        .ToArray();

    private static readonly IReadOnlyDictionary<string, IntrinsicBinding> BindingsByExternalName =
        Bindings
            .GroupBy(binding => binding.ExternalName, StringComparer.Ordinal)
            .ToDictionary(group => group.Key, group => group.First(), StringComparer.Ordinal);

    public static IReadOnlySet<string> SupportedExternalNames { get; } =
        BindingsByExternalName.Keys.ToHashSet(StringComparer.Ordinal);

    public static IReadOnlySet<string> SupportedFunctionValueExternalNames { get; } =
        Bindings
            .Where(binding => binding.FunctionValue is not null)
            .Select(binding => binding.ExternalName)
            .ToHashSet(StringComparer.Ordinal);

    public static IReadOnlySet<string> DirectMethodExternalNames { get; } =
        Bindings
            .Where(binding => binding.Method is not null)
            .Select(binding => binding.ExternalName)
            .ToHashSet(StringComparer.Ordinal);

    //     public static bool TryEmitFunctionValue(
    //         string externalName,
    //         TypeRefIr functionType,
    //         out ExpressionSyntax expression
    //     )
    //     {
    //         expression = LiteralExpression(SyntaxKind.DefaultLiteralExpression);
    //         if (
    //             functionType.Name != "Function"
    //             || functionType.Elements is not { Count: > 0 }
    //             || functionType.Element is null
    //             || !TryGetFunctionValueMethodName(externalName, out var methodName)
    //         )
    //         {
    //             return false;
    //         }

    //         expression = ParseExpression($"MoonBitIntrinsics.{methodName}");
    //         return true;
    //     }

    //     public static bool HasDirectMethod(string externalName) =>
    //         BindingsByExternalName.TryGetValue(externalName, out var binding)
    //         && binding.Method is not null;

    //     public static bool TryGetFunctionValueMethodName(string externalName, out string methodName)
    //     {
    //         if (
    //             BindingsByExternalName.TryGetValue(externalName, out var binding)
    //             && binding.FunctionValue is { } functionValue
    //         )
    //         {
    //             methodName = functionValue.MethodName;
    //             return true;
    //         }

    //         methodName = "";
    //         return false;
    //     }

    //     public static IReadOnlyList<MemberDeclarationSyntax> EmitFunctionValueMethods(
    //         IReadOnlySet<string> externalNames
    //     ) =>
    //         Bindings
    //             .Where(binding => externalNames.Contains(binding.ExternalName))
    //             .Select(binding => binding.FunctionValue)
    //             .OfType<FunctionValueBinding>()
    //             .GroupBy(binding => binding.MethodName, StringComparer.Ordinal)
    //             .Select(group => group.First())
    //             .OrderBy(binding => binding.MethodName, StringComparer.Ordinal)
    //             .Select(binding =>
    //                 ParseMemberDeclaration(
    //                     $"public static {binding.ReturnType} {binding.MethodName}({binding.Signature}) => {binding.Body};"
    //                 )!
    //             )
    //             .ToArray();

    //     public static IReadOnlyList<MemberDeclarationSyntax> EmitDirectMethods(
    //         IReadOnlySet<string> externalNames
    //     ) =>
    //         Bindings
    //             .Where(binding => externalNames.Contains(binding.ExternalName))
    //             .Select(binding => binding.Method)
    //             .OfType<MethodBinding>()
    //             .GroupBy(binding => binding.MethodName, StringComparer.Ordinal)
    //             .Select(group => group.First())
    //             .OrderBy(binding => binding.MethodName, StringComparer.Ordinal)
    //             .Select(binding =>
    //                 ParseMemberDeclaration(
    //                     $$"""
    //                     public static {{binding.ReturnType}} {{binding.MethodName}}({{binding.Signature}})
    //                     {
    //                     {{binding.Body}}
    //                     }
    //                     """
    //                 )!
    //             )
    //             .ToArray();

    //     public static bool TryGetParameterTypeName(string externalName, int index, out string typeName)
    //     {
    //         if (
    //             BindingsByExternalName.TryGetValue(externalName, out var binding)
    //             && index < binding.ParameterTypes.Count
    //             && binding.ParameterTypes[index] != "_"
    //         )
    //         {
    //             typeName = binding.ParameterTypes[index];
    //             return true;
    //         }

    //         typeName = "";
    //         return false;
    //     }

    //     public static bool TryEmit(
    //         ExternDeclIr decl,
    //         IReadOnlyList<ArgumentSyntax> arguments,
    //         TypeSyntax returnType,
    //         out ExpressionSyntax expression
    //     ) => TryEmit(decl.ExternalName, arguments, returnType, out expression);

    public static bool TryEmit(
        string externalName,
        IReadOnlyList<ArgumentSyntax> arguments,
        TypeSyntax returnType,
        out ExpressionSyntax expression
    )
    {
        expression = LiteralExpression(SyntaxKind.DefaultLiteralExpression);
        if (!BindingsByExternalName.TryGetValue(externalName, out var binding))
            return false;
        if (binding.ParameterTypes.Count != arguments.Count)
            return false;

        if (binding.Method is { } method)
        {
            expression = InvocationExpression(
                MemberAccessExpression(
                    SyntaxKind.SimpleMemberAccessExpression,
                    IdentifierName("MoonBitIntrinsics"),
                    IdentifierName(method.MethodName)
                ),
                ArgumentList(SeparatedList(arguments))
            );
            return true;
        }

        if (binding.Direct is null)
            return false;

        var args = arguments
            .Select(argument => argument.Expression.NormalizeWhitespace().ToFullString())
            .ToArray();
        expression = binding.Direct(arguments, args, returnType);
        return true;
    }

    private static IntrinsicBinding Direct(
        string externalName,
        IReadOnlyList<string> parameterTypes,
        DirectEmitter direct
    )
    {
        return new(externalName, parameterTypes, direct);
    }

    private static IntrinsicBinding Direct(
        string externalName,
        IReadOnlyList<string> parameterTypes,
        Func<IReadOnlyList<ArgumentSyntax>, ExpressionSyntax> direct
    )
    {
        return new(externalName, parameterTypes, (arguments, _, _) => direct(arguments));
    }

    private static ExpressionSyntax Binary(IReadOnlyList<ArgumentSyntax> arguments, string op)
    {
        return BinaryExpression(
            MapBinaryOperator(op),
            BinaryOperand(op, arguments[0].Expression, false),
            BinaryOperand(op, arguments[1].Expression, true)
        );
    }

    private static ExpressionSyntax BinaryOperand(
        string parentOp,
        ExpressionSyntax operand,
        bool isRight
    )
    {
        if (
            operand is BinaryExpressionSyntax childBinary
            && NeedsBinaryOperandParentheses(parentOp, BinaryOperatorText(childBinary), isRight)
        )
            return ParenthesizedExpression(operand);

        return operand;
    }

    private static bool NeedsBinaryOperandParentheses(string parentOp, string childOp, bool isRight)
    {
        var parentPrecedence = BinaryPrecedence(parentOp);
        var childPrecedence = BinaryPrecedence(childOp);
        if (childPrecedence < parentPrecedence)
            return true;

        return isRight
            && childPrecedence == parentPrecedence
            && !IsSafeRightAssociative(parentOp, childOp);
    }

    private static bool IsSafeRightAssociative(string parentOp, string childOp)
    {
        return parentOp == childOp && parentOp is "+" or "*" or "&&" or "||" or "&" or "|" or "^";
    }

    private static int BinaryPrecedence(string op)
    {
        return op switch
        {
            "||" => 1,
            "&&" => 2,
            "|" => 3,
            "^" => 4,
            "&" => 5,
            "==" or "!=" => 6,
            "<" or "<=" or ">" or ">=" => 7,
            "<<" or ">>" => 8,
            "+" or "-" => 9,
            "*" or "/" or "%" => 10,
            _ => 0,
        };
    }

    private static string BinaryOperatorText(BinaryExpressionSyntax binary)
    {
        return binary.Kind() switch
        {
            SyntaxKind.AddExpression => "+",
            SyntaxKind.SubtractExpression => "-",
            SyntaxKind.MultiplyExpression => "*",
            SyntaxKind.DivideExpression => "/",
            SyntaxKind.ModuloExpression => "%",
            SyntaxKind.LogicalAndExpression => "&&",
            SyntaxKind.LogicalOrExpression => "||",
            SyntaxKind.EqualsExpression => "==",
            SyntaxKind.NotEqualsExpression => "!=",
            SyntaxKind.LessThanExpression => "<",
            SyntaxKind.LessThanOrEqualExpression => "<=",
            SyntaxKind.GreaterThanExpression => ">",
            SyntaxKind.GreaterThanOrEqualExpression => ">=",
            SyntaxKind.BitwiseAndExpression => "&",
            SyntaxKind.BitwiseOrExpression => "|",
            SyntaxKind.ExclusiveOrExpression => "^",
            SyntaxKind.LeftShiftExpression => "<<",
            SyntaxKind.RightShiftExpression => ">>",
            _ => "",
        };
    }

    private static SyntaxKind MapBinaryOperator(string op)
    {
        return op switch
        {
            "+" => SyntaxKind.AddExpression,
            "-" => SyntaxKind.SubtractExpression,
            "*" => SyntaxKind.MultiplyExpression,
            "/" => SyntaxKind.DivideExpression,
            "%" => SyntaxKind.ModuloExpression,
            "==" => SyntaxKind.EqualsExpression,
            "!=" => SyntaxKind.NotEqualsExpression,
            "<" => SyntaxKind.LessThanExpression,
            "<=" => SyntaxKind.LessThanOrEqualExpression,
            ">" => SyntaxKind.GreaterThanExpression,
            ">=" => SyntaxKind.GreaterThanOrEqualExpression,
            "&" => SyntaxKind.BitwiseAndExpression,
            "|" => SyntaxKind.BitwiseOrExpression,
            "^" => SyntaxKind.ExclusiveOrExpression,
            "<<" => SyntaxKind.LeftShiftExpression,
            ">>" => SyntaxKind.RightShiftExpression,
            _ => throw new NotSupportedException($"intrinsic operator not supported: {op}"),
        };
    }

    private static string FixedArrayElementType(TypeSyntax returnType)
    {
        return returnType switch
        {
            ArrayTypeSyntax arrayType => arrayType.ElementType.NormalizeWhitespace().ToFullString(),
            _ => throw new InvalidOperationException(
                $"fixed array intrinsic expected array return type, got {returnType.NormalizeWhitespace().ToFullString()}"
            ),
        };
    }

    private static ExpressionSyntax EmitFixedArrayMake(
        IReadOnlyList<ArgumentSyntax> arguments,
        IReadOnlyList<string> argumentText,
        TypeSyntax returnType
    )
    {
        var elementType = FixedArrayElementType(returnType);
        if (
            arguments[0].Expression is LiteralExpressionSyntax sizeLiteral
            && sizeLiteral.Token.Value is int size
            && size is >= 0 and <= 64
            && IsFixedArrayRepeatSafe(arguments[1].Expression)
        )
        {
            var items = string.Join(", ", Enumerable.Repeat(argumentText[1], size));
            return ParseExpression($"new {elementType}[] {{ {items} }}");
        }

        return ParseExpression(
            $"MoonBitFixedArray.Make<{elementType}>({argumentText[0]}, {argumentText[1]})"
        );
    }

    private static ExpressionSyntax EmitUninitializedArrayMake(
        IReadOnlyList<string> argumentText,
        TypeSyntax returnType
    )
    {
        var elementType = FixedArrayElementType(returnType);
        return ParseExpression($"new {elementType}[{argumentText[0]}]");
    }

    private static bool IsFixedArrayRepeatSafe(ExpressionSyntax expression)
    {
        return expression is LiteralExpressionSyntax or CastExpressionSyntax;
    }

    private delegate ExpressionSyntax DirectEmitter(
        IReadOnlyList<ArgumentSyntax> arguments,
        IReadOnlyList<string> argumentText,
        TypeSyntax returnType
    );

    private sealed record FunctionValueBinding(
        string MethodName,
        string ReturnType,
        string Signature,
        string Body
    );

    private sealed record MethodBinding(
        string MethodName,
        string ReturnType,
        string Signature,
        string Body
    );

    private sealed record IntrinsicBinding(
        string ExternalName,
        IReadOnlyList<string> ParameterTypes,
        DirectEmitter? Direct,
        MethodBinding? Method = null,
        FunctionValueBinding? FunctionValue = null
    );
}
