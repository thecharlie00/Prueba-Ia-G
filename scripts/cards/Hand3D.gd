class_name Hand3D
extends SubViewportContainer
## Mano de cartas en 3D, sujeta delante de la cámara en abanico, como si el jugador la
## tuviera en la mano (docs/ARTE.md). Se dibuja en su propio mundo 3D encima de la escena,
## así que nunca atraviesa la mesa y no depende de dónde esté la cámara de juego.
##
## Cada carta es un Dictionary:
##   {"face": "playing", "text": "A ♠"}               carta de baraja (inglesa o española)
##   {"face": "resource", "resource": 0..4}           recurso de la isla
##   {"face": "development", "text": "Caballero"}     carta de desarrollo
## Claves opcionales: "disabled" (no se puede pulsar ni se levanta) y "dim" (más oscura).
## Al pulsar una carta habilitada se emite item_pressed(índice).

signal item_pressed(index: int)

const CARD := Vector3(0.68, 0.03, 0.96)
const DEPTH := 6.5
const SUIT_COLORS := {
	"♠": Palette.INK, "♣": Palette.INK, "♥": Palette.CORAL, "♦": Palette.CORAL,
	"O": Color("c98a00"), "C": Palette.CORAL, "E": Palette.PLAYER_BLUE, "B": Color("8a4f2a"),
}
const SUIT_GLYPHS := {"O": "oros", "C": "copas", "E": "espadas", "B": "bastos"}

var items: Array = []
var faces_hidden := false
## Altura del abanico en pantalla: 0 = centro de la carta en el borde inferior.
var lift := 0.0
## Desplazamiento horizontal del abanico (unidades de la mano; positivo = a la derecha),
## para no quedar debajo de un panel lateral.
var shift := 0.0

var _viewport: SubViewport
var _camera: Camera3D
var _cards_root: Node3D
var _cards: Array[Node3D] = []
var _hovered := -1
var _signature := ""
var _icon_textures := {}


func _init() -> void:
	name = "Hand3D"
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport = SubViewport.new()
	_viewport.name = "HandViewport"
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Palette.LAVENDER
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_camera.environment = environment
	_viewport.add_child(_camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	_viewport.add_child(light)
	_cards_root = Node3D.new()
	_cards_root.name = "Cards"
	_viewport.add_child(_cards_root)


func set_items(new_items: Array) -> void:
	var signature := str(new_items) + str(faces_hidden)
	items = new_items.duplicate(true)
	if signature == _signature:
		return
	_signature = signature
	_rebuild()


func set_faces_hidden(value: bool) -> void:
	faces_hidden = value
	_signature = ""
	set_items(items)


func card_nodes() -> Array[Node3D]:
	return _cards


## Índice de la carta bajo un punto de la pantalla (la de más arriba), o -1.
func card_at(point: Vector2) -> int:
	var local := point - get_global_rect().position
	for i in range(_cards.size() - 1, -1, -1):
		var card := _cards[i]
		var half := Vector2(CARD.x, CARD.z) * 0.5
		var polygon := PackedVector2Array()
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var world := card.global_transform * Vector3(corner.x * half.x, 0.0, corner.y * half.y)
			polygon.append(_camera.unproject_position(world))
		if Geometry2D.is_point_in_polygon(local, polygon):
			return i
	return -1


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _cards.is_empty():
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if _blocked_by_gui():
		return
	var index := card_at(event.position)
	if index < 0:
		return
	get_viewport().set_input_as_handled()
	if not bool(items[index].get("disabled", false)):
		item_pressed.emit(index)


func _process(delta: float) -> void:
	var hovered := -1
	if is_visible_in_tree() and not _blocked_by_gui():
		hovered = card_at(get_viewport().get_mouse_position())
		if hovered >= 0 and bool(items[hovered].get("disabled", false)):
			hovered = -1
	_hovered = hovered
	var weight := clampf(delta * 14.0, 0.0, 1.0)
	for i in _cards.size():
		var rest: Transform3D = _cards[i].get_meta("rest")
		if i == _hovered:
			rest.origin += Vector3(0, 0.32, 0.12)
		_cards[i].transform = _cards[i].transform.interpolate_with(rest, weight)


# Un control 2D bajo el ratón (paneles, botones de la barra) tiene prioridad sobre la mano.
func _blocked_by_gui() -> bool:
	var control := get_viewport().gui_get_hovered_control()
	return control != null and control != self


func _rebuild() -> void:
	for card in _cards:
		_cards_root.remove_child(card)
		card.queue_free()
	_cards.clear()
	var count := items.size()
	if count == 0:
		return
	# Abanico: cartas sobre un arco, giradas desde abajo y cada una un poco más cerca de la
	# cámara que la anterior para que se superpongan en orden.
	var spacing := minf(0.5, 6.0 / count)
	var spread := minf(26.0, 3.2 * count)
	var half_height := DEPTH * tan(deg_to_rad(_camera.fov * 0.5))
	var base_y := -half_height + 0.28 + lift
	for i in count:
		var t := (float(i) / (count - 1) - 0.5) * 2.0 if count > 1 else 0.0
		var angle := deg_to_rad(-t * spread * 0.5)
		var x := (i - (count - 1) * 0.5) * spacing + shift
		var card := _make_card(items[i])
		card.name = "Card%d" % i
		var basis := Basis(Vector3.FORWARD, angle) * Basis(Vector3.RIGHT, PI / 2.0)
		var origin := Vector3(x, base_y - absf(t) * absf(t) * 0.12, -DEPTH + i * 0.012)
		var rest := Transform3D(basis, origin)
		card.set_meta("rest", rest)
		card.transform = rest
		_cards_root.add_child(card)
		_cards.append(card)


func _make_card(item: Dictionary) -> Node3D:
	var card := Node3D.new()
	var face_kind := str(item.get("face", "playing"))
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = PieceKit.rounded_slab(CARD, 0.08, 0.012)
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.PAPER if not faces_hidden else Palette.CORAL
	body.material_override = material
	card.add_child(body)
	# Ilustración de la carta (CardArt) sobre la cara que mira a la cámara.
	var art: Texture2D
	if faces_hidden:
		art = CardArt.texture("back")
	elif face_kind == "resource":
		art = CardArt.texture("resource", int(item.get("resource", 0)))
	elif face_kind == "development":
		art = CardArt.texture("development", IslandRules.DEV_NAMES.find(str(item.get("text", ""))))
	else:
		art = CardArt.texture("playing", str(item.get("text", "")))
	var face := MeshInstance3D.new()
	face.name = "Face"
	var quad := QuadMesh.new()
	quad.size = Vector2(CARD.x, CARD.z)
	face.mesh = quad
	face.rotation_degrees.x = -90
	face.position.y = CARD.y * 0.5 + 0.003
	var face_material := StandardMaterial3D.new()
	face_material.albedo_texture = art
	face_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	face_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	face_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if bool(item.get("dim", false)):
		face_material.albedo_color = Color(0.62, 0.62, 0.68)
	face.material_override = face_material
	card.add_child(face)
	if bool(item.get("dim", false)) and not faces_hidden:
		card.add_child(_text("nueva", 60, Palette.CORAL, Vector3(0.1, 0.002, -0.36)))
	return card


func _text(value: String, size: int, color: Color, offset: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.font_size = size
	label.pixel_size = 0.0022
	label.modulate = color
	label.outline_size = 0
	label.rotation_degrees.x = -90
	label.position = offset + Vector3(0, CARD.y * 0.5 + 0.006, 0)
	if has_node("/root/ToonStyle"):
		label.font = get_node("/root/ToonStyle").DISPLAY_FONT
	return label


# Icono del recurso dibujado una vez en una textura (ResourceIcon) y compartido.
func _icon_texture(resource: int) -> Texture2D:
	if _icon_textures.has(resource):
		return _icon_textures[resource]
	var canvas := SubViewport.new()
	canvas.size = Vector2i(256, 256)
	canvas.transparent_bg = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ONCE
	var icon := ResourceIcon.new()
	icon.resource = resource
	icon.size = Vector2(256, 256)
	canvas.add_child(icon)
	# Dentro del mundo de la mano: un SubViewport hijo directo del contenedor se pintaría encima.
	_viewport.add_child(canvas)
	_icon_textures[resource] = canvas.get_texture()
	return _icon_textures[resource]
