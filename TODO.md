# TODO

## Reduce MoonBit override sources

The override sources are now unified under `moonbit/overrides`. The next goal is to replace as many of these files as possible with official `moonbitlang/core` source and keep only true C# backend intrinsics/runtime bridges.

### Blockers

- `extern "csharp"` overrides still encode runtime-specific implementations. Replace these with official MoonBit source plus C# intrinsic lowering/runtime utilities.
- Official `iterator.mbt` / iterable stack is not fully used yet. Support official `Iter` semantics, `size_hint`, closure field calls, and array/arrayview iteration from official source.
- Nullable `Option[T]` ABI is improved, but needs broader confidence before removing `core_option*` overrides.
- Official string/stringview/bytes/bytesview sources need complete intrinsic lowering for view, slice, index, and UTF-8 behavior.
- Numeric and conversion overrides remain because C# backend intrinsic coverage is incomplete for shifts, reinterpret casts, float/double rounding, UInt64 ops, and char/byte conversions.
- `Ref` and `prelude` should come from official core once package import/public-using behavior is fully root-cause correct, instead of C# override package stubs.
- `Map` / linked-hash-map override remains because official collection source still exposes backend/runtime gaps around arrays, hashing, mutation, and generated shape.
- Debug/Repr has only a small bridge left, but removing it needs generated Show/Debug evidence to come entirely from official source.
- `CoreBuiltinImplementationCatalog.json` still names individual override inputs. Replace the large manual list with graph-driven core source selection.

### Immediate cleanup direction

- Prefer official `moonbitlang/core` files whenever the C# backend can lower the required intrinsics.
- Keep override files only when they represent a real backend intrinsic boundary.
- When removing an override, add a small red/green MoonBit sample or vnext pipeline regression that proves the official source path works.
