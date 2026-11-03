class_name SandboxPersistence
extends RefCounted

const AtomicSave = preload("res://scripts/AtomicSaveFile.gd")

# Formato cerrado: nunca se cargan rutas de recursos procedentes de un archivo.
const SCENES := {
	"dice": preload("res://scenes/Dice3D.tscn"),
	"token": preload("res://scenes/Token3D.tscn"),
	"card": preload("res://scenes/Card3D.tscn"),
	"deck": preload("res://scenes/Deck3D.tscn")
}
const MAX_BYTES := 262144
const MAX_OBJECTS := 100
const MAX_CARDS := 100


static func snapshot(objects: Node, snap_enabled: bool) -> Dictionary:
	var pieces: Array[Dictionary] = []
	var used_names := {}
	for child in objects.get_children():
		var object := child as InteractiveTableObject
		if object == null or object.is_grabbed or object.freeze:
			return {}
		var kind := ""
		if object is Dice3D:
			kind = "dice"
		elif object is Token3D:
			kind = "token"
		elif object is Card3D:
			kind = "card"
		elif object is Deck3D:
			kind = "deck"
		else:
			return {}
		var q := object.global_basis.get_rotation_quaternion().normalized()
		# Los nombres internos automáticos con @ no pueden asignarse al cargar.
		var base_name := str(object.name).substr(0, 90)
		for invalid in ["/", ":", ".", '"', "%", "@"]:
			base_name = base_name.replace(invalid, "_")
		if base_name.is_empty():
			base_name = "Pieza"
		var saved_name := base_name
		var suffix := 1
		while used_names.has(saved_name):
			saved_name = base_name + "_" + str(suffix)
			suffix += 1
		used_names[saved_name] = true
		var data := {
			"type": kind,
			"name": saved_name,
			"display_name": object.display_name,
			"position": _vector_data(object.global_position),
			"rotation": [q.x, q.y, q.z, q.w],
			"velocity": _vector_data(object.linear_velocity),
			"angular_velocity": _vector_data(object.angular_velocity)
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
		pieces.append(data)
	var record := {
		"format": "diceon_sandbox", "version": 1, "snap": snap_enabled, "objects": pieces
	}
	return record if validate(record) else {}


static func save(path: String, record: Dictionary) -> bool:
	if not validate(record):
		return false
	var json := JSON.stringify(record)
	if json.to_utf8_buffer().size() > MAX_BYTES:
		return false
	return AtomicSave.write_text(path, json)


static func read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not validate(parser.data):
		return {}
	return parser.data


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


static func _validate_piece(piece: Variant) -> bool:
	if not piece is Dictionary or not piece.get("type") is String or not SCENES.has(piece["type"]):
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
	return false


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
		var object := SCENES[data["type"]].instantiate() as InteractiveTableObject
		if object == null:
			for created in result:
				created.free()
			return []
		object.name = data["name"]
		object.display_name = data["display_name"]
		if object is Token3D:
			var c: Array = data["color"]
			object.piece_color = Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]))
			object.is_king = data["king"]
		elif object is Card3D:
			object.card_label = data["label"]
		result.append(object)
	return result


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
	if object is Deck3D:
		object._cards.clear()
		for card in data["cards"]:
			object._cards.append(card)
		object.cards_remaining = object._cards.size()
	elif object is Dice3D:
		object._awaiting_result = data["awaiting_result"]
