class_name PhysicalDomino
extends Node3D

const DOMINO_SCENE := preload("res://scenes/Domino3D.tscn")
const BOARD_HEIGHT := 0.83

@onready var objects: Node3D = $Objects
@onready var grabber: PhysicsGrabber3D = $PhysicsGrabber3D
@onready var status_label: Label = $UI/Panel/Margin/Content/Status


func _ready() -> void:
	_spawn_dominoes()
	grabber.selection_changed.connect(_on_selection_changed)
	grabber.placement_message.connect(_on_placement_message)
	$UI/Panel/Margin/Content/Reset.pressed.connect(_reset)
	$UI/Panel/Margin/Content/Guided.pressed.connect(_open_guided)
	$UI/Panel/Margin/Content/Sandbox.pressed.connect(_open_sandbox)


func _spawn_dominoes() -> void:
	var index := 0
	for left in range(7):
		for right in range(left, 7):
			var tile := DOMINO_SCENE.instantiate() as Domino3D
			tile.left_value = left
			tile.right_value = right
			tile.position = Vector3(
				(index % 7 - 3) * 0.51, BOARD_HEIGHT + 0.12, (index / 7 - 1.5) * 0.53
			)
			objects.add_child(tile)
			index += 1


func _on_selection_changed(object: InteractiveTableObject) -> void:
	status_label.text = (
		object.display_name if is_instance_valid(object) else "28 fichas · doble seis"
	)


func _on_placement_message(message: String) -> void:
	status_label.text = message


func _reset() -> void:
	get_tree().reload_current_scene()


func _open_sandbox() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _open_guided() -> void:
	get_tree().change_scene_to_file("res://scenes/GuidedDomino.tscn")
