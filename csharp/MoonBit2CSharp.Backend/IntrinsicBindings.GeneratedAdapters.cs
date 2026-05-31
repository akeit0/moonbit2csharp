using System.Globalization;
using System.Text.RegularExpressions;
using static Microsoft.CodeAnalysis.CSharp.SyntaxFactory;

namespace MoonBit2CSharp.Backend;

public static partial class IntrinsicBindings
{
    private static IEnumerable<IntrinsicBinding> GeneratedAdapterBindings()
    {
        return IntrinsicImplementationCatalog
            .BindingSpecs.Where(binding =>
                IntrinsicImplementationCatalog.MetadataFor(binding.ExternalName).Mode
                == "GeneratedAdapter"
            )
            .Select(CreateDeclarativeBinding);
    }

    private static IntrinsicBinding CreateDeclarativeBinding(IntrinsicBindingSpec spec)
    {
        var functionValue = spec.FunctionValue is null
            ? null
            : new FunctionValueBinding(
                spec.FunctionValue.MethodName,
                spec.FunctionValue.ReturnType,
                spec.FunctionValue.Signature,
                spec.FunctionValue.Body
            );
        var method = spec.Method is null
            ? null
            : new MethodBinding(
                spec.Method.MethodName,
                spec.Method.ReturnType,
                spec.Method.Signature,
                spec.Method.Body
            );
        return new(
            spec.ExternalName,
            spec.ParameterTypes,
            spec.Expression is null
                ? null
                : (arguments, argumentText, returnType) =>
                    EmitGeneratedAdapter(
                        spec.ExternalName,
                        spec.Expression,
                        arguments,
                        argumentText,
                        returnType
                    ),
            method,
            functionValue
        );
    }

    private static ExpressionSyntax EmitGeneratedAdapter(
        string externalName,
        IntrinsicExpressionSpec expression,
        IReadOnlyList<ArgumentSyntax> arguments,
        IReadOnlyList<string> argumentText,
        TypeSyntax returnType
    )
    {
        return expression.Kind switch
        {
            "Unit" => ParseExpression("MoonBitUnit.Value"),
            "Argument" => arguments[
                expression.ArgumentIndex
                    ?? throw MissingIntrinsicExpressionValue(externalName, "argumentIndex")
            ].Expression,
            "Binary" => Binary(
                arguments,
                RequiredIntrinsicExpressionValue(externalName, expression.Operator, "operator")
            ),
            "Prefix" => PrefixExpression(externalName, expression, arguments),
            "Template" => ParseExpression(
                FormatIntrinsicTemplate(
                    externalName,
                    RequiredIntrinsicExpressionValue(externalName, expression.Template, "template"),
                    argumentText
                )
            ),
            "UninitializedArrayMake" => EmitUninitializedArrayMake(argumentText, returnType),
            _ => throw new NotSupportedException(
                $"intrinsic adapter expression kind not supported for {externalName}: {expression.Kind}"
            ),
        };
    }

    private static ExpressionSyntax PrefixExpression(
        string externalName,
        IntrinsicExpressionSpec expression,
        IReadOnlyList<ArgumentSyntax> arguments
    )
    {
        if (arguments.Count != 1)
            throw new InvalidOperationException(
                $"intrinsic adapter prefix expression for {externalName} expected one argument"
            );

        return RequiredIntrinsicExpressionValue(
            externalName,
            expression.Operator,
            "operator"
        ) switch
        {
            "!" => PrefixUnaryExpression(
                SyntaxKind.LogicalNotExpression,
                ParenthesizedExpression(arguments[0].Expression)
            ),
            _ => ParseExpression(
                RequiredIntrinsicExpressionValue(externalName, expression.Operator, "operator")
                    + arguments[0].Expression.NormalizeWhitespace().ToFullString()
            ),
        };
    }

    private static string FormatIntrinsicTemplate(
        string externalName,
        string template,
        IReadOnlyList<string> argumentText
    )
    {
        var result = template;
        for (var i = 0; i < argumentText.Count; i++)
            result = result.Replace(
                "{" + i.ToString(CultureInfo.InvariantCulture) + "}",
                argumentText[i],
                StringComparison.Ordinal
            );

        if (Regex.IsMatch(result, @"\{\d+\}"))
            throw new InvalidOperationException(
                $"intrinsic adapter template for {externalName} contains unresolved placeholders: {template}"
            );

        return result;
    }

    private static string RequiredIntrinsicExpressionValue(
        string externalName,
        string? value,
        string propertyName
    )
    {
        return value ?? throw MissingIntrinsicExpressionValue(externalName, propertyName);
    }

    private static InvalidOperationException MissingIntrinsicExpressionValue(
        string externalName,
        string propertyName
    )
    {
        return new($"intrinsic adapter expression for {externalName} is missing {propertyName}");
    }
}
