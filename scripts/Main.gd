extends Node3D

const CONFIRM_ACTION := preload("res://scripts/ui/ConfirmAction.gd")

@export var sandbox_save_path := "user://tablerama_sandbox.json"

var confirm_action: ConfirmAction
@onready var selection_label: Label = $UI/Margin/Panel/Content/Selection
@onready var result_label: Label = $UI/Margin/Panel/Content/Result
@onready var grabber: PhysicsGrabber3D = $PhysicsGrabber3D


var timeline: TableTimeline
var zones: Array[HiddenZone3D] = []

## Componentes utilitarios que se pueden añadir desde el cajón (queja 18 de TTS).
const UTILITY_SCENES := {
	"counter": "res://scenes/Counter3D.tscn",
	"bag": "res://scenes/Bag3D.tscn",
	"note": "res://scenes/Note3D.tscn",
	"timer": "res://scenes/Timer3D.tscn",
	"scoreboard": "res://scenes/Scoreboard3D.tscn",
}
const UTILITY_LABELS := {
	"counter": "Contador", "bag": "Bolsa", "note": "Nota", "timer": "Reloj", "scoreboard": "Marcador"
}


func _ready() -> void:
	TableHud.attach.call_deferred(self)
	# Rebobinar: línea de tiempo con los momentos de la mesa (fase 2).
	timeline = TableTimeline.new()
	timeline.table = self
	add_child(timeline)
	var rewind := Button.new()
	rewind.name = "Rewind"
	rewind.text = "Rebobinar"
	rewind.tooltip_text = "Vuelve la mesa a cualquier momento anterior"
	rewind.pressed.connect(timeline.toggle)
	$UI/Margin/Panel/Content.add_child(rewind)
	$UI/Margin/Panel/Content.move_child(rewind, $UI/Margin/Panel/Content/Reset.get_index())
	confirm_action = CONFIRM_ACTION.new()
	add_child(confirm_action)
	grabber.selection_changed.connect(_on_selection_changed)
	grabber.snap_status_changed.connect(_on_snap_status_changed)
	grabber.placement_message.connect(_on_placement_message)
	$UI/Margin/Panel/Content/SaveRow/Save.pressed.connect(_on_save_pressed)
	confirm_action.bind_button(
		$UI/Margin/Panel/Content/SaveRow/Load as Button,
		"Cargar mesa",
		"La partida actual será sustituida por el guardado local. ¿Continuar?",
		_on_load_pressed,
		_can_store
	)
	confirm_action.bind_button(
		$UI/Margin/Panel/Content/Reset as Button,
		"Reiniciar mesa",
		"Se descartarán los cambios actuales. ¿Continuar?",
		_on_reset_pressed,
		_can_store
	)
	confirm_action.bind_button(
		$UI/Margin/Panel/Content/Chess as Button,
		"Cambiar de mesa",
		"Se descartarán los cambios actuales. ¿Continuar?",
		_on_chess_pressed,
		_can_store
	)
	confirm_action.bind_button(
		$UI/Margin/Panel/Content/Checkers as Button,
		"Cambiar de mesa",
		"Se descartarán los cambios actuales. ¿Continuar?",
		_on_checkers_pressed,
		_can_store
	)
	confirm_action.bind_button(
		$UI/Margin/Panel/Content/PhysicalCheckers as Button,
		"Cambiar de mesa",
		"Se descartarán los cambios actuales. ¿Continuar?",
		_on_physical_checkers_pressed,
		_can_store
	)
	confirm_action.bind_button(
		$UI/Margin/Panel/Content/GuidedPhysicalCheckers as Button,
		"Cambiar de mesa",
		"Se descartarán los cambios actuales. ¿Continuar?",
		_on_guided_checkers_pressed,
		_can_store
	)
	confirm_action.bind_button(
		$UI/Margin/Panel/Content/PhysicalDomino as Button,
		"Cambiar de mesa",
		"Se descartarán los cambios actuales. ¿Continuar?",
		_on_physical_domino_pressed,
		_can_store
	)
	grabber.grab_finished.connect(_on_grab_finished)
	_build_zones()
	_build_tools_row()
	_connect_objects()
	# Tutorial jugable: desde el menú o la primera vez que se abre la mesa libre.
	if Tutorial.requested or (not Tutorial.was_seen() and DisplayServer.get_name() != "headless"):
		Tutorial.requested = false
		Tutorial.start.call_deferred(self)


## Zonas privadas de J1 (abajo) y J2 (enfrente). V cambia de asiento y, con él, quién mira.
func _build_zones() -> void:
	var specs := [
		{"seat": 1, "at": Vector3(1.6, 0.822, 1.75), "turn": 0.0, "color": Palette.CORAL},
		{"seat": 2, "at": Vector3(-1.6, 0.822, -1.75), "turn": PI, "color": Palette.PLAYER_BLUE},
	]
	for spec in specs:
		var zone := HiddenZone3D.new()
		zone.name = "HiddenZone%d" % spec["seat"]
		zone.owner_seat = spec["seat"]
		zone.zone_color = spec["color"]
		zone.objects = $Objects
		add_child(zone)
		zone.position = spec["at"]
		zone.rotation.y = spec["turn"]
		zones.append(zone)
	$TabletopCamera3D.view_changed.connect(_on_view_changed)


func _on_view_changed(view_name: String) -> void:
	if not view_name.begins_with("seat"):
		return
	var seat := int(view_name.substr(4))
	for zone in zones:
		zone.set_viewer(seat)
	result_label.text = tr("Ahora miras desde el asiento %d: ves tu mano y las de los demás quedan tapadas.") % seat


func _build_tools_row() -> void:
	var content := $UI/Margin/Panel/Content
	var title := Label.new()
	title.name = "AddTitle"
	title.text = "Añadir a la mesa"
	title.add_theme_font_size_override("font_size", 12)
	content.add_child(title)
	content.move_child(title, $UI/Margin/Panel/Content/Reset.get_index())
	var row := HBoxContainer.new()
	row.name = "AddRow"
	content.add_child(row)
	content.move_child(row, $UI/Margin/Panel/Content/Reset.get_index())
	for kind in UTILITY_LABELS:
		var button := Button.new()
		button.name = "Add" + kind.capitalize()
		button.text = UTILITY_LABELS[kind]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(spawn_utility.bind(kind))
		row.add_child(button)
	var extras := HBoxContainer.new()
	extras.name = "ExtrasRow"
	content.add_child(extras)
	content.move_child(extras, $UI/Margin/Panel/Content/Reset.get_index())
	var tutorial := Button.new()
	tutorial.name = "TutorialButton"
	tutorial.text = "Tutorial jugable"
	tutorial.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial.pressed.connect(
		func() -> void:
			if get_node_or_null("Tutorial") == null:
				Tutorial.start(self)
	)
	extras.add_child(tutorial)
	var flip := Button.new()
	flip.name = "FlipTable"
	flip.text = "¡Volcar la mesa!  Ctrl+F"
	flip.tooltip_text = "Todo sale volando. Rebobinar lo deja como estaba."
	flip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flip.pressed.connect(flip_table)
	extras.add_child(flip)
	# La chuleta de atajos se pliega: los atajos ya flotan sobre cada pieza y F1 los lista.
	var controls := $UI/Margin/Panel/Content/Controls as Label
	controls.visible = false
	var toggle := Button.new()
	toggle.name = "ShortcutsToggle"
	toggle.text = "Atajos de teclado"
	toggle.toggle_mode = true
	toggle.toggled.connect(func(on: bool) -> void: controls.visible = on)
	content.add_child(toggle)
	content.move_child(toggle, controls.get_index())


func spawn_utility(kind: String) -> InteractiveTableObject:
	if not UTILITY_SCENES.has(kind) or $Objects.get_child_count() >= SandboxPersistence.MAX_OBJECTS:
		result_label.text = "La mesa está llena: guarda piezas en una bolsa o retira alguna."
		return null
	var object := (load(UTILITY_SCENES[kind]) as PackedScene).instantiate() as InteractiveTableObject
	object.name = UTILITY_LABELS[kind]
	$Objects.add_child(object, true)
	var spread := $Objects.get_child_count() % 5
	object.global_position = Vector3(-0.8 + spread * 0.4, 1.3, 0.2)
	result_label.text = tr("%s añadido a la mesa.") % tr(UTILITY_LABELS[kind])
	return object


## Al soltar una pieza sobre una bolsa, entra en ella.
func _on_grab_finished(object: InteractiveTableObject, target: Vector3, reason: String) -> void:
	if reason != "released" or not is_instance_valid(object):
		return
	for child in $Objects.get_children():
		var bag := child as Bag3D
		if bag == null or not bag.can_hold(object):
			continue
		var flat := Vector2(target.x - bag.global_position.x, target.z - bag.global_position.z)
		if flat.length() <= Bag3D.DROP_RADIUS:
			_bag_later.call_deferred(bag, object)
			return
	match TableStacking.on_release($Objects, object, target):
		"deck":
			result_label.text = "Carta añadida arriba del mazo."
		"new_deck":
			result_label.text = "Dos cartas juntas forman un mazo nuevo."


func _bag_later(bag: Bag3D, object: InteractiveTableObject) -> void:
	if is_instance_valid(bag) and is_instance_valid(object) and not object.is_grabbed:
		if bag.put(object):
			result_label.text = "Pieza guardada en la bolsa · N saca una al azar."


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_F
		and event.ctrl_pressed
		and not event.alt_pressed
	):
		flip_table()
		get_viewport().set_input_as_handled()


## Volcar la mesa en clave cartoon (queja 16): las piezas sueltas saltan, la mesa da un
## respingo y la cámara tiembla. Se deshace con Rebobinar.
func flip_table() -> bool:
	if not _can_store():
		return false
	var moved := 0
	for child in $Objects.get_children():
		var object := child as InteractiveTableObject
		if object == null or object.is_table_locked or object.freeze:
			continue
		object.sleeping = false
		var velocity := Vector3(randf_range(-1.4, 1.4), randf_range(3.2, 4.2), randf_range(-2.8, -1.6))
		object.apply_central_impulse(velocity * object.mass)
		object.apply_torque_impulse(
			Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * object.mass * 0.6
		)
		moved += 1
	var style := get_node_or_null("/root/ToonStyle")
	if style == null or not style.reduce_motion:
		var lift := create_tween()
		for part in $Table.get_children():
			if part is MeshInstance3D:
				var rest: Vector3 = part.position
				lift.parallel().tween_property(part, "position:y", rest.y + 0.22, 0.12).set_ease(Tween.EASE_OUT)
		lift.chain()
		for part in $Table.get_children():
			if part is MeshInstance3D:
				lift.parallel().tween_property(part, "position:y", part.position.y, 0.35).set_trans(
					Tween.TRANS_BOUNCE
				).set_ease(Tween.EASE_OUT)
		var rig: Node3D = $TabletopCamera3D/Camera3D
		var shake := create_tween()
		for i in 6:
			shake.tween_property(rig, "h_offset", randf_range(-0.12, 0.12), 0.04)
		shake.tween_property(rig, "h_offset", 0.0, 0.05)
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play("dice")
		sfx.play("drop")
	result_label.text = tr("¡Mesa volcada! (%d piezas por los aires) · Rebobinar la deja como estaba.") % moved
	return true


func _connect_objects() -> void:
	for object in $Objects.get_children():
		if object is Dice3D:
			object.result_ready.connect(_on_dice_result)
		elif object is Deck3D:
			object.card_drawn.connect(_on_card_drawn.bind(object))
			object.deck_shuffled.connect(_on_deck_shuffled.bind(object))


func _on_selection_changed(object: InteractiveTableObject) -> void:
	if is_instance_valid(object):
		selection_label.text = (
			("CARTA" if object is Card3D else object.display_name.to_upper())
			+ (" · BLOQUEADA" if object.is_table_locked else "")
		)
	elif is_instance_valid(grabber.last_selected):
		selection_label.text = (
			"ÚLTIMA: %s · H PARA RECUPERAR"
			% (
				"CARTA"
				if grabber.last_selected is Card3D
				else grabber.last_selected.display_name.to_upper()
			)
		)
	else:
		selection_label.text = "NINGUNA PIEZA SELECCIONADA"


func _on_dice_result(value: int) -> void:
	result_label.text = "Última tirada  ·  %d" % value


func _on_card_drawn(_card: Card3D, deck: Deck3D) -> void:
	result_label.text = "Cartas en el mazo  ·  %d" % deck.cards_remaining


func _on_snap_status_changed(enabled: bool) -> void:
	result_label.text = "Imán de cuadrícula: " + ("activado" if enabled else "desactivado")


func _on_placement_message(message: String) -> void:
	result_label.text = message


func _on_reset_pressed() -> void:
	get_tree().reload_current_scene()


func _on_deck_shuffled(deck: Deck3D) -> void:
	result_label.text = "Mazo mezclado · %d cartas" % deck.cards_remaining


func _on_chess_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Chess.tscn")


func _on_checkers_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Checkers.tscn")


func _on_physical_checkers_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/PhysicalCheckers.tscn")


func _on_guided_checkers_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/GuidedPhysicalCheckers.tscn")


func _on_physical_domino_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/PhysicalDomino.tscn")


func _can_store() -> bool:
	if is_instance_valid(grabber.held) or grabber._pending_press:
		result_label.text = "Suelta la pieza antes de guardar o cargar."
		return false
	for object in $Objects.get_children():
		if (
			object is InteractiveTableObject
			and (object.is_grabbed or (object.freeze and not object.is_table_locked))
		):
			result_label.text = "Espera a que termine el volteo de la carta."
			return false
	return true


func _on_save_pressed() -> void:
	if not _can_store():
		return
	var record: Dictionary = SandboxPersistence.snapshot($Objects, $SnapGrid3D.enabled)
	var brush := get_node_or_null("TableBrush") as TableBrush
	if not record.is_empty() and brush != null and not brush.stroke_data.is_empty():
		record["drawings"] = brush.export_strokes()
	if record.is_empty() or not SandboxPersistence.save(sandbox_save_path, record):
		result_label.text = "No se pudo guardar la mesa."
	else:
		result_label.text = "Mesa guardada en este dispositivo."


func _on_load_pressed() -> void:
	if not _can_store():
		return
	var loaded := SandboxPersistence.read_with_source(sandbox_save_path)
	if loaded.is_empty():
		result_label.text = "No se pudo cargar: archivo ausente o inválido."
		return
	var record: Dictionary = loaded["value"]
	if not apply_record(record):
		result_label.text = "No se pudieron crear las piezas guardadas."
		return
	# Los dibujos van con la mesa guardada (si los hay y son válidos).
	var brush := get_node_or_null("TableBrush") as TableBrush
	if brush != null:
		var drawings: Variant = record.get("drawings", [])
		brush.import_strokes(drawings if TableBrush.valid_strokes(drawings) else [])
	result_label.text = (
		"Archivo principal inválido o ausente: cargada la copia anterior."
		if loaded["backup"]
		else "Mesa cargada; la simulación física continúa."
	)


## Sustituye la mesa por una instantánea ya validada (cargar partida y rebobinar).
## Devuelve false sin tocar la mesa si las piezas no se pueden crear.
func apply_record(record: Dictionary) -> bool:
	var pieces: Array[InteractiveTableObject] = SandboxPersistence.instantiate_pieces(record)
	if pieces.size() != record["objects"].size():
		for piece in pieces:
			piece.free()
		return false
	# No tocar la mesa hasta que archivo e instancias hayan pasado la validación.
	if is_instance_valid(grabber.hovered):
		grabber.hovered.set_hovered(false)
	grabber.hovered = null
	grabber.clear_movement_undo()
	grabber.last_selected = null
	grabber._pending_recovery = null
	grabber._pending_release = false
	grabber._release_reason = "released"
	$SnapGrid3D.show_candidate({})
	for old in $Objects.get_children():
		$Objects.remove_child(old)
		old.queue_free()
	for i in range(pieces.size()):
		$Objects.add_child(pieces[i])
		SandboxPersistence.restore_piece(pieces[i], record["objects"][i])
	$SnapGrid3D.enabled = record["snap"]
	_connect_objects()
	selection_label.text = "NINGUNA PIEZA SELECCIONADA"
	return true
