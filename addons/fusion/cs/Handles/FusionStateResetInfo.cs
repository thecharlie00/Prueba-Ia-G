#nullable enable
using Godot;

namespace FusionGodot;

/// <summary>Payload delivered with a replicator's <see cref="FusionReplicator.StateReset"/> signal (wraps native FusionStateResetInfo).</summary>
public sealed class FusionStateResetInfo : FusionWrapper<RefCounted>, IFusionWrapperFactory<FusionStateResetInfo>
{
    private static readonly StringName _className = "FusionStateResetInfo";
    public static StringName ClassName => _className;

    internal FusionStateResetInfo(GodotObject obj) : base(obj) { }

    /// <summary>Which network event caused the reset.</summary>
    public Reason Reason => (Reason)CallInt(MethodName.GetReason);

    // --- Wrapper Factory Methods ---

    static FusionStateResetInfo IFusionWrapperFactory<FusionStateResetInfo>.Create(GodotObject obj)
        => new(obj);

    // --- Cached native member names (GDExtension gets no GodotSharp-generated caches) ---

    /// <summary>Cached StringNames for this class's methods.</summary>
    public class MethodName : RefCounted.MethodName
    {
        public static readonly StringName GetReason = "get_reason";
    }

    /// <summary>Cached StringNames for this class's properties.</summary>
    public class PropertyName : RefCounted.PropertyName
    {
        public static readonly StringName Reason = "reason";
    }

    /// <summary>Cached StringNames for this class's signals.</summary>
    public class SignalName : RefCounted.SignalName
    {
    }
}
