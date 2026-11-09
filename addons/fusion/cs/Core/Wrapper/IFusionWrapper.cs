#nullable enable
using Godot;

namespace FusionGodot;

/// <summary>
/// Internal interface to support generic covariance for <see cref="NodeFusionExtensions"/>'s extension methods.
/// </summary>
public interface IFusionWrapper<out T> where T : GodotObject
{
    T Self { get; }

    bool IsValid { get; }
}
