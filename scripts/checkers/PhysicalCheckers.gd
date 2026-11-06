class_name PhysicalCheckers
extends Node3D

const CONFIRM_ACTION := preload("res://scripts/ui/ConfirmAction.gd")

const BoardGeometry = preload("res://scripts/BoardGeometry3D.gd")
const TOKEN_SCENE = preload("res://scenes/Token3D.tscn")
const CELL := 0.46
const BOARD_HEIGHT := 0.83

var confirm_action: ConfirmAction
@onready var tiles_root: Node3D = $Board/Tiles
@onready var objects: Node3D = $Objects
@onready var grabber: PhysicsGrabber3D = $PhysicsGrabber3D
@onready var status_label: Label = $UI/Panel/Margin/Content/Status


func _ready() -> void:
	TableHud.attach.call_deferred(self)
	confirm_action = CONFIRM_ACTION.new()
	add_child(confirm_action)
	_make_board()
	_spawn_tokens()
	grabber.selection_changed.connect(_on_selection_changed)
	grabber.placement_message.connect(_on_placement_message)
	confirm_action.bind_button(
		$UI/Panel/Margin/Content/Reset as Button,
		"Reiniciar mesa",
		"Se descartarán los cambios actuales. ¿Continuar?",
		_reset,
		_can_leave_table
	)
	confirm_action.bind_button(
		$UI/Panel/Margin/Content/Rules as Button,
		"Cambiar de mesa",
		"Se descartarán los cambios actuales. ¿Continuar?",
		_open_rules,
		_can_leave_table
	)
	confirm_action.bind_button(
		$UI/Panel/Margin/Content/Guided as Button,
		"Cambiar de mesa",
		"Se descartarán los cambios actuales. ¿Continuar?",
		_open_guided,
		_can_leave_table
	)
	confirm_action.bind_button(
		$UI/Panel/Margin/Content/Sandbox as Button,
		"Cambiar de mesa",
		"Se descartarán los cambios actuales. ¿Continuar?",
		_open_sandbox,
		_can_leave_table
	)


func _make_board() -> void:
	var squares: Array[MeshInstance3D] = BoardGeometry.make_tiles(tiles_root, CELL, BOARD_HEIGHT)
	var light: Material = BoardGeometry.make_material(Palette.BOARD_LIGHT)
	var dark: Material = BoardGeometry.make_material(Palette.BOARD_DARK)
	var highlight: Material = BoardGeometry.make_material(Palette.SELECTED)
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
			token.piece_color = Palette.PIECE_LIGHT if white else Palette.PIECE_DARK
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


func _can_leave_table() -> bool:
	if is_instance_valid(grabber.held) or grabber._pending_press:
		status_label.text = "Suelta la pieza antes de cambiar o reiniciar la mesa."
		return false
	return true
