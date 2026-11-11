# RuleEngine.gd
# Intérprete del grafo de lógica visual. Ejecuta nodos de forma segura,
# gestiona variables globales y por jugador, y expone señales para conectar
# eventos del juego (turno, carta jugada, dado, ficha movida, zona, etc.).
extends Node

# Grafo de reglas actualmente cargado.
# Tipado débil (sin tipo de clase) para evitar errores de orden de carga:
# RuleEngine.gd se parsea antes que RuleGraph.gd / RuleNode.gd alfabéticamente.
@export var graph = null

# Variables globales de partida.
var global_variables: Dictionary = {}

# Variables por jugador: { player_id: { var_name: value } }.
var player_variables: Dictionary = {}

# Índice de nodos por GUID para ejecución rápida.
var _nodes_by_id: Dictionary = {}

# Señales para que el juego se suscriba a eventos del motor de reglas.
signal event_triggered(event_name: String, args: Array)

var _is_running: Boolean = false

func _init() -> void:
	pass

func set_graph(new_graph: RuleGraph) -> void:
	graph = new_graph
	_rebuild_index()

func _rebuild_index() -> void:
	_nodes_by_id.clear()
	if graph != null:
		for node in graph.nodes:
			_nodes_by_id[node.guid] = node

# Arranca el motor de reglas.
func start() -> void:
	_is_running = true
	_rebuild_index()
	global_variables.clear()
	player_variables.clear()
	print("[RuleEngine] Motor de reglas iniciado")

# Detiene el motor de reglas.
func stop() -> void:
	_is_running = false

# Dispara un evento en el grafo. Busca nodos de tipo RuleEventNode cuyo
# event_name coincida y los ejecuta.
func trigger_event(event_name: String, args: Array = []) -> void:
	if not _is_running:
		return
	event_triggered.emit(event_name, args)
	if graph != null:
		for node in graph.nodes:
			if node.get_class() == "RuleEventNode" and node.event_name == event_name:
				_execute_node(node, args)

# Ejecuta un nodo y propaga el resultado a sus sucesores según las conexiones.
func _execute_node(node, input_args: Array) -> void:
	if not _is_running:
		return
	var output_args: Array = node.execute(self, input_args)
	# Propagar a nodos conectados desde este nodo.
	if graph != null:
		for conn in graph.connections:
			if conn.get("from_guid") == node.guid:
				var target = _nodes_by_id.get(conn.get("to_guid"), null)
				if target != null:
					_execute_node(target, output_args)

# --- Variables globales ---
func get_global_variable(name: String) -> Variant:
	return global_variables.get(name, null)

func set_global_variable(name: String, value: Variant) -> void:
	global_variables[name] = value

# --- Variables por jugador ---
func get_player_variable(player_id: int, name: String) -> Variant:
	var p_vars: Dictionary = player_variables.get(player_id, {})
	return p_vars.get(name, null)

func set_player_variable(player_id: int, name: String, value: Variant) -> void:
	if not player_variables.has(player_id):
		player_variables[player_id] = {}
	player_variables[player_id][name] = value

# --- Nodos de acción específicos integrados ---
# Mover una entidad a una posición.
func _action_move_object(entity, target_position: Vector3, duration: float = 0.5) -> void:
	if entity == null:
		return
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(entity, "global_position", target_position, duration)
	tween.play()

# Cambiar puntuación de un jugador.
func _action_modify_score(player_id: int, delta: float) -> void:
	var current: float = get_player_variable(player_id, "score")
	if current == null:
		current = 0
	set_player_variable(player_id, "score", current + delta)

# Finalizar turno actual.
func _action_end_turn(current_player: int, total_players: int) -> void:
	var next_player: int = (current_player + 1) % total_players
	set_global_variable("current_turn", next_player)
	trigger_event("OnTurnStarted", [next_player])
