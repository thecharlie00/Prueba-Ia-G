class_name HomeDecor
## Piezas de la sala de juegos de Tablerama: la usa el diorama de los menús (MenuBackdrop)
## y la habitación jugable (Home). Todo se construye en código, en el estilo de arcilla:
## ToonStyle añade el contorno y el material al entrar cada malla en el árbol.

const TABLE_Y := 0.98
const TABLE_RADIUS := 2.5


static func add_mesh(parent: Node, mesh: Mesh, position: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	node.material_override = material
	parent.add_child(node)
	return node


## Suelo, alfombra, paredes del fondo y lámpara colgante sobre la mesa.
static func build_room(parent: Node, accent: Color) -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	parent.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	parent.add_child(sun)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(40, 40)
	add_mesh(parent, floor_mesh, Vector3.ZERO, Palette.FLOOR)
	add_mesh(parent, PieceKit.rounded_disc(4.4, 0.04, 0.018, 96), Vector3(0, 0.02, 0), RoomDecor.RUG_EDGE)
	add_mesh(parent, PieceKit.rounded_disc(4.1, 0.05, 0.018, 96), Vector3(0, 0.025, 0), RoomDecor.RUG)
	for wall in [[Vector3(0, 4.5, -8), 0.0], [Vector3(-9, 4.5, 0), PI / 2.0], [Vector3(9, 4.5, 0), -PI / 2.0]]:
		var quad := QuadMesh.new()
		quad.size = Vector2(22, 9)
		var plane := add_mesh(parent, quad, wall[0], RoomDecor.WALL)
		plane.rotation.y = wall[1]
		var strip := QuadMesh.new()
		strip.size = Vector2(22, 0.6)
		add_mesh(plane, strip, Vector3(0, -4.2, 0.02), RoomDecor.TRIM)
	var shade := CylinderMesh.new()
	shade.top_radius = 0.22
	shade.bottom_radius = 0.75
	shade.height = 0.55
	shade.radial_segments = 40
	add_mesh(parent, shade, Vector3(0, 3.6, 0), accent.lerp(Palette.PAPER, 0.25))
	var cord := CylinderMesh.new()
	cord.top_radius = 0.02
	cord.bottom_radius = 0.02
	cord.height = 5.0
	add_mesh(parent, cord, Vector3(0, 6.35, 0), Palette.INK.lightened(0.3))
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 3.1, 0)
	glow.light_color = RoomDecor.WARM_SPOT
	glow.light_energy = 1.4
	glow.omni_range = 6.0
	parent.add_child(glow)


static func build_table(parent: Node) -> void:
	add_mesh(parent, PieceKit.rounded_disc(TABLE_RADIUS, 0.2, 0.08, 96), Vector3(0, TABLE_Y - 0.12, 0), Palette.WOOD)
	add_mesh(parent, PieceKit.rounded_disc(2.2, 0.04, 0.015, 96), Vector3(0, TABLE_Y - 0.01, 0), Palette.FELT)
	var leg := CylinderMesh.new()
	leg.top_radius = 0.3
	leg.bottom_radius = 0.42
	leg.height = 0.8
	leg.radial_segments = 32
	add_mesh(parent, leg, Vector3(0, 0.45, 0), Palette.WOOD.darkened(0.12))
	add_mesh(parent, PieceKit.rounded_disc(1.0, 0.1, 0.04, 48), Vector3(0, 0.07, 0), Palette.WOOD.darkened(0.12))


## Dados, fichas, piezas de ajedrez y un abanico de cartas sobre el tapete.
static func build_pieces(parent: Node) -> void:
	parent.add_child(make_die(Vector3(-0.35, TABLE_Y + 0.19, 0.55), 24.0))
	parent.add_child(make_die(Vector3(0.2, TABLE_Y + 0.19, 0.95), -31.0))
	var colors := [Palette.PLAYER_RED, Palette.PLAYER_BLUE, Palette.PLAYER_YELLOW, Palette.PLAYER_GREEN]
	for stack in 4:
		var base := Vector3(-1.35 + stack * 0.3, TABLE_Y + 0.045, -0.2 + (stack % 2) * 0.32)
		for level in 2 + stack % 3:
			add_mesh(parent, PieceKit.rounded_disc(0.14, 0.07, 0.025, 32), base + Vector3(0, level * 0.072, 0), colors[stack])
	var light := StandardMaterial3D.new()
	light.albedo_color = Palette.PIECE_LIGHT
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Palette.PIECE_DARK
	for piece in [
		[ChessRules.KING, true, Vector3(0.95, TABLE_Y, -0.75), 1.9],
		[ChessRules.KNIGHT, false, Vector3(1.4, TABLE_Y, -0.2), 1.9],
		[ChessRules.PAWN, true, Vector3(0.55, TABLE_Y, -0.3), 1.7],
		[ChessRules.ROOK, false, Vector3(0.25, TABLE_Y, -1.2), 1.8],
	]:
		var model := ChessPieceModel.create(piece[0], piece[1], light if piece[1] else dark)
		model.position = piece[2]
		model.scale = Vector3.ONE * float(piece[3])
		model.rotation.y = 0.7
		parent.add_child(model)
	var labels := ["A ♠", "K ♥", "7 O", "1 E"]
	for i in labels.size():
		var card := add_mesh(
			parent,
			PieceKit.rounded_slab(Vector3(0.46, 0.012, 0.66), 0.05, 0.004),
			Vector3(0.75 + i * 0.2, TABLE_Y + 0.012 + i * 0.006, 0.9 - i * 0.05),
			Palette.PAPER
		)
		card.rotation.y = deg_to_rad(18.0 - i * 13.0)
		var face := QuadMesh.new()
		face.size = Vector2(0.43, 0.63)
		var art := MeshInstance3D.new()
		art.mesh = face
		art.rotation.x = -PI / 2.0
		art.position.y = 0.0075
		var material := StandardMaterial3D.new()
		material.albedo_texture = CardArt.texture("playing", labels[i])
		art.material_override = material
		card.add_child(art)


## Dado de arcilla de 0,36 con puntos en las caras visibles. Devuelve el nodo sin añadir.
static func make_die(position: Vector3, turn: float, size := 0.36) -> MeshInstance3D:
	var die := MeshInstance3D.new()
	die.mesh = PieceKit.rounded_box(Vector3.ONE * size, size * 0.19)
	die.position = position
	die.rotation.y = deg_to_rad(turn)
	var body := StandardMaterial3D.new()
	body.albedo_color = Palette.PAPER
	die.material_override = body
	var pips := StandardMaterial3D.new()
	pips.albedo_color = Palette.INK.lightened(0.12)
	var k := size / 0.36
	var faces := [
		[Basis.IDENTITY, [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)]],
		[Basis(Vector3.RIGHT, PI / 2.0), [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)]],
		[Basis(Vector3.FORWARD, PI / 2.0), [Vector2(-1, -1), Vector2(1, 1)]],
		[Basis(Vector3.RIGHT, -PI / 2.0), [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]],
		[Basis(Vector3.FORWARD, -PI / 2.0), [Vector2(0, 0)]],
		[Basis(Vector3.RIGHT, PI), [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]],
	]
	for face in faces:
		for spot in face[1]:
			var pip := MeshInstance3D.new()
			pip.mesh = PieceKit.dot(0.036 * k, 0.012 * k)
			pip.material_override = pips
			pip.transform = Transform3D(face[0], face[0] * Vector3(spot.x * 0.09 * k, size * 0.5, spot.y * 0.09 * k))
			die.add_child(pip)
	return die


## Muñeco de arcilla (peón con ojos): cuerpo de cápsula, cabeza redonda y manos.
## Mide unos 2,4 de alto con escala 1. Devuelve la raíz sin añadir.
static func make_meeple(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Meeple"
	var body := CapsuleMesh.new()
	body.radius = 0.5
	body.height = 1.5
	add_mesh(root, body, Vector3(0, 0.95, 0), color).name = "Body"
	var head := SphereMesh.new()
	head.radius = 0.46
	head.height = 0.84
	var head_node := add_mesh(root, head, Vector3(0, 1.95, 0), color.lightened(0.08))
	head_node.name = "Head"
	for side in [-1.0, 1.0]:
		var eye := SphereMesh.new()
		eye.radius = 0.11
		eye.height = 0.22
		var white := add_mesh(head_node, eye, Vector3(side * 0.17, 0.06, 0.38), Palette.PAPER)
		var pupil := SphereMesh.new()
		pupil.radius = 0.055
		pupil.height = 0.11
		add_mesh(white, pupil, Vector3(side * -0.015, -0.01, 0.075), Palette.INK)
		var hand := SphereMesh.new()
		hand.radius = 0.17
		hand.height = 0.34
		add_mesh(root, hand, Vector3(side * 0.62, 1.15, 0.55), Palette.PAPER).name = "Hand"
	return root


## Cambia el color de un muñeco hecho con make_meeple.
static func tint_meeple(meeple: Node3D, color: Color) -> void:
	var body := meeple.get_node_or_null("Body") as MeshInstance3D
	var head := meeple.get_node_or_null("Head") as MeshInstance3D
	for part in [[body, color], [head, color.lightened(0.08)]]:
		var mesh := part[0] as MeshInstance3D
		if mesh == null:
			continue
		var material := StandardMaterial3D.new()
		material.albedo_color = part[1]
		mesh.material_override = material
		var style := mesh.get_tree().root.get_node_or_null("ToonStyle") if mesh.is_inside_tree() else null
		if style != null and style.has_method("restyle"):
			style.restyle(mesh)
