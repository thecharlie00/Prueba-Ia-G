#nullable enable
using Godot;

namespace FusionGodot;

/// <summary>
/// Accessors that turn an existing Fusion node into its typed wrapper.
/// Cache the result in a field rather than re-wrapping every frame.
/// </summary>
public static class NodeFusionExtensions
{
    /// <summary>
    /// Wraps an already fetched GodotObject into a Fusion type.
    /// Throws an exception if the GodotObject is null or not wrappable to the given Fusion type.
    /// </summary>
    /// <seealso cref="GetFusion{T}(Node, NodePath)"/>
    public static T AsFusion<T>(this GodotObject? obj) where T : class, IFusionWrapperFactory<T>, IFusionWrapper<GodotObject>
        => T.Wrap(obj);

    /// <summary>
    /// Wraps an already fetched GodotObject into a Fusion type.
    /// Returns null if the GodotObject is null or not wrappable to the given Fusion type.
    /// </summary>
    /// <seealso cref="GetFusion{T}(Node, NodePath)"/>
    public static T? AsFusionOrNull<T>(this GodotObject? obj) where T : class, IFusionWrapperFactory<T>, IFusionWrapper<GodotObject>
        => T.WrapOrNull(obj);

    /// <summary>
    /// Fetches a child node via NodePath and wraps it into a Fusion type.
    /// Throws an exception if the child node is null or not wrappable to the given Fusion type.
    /// Equivalent to <see cref="Node.GetNode{T}(NodePath)" /> for Fusion types.
    /// </summary>
    public static T GetFusion<T>(this Node parent, NodePath path) where T : class, IFusionWrapperFactory<T>, IFusionWrapper<Node>
        => T.Wrap(parent.GetNode(path));

    /// <summary>
    /// Fetches a child node via NodePath and wraps it into a Fusion type.
    /// Returns null if the child node is null or not wrappable to the given Fusion type. 
    /// Equivalent to <see cref="Node.GetNodeOrNull{T}(NodePath)" /> for Fusion types.
    /// </summary>
    public static T? GetFusionOrNull<T>(this Node parent, NodePath path) where T : class, IFusionWrapperFactory<T>, IFusionWrapper<Node>
        => T.WrapOrNull(parent.GetNodeOrNull(path));
}
