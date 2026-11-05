class_name ConfirmAction
extends Node

# Una sola acción pendiente; al cancelar nunca queda un callback reutilizable.
var dialog: ConfirmationDialog
var _action: Callable
var _check: Callable


func _ready() -> void:
	dialog = ConfirmationDialog.new()
	dialog.name = "ConfirmDestructiveAction"
	dialog.ok_button_text = "Continuar"
	dialog.dialog_autowrap = true
	dialog.exclusive = true
	dialog.confirmed.connect(_confirm)
	dialog.canceled.connect(_cancel)
	add_child(dialog)
	dialog.get_cancel_button().text = "Cancelar"


func bind_button(
	button: Button, title: String, message: String, action: Callable, check: Callable = Callable()
) -> void:
	button.pressed.connect(request.bind(title, message, action, check))


func request(
	title: String, message: String, action: Callable, check: Callable = Callable()
) -> void:
	if dialog.visible or not action.is_valid():
		return
	if check.is_valid() and not bool(check.call()):
		return
	_action = action
	_check = check
	dialog.title = title
	dialog.dialog_text = message
	dialog.popup_centered(Vector2i(500, 180))


func _confirm() -> void:
	var action := _action
	var check := _check
	_cancel()
	dialog.hide()
	if action.is_valid() and (not check.is_valid() or bool(check.call())):
		action.call()


func _cancel() -> void:
	_action = Callable()
	_check = Callable()
