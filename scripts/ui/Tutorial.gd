class_name Tutorial
extends CanvasLayer
## Tutorial jugable de la mesa libre (queja 1 de TTS: el tutorial de TTS solo cubre lo
## básico y los atajos están escondidos). Cada paso se completa haciéndolo de verdad sobre
## la mesa; «Saltar» pasa al siguiente.

## Lo activa el menú principal antes de abrir la mesa libre.
static var requested := false

const STEPS := [
	{"id": "grab", "title": "Agarra una pieza", "text": "Mantén el clic izquierdo sobre un dado o una ficha y arrástrala. Suelta para dejarla."},
	{"id": "orbit", "title": "Da la vuelta a la mesa", "text": "Arrastra con el clic derecho para orbitar la cámara."},
	{"id": "zoom", "title": "Acércate", "text": "Gira la rueda del ratón para acercar o alejar la vista."},
	{"id": "roll", "title": "Tira un dado", "text": "Pon el ratón sobre un dado y pulsa R. Encima de cada pieza ves sus atajos."},
	{"id": "radial", "title": "El menú de cada pieza", "text": "Haz clic derecho (sin arrastrar) sobre una pieza: aparecen todas sus acciones."},
	{"id": "view", "title": "Cambia de asiento", "text": "Pulsa V: vista cenital y vista desde cada asiento. Tu mano privada solo la ves desde tu asiento."},
	{"id": "ping", "title": "Señala algo", "text": "Pulsa P sobre la mesa para que todos miren ahí."},
	{"id": "draw", "title": "Dibuja en la mesa", "text": "Pulsa D y arrastra con el clic izquierdo. Vuelve a pulsar D para salir del pincel."},
	{"id": "done", "title": "¡Ya sabes jugar!", "text": "Añade contadores, bolsas, notas y relojes desde «Partida». F1 abre la ayuda y Rebobinar deshace cualquier cosa."},
]

var table: Node
var grabber: PhysicsGrabber3D
var rig: TabletopCamera3D
var step := 0
var _done_flags := {}
var _card: PanelContainer
var _counter: Label
var _title: Label
var _text: Label
var _skip: Button
var _start_yaw := 0.0
var _start_distance := 0.0
var _advance_at := -1


static func start(main: Node) -> Tutorial:
	var tutorial := Tutorial.new()
	tutorial.name = "Tutorial"
	tutorial.table = main
	main.add_child(tutorial)
	return tutorial


func _ready() -> void:
	layer = 12
	grabber = table.find_child("PhysicsGrabber3D", true, false) as PhysicsGrabber3D
	rig = table.find_child("TabletopCamera3D", true, false) as TabletopCamera3D
	if grabber != null:
		grabber.grab_started.connect(func(_o: InteractiveTableObject) -> void: mark("grab"))
	if rig != null:
		rig.view_changed.connect(func(_v: String) -> void: mark("view"))
	for dice in table.find_children("*", "Dice3D", true, false):
		dice.result_ready.connect(func(_v: int) -> void: mark("roll"))
	table.child_entered_tree.connect(
		func(node: Node) -> void:
			if node.name.begins_with("Ping"):
				mark("ping")
	)
	_build()
	_show_step()


func _build() -> void:
	_card = PanelContainer.new()
	_card.name = "TutorialCard"
	_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_card.offset_left = -400
	_card.offset_right = -18
	_card.offset_top = 112
	_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.PAPER
	box.set_border_width_all(0)
	box.set_corner_radius_all(16)
	box.shadow_color = Color(0.05, 0.04, 0.12, 0.34)
	box.shadow_size = 10
	box.shadow_offset = Vector2(0, 4)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 10
	box.content_margin_bottom = 12
	_card.add_theme_stylebox_override("panel", box)
	add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_card.add_child(column)
	_counter = _label(12, Palette.CORAL)
	column.add_child(_counter)
	_title = _label(22, Palette.INK)
	var style := get_node_or_null("/root/ToonStyle")
	if style != null:
		_title.add_theme_font_override("font", style.DISPLAY_FONT)
	column.add_child(_title)
	_text = _label(15, Palette.INK)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 340
	column.add_child(_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(row)
	_skip = Button.new()
	_skip.name = "Skip"
	_skip.text = "Saltar paso"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.pressed.connect(next_step)
	row.add_child(_skip)
	var close := Button.new()
	close.name = "Close"
	close.text = "Cerrar"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(finish)
	row.add_child(close)


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func current_id() -> String:
	return STEPS[step]["id"]


func mark(id: String) -> void:
	_done_flags[id] = true


func next_step() -> void:
	if step >= STEPS.size() - 1:
		finish()
		return
	step += 1
	_advance_at = -1
	_show_step()


func finish() -> void:
	mark_seen()
	queue_free()


static func mark_seen() -> void:
	var config := ConfigFile.new()
	config.load(UserFiles.SETTINGS)
	config.set_value("tutorial", "seen", true)
	config.save(UserFiles.SETTINGS)


static func was_seen() -> bool:
	var config := ConfigFile.new()
	if config.load(UserFiles.SETTINGS) != OK:
		return false
	return config.get_value("tutorial", "seen", false) == true


func _show_step() -> void:
	var data: Dictionary = STEPS[step]
	_counter.text = tr("TUTORIAL · PASO %d DE %d") % [step + 1, STEPS.size()]
	_title.text = data["title"]
	_text.text = data["text"]
	_skip.text = "Terminar" if step == STEPS.size() - 1 else "Saltar paso"
	_done_flags.erase(data["id"])
	if rig != null:
		_start_yaw = rig._yaw
		_start_distance = rig._target_distance


func _process(_delta: float) -> void:
	var id := current_id()
	match id:
		"orbit":
			if rig != null and absf(rig._yaw - _start_yaw) > 0.35:
				mark(id)
		"zoom":
			if rig != null and absf(rig._target_distance - _start_distance) > 0.6:
				mark(id)
		"radial":
			if grabber != null and grabber.radial_menu.is_open():
				mark(id)
		"draw":
			var brush := table.get_node_or_null("TableBrush") as TableBrush
			if brush != null and not brush.strokes.is_empty() and not brush.active:
				mark(id)
	if _done_flags.get(id, false) and id != "done":
		# Un instante de celebración antes de pasar al siguiente paso.
		if _advance_at < 0:
			_advance_at = Time.get_ticks_msec() + 700
			_counter.text = "¡BIEN!  ✓"
			var sfx := get_node_or_null("/root/Sfx")
			if sfx != null:
				sfx.play("turn")
		elif Time.get_ticks_msec() >= _advance_at:
			next_step()
