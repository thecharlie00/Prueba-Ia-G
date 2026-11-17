# NoteComponent.gd
# Nota de texto editable para los jugadores. Se ve al pasar el ratón por la pieza.
class_name NoteComponent
extends BehaviorComponent

const MAX_NOTES := 200

@export var text: String = ""
@export var show_on_hover: bool = true

func _serialize_extra(data: Dictionary) -> void:
	data["text"] = text
	data["show_on_hover"] = show_on_hover

func _deserialize_extra(data: Dictionary) -> void:
	text = str(data.get("text", text))
	show_on_hover = data.get("show_on_hover", show_on_hover) == true

## Pone el texto de la nota, recortado al máximo permitido.
func set_text(nuevo: String) -> void:
	text = str(nuevo).left(MAX_NOTES)

## Devuelve el texto de la nota.
func get_text() -> String:
	return text
