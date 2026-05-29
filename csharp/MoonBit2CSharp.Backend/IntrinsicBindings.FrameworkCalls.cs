namespace MoonBit2CSharp.Backend;

public static partial class IntrinsicBindings
{
    private static IEnumerable<IntrinsicBinding> FrameworkCallBindings()
    {
        return IntrinsicImplementationCatalog
            .BindingSpecs.Where(binding =>
                IntrinsicImplementationCatalog.MetadataFor(binding.ExternalName).Mode
                == "FrameworkCall"
            )
            .Select(CreateDeclarativeBinding);
    }
}
