class_name Home
extends Node3D
## La habitación de juegos: el menú principal de Tablerama, jugable. El peón de arcilla se
## mueve por la sala y cada mueble es una opción: la mesa con los bots, la estantería de
## juegos, la pizarra del tutorial, la puerta de las salas online, el taller del editor, el
## espejo (color del peón), el tocadiscos (sonido) y el corcho (ajustes). Tab abre el menú
## clásico y Esc los ajustes, para quien prefiera no caminar.

const SCENE_PATH := "res://scenes/Home.tscn"
const SCENES := {
	"mesa": "res://scenes/BotSelect.tscn",
	"estanteria": "res://scenes/Menu.tscn",
	"pizarra": "res://scenes/Main.tscn",
	"puerta": "res://scenes/Lobby.tscn",
	"taller": "res://scenes/game_creator/GameCreatorEditor.tscn",
}
const CLASSIC_PATH := "res://scenes/ModeSelect.tscn"
const SPAWN := Vector3(0, 0, 3.75)
const CAMERA_OFFSET := Vector3(0, 9.4, 12.6)
## Capas de física: 1 estático, 2 peón, 3 juguetes, 4 objetos para el rayo del ratón.
const LAYER_STATIC := 1
const LAYER_TOYS := 1 << 2
const LAYER_PICK := 1 << 3

## Último objeto usado: al volver a la habitación, el peón aparece junto a él.
static var last_item_id := ""
## La primera vez de la sesión, la cámara baja desde arriba hasta la sala.
static var _intro_done := false

var pawn: HomePawn
var camera: Camera3D
var items: Array[Interactable] = []
var nearest: Interactable
var settings_panel: Control
var _prompt: Button
var _toast: Label
var _toast_timer := 0.0
var _pending: Interactable
var _bots: Array[Node3D] = []
var _time := 0.0
var _sound_check: CheckButton
var _fullscreen_check: CheckButton
var _classic_check: CheckButton
var _report_btn: Button
var _jukebox_label: Label3D
var _leaving := false


func _ready() -> void:
	HomeDecor.build_room(self, Palette.SUN)
	HomeDecor.build_table(self)
	HomeDecor.build_pieces(self)
	_build_collision()
	_build_bots()
	_build_furniture()
	_build_toys()
	pawn = HomePawn.new()
	pawn.name = "Pawn"
	pawn.position = SPAWN
	pawn.rotation.y = PI
	for item in items:
		if item.id == last_item_id and item.id != "mesa":
			pawn.position = item.approach
			var to := item.position - item.approach
			pawn.rotation.y = atan2(to.x, to.z)
	add_child(pawn)
	pawn.arrived.connect(_on_pawn_arrived)
	camera = Camera3D.new()
	camera.name = "HomeCamera"
	camera.fov = 40.0
	add_child(camera)
	camera.current = true
	_place_camera(1.0)
	if not _intro_done and not _reduce_motion():
		camera.position += Vector3(0, 7.0, 4.0)
	_intro_done = true
	_build_ui()
	var locale := get_node_or_null("/root/Locale")
	if locale != null and locale.has_signal("language_changed"):
		locale.language_changed.connect(func(_code: String) -> void: _refresh_texts())


# --- Mundo ---------------------------------------------------------------------

func _static_box(size: Vector3, center: Vector3, rotation_y := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_STATIC
	body.collision_mask = 0
	body.position = center
	body.rotation.y = rotation_y
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	return body


func _build_collision() -> void:
	# Ojo: no se llama «Floor», que es el nombre con el que ToonStyle monta la sala de las mesas.
	_static_box(Vector3(40, 1, 40), Vector3(0, -0.5, 0)).name = "HomeFloor"
	_static_box(Vector3(20, 6, 0.6), Vector3(0, 3, -8.3))
	_static_box(Vector3(0.6, 6, 20), Vector3(-9.3, 3, 0))
	_static_box(Vector3(0.6, 6, 20), Vector3(9.3, 3, 0))
	_static_box(Vector3(20, 6, 0.6), Vector3(0, 3, 7.4))  # borde invisible del diorama
	var table := StaticBody3D.new()
	table.collision_layer = LAYER_STATIC
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = HomeDecor.TABLE_RADIUS + 0.05
	cylinder.height = 2.0
	shape.shape = cylinder
	shape.position.y = 0.0
	table.add_child(shape)
	add_child(table)


func _build_bots() -> void:
	for seat in [
		[Vector3(-1.6, 0, -2.9), Palette.PLAYER_BLUE, 0.5],
		[Vector3(2.35, 0, -2.25), Palette.PLAYER_RED, -0.75],
	]:
		var bot := HomeDecor.make_meeple(seat[1])
		bot.position = seat[0]
		bot.rotation.y = float(seat[2])
		add_child(bot)
		_bots.append(bot)


func _sign(text: String, position: Vector3, size := 64, color := Palette.PAPER, rotation_y := 0.0) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = MenuStyle.DISPLAY_FONT
	label.font_size = size
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_size = 14
	label.outline_modulate = Palette.INK
	label.position = position
	label.rotation.y = rotation_y
	label.double_sided = false
	add_child(label)
	return label


func _item(id: String, label: String, center: Vector3, approach: Vector3, extent: float, pick: Vector3, height: float) -> Interactable:
	var item := Interactable.new()
	item.name = "Item_" + id
	item.id = id
	item.label = label
	item.position = center
	item.approach = approach
	item.reach = 1.35
	item.set_meta("extent", extent)
	item.label_height = height
	item.set_pick_box(pick, Vector3(0, pick.y * 0.5, 0))
	var edition := get_node_or_null("/root/Edition")
	if SCENES.has(id) and edition != null and edition.has_method("allows"):
		item.locked = not edition.allows(SCENES[id])
	item.used.connect(_on_item_used)
	add_child(item)
	items.append(item)
	return item


func _build_furniture() -> void:
	var wood := Palette.WOOD
	var dark_wood := Palette.WOOD.darkened(0.25)

	# Mesa central: jugar contra los bots que ya están sentados.
	_item("mesa", "Jugar contra bots", Vector3.ZERO, Vector3(0, 0, 3.2), HomeDecor.TABLE_RADIUS, Vector3(5, 1.2, 5), 2.2)

	# Estantería de juegos (fondo, izquierda).
	var shelf := Vector3(-5.2, 0, -7.45)
	HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(3.3, 3.4, 0.12), 0.04), shelf + Vector3(0, 1.7, -0.4), dark_wood)
	for side in [-1.0, 1.0]:
		HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(0.14, 3.4, 0.9), 0.04), shelf + Vector3(side * 1.6, 1.7, 0), dark_wood)
	HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(3.34, 0.14, 0.94), 0.04), shelf + Vector3(0, 3.4, 0), dark_wood)
	var box_colors := [Palette.CORAL, Palette.SUN, Palette.MINT, Color("7cc6fe"), Palette.LAVENDER, Palette.PLAYER_RED, Palette.PLAYER_GREEN, Palette.PAPER]
	for row in 3:
		HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(3.1, 0.09, 0.8), 0.03), shelf + Vector3(0, 0.25 + row * 1.05, 0.06), wood)
		if row == 2:
			continue
		for i in 4:
			var tall := 0.62 + float((row * 4 + i) % 3) * 0.12
			var game_box := HomeDecor.add_mesh(
				self,
				PieceKit.rounded_box(Vector3(0.58, tall, 0.62), 0.05),
				shelf + Vector3(-1.08 + i * 0.72, 0.3 + row * 1.05 + tall * 0.5, 0.12),
				box_colors[(row * 4 + i + row) % box_colors.size()]
			)
			game_box.rotation.z = deg_to_rad(-6.0 if (row + i) % 4 == 3 else 0.0)
	_static_box(Vector3(3.4, 3.4, 1.0), shelf + Vector3(0, 1.7, 0))
	_sign("JUEGOS", shelf + Vector3(0, 3.0, 0.52), 60, Palette.SUN)
	_item("estanteria", "Elegir un juego", shelf, Vector3(-5.2, 0, -5.8), 1.7, Vector3(3.3, 3.4, 1.2), 4.3)

	# Corcho con notas (fondo, centro): ajustes.
	var cork := Vector3(0.4, 0, -7.85)
	HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(2.5, 1.7, 0.14), 0.06), cork + Vector3(0, 2.5, 0), Color("c98f5a"))
	var note_colors := [Palette.SUN, Palette.MINT, Palette.CORAL, Palette.PAPER, Color("7cc6fe")]
	for i in 5:
		var note := HomeDecor.add_mesh(
			self,
			PieceKit.rounded_box(Vector3(0.48, 0.48, 0.03), 0.02),
			cork + Vector3(-0.85 + i * 0.42, 2.3 + float(i % 2) * 0.45, 0.1),
			note_colors[i]
		)
		note.rotation.z = deg_to_rad(-8.0 + float(i * 37 % 16))
	_sign("AJUSTES", cork + Vector3(0, 1.45, 0.2), 52, Palette.PAPER)
	_item("corcho", "Ajustes", cork, Vector3(0.4, 0, -5.9), 1.3, Vector3(2.5, 3.4, 0.6), 4.1)

	# Pizarra con caballete (fondo, derecha): tutorial.
	var board := Vector3(5.0, 0, -7.3)
	for side in [-1.0, 1.0]:
		var leg := HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(0.12, 2.9, 0.12), 0.04), board + Vector3(side * 1.05, 1.45, 0), wood)
		leg.rotation.z = side * deg_to_rad(-4.0)
	HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(2.5, 1.65, 0.12), 0.06), board + Vector3(0, 1.95, 0.08), Color("2f5b4b"))
	var chalk := _sign("Cómo se juega", board + Vector3(0, 2.25, 0.16), 44, Palette.PAPER)
	chalk.outline_size = 0
	var arrow := _sign("→ 3 min", board + Vector3(0, 1.75, 0.16), 36, Palette.SUN)
	arrow.outline_size = 0
	_static_box(Vector3(2.6, 3.0, 0.6), board + Vector3(0, 1.5, 0))
	_item("pizarra", "Tutorial jugable", board, Vector3(5.0, 0, -5.8), 1.3, Vector3(2.6, 3.0, 0.8), 3.6)

	# Puerta de las salas (pared izquierda).
	var door := Vector3(-8.95, 0, -1.6)
	HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(0.2, 3.5, 2.1), 0.05), door + Vector3(0, 1.75, 0), RoomDecor.TRIM)
	HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(0.16, 3.2, 1.75), 0.06), door + Vector3(0.12, 1.62, 0), Palette.CORAL.darkened(0.15))
	var knob := SphereMesh.new()
	knob.radius = 0.09
	knob.height = 0.18
	HomeDecor.add_mesh(self, knob, door + Vector3(0.28, 1.55, 0.6), Palette.SUN)
	_sign("SALAS", door + Vector3(1.0, 3.75, 0), 64, Palette.SUN)
	var door_item := _item("puerta", "Salas online", door, Vector3(-7.7, 0, -1.6), 0.9, Vector3(0.8, 3.4, 2.0), 4.3)
	if door_item.locked:
		_padlock(door + Vector3(0.32, 2.2, 0))

	# Espejo (pared derecha): color del peón.
	var mirror := Vector3(8.92, 0, -4.2)
	var frame := HomeDecor.add_mesh(self, PieceKit.rounded_disc(0.95, 0.1, 0.04, 48), mirror + Vector3(-0.05, 2.0, 0), Palette.SUN.darkened(0.1))
	frame.rotation.z = PI / 2.0
	frame.scale = Vector3(1.0, 1.0, 0.7)
	var glass := HomeDecor.add_mesh(self, PieceKit.rounded_disc(0.82, 0.06, 0.02, 48), mirror + Vector3(-0.12, 2.0, 0), Color("c9d8f2"))
	glass.rotation.z = PI / 2.0
	glass.scale = Vector3(1.0, 1.0, 0.7)
	_item("espejo", "Cambiar de color", mirror, Vector3(7.7, 0, -4.2), 0.7, Vector3(0.6, 3.2, 1.6), 3.4)

	# Taller (pared derecha, delante): estudio de creación.
	var desk := Vector3(7.75, 0, 2.3)
	HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(1.3, 0.14, 2.8), 0.05), desk + Vector3(0, 1.05, 0), wood)
	for corner in [Vector3(-0.5, 0, -1.2), Vector3(0.5, 0, -1.2), Vector3(-0.5, 0, 1.2), Vector3(0.5, 0, 1.2)]:
		HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(0.12, 1.0, 0.12), 0.03), desk + corner + Vector3(0, 0.5, 0), dark_wood)
	var block_colors := [Palette.CORAL, Palette.MINT, Color("7cc6fe")]
	for i in 3:
		HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(0.32, 0.32, 0.32), 0.06), desk + Vector3(-0.15, 1.28 + (0.32 if i == 2 else 0.0), -0.8 + i * 0.36 - (0.18 if i == 2 else 0.0)), block_colors[i])
	var brush := HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(0.08, 0.08, 0.7), 0.03), desk + Vector3(0.1, 1.17, 0.7), Palette.SUN)
	brush.rotation.y = 0.5
	_static_box(Vector3(1.4, 1.2, 2.9), desk + Vector3(0, 0.6, 0))
	_sign("TALLER", desk + Vector3(-0.3, 2.4, 0), 56, Palette.MINT)
	var desk_item := _item("taller", "Estudio de creación", desk, Vector3(6.3, 0, 2.3), 1.0, Vector3(1.4, 1.6, 2.9), 2.9)
	if desk_item.locked:
		_padlock(desk + Vector3(-0.2, 1.5, -1.0))

	# Tocadiscos (pared izquierda, delante): sonido.
	var player := Vector3(-7.9, 0, 2.6)
	HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(1.1, 1.0, 1.4), 0.08), player + Vector3(0, 0.5, 0), Palette.CORAL)
	HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(1.0, 0.16, 1.3), 0.05), player + Vector3(0, 1.07, 0), dark_wood)
	var record := HomeDecor.add_mesh(self, PieceKit.rounded_disc(0.42, 0.03, 0.01, 40), player + Vector3(0, 1.17, -0.1), Palette.INK)
	record.set_meta("spin", true)
	record.name = "Record"
	HomeDecor.add_mesh(self, PieceKit.rounded_disc(0.13, 0.035, 0.01, 24), player + Vector3(0, 1.18, -0.1), Palette.SUN).set_meta("spin", true)
	_static_box(Vector3(1.2, 1.2, 1.5), player + Vector3(0, 0.6, 0))
	_jukebox_label = _sign("", player + Vector3(0.2, 1.95, 0), 44, Palette.PAPER)
	_item("tocadiscos", "Sonido", player, Vector3(-6.5, 0, 2.6), 0.8, Vector3(1.2, 1.4, 1.5), 2.9)
	_refresh_jukebox()


func _padlock(position: Vector3) -> void:
	HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(0.12, 0.34, 0.4), 0.05), position, Palette.SUN)
	var ring := HomeDecor.add_mesh(self, PieceKit.torus(0.13, 0.035, 24), position + Vector3(0, 0.22, 0), Palette.SUN.darkened(0.2))
	ring.rotation.z = PI / 2.0


func _build_toys() -> void:
	# Juguetes sueltos: dados y fichas que se pueden empujar con el peón.
	var spots := [
		[Vector3(-3.6, 0.4, 3.4), "die"], [Vector3(3.5, 0.4, 3.9), "die"], [Vector3(-2.4, 0.4, 5.4), "die"],
		[Vector3(4.6, 0.2, -3.9), "chip"], [Vector3(-4.4, 0.2, -3.5), "chip"], [Vector3(5.6, 0.2, 5.4), "chip"],
		[Vector3(-5.6, 0.2, 5.0), "chip"],
	]
	var chip_colors := [Palette.PLAYER_RED, Palette.PLAYER_BLUE, Palette.PLAYER_YELLOW, Palette.PLAYER_GREEN]
	for i in spots.size():
		var body := RigidBody3D.new()
		body.name = "Toy%d" % i
		body.collision_layer = LAYER_TOYS
		body.collision_mask = LAYER_STATIC | (1 << 1) | LAYER_TOYS
		body.position = spots[i][0]
		body.rotation.y = float(i) * 0.9
		body.linear_damp = 0.6
		body.angular_damp = 0.8
		var shape := CollisionShape3D.new()
		if spots[i][1] == "die":
			body.mass = 0.6
			var box := BoxShape3D.new()
			box.size = Vector3.ONE * 0.62
			shape.shape = box
			body.add_child(HomeDecor.make_die(Vector3.ZERO, 0.0, 0.62))
		else:
			body.mass = 0.3
			var cylinder := CylinderShape3D.new()
			cylinder.radius = 0.32
			cylinder.height = 0.16
			shape.shape = cylinder
			var mesh := MeshInstance3D.new()
			mesh.mesh = PieceKit.rounded_disc(0.32, 0.16, 0.05, 32)
			mesh.position.y = -0.08
			var material := StandardMaterial3D.new()
			material.albedo_color = chip_colors[i % chip_colors.size()]
			mesh.material_override = material
			body.add_child(mesh)
		body.add_child(shape)
		add_child(body)


# --- Interfaz ------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HomeUI"
	add_child(layer)
	var root := Control.new()
	root.name = "UIRoot"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var top := HBoxContainer.new()
	top.position = Vector2(28, 22)
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var title := MenuStyle.make_title("Tablerama", 40)
	title.name = "Title"
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	top.add_child(title)
	var edition := get_node_or_null("/root/Edition")
	var is_demo: bool = edition != null and edition.get("demo") == true
	var badge := MenuStyle.make_pill(
		"EDICIÓN DEMO" if is_demo else "v" + AppInfo.version(),
		Palette.CORAL if is_demo else MenuStyle.CARD_SURFACE,
		Palette.INK if is_demo else Palette.PAPER, 12, 10, 3
	)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(badge)

	var hint := MenuStyle.make_pill(
		"WASD o clic: moverse  ·  E: usar  ·  Tab: menú clásico  ·  Esc: ajustes",
		Color(Palette.INK, 0.72), Palette.PAPER, 13, 14, 6
	)
	hint.name = "Hint"
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_bottom = -20
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	_prompt = Button.new()
	_prompt.name = "Prompt"
	_prompt.visible = false
	_prompt.focus_mode = Control.FOCUS_NONE
	_prompt.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # el texto ya llega traducido
	_prompt.add_theme_font_override("font", MenuStyle.DISPLAY_FONT)
	_prompt.add_theme_font_size_override("font_size", 20)
	MenuStyle.style_primary(_prompt, 14, 5)
	_prompt.pressed.connect(func() -> void:
		if nearest != null:
			nearest.use()
	)
	root.add_child(_prompt)

	_toast = MenuStyle.make_muted("", 16)
	_toast.name = "Toast"
	_toast.add_theme_color_override("font_color", Palette.PAPER)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 86
	_toast.autowrap_mode = TextServer.AUTOWRAP_OFF
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	settings_panel = _build_settings()
	root.add_child(settings_panel)


func _build_settings() -> Control:
	var shade := ColorRect.new()
	shade.name = "Settings"
	shade.color = Color(MenuBackdrop.VEIL, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var card := MenuStyle.make_card_panel("SettingsCard", Palette.PANEL, Palette.INK, 22, 26, 22, 5)
	card.custom_minimum_size.x = 440
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	card.add_child(col)
	col.add_child(MenuStyle.make_eyebrow("EL CORCHO", Palette.SUN))
	col.add_child(MenuStyle.make_title("Ajustes", 36))

	var locale := get_node_or_null("/root/Locale")
	if locale != null and locale.has_method("make_selector"):
		var lang: OptionButton = locale.make_selector()
		lang.custom_minimum_size = Vector2(0, 40)
		MenuStyle.style_secondary(lang, 12, 5)
		col.add_child(lang)

	_sound_check = CheckButton.new()
	_sound_check.name = "SoundCheck"
	_sound_check.text = "Sonido"
	_sound_check.toggled.connect(func(on: bool) -> void:
		var sfx := get_node_or_null("/root/Sfx")
		if sfx != null:
			sfx.set_enabled(on)
		_refresh_jukebox()
	)
	col.add_child(_sound_check)

	_fullscreen_check = CheckButton.new()
	_fullscreen_check.name = "FullscreenCheck"
	_fullscreen_check.text = "Pantalla completa"
	_fullscreen_check.toggled.connect(func(on: bool) -> void:
		var style := get_node_or_null("/root/ToonStyle")
		if style != null and style.has_method("set_fullscreen"):
			style.set_fullscreen(on)
	)
	col.add_child(_fullscreen_check)

	_classic_check = CheckButton.new()
	_classic_check.name = "ClassicCheck"
	_classic_check.text = "Abrir con el menú clásico"
	_classic_check.tooltip_text = "Al arrancar y al salir de una mesa, la portada de siempre en vez de la habitación."
	_classic_check.toggled.connect(func(on: bool) -> void: HomePrefs.set_classic_menu(on))
	col.add_child(_classic_check)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var credits := Button.new()
	credits.name = "Credits"
	credits.text = "Créditos"
	MenuStyle.style_secondary(credits, 12, 5)
	credits.pressed.connect(func() -> void: _go("res://scenes/Credits.tscn"))
	row.add_child(credits)
	_report_btn = Button.new()
	_report_btn.name = "ReportBug"
	_report_btn.text = "Informar de un fallo"
	_report_btn.tooltip_text = "Copia la versión y la ruta del registro, y abre su carpeta."
	MenuStyle.style_secondary(_report_btn, 12, 5)
	_report_btn.pressed.connect(func() -> void:
		AppInfo.copy_report()
		_show_toast(tr("Copiado: pégalo en tu mensaje"))
	)
	row.add_child(_report_btn)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	col.add_child(bottom)
	var close := Button.new()
	close.name = "Close"
	close.text = "Volver a la habitación"
	close.custom_minimum_size = Vector2(0, 44)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuStyle.style_primary(close, 12, 5)
	close.pressed.connect(close_settings)
	bottom.add_child(close)
	var quit := Button.new()
	quit.name = "Quit"
	quit.text = "Salir del juego"
	quit.custom_minimum_size = Vector2(0, 44)
	MenuStyle.style_subtle(quit, 12)
	quit.pressed.connect(func() -> void: get_tree().quit())
	bottom.add_child(quit)
	var version := MenuStyle.make_muted("Tablerama v" + AppInfo.version(), 12)
	version.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	col.add_child(version)
	return shade


func open_settings() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	_sound_check.set_pressed_no_signal(sfx == null or sfx.get("enabled") == true)
	_fullscreen_check.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	_classic_check.set_pressed_no_signal(HomePrefs.classic_menu())
	settings_panel.visible = true
	pawn.input_enabled = false
	pawn.stop()
	settings_panel.find_child("Close", true, false).grab_focus.call_deferred()


func close_settings() -> void:
	settings_panel.visible = false
	pawn.input_enabled = true


func _refresh_texts() -> void:
	_refresh_jukebox()
	_update_prompt(true)


func _refresh_jukebox() -> void:
	if _jukebox_label == null:
		return
	var sfx := get_node_or_null("/root/Sfx")
	var on: bool = sfx == null or sfx.get("enabled") == true
	_jukebox_label.text = "♪ SÍ" if on else "♪ NO"


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast_timer = 2.6


# --- Bucle ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_place_camera(minf(1.0, delta * 4.0))
	if not _reduce_motion():
		for i in _bots.size():
			_bots[i].position.y = sin(_time * 1.3 + i * 1.9) * 0.025
	var sfx := get_node_or_null("/root/Sfx")
	if sfx == null or sfx.get("enabled") == true:
		for node in get_children():
			if node is MeshInstance3D and node.has_meta("spin"):
				node.rotation.y += delta * 2.2
	_toast_timer -= delta
	_toast.modulate.a = clampf(_toast_timer * 2.0, 0.0, 1.0)
	_update_prompt()


func _reduce_motion() -> bool:
	var style := get_node_or_null("/root/ToonStyle")
	return style != null and style.get("reduce_motion") == true


func _place_camera(weight: float) -> void:
	if pawn == null:
		return
	# Sigue al peón a medias: la habitación se mantiene encuadrada como un diorama.
	var focus := Vector3(pawn.position.x * 0.6, 1.0, clampf(pawn.position.z, -6.0, 5.0) * 0.55 - 0.6)
	var wanted := focus + CAMERA_OFFSET
	camera.position = camera.position.lerp(wanted, weight) if weight < 1.0 else wanted
	camera.look_at(camera.position - CAMERA_OFFSET + Vector3(0, 0.2, 0), Vector3.UP)


## Objeto más cercano al alcance del peón (o null).
func find_nearest() -> Interactable:
	var best: Interactable = null
	var best_gap := INF
	var here := Vector2(pawn.position.x, pawn.position.z)
	for item in items:
		var gap := here.distance_to(Vector2(item.position.x, item.position.z)) - float(item.get_meta("extent", 0.0))
		var near_approach := here.distance_to(Vector2(item.approach.x, item.approach.z)) < 0.9
		if (gap < item.reach or near_approach) and gap < best_gap:
			best = item
			best_gap = gap
	return best


func _update_prompt(force := false) -> void:
	var found := find_nearest() if not settings_panel.visible else null
	if found != nearest or force:
		nearest = found
		if nearest != null:
			_prompt.text = "E  ·  " + nearest.prompt_text()
			_prompt.reset_size()
	_prompt.visible = nearest != null
	if nearest != null:
		var anchor := nearest.position + Vector3(0, nearest.label_height, 0)
		if nearest.id == "mesa":
			anchor = pawn.position + Vector3(0, nearest.label_height + 0.6, 0)
		if camera.is_position_behind(anchor):
			_prompt.visible = false
			return
		var at := camera.unproject_position(anchor)
		var view := get_viewport().get_visible_rect().size
		_prompt.position = Vector2(
			clampf(at.x - _prompt.size.x * 0.5, 12.0, view.x - _prompt.size.x - 12.0),
			clampf(at.y - _prompt.size.y, 12.0, view.y - _prompt.size.y - 70.0)
		)


func _unhandled_input(event: InputEvent) -> void:
	if settings_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			close_settings()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		open_settings()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		_go(CLASSIC_PATH)
		get_viewport().set_input_as_handled()
	elif _is_use(event):
		if nearest != null:
			nearest.use()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(event.position)
		get_viewport().set_input_as_handled()


func _is_use(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		return true
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		return true
	return event is InputEventKey and event.is_action_pressed("ui_accept")


## Clic: sobre un objeto, el peón va hasta él y lo usa; sobre el suelo, va hasta allí.
func _click(screen: Vector2) -> void:
	var from := camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(screen) * 80.0)
	query.collide_with_areas = true
	query.collision_mask = LAYER_STATIC | LAYER_PICK
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var item := hit.get("collider") as Interactable
	if item != null:
		click_item(item)
	else:
		_pending = null
		pawn.walk_to(hit["position"])


func click_item(item: Interactable) -> void:
	if item == find_nearest():
		item.use()
		return
	_pending = item
	pawn.walk_to(item.approach)


func _on_pawn_arrived() -> void:
	if _pending != null and _pending == find_nearest():
		var item := _pending
		_pending = null
		item.use()
	_pending = null


# --- Acciones ------------------------------------------------------------------

func _on_item_used(item: Interactable) -> void:
	if _leaving:
		return
	if item.locked:
		_show_toast(tr("Disponible en el juego completo."))
		return
	last_item_id = item.id
	match item.id:
		"espejo":
			var index := HomePrefs.color_index() + 1
			HomePrefs.set_color_index(index)
			pawn.set_color(HomePrefs.pawn_color())
			_show_toast(tr("Tu color: %s") % tr(HomePrefs.COLOR_NAMES[HomePrefs.color_index()]))
		"tocadiscos":
			var sfx := get_node_or_null("/root/Sfx")
			if sfx != null:
				sfx.set_enabled(sfx.get("enabled") != true)
			_refresh_jukebox()
			var on: bool = sfx == null or sfx.get("enabled") == true
			_show_toast(tr("Sonido: SÍ") if on else tr("Sonido: NO"))
		"corcho":
			open_settings()
		"pizarra":
			Tutorial.requested = true
			_go(SCENES["pizarra"])
		_:
			if SCENES.has(item.id):
				_go(SCENES[item.id])


func _go(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file.call_deferred(path)
