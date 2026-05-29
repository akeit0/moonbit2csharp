# VNext Architecture

VNext is the new compiler-shaped path for MoonBit to C#. It is intentionally separate from the legacy frontend/backend compatibility surface. The boundary is typed semantic IR emitted by MoonBit and consumed by a Roslyn backend.

## Package Layout

- `moonbit/src/vnext/syntax`: current subset parser. It produces syntax AST only.
- `moonbit/src/vnext/ast`: syntax-shaped AST records.
- `moonbit/src/vnext/package`: `moon.pkg` import parsing for package aliases and imported source inputs.
- `moonbit/src/vnext/binding`: shared symbol, type, declaration, and binding records.
- `moonbit/src/vnext/semantic_core`: syntax-independent compiler facts: declaration index, selected callables, type conversion classification, type inference substitutions, executable IR validation, and resolved-type helpers.
- `moonbit/src/vnext/sema`: syntax adapter plus binder. It lowers AST into resolved typed IR by using `semantic_core`.
- `moonbit/src/vnext/ir`: executable semantic IR model.
- `moonbit/src/vnext/json`: versioned JSON writer for vnext semantic IR.
- `moonbit/src/vnext/pipeline`: file/package source entrypoints used by tests and CLI.
- `moonbit/src/vnext_cli`: MoonBit CLI for `.mbt -> .json`.
- `csharp/MoonBit2CSharp.VNext.Backend`: Roslyn backend for vnext semantic IR.
- `csharp/MoonBit2CSharp.Tests`: vnext backend tests. Keep these separate from legacy backend tests.

## Pipeline

1. Discover package context outside semantic typing. `moon.pkg` resolves package
   aliases and imported source inputs; source-level `using` will decide which
   imported declarations enter lexical lookup.
2. Lex/parse MoonBit source into vnext AST.
3. Build declaration indexes before body typing:
   - local package type/function/global headers;
   - imported package declarations, not only imported type definitions;
   - full local struct and enum definitions;
   - function signatures and default-argument declarations.
4. Bind function/global bodies with a `TypingContext`.
5. Validate executable IR before JSON emission.
6. Emit JSON matching `docs/vnext-typed-ir.schema.json`.
7. Emit C# from JSON with Roslyn.

The C# backend must not parse MoonBit syntax or infer source-language facts from strings. If the backend needs a fact, the MoonBit frontend must put it in typed IR.

## External C# Bodies

MoonBit `extern "csharp" fn ... = #|...` declarations are emitted as function
IR with an explicit `external` fact:

```json
{
  "kind": "Function",
  "external": { "target": "csharp", "body": "return 42;" }
}
```

The parser normalizes `#|` raw-body lines before JSON emission, so the backend
receives C# statements rather than MoonBit raw-string syntax. The declaration
still contributes its normal function signature to the declaration index, and
calls resolve to the same stable function id as ordinary functions.

Executable IR validation checks the external target and does not type-check the
placeholder `body` expression for external declarations. The Roslyn backend may
parse the C# statement body because the target is explicitly `csharp`; it must
not discover extern bodies by scanning source text or function names.

## Identity And Packages

VNext symbol identity must be stable at package level. Display names are not
semantic identity and must not be parsed by the backend.

Target ID forms:

- package: `pkg:<canonical-package-id>`;
- module: `mod:<package-id>:<module-path>`;
- type: `type:<package-id>:<module-path>:<name>`;
- function: `fn:<package-id>:<module-path>:<name>`;
- global: `global:<package-id>:<module-path>:<name>`;
- parameter: `param:<function-id>:<name>`;
- local: `local:<function-id>:<scope-or-span>:<name>`;
- field: `field:<type-id>:<name>`;
- enum variant: `variant:<type-id>:<name>`.

MoonBit currently does not allow same-identifier function overloads, so VNext
must not invent overload compatibility machinery now. The ID shape should still
leave room for a future signature suffix if the source language changes.

Package compilation should converge on a `CompilationIndex` / `PackageIndex`
shape rather than passing arrays of imported types:

```text
CompilationIndex
  local package
    module declarations
  imported packages
    alias -> package id
    exported types/functions/globals/traits/impls
  lexical using scope
    unqualified imported names for this module
```

`moon.pkg` package aliases and source-level `using @pkg{...}` are separate
layers. A package being available does not mean all of its declarations are in
unqualified lookup.

## Type Model

`TypeRef` is the current semantic type carrier. It supports:

- builtin scalar types such as `Int`, `Float`, `String`, `StringView`;
- builtin type constructors such as `Array[T]`, `FixedArray[T]`, `ArrayView[T]`,
  and `Option[T]` including MoonBit `T?` syntax sugar;
- declared nominal types with package/module symbols;
- type parameters;
- tuples;
- function types with effect;
- trait objects;
- unknown/error types for diagnostics and inference.

VNext should keep moving toward canonical resolved types in `semantic_core/resolved_type.mbt`. Do not add new backend checks for MoonBit package/member strings.

## Typing Context

`TypingContext` owns inference substitutions for a body-typing operation. It is small by design:

- inference variables are represented as internal `TypeRef::Unknown` reasons with controlled prefixes;
- type parameters are solved through substitution instead of ad-hoc per-call branches;
- local lazy typing uses the same substitution path as generic call inference;
- expected type flow is explicit at expression binding sites;
- implicit conversions are applied only after inference has tried to unify expected and actual types.

This is the intended replacement for expression-local guesses such as "if this local value is a struct literal, look at the enclosing return type."

`if` expression typing treats terminal control-transfer branches as non-value
branches. A branch that is `return`, `break`, or `continue` does not force the
other branch to `Unit`; the expression type is taken from the non-terminal
branch, or from the expected type when both branches transfer control.

## Callable Selection

Calls resolve through selected callable data, not direct string lowering. The current vnext slice supports:

- top-level function lookup by declaration index;
- arity filtering;
- generic function type-parameter inference from arguments;
- expected return type participation in inference;
- selected instantiated parameter and return types;
- conversion-aware argument/result compatibility.

The same path should grow to cover package-qualified functions, methods, operators, callable values, trait methods, and effect evidence. Do not add separate semantic shortcuts for each call syntax.

Candidate checking must be diagnostic-free. Rejected candidates are normal
compiler work and must not push diagnostics into `BindingContext`. Callable
selection should produce an argument plan with reordered arguments, type
arguments, conversions, and trait/effect evidence. Diagnostics are emitted only
after selection determines that there is no candidate, an ambiguity, or a
selected callable whose arguments fail final checking.

Operators are not a flat string-to-function table. They are syntax keys that map
to trait method requirements, similar to rustc's operator-overload lowering into
lang-item trait obligations. VNext models the key with arity and family:

- unary arithmetic: `-x -> Neg.neg(Self) -> Self`;
- binary arithmetic: `+ - * / % -> Add/Sub/Mul/Div/Mod`;
- bitwise/shift: `& | ^ << >> -> BitAnd/BitOr/BitXOr/Shl/Shr`;
- equality: `== != -> Eq.equal/Eq.not_equal -> Bool`;
- comparison: `< > <= >= -> Compare.op_lt/op_gt/op_le/op_ge -> Bool`.

The declaration index owns derived operator impl entries keyed by
`(OperatorKey, self_type)`. Duplicate entries are rejected while indexing impls;
expression binding should receive either one concrete candidate or none. It must
not scan aliases or reconstruct trait evidence from selected function ids.

Core builtin operators are normal trait impl declarations whose method bodies
may be intrinsic symbols, such as `%i32_add` or `%f64_add`. VNext stores that
intrinsic identity on the impl method body and carries it with the selected
operator candidate. The C# backend may use its intrinsic catalog to emit Roslyn,
but it should receive the intrinsic name from typed IR rather than deriving it
from `+`, `Int`, or a function display name.

The current vnext seed for core operator impls is temporary source-shaped input.
The long-term path is to feed real `moonbitlang/core/builtin/intrinsics.mbt`
declarations into package context and let the normal impl indexer build the same
facts. Do not grow a parallel handwritten builtin operator database.

Custom alias indexers are resolved through the same callable-selection path.
`#alias("_[_]")` and `#alias("_[_]=_")` attach alias facts to function
signatures during declaration collection. Index get/set binding first uses
builtin array-like semantics when the receiver type is known to be
`Array[T]`, `FixedArray[T]`, or `ArrayView[T]`; otherwise it selects an aliased
callable and emits a normal `Call` IR node. The backend must never infer custom
indexers from C# member names.

## Optional Values And Parameters

MoonBit `T?` lowers to builtin `Option[T]`. `Some(value)` and `None` are semantic option expressions in IR, not ordinary unresolved calls or names.

MoonBit `a? : T` is a labelled optional parameter. Without a default, its in-body symbol has type `Option[T]`; omitted calls lower an explicit `OptionNone`, and supplied calls lower `OptionSome(value)`.

MoonBit `a? : T = default_expr` is still labelled and omittable, but the in-body symbol has type `T`. VNext lowers omitted calls by binding `default_expr` at each call site. The backend must not turn this into a C# optional parameter default, because MoonBit evaluates the default expression each time it is used and preserves side effects.

MoonBit `a~ : T` is a required labelled parameter. Calls support both explicit labels such as `f(a=1)` and shorthand labels such as `f(a~)`. VNext records parameter labels in IR and reorders labelled call arguments by parameter order before backend emission.

Default expressions are declaration facts, not AST rescans. Function signature
collection should attach a `default_ref` to each parameter that has a default,
and the declaration index should own the default expression table. Omitted calls
bind the referenced default expression in the call-site typing context.

## Implicit Conversions

Implicit conversions are semantic IR nodes:

- `String -> StringView`;
- `Array[T] -> ArrayView[T]`;
- `FixedArray[T] -> ArrayView[T]`.

The backend currently emits these as runtime-supported no-op expressions where the runtime exposes implicit conversions. Conversion choice belongs to MoonBit semantic typing, not C# emission.

## Structs And Packages

Struct declarations carry stable type symbols and field definitions. Struct literals carry:

- `typeId`;
- field `name`;
- bound field `value`.

Field IDs are intentionally not repeated inside struct literal field values; `typeId` plus the type definition is enough. Tuple field names should use `"0"`, `"1"`, and so on when tuple literal/object support lands.

Package aliases from `moon.pkg` resolve to imported package IDs before type binding. Imported declared types should enter the declaration index as data.

Mutable field access is represented explicitly in IR:

- `FieldAccess(target, field_ref)` reads a declared struct field after semantic field lookup;
- `FieldAssign(target, field_ref, value)` writes only fields marked `mutable`;
- `Sequence(first, body)` preserves block ordering for side-effecting expressions and returns the body type.

`field_ref` should carry owner type id, field id, display name, mutable flag,
and resolved field type. Struct literal field values stay name-only because
`typeId` plus the type definition is enough for construction ordering and
validation.

If a struct has any mutable field, the vnext backend emits it as a reference type, matching the long-term aliasing policy used by the main backend. This is required for default-argument expressions such as `{val: 0}` to allocate a fresh object at each omitted call site while named defaults can intentionally share an outer value.

Generic receiver field typing substitutes declared type arguments before
producing `FieldRef`. For example, `Box[Int].value` resolves the field type from
`T` to `Int` in the frontend. Declared local types also win over same-name
builtin constructors during type resolution, so user declarations such as
`struct Map[K, V]` are not silently rebound to the builtin `Map` constructor.

## Enums

Enum declarations are nominal type definitions with stable variant ids. The
frontend resolves both qualified and expected-type-driven variants:

- `Relation::Smaller`;
- `@pkg.Relation::Smaller`;
- `Smaller` when the expected type is `Relation`;
- `Cons(1, Nil)` when the expected type is the payload enum.

All-constant enums may be emitted as C# `enum`. Payload enums are emitted as an
object-shaped discriminated union. Pattern tests and `match` must consume
resolved enum variant ids; the backend must not infer variants from display
strings.

## Control Flow

VNext models statement-like MoonBit control forms as typed expressions:

- `Return(value?)` has node type `Unit` and carries the function return value as
  an optional typed expression.
- `Break(value?)` has node type `Unit`; a value contributes the enclosing
  functional loop result type.
- `Continue(args)` has node type `Unit`; arguments update functional loop state
  variables by binding order.
- `ForLoop` carries loop bindings, optional condition, explicit update
  expressions, body, and the expression result type inferred from valued
  `break`.
- `ForRange` is a `Unit` expression with resolved range flags.
- `ForIn` carries optional index symbol, value symbol, resolved iterator
  expression, and
  `Unit` body.

The backend may lower these to C# statements, but only from explicit IR facts.
Functional loop result lowering uses a frontend-provided loop type and emits a
temporary destination for valued `break`; `continue` arguments assign state
variables before the C# `continue`.

`ForIn` is resolved through iterator semantics, not array-shape checks. The
frontend accepts an expression whose type is already `Iter[T]`; otherwise it
binds a normal receiver call to `iter()` and requires the result type to be
`Iter[T]`. Core iterable declarations such as `Array::iter`,
`FixedArray::iter`, `ArrayView::iter`, `StringView::iter`, `String::iter`, and
`String::split` are declaration-index facts. The backend lowers the resolved
iterator expression to a `Next()` loop and must not rediscover source collection
semantics from `Array`, `String`, or member names.

## Type Inference

`TypingContext` substitutions require an occurs check before broadening generic,
array, tuple, function, and enum-payload inference. A substitution such as
`T := Array[T]` must fail instead of creating an infinite resolved type.

Expression typing should move toward internal bidirectional APIs:

```text
infer_expr(expr) -> typed expression + actual type
check_expr(expr, expected) -> typed expression
```

Local lazy typing should be implemented with local inference variables and
constraints, not with expression-specific guesses. This preserves contextual
typing for struct/enum literals while allowing simple bottom-up locals such as
`let x = 1; x + x`.

## Traits

Traits are declaration-index facts, not backend naming conventions. A trait
declaration contributes a stable trait symbol plus method signatures. A type
parameter bound such as `fn[T : Animal]` is emitted on the function type
parameter as a constraint list, and `&Animal` resolves to a `TraitObject`
`TypeRef` carrying the resolved trait symbol.

The C# vnext backend follows the main backend shape for custom traits:

- `AnimalObject` stores `Self` and an object-safe `IAnimalImpl`;
- `IAnimalImpl<T, TImpl>` carries static abstract trait methods for generic
  constraint calls;
- `AnimalTrait` is the static dispatcher surface;
- `AnimalImplObject<T, TImpl>` adapts static impl evidence to trait objects.

Trait method calls lower to `TraitMethodCall` with the resolved trait symbol,
method id, receiver, already-bound arguments, and an explicit dispatch kind.
`TraitObject` dispatch calls the object vtable. `TypeParamBound` dispatch calls
the static trait dispatcher with the frontend-provided implementation type
parameter. `ConcreteImpl` dispatch carries the resolved implementation function
id and optional selected intrinsic, so concrete receiver calls do not require the
backend to rediscover trait evidence from names. The backend must not infer
impls by parsing trait, package, or method display strings.

## Backend Contract

The vnext backend consumes only JSON semantic IR:

- every emitted expression has a type;
- top-level `traits` carries resolved trait declarations;
- function declarations include typed `typeParams` objects with constraint
  lists;
- generic C# methods and trait constraints are emitted from function
  `typeParams`;
- `TraitObject` maps to the resolved trait object wrapper shape;
- `FixedArray[T]` maps to `T[]`;
- `Array[T]` maps to `MoonBitArray<T>`;
- `ArrayView[T]` maps to `MoonBitArrayView<T>`;
- `Option[T]` maps to `MoonBitOption<T>`;
- `Unit` maps to `MoonBitUnit`;
- `StringView` maps to `MoonBitStringView`;
- `FieldAccess`/`FieldAssign` carry resolved `FieldRef`;
- builtin `IndexGet`/`IndexAssign` are only for builtin array-like receivers;
- custom alias indexers arrive as ordinary resolved `Call` expressions;
- `ForIn`, `ForRange`, `ForLoop`, `Return`, `Break`, and `Continue` are
  statement-lowered from typed IR nodes.

When the JSON shape changes, update `docs/vnext-typed-ir.schema.json`, MoonBit IR/writer code, C# reader/emitter behavior, and vnext tests together.

## Executable IR Validation

Validation is a frontend/backend contract gate. It should reject executable IR
that requires backend guessing:

- symbol ids must use package-stable forms;
- expression nodes must not carry unresolved/error types unless diagnostics make
  the module non-executable;
- field access target type must be a declared struct and the field must exist;
- field assignment target field must exist, be mutable, and accept the assigned
  value type;
- struct literals must reference declared struct types and known fields;
- enum cases must reference declared enum types and known variants;
- `ForIn` body and expression type must be `Unit`;
- loop control nodes must have node type `Unit` even when they carry values;
- `Return` value must match the current function return type;
- selected calls must match the argument plan;
- conversion node kind must match source and target types.

Diagnostics JSON must include spans with at least file, start, and end offsets.
Line and column are useful but secondary.

## Near-Term Refactor Order

1. Replace imported-types-only handoff with imported package declarations in the
   declaration index for functions/globals/traits/impls, not just types.
2. Keep reducing resolver scans with indexed lookup tables consumed by real hot
   paths: alias functions, package-qualified declarations, impls, and fields.
3. Add occurs check and start splitting internal infer/check expression typing.
4. Extend callable selection to receiver methods and trait methods without
   growing syntax-specific shortcuts.
5. Feed real `moonbitlang/core/builtin/intrinsics.mbt` declarations into the
   package context and remove the temporary core-operator seed.
6. Broaden syntax coverage around loops, patterns, collection literals, and
   package imports while keeping executable IR validation strict.

## Verification Scope

Keep vnext verification narrow:

```powershell
moon -C moonbit test -p moonbit2csharp/frontend/vnext/semantic_core
moon -C moonbit test -p moonbit2csharp/frontend/vnext/pipeline
dnrelay test csharp\MoonBit2CSharp.Tests\MoonBit2CSharp.Tests.csproj
dnrelay build csharp\MoonBit2CSharp.Emit\MoonBit2CSharp.Emit.csproj
```

Do not run whole-repo `moon check` for a vnext-only edit unless a concrete cross-package boundary changed or the user asks for broad verification.
