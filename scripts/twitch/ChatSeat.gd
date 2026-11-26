class_name ChatSeat
extends Node
## El asiento del chat de Twitch en una mesa. La vista del juego le pide una votación con las
## jugadas legales; ChatSeat abre la votación, enseña el panel y los números sobre las piezas, y
## al cerrar devuelve la opción ganadora (o -1 si nadie votó: entonces juega el bot).

signal finished(winner: int)

const DISPLAY_FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const BODY_FONT := preload("res://assets/fonts/Nunito.ttf")
## Pausa antes de jugar sola una jugada que no tiene alternativa.
const SINGLE_DELAY := 1.2
## Tiempo que se ve la opción ganadora antes de aplicarla.
const RESULT_TIME := 1.1
const INTRO_TIME := 4.0

## Asiento (jugador) que controla el chat.
var seat := -1
var busy := false
var vote: VoteRound
## La última votación terminada (para leer su recuento al acabar).
var last_vote: VoteRound
var _on_done: Callable
var _targets: Array = []
var _labels: Array[Label3D] = []
var _layer: CanvasLayer
var _panel: PanelContainer
var _rows: VBoxContainer
var _title: Label
var _clock: ProgressBar
var _clock_label: Label
var _total: Label
var _recent: Label
var _intro: PanelContainer
var _result_left := 0.0
var _single_left := 0.0
var _intro_left := 0.0
var _intro_shown := false


func _init(controlled_seat: int = -1) -> void:
	seat = controlled_seat
	name = "ChatSeat"


func _ready() -> void:
	_build_panel()
	var twitch := _twitch()
	if twitch != null:
		twitch.chat_message.connect(_on_message)
		twitch.moderation.connect(_on_moderation)


static func _net() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("Net") if tree != null else null


## En una sala online: asiento donde juega el chat de este jugador, o -1.
static func online_seat() -> int:
	var net := _net()
	if net == null:
		return -1
	return int(net.call("chat_seat_of", int(net.call("local_seat"))))


## En una sala online: asientos del chat de otros streamers (los decide su ordenador).
static func remote_seats() -> Array[int]:
	var seats: Array[int] = []
	var net := _net()
	if net == null:
		return seats
	var mine := int(net.call("local_seat"))
	for seat in 4:
		var owner := int(net.call("chat_owner", seat))
		if owner >= 0 and owner != mine:
			seats.append(seat)
	return seats


## El asiento lo juega el chat de algún streamer de la sala.
static func is_room_chat(seat: int) -> bool:
	var net := _net()
	return net != null and int(net.call("chat_owner", seat)) >= 0


## Asientos de chat cuyo dueño es el jugador que se ha ido (para pasarlos a bot).
static func seats_of_owner(player_id: int) -> Array[int]:
	var seats: Array[int] = []
	var net := _net()
	if net == null:
		return seats
	for seat in 4:
		if int(net.call("chat_owner", seat)) == player_id - 1:
			seats.append(seat)
	return seats


func _twitch() -> Node:
	return get_node_or_null("/root/Twitch") if is_inside_tree() else null


func controls(player: int) -> bool:
	return seat >= 0 and player == seat


## Pide al chat que elija. `labels` son las opciones; `targets`, los nodos 3D sobre los que se
## ven los números (puede estar vacío). `on_done(winner)` recibe la opción o -1.
func ask(question: String, labels: Array[String], targets: Array, on_done: Callable) -> void:
	if busy:
		return
	busy = true
	_on_done = on_done
	if labels.size() <= 1:
		_single_left = SINGLE_DELAY
		return
	var twitch := _twitch()
	if twitch == null or not bool(twitch.call("is_available")):
		_finish(-1)
		return
	var seconds := float(twitch.get("vote_seconds")) if twitch != null else 20.0
	vote = VoteRound.new(labels, seconds)
	vote.tally_changed.connect(_refresh_panel)
	vote.closed.connect(_on_closed)
	vote.open()
	twitch.set("simulated_vote_options", labels.size())
	_targets = targets
	_show_labels()
	_title.text = question
	_panel.visible = true
	_refresh_panel()
	if not _intro_shown:
		_intro_shown = true
		_intro_left = INTRO_TIME
		_intro.visible = true


## Cancela la votación en curso sin aplicar nada (nueva partida, salir de la mesa…).
func cancel() -> void:
	busy = false
	vote = null
	_single_left = 0.0
	_result_left = 0.0
	_hide()


func _process(delta: float) -> void:
	if _intro_left > 0.0:
		_intro_left -= delta
		_intro.visible = _intro_left > 0.0
	if _single_left > 0.0:
		_single_left -= delta
		if _single_left <= 0.0:
			_finish(0)
		return
	if _result_left > 0.0:
		_result_left -= delta
		if _result_left <= 0.0:
			_finish(vote.winner if vote != null else -1)
		return
	if vote != null and vote.is_open:
		vote.tick(delta)
		if vote != null and vote.is_open:
			_update_clock()
	_place_labels()


func _on_message(message: Dictionary) -> void:
	var twitch := _twitch()
	if twitch != null and not bool(twitch.call("can_vote", message.get("badges", []))):
		return
	if vote != null and vote.is_open:
		if twitch != null and not bool(twitch.get("show_names")):
			message = message.duplicate()
			message["name"] = twitch.call("display_name", str(message.get("name", "")))
		vote.feed(message)


func _on_moderation(message_id: String, user_id: String) -> void:
	if vote != null and vote.is_open:
		vote.moderate(message_id, user_id)


func _on_closed(winner: int) -> void:
	var twitch := _twitch()
	if twitch != null:
		twitch.set("simulated_vote_options", 0)
	_refresh_panel()
	if winner < 0:
		_total.text = tr("Nadie ha votado: juega el bot")
	else:
		_total.text = tr("Gana la %d con %d votos") % [winner + 1, vote.counts()[winner]]
		var sfx := get_node_or_null("/root/Sfx")
		if sfx != null:
			sfx.call("play", "turn")
	_result_left = RESULT_TIME


func _finish(winner: int) -> void:
	busy = false
	_hide()
	var callback := _on_done
	_on_done = Callable()
	last_vote = vote
	vote = null
	finished.emit(winner)
	if callback.is_valid():
		callback.call(winner)


func _hide() -> void:
	if _panel != null:
		_panel.visible = false
	for label in _labels:
		label.queue_free()
	_labels.clear()
	_targets = []
	var twitch := _twitch()
	if twitch != null:
		twitch.set("simulated_vote_options", 0)


# --- Números sobre la mesa ----------------------------------------------------------

func _show_labels() -> void:
	for label in _labels:
		label.queue_free()
	_labels.clear()
	var parent := get_parent() as Node
	for i in _targets.size():
		var label := Label3D.new()
		label.text = str(i + 1)
		label.font = DISPLAY_FONT
		label.font_size = 96
		label.pixel_size = 0.0019
		label.outline_size = 28
		label.outline_modulate = Palette.INK
		label.modulate = Palette.SUN
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.render_priority = 10
		parent.add_child(label)
		_labels.append(label)
	_place_labels()


func _place_labels() -> void:
	var leading := vote.leader() if vote != null else -1
	for i in _labels.size():
		var target: Variant = _targets[i] if i < _targets.size() else null
		if target is Node3D and is_instance_valid(target):
			_labels[i].global_position = (target as Node3D).global_position + Vector3.UP * 0.16
			_labels[i].visible = true
		elif target is Vector3:
			_labels[i].global_position = (target as Vector3) + Vector3.UP * 0.16
			_labels[i].visible = true
		else:
			_labels[i].visible = false
		var pulse := 1.0 + (0.12 * sin(Time.get_ticks_msec() / 160.0) if i == leading else 0.0)
		_labels[i].scale = Vector3.ONE * pulse


# --- Panel de votación --------------------------------------------------------------

func _build_panel() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)

	_panel = PanelContainer.new()
	_panel.name = "ChatVotePanel"
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.offset_left = -320.0
	_panel.offset_right = -18.0
	_panel.offset_top = 160.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _box(Palette.PANEL, 18, 4))
	_panel.visible = false
	_layer.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	var eyebrow := _label("Turno del chat", BODY_FONT, 15, Palette.LAVENDER)
	titles.add_child(eyebrow)
	_title = _label("", DISPLAY_FONT, 24, Palette.PAPER)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(_title)
	_clock_label = _label("20", DISPLAY_FONT, 28, Palette.SUN)
	_clock_label.custom_minimum_size = Vector2(44, 0)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_clock_label)

	_clock = ProgressBar.new()
	_clock.show_percentage = false
	_clock.custom_minimum_size = Vector2(0, 8)
	_clock.add_theme_stylebox_override("background", _box(Palette.INK, 4, 0))
	_clock.add_theme_stylebox_override("fill", _box(Palette.SUN, 4, 0))
	column.add_child(_clock)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	column.add_child(_rows)

	_total = _label("", BODY_FONT, 17, Palette.PAPER)
	_total.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_total)
	_recent = _label("", BODY_FONT, 14, Palette.LAVENDER)
	column.add_child(_recent)

	_intro = PanelContainer.new()
	_intro.name = "ChatIntro"
	_intro.anchor_left = 0.5
	_intro.anchor_right = 0.5
	_intro.anchor_top = 0.0
	_intro.offset_left = -330.0
	_intro.offset_right = 330.0
	_intro.offset_top = 96.0
	_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.add_theme_stylebox_override("panel", _box(Palette.SUN, 18, 4))
	_intro.visible = false
	_layer.add_child(_intro)
	var intro_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		intro_margin.add_theme_constant_override("margin_" + side, 14)
	_intro.add_child(intro_margin)
	var intro_text := _label("¡Chat, os toca! Escribid !1, !2… en el chat para votar la jugada", DISPLAY_FONT, 26, Palette.INK)
	intro_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_margin.add_child(intro_text)


func _refresh_panel() -> void:
	if vote == null:
		return
	for child in _rows.get_children():
		child.queue_free()
	var tally := vote.counts()
	var total := maxi(vote.total(), 1)
	var leading := vote.leader()
	for i in vote.options.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var number := _label(str(i + 1), DISPLAY_FONT, 34, Palette.SUN if i == leading else Palette.PAPER)
		number.custom_minimum_size = Vector2(30, 0)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(number)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 2)
		var line := HBoxContainer.new()
		var text := _label(vote.options[i], BODY_FONT, 16, Palette.PAPER)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.clip_text = true
		line.add_child(text)
		var pct := int(round(100.0 * tally[i] / total)) if vote.total() > 0 else 0
		line.add_child(_label("%d %%" % pct, BODY_FONT, 15, Palette.LAVENDER))
		info.add_child(line)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 12)
		bar.max_value = 100
		bar.value = pct
		bar.add_theme_stylebox_override("background", _box(Palette.INK, 6, 0))
		bar.add_theme_stylebox_override("fill", _box(Palette.SUN if i == leading else Palette.LAVENDER, 6, 0))
		info.add_child(bar)
		row.add_child(info)
		_rows.add_child(row)
	if vote.is_open:
		var hint := "!1" if vote.options.size() < 2 else "!1 … !%d" % vote.options.size()
		_total.text = tr("%d votos · escribe %s") % [vote.total(), hint]
	var lines: Array[String] = []
	for entry in vote.recent.slice(maxi(vote.recent.size() - 2, 0)):
		lines.append(entry)
	_recent.text = "\n".join(lines)
	_update_clock()


func _update_clock() -> void:
	if vote == null:
		return
	_clock.max_value = vote.seconds
	_clock.value = vote.remaining
	_clock_label.text = str(ceili(vote.remaining))


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _box(color: Color, radius: int, border: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.set_border_width_all(border)
	box.border_color = Palette.INK
	if border > 0:
		box.shadow_color = Palette.INK
		box.shadow_size = 1
		box.shadow_offset = Vector2(5, 5)
	return box
