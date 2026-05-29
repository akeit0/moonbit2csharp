# MoonBit Pattern Lowering To C\#

This document describes how MoonBit patterns should flow through the frontend IR and how the C# backend should emit them. The goal is to preserve MoonBit semantics while using native C# pattern syntax whenever it gives clearer and smaller generated code.

## Pipeline Shape

MoonBit pattern syntax should be lowered once into typed IR pattern nodes. The C# backend should not parse MoonBit source text.

Preferred flow:

1. MoonBit syntax parser creates syntax pattern nodes.
2. Frontend resolves pattern meaning against the target expression type.
3. Frontend emits typed IR patterns such as `Some`, `None`, `Tuple`, `Range`, `Or`, `Enum`, and `Value`.
4. Backend converts typed IR patterns to C# switch patterns or `is` patterns.
5. Backend falls back to explicit `if` conditions and binding statements only when C# cannot express the MoonBit pattern safely.

## Pattern Mapping

| MoonBit pattern | Typed IR shape | Preferred C# |
| --- | --- | --- |
| `_` | `Wildcard` | `_` in switch, `true` in fallback condition |
| `42`, `"x"`, `true` | `Value` / `Literal` | constant pattern, or `object.Equals` fallback |
| `(a, b)` | `Tuple` | tuple pattern such as `(var a, var b)` |
| `p1 \| p2` | `Or` | `p1 or p2` when there are no conflicting bindings |
| `0..<60` | `Range(inclusive: false)` | `>= 0 and < 60` |
| `90..=100` | `Range(inclusive: true)` | `>= 90 and <= 100` |
| `'A'..='Z'` | char range | `>= 65 and <= 90` or readable char literal when the target representation supports it |
| `Some(v)` | `Some(payload: Binding(v))` | `{ IsSome: true, Value: var v }` |
| `Some((a, b))` | `Some(payload: Tuple(Binding(a), Binding(b)))` | `{ IsSome: true, Value: (var a, var b) }` |
| `None` | `None` | default arm for exhaustive `Option` matches, otherwise `{ IsSome: false }` |
| `Ok(v)` | `Ok(payload: Binding(v))` | `{ IsOk: true, Value: var v }` |
| `Err(e)` | `Err(payload: Binding(e))` | `{ IsOk: false, Error: var e }` |
| `Variant(a, b)` | `Enum(payload: Tuple(...))` | `Type.VariantCase(var a, var b)` |
| `Type::Variant` | `Enum` | enum value pattern or equality fallback |
| `[]` | `Array(prefix: [], rest: none, suffix: [])` | exact `Length == 0` check |
| `[c]` | `Array(prefix: [c], rest: none, suffix: [])` | exact `Length == 1` check plus element binding |
| `[a, b, c]` | `Array(prefix: [a,b,c], rest: none, suffix: [])` | exact `Length == 3` check plus element bindings |
| `[a, ..rest, b]` | `Array(prefix: [a], rest: rest, suffix: [b])` | minimum length check plus view binding |
| `[.. "yes", ..]` | `Array` with fixed spread segment | sequence comparison plus length/view checks |

## `match` Lowering

Use C# `switch` when all arms can be expressed as C# patterns.

MoonBit:

```moonbit
match score {
  0..<60 => "F"
  60..<70 => "D"
  90..=100 => "A"
  _ => "Invalid"
}
```

C# switch expression:

```csharp
score switch
{
    >= 0 and < 60 => "F",
    >= 60 and < 70 => "D",
    >= 90 and <= 100 => "A",
    _ => "Invalid"
}
```

For statement-only arms, use a C# `switch` statement when possible:

```csharp
switch (expr)
{
    case ExpressionSyntax.IntLiteralExprCase(var lit):
    {
        ...
        return MoonBitUnit.Value;
    }
}
```

Fallback to an `if`/`else` chain only when the arm body or pattern cannot be safely represented as a C# switch section, for example when preserving `break` / `continue` behavior in a surrounding MoonBit loop requires the older control-flow shape.

### Match Arm Guards

MoonBit match arms may include a boolean guard after the pattern:

```moonbit
match s.get_char(i) {
  Some(b) if self.chars[self.pos + i] == b => continue
  _ => return false
}
```

Typed IR represents this as an optional `guard` expression on the match arm. The guard is not part of the pattern. It is evaluated only after the pattern condition succeeds and after pattern bindings have been introduced.

Preferred fallback C# shape:

```csharp
var __match = String__get_char(s, i);
if (__match.IsSome)
{
    var b = __match.Value;
    if (self.chars[self.pos + i] == b)
    {
        continue;
    }
    else
    {
        return false;
    }
}
else
{
    return false;
}
```

Guarded arms generally should not use C# switch expressions, because pattern variables must be available to the guard and statement-only MoonBit bodies such as `continue` / `break` must preserve the surrounding control-flow target. If a future backend uses C# switch guards (`when`), it must prove the body and binding shape are valid in C# for that context.

## `Option` Special Case

`Option` is represented by a runtime value with `IsSome`, `IsNone`, and `Value`.

For exhaustive `Option` matches containing exactly one `Some` arm and one `None` arm, emit `None` as the C# default arm. This avoids generating an extra non-exhaustive throw and lets C# treat the switch as complete.

MoonBit:

```moonbit
match value {
  Some(v) => v
  None => 0
}
```

C#:

```csharp
value switch
{
    { IsSome: true, Value: var v } => v,
    _ => 0
}
```

The frontend still accepts legacy `binding`/`bindings` fields in IR for existing fixtures, but newly parsed constructor payloads are represented as nested `payload` patterns. The backend uses binding C# patterns for switch expressions and a condition-plus-binding-statement split for `if`/`else` lowering so repeated names in sibling arms do not violate C# pattern variable scope rules.

When a C# pattern condition already binds a variable, the backend must not emit a second `var` declaration for the same binding inside the arm body. This matters for tuple-wrapped enum patterns such as `(Ordered(_, d), _)`, where C# can bind `d` in the tuple pattern. For patterns that cannot bind in the condition, the backend emits ordered binding statements before the guard/body.

If the MoonBit source writes `None` before `Some`, the backend may reorder these two arms for C# emission because the patterns are disjoint and exhaustive:

```moonbit
match value {
  None => 0
  Some(v) => v
}
```

Preferred C#:

```csharp
value switch
{
    { IsSome: true, Value: var v } => v,
    _ => 0
}
```

Do not use default for `None` in non-exhaustive `Option` matches. In that case, keep `{ IsSome: false }` and preserve the backend's non-exhaustive behavior.

## `guard` Lowering

MoonBit `guard` continues when the condition or pattern matches, otherwise it evaluates the `else` body.

MoonBit:

```moonbit
guard resource is PlainText(text) else { "not text" }
text
```

C#:

```csharp
if (resource is not Resource.PlainTextCase { Item1: var text })
{
    return "not text";
}

return text;
```

For simple boolean guards:

```moonbit
guard index >= 0 && index < array.length() else { None }
```

C#:

```csharp
if (!(index >= 0 && index < array.Length))
{
    return MoonBitOption<int>.None();
}
```

For pattern guards with additional boolean checks, keep a single C# condition when definite assignment allows it:

```csharp
if (value is not { IsSome: true, Value: var text } || text.Length == 0)
{
    return fallback;
}
```

When C# definite-assignment rules do not allow a compact condition, split the guard into a pattern check followed by normal checks. Do not duplicate the MoonBit `else` body unless there is no safe alternative.

When a MoonBit `guard` has no `else`, the frontend lowers the else branch to a panic-shaped IR node. This models MoonBit's terminating behavior for failed no-else guards:

```moonbit
guard condition
```

is equivalent for lowering purposes to:

```moonbit
guard condition else { panic() }
```

Generated C# should emit `throw new MoonBitPanic()` on the failed path. The catchability rules for this panic path belong to [error-handling.md](error-handling.md).

## `is` Expression Lowering

MoonBit `expr is Pattern` should use the same pattern conversion as `match` and `guard`.

Preferred C#:

```csharp
value is { IsSome: true, Value: var x }
resource is Resource.PlainTextCase { Item1: var text }
codepoint is >= 0x0000 and <= 0xD7FF or >= 0xE000 and <= 0x10FFFF
```

If the pattern binds variables and the expression is used where bindings cannot escape, emit a plain boolean pattern test. If later statements need the binding, lower through guard-style statement code instead.

## Array Patterns

MoonBit array patterns apply to array-like and view-like values:

| MoonBit target type | Element type | Rest/view binding type |
| --- | --- | --- |
| `Array[T]` | `T` | `ArrayView[T]` |
| `ArrayView[T]` | `T` | `ArrayView[T]` |
| `FixedArray[T]` | `T` | `ArrayView[T]` |
| `Bytes` | `Byte` | `BytesView` |
| `BytesView` | `Byte` | `BytesView` |
| `String` | `Char` | `StringView` |
| `StringView` | `Char` | `StringView` |

The frontend should emit a structured pattern node rather than encoding this in strings:

```json
{
  "kind": "Array",
  "prefix": [ ... ],
  "restBinding": { "symbol": ..., "type": ... },
  "suffix": [ ... ],
  "fixedSpreads": [ ... ]
}
```

Exact field names can change with the schema update, but the important contract is:

- prefix patterns match from the start;
- suffix patterns match from the end;
- without an unbounded `..`, the total prefix plus suffix length is an exact length check;
- with an unbounded `..`, the total prefix plus suffix length is a minimum length check;
- `restBinding` receives the middle view and may be absent for `[..]`;
- fixed spreads such as `.. "yes"` or `.. NO` are exact sequence segments, not unbounded rest matches;
- the resolved target type decides element access and view creation.

C# list patterns are useful for simple shapes, but they are not enough for the full MoonBit semantics. Native C# can express simple array/list patterns such as:

```csharp
array is [var a, var b, var c]
array is [var a, .., var b]
```

However, the backend should prefer explicit helper lowering when the pattern:

- binds `rest`, because MoonBit needs an `ArrayView[T]`, `BytesView`, or `StringView`, not a copied array;
- targets `String`/`StringView`, because MoonBit `Char` is a Unicode scalar value and string matching must be code-point aware rather than UTF-16-code-unit based;
- targets `Bytes`/`BytesView`, because byte views need their own runtime representation;
- contains nested patterns that need additional bindings or nontrivial checks;
- contains fixed spread segments such as `[.. "yes", ..]`.

Preferred statement fallback shape:

```moonbit
guard ary is [c] else { fail("") }
```

```csharp
var __mbt_array = ary;
if (__mbt_array.Length != 1)
{
    return MoonBitControl.Fail<...>("");
}

var c = __mbt_array[0];
```

```moonbit
guard ary is [a, b, ..rest] else { fail("") }
```

```csharp
var __mbt_array = ary;
if (__mbt_array.Length < 2)
{
    return MoonBitControl.Fail<...>("");
}

var a = __mbt_array[0];
var b = __mbt_array[1];
var rest = __mbt_array.View(2, __mbt_array.Length);
```

For suffix patterns:

```moonbit
guard ary is [.., a, b] else { fail("") }
```

```csharp
var __mbt_array = ary;
if (__mbt_array.Length < 2)
{
    return MoonBitControl.Fail<...>("");
}

var a = __mbt_array[__mbt_array.Length - 2];
var b = __mbt_array[__mbt_array.Length - 1];
```

For `match`, each arm should evaluate the target once, then use a shared condition/binding builder:

```csharp
var __mbt_match = value;
if (/* arm 1 array-pattern condition */)
{
    /* arm 1 bindings */
    ...
}
else if (/* arm 2 condition */)
{
    ...
}
```

Use C# `switch` only for array patterns that can be expressed without changing MoonBit view semantics. In practice, that means exact-length patterns with no rest binding and no string/bytes target are the first safe candidates.

### String Array Patterns

MoonBit string array patterns operate on `Char` elements and must respect Unicode scalar boundaries. The backend should not lower them to `string[index]` or C# list patterns over `string`, because those operate on UTF-16 code units.

Preferred runtime surface:

```csharp
MoonBitStringView view = value.View();
int length = view.CharLength;
int first = view.CharAt(0);
MoonBitStringView rest = view.CharSlice(1, length - 1);
```

The exact helper names can change, but the runtime needs code-point indexing and slicing. This also keeps palindrome-style loops faithful:

```moonbit
match view {
  [] | [_] => break true
  [a, ..rest, b] => if a == b { continue rest } else { break false }
}
```

### Fixed Spread Segments

Consecutive char or byte constants may be written as fixed spread segments:

```moonbit
[.. "yes", ..]
[.. NO, ..]
```

These are exact sequence matches. They should lower to sequence comparison over the target's element representation:

- string/string view: compare Unicode scalar sequence for string literal segments;
- bytes/bytes view: compare byte sequence for bytes constants;
- array/fixed array/array view: compare element values using the resolved `Eq` implementation when required.

Do not model these fixed spreads as a second unbounded `..`. MoonBit allows multiple fixed spreads because their lengths are known; the one-unbounded-rest rule still applies to the true rest pattern.

### Bitstring Patterns

Bitstring patterns are array-pattern segments over byte containers:

```moonbit
[u1be(flag), u3be(kind), u4be(version), u8be(length), ..]
[u4be(0b1111), u4be(tag), ..]
[i1be(value), ..]
```

Lower them as `Array` pattern segments with explicit metadata:

```json
{ "kind": "BitField", "signed": false, "endian": "be", "width": 4, "binding": { "...": "..." } }
{ "kind": "BitField", "signed": false, "endian": "be", "width": 4, "value": { "kind": "IntLiteral", "value": 15, "...": "..." } }
```

When any bit field is present, the array-pattern condition uses bit offsets:

```csharp
value.Length * 8 >= requiredBits
(uint)MoonBitBitString.ExtractUnsigned(value, bitOffset, width, littleEndian)
```

Signed fields use two's-complement conversion through `ExtractSigned`. Result types follow MoonBit's width rule: unsigned `1..32` bits bind as `UInt`, signed `1..32` bits bind as `Int`, unsigned `33..64` bits bind as `UInt64`, and signed `33..64` bits bind as `Int64`.

Little-endian lowering must reject non-byte-aligned widths. The current runtime helper enforces that invariant; the frontend should eventually diagnose it earlier when the parser/typechecker has proper diagnostics.

## Ranges

MoonBit ranges are half-open or closed depending on the operator:

| MoonBit | Meaning | C# pattern |
| --- | --- | --- |
| `a..<b` | `a <= x < b` | `>= a and < b` |
| `a..=b` / `a..<=b` | `a <= x <= b` | `>= a and <= b` |

For non-switch fallback conditions:

```csharp
x >= a && x < b
x >= a && x <= b
```

Char ranges should compare the chosen C# representation consistently. The current backend represents MoonBit `Char` as an `int` Unicode scalar value, so range bounds can be emitted as integer scalar values while comments or readable literal rendering may be used where it improves generated code.

## Exhaustiveness And Throws

The frontend should keep enough type information in IR for the backend to know when a match is statically exhaustive.

Backend policy:

- Wildcard arm makes a match exhaustive.
- `Option` is exhaustive when it has both `Some` and `None`.
- `Result` is exhaustive when it has both `Ok` and `Err`.
- Constant enums can become exhaustive when all variants are covered.
- Payload enums should become exhaustive when all variants are covered, even if some variants bind payloads.

Only generate `throw new InvalidOperationException("non-exhaustive MoonBit match")` when the match is not known to be exhaustive. Do not generate a throw after an exhaustive `Option` switch where `None` is emitted as default.

## Long-Term Implementation Shape

Payload-carrying patterns should not encode nested shape in binding names. The backend still accepts compatibility-shaped bindings for older fixtures, but newly parsed constructor patterns use recursive payload IR:

```json
{ "kind": "Some", "payload": { "kind": "Tuple", "items": [ ... ] } }
{ "kind": "Ok", "payload": { "kind": "Binding", "binding": { ... } } }
{ "kind": "Err", "payload": { "kind": "Literal", "value": { ... } } }
{ "kind": "Enum", "enumName": "List", "variantName": "Cons", "payload": { "kind": "Tuple", "items": [ ... ] } }
```

`match`, `guard`, and `is` should all call the same backend pattern compiler, which returns:

1. a side-effect-free condition over a single evaluated target;
2. ordered binding statements for variables introduced by the pattern;
3. a flag indicating whether the pattern can be emitted as a native C# switch/is pattern without changing MoonBit view, binding, or exhaustiveness semantics.

That shared compiler is the boundary between typed MoonBit pattern semantics and C# syntax choices. It should be driven by resolved enum/option/result/array metadata, not source text or display names.

## Current Gaps

- Match-arm guards are implemented for the condition-plus-binding fallback path and are represented in typed IR. The remaining work is broader native C# `when` emission where it is actually better, not required for correctness.
- Deeper recursive enum payload destructuring is still limited.
- Compatibility binding-name encodings are still accepted and should be retired once remaining fixtures and frontend paths produce recursive payload IR consistently.
- Array patterns now have typed IR nodes, but they still need broader syntax/frontend coverage and one shared backend condition/binding path for `match`, `guard`, and `is`.
- Or-patterns with bindings need stricter checks before using C# `or` patterns, especially when a guard references a binding common to every alternative.
- Exhaustiveness for all enum variants should be driven by resolved enum metadata, not by local pattern inspection alone.
- Guard lowering should keep moving toward one shared pattern conversion path with `match`, match-arm guards, and `is`.
- Unsupported pattern forms should continue lowering to explicit `Unsupported` IR until they are implemented; do not reintroduce placeholder value types or runtime `fail` fallbacks.
