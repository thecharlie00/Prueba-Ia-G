# CounterComponent.gd
# Contador numérico con valor, mínimo y máximo. Se puede sumar, restar y poner a cero.
# Guardable y rebobinable con la mesa.
class_name CounterComponent
extends BehaviorComponent

@export var value: int = 0
@export var min_value: int = 0
@export var max_value: int = 999
@export var step: int = 1
@export var label: String = "Contador"

func _serialize_extra(data: Dictionary) -> void:
	data["value"] = value
	data["min_value"] = min_value
	data["max_value"] = max_value
	data["step"] = step
	data["label"] = label

func _deserialize_extra(data: Dictionary) -> void:
	value = clampi(int(data.get("value", value)), min_value, max_value)
	min_value = int(data.get("min_value", min_value))
	max_value = int(data.get("max_value", max_value))
	step = int(data.get("step", step))
	label = str(data.get("label", label))

## Suma `cantidad` al valor, respetando el máximo. Devuelve el valor resultante.
func add(amount: int = 1) -> int:
	value = clampi(value + int(amount), min_value, max_value)
	return value

## Resta `cantidad` al valor, respetando el mínimo. Devuelve el valor resultante.
func sub(amount: int = 1) -> int:
	value = clampi(value - int(amount), min_value, max_value)
	return value

## Pone el valor a `nuevo`, respetando mín/máx. Devuelve el valor resultante.
func set(nuevo: int) -> int:
	value = clampi(int(nuevo), min_value, max_value)
	return value

## Pone el valor al mínimo. Devuelve el valor resultante.
func reset() -> int:
	value = min_value
	return value

## Devuelve true si el valor está en el límite superior.
func at_max() -> bool:
	return value >= max_value

## Devuelve true si el valor está en el límite inferior.
func at_min() -> bool:
	return value <= min_value
