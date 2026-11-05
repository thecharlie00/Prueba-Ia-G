extends Node3D

const CONFIRM_ACTION := preload("res://scripts/ui/ConfirmAction.gd")

@export var sandbox_save_path := "user://diceon_sandbox.json"

var confirm_action: ConfirmAction
@onready var selection_label: Label = $UI/Margin/Panel/Content/Selection
@onready var result_label: Label = $UI/Margin/Panel/Content/Result
@onready var grabber: PhysicsGrabber3D = $PhysicsGrabber3D


func _ready() -> void:
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
	_connect_objects()


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
	var pieces: Array[InteractiveTableObject] = SandboxPersistence.instantiate_pieces(record)
	if pieces.size() != record["objects"].size():
		result_label.text = "No se pudieron crear las piezas guardadas."
		return
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
	result_label.text = (
		"Archivo principal inválido o ausente: cargada la copia anterior."
		if loaded["backup"]
		else "Mesa cargada; la simulación física continúa."
	)
