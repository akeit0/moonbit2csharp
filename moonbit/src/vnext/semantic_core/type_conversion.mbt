///|
pub(all) enum ConversionKind {
  Identity
  StringToStringView
  ArrayToArrayView
  FixedArrayToArrayView
  ConcreteToTraitObject
  Incompatible
} derive(Eq, Debug)

///|
pub fn classify_conversion(
  expected : TypeRef,
  actual : TypeRef,
) -> ConversionKind {
  classify_resolved_conversion(
    resolved_type_from_type_ref(expected),
    resolved_type_from_type_ref(actual),
  )
}

///|
pub fn classify_conversion_with_inference(
  context : TypingContext,
  expected : TypeRef,
  actual : TypeRef,
) -> ConversionKind {
  let expected = resolve_inferred_type(context, expected)
  let actual = resolve_inferred_type(context, actual)
  match @binding.type_constructor_name(expected) {
    Some(("ArrayView", [item])) =>
      if unresolved_inference_type(actual) {
        if unify_types(context, actual, @binding.array_type(item)) {
          return ConversionKind::ArrayToArrayView
        }
      }
    _ => ()
  }
  if unify_types(context, expected, actual) {
    return ConversionKind::Identity
  }
  match (expected, actual) {
    (TypeRef::TraitObject(_), _) => ConversionKind::ConcreteToTraitObject
    (TypeRef::Builtin("StringView"), TypeRef::Builtin("String")) =>
      ConversionKind::StringToStringView
    _ =>
      match
        (
          @binding.type_constructor_name(expected),
          @binding.type_constructor_name(actual),
        ) {
        (Some(("ArrayView", [expected_item])), Some(("Array", [actual_item]))) =>
          if unify_types(context, expected_item, actual_item) {
            ConversionKind::ArrayToArrayView
          } else {
            ConversionKind::Incompatible
          }
        (
          Some(("ArrayView", [expected_item])),
          Some(("FixedArray", [actual_item])),
        ) =>
          if unify_types(context, expected_item, actual_item) {
            ConversionKind::FixedArrayToArrayView
          } else {
            ConversionKind::Incompatible
          }
        _ => classify_conversion(expected, actual)
      }
  }
}

///|
pub fn classify_resolved_conversion(
  expected : ResolvedType,
  actual : ResolvedType,
) -> ConversionKind {
  if resolved_type_equal(expected, actual) {
    ConversionKind::Identity
  } else {
    match (expected, actual) {
      (ResolvedType::Builtin("UInt16"), ResolvedType::Builtin("Char"))
      | (ResolvedType::Builtin("Char"), ResolvedType::Builtin("UInt16")) =>
        ConversionKind::Identity
      (ResolvedType::Builtin("StringView"), ResolvedType::Builtin("String")) =>
        ConversionKind::StringToStringView
      (ResolvedType::ArrayView(expected_item), ResolvedType::Array(actual_item)) =>
        if resolved_type_equal(expected_item, actual_item) {
          ConversionKind::ArrayToArrayView
        } else {
          ConversionKind::Incompatible
        }
      (
        ResolvedType::ArrayView(expected_item),
        ResolvedType::FixedArray(actual_item),
      ) =>
        if resolved_type_equal(expected_item, actual_item) {
          ConversionKind::FixedArrayToArrayView
        } else {
          ConversionKind::Incompatible
        }
      (ResolvedType::TraitObject(_), _) => ConversionKind::ConcreteToTraitObject
      _ => ConversionKind::Incompatible
    }
  }
}

///|
pub fn conversion_kind_text(kind : ConversionKind) -> String {
  match kind {
    Identity => "Identity"
    StringToStringView => "StringToStringView"
    ArrayToArrayView => "ArrayToArrayView"
    FixedArrayToArrayView => "FixedArrayToArrayView"
    ConcreteToTraitObject => "ConcreteToTraitObject"
    Incompatible => "Incompatible"
  }
}
