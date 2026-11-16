# TableRecord.gd
# La mesa del editor en un formato sencillo de guardar (JSON) y de comprobar al cargar:
# sólo números, textos y listas, sin tipos de Godot. Lo usan el guardado, la carga y el
# historial de deshacer.
class_name TableRecord
extends RefCounted

const VERSION := 1
const MAX_PIECES := 200
const MAX_NAME := 40
const MAX_LABEL := 24
const MAX_NOTES := 200
const MAX_PATH := 300
## Hasta dónde puede estar una pieza: la mesa mide 2,6 de radio y se puede apilar.
const LIMIT_XZ := 4.0
const LIMIT_Y := 6.0


static func piece_record(entity: PropEntity) -> Dictionary:
	var visual := entity.get_component("VisualComponent") as VisualComponent
	var physics := entity.get_component("PhysicsComponent") as PhysicsComponent
	return {
		"id": entity.entity_id,
		"name": entity.entity_name,
		"shape": visual.shape if visual != null else PieceShapes.DEFAULT,
		"color": (visual.color_tint if visual != null else Color.WHITE).to_html(true),
		"texture": visual.texture_path if visual != null else "",
		"label": visual.label if visual != null else "",
		"pattern": visual.pattern if visual != null else "liso",
		"cells": visual.cells if visual != null else 8,
		"finish": visual.finish if visual != null else "mate",
		"back": visual.back_path if visual != null else "",
		"notes": visual.notes if visual != null else "",
		"shuffle": visual.shuffle_on_play if visual != null else false,
		"pos": [snappedf(entity.position.x, 0.001), snappedf(entity.position.y, 0.001), snappedf(entity.position.z, 0.001)],
		"rot": [snappedf(entity.rotation_degrees.x, 0.01), snappedf(entity.rotation_degrees.y, 0.01), snappedf(entity.rotation_degrees.z, 0.01)],
		"scale": visual.scale_factor if visual != null else 1.0,
		"locked": entity.is_locked,
		"mass": physics.mass if physics != null else 1.0,
		"bounce": physics.bounce if physics != null else 0.1,
	}


static func table_record(entities: Array) -> Dictionary:
	var pieces: Array = []
	for entity in entities:
		if is_instance_valid(entity):
			pieces.append(piece_record(entity))
	return {"version": VERSION, "pieces": pieces}


## Piezas válidas de un registro (limpias), o null si el registro no sirve.
static func pieces_of(data: Variant) -> Variant:
	if not data is Dictionary or not (data as Dictionary).get("pieces") is Array:
		return null
	var list: Array = data["pieces"]
	if list.size() > MAX_PIECES:
		return null
	var result: Array = []
	for item in list:
		var piece := valid_piece(item)
		if piece.is_empty():
			return null
		result.append(piece)
	return result


static func valid_piece(item: Variant) -> Dictionary:
	if not item is Dictionary:
		return {}
	var d: Dictionary = item
	var pos: Variant = _vec3(d.get("pos"))
	var rot: Variant = _vec3(d.get("rot"))
	if pos == null or rot == null:
		return {}
	var p: Vector3 = pos
	if absf(p.x) > LIMIT_XZ or absf(p.z) > LIMIT_XZ or p.y < -0.5 or p.y > LIMIT_Y:
		return {}
	var color_text := str(d.get("color", "ffffffff"))
	if not Color.html_is_valid(color_text):
		return {}
	var texture := str(d.get("texture", ""))
	var back := str(d.get("back", ""))
	if not (_valid_path(texture) and _valid_path(back)):
		return {}
	var scale_value: Variant = d.get("scale", 1.0)
	var mass_value: Variant = d.get("mass", 1.0)
	var bounce_value: Variant = d.get("bounce", 0.1)
	var cells_value: Variant = d.get("cells", 8)
	if not (_number(scale_value) and _number(mass_value) and _number(bounce_value) and _number(cells_value)):
		return {}
	var pattern := str(d.get("pattern", "liso"))
	var finish := str(d.get("finish", "mate"))
	return {
		"id": str(d.get("id", "")).left(32),
		"name": str(d.get("name", "Pieza")).left(MAX_NAME),
		"shape": PieceShapes.valid(str(d.get("shape", PieceShapes.DEFAULT))),
		"color": color_text,
		"texture": texture,
		"label": str(d.get("label", "")).left(MAX_LABEL),
		"pattern": pattern if pattern in PieceShapes.PATTERNS else "liso",
		"cells": clampi(int(cells_value), PieceShapes.MIN_CELLS, PieceShapes.MAX_CELLS),
		"finish": finish if finish in PieceShapes.FINISHES else "mate",
		"back": back,
		"notes": str(d.get("notes", "")).left(MAX_NOTES),
		"shuffle": d.get("shuffle", false) == true,
		"pos": p,
		"rot": rot,
		"scale": clampf(float(scale_value), PieceShapes.MIN_SCALE, PieceShapes.MAX_SCALE),
		"locked": d.get("locked", false) == true,
		"mass": clampf(float(mass_value), 0.05, 50.0),
		"bounce": clampf(float(bounce_value), 0.0, 1.0),
	}


## Vuelca una pieza limpia (de valid_piece) en una entidad, creando sus componentes.
static func apply_piece(entity: PropEntity, piece: Dictionary) -> void:
	if str(piece.get("id", "")) != "":
		entity.entity_id = piece["id"]
	entity.entity_name = piece["name"]
	entity.is_locked = piece["locked"]
	var visual := entity.get_component("VisualComponent") as VisualComponent
	if visual == null:
		visual = VisualComponent.new()
		entity.add_component(visual)
	visual.shape = piece["shape"]
	visual.color_tint = Color.html(piece["color"])
	visual.texture_path = piece["texture"]
	visual.scale_factor = piece["scale"]
	visual.label = piece.get("label", "")
	visual.pattern = piece.get("pattern", "liso")
	visual.cells = piece.get("cells", 8)
	visual.finish = piece.get("finish", "mate")
	visual.back_path = piece.get("back", "")
	visual.notes = piece.get("notes", "")
	visual.shuffle_on_play = piece.get("shuffle", false)
	var physics := entity.get_component("PhysicsComponent") as PhysicsComponent
	if physics == null:
		physics = PhysicsComponent.new()
		entity.add_component(physics)
	physics.mass = piece["mass"]
	physics.bounce = piece["bounce"]
	if entity.get_component("InteractiveComponent") == null:
		entity.add_component(InteractiveComponent.new())
	entity.position = piece["pos"]
	entity.rotation_degrees = piece["rot"]


## Rutas de imagen: vacías o dentro de los datos del juego (nunca del disco del jugador).
static func _valid_path(path: String) -> bool:
	if path == "":
		return true
	return path.length() <= MAX_PATH and (path.begins_with("user://") or path.begins_with("res://")) and not ".." in path


static func _vec3(value: Variant) -> Variant:
	if not value is Array or (value as Array).size() != 3:
		return null
	for n in value:
		if not _number(n):
			return null
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))
