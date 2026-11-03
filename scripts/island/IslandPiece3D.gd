class_name IslandPiece3D
extends InteractiveTableObject

@export_enum("settlement", "city", "road", "robber") var kind := "settlement"
@export var piece_color := Color("e6b466")


func _ready() -> void:
	super._ready()
	_rebuild()


func set_kind(value: String) -> void:
	if value == kind or value not in ["settlement", "city", "road", "robber"]:
		return
	kind = value
	_rebuild()


func _rebuild() -> void:
	var names := {"settlement": "Pueblo", "city": "Ciudad", "road": "Camino", "robber": "Ladrón"}
	display_name = names[kind]
	for child in $Visual.get_children():
		$Visual.remove_child(child)
		child.queue_free()
	var material := StandardMaterial3D.new()
	material.albedo_color = piece_color
	material.roughness = 0.65
	var shape := BoxShape3D.new()
	match kind:
		"road":
			shape.size = Vector3(0.31, 0.075, 0.075)
			_box(Vector3(0.31, 0.075, 0.075), Vector3.ZERO, material)
		"settlement":
			shape.size = Vector3(0.14, 0.18, 0.14)
			_box(Vector3(0.14, 0.12, 0.14), Vector3(0, -0.03, 0), material)
			_roof(Vector3(0, 0.055, 0), 0.105, material)
		"city":
			shape.size = Vector3(0.19, 0.21, 0.14)
			_box(Vector3(0.19, 0.14, 0.14), Vector3(0, -0.035, 0), material)
			_roof(Vector3(0, 0.065, 0), 0.13, material)
			_box(Vector3(0.045, 0.07, 0.045), Vector3(0.055, 0.115, 0), material)
		"robber":
			shape.size = Vector3(0.14, 0.20, 0.14)
			_box(Vector3(0.11, 0.14, 0.11), Vector3(0, -0.03, 0), material)
			_roof(Vector3(0, 0.06, 0), 0.085, material)
	$CollisionShape3D.shape = shape
	_update_highlight()


func _box(size: Vector3, position: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	node.material_override = material
	$Visual.add_child(node)


func _roof(position: Vector3, radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 4
	mesh.bottom_radius = radius
	mesh.top_radius = 0.0
	mesh.height = 0.10
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	node.rotation.y = PI / 4.0
	node.material_override = material
	$Visual.add_child(node)


func _update_highlight() -> void:
	var visual := get_node_or_null("Visual") as MeshInstance3D
	if visual == null:
		return
	var overlay: Material = _highlight if hovered or is_grabbed else null
	for child in visual.get_children():
		if child is MeshInstance3D:
			child.material_overlay = overlay
