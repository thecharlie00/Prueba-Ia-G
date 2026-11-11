# GameCreatorCore.gd
# Orquestador principal del estado de edición y ejecución en caliente.
# Gestiona el ciclo Build <-> Playtest, el motor de reglas y la carga de mods.
# Debe registrarse como Autoload en project.godot para estar accesible globalmente.
extends Node

enum EditorState { BUILD, PLAYTEST }

# Estado actual del editor.
@export var current_state: EditorState = EditorState.BUILD

# Instancias del motor de reglas y exportador de mods (asignadas por nodos hijos).
var rule_engine: RuleEngine = null
var mod_exporter: ModBundleExporter = null

# ID del mod activo (si se está editando un mod cargado).
var active_mod_id: String = ""

# Señales.
signal state_changed(new_state: EditorState)
signal mod_loaded(mod_id: String)
signal mod_unloaded()

func _ready() -> void:
	# Buscar el motor de reglas y exportador en el árbol si existen.
	rule_engine = get_node_or_null("%RuleEngine")
	mod_exporter = get_node_or_null("%ModBundleExporter")

# Entra en modo Edición (Build).
func enter_build_mode() -> void:
	current_state = EditorState.BUILD
	get_tree().paused = true
	if rule_engine != null:
		rule_engine.stop()
	state_changed.emit(EditorState.BUILD)
	print("[GameCreatorCore] Modo Edición activado")

# Entra en modo Prueba (Playtest) con hot-reload.
func enter_playtest_mode() -> void:
	current_state = EditorState.PLAYTEST
	get_tree().paused = false
	if rule_engine != null:
		rule_engine.start()
	state_changed.emit(EditorState.PLAYTEST)
	print("[GameCreatorCore] Modo Prueba activado")

# Alterna entre Build y Playtest.
func toggle_mode() -> void:
	if current_state == EditorState.BUILD:
		enter_playtest_mode()
	else:
		enter_build_mode()

# Carga un mod por su ID (descarga y monta la escena).
func load_mod(mod_id: String) -> void:
	if mod_exporter == null:
		push_error("[GameCreatorCore] ModBundleExporter no disponible")
		return
	var result: Dictionary = mod_exporter.download_and_extract(mod_id)
	if not result.has("success") or not result["success"]:
		push_error("[GameCreatorCore] No se pudo cargar el mod: ", mod_id)
		return
	active_mod_id = mod_id
	var scene_path: String = result.get("scene_path", "")
	if scene_path != "":
		var scene: PackedScene = load(scene_path)
		if scene != null:
			var instance: Node = scene.instantiate()
			add_child(instance)
	mod_loaded.emit(mod_id)
	print("[GameCreatorCore] Mod cargado: ", mod_id)

# Descarga el mod activo y vuelve a edición vacía.
func unload_mod() -> void:
	if active_mod_id != "":
		# Remover hijos del mod (excepto nodos del editor core).
		for child in get_children():
			if child is PropEntity:
				child.queue_free()
		active_mod_id = ""
		mod_unloaded.emit()
		print("[GameCreatorCore] Mod descargado")
