class_name Note3D
extends TableUtility
## Nota adhesiva: Intro (o «Escribir» en el menú radial) abre un cuadro para editar el texto.

const MAX_LENGTH := 140

@export var text := "Nota"
var _label: Label3D
var _editor: CanvasLayer


func _ready() -> void:
	super._ready()
	$Visual.mesh = PieceKit.rounded_slab(Vector3(0.7, 0.03, 0.7), 0.04, 0.01)
	$Visual.material_override = _material(piece_color, 0.85)
	var tape := MeshInstance3D.new()
	tape.name = "Tape"
	tape.mesh = PieceKit.rounded_slab(Vector3(0.26, 0.012, 0.09), 0.01, 0.004)
	tape.position = Vector3(0, 0.02, -0.33)
	var tape_material := _material(Color(1, 1, 1, 0.55), 0.4)
	tape_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tape.material_override = tape_material
	$Visual.add_child(tape)
	_label = Label3D.new()
	_label.name = "NoteText"
	_label.rotation_degrees.x = -90.0
	_label.position.y = 0.018
	_label.pixel_size = 0.0016
	_label.font_size = 64
	_label.width = 380.0
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.modulate = Palette.INK
	_label.outline_size = 0
	var style := get_node_or_null("/root/ToonStyle")
	if style != null:
		_label.font = style.BODY_FONT
	add_child(_label)
	set_text(text)


func set_text(value: String) -> void:
	text = value.strip_edges().substr(0, MAX_LENGTH)
	if _label != null:
		_label.text = text


func open_editor() -> LineEdit:
	if is_instance_valid(_editor):
		return _editor.find_child("NoteInput", true, false) as LineEdit
	_editor = CanvasLayer.new()
	_editor.name = "NoteEditor"
	_editor.layer = 40
	add_child(_editor)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_editor.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Escribe la nota"
	column.add_child(title)
	var input := LineEdit.new()
	input.name = "NoteInput"
	input.custom_minimum_size = Vector2(420, 44)
	input.max_length = MAX_LENGTH
	input.text = text
	input.select_all_on_focus = true
	column.add_child(input)
	var done := Button.new()
	done.text = "Hecho · Intro"
	column.add_child(done)
	input.text_submitted.connect(func(value: String) -> void: close_editor(value))
	done.pressed.connect(func() -> void: close_editor(input.text))
	input.grab_focus.call_deferred()
	return input


func close_editor(value: String) -> void:
	set_text(value)
	if is_instance_valid(_editor):
		_editor.queue_free()
	_editor = null
	_bump()


func handle_shortcut(keycode: int) -> bool:
	if keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
		open_editor()
		return true
	return false


func radial_actions() -> Array[Dictionary]:
	return [{"label": "Escribir", "key": "Intro", "keycode": KEY_ENTER}]


func shortcut_hint() -> String:
	return "Nota · Intro escribir · Q/E girar · L bloquear"


func extra_data() -> Dictionary:
	return {"text": text, "color": [piece_color.r, piece_color.g, piece_color.b, piece_color.a]}


func apply_extra(data: Dictionary) -> void:
	set_text(String(data["text"]))
