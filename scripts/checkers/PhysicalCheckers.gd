class_name PhysicalCheckers
extends Node3D

const BoardGeometry = preload("res://scripts/BoardGeometry3D.gd")
const TOKEN_SCENE = preload("res://scenes/Token3D.tscn")
const CELL := 0.46
const BOARD_HEIGHT := 0.83

@onready var tiles_root: Node3D = $Board/Tiles
@onready var objects: Node3D = $Objects
@onready var grabber: PhysicsGrabber3D = $PhysicsGrabber3D
@onready var status_label: Label = $UI/Panel/Margin/Content/Status


func _ready() -> void:
	_make_board()
	_spawn_tokens()
	grabber.selection_changed.connect(_on_selection_changed)
	grabber.placement_message.connect(_on_placement_message)
	$UI/Panel/Margin/Content/Reset.pressed.connect(_reset)
	$UI/Panel/Margin/Content/Rules.pressed.connect(_open_rules)
	$UI/Panel/Margin/Content/Guided.pressed.connect(_open_guided)
	$UI/Panel/Margin/Content/Sandbox.pressed.connect(_open_sandbox)


func _make_board() -> void:
	var squares: Array[MeshInstance3D] = BoardGeometry.make_tiles(tiles_root, CELL, BOARD_HEIGHT)
	var light: Material = BoardGeometry.make_material(Color("dfd1ad"))
	var dark: Material = BoardGeometry.make_material(Color("405f50"))
	var highlight: Material = BoardGeometry.make_material(Color("d8af5d"))
	var destinations: Array[int] = []
	BoardGeometry.update_tiles(squares, -1, destinations, light, dark, highlight, highlight)


func _spawn_tokens() -> void:
	for row in range(8):
		if row >= 3 and row <= 4:
			continue
		for column in range(8):
			if (row + column) % 2 == 0:
				continue
			var token := TOKEN_SCENE.instantiate() as Token3D
			var white: bool = row >= 5
			token.piece_color = Color("f5ead5") if white else Color("273833")
			token.display_name = "Ficha blanca" if white else "Ficha oscura"
			token.position = BoardGeometry.square_position(
				row * 8 + column, CELL, BOARD_HEIGHT + 0.08
			)
			objects.add_child(token)


func _on_selection_changed(object: InteractiveTableObject) -> void:
	status_label.text = object.display_name if is_instance_valid(object) else "Mesa física libre"


func _on_placement_message(message: String) -> void:
	status_label.text = message


func _reset() -> void:
	get_tree().reload_current_scene()


func _open_rules() -> void:
	get_tree().change_scene_to_file("res://scenes/Checkers.tscn")


func _open_sandbox() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _open_guided() -> void:
	get_tree().change_scene_to_file("res://scenes/GuidedPhysicalCheckers.tscn")
