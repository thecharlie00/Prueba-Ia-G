class_name SnapGrid3D
extends Node3D

## Rejilla opcional para colocar piezas; las consultas se realizan en el ciclo físico.
@export var columns: int = 4
@export var rows: int = 4
@export var cell_size: float = 0.6
@export var surface_y: float = 0.8
@export var enabled: bool = true
@export_flags_3d_physics var piece_mask: int = 2

var _marker: MeshInstance3D
var _marker_material: StandardMaterial3D


func _ready() -> void:
	_build_visuals()


# Devuelve un destino y su validez; un diccionario vacío significa fuera de la zona.
func candidate(object: InteractiveTableObject, desired: Vector3) -> Dictionary:
	if not enabled or not is_instance_valid(object) or cell_size <= 0.0:
		return {}
	var local: Vector3 = to_local(desired)
	var width: float = columns * cell_size
	var depth: float = rows * cell_size
	if absf(local.x) >= width * 0.5 or absf(local.z) >= depth * 0.5:
		return {}
	var col: int = floori((local.x + width * 0.5) / cell_size)
	var row: int = floori((local.z + depth * 0.5) / cell_size)
	var cell_local := Vector3(
		-width * 0.5 + (col + 0.5) * cell_size, 0.0, -depth * 0.5 + (row + 0.5) * cell_size
	)
	var world: Vector3 = to_global(cell_local)
	var shape_node := object.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not shape_node or not shape_node.shape is BoxShape3D:
		return {"position": world, "valid": false}

	# La altura engloba el colisionador girado, no solo su tamaño local.
	var box := shape_node.shape as BoxShape3D
	var shape_transform: Transform3D = object.global_transform * shape_node.transform
	var basis: Basis = shape_transform.basis
	var half: Vector3 = box.size * 0.5
	var extent_y: float = (
		absf(basis.x.y) * half.x + absf(basis.y.y) * half.y + absf(basis.z.y) * half.z
	)
	var offset_y: float = shape_transform.origin.y - object.global_position.y
	world.y = surface_y + extent_y - offset_y + 0.01
	shape_transform.origin += world - object.global_position
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = shape_transform
	query.collision_mask = piece_mask
	query.exclude = [object.get_rid()]
	query.margin = 0.005
	var blocked: bool = not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
	return {"position": world, "valid": not blocked}


func show_candidate(result: Dictionary) -> void:
	if not is_instance_valid(_marker):
		return
	_marker.visible = not result.is_empty()
	if result.is_empty():
		return
	var point: Vector3 = result["position"]
	_marker.global_position = Vector3(point.x, surface_y + 0.035, point.z)
	_marker_material.albedo_color = (
		Color(0.52, 1.0, 0.72, 0.65) if result["valid"] else Color(1.0, 0.3, 0.25, 0.65)
	)


func _build_visuals() -> void:
	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(cell_size - 0.025, 0.006, cell_size - 0.025)
	var light := StandardMaterial3D.new()
	light.albedo_color = Color(0.33, 0.49, 0.39)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.15, 0.34, 0.28)
	for row in range(rows):
		for col in range(columns):
			var tile := MeshInstance3D.new()
			tile.mesh = tile_mesh
			tile.material_override = light if (row + col) % 2 == 0 else dark
			tile.position = Vector3(
				-columns * cell_size * 0.5 + (col + 0.5) * cell_size,
				0.015,
				-rows * cell_size * 0.5 + (row + 0.5) * cell_size
			)
			add_child(tile)
	_marker = MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(cell_size - 0.05, 0.006, cell_size - 0.05)
	_marker.mesh = marker_mesh
	_marker_material = StandardMaterial3D.new()
	_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker.material_override = _marker_material
	_marker.visible = false
	add_child(_marker)
