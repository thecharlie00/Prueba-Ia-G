extends CanvasLayer
## Pantallas de carga entre escenas. Sustituye a get_tree().change_scene_to_file():
## tapa la pantalla con un dado que rueda, carga la escena nueva en un hilo aparte (la
## ventana no se congela) y no destapa hasta que la escena lleva unos fotogramas dibujándose,
## para que los estilos diferidos y la compilación de sombreadores queden ocultos.
##
## En headless (tests) y en la prueba de arranque cambia de escena directamente, como antes.
## Dentro de una sala online carga en el hilo principal para no perder mensajes de red
## mientras la mesa aún no existe, pero igualmente muestra la pantalla.

signal finished(path: String)

const FADE_IN := 0.15
const FADE_OUT := 0.3
## Fundido más lento de la entrada desde el título.
const PLAIN_FADE := 0.7
## Fotogramas que la escena nueva se dibuja bajo la pantalla antes de destaparla.
const HOLD_FRAMES := 5
## Tiempo mínimo con la pantalla entera a la vista (sin contar los fundidos): aunque la
## escena cargue al instante (los menús), la pantalla de carga se ve y el consejo se lee.
const MIN_VISIBLE := 1.1
const DISPLAY_FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const BODY_FONT := preload("res://assets/fonts/Nunito.ttf")
const TIPS := [
	"Pulsa Esc en cualquier mesa para abrir el menú.",
	"F1 muestra los controles de la mesa en la que estás.",
	"Ctrl+Z devuelve la última pieza que has movido.",
	"Puedes arrastrar el dado y soltarlo para tirarlo con física.",
	"En la habitación, muévete con WASD o haciendo clic en el suelo.",
	"Si el juego va lento, prueba la calidad gráfica Baja en Ajustes.",
	"En el taller puedes crear tus propios juegos de mesa.",
	"Jugar mesas te da fichas para decorar tu habitación.",
]

var busy := false
var _path := ""
var _plain := false
var _prefetched := {}
var _column: Control
var _root: Control
var _die: Control
var _bar_back: Panel
var _bar_fill: Panel
var _tip: Label
var _progress := 0.0
var _target := 0.0
var _time := 0.0
var _started_ms := 0
var _die_box := StyleBoxFlat.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	visible = false
	_build()


## Cambia a la escena `path` mostrando la pantalla de carga. Con `plain` solo funde a negro
## y vuelve a abrir sobre la escena nueva, sin dado ni consejo (entrada desde el título).
func go(path: String, plain := false) -> void:
	if busy:
		return
	if not _wants_screen():
		get_tree().change_scene_to_file(path)
		return
	busy = true
	_path = path
	_plain = plain
	await _show()
	var old := get_tree().current_scene
	if old != null:
		# La escena que se va deja de procesar: no responde a teclas y libera CPU para cargar.
		old.process_mode = Node.PROCESS_MODE_DISABLED
	var packed := await _load(path)
	if packed == null:
		push_error("SceneLoader: no se pudo cargar %s" % path)
		if is_instance_valid(old):
			old.process_mode = Node.PROCESS_MODE_INHERIT
		await _hide()
		busy = false
		return
	_target = 1.0
	await get_tree().process_frame
	get_tree().change_scene_to_packed(packed)
	await get_tree().scene_changed
	for i in HOLD_FRAMES:
		await get_tree().process_frame
	# El fundido a negro desde el título no es una pantalla de carga: no espera.
	while not _plain and (Time.get_ticks_msec() - _started_ms) / 1000.0 < MIN_VISIBLE:
		_target = 1.0
		await get_tree().process_frame
	await _hide()
	busy = false
	finished.emit(path)


## Vuelve a cargar la escena actual (reiniciar partida) con la pantalla de carga.
func reload() -> void:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path.is_empty():
		get_tree().reload_current_scene()
		return
	go(scene.scene_file_path)


## Empieza a cargar `path` en segundo plano para que el futuro go(path) sea inmediato.
func prefetch(path: String) -> void:
	if not _wants_screen() or _prefetched.has(path) or ResourceLoader.has_cached(path):
		return
	if ResourceLoader.load_threaded_request(path, "PackedScene") == OK:
		_prefetched[path] = true


func _wants_screen() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return not ("--prueba-arranque" in OS.get_cmdline_user_args())


## En una sala online la carga va en el hilo principal: mientras dura no se procesan
## mensajes de red, así que ninguno llega a una mesa que todavía no existe.
func _main_thread_only() -> bool:
	var net := get_node_or_null("/root/Net")
	if net == null or not net.has_method("is_singleplayer") or net.is_singleplayer():
		return false
	return FusionBridge.available() and FusionBridge.in_room()


func _load(path: String) -> PackedScene:
	var requested := _prefetched.has(path)
	_prefetched.erase(path)
	if not requested and (ResourceLoader.has_cached(path) or _main_thread_only()):
		_target = 0.7
		# Dos fotogramas para que la pantalla se vea entera antes del parón de la carga.
		await get_tree().process_frame
		await get_tree().process_frame
		return load(path) as PackedScene
	if not requested and ResourceLoader.load_threaded_request(path, "PackedScene") != OK:
		return load(path) as PackedScene
	var progress := []
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not progress.is_empty():
				_target = maxf(_target, float(progress[0]) * 0.9)
			await get_tree().process_frame
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			return ResourceLoader.load_threaded_get(path) as PackedScene
		else:
			return null
	return null


func _show() -> void:
	_progress = 0.0
	_target = 0.05
	_tip.text = str(TIPS.pick_random())
	_column.visible = not _plain
	visible = true
	if _reduce_motion():
		_root.modulate.a = 1.0
		await get_tree().process_frame
	else:
		_root.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_root, "modulate:a", 1.0, PLAIN_FADE if _plain else FADE_IN)
		await tween.finished
	_started_ms = Time.get_ticks_msec()


func _hide() -> void:
	if not _reduce_motion():
		var tween := create_tween()
		tween.tween_property(_root, "modulate:a", 0.0, PLAIN_FADE if _plain else FADE_OUT)
		await tween.finished
	visible = false


func _reduce_motion() -> bool:
	var toon := get_node_or_null("/root/ToonStyle")
	return toon != null and bool(toon.get("reduce_motion"))


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	# La barra avanza sola un poco aunque la carga no informe, para que nunca parezca parada.
	_target = minf(maxf(_target, _target + delta * 0.02), 1.0)
	_progress = move_toward(_progress, _target, delta * 1.0)
	_bar_fill.size = Vector2(maxf(_bar_back.size.x * _progress, _bar_back.size.y), _bar_back.size.y)
	_die.queue_redraw()


# --- Construcción ----------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "LoadingScreen"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var back := ColorRect.new()
	back.color = Palette.INK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(back)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)
	_column = column

	_die = Control.new()
	_die.name = "Die"
	_die.custom_minimum_size = Vector2(160, 150)
	_die.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_die.draw.connect(_draw_die)
	column.add_child(_die)

	var title := Label.new()
	title.name = "Title"
	title.text = "Cargando…"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", DISPLAY_FONT)
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Palette.PAPER)
	column.add_child(title)

	_bar_back = Panel.new()
	_bar_back.name = "Bar"
	_bar_back.custom_minimum_size = Vector2(320, 12)
	_bar_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_back.add_theme_stylebox_override("panel", _rounded(Palette.PANEL, 6))
	column.add_child(_bar_back)
	_bar_fill = Panel.new()
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_fill.add_theme_stylebox_override("panel", _rounded(Palette.SUN, 6))
	_bar_back.add_child(_bar_fill)

	_tip = Label.new()
	_tip.name = "Tip"
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(520, 0)
	_tip.add_theme_font_override("font", BODY_FONT)
	_tip.add_theme_font_size_override("font_size", 17)
	_tip.add_theme_color_override("font_color", Palette.LAVENDER)
	column.add_child(_tip)

	_die_box.bg_color = Palette.PAPER
	_die_box.set_corner_radius_all(14)
	_die_box.border_color = Palette.SUN
	_die_box.set_border_width_all(0)
	_die_box.border_width_bottom = 6


func _rounded(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box


## Un dado que da saltitos: en cada salto gira un cuarto de vuelta y cambia de cara.
func _draw_die() -> void:
	var still := _reduce_motion()
	var hops := 0.0 if still else _time * 1.5
	var phase := fmod(hops, 1.0)
	var lift := sin(phase * PI)
	var face := int(hops) % 6 + 1
	var center := _die.size * 0.5 + Vector2(0, 14)
	# Sombra en el suelo: se encoge cuando el dado está arriba.
	_die.draw_set_transform(center + Vector2(0, 46), 0.0, Vector2(1.0 - lift * 0.35, 0.22))
	_die.draw_circle(Vector2.ZERO, 38.0, Color(0, 0, 0, 0.3))
	var squash := 1.0 - (1.0 - lift) * 0.08 if not still else 1.0
	_die.draw_set_transform(center + Vector2(0, -lift * 34.0), phase * PI * 0.5, Vector2(2.0 - squash, squash))
	_die.draw_style_box(_die_box, Rect2(-34, -34, 68, 68))
	for pip in _pips(face):
		_die.draw_circle(pip * 18.0, 6.5, Palette.INK)
	_die.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _pips(face: int) -> Array[Vector2]:
	var c := Vector2.ZERO
	var tl := Vector2(-1, -1)
	var tr_ := Vector2(1, -1)
	var bl := Vector2(-1, 1)
	var br := Vector2(1, 1)
	match face:
		1:
			return [c]
		2:
			return [tl, br]
		3:
			return [tl, c, br]
		4:
			return [tl, tr_, bl, br]
		5:
			return [tl, tr_, c, bl, br]
	return [tl, tr_, Vector2(-1, 0), Vector2(1, 0), bl, br]
