class_name PhysicalChess
extends Node3D

const CONFIRM_ACTION := preload("res://scripts/ui/ConfirmAction.gd")

const PIECE_SCENE := preload("res://scenes/PhysicalChessPiece.tscn")
const CELL := 0.46
const BOARD_HEIGHT := 0.83

var confirm_action: ConfirmAction
@onready var objects: Node3D = $Objects
@onready var grabber: PhysicsGrabber3D = $PhysicsGrabber3D
@onready var status_label: Label = $UI/Panel/Margin/Content/Status


func _ready() -> void:
	TableHud.attach.call_deferred(self)
	confirm_action = CONFIRM_ACTION.new()
	add_child(confirm_action)
	_make_board()
	_spawn_pieces()
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
	var squares: Array[MeshInstance3D] = BoardGeometry3D.make_tiles(
		$Board/Tiles, CELL, BOARD_HEIGHT
	)
	var light := BoardGeometry3D.make_material(Palette.BOARD_LIGHT)
	var dark := BoardGeometry3D.make_material(Palette.BOARD_DARK)
	var destinations: Array[int] = []
	BoardGeometry3D.update_tiles(squares, -1, destinations, light, dark, light, dark)


func _spawn_pieces() -> void:
	var initial := ChessRules.new()
	for square in range(64):
		var value := initial.piece_at(square)
		if value == 0:
			continue
		var piece := PIECE_SCENE.instantiate() as PhysicalChessPiece
		piece.piece_type = absi(value)
		piece.white = value > 0
		var h := ChessPieceModel.height(piece.piece_type) + 0.01
		piece.position = BoardGeometry3D.square_position(
			square, CELL, BOARD_HEIGHT + h * 0.5 + 0.04
		)
		objects.add_child(piece)


func _on_selection_changed(object: InteractiveTableObject) -> void:
	status_label.text = (
		object.display_name if is_instance_valid(object) else "32 piezas · mesa libre"
	)


func _on_placement_message(message: String) -> void:
	status_label.text = message


func _reset() -> void:
	get_tree().reload_current_scene()


func _open_rules() -> void:
	get_tree().change_scene_to_file("res://scenes/Chess.tscn")


func _open_sandbox() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _open_guided() -> void:
	get_tree().change_scene_to_file("res://scenes/GuidedPhysicalChess.tscn")


func _can_leave_table() -> bool:
	if is_instance_valid(grabber.held) or grabber._pending_press:
		status_label.text = "Suelta la pieza antes de cambiar o reiniciar la mesa."
		return false
	return true
