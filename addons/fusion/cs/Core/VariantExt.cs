#nullable enable
using System;
using System.Collections.Generic;
using Godot;
using Array = Godot.Collections.Array;

namespace FusionGodot;

/// <summary>Small conversion helpers for Variants to <c>Fusion</c> wrappers.</summary>
internal static class VariantExt
{
    /// <summary>Map a Godot <see cref="Array"/> of objects into typed wrappers.</summary>
    internal static List<T> ToWrappers<T>(this Variant arrayVariant) where T : class, IFusionWrapperFactory<T>
    {
        var result = new List<T>();
        Array arr = arrayVariant.AsGodotArray();
        foreach (Variant item in arr)
        {
            GodotObject? obj = item.AsGodotObject();
            if (obj != null)
            {
                result.Add(T.Wrap(obj));
            }
        }
        return result;
    }

    /// <summary>Wraps a Godot variant into a typed wrapper, returning null if not wrappable.</summary>
    internal static T? ToWrapper<T>(this Variant variant) where T : class, IFusionWrapperFactory<T>
        => T.WrapOrNull(variant.AsGodotObject());
}
