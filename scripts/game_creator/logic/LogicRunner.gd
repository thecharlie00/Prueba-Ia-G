# LogicRunner.gd
# Ejecuta la lógica (blueprints) mientras se prueba la mesa: escucha los eventos, sigue los
# cables de flujo y calcula los valores que piden los bloques. Tiene un límite de pasos por
# evento para que un bucle mal montado no cuelgue el juego.
class_name LogicRunner
extends RefCounted

const STEP_LIMIT := 20000
## Bloques de flujo encadenados sin volver al evento (un círculo de cables acaba aquí).
const CHAIN_LIMIT := 300
const DEPTH_LIMIT := 64
const REPEAT_LIMIT := 1000

var graph: LogicGraph
var api := TableApi.new()
## Errores de compilación de los bloques GDScript: id → texto.
var errors := {}
## Lo que ha pasado (para los tests y la consola): textos cortos.
var trace: Array[String] = []
var active := false

var _editor: Node
var _outputs := {}
var _scripts := {}
var _steps := 0
var _depth := 0
var _chain := 0
var _stopped_warned := false
var _timers: Array = []


func _init(logic: LogicGraph, editor: Node) -> void:
	graph = logic
	_editor = editor
	LogicHost.bind(api, editor)


## Compila los bloques de código y dispara «Al empezar la partida».
func start() -> void:
	active = true
	errors.clear()
	for node in graph.nodes.values():
		if LogicNodes.DEFS[node["type"]]["cat"] == "codigo":
			var compiled := GdSandbox.compile(str(node["params"].get("codigo", "")))
			if compiled.has("error"):
				errors[node["id"]] = compiled["error"]
			else:
				_scripts[node["id"]] = (compiled["script"] as GDScript).new()
	for node in graph.events("ev_cada"):
		var timer := Timer.new()
		timer.wait_time = clampf(float(node["params"].get("segundos", 5.0)), 0.1, 3600.0)
		timer.autostart = true
		timer.timeout.connect(_on_timer.bind(int(node["id"])))
		_editor.add_child(timer)
		_timers.append(timer)
	fire("ev_inicio")


func stop() -> void:
	active = false
	for timer in _timers:
		if is_instance_valid(timer):
			timer.queue_free()
	_timers.clear()
	_scripts.clear()
	LogicHost.release(api)


## Dispara los eventos de tipo `type` que cumplan `matches` con estas salidas de datos.
func fire(type: String, matches := Callable(), data := {}) -> void:
	if not active:
		return
	for node in graph.events(type):
		if matches.is_valid() and not matches.call(node["params"]):
			continue
		_outputs[node["id"]] = data
		_steps = 0
		_stopped_warned = false
		LogicHost.reset_budget(api)
		_follow(int(node["id"]), "out")


func _on_timer(id: int) -> void:
	if active and graph.nodes.has(id):
		_steps = 0
		_stopped_warned = false
		LogicHost.reset_budget(api)
		_follow(id, "out")


func _follow(id: int, out: String) -> void:
	for next in graph.next_of(id, out):
		_chain += 1
		if _chain > CHAIN_LIMIT:
			_steps = STEP_LIMIT + 1
		_exec(int(next))
		_chain -= 1


func _exec(id: int) -> void:
	if not active or not graph.nodes.has(id):
		return
	_steps += 1
	if _steps > STEP_LIMIT:
		if not _stopped_warned:
			_stopped_warned = true
			_editor.logic_message(TranslationServer.translate("La lógica ha dado demasiados pasos seguidos y se ha parado."))
		return
	var node: Dictionary = graph.nodes[id]
	var type: String = node["type"]
	trace.append(type)
	match type:
		"fl_si":
			_follow(id, "si" if _truthy(_value(id, "condicion")) else "no")
			return
		"fl_secuencia":
			for out in ["1", "2", "3"]:
				_follow(id, out)
			return
		"fl_repetir":
			var times := clampi(int(_number(_value(id, "veces"))), 0, REPEAT_LIMIT)
			for i in times:
				_outputs[id] = {"indice": i}
				_follow(id, "cuerpo")
			_follow(id, "fin")
			return
		"fl_paracada":
			var list: Variant = _value(id, "lista")
			if list is Array:
				for item in (list as Array).slice(0, REPEAT_LIMIT):
					_outputs[id] = {"elemento": item}
					_follow(id, "cuerpo")
			_follow(id, "fin")
			return
		"fl_esperar":
			var seconds := clampf(_number(_value(id, "segundos")), 0.0, 600.0)
			var tree: SceneTree = _editor.get_tree()
			tree.create_timer(seconds).timeout.connect(func() -> void:
				if active:
					_steps = 0
					_follow(id, "out")
			)
			return
		"ac_repartir":
			_editor.logic_deal(int(_number(_value(id, "cantidad"))), str(node["params"]["de"]), str(node["params"]["a"]), str(node["params"]["etiqueta"]))
		"ac_mover":
			_editor.logic_move(str(_value(id, "pieza")), str(node["params"]["a"]))
		"ac_mezclar":
			_editor.logic_shuffle(str(node["params"]["zona"]))
		"ac_voltear":
			_editor.logic_flip(str(_value(id, "pieza")))
		"ac_voltear_zona":
			for piece in _editor.logic_pieces(str(node["params"]["zona"]), ""):
				_editor.logic_flip(piece)
		"ac_tirar":
			_editor.roll_dice()
		"ac_sumar":
			var counter := int(node["params"]["contador"])
			_editor.logic_set_counter(counter, _editor.logic_counter(counter) + int(_number(_value(id, "cantidad"))))
		"ac_poner":
			_editor.logic_set_counter(int(node["params"]["contador"]), int(_number(_value(id, "valor"))))
		"ac_mensaje":
			_editor.logic_message(str(_value(id, "texto")))
		"ac_interfaz":
			_editor.logic_show_element(int(node["params"]["elemento"]), _truthy(_value(id, "visible")))
		"ac_variable":
			_editor.logic_store(str(node["params"]["nombre"]), _value(id, "valor"))
		"ac_escribir":
			_editor.logic_set_label(str(_value(id, "pieza")), str(_value(id, "texto")))
		"ac_color":
			_editor.logic_set_color(str(_value(id, "pieza")), str(_value(id, "color")))
		"ac_repartir_mazo":
			_editor.repartir_mazo(str(_value(id, "mazo")), int(_number(_value(id, "cantidad"))), str(_value(id, "zona")))
		"ac_contador_sumar":
			var e := _editor
			if e != null:
				var entity: PropEntity = e._find_piece(str(_value(id, "pieza"))) as PropEntity
				var counter: CounterComponent = entity.get_component("CounterComponent") if entity != null else null
				if counter != null:
					counter.add(int(_number(_value(id, "cantidad"))))
		"ac_contador_poner":
			var e := _editor
			if e != null:
				var entity: PropEntity = e._find_piece(str(_value(id, "pieza"))) as PropEntity
				var counter: CounterComponent = entity.get_component("CounterComponent") if entity != null else null
				if counter != null:
					counter.set_value(int(_number(_value(id, "valor"))))
		"ac_contador_resetear":
			var e := _editor
			if e != null:
				var entity: PropEntity = e._find_piece(str(_value(id, "pieza"))) as PropEntity
				var counter: CounterComponent = entity.get_component("CounterComponent") if entity != null else null
				if counter != null:
					counter.reset()
		"ac_bolsa_sacar_azar":
			var e := _editor
			if e != null:
				var entity: PropEntity = e._find_piece(str(_value(id, "bolsa"))) as PropEntity
				var bag: BagComponent = entity.get_component("BagComponent") if entity != null else null
				var id_sacado: String = bag.draw_random() if bag != null else ""
				_outputs[id] = {"pieza": id_sacado}
		"ac_bolsa_agregar":
			var e := _editor
			if e != null:
				var bag_entity: PropEntity = e._find_piece(str(_value(id, "bolsa"))) as PropEntity
				var piece_entity: PropEntity = e._find_piece(str(_value(id, "pieza"))) as PropEntity
				var bag: BagComponent = bag_entity.get_component("BagComponent") if bag_entity != null else null
				if bag != null and piece_entity != null:
					bag.add(piece_entity.entity_id)
		"ac_nota_escribir":
			var e := _editor
			if e != null:
				var entity: PropEntity = e._find_piece(str(_value(id, "pieza"))) as PropEntity
				var note: NoteComponent = entity.get_component("NoteComponent") if entity != null else null
				if note != null:
					note.set_text(str(_value(id, "texto")))
		"ac_reloj_iniciar":
			var e := _editor
			if e != null:
				var entity: PropEntity = e._find_piece(str(_value(id, "reloj"))) as PropEntity
				var timer: TimerComponent = entity.get_component("TimerComponent") if entity != null else null
				if timer != null:
					timer.start()
		"ac_reloj_parar":
			var e := _editor
			if e != null:
				var entity: PropEntity = e._find_piece(str(_value(id, "reloj"))) as PropEntity
				var timer: TimerComponent = entity.get_component("TimerComponent") if entity != null else null
				if timer != null:
					timer.stop()
		"ac_reloj_reiniciar":
			var e := _editor
			if e != null:
				var entity: PropEntity = e._find_piece(str(_value(id, "reloj"))) as PropEntity
				var timer: TimerComponent = entity.get_component("TimerComponent") if entity != null else null
				if timer != null:
					timer.reset()
		"gd_bloque":
			_outputs[id] = {"resultado": _run_code(id)}
		"ac_pasar_turno":
			_editor.logic_pass_turn()
		"ac_dar_turno":
			_editor.logic_give_turn(int(_number(_value(id, "jugador"))) - 1)
	_follow(id, "out")


## Valor que llega a la entrada `input` de un bloque: por su cable o, sin cable, su parámetro.
func _value(id: int, input: String) -> Variant:
	var link := graph.link_into(id, input)
	if link.is_empty():
		return graph.nodes[id]["params"].get(input)
	var source := int(link["from"])
	if LogicNodes.is_pure(graph.nodes[source]["type"]):
		return _compute(source, str(link["out"]))
	return _outputs.get(source, {}).get(str(link["out"]))


func _compute(id: int, out: String) -> Variant:
	_depth += 1
	if _depth > DEPTH_LIMIT:
		_depth -= 1
		return null
	var result: Variant = _compute_inner(id, out)
	_depth -= 1
	return result


func _compute_inner(id: int, _out: String) -> Variant:
	var node: Dictionary = graph.nodes[id]
	var p: Dictionary = node["params"]
	match str(node["type"]):
		"da_numero":
			return float(p["valor"])
		"da_texto":
			return str(p["valor"])
		"da_piezas":
			return _editor.logic_pieces(str(p["zona"]), str(p["etiqueta"]))
		"da_contar":
			var list: Variant = _value(id, "lista")
			return float((list as Array).size()) if list is Array else 0.0
		"da_azar":
			var low := int(_number(_value(id, "min")))
			var high := int(_number(_value(id, "max")))
			return float(randi_range(mini(low, high), maxi(low, high)))
		"da_operar":
			var a := _number(_value(id, "a"))
			var b := _number(_value(id, "b"))
			match str(p["op"]):
				"+": return a + b
				"-": return a - b
				"×": return a * b
				"÷": return a / b if not is_zero_approx(b) else 0.0
				"resto": return fposmod(a, b) if not is_zero_approx(b) else 0.0
				"mín": return minf(a, b)
				"máx": return maxf(a, b)
		"da_comparar":
			return _compare(_value(id, "a"), _value(id, "b"), str(p["op"]))
		"da_logica":
			var a := _truthy(_value(id, "a"))
			var b := _truthy(_value(id, "b"))
			match str(p["op"]):
				"y": return a and b
				"o": return a or b
				"no": return not a
		"da_variable":
			return _editor.logic_variable(str(p["nombre"]))
		"da_contador":
			return float(_editor.logic_counter(int(p["contador"])))
		"da_dados":
			var total := 0
			for value in _editor.last_roll:
				total += value
			return float(total)
		"da_unir":
			return _text(_value(id, "a")) + _text(_value(id, "b"))
		"da_etiqueta":
			return str(p["etiqueta"]).strip_edges().to_lower() in _editor.logic_piece_tags(str(_value(id, "pieza")))
		"da_nombre":
			return _editor.logic_piece_name(str(_value(id, "pieza")))
		"da_todas_piezas":
			return _editor.logic_pieces("", "")
		"da_etiquetas_pieza":
			return _editor.logic_piece_tags(str(_value(id, "pieza")))
		"da_texto_de":
			return _editor.logic_piece_label(str(_value(id, "pieza")))
		"da_zona_de":
			return _editor.logic_zone_of(str(_value(id, "pieza")))
		"da_zonas":
			return _editor.logic_zone_names()
		"da_mano":
			return _editor.hand_zone_of(_editor.current_player)
		"da_nombre_jugador":
			return GamePlayers.player_name(clampi(int(_number(_value(id, "jugador"))) - 1, 0, _editor.players - 1))
		"da_rango":
			var n := clampi(int(_number(_value(id, "n"))), 0, 1000)
			return range(n)
		"da_color":
			var c: Color = _editor.logic_piece_color(str(_value(id, "pieza")))
			return c.to_html(true)
		"da_cartas_en_mazo":
			return float(_editor.cartas_en_mazo(str(_value(id, "mazo"))))
		"da_carta_arriba":
			return _editor.carta_arriba(str(_value(id, "mazo")))
		"da_contador_valor":
			var e := _editor
			var entity: PropEntity = e._find_piece(str(_value(id, "pieza"))) if e != null else null as PropEntity
			var counter := entity.get_component("CounterComponent") if entity != null else null
			return float(counter.value if counter != null else 0)
		"da_bolsa_contar":
			var e := _editor
			var entity: PropEntity = e._find_piece(str(_value(id, "bolsa"))) if e != null else null as PropEntity
			var bag := entity.get_component("BagComponent") if entity != null else null
			return float(bag.count() if bag != null else 0)
		"da_nota_leer":
			var e := _editor
			var entity: PropEntity = e._find_piece(str(_value(id, "pieza"))) if e != null else null as PropEntity
			var note := entity.get_component("NoteComponent") if entity != null else null
			return note.get_text() if note != null else ""
		"da_reloj_tiempo":
			var e := _editor
			var entity: PropEntity = e._find_piece(str(_value(id, "reloj"))) if e != null else null as PropEntity
			var timer := entity.get_component("TimerComponent") if entity != null else null
			return float(timer.remaining() if timer != null else 0.0)
		"gd_expresion":
			return _run_code(id)
		"da_jugador":
			return float(_editor.current_player + 1) if _out == "jugador" else GamePlayers.player_name(_editor.current_player)
		"da_jugadores":
			return float(_editor.players)
	return null


func _run_code(id: int) -> Variant:
	if errors.has(id):
		_editor.logic_message(TranslationServer.translate("Un bloque GDScript tiene un error: ") + str(errors[id]))
		return null
	var instance: Object = _scripts.get(id)
	if instance == null:
		return null
	return instance.call("ejecutar", api, _value(id, "a"), _value(id, "b"))


static func _number(value: Variant) -> float:
	if value is float or value is int:
		return float(value)
	if value is bool:
		return 1.0 if value else 0.0
	if value is String and (value as String).is_valid_float():
		return float(value)
	if value is Array:
		return float((value as Array).size())
	return 0.0


static func _truthy(value: Variant) -> bool:
	if value is bool:
		return value
	if value is float or value is int:
		return not is_zero_approx(float(value))
	if value is String:
		return value != ""
	if value is Array:
		return not (value as Array).is_empty()
	return value != null


static func _text(value: Variant) -> String:
	if value is float and is_equal_approx(value, roundf(value)):
		return str(int(value))
	return "" if value == null else str(value)


static func _compare(a: Variant, b: Variant, op: String) -> bool:
	var numbers := (a is float or a is int or a is bool) and (b is float or b is int or b is bool)
	if numbers:
		var x := _number(a)
		var y := _number(b)
		match op:
				"==": return is_equal_approx(x, y)
				"!=": return not is_equal_approx(x, y)
				"<": return x < y
				">": return x > y
				"<=": return x <= y or is_equal_approx(x, y)
				">=": return x >= y or is_equal_approx(x, y)
	var s := _text(a)
	var t := _text(b)
	match op:
		"==": return s == t
		"!=": return s != t
		"<": return s < t
		">": return s > t
		"<=": return s <= t
		">=": return s >= t
	return false
