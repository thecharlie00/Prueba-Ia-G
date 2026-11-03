extends CanvasLayer

signal controls_changed(click_to_grab: bool)

const MENU_PATH := "res://scenes/Menu.tscn"
var settings_path := "user://diceon_controls.cfg"
var click_to_grab := false
var controls_status: Label
var grab_option: CheckButton
var menu_button: Button
var camera_button: Button
var camera_slot: OptionButton
var camera_save: Button
var camera_load: Button
var camera_status: Label
var overlay: Control
var _visible := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_controls()
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
	camera_button = Button.new()
	camera_button.name = "ResetCamera"
	camera_button.text = "Centrar cámara · Inicio"
	camera_button.pressed.connect(_reset_camera)
	content.add_child(camera_button)
	var views := HBoxContainer.new()
	views.name = "CameraViews"
	content.add_child(views)
	camera_slot = OptionButton.new()
	camera_slot.name = "Slot"
	for slot in range(1, 4):
		camera_slot.add_item("Vista %d" % slot, slot)
	camera_slot.item_selected.connect(_camera_slot_changed)
	views.add_child(camera_slot)
	camera_save = Button.new()
	camera_save.name = "SaveView"
	camera_save.text = "Guardar vista"
	camera_save.pressed.connect(_save_camera_view)
	views.add_child(camera_save)
	camera_load = Button.new()
	camera_load.name = "LoadView"
	camera_load.text = "Ir a vista"
	camera_load.pressed.connect(_load_camera_view)
	views.add_child(camera_load)
	camera_status = Label.new()
	camera_status.name = "ViewStatus"
	camera_status.text = "Vistas temporales: Ctrl+1–3 guarda · Mayús+1–3 recupera."
	camera_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	camera_status.add_theme_font_size_override("font_size", 12)
	content.add_child(camera_status)
	grab_option = CheckButton.new()
	grab_option.name = "ClickToGrab"
	grab_option.text = "Clic para agarrar y clic para soltar"
	grab_option.button_pressed = click_to_grab
	grab_option.toggled.connect(set_click_to_grab)
	content.add_child(grab_option)
	var control_help := Label.new()
	control_help.text = (
		"Sobre la interfaz, el clic cancela la suelta sin activar el botón. "
		+ "Esc cancela y pausa."
	)
	control_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control_help.add_theme_font_size_override("font_size", 12)
	content.add_child(control_help)
	controls_status = Label.new()
	controls_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_status.text = "Con la opción desactivada, mantén pulsado para arrastrar."
	controls_status.add_theme_font_size_override("font_size", 12)
	content.add_child(controls_status)
	var exit := Button.new()
	exit.name = "ReturnToMenu"
	exit.text = "Volver al menú principal"
	exit.pressed.connect(_return_to_menu)
	content.add_child(exit)


func _load_controls() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var saved: Variant = config.get_value("controls", "click_to_grab", false)
	if saved is bool:
		click_to_grab = saved


func set_click_to_grab(enabled: bool) -> void:
	# Cambiar de modo nunca confirma ni deja un agarre pendiente.
	_cancel_grab()
	click_to_grab = enabled
	var grabber := _find_grabber()
	if grabber != null:
		grabber.click_to_grab = enabled
	if is_instance_valid(grab_option):
		grab_option.set_pressed_no_signal(enabled)
	var config := ConfigFile.new()
	config.set_value("controls", "click_to_grab", enabled)
	var error := config.save(settings_path)
	if is_instance_valid(controls_status):
		controls_status.text = (
			"Ajuste guardado en este equipo."
			if error == OK
			else "Ajuste activo para esta sesión; no se pudo guardar."
		)
	controls_changed.emit(enabled)


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
		camera_button.disabled = _find_camera() == null
		_update_camera_views()
		(overlay.find_child("Resume", true, false) as Button).grab_focus()


func _find_camera() -> TabletopCamera3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for node in scene.find_children("*", "Node3D", true, false):
		if node is TabletopCamera3D:
			return node
	return null


func _reset_camera() -> void:
	var camera := _find_camera()
	if camera != null:
		camera.reset_view()


func _camera_slot_changed(_index: int) -> void:
	_update_camera_views()


func _update_camera_views() -> void:
	var camera := _find_camera()
	camera_slot.disabled = camera == null
	camera_save.disabled = camera == null
	camera_load.disabled = camera == null or not camera.has_bookmark(camera_slot.get_selected_id())


func _save_camera_view() -> void:
	var camera := _find_camera()
	var slot := camera_slot.get_selected_id()
	if camera != null and camera.save_bookmark(slot):
		camera_status.text = "Vista %d guardada para esta mesa." % slot
	_update_camera_views()


func _load_camera_view() -> void:
	var camera := _find_camera()
	var slot := camera_slot.get_selected_id()
	if camera != null and camera.load_bookmark(slot):
		camera_status.text = "Vista %d recuperada." % slot
	_update_camera_views()


func _find_grabber() -> PhysicsGrabber3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("PhysicsGrabber3D", true, false) as PhysicsGrabber3D


func _cancel_grab() -> void:
	var grabber := _find_grabber()
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
