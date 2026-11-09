#nullable enable
using Godot;
using System;

namespace FusionGodot;

/// <summary>
/// Result handle returned by the <c>Fusion.Rpc*</c> calls (wraps native FusionRpcResult).
/// </summary>
public sealed class FusionRpcResult : FusionWrapper<RefCounted>, IFusionWrapperFactory<FusionRpcResult>
{
    private static readonly StringName _className = "FusionRpcResult";
    public static StringName ClassName => _className;

    internal FusionRpcResult(GodotObject obj) : base(obj) { }

    /// <summary>
    /// Register a callback invoked if the RPC fails within <paramref name="ttl"/> seconds.
    /// Returns this result for chaining.
    /// </summary>
    public FusionRpcResult OnFail(Action<RpcFailure> callback, float ttl = 2.0f)
    {
        var callable = Callable.From(
            (int reason, int targetPlayer, int originPlayer, int attempts) 
                => callback(new RpcFailure((RpcError)reason, targetPlayer, originPlayer, attempts)));

        Call(MethodName.OnFail, callable, ttl);
        return this;
    }

    /// <summary>
    /// Register a callback invoked if the RPC fails within <paramref name="ttl"/> seconds.
    /// Returns this result for chaining.
    /// </summary>
    public FusionRpcResult OnFail(Action callback, float ttl = 2.0f)
    {
        var callable = Callable.From((int _, int _, int _, int _) => callback());
        Call(MethodName.OnFail, callable, ttl);
        return this;
    }

    // --- Wrapper Factory Methods ---

    static FusionRpcResult IFusionWrapperFactory<FusionRpcResult>.Create(GodotObject obj)
        => new(obj);

    // --- Cached native member names (GDExtension gets no GodotSharp-generated caches) ---

    /// <summary>Cached StringNames for this class's methods.</summary>
    public class MethodName : RefCounted.MethodName
    {
        public static readonly StringName OnFail = "on_fail";
    }

    /// <summary>Cached StringNames for this class's properties.</summary>
    public class PropertyName : RefCounted.SignalName
    {
    }

    /// <summary>Cached StringNames for this class's signals.</summary>
    public class SignalName : RefCounted.SignalName
    {
    }

    // --- Helper classes ---
    public readonly record struct RpcFailure(RpcError Reason, int TargetPlayer, int OriginPlayer, int Attempts);
}
