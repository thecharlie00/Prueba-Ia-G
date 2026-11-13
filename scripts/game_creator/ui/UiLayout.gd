class_name UiLayout
extends RefCounted
## Interfaz que un creador diseña para su juego: una lista de elementos (textos, botones,
## paneles, imágenes y contadores) colocados sobre una pantalla de referencia de 1280 × 720.
##
## Cada elemento es un diccionario con: id, type, name, pos (esquina superior izquierda, en
## píxeles de referencia), size, anchor (a qué borde o esquina se sujeta cuando cambia el
## tamaño de la ventana), text, font_size, color, bg, image, value (contadores) y, en los
## botones, action + target (qué hace al pulsarse).
##
## Se guarda como JSON. Al cargar se valida todo: tipos conocidos, textos acotados, números
## en rango e imágenes solo de la carpeta de imágenes del creador.

const REFERENCE := Vector2(1280, 720)
const TYPES := ["text", "button", "panel", "image", "counter"]
const TYPE_NAMES := {
	"text": "Texto", "button": "Botón", "panel": "Panel", "image": "Imagen", "counter": "Contador",
}
## Qué puede hacer un botón.
const ACTIONS := ["none", "add", "sub", "roll", "toggle"]
const ACTION_NAMES := {
	"none": "Nada",
	"add": "Sumar 1 a un contador",
	"sub": "Restar 1 a un contador",
	"roll": "Tirar un dado (1–6) en un contador",
	"toggle": "Mostrar u ocultar un elemento",
}
## Sujeción: columna (0 izquierda, 1 centro, 2 derecha) + 3 × fila (0 arriba, 1 centro, 2 abajo).
const ANCHOR_NAMES := [
	"arriba a la izquierda", "arriba en el centro", "arriba a la derecha",
	"centro a la izquierda", "centro", "centro a la derecha",
	"abajo a la izquierda", "abajo en el centro", "abajo a la derecha",
]
## Colores que ofrece el inspector (los de la paleta del juego).
const SWATCHES := [
	"fff8ec", "1d1a3a", "2a2552", "ffc83d", "ee6f60", "5a8ae8", "58c08f", "f09a50", "b48cf2",
]
const MAX_ELEMENTS := 60
const MAX_TEXT := 200
const MIN_SIZE := Vector2(24, 24)
const IMAGE_ROOT := "user://creador/imagenes/"
const DEFAULTS := {
	"text": {"size": Vector2(260, 48), "text": "Texto", "font_size": 26, "color": "fff8ec", "bg": ""},
	"button": {"size": Vector2(200, 56), "text": "Botón", "font_size": 20, "color": "1d1a3a", "bg": "ffc83d"},
	"panel": {"size": Vector2(320, 200), "text": "", "font_size": 18, "color": "fff8ec", "bg": "2a2552"},
	"image": {"size": Vector2(180, 180), "text": "", "font_size": 18, "color": "fff8ec", "bg": ""},
	"counter": {"size": Vector2(220, 64), "text": "Puntos", "font_size": 20, "color": "fff8ec", "bg": "2a2552"},
}

var elements: Array[Dictionary] = []
var _next_id := 1


## Añade un elemento del tipo dado, en el centro (cada nuevo algo desplazado). Devuelve su
## diccionario, o {} si el tipo no existe o ya hay demasiados.
func add(type: String) -> Dictionary:
	if type not in TYPES or elements.size() >= MAX_ELEMENTS:
		return {}
	var base: Dictionary = DEFAULTS[type]
	var size: Vector2 = base["size"]
	var step := float(elements.size() % 6) * 26.0
	var element := {
		"id": _next_id,
		"type": type,
		"name": "%s %d" % [TYPE_NAMES[type], _next_id],
		"pos": (REFERENCE - size) * 0.5 + Vector2(step, step),
		"size": size,
		"anchor": 4,
		"text": base["text"],
		"font_size": base["font_size"],
		"color": base["color"],
		"bg": base["bg"],
		"image": "",
		"value": 0,
		"action": "none",
		"target": 0,
	}
	_next_id += 1
	elements.append(element)
	reanchor(element)
	return element


func find(id: int) -> Dictionary:
	for element in elements:
		if int(element["id"]) == id:
			return element
	return {}


func remove(id: int) -> bool:
	for i in elements.size():
		if int(elements[i]["id"]) == id:
			elements.remove_at(i)
			# Los botones que apuntaban a él se quedan sin destino.
			for element in elements:
				if int(element["target"]) == id:
					element["target"] = 0
			return true
	return false


## Lleva un elemento al frente (se dibuja el último).
func bring_to_front(id: int) -> void:
	var element := find(id)
	if not element.is_empty():
		elements.erase(element)
		elements.append(element)


## Elementos a los que puede apuntar una acción: contadores, o cualquiera para «mostrar».
func targets_for(action: String, own_id: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for element in elements:
		if int(element["id"]) == own_id:
			continue
		if action == "toggle" or (action in ["add", "sub", "roll"] and element["type"] == "counter"):
			found.append(element)
	return found


## Mantiene el elemento dentro de la pantalla y lo sujeta al borde o esquina más cercano.
func reanchor(element: Dictionary) -> void:
	var size: Vector2 = element["size"]
	size = size.clamp(MIN_SIZE, REFERENCE)
	element["size"] = size
	var pos: Vector2 = element["pos"]
	pos = pos.clamp(Vector2.ZERO, REFERENCE - size)
	element["pos"] = pos
	var center := pos + size * 0.5
	var column := clampi(int(center.x / (REFERENCE.x / 3.0)), 0, 2)
	var row := clampi(int(center.y / (REFERENCE.y / 3.0)), 0, 2)
	element["anchor"] = column + row * 3


## Punto de la pantalla (de tamaño `screen`) al que se sujeta una sujeción.
static func anchor_point(anchor: int, screen: Vector2) -> Vector2:
	return Vector2(screen.x * 0.5 * (anchor % 3), screen.y * 0.5 * (anchor / 3))


## Rectángulo del elemento en una pantalla real: conserva la distancia a su sujeción y escala
## con la ventana (lo que mide la ventana respecto a la referencia, por el lado menor).
static func rect_on(element: Dictionary, screen: Vector2) -> Rect2:
	var scale := minf(screen.x / REFERENCE.x, screen.y / REFERENCE.y)
	var anchor := int(element["anchor"])
	var offset: Vector2 = (element["pos"] as Vector2) - anchor_point(anchor, REFERENCE)
	return Rect2(anchor_point(anchor, screen) + offset * scale, (element["size"] as Vector2) * scale)


# --- Guardar y cargar ---------------------------------------------------------

func to_record() -> Dictionary:
	var list := []
	for element in elements:
		var copy := element.duplicate()
		copy["pos"] = [element["pos"].x, element["pos"].y]
		copy["size"] = [element["size"].x, element["size"].y]
		list.append(copy)
	return {"kind": "tablerama_ui", "version": 1, "elements": list}


## Reconstruye un diseño desde datos guardados, o null si algo no es válido.
static func from_record(data: Variant) -> UiLayout:
	if not data is Dictionary or data.get("kind") != "tablerama_ui":
		return null
	if not _is_int(data.get("version")) or int(data["version"]) != 1:
		return null
	var list: Variant = data.get("elements")
	if not list is Array or list.size() > MAX_ELEMENTS:
		return null
	var layout := UiLayout.new()
	var seen := {}
	for item in list:
		var element := _valid_element(item)
		if element.is_empty() or seen.has(element["id"]):
			return null
		seen[element["id"]] = true
		layout.elements.append(element)
		layout._next_id = maxi(layout._next_id, int(element["id"]) + 1)
	for element in layout.elements:
		if int(element["target"]) != 0 and not seen.has(int(element["target"])):
			return null
	return layout


static func _is_int(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and float(value) == floorf(float(value))


static func _pair(value: Variant) -> Variant:
	if not value is Array or value.size() != 2:
		return null
	for part in value:
		if typeof(part) not in [TYPE_INT, TYPE_FLOAT] or is_nan(float(part)) or is_inf(float(part)):
			return null
	return Vector2(float(value[0]), float(value[1]))


static func _color(value: Variant, allow_empty: bool) -> bool:
	if not value is String:
		return false
	if value == "":
		return allow_empty
	return value.length() == 6 and value.is_valid_hex_number()


static func _valid_element(item: Variant) -> Dictionary:
	if not item is Dictionary:
		return {}
	var type: Variant = item.get("type")
	if not type is String or type not in TYPES:
		return {}
	for key in ["id", "anchor", "font_size", "value", "target"]:
		if not _is_int(item.get(key)):
			return {}
	var pos: Variant = _pair(item.get("pos"))
	var size: Variant = _pair(item.get("size"))
	if pos == null or size == null:
		return {}
	for key in ["name", "text", "image", "action"]:
		if not item.get(key) is String or (item[key] as String).length() > MAX_TEXT:
			return {}
	if not _color(item.get("color"), false) or not _color(item.get("bg"), true):
		return {}
	var id := int(item["id"])
	var anchor := int(item["anchor"])
	var font_size := int(item["font_size"])
	if id < 1 or id > 100000 or anchor < 0 or anchor > 8 or font_size < 8 or font_size > 96:
		return {}
	if absi(int(item["value"])) > 999999 or int(item["target"]) < 0 or item["action"] not in ACTIONS:
		return {}
	var image: String = item["image"]
	if image != "" and (not image.begins_with(IMAGE_ROOT) or ".." in image):
		return {}
	var size_v: Vector2 = size
	var pos_v: Vector2 = pos
	if size_v.x < MIN_SIZE.x or size_v.y < MIN_SIZE.y or size_v.x > REFERENCE.x or size_v.y > REFERENCE.y:
		return {}
	if pos_v.x < 0 or pos_v.y < 0 or pos_v.x + size_v.x > REFERENCE.x + 0.5 or pos_v.y + size_v.y > REFERENCE.y + 0.5:
		return {}
	return {
		"id": id, "type": type, "name": item["name"], "pos": pos_v, "size": size_v,
		"anchor": anchor, "text": item["text"], "font_size": font_size, "color": item["color"],
		"bg": item["bg"], "image": image, "value": int(item["value"]),
		"action": item["action"], "target": int(item["target"]),
	}
