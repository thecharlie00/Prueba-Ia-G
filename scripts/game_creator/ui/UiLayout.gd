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
const GRID_STEP := 20.0  # Paso de la cuadrícula de diseño (píxeles de referencia).

## Alineaciones soportadas para seleccionados.
const ALIGN_LEFT := 0
const ALIGN_CENTER_X := 1
const ALIGN_RIGHT := 2
const ALIGN_TOP := 3
const ALIGN_CENTER_Y := 4
const ALIGN_BOTTOM := 5

## Direcciones de distribución.
const DISTRIBUTE_HORIZONTAL := 0
const DISTRIBUTE_VERTICAL := 1
const DEFAULTS := {
	"text": {"size": Vector2(260, 48), "text": "Texto", "font_size": 26, "color": "fff8ec", "bg": ""},
	"button": {"size": Vector2(200, 56), "text": "Botón", "font_size": 20, "color": "1d1a3a", "bg": "ffc83d"},
	"panel": {"size": Vector2(320, 200), "text": "", "font_size": 18, "color": "fff8ec", "bg": "2a2552"},
	"image": {"size": Vector2(180, 180), "text": "", "font_size": 18, "color": "fff8ec", "bg": ""},
	"counter": {"size": Vector2(220, 64), "text": "Puntos", "font_size": 20, "color": "fff8ec", "bg": "2a2552"},
}

var elements: Array[Dictionary] = []
var _next_id := 1
## IDs de los elementos seleccionados (selección múltiple en diseño).
var selected: Array[int] = []
## ID del grupo al que pertenece cada elemento (clave: element_id, valor: group_id).
var groups: Dictionary = {}
var _next_group_id := 1


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
	selected = [int(element["id"])]
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
			# Limpiar selección y grupo.
			selected.erase(id)
			groups.erase(id)
			return true
	return false


## Lleva un elemento al frente (se dibuja el último). Si hay selección múltiple, lleva todos los seleccionados al frente.
func bring_to_front(id: int) -> void:
	var ids := selected if selected.size() > 1 else [id]
	for target_id in ids:
		var element := find(target_id)
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


## Selecciona un elemento (o varios si `multi` y ya hay selección). Devuelve los IDs seleccionados.
func select(id: int, multi: bool = false) -> Array[int]:
	if multi:
		if id in selected:
			selected.erase(id)
		else:
			selected.append(id)
	else:
		selected.assign([id] if id != 0 else [])
	return selected.duplicate()


## Devuelve los IDs de los elementos seleccionados.
func get_selected() -> Array[int]:
	return selected.duplicate()


## Limpia la selección.
func clear_selection() -> void:
	selected = []


## Devuelve los diccionarios de los elementos seleccionados.
func selected_elements() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in selected:
		var element := find(id)
		if not element.is_empty():
			result.append(element)
	return result


## Alinea los elementos seleccionados al tipo dado (ALIGN_*). Usa el primer seleccionado como referencia
## para centro_x/centro_y, o el borde extremo para left/right/top/bottom.
func align_selected(alignment: int) -> int:
	var elems: Array[Dictionary] = selected_elements()
	if elems.size() < 2:
		return 0
	var moved := 0
	match alignment:
		ALIGN_LEFT:
			var min_x := 99999.0
			for e in elems:
				min_x = min(min_x, (e["pos"] as Vector2).x)
			for e in elems:
				var pos := e["pos"] as Vector2
				if pos.x != min_x:
					pos.x = min_x
					e["pos"] = pos
					moved += 1
		ALIGN_CENTER_X:
			var ref := elems[0]
			var cx := (ref["pos"] as Vector2).x + (ref["size"] as Vector2).x * 0.5
			for e in elems:
				var pos := e["pos"] as Vector2
				var size := e["size"] as Vector2
				var nx := cx - size.x * 0.5
				if pos.x != nx:
					pos.x = nx
					e["pos"] = pos
					moved += 1
		ALIGN_RIGHT:
			var max_x := -99999.0
			for e in elems:
				var pos := e["pos"] as Vector2
				var size := e["size"] as Vector2
				max_x = max(max_x, pos.x + size.x)
			for e in elems:
				var pos := e["pos"] as Vector2
				var size := e["size"] as Vector2
				var nx := max_x - size.x
				if pos.x != nx:
					pos.x = nx
					e["pos"] = pos
					moved += 1
		ALIGN_TOP:
			var min_y := 99999.0
			for e in elems:
				min_y = min(min_y, (e["pos"] as Vector2).y)
			for e in elems:
				var pos := e["pos"] as Vector2
				if pos.y != min_y:
					pos.y = min_y
					e["pos"] = pos
					moved += 1
		ALIGN_CENTER_Y:
			var ref := elems[0]
			var cy := (ref["pos"] as Vector2).y + (ref["size"] as Vector2).y * 0.5
			for e in elems:
				var pos := e["pos"] as Vector2
				var size := e["size"] as Vector2
				var ny := cy - size.y * 0.5
				if pos.y != ny:
					pos.y = ny
					e["pos"] = pos
					moved += 1
		ALIGN_BOTTOM:
			var max_y := -99999.0
			for e in elems:
				var pos := e["pos"] as Vector2
				var size := e["size"] as Vector2
				max_y = max(max_y, pos.y + size.y)
			for e in elems:
				var pos := e["pos"] as Vector2
				var size := e["size"] as Vector2
				var ny := max_y - size.y
				if pos.y != ny:
					pos.y = ny
					e["pos"] = pos
					moved += 1
	for e in elems:
		reanchor(e)
	return moved


## Distribuye los elementos seleccionados uniformemente (HORIZONTAL o VERTICAL) según sus centros.
func distribute_selected(direction: int) -> int:
	var elems: Array[Dictionary] = selected_elements()
	if elems.size() < 3:
		return 0
	var sorted: Array[Dictionary] = elems.duplicate()
	if direction == DISTRIBUTE_HORIZONTAL:
		sorted.sort_custom(func(a, b):
			return (a["pos"] as Vector2).x < (b["pos"] as Vector2).x
		)
	else:
		sorted.sort_custom(func(a, b):
			return (a["pos"] as Vector2).y < (b["pos"] as Vector2).y
		)
	var first: Dictionary = sorted[0]
	var last: Dictionary = sorted[sorted.size() - 1]
	var p1 := first["pos"] as Vector2
	var p2 := last["pos"] as Vector2
	var s1 := first["size"] as Vector2
	var s2 := last["size"] as Vector2
	var c1 := (p1.x + s1.x * 0.5) if direction == DISTRIBUTE_HORIZONTAL else (p1.y + s1.y * 0.5)
	var c2 := (p2.x + s2.x * 0.5) if direction == DISTRIBUTE_HORIZONTAL else (p2.y + s2.y * 0.5)
	var step := (c2 - c1) / float(sorted.size() - 1)
	var moved := 0
	for i in range(1, sorted.size() - 1):
		var e: Dictionary = sorted[i] as Dictionary
		var pos := e["pos"] as Vector2
		var size := e["size"] as Vector2
		var target_c := c1 + step * float(i)
		var nc: float
		if direction == DISTRIBUTE_HORIZONTAL:
			nc = target_c - size.x * 0.5
			if pos.x != nc:
				pos.x = nc
				e["pos"] = pos
				moved += 1
		else:
			nc = target_c - size.y * 0.5
			if pos.y != nc:
				pos.y = nc
				e["pos"] = pos
				moved += 1
	for e in elems:
		reanchor(e)
	return moved


## Duplica un elemento (o todos los seleccionados si no se pasa id). Devuelve los nuevos IDs.
func duplicate(id_or_none: Variant = null) -> Array[int]:
	var ids: Array[int] = []
	if id_or_none is int and id_or_none != 0:
		ids = [id_or_none]
	else:
		ids = get_selected()
	var made: Array[int] = []
	for id in ids:
		var element := find(id)
		if element.is_empty():
			continue
		var copy := element.duplicate(true)
		copy["id"] = _next_id
		_next_id += 1
		var pos := copy["pos"] as Vector2
		pos = pos + Vector2(18.0, 18.0)
		copy["pos"] = pos
		copy["name"] = copy["name"] + " copia"
		if int(copy["target"]) == id:
			copy["target"] = 0
		elements.append(copy)
		reanchor(copy)
		made.append(int(copy["id"]))
	return made


## Copia los elementos seleccionados al portapapeles interno.
func copy_selected() -> Array[Dictionary]:
	var clipboard: Array[Dictionary] = []
	for id in selected:
		var element := find(id)
		if not element.is_empty():
			clipboard.append(element.duplicate(true))
	return clipboard


## Pega el portapapeles (desplazado). Devuelve los nuevos IDs.
func paste(clipboard: Array[Dictionary]) -> Array[int]:
	var made: Array[int] = []
	for element in clipboard:
		var copy := element.duplicate(true)
		copy["id"] = _next_id
		_next_id += 1
		var pos := copy["pos"] as Vector2
		pos = pos + Vector2(24.0, 24.0)
		copy["pos"] = pos
		copy["name"] = copy["name"] + " copia"
		if int(copy["target"]) != 0:
			copy["target"] = 0
		elements.append(copy)
		reanchor(copy)
		made.append(int(copy["id"]))
	selected = made
	return made


## Agrupa los elementos seleccionados bajo un nuevo group_id. Devuelve el group_id.
func group_selected() -> int:
	if selected.is_empty():
		return 0
	var gid := _next_group_id
	_next_group_id += 1
	for id in selected:
		groups[id] = gid
	return gid


## Desagrupa los elementos seleccionados (elimina su asignación de grupo).
func ungroup_selected() -> void:
	for id in selected:
		groups.erase(id)


## Devuelve el group_id de un elemento, o 0 si no tiene grupo.
func group_of(id: int) -> int:
	return groups.get(id, 0) as int


## Si un elemento tiene grupo, devuelve los IDs de todos los elementos de ese grupo.
func group_members(id: int) -> Array[int]:
	var gid := groups.get(id, 0) as int
	if gid == 0:
		return []
	var result: Array[int] = []
	var keys := groups.keys()
	for i in range(keys.size()):
		var eid := keys[i] as int
		if groups[eid] == gid:
			result.append(eid)
	return result


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
	var grupos := {}
	for gid in groups.keys():
		var eid := groups[gid] as int
		if not grupos.has(gid):
			grupos[gid] = []
		grupos[gid].append(eid)
	return {
		"kind": "tablerama_ui",
		"version": 2,
		"elements": list,
		"groups": grupos,
	}


## Reconstruye un diseño desde datos guardados, o null si algo no es válido.
static func from_record(data: Variant) -> UiLayout:
	if not data is Dictionary or data.get("kind") != "tablerama_ui":
		return null
	var version := int(data.get("version", 1))
	if not _is_int(data.get("version", 1)) or version != 2:
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
	# Restaurar grupos.
	var raw_groups := data.get("groups", {}) as Dictionary
	if raw_groups is Dictionary:
		for gid in raw_groups.keys():
			var members := raw_groups[gid] as Array
			if members is Array:
				for eid in members:
					if int(eid) > 0 and seen.has(int(eid)):
						layout.groups[int(eid)] = int(gid)
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
