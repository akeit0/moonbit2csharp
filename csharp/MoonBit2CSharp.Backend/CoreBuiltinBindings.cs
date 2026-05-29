// namespace MoonBit2CSharp.Backend;

// internal static class CoreBuiltinBindings
// {
//     private static readonly ISet<string> KnownTypes = new HashSet<string>(StringComparer.Ordinal)
//     {
//         "Json",
//     };

//     private static readonly ISet<string> KnownErrorTypes = new HashSet<string>(
//         StringComparer.Ordinal
//     )
//     {
//         "BenchError",
//         "Failure",
//         "InspectError",
//         "SnapshotError",
//     };

//     public static bool IsKnownType(string typeName) => KnownTypes.Contains(typeName);

//     public static bool IsKnownErrorType(string typeName) => KnownErrorTypes.Contains(typeName);

//     public static IEnumerable<string> KnownErrorTypeNames => KnownErrorTypes;

//     public static string UnsupportedMemberMessage(string typeName, string memberName) =>
//         $"official core builtin not implemented: {typeName}::{memberName}";

//     public static string UnsupportedTypeMessage(string typeName) =>
//         $"official core builtin type not implemented: {typeName}";

//     public static string UnsupportedShowMessage(string typeName) =>
//         $"official core builtin not implemented: {typeName}::Show";
// }
