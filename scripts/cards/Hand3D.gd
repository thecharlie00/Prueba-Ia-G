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
## Al pulsar una carta habilitada se emite item_pressed(índice). Con reorderable, una carta
## arrastrada a otro hueco del abanico emite item_moved(origen, destino) en vez de pulsarse.

signal item_pressed(index: int)
signal item_moved(from: int, to: int)

const CARD := Vector3(0.68, 0.03, 0.96)
const DEPTH := 6.5
## Tamaño de la carta bajo el ratón respecto a las demás.
const ZOOM := 1.9
const SUIT_COLORS := {
	"♠": Palette.INK, "♣": Palette.INK, "♥": Palette.CORAL, "♦": Palette.CORAL,
	"O": Color("c98a00"), "C": Palette.CORAL, "E": Palette.PLAYER_BLUE, "B": Color("8a4f2a"),
}
const SUIT_GLYPHS := {"O": "oros", "C": "copas", "E": "espadas", "B": "bastos"}

var items: Array = []
var faces_hidden := false
## Altura del abanico en pantalla: 0 = centro de la carta en el borde inferior.
var lift := 0.0
## Se pueden reordenar arrastrando (la pulsación se emite al soltar, si no hubo arrastre).
var reorderable := false
## Píxeles que tiene que moverse el ratón para que la pulsación cuente como arrastre.
const DRAG_THRESHOLD := 18.0
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
var _press_index := -1
var _press_position := Vector2.ZERO
var _dragging := false
var _last_drag_x := 0.0
var _drag_tilt := 0.0
var _hover_phase := 0.0


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
	# La carta ampliada está delante de todas: se comprueba primero.
	var order: Array[int] = []
	if _hovered >= 0 and _hovered < _cards.size():
		order.append(_hovered)
	for i in range(_cards.size() - 1, -1, -1):
		if i != _hovered:
			order.append(i)
	for i in order:
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
		_press_index = -1
		return
	if reorderable and _press_index >= 0:
		if event is InputEventMouseMotion:
			if not _dragging and event.position.distance_to(_press_position) > DRAG_THRESHOLD:
				_dragging = true
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			get_viewport().set_input_as_handled()
			finish_press(event.position)
			return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if _blocked_by_gui():
		return
	var index := card_at(event.position)
	if index < 0:
		return
	get_viewport().set_input_as_handled()
	if reorderable:
		begin_press(index, event.position)
	elif not bool(items[index].get("disabled", false)):
		item_pressed.emit(index)


## Empieza una pulsación sobre una carta (público para los tests).
func begin_press(index: int, point: Vector2) -> void:
	_press_index = index
	_press_position = point
	_dragging = false


## Termina la pulsación: si la carta se arrastró, va al hueco más cercano; si no, se pulsa.
func finish_press(point: Vector2) -> void:
	var index := _press_index
	var dragged := _dragging or point.distance_to(_press_position) > DRAG_THRESHOLD
	_press_index = -1
	_dragging = false
	if index < 0 or index >= _cards.size():
		return
	if dragged:
		var target := slot_at(point, index)
		if target != index:
			item_moved.emit(index, target)
	elif not bool(items[index].get("disabled", false)):
		item_pressed.emit(index)


## Hueco del abanico donde caería la carta arrastrada si se suelta en ese punto.
func slot_at(point: Vector2, dragged: int) -> int:
	var x := _pointer_x(point)
	var slot := 0
	for i in _cards.size():
		if i == dragged:
			continue
		var rest: Transform3D = _cards[i].get_meta("rest")
		if rest.origin.x < x:
			slot += 1
	return slot


# Posición horizontal del ratón en el mundo de la mano, a la profundidad de las cartas.
func _pointer_x(point: Vector2) -> float:
	var local := point - get_global_rect().position
	return _camera.project_position(local, DEPTH).x


func _process(delta: float) -> void:
	var hovered := -1
	var mouse_pos := get_viewport().get_mouse_position()
	if is_visible_in_tree() and not _blocked_by_gui():
		# También las cartas que no se pueden usar ahora se amplían para leerlas.
		hovered = card_at(mouse_pos)
	if _dragging:
		hovered = -1
	if hovered != _hovered and hovered >= 0:
		var sfx := get_node_or_null("/root/Sfx")
		if sfx != null:
			sfx.play("ui", -8.0)
	_hovered = hovered
	var style := get_node_or_null("/root/ToonStyle")
	var reduce: bool = style != null and style.get("reduce_motion") == true
	if not reduce:
		_hover_phase += delta * 4.2
	var weight := clampf(delta * 15.0, 0.0, 1.0)
	var cur_drag_x := _pointer_x(mouse_pos) if _dragging else 0.0
	if _dragging and delta > 0.0001 and not reduce:
		var vel_x := clampf((cur_drag_x - _last_drag_x) / delta, -12.0, 12.0)
		_drag_tilt = lerpf(_drag_tilt, -vel_x * 0.032, clampf(delta * 18.0, 0.0, 1.0))
	else:
		_drag_tilt = lerpf(_drag_tilt, 0.0, clampf(delta * 14.0, 0.0, 1.0))
	_last_drag_x = cur_drag_x

	for i in _cards.size():
		var target: Transform3D = _cards[i].get_meta("rest")
		if i == _hovered:
			target = _zoomed(target, mouse_pos, reduce)
		elif _dragging and i == _press_index:
			# La carta arrastrada sigue al ratón, levantada, delante e inclinada por la inercia.
			target.origin.x = cur_drag_x
			target.origin.y += 0.32
			target.origin.z += 0.52
			if not reduce:
				target.basis = Basis(Vector3.FORWARD, _drag_tilt) * target.basis
		elif _hovered >= 0 and not reduce:
			# Las cartas vecinas se abren ligeramente como un abanico vivo (estilo Hearthstone).
			var dist := i - _hovered
			var push := (0.11 / float(absi(dist))) * signf(float(dist))
			target.origin.x += push
		_cards[i].transform = _cards[i].transform.interpolate_with(target, weight)


## Carta ampliada: al doble de tamaño, elevada y con inclinación magnética hacia el cursor.
func _zoomed(rest: Transform3D, mouse_pos: Vector2, reduce: bool) -> Transform3D:
	var origin := rest.origin + Vector3(0, CARD.z * (ZOOM - 1.0) * 0.5 + 0.35, 0.9)
	var basis := Basis(Vector3.RIGHT, PI / 2.0)
	if not reduce:
		var local_mouse := mouse_pos - get_global_rect().position
		var center_2d := _camera.unproject_position(origin)
		var offset := (local_mouse - center_2d) / Vector2(130.0, 175.0)
		var tilt_x := clampf(offset.y, -1.0, 1.0) * deg_to_rad(8.5)
		var tilt_z := clampf(-offset.x, -1.0, 1.0) * deg_to_rad(10.0)
		basis = Basis(Vector3.FORWARD, tilt_z) * Basis(Vector3.RIGHT, PI / 2.0 + tilt_x)
		origin.y += sin(_hover_phase) * 0.018
	return Transform3D(basis.scaled(Vector3.ONE * ZOOM), origin)


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
