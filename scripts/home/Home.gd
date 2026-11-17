class_name Home
extends Node3D
## La habitación de juegos: el menú principal de Tablerama, jugable. El peón de arcilla se
## mueve por la sala y cada mueble es una opción: la mesa con los bots, la estantería de
## juegos, la pizarra del tutorial, la puerta de las salas online, el taller del editor, el
## armario (aspecto del peón), el ordenador (tienda Dadazon), el tocadiscos (sonido) y el
## corcho (ajustes). Lo comprado llega en cajas a la puerta. Tab abre el menú
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
## Las pruebas lo activan para recorrer la caída animada aunque no haya pantalla.
static var force_drop_animation := false
## Mallas de los paquetes y sus efectos, construidas una sola vez por sesión: generarlas en
## mitad de la caída (cajas redondeadas, toro, cúpula) daba un tirón.
static var _fx_meshes := {}

var pawn: HomePawn
var camera: Camera3D
var items: Array[Interactable] = []
var nearest: Interactable
var settings_panel: Control
var _prompt: Button
var _toast: Label
var _toast_box: PanelContainer
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
# Atrezo animado
var _curtains: Array[Node3D] = []
var _leaves: Array[Node3D] = []
var _bulbs: Array[MeshInstance3D] = []
var _clock_hands: Array[Node3D] = []
var _cat: Node3D
var _cat_awake := false
var _cat_zzz: Label3D
var _bot_bubble: Label3D
var _marker: MeshInstance3D
var _note_timer := 0.0
var _fade: ColorRect
# Tienda, armario y paquetes
var shop: ShopUI
var wardrobe: WardrobeUI
var _coin_label: Label
var _decor := {}
var _parcels: Array[Node3D] = []
var _wardrobe_focus := false
## Temblor de cámara (segundos que le quedan).
var _shake := 0.0
const DOOR_DROP := Vector3(-6.9, 0, -0.3)


func _ready() -> void:
	HomeDecor.build_room(self, Palette.SUN)
	HomeDecor.build_table(self)
	HomeDecor.build_pieces(self)
	_build_collision()
	_build_bots()
	_build_furniture()
	_build_props()
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
	_build_marker()
	FxMaterials.prewarm(self)
	_prewarm_parcels()
	for id in HomePrefs.placed_decor():
		_place_decor(id, false)
	for id in HomePrefs.deliveries():
		_spawn_parcel(id, false)
	_show_reward.call_deferred()
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
	var shelf_games := [["parchis", "brisca", "ludo", "chess"], ["checkers", "domino", "island", "cards"]]
	for row in 3:
		HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(3.1, 0.09, 0.8), 0.03), shelf + Vector3(0, 0.25 + row * 1.05, 0.06), wood)
	for row in 2:
		for i in 4:
			var game_box := HomeProps.game_box(self, shelf_games[row][i], shelf + Vector3(-1.08 + i * 0.72, 0.3 + row * 1.05 + 0.375, 0.16))
			game_box.rotation.z = deg_to_rad(-5.0 if (row + i) % 4 == 3 else 0.0)
	var top_box := HomeProps.game_box(self, "sandbox", shelf + Vector3(-0.7, 2.4 + 0.375, 0.16))
	top_box.rotation.z = deg_to_rad(4.0)
	for k in 2:
		HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(0.8, 0.16, 0.6), 0.04), shelf + Vector3(0.75, 2.4 + 0.08 + k * 0.17, 0.12), [Palette.MINT, Palette.CORAL][k]).rotation.y = k * 0.25
	_static_box(Vector3(3.4, 3.4, 1.0), shelf + Vector3(0, 1.7, 0))
	_sign("JUEGOS", shelf + Vector3(0, 3.78, 0.45), 60, Palette.SUN)
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

	# Armario con espejo (pared derecha): aspecto del peón.
	var closet := Vector3(8.45, 0, -4.3)
	HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(1.0, 3.3, 2.3), 0.08), closet + Vector3(0, 1.65, 0), Palette.LAVENDER.darkened(0.15))
	HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(1.1, 0.16, 2.45), 0.05), closet + Vector3(0, 3.35, 0), Palette.LAVENDER.darkened(0.3))
	for side in [-1.0, 1.0]:
		HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(0.08, 3.0, 1.06), 0.04), closet + Vector3(-0.52, 1.65, side * 0.56), Palette.LAVENDER)
		HomeDecor.add_mesh(self, _knob_mesh(), closet + Vector3(-0.6, 1.65, side * 0.12), Palette.SUN)
	var glass := HomeDecor.add_mesh(self, PieceKit.rounded_disc(0.36, 0.04, 0.015, 40), closet + Vector3(-0.58, 2.0, -0.56), Color("c9d8f2"))
	glass.rotation.z = PI / 2.0
	glass.scale = Vector3(1.6, 1.0, 1.0)
	_static_box(Vector3(1.1, 3.4, 2.4), closet + Vector3(0, 1.7, 0))
	_sign("ARMARIO", closet + Vector3(-0.6, 3.75, 0), 48, Palette.LAVENDER.lightened(0.3))
	_item("armario", "Personalizar tu peón", closet, Vector3(7.0, 0, -4.3), 1.0, Vector3(1.0, 3.3, 2.3), 4.0)

	# Ordenador (pared izquierda): la tienda Dadazon.
	var pc := Vector3(-8.25, 0, -5.0)
	HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(1.2, 0.12, 2.2), 0.04), pc + Vector3(0, 1.0, 0), wood)
	for corner in [Vector3(-0.45, 0, -0.95), Vector3(0.45, 0, -0.95), Vector3(-0.45, 0, 0.95), Vector3(0.45, 0, 0.95)]:
		HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(0.1, 0.95, 0.1), 0.03), pc + corner + Vector3(0, 0.48, 0), dark_wood)
	HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(0.16, 0.9, 1.3), 0.06), pc + Vector3(-0.15, 1.65, 0), Palette.INK.lightened(0.15))
	var screen := QuadMesh.new()
	screen.size = Vector2(1.15, 0.75)
	var screen_mesh := MeshInstance3D.new()
	screen_mesh.name = "Screen"
	screen_mesh.mesh = screen
	var screen_mat := StandardMaterial3D.new()
	screen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_mat.albedo_color = Palette.SUN.lerp(Palette.PAPER, 0.4)
	screen_mesh.material_override = screen_mat
	screen_mesh.position = pc + Vector3(-0.06, 1.65, 0)
	screen_mesh.rotation.y = PI / 2.0
	add_child(screen_mesh)
	var screen_logo := _sign("dadazon", pc + Vector3(-0.04, 1.7, 0), 40, Palette.INK, PI / 2.0)
	screen_logo.outline_size = 0
	screen_logo.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(0.12, 0.3, 0.12), 0.03), pc + Vector3(-0.15, 1.2, 0), Palette.INK.lightened(0.15))
	HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(0.4, 0.04, 0.9), 0.02), pc + Vector3(0.25, 1.08, 0), Palette.PAPER)
	_static_box(Vector3(1.3, 2.2, 2.3), pc + Vector3(0, 1.1, 0))
	_item("ordenador", "Comprar en Dadazon", pc, Vector3(-6.75, 0, -5.0), 0.9, Vector3(1.2, 2.2, 2.2), 3.0)

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


func _knob_mesh() -> SphereMesh:
	var knob := SphereMesh.new()
	knob.radius = 0.07
	knob.height = 0.14
	return knob


func _padlock(position: Vector3) -> void:
	HomeDecor.add_mesh(self, PieceKit.rounded_box(Vector3(0.12, 0.34, 0.4), 0.05), position, Palette.SUN)
	var ring := HomeDecor.add_mesh(self, PieceKit.torus(0.13, 0.035, 24), position + Vector3(0, 0.22, 0), Palette.SUN.darkened(0.2))
	ring.rotation.z = PI / 2.0


func _build_props() -> void:
	HomeProps.floor_planks(self)
	# Cuadros con portadas.
	HomeProps.poster(self, "parchis", Vector3(-2.25, 2.05, -7.93), 0.0, -2.0, 1.3)
	HomeProps.poster(self, "chess", Vector3(2.85, 2.3, -7.93), 0.0, 3.0, 1.3)
	HomeProps.poster(self, "domino", Vector3(-8.93, 2.7, 5.2), PI / 2.0, -3.0, 1.3)
	HomeProps.poster(self, "ludo", Vector3(8.93, 2.6, 5.3), -PI / 2.0, 2.5, 1.3)
	# Ventana con cortinas en la pared derecha.
	_curtains = HomeProps.window(self, Vector3(8.93, 2.6, -1.0), -PI / 2.0)
	# Plantas en las esquinas.
	_leaves.append(HomeProps.plant(self, Vector3(-8.1, 0, -7.1), 1.15))
	_leaves.append(HomeProps.plant(self, Vector3(8.1, 0, -7.1), 1.0))
	_leaves.append(HomeProps.plant(self, Vector3(8.1, 0, 5.9), 0.9))
	for spot in [Vector3(-8.1, 0, -7.1), Vector3(8.1, 0, -7.1), Vector3(8.1, 0, 5.9)]:
		_static_box(Vector3(1.0, 1.4, 1.0), spot + Vector3(0, 0.7, 0))
	# Guirnalda de luces y reloj en la pared del fondo.
	_bulbs = HomeProps.garland(self, Vector3(-8.8, 4.2, -7.85), Vector3(8.8, 4.2, -7.85), 22, 0.25)
	_clock_hands = HomeProps.clock(self, Vector3(-2.25, 3.42, -7.9))
	# Puf con el gato dormido (delante, a la izquierda).
	var bag := Vector3(-5.6, 0, 5.3)
	_cat = HomeProps.cat_on_beanbag(self, bag, -1.3)
	_static_box(Vector3(1.6, 1.0, 1.6), bag + Vector3(0, 0.5, 0))
	_cat_zzz = _sign("z z", bag + Vector3(0.2, 2.0, 0), 40, Palette.PAPER)
	_item("gato", "Acariciar al gato", bag, bag + Vector3(1.4, 0, -0.8), 0.9, Vector3(1.6, 1.4, 1.6), 2.3)
	# Bocadillo de los bots.
	_bot_bubble = _sign("¿Echamos una partida?", Vector3(-1.6, 3.2, -2.9), 48, Palette.INK)
	_bot_bubble.outline_modulate = Palette.PAPER
	_bot_bubble.outline_size = 22
	_bot_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bot_bubble.visible = false
	# Motas de polvo bajo la lámpara.
	var motes := CPUParticles3D.new()
	motes.name = "DustMotes"
	motes.amount = 40
	motes.lifetime = 7.0
	motes.preprocess = 7.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(3.2, 1.4, 3.2)
	motes.position = Vector3(0, 2.4, 0)
	motes.direction = Vector3(0.2, 1, 0)
	motes.spread = 60.0
	motes.gravity = Vector3.ZERO
	motes.initial_velocity_min = 0.03
	motes.initial_velocity_max = 0.12
	motes.scale_amount_min = 0.5
	motes.scale_amount_max = 1.0
	var mote := QuadMesh.new()
	mote.size = Vector2(0.05, 0.05)
	var mote_mat := StandardMaterial3D.new()
	mote_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote_mat.albedo_color = Color(1.0, 0.95, 0.75, 0.55)
	mote.material = mote_mat
	motes.mesh = mote
	add_child(motes)


## Aro en el suelo donde hay que ponerse para usar el objeto más cercano.
func _build_marker() -> void:
	_marker = MeshInstance3D.new()
	_marker.name = "UseMarker"
	_marker.mesh = PieceKit.torus(0.55, 0.05, 40)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Palette.SUN
	_marker.material_override = material
	_marker.visible = false
	add_child(_marker)


func _animate_props(delta: float) -> void:
	var calm := _reduce_motion()
	for i in _curtains.size():
		_curtains[i].rotation.z = 0.0 if calm else sin(_time * 0.9 + i) * 0.045
	for i in _leaves.size():
		_leaves[i].rotation.z = 0.0 if calm else sin(_time * 0.7 + i * 2.1) * 0.035
	for i in _bulbs.size():
		var material := _bulbs[i].material_override as StandardMaterial3D
		if not material.has_meta(&"base"):
			material.set_meta(&"base", material.albedo_color)
		var base: Color = material.get_meta(&"base")
		var glow := 0.5 + 0.5 * sin(_time * 2.2 + i * 1.7)
		material.albedo_color = base.lerp(Color.WHITE, 0.0 if calm else glow * 0.45)
	if _clock_hands.size() == 2:
		var now := Time.get_time_dict_from_system()
		var minutes := float(now["minute"]) + float(now["second"]) / 60.0
		_clock_hands[0].rotation.z = -TAU * (float(int(now["hour"]) % 12) + minutes / 60.0) / 12.0
		_clock_hands[1].rotation.z = -TAU * minutes / 60.0
	# Gato: se despierta cuando el peón se acerca.
	if _cat != null:
		var near := Vector2(pawn.position.x, pawn.position.z).distance_to(Vector2(_cat.global_position.x, _cat.global_position.z)) < 2.8
		if near != _cat_awake:
			_cat_awake = near
			_cat.get_node("Head/EyesOpen").visible = near
			_cat.get_node("Head/EyesClosed").visible = not near
			if near:
				_sfx("pop", -14.0)
		var head := _cat.get_node("Head") as Node3D
		head.position.y = lerpf(head.position.y, 0.34 if _cat_awake else 0.2, minf(1.0, delta * 6.0))
		var tail := _cat.get_node("Tail") as Node3D
		tail.rotation.y = sin(_time * (5.0 if _cat_awake else 1.2)) * (0.5 if _cat_awake else 0.15)
		var body := _cat.get_node("Body") as Node3D
		body.scale.y = 0.72 + (0.0 if calm or _cat_awake else sin(_time * 1.6) * 0.03)
		_cat_zzz.visible = not _cat_awake
		_cat_zzz.position.y = 2.0 + sin(_time * 1.5) * 0.12
		_cat_zzz.modulate.a = 0.55 + 0.45 * sin(_time * 1.5)
	# Bots: miran al peón y le invitan cuando se acerca a la mesa.
	for bot in _bots:
		var head := bot.get_node_or_null("Head") as Node3D
		if head == null:
			continue
		var local := bot.to_local(pawn.global_position + Vector3(0, 1.8, 0))
		var yaw := clampf(atan2(local.x, local.z), -0.9, 0.9)
		head.rotation.y = lerp_angle(head.rotation.y, yaw, minf(1.0, delta * 4.0))
	_bot_bubble.visible = nearest != null and nearest.id == "mesa"
	if _bot_bubble.visible:
		_bot_bubble.position.y = 3.25 + sin(_time * 3.0) * 0.06
	# Tocadiscos: notas que suben mientras suena.
	var sfx := get_node_or_null("/root/Sfx")
	if (sfx == null or sfx.get("enabled") == true) and not calm:
		_note_timer -= delta
		if _note_timer <= 0.0:
			_note_timer = 0.9
			_float_text("♪" if randf() < 0.5 else "♫", Vector3(-7.9, 1.5, 2.5), Palette.SUN)
	# Aro de uso bajo el objeto más cercano.
	_marker.visible = nearest != null and not panel_open()
	if _marker.visible:
		var flat := Vector3(pawn.position.x, 0, pawn.position.z)
		var spot := nearest.approach if nearest.id != "mesa" else flat.normalized() * (HomeDecor.TABLE_RADIUS + 0.75)
		_marker.position = Vector3(spot.x, 0.04, spot.z)
		var pulse := 1.0 + (0.0 if calm else sin(_time * 5.0) * 0.08)
		_marker.scale = Vector3(pulse, 1.0, pulse)


## Texto que sube y se desvanece (notas, corazones).
func _float_text(text: String, at: Vector3, color: Color, size := 52) -> void:
	var label := _sign(text, at, size, color)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position", at + Vector3(randf_range(-0.3, 0.3), 1.3, 0), 1.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.6).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


func _sfx(sound: String, volume := 0.0) -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null and sfx.has_method("play"):
		sfx.play(sound, volume)


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
		body.contact_monitor = true
		body.max_contacts_reported = 2
		var sound := "dice" if spots[i][1] == "die" else "drop"
		body.body_entered.connect(func(_other: Node) -> void:
			if body.linear_velocity.length() > 1.2:
				_sfx(sound, -10.0)
		)
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
	var coins := MenuStyle.make_pill("", Palette.SUN, Palette.INK, 14, 12, 4)
	coins.name = "Coins"
	coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coins.tooltip_text = "Fichas: se ganan jugando en las mesas y se gastan en Dadazon."
	top.add_child(coins)
	_coin_label = coins.get_child(0) as Label
	_refresh_coins()

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

	_toast_box = MenuStyle.make_pill("", Palette.INK, Palette.PAPER, 17, 20, 8)
	_toast_box.name = "ToastBox"
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_box.offset_top = 92
	_toast_box.modulate.a = 0.0
	root.add_child(_toast_box)
	_toast = _toast_box.get_child(0) as Label
	_toast.name = "Toast"

	settings_panel = _build_settings()
	root.add_child(settings_panel)

	shop = ShopUI.new()
	root.add_child(shop)
	shop.purchased.connect(_on_purchased)
	shop.closed.connect(_on_shop_closed)
	wardrobe = WardrobeUI.new()
	root.add_child(wardrobe)
	wardrobe.changed.connect(func() -> void: pawn.refresh_look())
	wardrobe.closed.connect(_on_wardrobe_closed)

	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color(MenuBackdrop.VEIL, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_fade)


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
	_toast_box.reset_size()
	_toast_box.offset_left = -_toast_box.size.x * 0.5
	_toast_box.offset_right = _toast_box.size.x * 0.5
	_toast_timer = 2.8


# --- Bucle ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_shake = maxf(0.0, _shake - delta)
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
	_toast_box.modulate.a = clampf(_toast_timer * 2.0, 0.0, 1.0)
	_update_prompt()
	_animate_props(delta)
	_animate_decor(delta)


func _reduce_motion() -> bool:
	var style := get_node_or_null("/root/ToonStyle")
	return style != null and style.get("reduce_motion") == true


func _place_camera(weight: float) -> void:
	if pawn == null:
		return
	# En el armario, primer plano del peón (a la izquierda, para dejar sitio al panel).
	if _wardrobe_focus:
		var target := pawn.position + Vector3(0, 1.55, 0)
		var close := target + Vector3(-2.2, 1.0, 3.9)
		camera.position = camera.position.lerp(close, weight)
		camera.look_at(target + Vector3(1.1, -0.1, 0), Vector3.UP)
		return
	# Sigue al peón a medias: la habitación se mantiene encuadrada como un diorama.
	var focus := Vector3(pawn.position.x * 0.6, 1.0, clampf(pawn.position.z, -6.0, 5.0) * 0.55 - 0.6)
	var wanted := focus + CAMERA_OFFSET
	camera.position = camera.position.lerp(wanted, weight) if weight < 1.0 else wanted
	camera.look_at(camera.position - CAMERA_OFFSET + Vector3(0, 0.2, 0), Vector3.UP)
	if _shake > 0.0:
		var strength := _shake * 0.5
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * strength


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
	var found := find_nearest() if not panel_open() else null
	if found != nearest or force:
		nearest = found
		if nearest != null:
			_prompt.text = "E  ·  " + nearest.prompt_text()
			_prompt.reset_size()
			if not force:
				_prompt.pivot_offset = _prompt.size * 0.5
				_prompt.scale = Vector2(0.6, 0.6)
				create_tween().tween_property(_prompt, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_sfx("pop", -20.0)
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


## Hay un panel abierto (ajustes, tienda o armario): el peón no se mueve.
func panel_open() -> bool:
	return settings_panel.visible or shop.visible or wardrobe.visible


func _unhandled_input(event: InputEvent) -> void:
	if shop.visible or wardrobe.visible:
		if event.is_action_pressed("ui_cancel"):
			if shop.visible:
				shop.close_shop()
			else:
				wardrobe.close_wardrobe()
			get_viewport().set_input_as_handled()
		return
	if settings_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			close_settings()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		open_settings()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		_go(CLASSIC_PATH)
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
	_sfx("ui", -6.0)
	pawn.hop()
	match item.id:
		"gato":
			for k in 3:
				get_tree().create_timer(k * 0.18).timeout.connect(func() -> void:
					_float_text("♥", _cat.global_position + Vector3(0, 0.8, 0), Palette.CORAL, 60)
				)
			_show_toast(tr("Prrrr…"))
		"armario":
			open_wardrobe()
		"ordenador":
			open_shop()
		"paquete":
			_open_parcel(item)
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


## Sale de la habitación: la cámara se acerca y la pantalla funde a tinta.
func _go(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	pawn.input_enabled = false
	pawn.stop()
	if _reduce_motion() or DisplayServer.get_name() == "headless":
		get_tree().change_scene_to_file.call_deferred(path)
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(camera, "fov", 30.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_fade, "color:a", 1.0, 0.4)
	tween.chain().tween_callback(func() -> void: get_tree().change_scene_to_file(path))


# --- Tienda, armario y paquetes ------------------------------------------------

func open_shop() -> void:
	pawn.input_enabled = false
	pawn.stop()
	shop.open_shop()


func _on_shop_closed() -> void:
	pawn.input_enabled = true
	_refresh_coins()
	# Lo pedido llega enseguida: suena el timbre y cae la caja junto a la puerta.
	var pending := HomePrefs.deliveries().filter(func(id: Variant) -> bool: return not _has_parcel(str(id)))
	if pending.is_empty():
		return
	var delay := 0.0 if DisplayServer.get_name() == "headless" else 0.9
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		_sfx("turn", -2.0)
		_show_toast(tr("¡Mira arriba! Tu pedido de Dadazon llega en paracaídas."))
		for i in pending.size():
			_spawn_parcel(str(pending[i]), true, i * 0.45)
	)


func _on_purchased(_id: String) -> void:
	_sfx("pop")
	_refresh_coins()


func open_wardrobe() -> void:
	pawn.input_enabled = false
	pawn.stop()
	_wardrobe_focus = true
	pawn.set("_blink", 3.0)
	var tween := create_tween()
	tween.tween_property(pawn, "rotation:y", 0.0, 0.3)
	wardrobe.open_wardrobe()


func _on_wardrobe_closed() -> void:
	_wardrobe_focus = false
	pawn.input_enabled = true


func _refresh_coins() -> void:
	if _coin_label != null:
		_coin_label.text = tr("%d fichas") % HomePrefs.coins()


## Recompensa por la última partida (la calcula SessionNavigation al volver de una mesa).
func _show_reward() -> void:
	var nav := get_node_or_null("/root/SessionNavigation")
	if nav == null or int(nav.get("last_reward")) <= 0:
		return
	_show_toast(tr("+%d fichas por jugar") % int(nav.get("last_reward")))
	nav.set("last_reward", 0)
	_sfx("pop")


func _has_parcel(id: String) -> bool:
	for parcel in _parcels:
		if is_instance_valid(parcel) and parcel.get_meta(&"order", "") == id:
			return true
	return false


## Caja de Dadazon junto a la puerta. Con «animated», cae desde arriba y rebota.
## Caja de Dadazon junto a la puerta. Con «animated», cae del cielo en paracaídas.
func _spawn_parcel(id: String, animated: bool, delay := 0.0) -> void:
	var count := _parcels.filter(func(p: Node3D) -> bool: return is_instance_valid(p)).size()
	var offsets: Array[Vector3] = [Vector3.ZERO, Vector3(1.15, 0, 1.0), Vector3(0.1, 0, 2.0), Vector3(1.3, 0, -0.9)]
	var spot: Vector3 = DOOR_DROP + offsets[count % 4]
	var parcel := Node3D.new()
	parcel.name = "Parcel_" + id
	parcel.set_meta(&"order", id)
	parcel.position = spot
	parcel.rotation.y = randf_range(-0.4, 0.4)
	add_child(parcel)
	var box := Node3D.new()
	box.name = "Box"
	parcel.add_child(box)
	parcel.scale = Vector3.ONE * 1.25
	var cardboard := Color("c99a63")
	HomeDecor.add_mesh(box, _fx_mesh("box"), Vector3(0, 0.35, 0), cardboard)
	var lid := HomeDecor.add_mesh(box, _fx_mesh("lid"), Vector3(0, 0.72, 0), cardboard.darkened(0.08))
	lid.name = "Lid"
	HomeDecor.add_mesh(lid, _fx_mesh("tape"), Vector3(0, 0.04, 0), Palette.SUN)
	for side in [-1.0, 1.0]:
		var brand := Label3D.new()
		brand.text = "dadazon"
		brand.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		brand.font = MenuStyle.DISPLAY_FONT
		brand.font_size = 40
		brand.pixel_size = 0.005
		brand.modulate = Palette.INK
		brand.position = Vector3(0, 0.4, side * 0.46)
		brand.rotation.y = 0.0 if side > 0 else PI
		box.add_child(brand)
	_parcels.append(parcel)
	var calm := (_reduce_motion() or DisplayServer.get_name() == "headless") and not force_drop_animation
	if not animated or calm:
		_add_parcel_item(parcel, id, spot)
		return
	_sky_drop(parcel, id, spot, delay)


func _add_parcel_item(parcel: Node3D, id: String, spot: Vector3) -> void:
	var item := Interactable.new()
	item.name = "Item_paquete_" + id
	item.id = "paquete"
	item.label = "Abrir paquete de Dadazon"
	item.approach = spot + Vector3(1.15, 0, 0.2)
	item.reach = 1.2
	item.set_meta("extent", 0.5)
	item.set_meta(&"order", id)
	item.label_height = 1.5
	item.position = spot
	item.set_pick_box(Vector3(1.0, 0.9, 1.0), Vector3(0, 0.45, 0))
	item.used.connect(_on_item_used)
	add_child(item)
	items.append(item)
	parcel.set_meta(&"item", item)


## La caja cae del cielo: sombra que crece en el suelo, caída en picado, paracaídas de
## Dadazon que se abre de golpe y la frena meciéndose, aterrizaje con aplastón, polvo,
## temblor de cámara y un «¡PLOF!»; el paracaídas se suelta y se va volando.
func _sky_drop(parcel: Node3D, id: String, spot: Vector3, delay: float) -> void:
	var box := parcel.get_node("Box") as Node3D
	box.position.y = 18.0
	box.rotation = Vector3(randf_range(-0.6, 0.6), randf_range(0, TAU), randf_range(-0.6, 0.6))
	# Sombra que avisa de dónde va a caer.
	var shadow_mat := FxMaterials.make(FxMaterials.GLOW_ALPHA, Color(Palette.INK, 0.0))
	var shadow := _fx_node(parcel, "shadow", shadow_mat, Vector3(0, 0.03, 0))
	shadow.scale = Vector3(0.15, 1.0, 0.15)
	# Paracaídas (plegado hasta que se abre).
	var chute := _make_parachute()
	chute.scale = Vector3.ONE * 0.05
	chute.visible = false
	box.add_child(chute)

	var fall := create_tween()
	fall.tween_interval(delay)
	fall.tween_callback(func() -> void: _sfx("grab", -4.0))
	fall.set_parallel(true)
	fall.tween_property(shadow, "scale", Vector3(0.6, 1.0, 0.6), 0.55)
	fall.tween_property(shadow_mat, "albedo_color:a", 0.18, 0.55)
	fall.tween_property(box, "position:y", 7.5, 0.55).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fall.tween_property(box, "rotation", Vector3(0, box.rotation.y + 1.5, 0), 0.55)
	fall.set_parallel(false)
	# ¡Paf! Se abre el paracaídas: sacudida hacia arriba y rebote elástico.
	fall.tween_callback(func() -> void:
		chute.visible = true
		_sfx("pop", -2.0)
		_float_text("!", pawn.position + Vector3(0, 2.6, 0), Palette.SUN, 90)
	)
	fall.set_parallel(true)
	fall.tween_property(chute, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	fall.tween_property(box, "position:y", 8.1, 0.18).set_ease(Tween.EASE_OUT)
	fall.set_parallel(false)
	# Descenso suave meciéndose; la sombra se oscurece y se hace grande.
	fall.set_parallel(true)
	fall.tween_property(box, "position:y", 0.9, 1.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	fall.tween_method(func(t: float) -> void:
		box.rotation.z = sin(t * TAU * 1.5) * 0.22 * (1.0 - t)
		box.rotation.x = cos(t * TAU * 1.2) * 0.12 * (1.0 - t)
	, 0.0, 1.0, 1.6)
	fall.tween_property(shadow, "scale", Vector3(1.15, 1.0, 1.15), 1.6)
	fall.tween_property(shadow_mat, "albedo_color:a", 0.38, 1.6)
	fall.set_parallel(false)
	# Se suelta el paracaídas y la caja cae el último tramo.
	fall.tween_callback(func() -> void: _release_parachute(chute))
	fall.tween_property(box, "position:y", 0.0, 0.16).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fall.tween_callback(func() -> void:
		_land(parcel, box, spot)
		shadow.queue_free()
		_add_parcel_item(parcel, id, spot)
	)
	# Aplastón y rebote.
	fall.tween_property(box, "scale", Vector3(1.35, 0.55, 1.35), 0.07)
	fall.tween_property(box, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _make_parachute() -> Node3D:
	var chute := Node3D.new()
	chute.name = "Parachute"
	var dome := _fx_node(chute, "dome", FxMaterials.make(FxMaterials.CLOTH, Palette.CORAL), Vector3(0, 2.2, 0))
	dome.scale = Vector3(1.0, 0.7, 1.0)
	_fx_node(chute, "band", FxMaterials.make(FxMaterials.CLOTH, Palette.SUN), Vector3(0, 2.45, 0))
	_fx_node(chute, "cap", FxMaterials.make(FxMaterials.CLOTH, Palette.SUN), Vector3(0, 2.92, 0))
	for k in 4:
		var angle := TAU * (k + 0.5) / 4.0
		var top := Vector3(cos(angle) * 0.95, 2.2, sin(angle) * 0.95)
		var bottom := Vector3(cos(angle) * 0.38, 0.75, sin(angle) * 0.38)
		var line := _fx_node(chute, "rope", FxMaterials.make(FxMaterials.CLOTH, Palette.PAPER), (top + bottom) * 0.5)
		var up := (top - bottom).normalized()
		var side := up.cross(Vector3.FORWARD).normalized() if absf(up.z) < 0.95 else Vector3.RIGHT
		line.basis = Basis(side, up * top.distance_to(bottom), side.cross(up))
	var logo := Label3D.new()
	logo.text = "dadazon"
	logo.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	logo.font = MenuStyle.DISPLAY_FONT
	logo.font_size = 64
	logo.pixel_size = 0.006
	logo.modulate = Palette.PAPER
	logo.outline_size = 12
	logo.outline_modulate = Palette.INK
	logo.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	logo.position = Vector3(0, 2.55, 0)
	chute.add_child(logo)
	return chute


## El paracaídas se suelta, sube flotando, se aleja girando y se desvanece.
func _release_parachute(chute: Node3D) -> void:
	var where := chute.global_transform
	chute.get_parent().remove_child(chute)
	add_child(chute)
	chute.global_transform = where
	var drift := Vector3(randf_range(-2.5, 2.5), 4.5, randf_range(-2.0, 0.5))
	var tween := chute.create_tween().set_parallel(true)
	tween.tween_property(chute, "position", chute.position + drift, 1.6).set_ease(Tween.EASE_OUT)
	tween.tween_property(chute, "rotation", Vector3(0.6, 2.5, -0.5), 1.6)
	tween.tween_property(chute, "scale", Vector3(1.3, 0.3, 1.3), 1.6).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(chute.queue_free)


func _land(parcel: Node3D, box: Node3D, spot: Vector3) -> void:
	box.rotation = Vector3(0, box.rotation.y, 0)
	pawn.hop()
	_sfx("drop", 2.0)
	_sfx("dice", -4.0)
	_shake = 0.35
	# Anillo de polvo que se abre.
	var ring_mat := FxMaterials.make(FxMaterials.GLOW_ALPHA, Color(1, 0.96, 0.88, 0.85))
	var ring := _fx_node(self, "ring", ring_mat, spot + Vector3(0, 0.08, 0))
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(3.2, 1.0, 3.2), 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring_mat, "albedo_color:a", 0.0, 0.5)
	tween.chain().tween_callback(ring.queue_free)
	# Bocanadas de polvo alrededor.
	for k in 8:
		var angle := TAU * k / 8.0
		pawn.call("_puff", spot + Vector3(cos(angle), 0, sin(angle)) * 0.7)
	# Los juguetes cercanos dan un saltito.
	for node in get_children():
		if node is RigidBody3D and (node as RigidBody3D).position.distance_to(spot) < 4.0:
			(node as RigidBody3D).apply_central_impulse(Vector3(randf_range(-0.4, 0.4), 2.2, randf_range(-0.4, 0.4)))
	# ¡PLOF!
	var bang := Label3D.new()
	bang.text = "¡PLOF!"
	bang.font = MenuStyle.DISPLAY_FONT
	bang.font_size = 96
	bang.pixel_size = 0.008
	bang.modulate = Palette.SUN
	bang.outline_size = 24
	bang.outline_modulate = Palette.INK
	bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bang.no_depth_test = true
	bang.position = spot + Vector3(0, 1.6, 0)
	bang.scale = Vector3.ONE * 0.2
	add_child(bang)
	var pop := bang.create_tween()
	pop.tween_property(bang, "scale", Vector3.ONE * 1.15, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(bang, "scale", Vector3.ONE, 0.12)
	pop.tween_interval(0.45)
	pop.set_parallel(true)
	pop.tween_property(bang, "position:y", bang.position.y + 0.8, 0.4)
	pop.tween_property(bang, "modulate:a", 0.0, 0.4)
	pop.set_parallel(false)
	pop.tween_callback(bang.queue_free)
	_confetti(spot + Vector3(0, 0.8, 0))


func _open_parcel(item: Interactable) -> void:
	var id := str(item.get_meta(&"order", ""))
	items.erase(item)
	item.queue_free()
	var parcel: Node3D = null
	for p in _parcels:
		if is_instance_valid(p) and p.get_meta(&"order", "") == id:
			parcel = p
	_parcels.erase(parcel)
	HomePrefs.open_delivery(id)
	var kind := ShopCatalog.kind(id)
	if kind == ShopCatalog.HAT:
		HomePrefs.set_hat(id)
		pawn.refresh_look()
	elif kind == ShopCatalog.ACCESSORY:
		HomePrefs.set_accessory(id)
		pawn.refresh_look()
	else:
		_place_decor(id, true)
	_confetti(parcel.global_position + Vector3(0, 0.9, 0) if parcel != null else pawn.position)
	_sfx("pop")
	_show_toast(tr("¡Nuevo: %s!") % tr(ShopCatalog.item_name(id)) if kind == ShopCatalog.DECOR else tr("¡Estrenas %s! Cámbialo cuando quieras en el armario.") % tr(ShopCatalog.item_name(id)))
	if parcel != null:
		var lid := parcel.get_node_or_null("Lid") as Node3D
		var tween := create_tween()
		if lid != null:
			tween.tween_property(lid, "position", lid.position + Vector3(0.3, 0.9, 0), 0.25)
		tween.tween_property(parcel, "scale", Vector3(1.2, 0.2, 1.2), 0.2).set_delay(0.15)
		tween.tween_callback(parcel.queue_free)


func _place_decor(id: String, animated: bool) -> void:
	if _decor.has(id) or not DecorItems.SLOTS.has(id):
		return
	var node := DecorItems.build(self, id)
	_decor[id] = node
	if DecorItems.FOOTPRINT.has(id):
		var size: Vector3 = DecorItems.FOOTPRINT[id]
		var body := _static_box(size, node.position + Vector3(0, size.y * 0.5, 0), node.rotation.y)
		body.name = "DecorBody_" + id
	if animated:
		var rest := node.scale
		node.scale = Vector3.ONE * 0.05
		create_tween().tween_property(node, "scale", rest, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Lluvia de papelitos de colores.
func _confetti(at: Vector3) -> void:
	var colors := [Palette.SUN, Palette.CORAL, Palette.MINT, Color("7cc6fe"), Palette.LAVENDER]
	for i in 24:
		var bit := _fx_node(self, "confetti", FxMaterials.make(FxMaterials.GLOW_TWO_SIDED, colors[i % colors.size()]), at)
		var flight := Vector3(randf_range(-1.6, 1.6), randf_range(1.2, 2.6), randf_range(-1.6, 1.6))
		var tween := bit.create_tween().set_parallel(true)
		tween.tween_property(bit, "position", at + flight, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(bit, "rotation", Vector3(randf() * 9.0, randf() * 9.0, randf() * 9.0), 1.3)
		tween.chain().tween_property(bit, "position:y", 0.02, 0.85).set_ease(Tween.EASE_IN)
		tween.chain().tween_interval(1.2)
		tween.chain().tween_callback(bit.queue_free)


## Animaciones de la decoración comprada: bola que gira, pez que nada, Botito que te sigue.
func _animate_decor(delta: float) -> void:
	var calm := _reduce_motion()
	if _decor.has("bola_disco"):
		var ball := (_decor["bola_disco"] as Node3D).find_child("Ball", true, false) as Node3D
		if ball != null and not calm:
			ball.rotation.y += delta * 1.2
	if _decor.has("pecera"):
		var fish := (_decor["pecera"] as Node3D).find_child("Fish", true, false) as Node3D
		if fish != null and not calm:
			fish.rotation.y = -_time * 1.4
			fish.position.y = 1.22 + sin(_time * 2.0) * 0.05
	if _decor.has("neon"):
		var sign := (_decor["neon"] as Node3D).get_child(0) as Label3D
		if sign != null:
			var flicker := 1.0 if calm or fmod(_time, 5.3) > 0.18 else 0.4
			sign.modulate.a = flicker
	if _decor.has("botito"):
		var bot := _decor["botito"] as Node3D
		var behind := pawn.position - pawn.global_basis.z * 1.4 + pawn.global_basis.x * 0.9
		behind.y = 0.0
		var to := behind - bot.position
		if to.length() > 0.3:
			bot.position += to.normalized() * minf(to.length(), delta * 4.2 * clampf(to.length(), 0.4, 2.0))
			bot.rotation.y = lerp_angle(bot.rotation.y, atan2(to.x, to.z), minf(1.0, delta * 8.0))
		var body := bot.get_node_or_null("BotitoBody") as Node3D
		if body != null and not calm:
			body.position.y = absf(sin(_time * 6.0)) * 0.06 + 0.15 + sin(_time * 2.0) * 0.05


## Malla de efectos cacheada (se construye la primera vez y se reutiliza).
static func _fx_mesh(key: String) -> Mesh:
	if _fx_meshes.has(key):
		return _fx_meshes[key]
	var mesh: Mesh
	match key:
		"box":
			mesh = PieceKit.rounded_box(Vector3(0.9, 0.7, 0.9), 0.05)
		"lid":
			mesh = PieceKit.rounded_box(Vector3(0.94, 0.08, 0.94), 0.03)
		"tape":
			mesh = PieceKit.rounded_box(Vector3(0.96, 0.03, 0.2), 0.01)
		"dome":
			var half := SphereMesh.new()
			half.radius = 1.0
			half.height = 1.0
			half.is_hemisphere = true
			half.radial_segments = 32
			half.rings = 12
			mesh = half
		"band":
			mesh = PieceKit.torus(0.92, 0.07, 32)
		"cap":
			mesh = PieceKit.rounded_disc(0.2, 0.08, 0.03, 20)
		"rope":
			var rope := CylinderMesh.new()
			rope.top_radius = 0.012
			rope.bottom_radius = 0.012
			rope.height = 1.0
			rope.radial_segments = 6
			rope.rings = 1
			mesh = rope
		"ring":
			mesh = PieceKit.torus(0.6, 0.12, 32)
		"shadow":
			mesh = PieceKit.rounded_disc(0.7, 0.01, 0.005, 32)
		"confetti":
			var quad := QuadMesh.new()
			quad.size = Vector2(0.09, 0.14)
			mesh = quad
	_fx_meshes[key] = mesh
	return mesh


## Efecto sin sombra proyectada (los efectos efímeros no deben redibujar el mapa de sombras).
static func _fx_node(parent: Node, key: String, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = _fx_mesh(key)
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = at
	parent.add_child(node)
	return node


## Prepara al cargar la habitación todo lo que usa la caída de un paquete: mallas, textos con
## sus tamaños de letra (se rasterizan las letras) y un paracaídas entero bajo el suelo, para
## que los shaders y las texturas estén listos antes del primer pedido.
func _prewarm_parcels() -> void:
	var holder := Node3D.new()
	holder.name = "ParcelPrewarm"
	holder.position = Vector3(0, -6.0, 0)
	add_child(holder)
	for key in ["box", "lid", "tape", "dome", "band", "cap", "rope", "ring", "shadow", "confetti"]:
		_fx_mesh(key)
	var chute := _make_parachute()
	chute.name = "ParachutePrewarm"
	holder.add_child(chute)
	for spec in [["¡PLOF!", 96, 24], ["!", 90, 14], ["dadazon", 40, 0], ["♥", 60, 14]]:
		var label := Label3D.new()
		label.text = tr(spec[0])
		label.font = MenuStyle.DISPLAY_FONT
		label.font_size = spec[1]
		label.outline_size = spec[2]
		holder.add_child(label)
