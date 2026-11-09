#nullable enable
using Godot;
using System;
using System.Diagnostics.CodeAnalysis;

namespace FusionGodot;

/// <summary>
/// Self-implemented factory to create wrappers from GodotObjects.
/// Used for generic constraints in NodeFusionExtensions.
/// Mainly for internal use, prefer <see cref="NodeFusionExtensions.AsFusion{T}(GodotObject?)"/>
/// </summary>
public interface IFusionWrapperFactory<T> where T : class, IFusionWrapperFactory<T>
{
    /// <summary>The internal ClassDB name for the given wrapped type.</summary>
    static abstract StringName ClassName { get; }

    /// <summary>Creates a new wrapper instance for the given GodotObject</summary>
    internal static abstract T Create(GodotObject obj);

    /// <summary>
    /// Creates a Fusion wrapper over the supplied GodotObject.
    /// Throws System.InvalidCastException if <paramref name="obj"/> is not a compatible type.
    /// </summary>
    static virtual T Wrap(GodotObject? obj)
    {
        if (!CanWrap(obj, T.ClassName))
            throw new InvalidCastException($"Cannot wrap type '{obj?.GetClass()}' as a '{T.ClassName}'.");

        return T.Create(obj);
    }

    /// <summary>
    /// Creates a Fusion wrapper over the supplied GodotObject.
    /// Returns null if <paramref name="obj"/> is not a compatible type.
    /// </summary>
    static virtual T? WrapOrNull(GodotObject? obj)
        => CanWrap(obj, T.ClassName) ? T.Create(obj) : null;


    // --- Helpers for wrapping objects ---

    private static bool CanWrap([NotNullWhen(true)] GodotObject? obj, StringName className)
        => obj != null && obj.IsClass(className);
}
