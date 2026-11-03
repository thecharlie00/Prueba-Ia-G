class_name BoardGeometry3D
extends RefCounted


## Geometría compartida para tableros de 8×8 sobre la mesa.
static func square_from_mouse(camera: Camera3D, mouse: Vector2, cell: float, height: float) -> int:
	var origin: Vector3 = camera.project_ray_origin(mouse)
	var direction: Vector3 = camera.project_ray_normal(mouse)
	if absf(direction.y) < 0.0001:
		return -1
	var distance: float = (height - origin.y) / direction.y
	if distance < 0.0:
		return -1
	var point: Vector3 = origin + direction * distance
	var x: int = floori(point.x / cell + 4.0)
	var y: int = floori(point.z / cell + 4.0)
	return y * 8 + x if x >= 0 and x < 8 and y >= 0 and y < 8 else -1


static func square_position(square: int, cell: float, height: float) -> Vector3:
	return Vector3((square % 8 - 3.5) * cell, height, (square / 8 - 3.5) * cell)


static func make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material


static func make_tiles(root: Node3D, cell: float, height: float) -> Array[MeshInstance3D]:
	var squares: Array[MeshInstance3D] = []
	var mesh := BoxMesh.new()
	mesh.size = Vector3(cell, 0.035, cell)
	for square in range(64):
		var tile := MeshInstance3D.new()
		tile.mesh = mesh
		tile.position = square_position(square, cell, height - 0.0175)
		root.add_child(tile)
		squares.append(tile)
	for index in range(8):
		_add_coordinate(
			root,
			"abcdefgh".substr(index, 1),
			Vector3((index - 3.5) * cell, height + 0.01, 4.35 * cell)
		)
		_add_coordinate(
			root, str(8 - index), Vector3(-4.35 * cell, height + 0.01, (index - 3.5) * cell)
		)
	return squares


static func _add_coordinate(root: Node3D, text: String, point: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.003
	label.modulate = Color("f5ead5")
	label.rotation_degrees.x = -90.0
	label.position = point
	root.add_child(label)


static func update_tiles(
	squares: Array[MeshInstance3D],
	selected: int,
	destinations: Array[int],
	light: Material,
	dark: Material,
	selection: Material,
	legal: Material
) -> void:
	for square in range(64):
		var shade: int = (square % 8 + square / 8) % 2
		squares[square].material_override = light if shade == 0 else dark
		if square == selected:
			squares[square].material_override = selection
		elif square in destinations:
			squares[square].material_override = legal
