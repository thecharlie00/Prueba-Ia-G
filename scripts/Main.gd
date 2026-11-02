extends Node3D

@onready var selection_label: Label = $UI/Margin/Panel/Content/Selection
@onready var result_label: Label = $UI/Margin/Panel/Content/Result
@onready var grabber: PhysicsGrabber3D = $PhysicsGrabber3D


func _ready() -> void:
	grabber.selection_changed.connect(_on_selection_changed)
	grabber.snap_status_changed.connect(_on_snap_status_changed)
	grabber.placement_message.connect(_on_placement_message)
	$UI/Margin/Panel/Content/Reset.pressed.connect(_on_reset_pressed)
	$UI/Margin/Panel/Content/Chess.pressed.connect(_on_chess_pressed)
	$Objects/Dice.result_ready.connect(_on_dice_result)
	$Objects/Deck.card_drawn.connect(_on_card_drawn)
	$Objects/Deck.deck_shuffled.connect(_on_deck_shuffled)


func _on_selection_changed(object: InteractiveTableObject) -> void:
	selection_label.text = (
		object.display_name.to_upper()
		if is_instance_valid(object)
		else "NINGUNA PIEZA SELECCIONADA"
	)


func _on_dice_result(value: int) -> void:
	result_label.text = "Última tirada  ·  %d" % value


func _on_card_drawn(_card: Card3D) -> void:
	result_label.text = "Cartas en el mazo  ·  %d" % $Objects/Deck.cards_remaining


func _on_snap_status_changed(enabled: bool) -> void:
	result_label.text = "Imán de cuadrícula: " + ("activado" if enabled else "desactivado")


func _on_placement_message(message: String) -> void:
	result_label.text = message


func _on_reset_pressed() -> void:
	get_tree().reload_current_scene()


func _on_deck_shuffled() -> void:
	result_label.text = "Mazo mezclado · %d cartas" % $Objects/Deck.cards_remaining


func _on_chess_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Chess.tscn")
