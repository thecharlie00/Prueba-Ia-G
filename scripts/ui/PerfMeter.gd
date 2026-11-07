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


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
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


## Los sistemas del juego avisan de lo que acaba de pasar para cruzarlo con los tirones.
func note(event: String) -> void:
	_last_event = event
	_last_event_at = Time.get_ticks_msec()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_panel.visible = not _panel.visible
		# Medir el tiempo de render solo con el medidor abierto: así no añade coste al jugar.
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), _panel.visible)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if Engine.get_process_frames() > 30:
		record_frame(delta * 1000.0)
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
			"process": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"physics": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"render_cpu": RenderingServer.viewport_get_measured_render_time_cpu(rid)
			+ RenderingServer.get_frame_setup_time_cpu(),
			"render_gpu": RenderingServer.viewport_get_measured_render_time_gpu(rid),
			"event": _last_event if since < 1500 else "",
			"since": since,
			"time": Time.get_ticks_msec(),
		})
		while spikes.size() > KEEP:
			spikes.pop_front()


func _refresh() -> void:
	var lines: Array[String] = [
		"%d FPS · tirones de más de %d ms (F3 oculta)" % [Engine.get_frames_per_second(), SPIKE_MS]
	]
	if spikes.is_empty():
		lines.append("Ninguno todavía.")
	for spike in spikes:
		var cause := ""
		if not String(spike["event"]).is_empty():
			cause = " · %d ms después de «%s»" % [spike["since"], spike["event"]]
		lines.append(
			"%.0f ms: scripts %.0f · física %.0f · render CPU %.0f · GPU %.0f%s"
			% [spike["frame"], spike["process"], spike["physics"], spike["render_cpu"], spike["render_gpu"], cause]
		)
	_text.text = "\n".join(lines)
