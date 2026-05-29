#nullable enable

using System;

namespace Generated.MoonBit;

public sealed class MoonBitFailure : Exception
{
    public MoonBitFailure(string message)
        : base(message) { }
}

public static class MoonBitControl
{
    public static T Fail<T>(string message, string? source = null) =>
        throw new MoonBitFailure(FormatFailure(message, source));

    public static void Fail(string message, string? source = null) =>
        throw new MoonBitFailure(FormatFailure(message, source));

    public static T Panic<T>() => throw new InvalidOperationException("panic");

    public static void Panic() => throw new InvalidOperationException("panic");

    private static string FormatFailure(string message, string? source) =>
        source is null ? message : $"{source} FAILED: {message}";
}

public static class MoonBitShow
{
    public static string ShowTuple(params string[] items) => "(" + string.Join(", ", items) + ")";

    public static string QuoteString(string value) =>
        "\""
        + value
            .Replace("\\", "\\\\", StringComparison.Ordinal)
            .Replace("\"", "\\\"", StringComparison.Ordinal)
        + "\"";

    public static string ShowValue(string value) => value;

    public static string ShowValue<T>(T value) => ShowObject(value);

    public static string ShowNested<T>(T value) => ShowObject(value);

    private static string ShowObject(object? value) =>
        value switch
        {
            null => "",
            int i => i.ToString(System.Globalization.CultureInfo.InvariantCulture),
            ushort u => u.ToString(System.Globalization.CultureInfo.InvariantCulture),
            ulong ul => ul.ToString(System.Globalization.CultureInfo.InvariantCulture),
            System.Text.Rune r => r.ToString(),
            float f => f.ToString(System.Globalization.CultureInfo.InvariantCulture),
            double d => d.ToString(System.Globalization.CultureInfo.InvariantCulture),
            bool b => b ? "true" : "false",
            string s => QuoteString(s),
            Array array => ShowArray(array),
            System.Runtime.CompilerServices.ITuple tuple => ShowTupleValue(tuple),
            _ => value.ToString() ?? "",
        };

    private static string ShowArray(Array array)
    {
        var items = new string[array.Length];
        for (var i = 0; i < array.Length; i++)
        {
            items[i] = ShowObject(array.GetValue(i));
        }

        return "[" + string.Join(", ", items) + "]";
    }

    private static string ShowTupleValue(System.Runtime.CompilerServices.ITuple tuple)
    {
        var items = new string[tuple.Length];
        for (var i = 0; i < tuple.Length; i++)
        {
            items[i] = ShowObject(tuple[i]);
        }

        return ShowTuple(items);
    }
}

public static class MoonBitConsole
{
    public static void println(string value) => Console.WriteLine(value);

    public static void println<T>(T value) => Console.WriteLine(MoonBitShow.ShowValue(value));
}

public readonly record struct MoonBitResult<T>(bool IsOk, T? Value, string? Error)
{
    public static MoonBitResult<T> Ok(T value) => new(true, value, null);

    public static MoonBitResult<T> Err(string error) => new(false, default, error);

    public override string ToString() =>
        IsOk ? $"Ok({Value})" : $"Err(Failure({MoonBitShow.QuoteString(Error ?? "")}))";
}

public static partial class Sample
{
    public static int safe_add(int i, int j)
    {
        int signum_i = i & -2147483648;
        int signum_j = j & -2147483648;
        int result = i + j;
        if (signum_i != signum_j)
        {
            return result;
        }
        else
        {
            int result_signum = result & -2147483648;
            if (result_signum != signum_i)
            {
                return MoonBitControl.Fail<int>("overflow");
            }
            else
            {
                return result;
            }
        }
    }

    public static void Main()
    {
        int a;
        try
        {
            a = safe_add(1, 2);
        }
        catch
        {
            a = MoonBitControl.Panic<int>();
        }

        MoonBitConsole.println(a);
        try
        {
            int result = safe_add(2147483647, 2147483647);
            MoonBitConsole.println(result);
        }
        catch (MoonBitFailure ex)
        {
            string error_message = ex.Message;
            MoonBitConsole.println(error_message);
        }
        catch
        {
            MoonBitControl.Panic();
        }

        MoonBitResult<int> result_1;
        try
        {
            result_1 = MoonBitResult<int>.Ok(safe_add(2147483647, 2147483647));
        }
        catch (MoonBitFailure ex)
        {
            result_1 = MoonBitResult<int>.Err(ex.Message);
        }

        MoonBitConsole.println(result_1);
    }
}
