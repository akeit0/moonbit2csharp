using static Microsoft.CodeAnalysis.CSharp.SyntaxFactory;

namespace MoonBit2CSharp.Backend;

public static partial class IntrinsicBindings
{
    private static IEnumerable<IntrinsicBinding> HandwrittenRuntimeBindings()
    {
        yield return Direct(
            "%panic",
            [],
            (_, _, _) =>
                ThrowExpression(
                    ObjectCreationExpression(IdentifierName("MoonBitPanic"))
                        .WithArgumentList(ArgumentList())
                )
        );
        yield return Direct(
            "%ignore",
            ["_"],
            (_, args, _) => ParseExpression($"MoonBitIntrinsics.Ignore({args[0]})")
        );
        yield return Direct(
            "%bytes_make",
            ["Int", "Byte"],
            (_, args, _) =>
                ParseExpression(
                    $"System.Linq.Enumerable.Repeat((byte){args[1]}, {args[0]}).ToArray()"
                )
        );
        yield return Direct(
            "$moonbit.unsafe_bytes_sub_string",
            ["Bytes", "Int", "Int"],
            (_, args, _) =>
                ParseExpression(
                    $"System.Text.Encoding.Unicode.GetString({args[0]}.AsSpan().Slice({args[1]}, {args[2]}))"
                )
        );
        yield return Direct(
            "%fixedarray.make",
            ["Int", "_"],
            (arguments, args, returnType) => EmitFixedArrayMake(arguments, args, returnType)
        );
        yield return Direct(
            "%fixedarray.set",
            ["_", "Int", "_"],
            (_, args, _) =>
                ParseExpression($"MoonBitFixedArray.Set({args[0]}, {args[1]}, {args[2]})")
        );
        yield return Direct(
            "%fixedarray.unsafe_set",
            ["_", "Int", "_"],
            (_, args, _) =>
                ParseExpression($"MoonBitFixedArray.Set({args[0]}, {args[1]}, {args[2]})")
        );
        yield return Direct(
            "%arrayview.buf",
            ["_"],
            (_, args, _) => ParseExpression($"{args[0]}.Buffer")
        );
        yield return Direct(
            "%arrayview.start",
            ["_"],
            (_, args, _) => ParseExpression($"{args[0]}.StartOffset")
        );
        yield return Direct(
            "%arrayview.len",
            ["_"],
            (_, args, _) => ParseExpression($"{args[0]}.Length")
        );
        yield return Direct(
            "%arrayview.make",
            ["_", "Int", "Int"],
            (_, args, returnType) =>
                ParseExpression($"{returnType}.Make({args[0]}, {args[1]}, {args[2]})")
        );
        yield return Direct(
            "%arrayview.unsafe_get",
            ["_", "Int"],
            (_, args, _) => ParseExpression($"{args[0]}[{args[1]}]")
        );
        yield return Direct(
            "%arrayview.unsafe_set",
            ["_", "Int", "_"],
            (_, args, _) => ParseExpression($"{args[0]}[{args[1]}] = {args[2]}")
        );
        yield return Direct(
            "%array.unsafe_get",
            ["_", "Int"],
            (_, args, _) => ParseExpression($"ArrayUtility.UnsafeGet({args[0]}, {args[1]})")
        );
        yield return Direct(
            "%array.get",
            ["_", "Int"],
            (_, args, _) => ParseExpression($"ArrayUtility.Get({args[0]}, {args[1]})")
        );
        yield return Direct(
            "%array.unsafe_set",
            ["_", "Int", "_"],
            (_, args, _) =>
                ParseExpression($"ArrayUtility.UnsafeSet({args[0]}, {args[1]}, {args[2]})")
        );
        yield return Direct(
            "%array.set",
            ["_", "Int", "_"],
            (_, args, _) => ParseExpression($"ArrayUtility.Set({args[0]}, {args[1]}, {args[2]})")
        );
        yield return Direct(
            "%array_is_empty",
            ["_"],
            (_, args, _) => ParseExpression($"ArrayUtility.IsEmpty({args[0]})")
        );
        yield return Direct(
            "%array_copy",
            ["_"],
            (_, args, _) => ParseExpression($"ArrayUtility.Copy({args[0]})")
        );
        yield return Direct(
            "%array_make",
            ["Int", "_"],
            (_, args, _) => ParseExpression($"MoonBitIntrinsics.ArrayMake({args[0]}, {args[1]})")
        );
        yield return Direct(
            "%array_remove",
            ["_", "Int"],
            (_, args, _) => ParseExpression($"MoonBitIntrinsics.ArrayRemove({args[0]}, {args[1]})")
        );
        yield return Direct(
            "%array_pop",
            ["_"],
            (_, args, _) => ParseExpression($"ArrayUtility.Pop({args[0]})")
        );
        yield return Direct(
            "%array_last",
            ["_"],
            (_, args, _) => ParseExpression($"MoonBitIntrinsics.ArrayLast({args[0]})")
        );
        yield return Direct(
            "%array_filter",
            ["_", "_"],
            (_, args, _) => ParseExpression($"MoonBitIntrinsics.ArrayFilter({args[0]}, {args[1]})")
        );
        yield return Direct(
            "%array_sort_by",
            ["_", "_"],
            (_, args, _) => ParseExpression($"MoonBitIntrinsics.ArraySortBy({args[0]}, {args[1]})")
        );
        yield return Direct(
            "%f64_to_string",
            ["Double"],
            (_, args, _) =>
                ParseExpression(
                    $"{args[0]}.ToString(System.Globalization.CultureInfo.InvariantCulture)"
                )
        );
        yield return Direct(
            "%f32_to_string",
            ["Float"],
            (_, args, _) =>
                ParseExpression(
                    $"{args[0]}.ToString(System.Globalization.CultureInfo.InvariantCulture)"
                )
        );
        yield return Direct(
            "%f32.div",
            ["Float", "Float"],
            (_, args, _) => ParseExpression($"{args[0]} / {args[1]}")
        );
        yield return Direct(
            "%f64_div",
            ["Double", "Double"],
            (_, args, _) => ParseExpression($"{args[0]} / {args[1]}")
        );
        yield return Direct(
            "%f32.lt",
            ["Float", "Float"],
            (_, args, _) => ParseExpression($"{args[0]} < {args[1]}")
        );
        yield return Direct(
            "%f64.lt",
            ["Double", "Double"],
            (_, args, _) => ParseExpression($"{args[0]} < {args[1]}")
        );
        yield return Direct(
            "%string_has_prefix",
            ["String", "StringView"],
            (_, args, _) =>
                ParseExpression(
                    $"{args[0]}.AsSpan().StartsWith({args[1]}.AsSpan(), StringComparison.Ordinal)"
                )
        );
        yield return Direct(
            "%string_has_suffix",
            ["String", "StringView"],
            (_, args, _) =>
                ParseExpression(
                    $"{args[0]}.AsSpan().EndsWith({args[1]}.AsSpan(), StringComparison.Ordinal)"
                )
        );
        yield return Direct(
            "%string_contains",
            ["String", "StringView"],
            (_, args, _) =>
                ParseExpression(
                    $"{args[0]}.AsSpan().Contains({args[1]}.AsSpan(), StringComparison.Ordinal)"
                )
        );
        yield return Direct(
            "%string_contains_char",
            ["String", "Char"],
            (_, args, _) =>
                ParseExpression(
                    $"MoonBitIntrinsics.StringContainsChar({args[0]}.View(), {args[1]})"
                )
        );
        yield return Direct(
            "%string_trim",
            ["String", "StringView"],
            (_, args, _) =>
                ParseExpression($"MoonBitIntrinsics.StringViewTrim({args[0]}.View(), {args[1]})")
        );
        yield return Direct(
            "%string_trim_start",
            ["String", "StringView"],
            (_, args, _) =>
                ParseExpression(
                    $"MoonBitIntrinsics.StringViewTrimStart({args[0]}.View(), {args[1]})"
                )
        );
        yield return Direct(
            "%string_trim_end",
            ["String", "StringView"],
            (_, args, _) =>
                ParseExpression($"MoonBitIntrinsics.StringViewTrimEnd({args[0]}.View(), {args[1]})")
        );
        yield return Direct(
            "%string_split",
            ["String", "StringView"],
            (_, args, _) => ParseExpression($"{args[0]}.SplitMoonBit({args[1]})")
        );
        yield return Direct(
            "%string_is_empty",
            ["String"],
            (_, args, _) => ParseExpression($"{args[0]}.Length == 0")
        );
        yield return Direct(
            "%string.substring",
            ["String", "Int", "Int"],
            (_, args, _) =>
                ParseExpression($"{args[0]}.Substring({args[1]}, {args[2]} - {args[1]})")
        );
        yield return Direct(
            "%string_get_char",
            ["String", "Int"],
            (_, args, _) =>
                ParseExpression($"MoonBitIntrinsics.StringGetChar({args[0]}, {args[1]})")
        );
        yield return Direct(
            "%string_to_array",
            ["String"],
            (_, args, _) => ParseExpression($"MoonBitIntrinsics.StringToArray({args[0]}.View())")
        );
        yield return Direct(
            "%string_char_length",
            ["String"],
            (_, args, _) => ParseExpression($"MoonBitIntrinsics.StringCharLength({args[0]}.View())")
        );
        yield return Direct(
            "%string_make",
            ["Int", "Char"],
            (_, args, _) => ParseExpression($"MoonBitIntrinsics.StringMake({args[0]}, {args[1]})")
        );
        yield return Direct(
            "%string_to_lower",
            ["String"],
            (_, args, _) => ParseExpression($"{args[0]}.ToLowerInvariant()")
        );
        yield return Direct(
            "%string_to_upper",
            ["String"],
            (_, args, _) => ParseExpression($"{args[0]}.ToUpperInvariant()")
        );
        yield return Direct(
            "%stringview_is_empty",
            ["StringView"],
            (_, args, _) => ParseExpression($"{args[0]}.Length == 0")
        );
        yield return Direct(
            "%stringview_eq",
            ["StringView", "StringView"],
            (_, args, _) => ParseExpression($"{args[0]}.AsSpan().SequenceEqual({args[1]}.AsSpan())")
        );
        yield return Direct(
            "%stringview_ne",
            ["StringView", "StringView"],
            (_, args, _) =>
                ParseExpression($"!{args[0]}.AsSpan().SequenceEqual({args[1]}.AsSpan())")
        );
        yield return Direct(
            "%stringview_find",
            ["StringView", "StringView"],
            (_, args, _) =>
                ParseExpression($"MoonBitIntrinsics.StringViewFind({args[0]}, {args[1]})")
        );
        yield return Direct(
            "%stringview_view",
            ["StringView", "Int", "_"],
            (_, args, _) =>
                ParseExpression(
                    $"MoonBitIntrinsics.StringViewView({args[0]}, {args[1]}, {args[2]})"
                )
        );
        yield return Direct(
            "%stringview_get_char",
            ["StringView", "Int"],
            (_, args, _) =>
                ParseExpression($"MoonBitIntrinsics.StringViewGetChar({args[0]}, {args[1]})")
        );
        yield return Direct(
            "%stringview_to_array",
            ["StringView"],
            (_, args, _) => ParseExpression($"MoonBitIntrinsics.StringToArray({args[0]})")
        );
        yield return Direct(
            "%stringview_char_length",
            ["StringView"],
            (_, args, _) => ParseExpression($"MoonBitIntrinsics.StringCharLength({args[0]})")
        );
        yield return Direct(
            "%stringview_to_lower",
            ["StringView"],
            (_, args, _) => ParseExpression($"{args[0]}.ToString().ToLowerInvariant().View()")
        );
        yield return Direct(
            "%stringview_to_upper",
            ["StringView"],
            (_, args, _) => ParseExpression($"{args[0]}.ToString().ToUpperInvariant().View()")
        );
        yield return Direct(
            "%stringview_has_prefix",
            ["StringView", "StringView"],
            (_, args, _) =>
                ParseExpression(
                    $"{args[0]}.AsSpan().StartsWith({args[1]}.AsSpan(), StringComparison.Ordinal)"
                )
        );
        yield return Direct(
            "%stringview_has_suffix",
            ["StringView", "StringView"],
            (_, args, _) =>
                ParseExpression(
                    $"{args[0]}.AsSpan().EndsWith({args[1]}.AsSpan(), StringComparison.Ordinal)"
                )
        );
        yield return Direct(
            "%stringview_contains",
            ["StringView", "StringView"],
            (_, args, _) =>
                ParseExpression(
                    $"{args[0]}.AsSpan().Contains({args[1]}.AsSpan(), StringComparison.Ordinal)"
                )
        );
        yield return Direct(
            "%stringview_contains_char",
            ["StringView", "Char"],
            (_, args, _) =>
                ParseExpression($"MoonBitIntrinsics.StringContainsChar({args[0]}, {args[1]})")
        );
        yield return Direct(
            "%stringview_trim",
            ["StringView", "StringView"],
            (_, args, _) =>
                ParseExpression($"MoonBitIntrinsics.StringViewTrim({args[0]}, {args[1]})")
        );
        yield return Direct(
            "%stringview_trim_start",
            ["StringView", "StringView"],
            (_, args, _) =>
                ParseExpression($"MoonBitIntrinsics.StringViewTrimStart({args[0]}, {args[1]})")
        );
        yield return Direct(
            "%stringview_trim_end",
            ["StringView", "StringView"],
            (_, args, _) =>
                ParseExpression($"MoonBitIntrinsics.StringViewTrimEnd({args[0]}, {args[1]})")
        );
    }
}
