///|
fn collect_impls(
  context : BindingContext,
  index : DeclarationIndex,
  ast : Module,
) -> Unit {
  for impl_decl in ast.impls {
    collect_impl(context, index, impl_decl)
  }
}

///|
fn collect_impl(
  context : BindingContext,
  index : DeclarationIndex,
  impl_decl : ImplDecl,
) -> Unit {
  if is_default_impl_self_type(impl_decl.self_type) {
    for impl_method in impl_decl.methods {
      match impl_method.intrinsic {
        Some(_) => ()
        None =>
          if impl_method.body is Some(_) {
            @semantic.declare_default_trait_impl_method(
              index,
              impl_decl.trait_name,
              impl_method.name,
              fixed_type_param_constraints(impl_decl.type_params),
              impl_method.span,
            )
          }
      }
    }
    return
  }
  let self_type = resolve_type_with_params(
    context,
    index,
    impl_decl.self_type,
    fixed_type_param_names(impl_decl.type_params),
  )
  if impl_decl.methods.length() == 0 {
    if impl_decl.is_interface {
      ignore(
        @semantic.try_declare_imported_interface_impl_conformance(
          index,
          impl_decl.trait_name,
          self_type,
          impl_decl.span,
        ),
      )
    } else {
      @semantic.declare_impl_conformance(
        index,
        impl_decl.trait_name,
        self_type,
        impl_decl.span,
      )
    }
    return
  }
  for impl_method in impl_decl.methods {
    match impl_method.intrinsic {
      Some(intrinsic) =>
        @semantic.declare_impl_method_with_type_param_constraints(
          index,
          impl_decl.trait_name,
          self_type,
          fixed_type_param_constraints(impl_decl.type_params),
          impl_method.name,
          @semantic.ImplMethodBody::Intrinsic(intrinsic),
          impl_method.span,
        )
      None =>
        @semantic.declare_impl_method_with_type_param_constraints(
          index,
          impl_decl.trait_name,
          self_type,
          fixed_type_param_constraints(impl_decl.type_params),
          impl_method.name,
          if impl_method.body is Some(_) {
            @semantic.ImplMethodBody::Function("")
          } else {
            @semantic.ImplMethodBody::DefaultMethod
          },
          impl_method.span,
        )
    }
  }
}

///|
fn is_default_impl_self_type(self_type : TypeSyntax) -> Bool {
  self_type.package_alias is None &&
  self_type.name == "Self" &&
  self_type.args.length() == 0
}

///|

