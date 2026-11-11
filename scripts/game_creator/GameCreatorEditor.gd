# GameCreatorEditor.gd
# Escena de entrada al Editor Universal de Juegos (Game Creator Studio).
# Inicializa el GameCreatorCore (autoload) y construye el workspace estilo IDE
# con Viewport 3D, Inspector, Jerarquía de Escena y Asset Browser.
class_name GameCreatorEditor
extends Control

@onready var _viewport_container: ViewportContainer = $ViewportContainer
@onready var _docks: HBoxContainer = $Docks
@onready var _status_bar: Label = $StatusBar/StatusLabel

# Estado del editor.
var _build_mode: Boolean = true

func _ready() -> void:
	# Asegurar que el core del editor esté disponible.
	var core: GameCreatorCore = get_node_or_null("/root/GameCreatorCore")
	if core == null:
		push_error("[GameCreatorEditor] GameCreatorCore no está registrado como autoload.")
		return

	core.enter_build_mode()
	core.state_changed.connect(_on_state_changed)

	_build_editor_ui()
	_update_status("Editor de juegos — Modo construcción")

	# Foco inicial.
	var btn := $Docks/LeftDock/BuildModeButton
	if btn != null:
		btn.grab_focus.call_deferred()

func _build_editor_ui() -> void:
	# Limpiar contenido previo de los docks.
	for child in _docks.get_children():
		child.queue_free()

	# Dock izquierdo: Modos y herramientas.
	var left := _make_dock("LeftDock")
	_docks.add_child(left)

	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 8)
	left.add_child(left_col)

	var mode_label := Label.new()
	mode_label.text = "MODO DE EDICIÓN"
	mode_label.add_theme_font_size_override("font_size", 11)
	mode_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	left_col.add_child(mode_label)

	var build_btn := Button.new()
	build_btn.name = "BuildModeButton"
	build_btn.text = "▶ Cambiar a Prueba (Playtest)"
	build_btn.custom_minimum_size = Vector2(0, 40)
	build_btn.pressed.connect(_toggle_mode)
	left_col.add_child(build_btn)

	var test_btn := Button.new()
	test_btn.name = "PlaytestButton"
	test_btn.text = "⏸ Volver a Edición"
	test_btn.custom_minimum_size = Vector2(0, 40)
	test_btn.visible = false
	test_btn.pressed.connect(_toggle_mode)
	left_col.add_child(test_btn)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_child(spacer)

	var new_entity_btn := Button.new()
	new_entity_btn.text = "+ Nueva entidad"
	new_entity_btn.custom_minimum_size = Vector2(0, 36)
	new_entity_btn.pressed.connect(func() -> void: _spawn_example_entity())
	left_col.add_child(new_entity_btn)

	# Dock derecho: Inspector de propiedades.
	var right := _make_dock("RightDock")
	_docks.add_child(right)

	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 8)
	right.add_child(right_col)

	var insp_label := Label.new()
	insp_label.text = "INSPECTOR"
	insp_label.add_theme_font_size_override("font_size", 11)
	insp_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	right_col.add_child(insp_label)

	var inspect_target := Label.new()
	inspect_target.text = "Selecciona una entidad en el viewport."
	inspect_target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_target.add_theme_font_size_override("font_size", 13)
	inspect_target.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	right_col.add_child(inspect_target)

	# Placeholder de propiedades.
	var props_well := _make_card_well("Propiedades")
	right_col.add_child(props_well)

	var props_col := VBoxContainer.new()
	props_col.add_theme_constant_override("separation", 6)
	props_well.add_child(props_col)

	var pos_lbl := Label.new()
	pos_lbl.text = "Posición: (0, 0, 0)"
	pos_lbl.add_theme_font_size_override("font_size", 12)
	pos_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	props_col.add_child(pos_lbl)

	var rot_lbl := Label.new()
	rot_lbl.text = "Rotación: (0, 0, 0)"
	rot_lbl.add_theme_font_size_override("font_size", 12)
	rot_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	props_col.add_child(rot_lbl)

	# Dock inferior: consola / log.
	var bottom_dock := _make_dock("BottomDock")
	_docks.add_child(bottom_dock)

	var bottom_col := VBoxContainer.new()
	bottom_col.add_theme_constant_override("separation", 4)
	bottom_dock.add_child(bottom_col)

	var log_label := Label.new()
	log_label.text = "CONSOLA"
	log_label.add_theme_font_size_override("font_size", 11)
	log_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	bottom_col.add_child(log_label)

	var log_text := Label.new()
	log_text.name = "LogText"
	log_text.text = "> Editor iniciado. Construye tu tablero, configura reglas y prueba."
	log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_text.add_theme_font_size_override("font_size", 12)
	log_text.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	bottom_col.add_child(log_text)

func _make_dock(name: String) -> Control:
	var dock := Control.new()
	dock.name = name
	dock.custom_minimum_size = Vector2(260, 0)
	dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	dock.add_child(col)
	return dock

func _make_card_well(title: String) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(0, 120)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 12)
	t.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	col.add_child(t)
	return card

func _on_state_changed(new_state: GameCreatorCore.EditorState) -> void:
	_build_mode = (new_state == GameCreatorCore.EditorState.BUILD)
	var build_btn := $Docks/LeftDock/BuildModeButton
	var test_btn := $Docks/LeftDock/PlaytestButton
	if build_btn != null:
		build_btn.visible = _build_mode
		build_btn.text = "▶ Cambiar a Prueba (Playtest)" if _build_mode else "▶ Cambiar a Prueba (Playtest)"
	if test_btn != null:
		test_btn.visible = not _build_mode
	var log := $Docks/BottomDock/LogText
	if log != null:
		log.text = "> Modo: " + ("Construcción (Build)" if _build_mode else "Prueba (Playtest)")

func _toggle_mode() -> void:
	var core: GameCreatorCore = get_node_or_null("/root/GameCreatorCore")
	if core == null:
		return
	if _build_mode:
		core.enter_playtest_mode()
	else:
		core.enter_build_mode()

func _spawn_example_entity() -> void:
	var core: GameCreatorCore = get_node_or_null("/root/GameCreatorCore")
	if core == null:
		return
	var log := $Docks/BottomDock/LogText
	if log != null:
		log.text = "> Entidad de ejemplo creada (usa el Inspector para configurarla)."

func _update_status(message: String) -> void:
	if _status_bar != null:
		_status_bar.text = message

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")
		get_viewport().set_input_as_handled()
