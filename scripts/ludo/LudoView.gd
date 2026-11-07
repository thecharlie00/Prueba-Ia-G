class_name LudoView
extends Node3D

const CONFIRM_ACTION := preload("res://scripts/ui/ConfirmAction.gd")

const SAVE_STORE := preload("res://scripts/persistence/SaveStore.gd")
const SAVE_CODECS := preload("res://scripts/persistence/SaveCodecs.gd")

const TOKEN := preload("res://scenes/Token3D.tscn")
const DICE := preload("res://scenes/Dice3D.tscn")
# Rojo, azul, amarillo y verde de la paleta (docs/ARTE.md); los textos usan estos nombres.
const COLORS := [Palette.PLAYER_RED, Palette.PLAYER_BLUE, Palette.PLAYER_YELLOW, Palette.PLAYER_GREEN]
const NAMES := ["rojo", "azul", "amarillo", "verde"]
const CENTER := Vector3(-0.62, 0.83, 0)
const TRACK_RADIUS := 1.37
const MAX_SAVE_BYTES := 500000

@export_range(2, 4) var player_count := 2
## "ludo" o "parchis" (LudoRules): mismo tablero, reglas del parchís español.
@export var variant := "ludo"
@export var save_path := "user://diceon_ludo.json"
var confirm_action: ConfirmAction
var rules: LudoRules
var die: Dice3D
var tokens: Array = []
var markers: Array[MeshInstance3D] = []
var in_transit: Dictionary = {}
var waiting_roll := false
var stable_time := 0.0
var stuck_time := 0.0
var nudges := 0
var status: Label
var help: Label
var roll_button: Button
var reset_button: Button
var token_buttons: Array[Button] = []
var new_game_confirmation: ConfirmationDialog
## Jugadores que lleva un bot (TableBots); el resto juega en el mismo equipo.
var bots: Array[bool] = [false, false, false, false]
var bot_toggles: Array[CheckBox] = []
var _bot_wait := 0.0

@onready var objects: Node3D = $Objects
@onready var grabber: PhysicsGrabber3D = $PhysicsGrabber3D
@onready var camera: Camera3D = $CameraRig/Camera3D


func _ready() -> void:
	confirm_action = CONFIRM_ACTION.new()
	add_child(confirm_action)
	rules = LudoRules.new(player_count, variant)
	_make_board()
	_make_tokens()
	_make_tray()
	_make_ui()
	_make_seats()
	grabber.dice_shortcuts_enabled = false
	grabber.grab_finished.connect(_on_release)
	_refresh()


## Jugadores sentados junto a su casa, con lo que llevan a la meta encima.
var seats: TableSeats


func _make_seats() -> void:
	var list := []
	for player in range(rules.players):
		var home := Vector3.ZERO
		for token in range(4):
			home += _yard_position(player, token) * 0.25
		var outward := Vector3(home.x - CENTER.x, 0, home.z - CENTER.z).normalized()
		var spot := Vector3(CENTER.x, -0.15, CENTER.z) + outward * 3.3
		list.append(
			{
				"name": "Jugador %d" % (player + 1),
				"color": COLORS[player],
				"bot": false,
				"position": spot,
				"look_at": Vector3(CENTER.x, -0.15, CENTER.z),
			}
		)
	seats = TableSeats.new()
	seats.name = "TableSeats"
	add_child(seats)
	seats.setup(list)
	seats.center = CENTER
	_update_seats()


func _update_seats() -> void:
	if seats == null:
		return
	seats.set_active(rules.turn if rules.phase != LudoRules.FINISHED else rules.winner)
	for player in range(rules.players):
		var done := 0
		var waiting := 0
		for progress in rules.positions[player]:
			if progress == LudoRules.FINISH:
				done += 1
			elif progress == LudoRules.YARD:
				waiting += 1
		seats.set_status(
			player, "%sMeta %d/4 · casa %d" % ["Bot · " if bots[player] else "", done, waiting]
		)


func _make_board() -> void:
	var shape := $Board/CollisionShape3D.shape.duplicate() as BoxShape3D
	shape.size = Vector3(4.9, 0.03, 4.25)
	$Board/CollisionShape3D.shape = shape
	$Board/CollisionShape3D.position.x = CENTER.x
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = shape.size
	base.mesh = base_mesh
	base.position = Vector3(CENTER.x, 0.815, 0)
	base.material_override = BoardGeometry3D.make_material(Color("374d3b"))
	$Board/Tiles.add_child(base)
	for square in range(52):
		var color := Color("d8d2b4")
		if square in LudoRules.SAFE:
			color = COLORS[(square / 13) % 4].lightened(0.2)
		_disc(_track_position(square), 0.071, color)
	for player in range(4):
		for progress in range(52, 57):
			_disc(_lane_position(player, progress), 0.073, COLORS[player].darkened(0.12))
		for token in range(4):
			_disc(_yard_position(player, token), 0.10, COLORS[player].darkened(0.25))
			_disc(_finished_position(player, token), 0.10, COLORS[player].lightened(0.35))
		var marker := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.10
		mesh.bottom_radius = 0.10
		mesh.height = 0.012
		marker.mesh = mesh
		marker.material_override = BoardGeometry3D.make_material(Color("9efa9a"))
		$Board/Tiles.add_child(marker)
		marker.visible = false
		markers.append(marker)


func _disc(position: Vector3, radius: float, color: Color) -> void:
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.014
	visual.mesh = mesh
	visual.position = position + Vector3.UP * 0.01
	visual.material_override = BoardGeometry3D.make_material(color)
	$Board/Tiles.add_child(visual)


func _track_position(square: int) -> Vector3:
	var angle := TAU * float(square) / 52.0 - PI / 2.0
	return CENTER + Vector3(cos(angle) * TRACK_RADIUS, 0, sin(angle) * TRACK_RADIUS)


func _lane_position(player: int, progress: int) -> Vector3:
	var angle := TAU * float(player * 13 - 1) / 52.0 - PI / 2.0
	var radius := 1.14 - float(progress - 52) * 0.19
	return CENTER + Vector3(cos(angle) * radius, 0, sin(angle) * radius)


func _yard_position(player: int, token: int) -> Vector3:
	var angle := TAU * float(player) / 4.0 - PI / 2.0
	var base := CENTER + Vector3(cos(angle) * 1.79, 0, sin(angle) * 1.79)
	return base + Vector3((token % 2 - 0.5) * 0.19, 0, (token / 2 - 0.5) * 0.19)


func _finished_position(player: int, token: int) -> Vector3:
	var angle := TAU * float(player) / 4.0 - PI / 2.0
	return _yard_position(player, token) + Vector3(-sin(angle), 0, cos(angle)) * 0.45


func _token_position(player: int, token: int, progress: int) -> Vector3:
	if progress == LudoRules.YARD:
		return _yard_position(player, token)
	if progress == LudoRules.FINISH:
		return _finished_position(player, token)
	if progress >= 52:
		return _lane_position(player, progress) + _share_offset(player, token, progress)
	return _track_position(LudoRules.track_square(player, progress)) + _share_offset(player, token, progress)


# Parchís: dos fichas en la misma casilla (barrera o seguro compartido) se ponen una al lado
# de la otra, en el sentido del recorrido, para que no se monten.
func _share_offset(player: int, token: int, progress: int) -> Vector3:
	if rules == null or not rules.is_parchis():
		return Vector3.ZERO
	var mates: Array[Vector2i] = []
	if progress < 52:
		mates = rules.tokens_on(LudoRules.track_square(player, progress))
	else:
		for other in range(4):
			if rules.positions[player][other] == progress:
				mates.append(Vector2i(player, other))
	if not Vector2i(player, token) in mates:
		mates.append(Vector2i(player, token))
	if mates.size() < 2:
		return Vector3.ZERO
	mates.sort()
	var side := -1.0 if mates.find(Vector2i(player, token)) == 0 else 1.0
	var here := _track_position(LudoRules.track_square(player, progress)) if progress < 52 else _lane_position(player, progress)
	var outward := Vector3(here.x - CENTER.x, 0, here.z - CENTER.z).normalized()
	var along := Vector3(-outward.z, 0, outward.x)
	return along * side * 0.075


func _make_tokens() -> void:
	for player in range(4):
		var pieces: Array[Token3D] = []
		for index in range(4):
			var token := TOKEN.instantiate() as Token3D
			token.piece_color = COLORS[player]
			token.display_name = "J%d · ficha %d" % [player + 1, index + 1]
			token.position = _yard_position(player, index) + Vector3.UP * 0.1
			token.mass = 0.05
			(token.get_node("Visual") as MeshInstance3D).scale = Vector3.ONE * 0.4
			var collision := token.get_node("CollisionShape3D") as CollisionShape3D
			var shape := collision.shape.duplicate() as CylinderShape3D
			shape.radius = 0.08
			shape.height = 0.048
			collision.shape = shape
			objects.add_child(token)
			var label := Label3D.new()
			label.text = str(index + 1)
			label.font_size = 52
			label.pixel_size = 0.002
			label.rotation_degrees.x = -90
			label.position.y = 0.038
			label.modulate = Color("13291f")
			token.add_child(label)
			pieces.append(token)
		tokens.append(pieces)
	_update_token_activity()


func _update_token_activity() -> void:
	for player in range(4):
		for token: Token3D in tokens[player]:
			token.visible = player < rules.players
			token.freeze = player >= rules.players
			token.collision_layer = 2 if player < rules.players else 0
			token.collision_mask = 3 if player < rules.players else 0


func _make_tray() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	add_child(body)
	for pair in [
		[Vector3(1.98, 1.15, 0), Vector3(0.08, 0.7, 2.0)],
		[Vector3(3.34, 1.15, 0), Vector3(0.08, 0.7, 2.0)],
		[Vector3(2.66, 1.15, -1.0), Vector3(1.44, 0.7, 0.08)],
		[Vector3(2.66, 1.15, 1.0), Vector3(1.44, 0.7, 0.08)]
	]:
		var shape := BoxShape3D.new()
		shape.size = pair[1]
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = pair[0]
		body.add_child(collision)
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = pair[1]
		visual.mesh = mesh
		visual.position = pair[0]
		visual.material_override = BoardGeometry3D.make_material(Color("50796b"))
		body.add_child(visual)
	die = DICE.instantiate() as Dice3D
	die.position = Vector3(2.66, 1.2, 0)
	die.collision_mask |= 4
	die.display_name = "Dado físico · R"
	objects.add_child(die)


func _make_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LudoUI"
	add_child(layer)
	var panel := PanelContainer.new()
	panel.offset_left = 18
	panel.offset_top = 18
	panel.offset_right = 330
	panel.anchor_bottom = 1.0
	panel.offset_bottom = -18
	var theme := GameThemes.theme_for(self)
	var style := GameThemes.panel_box(theme)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	header.add_child(GameThemes.emblem(theme, 36.0))
	var title := _label(header, "PARCHÍS · MESA LOCAL" if rules.is_parchis() else "LUDO · MESA LOCAL")
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", theme["accent"].lightened(0.2))
	status = _label(column, "")
	help = _label(column, "")
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roll_button = _button(column, "Lanzar dado · R", _roll)
	GameThemes.style_button(roll_button, theme)
	reset_button = _button(column, "Recolocar dado", _reset_die)
	_label(column, "Elige una ficha o arrástrala a su marca verde:")
	var row := HBoxContainer.new()
	column.add_child(row)
	for index in range(4):
		var button := _button(row, "%d" % (index + 1), _choose_token.bind(index))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		token_buttons.append(button)
	_label(column, "Jugadores que lleva un bot:")
	var bot_row := HBoxContainer.new()
	bot_row.name = "BotRow"
	column.add_child(bot_row)
	for player in range(rules.players):
		var toggle := CheckBox.new()
		toggle.name = "Bot%d" % (player + 1)
		toggle.text = "J%d" % (player + 1)
		toggle.add_theme_color_override("font_color", COLORS[player].lightened(0.3))
		toggle.toggled.connect(set_bot.bind(player))
		bot_row.add_child(toggle)
		bot_toggles.append(toggle)
	var explanation := _label(
		column,
		(
			"Salida con 5 (obligatoria) · el 6 da otra tirada y vale 7 sin fichas en casa.\n"
			+ "Dos fichas forman barrera: nadie pasa. En los seguros no se come.\n"
			+ "Comer: 20 de premio · llegar a meta: 10 · el tercer 6 manda a casa la última ficha movida."
		)
		if rules.is_parchis()
		else (
			"Salida con 6 · el 6 da otra tirada · meta exacta.\n"
			+ "Verde: destino válido; casillas de color: seguras.\n"
			+ "Recorrido horario; sin apilar ni bloqueos de barrera. "
			+ "Las casillas claras junto a casa son las metas."
		)
	)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 12)
	_button(column, "Guardar partida", _save_game)
	_button(column, "Cargar partida", _request_load)
	_button(column, "Nueva partida", _new_game)
	_label(column, "Rueda: zoom · Derecho: orbitar · Inicio: centrar · Esc: menú")
	new_game_confirmation = ConfirmationDialog.new()
	new_game_confirmation.title = "Nueva partida"
	new_game_confirmation.dialog_text = "¿Descartar la partida actual y empezar de nuevo?"
	new_game_confirmation.ok_button_text = "Nueva partida"
	new_game_confirmation.confirmed.connect(_confirm_new_game)
	layer.add_child(new_game_confirmation)


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 32
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func set_bot(enabled: bool, player: int) -> void:
	if player < 0 or player >= bots.size():
		return
	bots[player] = enabled
	_bot_wait = 0.0
	if player < bot_toggles.size() and bot_toggles[player].button_pressed != enabled:
		bot_toggles[player].set_pressed_no_signal(enabled)
	_refresh()


func is_bot_turn() -> bool:
	return rules.phase != LudoRules.FINISHED and rules.turn < bots.size() and bots[rules.turn]


func _process(delta: float) -> void:
	if not is_bot_turn() or waiting_roll or grabber.held != null or not in_transit.is_empty():
		_bot_wait = 0.0
		return
	_bot_wait += delta
	if _bot_wait >= TableBots.THINK_TIME:
		_bot_wait = 0.0
		bot_step()


## Una acción del bot: tirar el dado o mover la ficha que elige TableBots.
func bot_step() -> bool:
	if rules.phase == LudoRules.ROLL:
		_roll()
		return true
	if rules.phase == LudoRules.MOVE:
		var token := TableBots.ludo_choice(rules)
		if token >= 0:
			_choose_token(token)
			help.text = tr("El bot mueve su ficha %d.") % (token + 1)
			return true
	return false


func _refresh() -> void:
	_update_seats()
	status.text = (
		"%s · %d jugadores\nTurno J%d (%s)%s" % ["Parchís" if rules.is_parchis() else "Ludo", rules.players, rules.turn + 1, NAMES[rules.turn], " · bot" if is_bot_turn() else ""]
	)
	if rules.phase == LudoRules.FINISHED:
		status.text = "¡Gana J%d (%s)!" % [rules.winner + 1, NAMES[rules.winner]]
	elif rules.phase == LudoRules.MOVE and rules.bonus > 0:
		status.text += " · premio de %d casillas" % rules.bonus
	elif rules.phase == LudoRules.MOVE:
		status.text += " · dado %d" % rules.die
		if rules.steps() != rules.die:
			status.text += " (cuenta %d)" % rules.steps()
	elif waiting_roll:
		status.text += " · esperando el dado…"
	roll_button.disabled = rules.phase != LudoRules.ROLL or waiting_roll
	reset_button.disabled = rules.phase != LudoRules.ROLL
	var legal := rules.legal_tokens()
	for index in range(4):
		token_buttons[index].disabled = index not in legal
		markers[index].visible = index in legal
		if index in legal:
			markers[index].position = (
				_token_position(rules.turn, index, rules.destination(index)) + Vector3.UP * 0.035
			)
	if rules.phase == LudoRules.ROLL:
		help.text = (
			"Lanza o arrastra y suelta el dado." if not waiting_roll else "Espera a que se detenga."
		)
	elif rules.phase == LudoRules.MOVE and rules.bonus > 0:
		help.text = "Premio: mueve %d casillas con la ficha que quieras." % rules.bonus
	elif rules.phase == LudoRules.MOVE:
		help.text = "Elige una ficha disponible o arrástrala a su destino verde."
	else:
		help.text = "Partida terminada. Vuelve al menú para empezar otra."


func _physics_process(delta: float) -> void:
	if waiting_roll:
		_update_die(delta)
	for player in range(rules.players):
		for index in range(4):
			var token: Token3D = tokens[player][index]
			if token == grabber.held:
				continue
			var target := _token_position(player, index, rules.positions[player][index])
			if in_transit.has(token):
				_steer_in_transit(token, target)
				continue
			var displacement := Vector3(
				target.x - token.global_position.x, 0, target.z - token.global_position.z
			)
			var velocity := Vector3(token.linear_velocity.x, 0, token.linear_velocity.z)
			if displacement.length() > 0.012 or velocity.length() > 0.03:
				token.sleeping = false
				token.apply_central_force(
					(displacement * 28.0 - velocity * 9.0).limit_length(20.0) * token.mass
				)


func _steer_in_transit(token: Token3D, target: Vector3) -> void:
	# Sube primero para no quedar atascada en las demás fichas de la casa.
	var traveling: bool = in_transit[token]
	if not traveling and token.global_position.y >= 1.02:
		traveling = true
		in_transit[token] = true
	var displacement := Vector3(
		target.x - token.global_position.x, 0, target.z - token.global_position.z
	)
	if traveling and displacement.length() < 0.035:
		in_transit.erase(token)
		return
	if not traveling:
		displacement = Vector3.ZERO
	var acceleration := (
		displacement * 28.0 - Vector3(token.linear_velocity.x, 0, token.linear_velocity.z) * 9.0
	)
	acceleration.y = (1.07 - token.global_position.y) * 45.0 - token.linear_velocity.y * 12.0
	acceleration.y += float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	token.sleeping = false
	token.apply_central_force(acceleration.limit_length(40.0) * token.mass)


func _update_die(delta: float) -> void:
	if (
		absf(die.global_position.x) > 3.4
		or absf(die.global_position.z) > 2.3
		or die.global_position.y < 0.75
	):
		stable_time = 0.0
		help.text = "El dado salió de la mesa. Usa Recolocar dado."
		return
	var basis := die.global_basis.orthonormalized()
	var upright := maxf(absf(basis.x.dot(Vector3.UP)), absf(basis.y.dot(Vector3.UP)))
	upright = maxf(upright, absf(basis.z.dot(Vector3.UP)))
	var slow := die.linear_velocity.length() < 0.07 and die.angular_velocity.length() < 0.16
	if not die.is_grabbed and slow and upright < 0.96:
		stuck_time += delta
		if stuck_time >= 1.2 and nudges < 3:
			stuck_time = 0.0
			nudges += 1
			die.sleeping = false
			var inward := Vector3(2.66 - die.position.x, 0, -die.position.z).normalized()
			die.apply_central_impulse((Vector3.UP * 1.1 + inward * 0.35) * die.mass)
			die.apply_torque_impulse(
				Vector3(randf_range(-0.7, 0.7), 0.25, randf_range(-0.7, 0.7)) * die.mass
			)
			help.text = "Dado inclinado: se aplica un pequeño impulso físico."
	else:
		stuck_time = 0.0
	stable_time = stable_time + delta if not die.is_grabbed and slow and upright >= 0.96 else 0.0
	if stable_time >= 1.0:
		var value := die.top_face()
		waiting_roll = false
		die._awaiting_result = false
		rules.apply_roll(value)
		_refresh()
		if rules.phase == LudoRules.ROLL:
			help.text = (
				"Salió %d; no había fichas disponibles. Continúa con la siguiente tirada." % value
			)


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode in [KEY_R, KEY_T]
	):
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:
			return
		_roll()
		get_viewport().set_input_as_handled()


func _roll() -> void:
	if rules.phase != LudoRules.ROLL or waiting_roll or grabber.held != null:
		return
	_begin_roll()
	die.roll(0.55)


func _begin_roll() -> void:
	waiting_roll = true
	stable_time = 0.0
	stuck_time = 0.0
	nudges = 0
	_refresh()


func _reset_die() -> void:
	if rules.phase != LudoRules.ROLL or grabber.held != null:
		return
	waiting_roll = false
	die._awaiting_result = false
	die.global_position = Vector3(2.66, 1.2, 0)
	die.linear_velocity = Vector3.ZERO
	die.angular_velocity = Vector3.ZERO
	die.sleeping = false
	_refresh()
	help.text = "Dado recolocado; la tirada anterior no cuenta."


func _on_release(object: InteractiveTableObject, target: Vector3, reason: String) -> void:
	if object == die:
		if reason == "released" and rules.phase == LudoRules.ROLL and not waiting_roll:
			_begin_roll()
		return
	for player in range(rules.players):
		for index in range(4):
			var token: Token3D = tokens[player][index]
			if object != token:
				continue
			var dest := rules.destination(index) if player == rules.turn else -2
			if reason == "released" and dest >= 0:
				var goal := _token_position(player, index, dest)
				var aim := Vector2(target.x - goal.x, target.z - goal.z).length()
				var actual := (
					Vector2(token.global_position.x - goal.x, token.global_position.z - goal.z)
					. length()
				)
				if aim <= 0.12 and actual <= 0.16:
					_choose_token(index)
					return
			_refresh()
			help.text = "Movimiento no válido: la ficha vuelve a su casilla."
			return


func _choose_token(index: int) -> void:
	if grabber.held != null:
		return
	var previous := rules.positions.duplicate(true)
	if rules.move(index):
		for player in range(rules.players):
			for token_index in range(4):
				if previous[player][token_index] != rules.positions[player][token_index]:
					in_transit[tokens[player][token_index]] = false
		_refresh()
		help.text = "Movimiento aceptado; las fichas se desplazan con fuerzas."


func _save_game() -> void:
	if waiting_roll or grabber.held != null:
		help.text = "Termina la tirada y suelta la ficha antes de guardar."
		return
	if rules.events.size() > LudoRules.MAX_EVENTS:
		help.text = "La partida supera el límite; se conserva el guardado anterior."
		return
	var json := JSON.stringify(rules.export_record())
	if not SAVE_STORE.write(save_path, json, MAX_SAVE_BYTES, SAVE_CODECS.ludo):
		help.text = "No se pudo guardar; comprueba el espacio e inténtalo de nuevo."
		return
	help.text = "Partida guardada en este dispositivo."


func _load_game() -> void:
	if waiting_roll or grabber.held != null:
		help.text = "Termina la tirada y suelta la ficha antes de cargar."
		return
	var loaded := SAVE_STORE.read_validated(save_path, MAX_SAVE_BYTES, SAVE_CODECS.ludo)
	if loaded.is_empty():
		help.text = "Guardado ausente o inválido; se conserva la partida actual."
		return
	rules = loaded["value"] as LudoRules
	in_transit.clear()
	_update_token_activity()
	for player in range(rules.players):
		for index in range(4):
			var token: Token3D = tokens[player][index]
			token.global_position = (
				_token_position(player, index, rules.positions[player][index]) + Vector3.UP * 0.1
			)
			token.linear_velocity = Vector3.ZERO
			token.angular_velocity = Vector3.ZERO
	_refresh()
	help.text = (
		"Cargada la copia anterior: el guardado principal falta o es inválido."
		if loaded["backup"]
		else "Partida cargada en este dispositivo."
	)


func _new_game() -> void:
	if _can_replace_game():
		new_game_confirmation.popup_centered()


func _confirm_new_game() -> void:
	if _can_replace_game():
		get_tree().change_scene_to_file(scene_file_path)


func _can_replace_game() -> bool:
	if waiting_roll or is_instance_valid(grabber.held) or grabber._pending_press:
		help.text = "Termina la tirada y suelta la ficha antes de continuar."
		return false
	return true


func _request_load() -> void:
	confirm_action.request(
		"Cargar partida",
		"La partida actual será sustituida por el guardado local. ¿Continuar?",
		_load_game,
		_can_replace_game
	)
