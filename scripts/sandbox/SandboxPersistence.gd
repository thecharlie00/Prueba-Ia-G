class_name SandboxPersistence
extends RefCounted

const SAVE_STORE := preload("res://scripts/persistence/SaveStore.gd")

# Formato cerrado: nunca se cargan rutas de recursos procedentes de un archivo.
const SCENES := {
	"dice": preload("res://scenes/Dice3D.tscn"),
	"token": preload("res://scenes/Token3D.tscn"),
	"card": preload("res://scenes/Card3D.tscn"),
	"deck": preload("res://scenes/Deck3D.tscn"),
	"counter": "res://scenes/Counter3D.tscn",
	"bag": "res://scenes/Bag3D.tscn",
	"note": "res://scenes/Note3D.tscn",
	"timer": "res://scenes/Timer3D.tscn",
}
const MAX_BYTES := 262144
const MAX_OBJECTS := 100
const MAX_CARDS := 100


static func snapshot(objects: Node, snap_enabled: bool) -> Dictionary:
	var pieces: Array[Dictionary] = []
	var used_names := {}
	for child in objects.get_children():
		var object := child as InteractiveTableObject
		if object == null or object.is_grabbed or (object.freeze and not object.is_table_locked):
			return {}
		var data := piece_data(object)
		if data.is_empty():
			return {}
		var base_name: String = data["name"]
		var saved_name := base_name
		var suffix := 1
		while used_names.has(saved_name):
			saved_name = base_name + "_" + str(suffix)
			suffix += 1
		used_names[saved_name] = true
		data["name"] = saved_name
		pieces.append(data)
	var record := {
		"format": "diceon_sandbox", "version": 1, "snap": snap_enabled, "objects": pieces
	}
	return record if validate(record) else {}


static func kind_of(object: InteractiveTableObject) -> String:
	if object is Dice3D:
		return "dice"
	if object is Token3D:
		return "token"
	if object is Card3D:
		return "card"
	if object is Deck3D:
		return "deck"
	if object is Counter3D:
		return "counter"
	if object is Bag3D:
		return "bag"
	if object is Note3D:
		return "note"
	if object is Timer3D:
		return "timer"
	return ""


## Datos de una pieza (también los usa la bolsa para guardar lo que lleva dentro).
static func piece_data(object: InteractiveTableObject) -> Dictionary:
	var kind := kind_of(object)
	if kind.is_empty():
		return {}
	var q := object.global_basis.get_rotation_quaternion().normalized()
	# Los nombres internos automáticos con @ no pueden asignarse al cargar.
	var base_name := str(object.name).substr(0, 90)
	for invalid in ["/", ":", ".", '"', "%", "@"]:
		base_name = base_name.replace(invalid, "_")
	if base_name.is_empty():
		base_name = "Pieza"
	var data := {
		"type": kind,
		"name": base_name,
		"display_name": object.display_name,
		"position": _vector_data(object.global_position),
		"rotation": [q.x, q.y, q.z, q.w],
		"velocity": _vector_data(object.linear_velocity),
		"angular_velocity": _vector_data(object.angular_velocity),
		"locked": object.is_table_locked
	}
	if object is Token3D:
		var color: Color = object.piece_color
		data["color"] = [color.r, color.g, color.b, color.a]
		data["king"] = object.is_king
	elif object is Card3D:
		data["label"] = object.card_label
	elif object is Deck3D:
		data["cards"] = object._cards.duplicate()
	elif object is Dice3D:
		data["awaiting_result"] = object._awaiting_result
	elif object is TableUtility:
		data.merge((object as TableUtility).extra_data())
	return data


static func save(path: String, record: Dictionary) -> bool:
	if not validate(record):
		return false
	return SAVE_STORE.write(path, JSON.stringify(record), MAX_BYTES, _decode_record)


static func read(path: String) -> Dictionary:
	var result := read_with_source(path)
	return result.get("value", {})


static func read_with_source(path: String) -> Dictionary:
	return SAVE_STORE.read_validated(path, MAX_BYTES, _decode_record)


static func _decode_record(record: Variant) -> Variant:
	return record if validate(record) else null


static func validate(record: Variant) -> bool:
	if not record is Dictionary:
		return false
	if record.get("format") != "diceon_sandbox" or not _number(record.get("version"), 1, 1):
		return false
	if not record.get("snap") is bool or not record.get("objects") is Array:
		return false
	var pieces: Array = record["objects"]
	if pieces.is_empty() or pieces.size() > MAX_OBJECTS:
		return false
	var names := {}
	for piece in pieces:
		if not _validate_piece(piece):
			return false
		if names.has(piece["name"]):
			return false
		names[piece["name"]] = true
	return true


static func _validate_piece(piece: Variant, nested := false) -> bool:
	if not piece is Dictionary or not piece.get("type") is String or not SCENES.has(piece["type"]):
		return false
	if typeof(piece.get("locked", false)) != TYPE_BOOL:
		return false
	if not _valid_name(piece.get("name")) or not _text(piece.get("display_name"), 120):
		return false
	if not _array_numbers(piece.get("position"), 3, -100.0, 100.0):
		return false
	if not _array_numbers(piece.get("rotation"), 4, -1.001, 1.001):
		return false
	var r: Array = piece["rotation"]
	var length_squared: float = 0.0
	for value in r:
		length_squared += float(value) * float(value)
	if absf(length_squared - 1.0) > 0.01:
		return false
	if not _array_numbers(piece.get("velocity"), 3, -200.0, 200.0):
		return false
	if not _array_numbers(piece.get("angular_velocity"), 3, -200.0, 200.0):
		return false
	match piece["type"]:
		"dice":
			return piece.get("awaiting_result") is bool
		"token":
			return _array_numbers(piece.get("color"), 4, 0.0, 1.0) and piece.get("king") is bool
		"card":
			return _text(piece.get("label"), 80)
		"deck":
			var cards: Variant = piece.get("cards")
			if not cards is Array or cards.size() > MAX_CARDS:
				return false
			for card in cards:
				if not _text(card, 80):
					return false
			return true
		"counter":
			return (
				_utility_color(piece)
				and typeof(piece.get("value")) in [TYPE_INT, TYPE_FLOAT]
				and _number(piece["value"], Counter3D.MIN_VALUE, Counter3D.MAX_VALUE)
			)
		"note":
			return _utility_color(piece) and _text(piece.get("text"), Note3D.MAX_LENGTH)
		"timer":
			return (
				_utility_color(piece)
				and _number(piece.get("seconds"), 0.0, Timer3D.MAX_SECONDS)
				and _number(piece.get("countdown"), 0.0, Timer3D.MAX_SECONDS)
			)
		"bag":
			# Una bolsa no puede contener otra bolsa.
			var contents: Variant = piece.get("contents")
			if nested or not _utility_color(piece) or not contents is Array:
				return false
			if contents.size() > Bag3D.MAX_CONTENTS:
				return false
			for entry in contents:
				if not _validate_piece(entry, true):
					return false
			return true
	return false


static func _utility_color(piece: Dictionary) -> bool:
	return _array_numbers(piece.get("color"), 4, 0.0, 1.0)


static func _valid_name(value: Variant) -> bool:
	if not _text(value, 100) or value.is_empty():
		return false
	# Estos caracteres son inválidos para nombres de nodo y podrían cambiar al restaurar.
	for invalid in ["/", ":", ".", '"', "%", "@"]:
		if invalid in value:
			return false
	return true


static func _text(value: Variant, max_length: int) -> bool:
	return value is String and value.length() <= max_length


static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return is_finite(number) and number >= minimum and number <= maximum


static func _array_numbers(value: Variant, count: int, minimum: float, maximum: float) -> bool:
	if not value is Array or value.size() != count:
		return false
	for entry in value:
		if not _number(entry, minimum, maximum):
			return false
	return true


static func _vector_data(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


# Se crean todas las instancias antes de reemplazar nada. El llamante valida antes.
static func instantiate_pieces(record: Dictionary) -> Array[InteractiveTableObject]:
	var result: Array[InteractiveTableObject] = []
	if not validate(record):
		return result
	for data in record["objects"]:
		var object := instantiate_piece(data)
		if object == null:
			for created in result:
				created.free()
			return []
		result.append(object)
	return result


## Crea una pieza (sin añadirla al árbol) a partir de datos ya validados.
static func instantiate_piece(data: Dictionary) -> InteractiveTableObject:
	if not SCENES.has(data.get("type")):
		return null
	var scene: Variant = SCENES[data["type"]]
	# Las escenas de los utilitarios se cargan al usarlas: precargarlas aquí crea un ciclo con
	# sus scripts (que consultan este archivo) y el motor no los libera al salir.
	if scene is String:
		scene = load(scene)
	var object := (scene as PackedScene).instantiate() as InteractiveTableObject
	if object == null:
		return null
	object.name = data["name"]
	object.display_name = data["display_name"]
	if object is Token3D:
		var c: Array = data["color"]
		object.piece_color = Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]))
		object.is_king = data["king"]
	elif object is Card3D:
		object.card_label = data["label"]
	elif object is TableUtility:
		var u: Array = data["color"]
		var utility := object as TableUtility
		utility.piece_color = Color(float(u[0]), float(u[1]), float(u[2]), float(u[3]))
		utility.ready.connect(func() -> void: utility.apply_extra(data), CONNECT_ONE_SHOT)
	return object


# Solo se llama después de añadir la instancia al árbol y ejecutar su _ready().
static func restore_piece(object: InteractiveTableObject, data: Dictionary) -> void:
	var q: Array = data["rotation"]
	object.global_transform = Transform3D(
		Basis(Quaternion(float(q[0]), float(q[1]), float(q[2]), float(q[3])).normalized()),
		_vector(data["position"])
	)
	object.linear_velocity = _vector(data["velocity"])
	object.angular_velocity = _vector(data["angular_velocity"])
	object.sleeping = false
	object.set_table_locked(bool(data.get("locked", false)))
	if object is Deck3D:
		object._cards.clear()
		for card in data["cards"]:
			object._cards.append(card)
		object.cards_remaining = object._cards.size()
	elif object is Dice3D:
		object._awaiting_result = data["awaiting_result"]
