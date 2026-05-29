using System.Globalization;

namespace MoonBit2CSharp.Backend;

public sealed record ModuleIr(string Name, IReadOnlyList<DeclIr> Decls);

public sealed record SourceSpanIr(
    string? File,
    int Start,
    int End,
    int StartLine,
    int StartColumn,
    int EndLine,
    int EndColumn
);

public sealed record SymbolIr(string Kind, string Id, string Name);

public abstract record DeclIr;

public sealed record GlobalLetDeclIr(
    SymbolIr Symbol,
    bool Mutable,
    TypeRefIr DeclaredType,
    ExprIr Value
) : DeclIr
{
    public string Id => Symbol.Id;
    public string Name => Symbol.Name;
}

public sealed record TypeParamIr(string Name, IReadOnlyList<string> Constraints);

public sealed record FnDeclIr(
    SymbolIr Symbol,
    IReadOnlyList<TypeParamIr> TypeParams,
    IReadOnlyList<ParamIr> Parameters,
    TypeRefIr ReturnType,
    ExprIr Body,
    bool Raises = false,
    TypeRefIr? ErrorType = null
) : DeclIr
{
    public string Id => Symbol.Id;
    public string Name => Symbol.Name;
}

public sealed record ExternDeclIr(
    SymbolIr Symbol,
    IReadOnlyList<TypeParamIr> TypeParams,
    IReadOnlyList<ParamIr> Parameters,
    TypeRefIr ReturnType,
    string ExternalName,
    bool Raises = false,
    string Language = "intrinsic",
    TypeRefIr? ErrorType = null
) : DeclIr
{
    public string Id => Symbol.Id;
    public string Name => Symbol.Name;
}

public sealed record StructDeclIr(
    SymbolIr Symbol,
    IReadOnlyList<string> TypeParams,
    IReadOnlyList<FieldIr> Fields,
    IReadOnlyList<string> Derives
) : DeclIr
{
    public string Id => Symbol.Id;
    public string Name => Symbol.Name;
}

public sealed record EnumDeclIr(
    SymbolIr Symbol,
    IReadOnlyList<string> TypeParams,
    IReadOnlyList<EnumVariantIr> Variants,
    IReadOnlyList<string> Derives,
    bool IsError = false
) : DeclIr
{
    public string Id => Symbol.Id;
    public string Name => Symbol.Name;
}

public sealed record ExternalTypeDeclIr(
    SymbolIr Symbol,
    IReadOnlyList<string> TypeParams,
    string Language,
    string ExternalName
) : DeclIr
{
    public string Id => Symbol.Id;
    public string Name => Symbol.Name;
}

public sealed record TraitDeclIr(SymbolIr Symbol, IReadOnlyList<TraitMethodIr> Methods) : DeclIr
{
    public string Id => Symbol.Id;
    public string Name => Symbol.Name;
}

public sealed record TraitImplDeclIr(
    SymbolIr ImplSymbol,
    string TraitName,
    TypeRefIr ReceiverType,
    string MethodName,
    SymbolIr FunctionSymbol,
    TypeRefIr ReturnType,
    string ExternalName = "",
    IReadOnlyList<TypeParamIr>? TypeParams = null,
    bool IsDefault = false
) : DeclIr
{
    public string TypeName => ReceiverType.Name;
    public string FunctionName => FunctionSymbol.Name;
    public IReadOnlyList<TypeParamIr> TypeParameters => TypeParams ?? [];
}

public sealed record TraitMethodIr(
    string Name,
    IReadOnlyList<TypeRefIr> ParameterTypes,
    TypeRefIr ReturnType
);

public sealed record EnumVariantIr(
    SymbolIr Symbol,
    IReadOnlyList<string> PayloadNames,
    IReadOnlyList<bool> PayloadMutables,
    IReadOnlyList<TypeRefIr> Payload
)
{
    public string Id => Symbol.Id;
    public string Name => Symbol.Name;
}

public sealed record FieldIr(SymbolIr Symbol, TypeRefIr Type, bool Mutable = false)
{
    public string Id => Symbol.Id;
    public string Name => Symbol.Name;
}

public sealed record ParamIr(SymbolIr Symbol, TypeRefIr Type, ExprIr? DefaultValue = null)
{
    public string Id => Symbol.Id;
    public string Name => Symbol.Name;
}

public sealed record TypeRefIr(
    string Name,
    IReadOnlyList<TypeRefIr>? Elements = null,
    TypeRefIr? Element = null,
    TypeRefIr? Key = null,
    TypeRefIr? Value = null,
    TypeRefIr? Error = null
);

public abstract record ExprIr(TypeRefIr Type);

public sealed record IntLiteralIr(string ValueText, TypeRefIr TypeRef) : ExprIr(TypeRef)
{
    public long Value => long.Parse(ValueText, CultureInfo.InvariantCulture);

    public bool TryGetInt32(out int value)
    {
        return int.TryParse(
            ValueText,
            NumberStyles.Integer,
            CultureInfo.InvariantCulture,
            out value
        );
    }
}

public sealed record DoubleLiteralIr(double Value, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record StringLiteralIr(string Value, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record CharLiteralIr(string Value, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record ByteLiteralIr(string Value, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record BytesLiteralIr(string Value, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record BoolLiteralIr(bool Value, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record SourceLocIr(string Repr, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record ArgsLocIr(IReadOnlyList<string> Items, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record UnsupportedExprIr(
    string Reason,
    TypeRefIr TypeRef,
    SourceSpanIr? SourceSpan = null
) : ExprIr(TypeRef);

public sealed record VarIr(SymbolIr SymbolRef, TypeRefIr TypeRef) : ExprIr(TypeRef)
{
    public string Symbol => SymbolRef.Id;
    public string Name => SymbolRef.Name;
}

public sealed record PackageRefIr(string Package, string PackageId, TypeRefIr TypeRef)
    : ExprIr(TypeRef);

public sealed record PackageValueIr(string Package, string Member, TypeRefIr TypeRef)
    : ExprIr(TypeRef);

public sealed record FunctionRefIr(SymbolIr SymbolRef, TypeRefIr TypeRef) : ExprIr(TypeRef)
{
    public string Symbol => SymbolRef.Id;
    public string Name => SymbolRef.Name;
}

public sealed record StaticTypeRefIr(string TypeName, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record StaticValueIr(
    string TypeName,
    string Member,
    string ExternalName,
    TypeRefIr TypeRef
) : ExprIr(TypeRef);

public sealed record BinaryIr(string Op, ExprIr Left, ExprIr Right, TypeRefIr TypeRef)
    : ExprIr(TypeRef);

public sealed record TraitOperatorCallIr(
    string TraitName,
    SymbolIr? ImplSymbol,
    string MethodName,
    IReadOnlyList<ExprIr> Arguments,
    TypeRefIr TypeRef
) : ExprIr(TypeRef);

public sealed record IsIr(ExprIr Target, IsPatternIr Pattern, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record CallIr(
    CalleeIr Callee,
    IReadOnlyList<ExprIr> Arguments,
    TypeRefIr TypeRef,
    IReadOnlyList<TraitArgumentIr>? TraitArguments = null
) : ExprIr(TypeRef);

public sealed record TraitArgumentIr(
    string TraitName,
    TypeRefIr Type,
    SymbolIr? FunctionSymbol,
    SymbolIr? ImplSymbol
);

public sealed record TraitMethodEvidenceIr(
    string TraitName,
    SymbolIr TraitSymbol,
    string MethodName,
    SymbolIr MethodSymbol,
    SymbolIr? ImplSymbol
);

public sealed record DelegateCallIr(
    ExprIr Target,
    IReadOnlyList<ExprIr> Arguments,
    TypeRefIr TypeRef
) : ExprIr(TypeRef);

public sealed record LambdaIr(
    IReadOnlyList<LambdaParameterIr> Parameters,
    ExprIr Body,
    TypeRefIr TypeRef
) : ExprIr(TypeRef);

public sealed record LambdaParameterIr(SymbolIr SymbolRef, TypeRefIr Type)
{
    public string Symbol => SymbolRef.Id;
    public string Name => SymbolRef.Name;
}

public sealed record LocalFunctionIr(
    SymbolIr Symbol,
    IReadOnlyList<ParamIr> Parameters,
    TypeRefIr ReturnType,
    ExprIr Body,
    TypeRefIr TypeRef
) : ExprIr(TypeRef)
{
    public string Id => Symbol.Id;
    public string Name => Symbol.Name;
}

public sealed record SomeIr(ExprIr Value, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record NoneIr(TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record ResultOkIr(ExprIr Value, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record ResultErrIr(ExprIr Value, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record LetIr(SymbolIr SymbolRef, ExprIr Value, ExprIr Then, TypeRefIr TypeRef)
    : ExprIr(TypeRef)
{
    public string Symbol => SymbolRef.Id;
    public string Name => SymbolRef.Name;
}

public sealed record VarDeclIr(
    SymbolIr SymbolRef,
    bool Mutable,
    TypeRefIr DeclaredType,
    ExprIr Value,
    TypeRefIr TypeRef
) : ExprIr(TypeRef)
{
    public string Symbol => SymbolRef.Id;
    public string Name => SymbolRef.Name;
}

public sealed record AssignIr(SymbolIr SymbolRef, ExprIr Value, TypeRefIr TypeRef) : ExprIr(TypeRef)
{
    public string Symbol => SymbolRef.Id;
    public string Name => SymbolRef.Name;
}

public sealed record FieldAssignIr(ExprIr Target, string Name, ExprIr Value, TypeRefIr TypeRef)
    : ExprIr(TypeRef);

public sealed record IndexAssignIr(ExprIr Target, ExprIr Index, ExprIr Value, TypeRefIr TypeRef)
    : ExprIr(TypeRef);

public sealed record TupleLiteralIr(IReadOnlyList<ExprIr> Items, TypeRefIr TypeRef)
    : ExprIr(TypeRef);

public sealed record TupleGetIr(ExprIr Target, int Index, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record LetTupleIr(
    IReadOnlyList<LetTupleBindingIr> Bindings,
    ExprIr Value,
    TypeRefIr TypeRef
) : ExprIr(TypeRef);

public sealed record LetTupleBindingIr(SymbolIr SymbolRef, TypeRefIr Type)
{
    public string Symbol => SymbolRef.Id;
    public string Name => SymbolRef.Name;
}

public sealed record ArrayLiteralIr(IReadOnlyList<ExprIr> Items, TypeRefIr TypeRef)
    : ExprIr(TypeRef);

public sealed record MapLiteralEntryIr(ExprIr Key, ExprIr Value);

public sealed record MapLiteralIr(IReadOnlyList<MapLiteralEntryIr> Entries, TypeRefIr TypeRef)
    : ExprIr(TypeRef);

public sealed record IndexGetIr(ExprIr Target, ExprIr Index, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record NewStructIr(string Name, IReadOnlyList<ExprIr> Arguments, TypeRefIr TypeRef)
    : ExprIr(TypeRef);

public sealed record RecordUpdateFieldIr(string Name, ExprIr Value);

public sealed record RecordUpdateIr(
    ExprIr Target,
    IReadOnlyList<RecordUpdateFieldIr> Fields,
    TypeRefIr TypeRef
) : ExprIr(TypeRef);

public sealed record EnumCaseIr(
    string EnumName,
    string VariantName,
    IReadOnlyList<ExprIr> Arguments,
    TypeRefIr TypeRef
) : ExprIr(TypeRef);

public sealed record FieldGetIr(ExprIr Target, string Name, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record MemberCallIr(
    ExprIr Target,
    string Name,
    IReadOnlyList<ExprIr> Arguments,
    IReadOnlyList<string?> ArgumentLabels,
    TypeRefIr TypeRef,
    IReadOnlyList<TraitArgumentIr>? TraitArguments = null,
    TraitMethodEvidenceIr? TraitEvidence = null
) : ExprIr(TypeRef);

public sealed record TraitObjectIr(
    string TraitName,
    string SelfType,
    SymbolIr? ImplSymbol,
    ExprIr Self,
    TypeRefIr TypeRef
) : ExprIr(TypeRef);

public sealed record InterpolatedStringIr(
    IReadOnlyList<InterpolatedStringPartIr> Parts,
    TypeRefIr TypeRef
) : ExprIr(TypeRef);

public sealed record InterpolatedStringPartIr(string? Text, ExprIr? Expression);

public sealed record ForRangeIr(
    SymbolIr SymbolRef,
    ExprIr Start,
    ExprIr End,
    bool Inclusive,
    bool Reverse,
    bool ExcludeStart,
    IReadOnlyList<ForLoopBindingIr> Bindings,
    ExprIr Body,
    ExprIr? NoBreak,
    TypeRefIr TypeRef
) : ExprIr(TypeRef)
{
    public string Symbol => SymbolRef.Id;
    public string Name => SymbolRef.Name;
}

public sealed record ForLoopBindingIr(SymbolIr SymbolRef, TypeRefIr Type, ExprIr Initial)
{
    public string Symbol => SymbolRef.Id;
    public string Name => SymbolRef.Name;
}

public sealed record ForLoopUpdateIr(SymbolIr SymbolRef, ExprIr Value)
{
    public string Symbol => SymbolRef.Id;
    public string Name => SymbolRef.Name;
}

public sealed record ForLoopIr(
    IReadOnlyList<ForLoopBindingIr> Bindings,
    ExprIr Condition,
    IReadOnlyList<ForLoopUpdateIr> Updates,
    ExprIr Body,
    TypeRefIr TypeRef
) : ExprIr(TypeRef);

public sealed record FunctionalForIr(
    IReadOnlyList<ForLoopBindingIr> Bindings,
    ExprIr Condition,
    IReadOnlyList<ForLoopUpdateIr> Updates,
    ExprIr Body,
    ExprIr NoBreak,
    TypeRefIr TypeRef
) : ExprIr(TypeRef);

public sealed record WhileIr(
    ExprIr Condition,
    ExprIr Body,
    TypeRefIr TypeRef,
    ExprIr? NoBreak = null
) : ExprIr(TypeRef);

public sealed record ForEachIr(
    SymbolIr? IndexSymbolRef,
    SymbolIr ValueSymbolRef,
    ExprIr Target,
    IReadOnlyList<ForLoopBindingIr> Bindings,
    ExprIr Body,
    ExprIr? NoBreak,
    TypeRefIr TypeRef
) : ExprIr(TypeRef)
{
    public string? IndexSymbol => IndexSymbolRef?.Id;
    public string? IndexName => IndexSymbolRef?.Name;
    public string ValueSymbol => ValueSymbolRef.Id;
    public string ValueName => ValueSymbolRef.Name;
}

public sealed record BreakIr(TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record ContinueIr(IReadOnlyList<ExprIr> Values, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record GuardIr(ExprIr Condition, ExprIr Else, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record ReturnIr(ExprIr Value, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record BlockIr(IReadOnlyList<ExprIr> Items, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record IfIr(ExprIr Condition, ExprIr Then, ExprIr Else, TypeRefIr TypeRef)
    : ExprIr(TypeRef);

public sealed record MatchIr(ExprIr Target, IReadOnlyList<MatchArmIr> Arms, TypeRefIr TypeRef)
    : ExprIr(TypeRef);

public sealed record MatchArmIr(MatchPatternIr Pattern, ExprIr Body, ExprIr? Guard = null);

public sealed record FailIr(ExprIr Message, string? Source, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record PanicIr(TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record TryCatchIr(
    ExprIr Body,
    IReadOnlyList<CatchClauseIr> Catches,
    TypeRefIr TypeRef
) : ExprIr(TypeRef);

public sealed record TryResultIr(ExprIr Body, TypeRefIr TypeRef) : ExprIr(TypeRef);

public sealed record CatchClauseIr(CatchPatternIr Pattern, ExprIr Body);

public abstract record CatchPatternIr;

public sealed record FailureCatchPatternIr(SymbolIr? BindingSymbol) : CatchPatternIr
{
    public string? BindingName => BindingSymbol?.Name;
}

public sealed record WildcardCatchPatternIr : CatchPatternIr;

public sealed record MatchCatchPatternIr(TypeRefIr ErrorType, MatchPatternIr Pattern)
    : CatchPatternIr;

public abstract record IsPatternIr;

public sealed record NoneIsPatternIr : IsPatternIr;

public sealed record SomeIsPatternIr(SymbolIr? BindingSymbol, MatchPatternIr? Payload = null)
    : IsPatternIr
{
    public string? BindingName => BindingSymbol?.Name;
}

public sealed record OkIsPatternIr(SymbolIr? BindingSymbol, MatchPatternIr? Payload = null)
    : IsPatternIr
{
    public string? BindingName => BindingSymbol?.Name;
}

public sealed record ErrIsPatternIr(SymbolIr? BindingSymbol, MatchPatternIr? Payload = null)
    : IsPatternIr
{
    public string? BindingName => BindingSymbol?.Name;
}

public sealed record ValueIsPatternIr(ExprIr Value) : IsPatternIr;

public sealed record OrIsPatternIr(IReadOnlyList<IsPatternIr> Alternatives) : IsPatternIr;

public sealed record MatchIsPatternIr(MatchPatternIr Pattern) : IsPatternIr;

public sealed record EnumIsPatternIr(
    string EnumName,
    string VariantName,
    IReadOnlyList<SymbolIr> Bindings,
    MatchPatternIr? Payload = null
) : IsPatternIr;

public abstract record MatchPatternIr;

public sealed record WildcardMatchPatternIr : MatchPatternIr;

public sealed record BindingMatchPatternIr(SymbolIr BindingSymbol) : MatchPatternIr
{
    public string BindingName => BindingSymbol.Name;
}

public sealed record NoneMatchPatternIr : MatchPatternIr;

public sealed record SomeMatchPatternIr(SymbolIr? BindingSymbol, MatchPatternIr? Payload = null)
    : MatchPatternIr
{
    public string? BindingName => BindingSymbol?.Name;
}

public sealed record OkMatchPatternIr(SymbolIr? BindingSymbol, MatchPatternIr? Payload = null)
    : MatchPatternIr
{
    public string? BindingName => BindingSymbol?.Name;
}

public sealed record ErrMatchPatternIr(SymbolIr? BindingSymbol, MatchPatternIr? Payload = null)
    : MatchPatternIr
{
    public string? BindingName => BindingSymbol?.Name;
}

public sealed record TupleMatchPatternIr(IReadOnlyList<MatchPatternIr> Items) : MatchPatternIr;

public abstract record ArrayPatternSegmentIr;

public sealed record ArrayElementPatternSegmentIr(MatchPatternIr Pattern) : ArrayPatternSegmentIr;

public sealed record ArrayRestPatternSegmentIr(SymbolIr? BindingSymbol) : ArrayPatternSegmentIr
{
    public string? BindingName => BindingSymbol?.Name;
}

public sealed record ArrayFixedSpreadPatternSegmentIr(ExprIr Value) : ArrayPatternSegmentIr;

public sealed record ArrayBitFieldPatternSegmentIr(
    bool Signed,
    string Endian,
    int Width,
    SymbolIr? BindingSymbol,
    ExprIr? Value
) : ArrayPatternSegmentIr
{
    public string? BindingName => BindingSymbol?.Name;
}

public sealed record ArrayMatchPatternIr(IReadOnlyList<ArrayPatternSegmentIr> Segments)
    : MatchPatternIr;

public sealed record RangeMatchPatternIr(
    ExprIr Start,
    ExprIr End,
    bool Inclusive,
    SymbolIr? BindingSymbol = null
) : MatchPatternIr;

public sealed record EnumMatchPatternIr(
    string EnumName,
    string VariantName,
    IReadOnlyList<SymbolIr> BindingSymbols,
    MatchPatternIr? Payload = null
) : MatchPatternIr
{
    public IReadOnlyList<string> Bindings => BindingSymbols.Select(b => b.Name).ToList();
}

public sealed record LiteralMatchPatternIr(ExprIr Value) : MatchPatternIr;

public sealed record OrMatchPatternIr(
    IReadOnlyList<MatchPatternIr> Alternatives,
    SymbolIr? BindingSymbol = null
) : MatchPatternIr;

public abstract record CalleeIr;

public sealed record BuiltinCalleeIr(string Name) : CalleeIr;

public sealed record FunctionCalleeIr(SymbolIr SymbolRef) : CalleeIr
{
    public string Symbol => SymbolRef.Id;
    public string Name => SymbolRef.Name;
}

public sealed record IntrinsicCalleeIr(string ExternalName, SymbolIr SymbolRef) : CalleeIr
{
    public string Symbol => SymbolRef.Id;
    public string Name => SymbolRef.Name;
}

public sealed record CSharpExternCalleeIr(string ExternalName, SymbolIr SymbolRef) : CalleeIr
{
    public string Symbol => SymbolRef.Id;
    public string Name => SymbolRef.Name;
}
