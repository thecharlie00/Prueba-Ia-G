class_name TableTimeline
extends CanvasLayer
## Rebobinado de la mesa libre (fase 2): guarda una instantánea cada vez que la mesa queda
## quieta tras un cambio y permite volver a cualquiera desde una tira de momentos.
## Es la petición «deshacer de verdad» de los usuarios de TTS: elegir el punto exacto en vez
## de deshacer paso a paso. Usa el mismo formato validado que guardar y cargar.

const MAX_MOMENTS := 40
const CHECK_EVERY := 0.5

## Escena de la mesa libre (Main): aporta grabber, $Objects, $SnapGrid3D y apply_record().
var table: Node
## Cada momento: {"record": Dictionary, "time": msec, "signature": String}.
var moments: Array[Dictionary] = []

var _since_check := 0.0
## Hay que guardar un momento en cuanto la mesa se quede quieta: solo tras una acción del
## jugador (tecla o clic), no por el bamboleo de las fichas.
var _dirty := true
var _scroll: ScrollContainer
var _bar: PanelContainer
var _strip: HBoxContainer
var _title: Label


func _ready() -> void:
	name = "TableTimeline"
	layer = 5
	_build_bar()
	capture.call_deferred()


func _process(delta: float) -> void:
	_since_check += delta
	if _since_check < CHECK_EVERY:
		return
	_since_check = 0.0
	if _dirty and capture():
		_dirty = false
	if _bar.visible:
		_refresh_labels()


func _input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and not event.pressed):
		_dirty = true


## Guarda el estado actual si la mesa está quieta y ha cambiado. Devuelve true si guardó.
func capture() -> bool:
	if table == null or not _settled():
		return false
	var record: Dictionary = SandboxPersistence.snapshot(table.get_node("Objects"), table.get_node("SnapGrid3D").enabled)
	if record.is_empty():
		return false
	var signature := _signature(record)
	if not moments.is_empty() and moments.back()["signature"] == signature:
		return false
	moments.append({"record": record, "time": Time.get_ticks_msec(), "signature": signature})
	while moments.size() > MAX_MOMENTS:
		moments.pop_front()
	if _bar.visible:
		_rebuild_strip()
	return true


## Vuelve al momento index. Los momentos posteriores se conservan (se puede ir hacia
## delante otra vez) hasta que la mesa cambie.
func rewind_to(index: int) -> bool:
	if index < 0 or index >= moments.size():
		return false
	var grabber = table.get("grabber")
	if grabber != null and (is_instance_valid(grabber.held) or grabber._pending_press):
		return false
	if not table.apply_record(moments[index]["record"]):
		return false
	# El estado restaurado ya está en la lista: que la siguiente captura no lo duplique.
	var restored: Dictionary = moments[index]
	moments.remove_at(index)
	moments.append(restored)
	_rebuild_strip()
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.play("card")
	return true


func toggle() -> void:
	_bar.visible = not _bar.visible
	if _bar.visible:
		capture()
		_rebuild_strip()


func is_open() -> bool:
	return _bar.visible


func _settled() -> bool:
	var grabber = table.get("grabber")
	if grabber != null and (is_instance_valid(grabber.held) or grabber._pending_press):
		return false
	for child in table.get_node("Objects").get_children():
		var object := child as InteractiveTableObject
		if object == null:
			continue
		if object.is_grabbed or (object.freeze and not object.is_table_locked):
			return false
		# Tolerante con el bamboleo lento de fichas y monedas: la firma redondeada evita
		# momentos repetidos; solo se espera a que nada caiga o ruede deprisa.
		if not object.freeze and (object.linear_velocity.length() > 0.4 or object.angular_velocity.length() > 2.0):
			return false
	return true


# Firma con posiciones redondeadas: los temblores de la física no crean momentos nuevos.
func _signature(record: Dictionary) -> String:
	var parts: Array[String] = [str(record.get("snap", false))]
	for piece in record["objects"]:
		var p: Array = piece["position"]
		var q: Array = piece["rotation"]
		parts.append(
			"%s|%.1f,%.1f,%.1f|%.1f,%.1f,%.1f,%.1f|%s|%s"
			% [piece["name"], p[0], p[1], p[2], q[0], q[1], q[2], q[3], piece.get("locked", false), piece.get("cards", [])]
		)
	return ";".join(parts)


func _build_bar() -> void:
	_bar = PanelContainer.new()
	_bar.name = "RewindBar"
	_bar.visible = false
	_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bar.offset_left = -440
	_bar.offset_right = 440
	_bar.offset_top = -170
	_bar.offset_bottom = -78
	add_child(_bar)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_bar.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = Label.new()
	_title.text = "Rebobinar · elige un momento de la mesa"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 15)
	header.add_child(_title)
	var close := Button.new()
	close.name = "CloseRewind"
	close.text = "Cerrar"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(toggle)
	header.add_child(close)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 44)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 6)
	_scroll.add_child(_strip)


func _rebuild_strip() -> void:
	for child in _strip.get_children():
		_strip.remove_child(child)
		child.queue_free()
	for i in moments.size():
		var button := Button.new()
		button.name = "Moment%d" % i
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(rewind_to.bind(i))
		_strip.add_child(button)
	_refresh_labels()
	_show_latest.call_deferred()
	_title.text = "Rebobinar · %d momentos guardados · el último es la mesa actual" % moments.size()


func _refresh_labels() -> void:
	var now := Time.get_ticks_msec()
	for i in _strip.get_child_count():
		var button := _strip.get_child(i) as Button
		if i == moments.size() - 1:
			button.text = "Ahora"
			button.disabled = true
			continue
		var seconds := int((now - int(moments[i]["time"])) / 1000)
		button.text = "hace %d s" % seconds if seconds < 60 else "hace %d min" % (seconds / 60)
		button.tooltip_text = "Volver a la mesa de este momento"


# La tira empieza mostrando lo más reciente (a la derecha).
func _show_latest() -> void:
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_horizontal = int(_scroll.get_h_scroll_bar().max_value)
