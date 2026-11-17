extends SceneTree
## FASE 7 — Mejoras al diseñador de interfaz.
## Prueba: selección múltiple, alineación, distribución, copiar/pegar,
## duplicar, grupos, y validación de elementos.

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# No necesitamos cargar el editor para probar UiLayout.
	var layout := UiLayout.new()

	# 1. Añadir varios elementos.
	var e1 := layout.add("text")
	var e2 := layout.add("button")
	var e3 := layout.add("panel")
	var e4 := layout.add("counter")
	_check(e1.has("id") and e1["id"] == 1, "primer elemento tiene id 1")
	_check(e2["id"] == 2, "segundo elemento tiene id 2")
	_check(e3["id"] == 3, "tercer elemento tiene id 3")
	_check(e4["id"] == 4, "cuarto elemento tiene id 4")

	# 2. Selección múltiple.
	layout.select(1, false)
	_check(layout.get_selected() == [1], "selección simple: [1]")
	layout.select(2, true)
	_check(layout.get_selected() == [1, 2], "selección múltiple con Ctrl: [1, 2]")
	layout.select(1, true)  # quitar 1
	_check(layout.get_selected() == [2], "quitar con Ctrl: [2]")

	# 3. Alineación izquierda (necesita al menos 2 elementos).
	layout.select(1, false)
	layout.select(3, true)  # seleccionar 1 y 3
	var n := layout.align_selected(UiLayout.ALIGN_LEFT)
	_check(n >= 0, "align_selected左 devuelve %d" % n)

	# 4. Alineación centro X.
	layout.select(1, false)
	layout.select(2, true)
	n = layout.align_selected(UiLayout.ALIGN_CENTER_X)
	_check(n >= 0, "align_selected centro X devuelve %d" % n)

	# 5. Distribución horizontal (necesita al menos 3).
	layout.select(1, false)
	layout.select(2, true)
	layout.select(3, true)
	n = layout.distribute_selected(UiLayout.DISTRIBUTE_HORIZONTAL)
	_check(n >= 0, "distribute_selected horizontal devuelve %d" % n)

	# 6. Duplicar un elemento.
	var dupes := layout.duplicate(1)
	_check(dupes.size() == 1, "duplicar devuelve 1 ID")
	var dup := layout.find(dupes[0])
	_check(not dup.is_empty(), "elemento duplicado existe")
	_check(dup["name"] == "Texto 1 copia", "nombre del duplicado tiene 'copia'")
	_check(int(dup["target"]) == 0, "target del duplicado se limpia si apuntaba al original")

	# 7. Copiar y pegar.
	layout.select(1, false)
	layout.select(2, true)
	var clipboard := layout.copy_selected()
	_check(clipboard.size() == 2, "portapapeles tiene 2 elementos")
	var pasted := layout.paste(clipboard)
	_check(pasted.size() == 2, "pegar devuelve 2 IDs")
	_check(layout.get_selected() == pasted, "selección es lo pegado")

	# 8. Agrupar.
	layout.select(1, false)
	layout.select(3, true)
	var gid := layout.group_selected()
	_check(gid > 0, "grupo creado con id %d" % gid)
	_check(layout.group_of(1) == gid, "elemento 1 pertenece al grupo %d" % gid)
	_check(layout.group_of(3) == gid, "elemento 3 pertenece al grupo %d" % gid)
	var members := layout.group_members(1)
	_check(members.size() == 2, "grupo tiene 2 miembros")
	layout.ungroup_selected()
	_check(layout.group_of(1) == 0, "desagrupar elimina grupo de elemento 1")

	# 9. Validación: no más de MAX_ELEMENTOS.
	for i in range(layout.elements.size(), UiLayout.MAX_ELEMENTS):
		layout.add("text")
	_check(layout.elements.size() >= UiLayout.MAX_ELEMENTS, "se llegó al máximo de elementos")
	var extra := layout.add("text")
	_check(extra.is_empty(), "no se pueden añadir más de %d elementos" % UiLayout.MAX_ELEMENTS)

	# 10. Validación: from_record rechaza versión inválida.
	var bad := {"kind": "tablerama_ui", "version": 99, "elements": []}
	var loaded := UiLayout.from_record(bad)
	_check(loaded == null, "from_record rechaza versión no soportada")

	# 11. Validación: from_record acepta versión 2 con grupos.
	var good := {
		"kind": "tablerama_ui",
		"version": 2,
		"elements": [
			{"id": 1, "type": "text", "name": "Hola", "pos": [100, 100], "size": [200, 50],
			 "anchor": 4, "text": "Hola", "font_size": 20, "color": "fff8ec", "bg": "",
			 "image": "", "value": 0, "action": "none", "target": 0},
			{"id": 2, "type": "button", "name": "Boton", "pos": [100, 200], "size": [150, 40],
			 "anchor": 4, "text": "Pulsa", "font_size": 18, "color": "1d1a3a", "bg": "ffc83d",
			 "image": "", "value": 0, "action": "none", "target": 0},
		],
		"groups": {"1": [1, 2]},
	}
	loaded = UiLayout.from_record(good)
	_check(loaded != null, "from_record acepta versión 2 con grupos")
	_check(loaded.group_of(1) == 1, "grupo restaurado: elemento 1 en grupo 1")
	_check(loaded.group_of(2) == 1, "grupo restaurado: elemento 2 en grupo 1")

	if _failed:
		quit(1)
	else:
		print("editor_ui_diseno: ok")
		quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("FALLO: " + message)
