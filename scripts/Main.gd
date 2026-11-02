extends Node3D

@onready var selection_label: Label = $UI/Margin/Panel/Content/Selection
@onready var result_label: Label = $UI/Margin/Panel/Content/Result
@onready var grabber: PhysicsGrabber3D = $PhysicsGrabber3D


func _ready() -> void:
	grabber.selection_changed.connect(_on_selection_changed)
	$Objects/Dice.result_ready.connect(_on_dice_result)
	$Objects/Deck.card_drawn.connect(_on_card_drawn)


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
