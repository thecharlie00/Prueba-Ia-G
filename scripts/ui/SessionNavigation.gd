extends CanvasLayer

signal controls_changed(click_to_grab: bool)

const MENU_PATH := "res://scenes/BotMenu.tscn"

## Pantallas de menú (no son mesas): en ellas no aparecen los botones de
## sesión ni la pausa. La salida desde una mesa siempre vuelve al menú principal.
const MENU_SCENES := [
	"res://scenes/BotMenu.tscn",
	"res://scenes/ModeSelect.tscn",
	"res://scenes/Menu.tscn",
	"res://scenes/BotSelect.tscn",
	"res://scenes/Lobby.tscn",
]

var settings_path := "user://diceon_controls.cfg"
var click_to_grab := false
var controls_status: Label
var grab_option: CheckButton
var _sound_option: CheckButton
var _motion_option: CheckButton
var _emblem_slot: HBoxContainer
var menu_button: Button
var help_button: Button
var undo_button: Button
var controls_dialog: AcceptDialog
var camera_button: Button
var camera_slot: OptionButton
var camera_save: Button
var camera_load: Button
var camera_status: Label
var overlay: Control
var _ui_scene: Node
var _ui_grabber: PhysicsGrabber3D
var _exit_confirmation := false
var _visible := false
## Hueco que se deja a la derecha para el botón «Partida» del HUD de la mesa.
const HUD_RESERVE := 172.0
var _top_reserve := -1.0


func _in_game(scene: Node) -> bool:
	return scene != null and not MENU_SCENES.has(scene.scene_file_path)


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
	menu_button.offset_top = 16
	menu_button.offset_bottom = 54
	MenuStyle.style_secondary(menu_button, 12, 5)
	menu_button.pressed.connect(_toggle)
	add_child(menu_button)

	help_button = Button.new()
	help_button.name = "ControlsHelp"
	help_button.text = "Ayuda · F1"
	help_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	help_button.offset_left = -290
	help_button.offset_right = -164
	help_button.offset_top = 16
	help_button.offset_bottom = 54
	MenuStyle.style_secondary(help_button, 12, 5)
	help_button.pressed.connect(_toggle_help)
	add_child(help_button)

	undo_button = Button.new()
	undo_button.name = "UndoPhysical"
	undo_button.text = "Deshacer pieza"
	undo_button.tooltip_text = "Ctrl+Z: devuelve la última pieza movida, sin deshacer otras acciones."
	undo_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	undo_button.offset_left = -456
	undo_button.offset_right = -302
	undo_button.offset_top = 16
	undo_button.offset_bottom = 54
	MenuStyle.style_secondary(undo_button, 12, 5)
	undo_button.pressed.connect(_request_movement_undo)
	add_child(undo_button)

	controls_dialog = AcceptDialog.new()
	controls_dialog.name = "ControlsGuide"
	controls_dialog.title = "Controles de mesa"
	controls_dialog.dialog_autowrap = true
	controls_dialog.exclusive = true
	add_child(controls_dialog)
	controls_dialog.get_ok_button().text = "Entendido"

	overlay = Control.new()
	overlay.name = "PauseOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)

	var background := ColorRect.new()
	background.color = Color(0.08, 0.06, 0.17, 0.80)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(background)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay.add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	center.add_child(margin)

	var panel := MenuStyle.make_card_panel(
		"PauseCard", Palette.PANEL, Palette.INK, 26, 22, 22, 6
	)
	panel.custom_minimum_size = Vector2(468, 0)
	margin.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	# Cabecera con emblema dinámico de la mesa actual
	var head_row := HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 12)
	content.add_child(head_row)

	_emblem_slot = HBoxContainer.new()
	head_row.add_child(_emblem_slot)

	var head_col := VBoxContainer.new()
	head_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_col.add_theme_constant_override("separation", 1)
	head_row.add_child(head_col)

	head_col.add_child(MenuStyle.make_eyebrow("SESIÓN EN CURSO", Palette.SUN))
	var title := MenuStyle.make_title("Partida en pausa", 28)
	head_col.add_child(title)

	var hint := MenuStyle.make_muted(
		"Al volver al menú se descartan los cambios no guardados.", 13
	)
	hint.name = "PauseHint"
	content.add_child(hint)

	var resume := Button.new()
	resume.name = "Resume"
	resume.text = "Continuar partida"
	resume.custom_minimum_size = Vector2(0, 48)
	resume.add_theme_font_override("font", MenuStyle.DISPLAY_FONT)
	resume.add_theme_font_size_override("font_size", 20)
	MenuStyle.style_primary(resume, 14, 6)
	resume.pressed.connect(_toggle)
	content.add_child(resume)

	# Subtarjeta 1: Cámara y marcadores de vista
	var cam_card := MenuStyle.make_card_panel(
		"CameraSection", MenuStyle.CARD_SURFACE, Palette.INK, 14, 12, 16, 0
	)
	content.add_child(cam_card)

	var cam_col := VBoxContainer.new()
	cam_col.add_theme_constant_override("separation", 8)
	cam_card.add_child(cam_col)

	cam_col.add_child(MenuStyle.make_eyebrow("CÁMARA Y VISTAS", Palette.SUN_LIGHT))

	camera_button = Button.new()
	camera_button.name = "ResetCamera"
	camera_button.text = "Centrar cámara · Inicio"
	camera_button.custom_minimum_size = Vector2(0, 40)
	MenuStyle.style_secondary(camera_button, 12, 5)
	camera_button.pressed.connect(_reset_camera)
	cam_col.add_child(camera_button)

	var views := HBoxContainer.new()
	views.name = "CameraViews"
	views.add_theme_constant_override("separation", 8)
	cam_col.add_child(views)

	camera_slot = OptionButton.new()
	camera_slot.name = "Slot"
	for slot in range(1, 4):
		camera_slot.add_item("Vista %d" % slot, slot)
	MenuStyle.style_secondary(camera_slot, 10, 5)
	camera_slot.item_selected.connect(_camera_slot_changed)
	views.add_child(camera_slot)

	camera_save = Button.new()
	camera_save.name = "SaveView"
	camera_save.text = "Guardar vista"
	camera_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuStyle.style_secondary(camera_save, 10, 5)
	camera_save.pressed.connect(_save_camera_view)
	views.add_child(camera_save)

	camera_load = Button.new()
	camera_load.name = "LoadView"
	camera_load.text = "Ir a vista"
	camera_load.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuStyle.style_secondary(camera_load, 10, 5)
	camera_load.pressed.connect(_load_camera_view)
	views.add_child(camera_load)

	camera_status = MenuStyle.make_muted(
		"Vistas temporales: Ctrl+1–3 guarda · Mayús+1–3 recupera.", 12
	)
	camera_status.name = "ViewStatus"
	cam_col.add_child(camera_status)

	# Subtarjeta 2: Controles y comodidad
	var opts_card := MenuStyle.make_card_panel(
		"QuickSettingsSection", MenuStyle.CARD_WELL, Palette.INK, 14, 10, 16, 0
	)
	content.add_child(opts_card)

	var opts_col := VBoxContainer.new()
	opts_col.add_theme_constant_override("separation", 5)
	opts_card.add_child(opts_col)

	grab_option = CheckButton.new()
	grab_option.name = "ClickToGrab"
	grab_option.text = "Clic para agarrar y clic para soltar"
	grab_option.button_pressed = click_to_grab
	grab_option.toggled.connect(set_click_to_grab)
	opts_col.add_child(grab_option)

	_sound_option = CheckButton.new()
	_sound_option.name = "PauseSoundEffects"
	_sound_option.text = "Efectos de sonido"
	_sound_option.toggled.connect(func(on: bool) -> void:
		var sfx := get_node_or_null("/root/Sfx")
		if sfx != null:
			sfx.set_enabled(on)
	)
	opts_col.add_child(_sound_option)

	_motion_option = CheckButton.new()
	_motion_option.name = "PauseReduceMotion"
	_motion_option.text = "Reducir animaciones"
	_motion_option.toggled.connect(func(on: bool) -> void:
		var style := get_node_or_null("/root/ToonStyle")
		if style != null:
			style.set_reduce_motion(on)
	)
	opts_col.add_child(_motion_option)

	var control_help := MenuStyle.make_muted(
		"Sobre la interfaz, el clic cancela la suelta sin activar el botón. Esc cancela y pausa.",
		12
	)
	opts_col.add_child(control_help)

	controls_status = MenuStyle.make_muted(
		"Con la opción desactivada, mantén pulsado para arrastrar.", 12
	)
	opts_col.add_child(controls_status)

	# Botones de salida con confirmación en dos pasos
	var exit_row := HBoxContainer.new()
	exit_row.add_theme_constant_override("separation", 10)
	content.add_child(exit_row)

	var cancel_exit := Button.new()
	cancel_exit.name = "CancelExit"
	cancel_exit.text = "Seguir jugando"
	cancel_exit.visible = false
	cancel_exit.custom_minimum_size = Vector2(0, 44)
	cancel_exit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuStyle.style_primary(cancel_exit, 12, 6)
	cancel_exit.pressed.connect(_cancel_return_to_menu)
	exit_row.add_child(cancel_exit)

	var exit := Button.new()
	exit.name = "ReturnToMenu"
	exit.text = "Volver al menú principal"
	exit.custom_minimum_size = Vector2(0, 44)
	exit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	MenuStyle.style_secondary(exit, 12, 6)
	exit.pressed.connect(_request_return_to_menu)
	exit_row.add_child(exit)


func _layout_top_row(reserve: float) -> void:
	if is_equal_approx(reserve, _top_reserve):
		return
	_top_reserve = reserve
	var right := -20.0 - reserve
	for entry in [[menu_button, 136.0], [help_button, 128.0]]:
		var button: Button = entry[0]
		button.offset_right = right
		button.offset_left = right - entry[1]
		right -= entry[1] + 10.0
	# Con HUD, «Deshacer pieza» baja a una segunda fila para no chocar con el cartel central.
	var below := reserve > 0.0
	undo_button.offset_right = -20.0 - reserve if below else right
	undo_button.offset_left = undo_button.offset_right - 156.0
	undo_button.offset_top = 62.0 if below else 16.0
	undo_button.offset_bottom = undo_button.offset_top + 38.0


func _load_controls() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	var saved: Variant = config.get_value("controls", "click_to_grab", false)
	if saved is bool:
		click_to_grab = saved


func set_click_to_grab(enabled: bool) -> void:
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
	var in_game := _in_game(scene)
	menu_button.visible = in_game and not _visible
	help_button.visible = in_game and not _visible
	var hud := scene.get_node_or_null("TableHud") if in_game else null
	_layout_top_row(HUD_RESERVE if hud != null else 0.0)
	if scene != _ui_scene or (is_instance_valid(_ui_grabber) and not _ui_grabber.is_inside_tree()):
		_ui_scene = scene
		_ui_grabber = _find_grabber() if in_game else null
	var physical_undo := is_instance_valid(_ui_grabber) and _ui_grabber.lock_shortcut_enabled
	undo_button.visible = in_game and not _visible and physical_undo
	undo_button.disabled = (
		not physical_undo
		or not _ui_grabber.can_undo_movement()
		or is_instance_valid(_ui_grabber.held)
		or _ui_grabber._pending_press
		or _ui_grabber._pending_release
		or _ui_grabber._pending_undo
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F1 and event.pressed and not event.echo:
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:
			return
		if not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
			var scene := get_tree().current_scene
			if _in_game(scene):
				_toggle_help()
				get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		var scene := get_tree().current_scene
		if _in_game(scene):
			_toggle()
			get_viewport().set_input_as_handled()


func _request_movement_undo() -> void:
	var grabber := _find_grabber()
	if grabber != null and not get_tree().paused:
		grabber.request_movement_undo()


func _toggle_help() -> void:
	if controls_dialog.visible:
		controls_dialog.hide()
		return
	_cancel_grab()
	var grabber := _find_grabber()
	var guide := "CÁMARA\nDerecho: orbitar · Rueda: zoom · Inicio: recentrar.\n"
	if grabber != null:
		guide += "\nPIEZAS\n"
		guide += (
			"Un clic agarra y otro suelta. "
			if grabber.click_to_grab
			else "Mantén pulsado para agarrar y suelta para colocar. "
		)
		guide += (
			"Rueda con pieza sujeta: altura. X: cancelar el agarre.\n"
			+ "H: recuperar la pieza señalada o la última señalada.\n"
			+ "Q/E: girar · F: voltear carta o dominó · R: mezclar o lanzar según la mesa.\n"
		)
		if grabber.lock_shortcut_enabled:
			guide += "L: bloquear o desbloquear · Alt: inspeccionar sin revelar cartas ocultas.\n"
			guide += "Ctrl+Z: devolver la última pieza movida si su destino está libre.\n"
		if is_instance_valid(grabber.snap_grid):
			guide += "S: activar o desactivar la cuadrícula magnética.\n"
	else:
		guide += "\nElige una pieza y después su destino con clic.\n"
	guide += (
		"\nEsc: pausa y menú · F1: esta ayuda. " + "Las acciones disponibles dependen de la mesa."
	)
	controls_dialog.dialog_text = guide
	controls_dialog.popup_centered(Vector2i(560, 360))


func _refresh_pause_meta(scene: Node) -> void:
	if _emblem_slot != null:
		for child in _emblem_slot.get_children():
			_emblem_slot.remove_child(child)
			child.queue_free()
		var key := GameThemes.key_for(scene)
		_emblem_slot.add_child(MenuStyle.make_emblem_badge(key, 30.0, MenuStyle.CARD_WELL))
	var sfx := get_node_or_null("/root/Sfx")
	if _sound_option != null and sfx != null:
		_sound_option.set_pressed_no_signal(sfx.get("enabled") == true)
	var style := get_node_or_null("/root/ToonStyle")
	if _motion_option != null and style != null:
		_motion_option.set_pressed_no_signal(style.get("reduce_motion") == true)


func _toggle() -> void:
	if not _visible:
		_cancel_grab()
	_exit_confirmation = false
	_set_exit_confirmation_visible(false)
	_visible = not _visible
	overlay.visible = _visible
	menu_button.visible = not _visible
	var scene := get_tree().current_scene
	var is_online: bool = scene != null and scene.get("online") == true
	get_tree().paused = _visible and not is_online
	if _visible:
		_refresh_pause_meta(scene)
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
	_exit_confirmation = false
	_visible = false
	overlay.visible = false
	get_tree().paused = false
	var scene := get_tree().current_scene
	if scene != null and scene.get("online") == true:
		var net := get_node_or_null("/root/Net")
		if net != null and net.has_method("leave_room"):
			net.leave_room()
	get_tree().change_scene_to_file(MENU_PATH)


func _request_return_to_menu() -> void:
	if not _exit_confirmation:
		_exit_confirmation = true
		_set_exit_confirmation_visible(true)
		(overlay.find_child("CancelExit", true, false) as Button).grab_focus()
		return
	_return_to_menu()


func _cancel_return_to_menu() -> void:
	_exit_confirmation = false
	_set_exit_confirmation_visible(false)
	(overlay.find_child("Resume", true, false) as Button).grab_focus()


func _set_exit_confirmation_visible(visible: bool) -> void:
	var hint := overlay.find_child("PauseHint", true, false) as Label
	var exit := overlay.find_child("ReturnToMenu", true, false) as Button
	var cancel_exit := overlay.find_child("CancelExit", true, false) as Button
	if visible:
		hint.text = "Se perderá el progreso no guardado de esta partida. ¿Quieres salir?"
		hint.add_theme_color_override("font_color", Palette.CORAL.lightened(0.22))
		exit.text = "Sí, descartar y salir"
		MenuStyle.style_danger(exit, 12)
	else:
		hint.text = "Al volver al menú se descartan los cambios no guardados."
		hint.add_theme_color_override("font_color", Palette.MUTED)
		exit.text = "Volver al menú principal"
		MenuStyle.style_secondary(exit, 12, 6)
	cancel_exit.visible = visible
