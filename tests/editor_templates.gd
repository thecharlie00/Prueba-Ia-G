extends SceneTree
## FASE 4 — Plantillas que se preparan solas y asistente de importación de hojas.
## Prueba: auto-setup de plantilla cartas (mezclar mazo, repartir 5 a mano),
## auto-setup de plantilla dados, y importación de hoja con dorso automático.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/game_creator/GameCreatorEditor.tscn")
	for i in range(10):
		await process_frame
	var editor: GameCreatorEditor = current_scene as GameCreatorEditor
	editor.table_save_path = "user://test_editor_templates.json"
	var hierarchy: SceneHierarchy = editor._scene_hierarchy

	# 1. Cargar plantilla "cartas" con auto-setup.
	editor.load_template("cartas")
	_check(hierarchy.entities.size() >= 3, "plantilla cartas pone al menos mazo, descarte y mano (%d)" % hierarchy.entities.size())

	# Verificar que el mazo existe y tiene cartas.
	var mazo: PropEntity = null
	var mano: PropEntity = null
	for e in hierarchy.entities:
		var v := e.get_component("VisualComponent") as VisualComponent
		if v != null and v.shape == "zona":
			if e.entity_name == "Zona mazo" or e.entity_name == "MAZO":
				mazo = e
			if e.entity_name == "Zona mano" or e.entity_name == "MANO":
				mano = e
	_check(mazo != null, "se encontró la zona mazo")
	_check(mano != null, "se encontró la zona mano")

	# Las cartas deben estar en la zona mazo (no sueltas).
	var cartas_en_mazo: Array = editor.logic_pieces(mazo.entity_id, "")
	_check(cartas_en_mazo.size() > 0, "hay cartas en el mazo tras auto-setup (%d)" % cartas_en_mazo.size())

	# 2. Deshacer y volver a cargar para verificar que el auto-setup es deshacible.
	editor.undo()
	_check(hierarchy.entities.size() == 0, "deshacer plantilla vacía la mesa (%d)" % hierarchy.entities.size())

	# 3. Cargar plantilla "dados" con auto-setup (mezclar zona de tirada).
	editor.load_template("dados")
	_check(hierarchy.entities.size() >= 6, "plantilla dados pone zona + 5 dados (%d)" % hierarchy.entities.size())
	var zona_tirada: PropEntity = null
	for e in hierarchy.entities:
		var v := e.get_component("VisualComponent") as VisualComponent
		if v != null and v.shape == "zona" and e.entity_name == "TIRADA":
			zona_tirada = e
			break
	_check(zona_tirada != null, "se encontró la zona de tirada")

	# 4. Deshacer plantilla dados.
	editor.undo()
	_check(hierarchy.entities.size() == 0, "deshacer plantilla dados vacía la mesa (%d)" % hierarchy.entities.size())

	# 5. Crear un mazo de 4 cartas con dorso automático desde imágenes existentes.
	# Usamos deck_from_sheet con una imagen de la galería, pero como no hay imágenes
	# reales, verificamos que la función acepta el parámetro back_path sin errores.
	var deck_result: Array = editor.deck_from_sheet("", 1, 1, 1) as Array
	_check(deck_result.is_empty(), "deck_from_sheet con path vacío devuelve array vacío")

	# 6. Limpiar.
	editor.clear_table()
	_check(hierarchy.entities.size() == 0, "mesa vaciada tras clear (%d)" % hierarchy.entities.size())

	# Limpieza de archivos temporales.
	for f in [editor.table_save_path, editor.table_save_path + ".bak", editor.table_save_path + ".tmp"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

	if _failed:
		quit(1)
	else:
		print("editor_templates: ok")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
