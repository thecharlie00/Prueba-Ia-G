class_name PhysicalChessPiece
extends InteractiveTableObject

const NAMES := {1: "Peón", 2: "Caballo", 3: "Alfil", 4: "Torre", 5: "Dama", 6: "Rey"}

@export_range(1, 6) var piece_type := ChessRules.PAWN
@export var white := true


func _ready() -> void:
	super._ready()
	_rebuild_model()


func set_piece_type(kind: int) -> void:
	if kind == piece_type or kind not in NAMES:
		return
	piece_type = kind
	_rebuild_model()


func _rebuild_model() -> void:
	display_name = str(NAMES[piece_type]) + (" blanco" if white else " negro")
	for child in $Visual.get_children():
		$Visual.remove_child(child)
		child.queue_free()
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.PIECE_LIGHT if white else Palette.PIECE_DARK
	material.roughness = 0.58
	var model := ChessPieceModel.create(piece_type, white, material)
	var piece_height := ChessPieceModel.height(piece_type) + 0.01
	model.position.y = -piece_height * 0.5
	$Visual.add_child(model)
	var shape := ($CollisionShape3D.shape as CylinderShape3D).duplicate() as CylinderShape3D
	shape.height = piece_height
	$CollisionShape3D.shape = shape
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -piece_height * 0.33, 0)
	_update_highlight()


func _update_highlight() -> void:
	var visual := get_node_or_null("Visual") as MeshInstance3D
	if visual == null:
		return
	var overlay: Material = _highlight if hovered or is_grabbed else null
	_apply_overlay(visual, overlay)


func _apply_overlay(parent: Node, overlay: Material) -> void:
	if parent is MeshInstance3D:
		(parent as MeshInstance3D).material_overlay = overlay
	for child in parent.get_children():
		_apply_overlay(child, overlay)
