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


# --- Construcción (las piezas están en HomeDecor, compartidas con la habitación) ------

func _build_room() -> void:
	HomeDecor.build_room(_viewport, accent_color)


func _build_table() -> void:
	HomeDecor.build_table(_viewport)


func _build_pieces() -> void:
	HomeDecor.build_pieces(_viewport)


# Dos muñecos de arcilla sentados a la mesa.
func _build_players() -> void:
	for seat in [
		[Vector3(-1.5, 0, -2.9), Palette.PLAYER_BLUE, 0.45],
		[Vector3(2.3, 0, -2.3), Palette.PLAYER_RED, -0.7],
	]:
		var root := HomeDecor.make_meeple(seat[1])
		root.position = seat[0]
		root.rotation.y = float(seat[2])
		root.set_meta("rest_y", 0.0)
		_viewport.add_child(root)
		_bobbers.append(root)


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
