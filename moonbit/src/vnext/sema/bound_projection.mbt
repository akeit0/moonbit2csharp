///|
fn bound_traits(
  traits : Array[@semantic.TraitDefinition],
) -> Array[@ir.BoundTrait] {
  let result : Array[@ir.BoundTrait] = []
  for trait_def in traits {
    let methods : Array[@ir.BoundTraitMethod] = []
    for trait_method in trait_def.methods {
      let parameters : Array[TypeRef] = []
      for param in trait_method.parameters {
        parameters.push(param.type_)
      }
      methods.push({
        name: trait_method.name,
        parameters,
        return_type: trait_method.return_type,
        has_default: trait_method.has_default,
        default_function_id: trait_method.default_function_id,
      })
    }
    result.push({ symbol: trait_def.symbol, methods })
  }
  result
}
