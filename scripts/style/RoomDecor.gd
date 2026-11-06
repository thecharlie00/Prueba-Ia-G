class_name RoomDecor
extends Node3D
## Habitación acogedora alrededor de la mesa (fase 1, docs/ARTE.md): alfombra, dos paredes con
## zócalo, ventana, estantería con libros y una planta. Solo decorado: sin colisiones.
## Las paredes solo se ven por dentro (cara única), así que al girar la cámara por detrás se
## vuelven invisibles en lugar de tapar la mesa, como una casa de muñecas.
## ToonStyle la añade una vez por escena al encontrar el nodo "Floor".

const WALL := Color("e9c9a0")
const TRIM := Color("c98f5b")
const RUG := Color("9a88d6")
const RUG_EDGE := Color("5b4aa0")
const GLASS := Color("bfe3ff")
const BOOKS := [Color("ff6b5e"), Color("4d7cfe"), Color("ffc83d"), Color("3fcf8e"), Color("8a7fd6")]

## Distancia de las paredes al centro de la mesa.
var north_z := -10.0
var west_x := -12.5


func _ready() -> void:
	name = "RoomDecor"
	_floorboards()
	_rug()
	_wall(Vector3(0, 0, north_z), 0.0, 32.0)
	_wall(Vector3(west_x, 0, 0), PI / 2.0, 26.0)
	_window(Vector3(-2.5, 4.2, north_z + 0.02))
	_shelf(Vector3(west_x + 0.25, 2.6, -3.0))
	_plant(Vector3(west_x + 1.2, 0, north_z + 1.2))


# Juntas entre tablones del suelo: líneas oscuras finas (sin contorno por ser tan finas).
func _floorboards() -> void:
	var seam := _material(Palette.FLOOR.darkened(0.35))
	for i in range(-16, 17):
		var line := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(40.0, 0.004, 0.05)
		line.mesh = box
		line.position = Vector3(0, 0.003, i * 1.1)
		line.material_override = seam
		add_child(line)
		# Juntas cortas escalonadas entre los extremos de los tablones.
		for j in range(-6, 7):
			var cut := MeshInstance3D.new()
			var short := BoxMesh.new()
			short.size = Vector3(0.05, 0.004, 1.1)
			cut.mesh = short
			cut.position = Vector3(j * 3.2 + (1.6 if i % 2 else 0.0), 0.003, i * 1.1 + 0.55)
			cut.material_override = seam
			add_child(cut)


func _rug() -> void:
	var edge := _mesh(PieceKit.rounded_disc(5.4, 0.03, 0.015, 48), Vector3(0, 0.015, 0), RUG_EDGE)
	edge.scale = Vector3(1.0, 1.0, 0.72)
	var top := _mesh(PieceKit.rounded_disc(5.0, 0.035, 0.015, 48), Vector3(0, 0.02, 0), RUG)
	top.scale = Vector3(1.0, 1.0, 0.72)


func _wall(origin: Vector3, turn: float, width: float) -> void:
	var wall := Node3D.new()
	wall.position = origin
	wall.rotation.y = turn
	add_child(wall)
	var plane := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width, 9.0)
	plane.mesh = quad
	plane.position.y = 4.5
	plane.material_override = _material(WALL, true)
	wall.add_child(plane)
	# Zócalo de madera: también de una cara.
	var trim := MeshInstance3D.new()
	var strip := QuadMesh.new()
	strip.size = Vector2(width, 0.7)
	trim.mesh = strip
	trim.position = Vector3(0, 0.35, 0.01)
	trim.material_override = _material(TRIM, true)
	wall.add_child(trim)


func _window(center: Vector3) -> void:
	var glass := MeshInstance3D.new()
	var pane := QuadMesh.new()
	pane.size = Vector2(3.2, 2.6)
	glass.mesh = pane
	glass.position = center + Vector3(0, 0, 0.01)
	var glass_material := _material(GLASS, true)
	glass_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.material_override = glass_material
	add_child(glass)
	# Marco y cruz de madera.
	for bar in [
		[Vector3(0, 1.36, 0), Vector3(3.5, 0.18, 0.12)], [Vector3(0, -1.36, 0), Vector3(3.6, 0.22, 0.2)],
		[Vector3(-1.66, 0, 0), Vector3(0.18, 2.9, 0.12)], [Vector3(1.66, 0, 0), Vector3(0.18, 2.9, 0.12)],
		[Vector3(0, 0, 0), Vector3(3.2, 0.1, 0.08)], [Vector3(0, 0, 0), Vector3(0.1, 2.6, 0.08)],
	]:
		_mesh(PieceKit.rounded_box(bar[1], 0.03), center + bar[0] + Vector3(0, 0, 0.06), Palette.PAPER)
	# Una nube en el cristal.
	for puff in [Vector3(-0.6, 0.55, 0), Vector3(-0.25, 0.7, 0), Vector3(0.1, 0.55, 0)]:
		var cloud := _mesh(PieceKit.dot(0.28, 0.02), center + puff + Vector3(0, 0, 0.03), Palette.PAPER)
		cloud.rotation_degrees.x = 90


func _shelf(origin: Vector3) -> void:
	var board := _mesh(PieceKit.rounded_box(Vector3(0.6, 0.12, 3.2), 0.03), origin, TRIM)
	board.name = "Shelf"
	var z := origin.z - 1.3
	for i in 9:
		var height := 0.5 + float((i * 7) % 4) * 0.08
		var thick := 0.16 + float((i * 3) % 3) * 0.03
		var book := _mesh(
			PieceKit.rounded_box(Vector3(0.42, height, thick), 0.02),
			Vector3(origin.x, origin.y + 0.06 + height * 0.5, z + thick * 0.5),
			BOOKS[i % BOOKS.size()]
		)
		if i == 7:
			book.rotation.x = -0.35
		z += thick + 0.03


func _plant(base: Vector3) -> void:
	var pot := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.55
	cone.bottom_radius = 0.42
	cone.height = 0.9
	pot.mesh = cone
	pot.position = base + Vector3(0, 0.45, 0)
	pot.material_override = _material(Palette.CORAL)
	add_child(pot)
	for leaf in [
		Vector3(0, 1.5, 0), Vector3(-0.45, 1.25, 0.1), Vector3(0.45, 1.3, -0.1),
		Vector3(0.1, 1.95, 0.2), Vector3(-0.25, 1.75, -0.25), Vector3(0.35, 1.8, 0.2),
	]:
		var ball := SphereMesh.new()
		ball.radius = 0.38
		ball.height = 0.76
		ball.radial_segments = 14
		ball.rings = 7
		_mesh(ball, base + leaf, Palette.PLAYER_GREEN.darkened(0.15))


func _mesh(mesh: Mesh, position: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	node.material_override = _material(color)
	add_child(node)
	return node


func _material(color: Color, one_sided := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic_specular = 0.1
	# Paredes de una sola cara: invisibles vistas desde fuera (StandardMaterial3D ya
	# descarta la cara trasera; se deja explícito).
	if one_sided:
		material.cull_mode = BaseMaterial3D.CULL_BACK
	return material
