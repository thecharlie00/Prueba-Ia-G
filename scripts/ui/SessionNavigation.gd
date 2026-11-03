extends CanvasLayer

const MENU_PATH := "res://scenes/Menu.tscn"
var menu_button: Button
var overlay: Control
var _visible := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	menu_button = Button.new()
	menu_button.name = "OpenMenu"
	menu_button.text = "Menú  ·  Esc"
	menu_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_button.offset_left = -152
	menu_button.offset_right = -20
	menu_button.offset_top = 20
	menu_button.offset_bottom = 56
	menu_button.pressed.connect(_toggle)
	add_child(menu_button)
	overlay = Control.new()
	overlay.name = "PauseOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)
	var background := ColorRect.new()
	background.color = Color(0.02, 0.04, 0.03, 0.8)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(350, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142b21")
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	var title := Label.new()
	title.text = "Partida en pausa"
	title.add_theme_font_size_override("font_size", 26)
	content.add_child(title)
	var hint := Label.new()
	hint.text = "Al volver al menú se descartan los cambios no guardados."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)
	var resume := Button.new()
	resume.name = "Resume"
	resume.text = "Continuar partida"
	resume.pressed.connect(_toggle)
	content.add_child(resume)
	var exit := Button.new()
	exit.name = "ReturnToMenu"
	exit.text = "Volver al menú principal"
	exit.pressed.connect(_return_to_menu)
	content.add_child(exit)


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	menu_button.visible = scene != null and scene.scene_file_path != MENU_PATH and not _visible


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		var scene := get_tree().current_scene
		if scene != null and scene.scene_file_path != MENU_PATH:
			_toggle()
			get_viewport().set_input_as_handled()


func _toggle() -> void:
	if not _visible:
		_cancel_grab()
	_visible = not _visible
	overlay.visible = _visible
	menu_button.visible = not _visible
	get_tree().paused = _visible
	if _visible:
		(overlay.find_child("Resume", true, false) as Button).grab_focus()


func _cancel_grab() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var grabber := scene.find_child("PhysicsGrabber3D", true, false) as PhysicsGrabber3D
	if grabber != null:
		grabber._pending_press = false
		grabber._pending_release = false
		grabber._pending_recovery = null
		grabber._release_reason = "released"
		if is_instance_valid(grabber.held):
			grabber._release("cancelled")


func _return_to_menu() -> void:
	_visible = false
	overlay.visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_PATH)
