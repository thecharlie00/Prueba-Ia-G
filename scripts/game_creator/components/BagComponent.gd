# BagComponent.gd
# Bolsa que guarda piezas (por su entity_id) y permite sacar una al azar.
# Las piezas dentro de la bolsa están ocultas: solo se sabe cuántas hay.
class_name BagComponent
extends BehaviorComponent

@export var label: String = "Bolsa"
@export var hidden: bool = true  # si es true, no se ve qué hay dentro

# IDs de las piezas dentro de la bolsa.
@export var contained_ids: Array[String] = []

func _serialize_extra(data: Dictionary) -> void:
	data["label"] = label
	data["hidden"] = hidden
	data["contained_ids"] = contained_ids

func _deserialize_extra(data: Dictionary) -> void:
	label = str(data.get("label", label))
	hidden = data.get("hidden", hidden) == true
	contained_ids = data.get("contained_ids", []) if data.get("contained_ids") is Array else []

## Devuelve cuántas piezas hay en la bolsa.
func count() -> int:
	return contained_ids.size()

## Devuelve true si la bolsa está vacía.
func is_empty() -> bool:
	return contained_ids.is_empty()

## Añade una pieza (por su entity_id) a la bolsa. Devuelve true si se pudo.
func add(entity_id: String) -> bool:
	if entity_id in contained_ids:
		return false
	contained_ids.append(entity_id)
	return true

## Saca y devuelve una pieza al azar de la bolsa, o "" si está vacía.
func draw_random() -> String:
	if contained_ids.is_empty():
		return ""
	var idx := randi_range(0, contained_ids.size() - 1)
	return contained_ids.remove_at(idx)

## Saca y devuelve la primera pieza de la bolsa, o "" si está vacía.
func draw_first() -> String:
	if contained_ids.is_empty():
		return ""
	return contained_ids.remove_at(0)

## Devuelve una copia de los IDs de las piezas dentro.
func all_ids() -> Array:
	return contained_ids.duplicate()
