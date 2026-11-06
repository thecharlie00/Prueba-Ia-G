class_name IslandTerrain
extends RefCounted
## Casillas de la isla en 3D y estilo cartoon (docs/ARTE.md): prisma hexagonal del color del
## terreno con su paisaje en miniatura encima y la ficha de número en el centro.
## El paisaje se coloca entre el centro y los lados, lejos de esquinas (pueblos) y lados
## (caminos), y no tiene colisiones.

## Colores por recurso: madera, ladrillo, lana, trigo, mineral. El desierto va aparte.
# Saturados y algo oscuros: la luz toon aclara mucho las caras que miran al sol.
const GROUND := [Color("2f8f4e"), Color("c9643a"), Color("6fbf45"), Color("e3a92a"), Color("737d9c")]
const DESERT_GROUND := Color("d9b874")
const SEA := Color("3f7fd9")
## Color de carta de cada recurso (más claro que el suelo, para el texto de tinta).
const CARD := [Color("bfe8b0"), Color("f7c4a3"), Color("e3f5c9"), Color("fbe9a6"), Color("d9dded")]
const TREE := Color("1f6e3f")
const TRUNK := Color("8a4f2a")
const BRICK := Color("c4532f")
const SHEEP := Color("fff8ec")
const WHEAT := Color("e0a42a")
const ROCK := Color("5d6684")
const SNOW := Color("fff8ec")
const CACTUS := Color("4fa860")
const TOKEN := Color("fff1d9")
const HOT := Color("d6453b")

const TILE_HEIGHT := 0.07


## Casilla completa, con el origen en el centro de su cara superior.
static func build_tile(terrain: int, number: int, radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Tile"
	var prism := MeshInstance3D.new()
	prism.name = "Ground"
	var mesh := CylinderMesh.new()
	# Seis lados: las esquinas de CylinderMesh caen en 30° + 60°·k, igual que el tablero.
	mesh.radial_segments = 6
	mesh.rings = 1
	mesh.top_radius = radius * 0.96
	mesh.bottom_radius = radius * 0.96
	mesh.height = TILE_HEIGHT
	prism.mesh = mesh
	prism.position.y = -TILE_HEIGHT * 0.5
	prism.material_override = _material(DESERT_GROUND if terrain == IslandBoard.DESERT else GROUND[terrain])
	root.add_child(prism)
	var scenery := Node3D.new()
	scenery.name = "Scenery"
	root.add_child(scenery)
	match terrain:
		0:
			_forest(scenery)
		1:
			_hills(scenery)
		2:
			_pasture(scenery)
		3:
			_field(scenery)
		4:
			_mountains(scenery)
		_:
			_desert(scenery)
	if terrain != IslandBoard.DESERT:
		root.add_child(_number_token(number))
	return root


## Ficha de número: disco crema con el número y puntos de probabilidad (6 y 8 en rojo).
static func _number_token(number: int) -> Node3D:
	var token := Node3D.new()
	token.name = "NumberToken"
	var disc := MeshInstance3D.new()
	disc.mesh = PieceKit.rounded_disc(0.1, 0.03, 0.01)
	disc.position.y = 0.015
	disc.material_override = _material(TOKEN)
	token.add_child(disc)
	var hot := number in [6, 8]
	var label := Label3D.new()
	label.text = str(number)
	label.font_size = 64
	label.pixel_size = 0.0019
	label.position = Vector3(0, 0.032, -0.012)
	label.rotation_degrees.x = -90
	label.modulate = HOT if hot else Palette.INK
	label.outline_size = 0
	if Engine.get_main_loop() is SceneTree:
		var style := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("ToonStyle")
		if style != null:
			label.font = style.DISPLAY_FONT
	token.add_child(label)
	var pips := 6 - absi(7 - number)
	var pip_mesh := PieceKit.dot(0.009, 0.004)
	var pip_material := _material(HOT if hot else Palette.INK)
	for i in pips:
		var pip := MeshInstance3D.new()
		pip.mesh = pip_mesh
		pip.material_override = pip_material
		pip.position = Vector3((i - (pips - 1) * 0.5) * 0.024, 0.031, 0.05)
		token.add_child(pip)
	return token


# Tres puntos entre el centro y los lados (0°, 120° y 240°), donde no hay pueblos ni caminos.
static func _spots(distance := 0.215, turn := 0.0) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for i in 3:
		var angle := deg_to_rad(turn + i * 120.0)
		spots.append(Vector3(cos(angle) * distance, 0.0, sin(angle) * distance))
	return spots


static func _forest(parent: Node3D) -> void:
	var leaves := _material(TREE)
	var trunk := _material(TRUNK)
	for spot in _spots():
		for offset in [Vector3(-0.04, 0, 0.02), Vector3(0.035, 0, -0.025)]:
			var tree := Node3D.new()
			tree.position = spot + offset
			parent.add_child(tree)
			tree.add_child(_mesh(_cylinder(0.014, 0.014, 0.04), Vector3(0, 0.02, 0), trunk))
			tree.add_child(_mesh(_cylinder(0.0, 0.05, 0.08), Vector3(0, 0.075, 0), leaves))
			tree.add_child(_mesh(_cylinder(0.0, 0.038, 0.06), Vector3(0, 0.115, 0), leaves))


static func _hills(parent: Node3D) -> void:
	var brick := _material(BRICK)
	var hill := _material(GROUND[1].darkened(0.12))
	for spot in _spots():
		var mound := MeshInstance3D.new()
		mound.mesh = PieceKit.rounded_disc(0.07, 0.035, 0.03)
		mound.position = spot + Vector3(0, 0.0175, 0)
		mound.material_override = hill
		parent.add_child(mound)
		# Pila de ladrillos: dos abajo, uno arriba.
		for b in [Vector3(-0.022, 0.05, 0), Vector3(0.022, 0.05, 0), Vector3(0, 0.074, 0)]:
			parent.add_child(_mesh(PieceKit.rounded_box(Vector3(0.042, 0.022, 0.026), 0.006), spot + b, brick))


static func _pasture(parent: Node3D) -> void:
	var wool := _material(SHEEP)
	var face := _material(Palette.INK)
	for spot in _spots(0.215, 60.0):
		var sheep := Node3D.new()
		sheep.position = spot
		sheep.rotation.y = spot.x * 9.0 + spot.z * 5.0  # Variado pero siempre igual.
		parent.add_child(sheep)
		for leg in [Vector3(-0.022, 0.012, -0.014), Vector3(0.022, 0.012, -0.014), Vector3(-0.022, 0.012, 0.014), Vector3(0.022, 0.012, 0.014)]:
			sheep.add_child(_mesh(_cylinder(0.006, 0.006, 0.024), leg, face))
		var body := _mesh(_sphere(0.04), Vector3(0, 0.05, 0), wool)
		body.scale = Vector3(1.25, 0.9, 1.0)
		sheep.add_child(body)
		sheep.add_child(_mesh(_sphere(0.019), Vector3(0.052, 0.062, 0), face))


static func _field(parent: Node3D) -> void:
	var stalk := _material(WHEAT.darkened(0.15))
	var ear := _material(WHEAT)
	for spot in _spots(0.215, 60.0):
		for x in [-0.03, 0.0, 0.03]:
			for z in [-0.02, 0.02]:
				var p := spot + Vector3(x, 0, z + x * 0.3)
				parent.add_child(_mesh(_cylinder(0.004, 0.004, 0.06), p + Vector3(0, 0.03, 0), stalk))
				var head := _mesh(_sphere(0.012), p + Vector3(0, 0.068, 0), ear)
				head.scale = Vector3(0.8, 1.8, 0.8)
				parent.add_child(head)


static func _mountains(parent: Node3D) -> void:
	var rock := _material(ROCK)
	var snow := _material(SNOW)
	var sizes := [1.0, 0.8, 0.9]
	var spots := _spots()
	for i in spots.size():
		var s: float = sizes[i]
		parent.add_child(_mesh(_cylinder(0.0, 0.07 * s, 0.12 * s, 7), spots[i] + Vector3(0, 0.06 * s, 0), rock))
		parent.add_child(_mesh(_cylinder(0.0, 0.026 * s, 0.045 * s, 7), spots[i] + Vector3(0, 0.0975 * s, 0), snow))


static func _desert(parent: Node3D) -> void:
	var green := _material(CACTUS)
	var cactus := Node3D.new()
	parent.add_child(cactus)
	var trunk := CapsuleMesh.new()
	trunk.radius = 0.028
	trunk.height = 0.17
	cactus.add_child(_mesh(trunk, Vector3(0, 0.085, 0), green))
	for side in [-1.0, 1.0]:
		var arm := CapsuleMesh.new()
		arm.radius = 0.018
		arm.height = 0.08
		cactus.add_child(_mesh(arm, Vector3(side * 0.045, 0.1 + side * 0.012, 0), green))
	var rock := _material(DESERT_GROUND.darkened(0.2))
	for spot in _spots(0.22, 60.0):
		var stone := _mesh(_sphere(0.025), spot + Vector3(0, 0.01, 0), rock)
		stone.scale = Vector3(1.3, 0.6, 1.0)
		parent.add_child(stone)


static func _mesh(mesh: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	node.material_override = material
	return node


static func _cylinder(top: float, bottom: float, height: float, segments := 12) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	# Sin brillo: con especular toon, las caras planas se ven como una mancha blanca.
	material.metallic_specular = 0.0
	return material


## Mar bajo la isla: disco azul que asoma alrededor de las casillas, con los puertos encima.
static func build_sea(radius: float) -> MeshInstance3D:
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = PieceKit.rounded_disc(radius, 0.05, 0.02, 48)
	sea.material_override = _material(SEA)
	return sea
