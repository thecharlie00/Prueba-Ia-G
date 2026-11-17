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
const MAX_TAGS := 8
const MAX_TAG := 20
const MAX_PATH := 300
## Hasta dónde puede estar una pieza: la mesa mide 2,6 de radio y se puede apilar.
const LIMIT_XZ := 4.0
const LIMIT_Y := 6.0


static func piece_record(entity: PropEntity) -> Dictionary:
	var visual := entity.get_component("VisualComponent") as VisualComponent
	var physics := entity.get_component("PhysicsComponent") as PhysicsComponent
	var deck := entity.get_component("DeckComponent") as DeckComponent
	var counter := entity.get_component("CounterComponent") as CounterComponent
	var bag := entity.get_component("BagComponent") as BagComponent
	var note := entity.get_component("NoteComponent") as NoteComponent
	var timer := entity.get_component("TimerComponent") as TimerComponent
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
		"tags": Array(entity.tags),
		"zkind": visual.zone_kind if visual != null else "normal",
		"player": visual.owner_player if visual != null else 0,
		"tag_filter": visual.tag_filter if visual != null else "",
		"model": visual.mesh_path if visual != null else "",
		"msize": [visual.model_size.x, visual.model_size.y, visual.model_size.z] if visual != null else [0, 0, 0],
		"pos": [snappedf(entity.position.x, 0.001), snappedf(entity.position.y, 0.001), snappedf(entity.position.z, 0.001)],
		"rot": [snappedf(entity.rotation_degrees.x, 0.01), snappedf(entity.rotation_degrees.y, 0.01), snappedf(entity.rotation_degrees.z, 0.01)],
		"scale": visual.scale_factor if visual != null else 1.0,
		"locked": entity.is_locked,
		"mass": physics.mass if physics != null else 1.0,
		"bounce": physics.bounce if physics != null else 0.1,
		"deck": _deck_record(deck),
		"counter": _counter_record(counter),
		"bag": _bag_record(bag),
		"note": _note_record(note),
		"timer": _timer_record(timer),
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
	var model := str(d.get("model", ""))
	if not (_valid_path(texture) and _valid_path(back) and _valid_path(model)):
		return {}
	var model_size: Variant = _vec3(d.get("msize", [0, 0, 0]))
	if model_size == null:
		return {}
	var zone_kind := str(d.get("zkind", "normal"))
	var player_value: Variant = d.get("player", 0)
	if not _number(player_value):
		return {}
	var scale_value: Variant = d.get("scale", 1.0)
	var mass_value: Variant = d.get("mass", 1.0)
	var bounce_value: Variant = d.get("bounce", 0.1)
	var cells_value: Variant = d.get("cells", 8)
	if not (_number(scale_value) and _number(mass_value) and _number(bounce_value) and _number(cells_value)):
		return {}
	var pattern := str(d.get("pattern", "liso"))
	var finish := str(d.get("finish", "mate"))
	# DeckComponent: validar mazo si viene.
	var deck_value := d.get("deck", {})
	var deck_clean: Dictionary = {}
	if deck_value is Dictionary and not deck_value.is_empty():
		var cards_raw := deck_value.get("cards", []) as Array
		var cards_clean: Array = []
		if cards_raw is Array:
			for c in cards_raw:
				if c is Dictionary:
					cards_clean.append({
						"id": str(c.get("id", "")).left(32),
						"name": str(c.get("name", "Carta")).left(MAX_NAME),
						"texture": str(c.get("texture", "")).left(MAX_PATH),
						"back": str(c.get("back", "")).left(MAX_PATH),
						"label": str(c.get("label", "")).left(MAX_LABEL),
						"notes": str(c.get("notes", "")).left(MAX_NOTES),
						"face_up": c.get("face_up", true) == true,
					})
		deck_clean = {
			"cards": cards_clean,
			"face_up": deck_value.get("face_up", true) == true,
			"show_count": deck_value.get("show_count", true) == true,
			"peek_count": clampi(int(deck_value.get("peek_count", 3)), 1, 10),
			"max_capacity": int(deck_value.get("max_capacity", -1)),
			"default_deal_zone": str(deck_value.get("default_deal_zone", "")).left(MAX_PATH),
		}

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
		"tags": clean_tags(d.get("tags", [])),
		"zkind": zone_kind if zone_kind in PieceShapes.ZONE_KINDS else "normal",
		"player": clampi(int(player_value), 0, GamePlayers.MAX),
		"tag_filter": str(d.get("tag_filter", "")).left(MAX_TAG),
		"model": model,
		"msize": (model_size as Vector3).clamp(Vector3.ZERO, Vector3.ONE),
		"pos": p,
		"rot": rot,
		"scale": clampf(float(scale_value), PieceShapes.MIN_SCALE, PieceShapes.MAX_SCALE),
		"locked": d.get("locked", false) == true,
		"mass": clampf(float(mass_value), 0.05, 50.0),
		"bounce": clampf(float(bounce_value), 0.0, 1.0),
		"deck": deck_clean,
		"counter": _clean_counter(d.get("counter", {})),
		"bag": _clean_bag(d.get("bag", {})),
		"note": _clean_note(d.get("note", {})),
		"timer": _clean_timer(d.get("timer", {})),
	}


## Vuelca una pieza limpia (de valid_piece) en una entidad, creando sus componentes.
static func apply_piece(entity: PropEntity, piece: Dictionary) -> void:
	if str(piece.get("id", "")) != "":
		entity.entity_id = piece["id"]
	entity.entity_name = piece["name"]
	entity.is_locked = piece["locked"]
	entity.tags.assign(piece.get("tags", []))
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
	visual.zone_kind = piece.get("zkind", "normal")
	visual.owner_player = piece.get("player", 0)
	visual.tag_filter = str(piece.get("tag_filter", ""))
	visual.mesh_path = piece.get("model", "")
	visual.model_size = piece.get("msize", Vector3.ZERO)
	var physics := entity.get_component("PhysicsComponent") as PhysicsComponent
	if physics == null:
		physics = PhysicsComponent.new()
		entity.add_component(physics)
	physics.mass = piece["mass"]
	physics.bounce = piece["bounce"]
	if entity.get_component("InteractiveComponent") == null:
		entity.add_component(InteractiveComponent.new())
	# DeckComponent: mazo como un solo objeto (FASE 1).
	var deck_data := piece.get("deck", {})
	if deck_data is Dictionary and not deck_data.is_empty():
		if entity.get_component("DeckComponent") == null:
			entity.add_component(DeckComponent.new())
		var deck := entity.get_component("DeckComponent") as DeckComponent
		deck.cards = deck_data.get("cards", []) if deck_data.get("cards") is Array else []
		deck.face_up = deck_data.get("face_up", true) == true
		deck.show_count = deck_data.get("show_count", true) == true
		deck.peek_count = clampi(int(deck_data.get("peek_count", 3)), 1, 10)
		deck.max_capacity = int(deck_data.get("max_capacity", -1))
		deck.default_deal_zone = str(deck_data.get("default_deal_zone", ""))
	# CounterComponent (FASE 5).
	var counter_data := piece.get("counter", {})
	if counter_data is Dictionary and not counter_data.is_empty():
		if entity.get_component("CounterComponent") == null:
			entity.add_component(CounterComponent.new())
		var counter := entity.get_component("CounterComponent") as CounterComponent
		counter.value = clampi(int(counter_data.get("value", 0)), int(counter_data.get("min_value", 0)), int(counter_data.get("max_value", 999)))
		counter.min_value = int(counter_data.get("min_value", 0))
		counter.max_value = int(counter_data.get("max_value", 999))
		counter.step = int(counter_data.get("step", 1))
		counter.label = str(counter_data.get("label", "Contador"))
	# BagComponent (FASE 5).
	var bag_data := piece.get("bag", {})
	if bag_data is Dictionary and not bag_data.is_empty():
		if entity.get_component("BagComponent") == null:
			entity.add_component(BagComponent.new())
		var bag := entity.get_component("BagComponent") as BagComponent
		bag.label = str(bag_data.get("label", "Bolsa"))
		bag.hidden = bag_data.get("hidden", true) == true
		bag.contained_ids = bag_data.get("contained_ids", []) if bag_data.get("contained_ids") is Array else []
	# NoteComponent (FASE 5).
	var note_data := piece.get("note", {})
	if note_data is Dictionary and not note_data.is_empty():
		if entity.get_component("NoteComponent") == null:
			entity.add_component(NoteComponent.new())
		var note := entity.get_component("NoteComponent") as NoteComponent
		note.text = str(note_data.get("text", "")).left(NoteComponent.MAX_NOTES)
		note.show_on_hover = note_data.get("show_on_hover", true) == true
	# TimerComponent (FASE 5).
	var timer_data := piece.get("timer", {})
	if timer_data is Dictionary and not timer_data.is_empty():
		if entity.get_component("TimerComponent") == null:
			entity.add_component(TimerComponent.new())
		var timer := entity.get_component("TimerComponent") as TimerComponent
		timer.label = str(timer_data.get("label", "Reloj"))
		timer.duration_seconds = clampf(float(timer_data.get("duration_seconds", 60.0)), 0.0, 3600.0)
		timer.running = timer_data.get("running", false) == true
		timer.time_left = clampf(float(timer_data.get("time_left", timer.duration_seconds)), 0.0, timer.duration_seconds)
		timer.on_finish_message = str(timer_data.get("on_finish_message", "¡Tiempo agotado!")).left(NoteComponent.MAX_NOTES)
	entity.position = piece["pos"]
	entity.rotation_degrees = piece["rot"]


## Registro del DeckComponent de una pieza (mazo), o un diccionario vacío si no hay.
static func _deck_record(deck: DeckComponent) -> Dictionary:
	if deck == null:
		return {}
	return {
		"cards": deck.cards,
		"face_up": deck.face_up,
		"show_count": deck.show_count,
		"peek_count": deck.peek_count,
		"max_capacity": deck.max_capacity,
		"default_deal_zone": deck.default_deal_zone,
	}

## Registro del CounterComponent, o vacío si no hay.
static func _counter_record(counter: CounterComponent) -> Dictionary:
	if counter == null:
		return {}
	return {
		"value": counter.value,
		"min_value": counter.min_value,
		"max_value": counter.max_value,
		"step": counter.step,
		"label": counter.label,
	}

## Registro del BagComponent, o vacío si no hay.
static func _bag_record(bag: BagComponent) -> Dictionary:
	if bag == null:
		return {}
	return {
		"label": bag.label,
		"hidden": bag.hidden,
		"contained_ids": Array(bag.contained_ids),
	}

## Registro del NoteComponent, o vacío si no hay.
static func _note_record(note: NoteComponent) -> Dictionary:
	if note == null:
		return {}
	return {
		"text": note.text,
		"show_on_hover": note.show_on_hover,
	}

## Registro del TimerComponent, o vacío si no hay.
static func _timer_record(timer: TimerComponent) -> Dictionary:
	if timer == null:
		return {}
	return {
		"label": timer.label,
		"duration_seconds": timer.duration_seconds,
		"running": timer.running,
		"time_left": timer.time_left,
		"on_finish_message": timer.on_finish_message,
	}

## Etiquetas: en minúsculas, sin repetir, como mucho MAX_TAGS de MAX_TAG letras.
static func clean_tags(raw: Variant) -> Array:
	var result: Array = []
	var items: Array = raw if raw is Array else (str(raw).split(",") as Array if raw is String else [])
	for item in items:
		var tag := str(item).strip_edges().to_lower().left(MAX_TAG)
		if tag != "" and not tag in result and result.size() < MAX_TAGS:
			result.append(tag)
	return result


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


## Limpia y valida los datos de un CounterComponent, o vacío si no hay.
static func _clean_counter(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var value := int(raw.get("value", 0))
	var min_v := int(raw.get("min_value", 0))
	var max_v := int(raw.get("max_value", 999))
	var step := int(raw.get("step", 1))
	var label := str(raw.get("label", "Contador"))
	if min_v > max_v:
		min_v = 0
		max_v = 999
	value = clampi(value, min_v, max_v)
	return {
		"value": value,
		"min_value": min_v,
		"max_value": max_v,
		"step": step,
		"label": label.left(MAX_NAME),
	}

## Limpia y valida los datos de un BagComponent, o vacío si no hay.
static func _clean_bag(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var label := str(raw.get("label", "Bolsa")).left(MAX_NAME)
	var hidden := raw.get("hidden", true) == true
	var ids := raw.get("contained_ids", []) as Array
	if not ids is Array:
		ids = []
	var clean_ids: Array = []
	for id in ids:
		var sid := str(id).left(32)
		if sid != "" and not sid in clean_ids:
			clean_ids.append(sid)
	return {
		"label": label,
		"hidden": hidden,
		"contained_ids": clean_ids,
	}

## Limpia y valida los datos de un NoteComponent, o vacío si no hay.
static func _clean_note(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	return {
		"text": str(raw.get("text", "")).left(MAX_NOTES),
		"show_on_hover": raw.get("show_on_hover", true) == true,
	}

## Limpia y valida los datos de un TimerComponent, o vacío si no hay.
static func _clean_timer(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var duration := clampf(float(raw.get("duration_seconds", 60.0)), 0.0, 3600.0)
	var running := raw.get("running", false) == true
	var time_left := clampf(float(raw.get("time_left", duration)), 0.0, duration)
	var message := str(raw.get("on_finish_message", "¡Tiempo agotado!")).left(MAX_NOTES)
	return {
		"label": str(raw.get("label", "Reloj")).left(MAX_NAME),
		"duration_seconds": duration,
		"running": running,
		"time_left": time_left,
		"on_finish_message": message,
	}
