class_name MenuBackdrop
extends Control
## Fondo de todos los menús (docs/ARTE.md): un diorama 3D de la sala de juegos, con la mesa
## puesta, dos muñecos de arcilla sentados y la lámpara encendida, mientras la cámara gira
## despacio. Encima, un velo oscuro para que el texto se lea: de lado («side», la portada deja
## ver la mesa a la derecha) o entero («full», menús con tarjetas por toda la pantalla).
##
## Usa el mismo estilo de materiales y luz que las mesas (ToonStyle actúa sobre sus nodos), así
## que el menú enseña el aspecto real del juego. Con «Reducir animaciones» la cámara no gira.

const SIDE := "side"
const FULL := "full"
const VEIL := Color("1b1733")
const TABLE_Y := 0.98

## Color de acento del menú: tiñe la pantalla de la lámpara.
var accent_color := Palette.SUN
var layout := FULL: set = set_layout

var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _veil: TextureRect
var _bobbers: Array[Node3D] = []
var _time := 0.0


func _init() -> void:
	name = "MenuBackdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var container := SubViewportContainer.new()
	container.name = "Diorama"
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.handle_input_locally = false
	_viewport.gui_disable_input = true
	container.add_child(_viewport)
	_build_room()
	_build_table()
	_build_pieces()
	_build_players()
	_build_camera()
	_veil = TextureRect.new()
	_veil.name = "Veil"
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.stretch_mode = TextureRect.STRETCH_SCALE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)
	set_layout(layout)


func set_layout(value: String) -> void:
	layout = SIDE if value == SIDE else FULL
	if _veil == null:
		return
	var gradient := Gradient.new()
	if layout == SIDE:
		gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.75, 1.0])
		gradient.colors = PackedColorArray([
			Color(VEIL, 0.94), Color(VEIL, 0.82), Color(VEIL, 0.22), Color(VEIL, 0.08),
		])
	else:
		gradient.offsets = PackedFloat32Array([0.0, 1.0])
		gradient.colors = PackedColorArray([Color(VEIL, 0.84), Color(VEIL, 0.78)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	_veil.texture = texture
	if _camera != null:
		# De lado, la mesa se va a la derecha de la pantalla para dejar sitio al texto.
		_camera.h_offset = -1.9 if layout == SIDE else 0.0


func _process(delta: float) -> void:
	var style := get_node_or_null("/root/ToonStyle")
	if style != null and style.get("reduce_motion") == true:
		return
	_time += delta
	if _pivot != null:
		_pivot.rotation.y = deg_to_rad(-18.0) + sin(_time * 0.16) * deg_to_rad(11.0)
	for i in _bobbers.size():
		var node := _bobbers[i]
		node.position.y = float(node.get_meta("rest_y")) + sin(_time * 1.3 + i * 1.9) * 0.025


# --- Construcción -------------------------------------------------------------

func _add(mesh: Mesh, position: Vector3, color: Color, parent: Node = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	node.material_override = material
	(parent if parent != null else _viewport).add_child(node)
	return node


func _build_room() -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	_viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	_viewport.add_child(sun)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(40, 40)
	_add(floor_mesh, Vector3.ZERO, Palette.FLOOR)
	_add(PieceKit.rounded_disc(4.4, 0.04, 0.018, 96), Vector3(0, 0.02, 0), RoomDecor.RUG_EDGE)
	_add(PieceKit.rounded_disc(4.1, 0.05, 0.018, 96), Vector3(0, 0.025, 0), RoomDecor.RUG)
	# Dos paredes que cierran el fondo sea cual sea el giro de la cámara.
	for wall in [[Vector3(0, 4.5, -8), 0.0], [Vector3(-9, 4.5, 0), PI / 2.0], [Vector3(9, 4.5, 0), -PI / 2.0]]:
		var quad := QuadMesh.new()
		quad.size = Vector2(22, 9)
		var plane := _add(quad, wall[0], RoomDecor.WALL)
		plane.rotation.y = wall[1]
		var strip := QuadMesh.new()
		strip.size = Vector2(22, 0.6)
		var trim := _add(strip, Vector3(0, -4.2, 0.02), RoomDecor.TRIM, plane)
		trim.position = Vector3(0, -4.2, 0.02)
	# Lámpara colgante: pantalla del color del menú y luz cálida sobre el tapete.
	var shade := CylinderMesh.new()
	shade.top_radius = 0.22
	shade.bottom_radius = 0.75
	shade.height = 0.55
	shade.radial_segments = 40
	_add(shade, Vector3(0, 3.6, 0), accent_color.lerp(Palette.PAPER, 0.25))
	var cord := CylinderMesh.new()
	cord.top_radius = 0.02
	cord.bottom_radius = 0.02
	cord.height = 5.0
	_add(cord, Vector3(0, 6.35, 0), Palette.INK.lightened(0.3))
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 3.1, 0)
	glow.light_color = RoomDecor.WARM_SPOT
	glow.light_energy = 1.4
	glow.omni_range = 6.0
	_viewport.add_child(glow)


func _build_table() -> void:
	_add(PieceKit.rounded_disc(2.5, 0.2, 0.08, 96), Vector3(0, TABLE_Y - 0.12, 0), Palette.WOOD)
	_add(PieceKit.rounded_disc(2.2, 0.04, 0.015, 96), Vector3(0, TABLE_Y - 0.01, 0), Palette.FELT)
	var leg := CylinderMesh.new()
	leg.top_radius = 0.3
	leg.bottom_radius = 0.42
	leg.height = 0.8
	leg.radial_segments = 32
	_add(leg, Vector3(0, 0.45, 0), Palette.WOOD.darkened(0.12))
	_add(PieceKit.rounded_disc(1.0, 0.1, 0.04, 48), Vector3(0, 0.07, 0), Palette.WOOD.darkened(0.12))


func _build_pieces() -> void:
	# Dos dados.
	_die(Vector3(-0.35, TABLE_Y + 0.19, 0.55), 24.0)
	_die(Vector3(0.2, TABLE_Y + 0.19, 0.95), -31.0)
	# Pilas de fichas con los colores de jugador.
	var colors := [Palette.PLAYER_RED, Palette.PLAYER_BLUE, Palette.PLAYER_YELLOW, Palette.PLAYER_GREEN]
	for stack in 4:
		var base := Vector3(-1.35 + stack * 0.3, TABLE_Y + 0.045, -0.2 + (stack % 2) * 0.32)
		for level in 2 + stack % 3:
			_add(PieceKit.rounded_disc(0.14, 0.07, 0.025, 32), base + Vector3(0, level * 0.072, 0), colors[stack])
	# Piezas de ajedrez.
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
		_viewport.add_child(model)
	# Abanico de cartas.
	var labels := ["A ♠", "K ♥", "7 O", "1 E"]
	for i in labels.size():
		var card := _add(
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


func _die(position: Vector3, turn: float) -> void:
	var die := _add(PieceKit.rounded_box(Vector3(0.36, 0.36, 0.36), 0.07), position, Palette.PAPER)
	die.rotation.y = deg_to_rad(turn)
	var pips := StandardMaterial3D.new()
	pips.albedo_color = Palette.INK.lightened(0.12)
	# Cara de arriba (5) y dos laterales (3 y 2): suficiente desde cualquier lado de la cámara.
	var faces := [
		[Basis.IDENTITY, [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)]],
		[Basis(Vector3.RIGHT, PI / 2.0), [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)]],
		[Basis(Vector3.FORWARD, PI / 2.0), [Vector2(-1, -1), Vector2(1, 1)]],
		[Basis(Vector3.RIGHT, -PI / 2.0), [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]],
		[Basis(Vector3.FORWARD, -PI / 2.0), [Vector2(0, 0)]],
	]
	for face in faces:
		for spot in face[1]:
			var pip := MeshInstance3D.new()
			pip.mesh = PieceKit.dot(0.036, 0.012)
			pip.material_override = pips
			pip.transform = Transform3D(face[0], face[0] * Vector3(spot.x * 0.09, 0.18, spot.y * 0.09))
			die.add_child(pip)


# Dos muñecos de arcilla sentados a la mesa: cuerpo de cápsula, cabeza redonda y ojos grandes.
func _build_players() -> void:
	for seat in [
		[Vector3(-1.5, 0, -2.9), Palette.PLAYER_BLUE, 0.45],
		[Vector3(2.3, 0, -2.3), Palette.PLAYER_RED, -0.7],
	]:
		var root := Node3D.new()
		root.position = seat[0]
		root.rotation.y = float(seat[2])
		root.set_meta("rest_y", 0.0)
		_viewport.add_child(root)
		_bobbers.append(root)
		var color: Color = seat[1]
		var body := CapsuleMesh.new()
		body.radius = 0.5
		body.height = 1.5
		_add(body, Vector3(0, 0.95, 0), color, root)
		var head := SphereMesh.new()
		head.radius = 0.46
		head.height = 0.84
		var head_node := _add(head, Vector3(0, 1.95, 0), color.lightened(0.08), root)
		for side in [-1.0, 1.0]:
			var eye := SphereMesh.new()
			eye.radius = 0.11
			eye.height = 0.22
			var white := _add(eye, Vector3(side * 0.17, 0.06, 0.38), Palette.PAPER, head_node)
			var pupil := SphereMesh.new()
			pupil.radius = 0.055
			pupil.height = 0.11
			_add(pupil, Vector3(side * -0.015, -0.01, 0.075), Palette.INK, white)
			var hand := SphereMesh.new()
			hand.radius = 0.17
			hand.height = 0.34
			_add(hand, Vector3(side * 0.62, 1.15, 0.55), Palette.PAPER, root)


func _build_camera() -> void:
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, 1.1, 0)
	_pivot.rotation.y = deg_to_rad(-18.0)
	_viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 36.0
	_camera.position = Vector3(0, 3.3, 8.2)
	_pivot.add_child(_camera)
	# Mira al centro del tapete (aún no está en el árbol: se inclina a mano).
	_camera.rotation.x = -atan2(_camera.position.y - 0.1, _camera.position.z)
	_camera.current = true
