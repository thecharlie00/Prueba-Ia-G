extends CanvasLayer
## Medidor de rendimiento (F3). Muestra FPS y apunta cada tirón (fotograma lento) con el
## reparto de tiempo: scripts, física, render en CPU y en GPU, y el último suceso del juego
## (por ejemplo, «dado: resultado»). Sirve para localizar tirones que solo pasan en algunos
## equipos.

const SPIKE_MS := 50.0
const KEEP := 6

var spikes: Array[Dictionary] = []
var _panel: PanelContainer
var _text: Label
var _last_event := ""
var _last_event_at := 0
var _since_refresh := 0.0
# Medición propia, fotograma a fotograma y con reloj real (el delta del motor se suaviza y no
# refleja los parones): inicio y fin de los _process y de los _physics_process.
var _frame_start := 0
var _process_ms := 0.0
var _physics_ms := 0.0
var _physics_start := 0
var _last_physics_ms := 0.0
var _last_process_ms := 0.0
var _last_event_cost := ""
## Prueba A/B del tirón del dado (F4 con el medidor abierto): qué partes del resultado se
## desactivan para ver cuál provoca el parón en un equipo concreto.
const DICE_MODES := ["normal", "sin número", "sin sonido", "sin número ni sonido", "sin aviso a la mesa"]
var dice_mode := 0


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100000
	process_physics_priority = -100000
	var tail := _Tail.new()
	tail.meter = self
	add_child(tail)
	_panel = PanelContainer.new()
	_panel.name = "PerfPanel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_panel.offset_left = 12
	_panel.offset_top = 12
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.INK, 0.88)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(10)
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 13)
	_text.add_theme_color_override("font_color", Palette.PAPER)
	_panel.add_child(_text)
	_panel.visible = false


## Qué partes del resultado del dado están activas en la prueba A/B.
func dice_part_enabled(part: String) -> bool:
	match part:
		"pop":
			return dice_mode != 1 and dice_mode != 3
		"sound":
			return dice_mode != 2 and dice_mode != 3
		"signal":
			return dice_mode != 4
	return true


## Los sistemas del juego avisan de lo que acaba de pasar para cruzarlo con los tirones.
func note(event: String, cost := "") -> void:
	_last_event = event
	_last_event_cost = cost
	_last_event_at = Time.get_ticks_msec()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4 and _panel.visible:
		dice_mode = (dice_mode + 1) % DICE_MODES.size()
		spikes.clear()
		_refresh()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_panel.visible = not _panel.visible
		# Medir el tiempo de render solo con el medidor abierto: así no añade coste al jugar.
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), _panel.visible)
		get_viewport().set_input_as_handled()


## Nodo que corre el último en cada fotograma para cerrar las mediciones.
class _Tail:
	extends Node
	var meter: Node

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_priority = 100000
		process_physics_priority = 100000

	func _process(_delta: float) -> void:
		meter._process_ms = (Time.get_ticks_usec() - meter._frame_start) / 1000.0

	func _physics_process(_delta: float) -> void:
		meter._physics_ms += (Time.get_ticks_usec() - meter._physics_start) / 1000.0


func _physics_process(_delta: float) -> void:
	_physics_start = Time.get_ticks_usec()


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var wall := (now - _frame_start) / 1000.0 if _frame_start > 0 else delta * 1000.0
	# Lo medido en el fotograma que acaba de terminar.
	_last_process_ms = _process_ms
	_last_physics_ms = _physics_ms
	_physics_ms = 0.0
	_frame_start = now
	if Engine.get_process_frames() > 30:
		record_frame(wall)
	_since_refresh += delta
	if _panel.visible and _since_refresh > 0.25:
		_since_refresh = 0.0
		_refresh()


## Apunta el fotograma si es un tirón (público para los tests).
func record_frame(frame_ms: float) -> void:
	if frame_ms >= SPIKE_MS:
		var rid := get_viewport().get_viewport_rid()
		var since := Time.get_ticks_msec() - _last_event_at
		spikes.append({
			"frame": frame_ms,
			"process": _last_process_ms,
			"physics": _last_physics_ms,
			"render_cpu": RenderingServer.viewport_get_measured_render_time_cpu(rid)
			+ RenderingServer.get_frame_setup_time_cpu(),
			"render_gpu": RenderingServer.viewport_get_measured_render_time_gpu(rid),
			"event": (_last_event + _last_event_cost) if since < 1500 else "",
			"since": since,
			"time": Time.get_ticks_msec(),
		})
		while spikes.size() > KEEP:
			spikes.pop_front()


func _refresh() -> void:
	var lines: Array[String] = [
		"%d FPS · tirones de más de %d ms (F3 oculta) · prueba del dado: %s (F4 cambia)"
		% [Engine.get_frames_per_second(), SPIKE_MS, DICE_MODES[dice_mode]]
	]
	if spikes.is_empty():
		lines.append("Ninguno todavía.")
	for spike in spikes:
		var cause := ""
		if not String(spike["event"]).is_empty():
			cause = " · %d ms después de «%s»" % [spike["since"], spike["event"]]
		var other := maxf(0.0, spike["frame"] - spike["process"] - spike["physics"])
		lines.append(
			"%.0f ms: scripts %.0f · física %.0f · resto (render, avisos, sistema) %.0f · GPU %.0f%s"
			% [spike["frame"], spike["process"], spike["physics"], other, spike["render_gpu"], cause]
		)
	_text.text = "\n".join(lines)
