extends Control
## Intro animada y pantalla de título. Es la escena de arranque: las piezas de los juegos
## caen y rebotan, aparece «Tablerama» letra a letra y queda la pantalla de título con
## «Pulsa cualquier botón para empezar». Cualquier botón durante la animación salta al título;
## en el título, entra en la habitación con un fundido. Mientras tanto, la habitación se carga
## en segundo plano para que la entrada sea inmediata.
##
## Todo se dibuja en _draw a partir del tiempo, así que saltar es solo adelantar el reloj.

const DISPLAY_FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const BODY_FONT := preload("res://assets/fonts/Nunito.ttf")
const TITLE := "Tablerama"
const PROMPT := "Pulsa cualquier botón para empezar"

## Momentos de la animación (segundos).
const PIECES_AT := 0.3
const PIECE_STAGGER := 0.16
const FALL_TIME := 0.95
const TITLE_AT := 1.55
const LETTER_STAGGER := 0.07
const LETTER_TIME := 0.45
const SPARKLE_AT := 2.45
const PROMPT_AT := 2.9
## Adonde salta el reloj al saltarse la animación.
const SKIP_TO := 3.3

## Piezas: tipo, posición final (en unidades de diseño 1600×900 respecto al centro) y giro final.
const PIECES := [
	{"kind": "die", "at": Vector2(-560, -120), "tilt": -0.18},
	{"kind": "token", "at": Vector2(-430, 150), "tilt": 0.0},
	{"kind": "pawn", "at": Vector2(-660, 140), "tilt": 0.12},
	{"kind": "card", "at": Vector2(560, -130), "tilt": 0.2},
	{"kind": "domino", "at": Vector2(450, 150), "tilt": -0.25},
	{"kind": "checker", "at": Vector2(660, 150), "tilt": 0.0},
]
const PIECE_SOUND := {"die": "dice", "card": "card"}

var _time := 0.0
var _leaving := false
var _still := false
var _played := {}
var _dots: Array[Dictionary] = []
var _spin: Array[float] = []
var _box := StyleBoxFlat.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var toon := get_node_or_null("/root/ToonStyle")
	_still = toon != null and bool(toon.get("reduce_motion"))
	if _still:
		_skip()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 46:
		_dots.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"speed": rng.randf_range(0.004, 0.018),
			"size": rng.randf_range(1.2, 3.4),
			"alpha": rng.randf_range(0.12, 0.35),
			"phase": rng.randf() * TAU,
		})
	for i in PIECES.size():
		_spin.append(rng.randf_range(-2.4, 2.4))
	_box.set_corner_radius_all(16)
	var loader := get_node_or_null("/root/SceneLoader")
	if loader != null and bool(loader.call("_wants_screen")):
		loader.call("prefetch", destination())


## Escena a la que se entra: la habitación, o el menú clásico si el jugador lo prefiere.
static func destination() -> String:
	return SessionNavigation.home_scene()


func is_title_shown() -> bool:
	return _time >= PROMPT_AT


func _process(delta: float) -> void:
	if not _still:
		_time += delta
	_play_sounds()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _is_press(event):
		return
	get_viewport().set_input_as_handled()
	press()


## Lo que hace cualquier botón: salta la animación o, en el título, entra en el juego.
func press() -> void:
	if _leaving:
		return
	if not is_title_shown():
		_skip()
		return
	_leaving = true
	var sfx := get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.call("play", "turn")
	Scenes.go(destination(), true)


func _skip() -> void:
	_time = maxf(_time, SKIP_TO)
	# Los sonidos de lo que se ha saltado no deben sonar todos de golpe.
	for i in PIECES.size():
		_played["piece%d" % i] = true
	for i in TITLE.length():
		_played["letter%d" % i] = true
	_played["chime"] = true


static func _is_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		return button.pressed and button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


func _play_sounds() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx == null:
		return
	for i in PIECES.size():
		var key := "piece%d" % i
		if not _played.has(key) and _time >= _piece_start(i) + FALL_TIME * 0.3636:
			_played[key] = true
			sfx.call("play", str(PIECE_SOUND.get(PIECES[i]["kind"], "drop")))
	for i in TITLE.length():
		var key := "letter%d" % i
		if not _played.has(key) and _time >= TITLE_AT + i * LETTER_STAGGER:
			_played[key] = true
			sfx.call("play", "pop", -8.0)
	if not _played.has("chime") and _time >= SPARKLE_AT:
		_played["chime"] = true
		sfx.call("play", "turn", -4.0)


static func _piece_start(index: int) -> float:
	return PIECES_AT + index * PIECE_STAGGER


# --- Dibujo ----------------------------------------------------------------------

func _draw() -> void:
	var s := minf(size.x / 1600.0, size.y / 900.0)
	var center := size * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), Palette.INK)
	_draw_dots(s)
	_draw_glow(center + Vector2(0, -30) * s, s)
	for i in PIECES.size():
		_draw_piece(i, center, s)
	_draw_title(center + Vector2(0, -30) * s, s)
	_draw_prompt(center, s)


func _draw_dots(s: float) -> void:
	for dot in _dots:
		var pos: Vector2 = dot["pos"]
		var y := fposmod(pos.y - _time * float(dot["speed"]), 1.0)
		var x := pos.x + sin(_time * 0.4 + float(dot["phase"])) * 0.01
		var twinkle := 0.6 + 0.4 * sin(_time * 1.7 + float(dot["phase"]))
		var color := Palette.LAVENDER
		color.a = float(dot["alpha"]) * twinkle
		draw_circle(Vector2(x * size.x, y * size.y), float(dot["size"]) * s, color)


func _draw_glow(at: Vector2, s: float) -> void:
	var grow := clampf((_time - TITLE_AT + 0.3) / 0.8, 0.0, 1.0)
	if grow <= 0.0:
		return
	for i in 9:
		var color := Palette.PANEL.lightened(0.08)
		color.a = 0.11 * grow
		draw_circle(at, (520.0 - i * 52.0) * s * (0.7 + 0.3 * _ease_out(grow)), color)


func _draw_piece(index: int, center: Vector2, s: float) -> void:
	var piece: Dictionary = PIECES[index]
	var target: Vector2 = center + (piece["at"] as Vector2) * s
	var unit := 125.0 * s
	var u := clampf((_time - _piece_start(index)) / FALL_TIME, 0.0, 1.0)
	if _time < _piece_start(index):
		return
	var fall := _bounce(u)
	var drop := size.y * 0.75 + 200.0 * s
	var pos := target - Vector2(0, drop * (1.0 - fall))
	var tilt: float = piece["tilt"]
	var rot := lerpf(_spin[index], tilt, _ease_out(u))
	var squash := _squash(u)
	# Reposo: flotan un poco y el dado da un saltito de vez en cuando.
	var settled := clampf((_time - _piece_start(index) - FALL_TIME) / 0.6, 0.0, 1.0)
	var bob := sin(_time * 1.6 + index * 1.3) * 5.0 * s * settled
	var hop := 0.0
	var face := 5
	if piece["kind"] == "die" and settled >= 1.0:
		var cycle := fmod(_time, 2.6)
		if cycle < 0.55:
			var h := cycle / 0.55
			hop = sin(h * PI) * 34.0 * s
			rot += h * PI * 0.5
		face = int(_time / 2.6) % 6 + 1
	pos.y += bob - hop
	rot += sin(_time * 1.2 + index) * 0.04 * settled
	# Sombra en el suelo.
	var ground := target.y + unit * 0.55
	var height := clampf((ground - (pos.y + unit * 0.5)) / (300.0 * s), 0.0, 1.0)
	draw_set_transform(Vector2(target.x, ground), 0.0, Vector2(1.0 - height * 0.5, 0.2))
	draw_circle(Vector2.ZERO, unit * 0.48, Color(0, 0, 0, 0.32 * (1.0 - height * 0.7)))
	_draw_dust(index, Vector2(target.x, ground), unit)
	draw_set_transform(pos, rot, Vector2(1.0 + squash * 0.7, 1.0 - squash))
	match str(piece["kind"]):
		"die":
			_draw_die(unit, face)
		"token":
			_draw_token(unit)
		"pawn":
			_draw_pawn(unit)
		"card":
			_draw_card(unit)
		"domino":
			_draw_domino(unit)
		"checker":
			_draw_checker(unit)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Nube de polvo al tocar el suelo por primera vez.
func _draw_dust(index: int, at: Vector2, unit: float) -> void:
	var since := _time - (_piece_start(index) + FALL_TIME * 0.3636)
	if since < 0.0 or since > 0.4:
		return
	var k := since / 0.4
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for side in [-1.0, 1.0]:
		for j in 3:
			var color := Palette.LAVENDER
			color.a = 0.45 * (1.0 - k)
			var offset := Vector2(side * (0.3 + j * 0.18 + k * 0.5) * unit, -k * 0.12 * unit * (j + 1))
			draw_circle(at + offset, unit * (0.07 + 0.04 * j) * (1.0 - k * 0.5), color)


func _draw_die(unit: float, face: int) -> void:
	var half := unit * 0.42
	_box.bg_color = Palette.PAPER
	_box.border_color = Palette.SUN
	_box.set_border_width_all(0)
	_box.border_width_bottom = int(unit * 0.08)
	_box.set_corner_radius_all(int(unit * 0.18))
	draw_style_box(_box, Rect2(-half, -half, half * 2.0, half * 2.0))
	for pip in _pips(face):
		draw_circle(pip * half * 0.55, unit * 0.075, Palette.INK)


func _draw_token(unit: float) -> void:
	var r := unit * 0.42
	draw_circle(Vector2(0, unit * 0.06), r, Palette.PLAYER_RED.darkened(0.35))
	draw_circle(Vector2.ZERO, r, Palette.PLAYER_RED)
	draw_circle(Vector2.ZERO, r * 0.62, Palette.PLAYER_RED.darkened(0.15))
	draw_arc(Vector2.ZERO, r * 0.8, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.45), unit * 0.05)


func _draw_pawn(unit: float) -> void:
	var c := Palette.PLAYER_BLUE
	var h := unit * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(-0.16, -0.32) * h, Vector2(0.16, -0.32) * h, Vector2(0.4, 0.62) * h, Vector2(-0.4, 0.62) * h,
	]), c)
	_box.bg_color = c.darkened(0.2)
	_box.set_border_width_all(0)
	_box.set_corner_radius_all(int(unit * 0.08))
	draw_style_box(_box, Rect2(Vector2(-0.6, 0.55) * h, Vector2(1.2, 0.36) * h))
	draw_style_box(_box, Rect2(Vector2(-0.34, -0.4) * h, Vector2(0.68, 0.16) * h))
	draw_circle(Vector2(0, -0.66) * h, 0.3 * h, c)
	draw_circle(Vector2(-0.1, -0.76) * h, 0.08 * h, Color(1, 1, 1, 0.5))


func _draw_card(unit: float) -> void:
	var w := unit * 0.72
	var h := unit * 1.0
	_box.bg_color = Palette.PAPER
	_box.border_color = Palette.LAVENDER
	_box.set_border_width_all(int(maxf(unit * 0.025, 1.0)))
	_box.set_corner_radius_all(int(unit * 0.08))
	draw_style_box(_box, Rect2(-w * 0.5, -h * 0.5, w, h))
	var k := unit * 0.22
	draw_circle(Vector2(-0.5, -0.2) * k, 0.55 * k, Palette.CORAL)
	draw_circle(Vector2(0.5, -0.2) * k, 0.55 * k, Palette.CORAL)
	draw_colored_polygon(PackedVector2Array([Vector2(-1.03, 0.0) * k, Vector2(1.03, 0.0) * k, Vector2(0, 1.15) * k]), Palette.CORAL)
	var font_size := int(unit * 0.2)
	draw_string(DISPLAY_FONT, Vector2(-w * 0.4, -h * 0.28), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.CORAL)


func _draw_domino(unit: float) -> void:
	var w := unit * 0.52
	var h := unit * 1.04
	_box.bg_color = Palette.PAPER
	_box.border_color = Palette.MUTED
	_box.set_border_width_all(0)
	_box.border_width_bottom = int(unit * 0.06)
	_box.set_corner_radius_all(int(unit * 0.09))
	draw_style_box(_box, Rect2(-w * 0.5, -h * 0.5, w, h))
	draw_line(Vector2(-w * 0.36, 0), Vector2(w * 0.36, 0), Palette.MUTED, maxf(unit * 0.025, 1.0))
	var q := w * 0.24
	for pip in [Vector2(-1, -1), Vector2(1, 1)]:
		draw_circle(Vector2(0, -h * 0.25) + pip * q, unit * 0.05, Palette.INK)
	for pip in _pips(5):
		draw_circle(Vector2(0, h * 0.25) + pip * q, unit * 0.05, Palette.INK)


func _draw_checker(unit: float) -> void:
	var r := unit * 0.42
	var c := Palette.PLAYER_GREEN
	draw_circle(Vector2(0, unit * 0.07), r, c.darkened(0.35))
	draw_circle(Vector2.ZERO, r, c)
	draw_arc(Vector2.ZERO, r * 0.68, 0, TAU, 32, c.lightened(0.3), unit * 0.04)
	draw_arc(Vector2.ZERO, r * 0.36, 0, TAU, 24, c.lightened(0.3), unit * 0.04)


func _draw_title(at: Vector2, s: float) -> void:
	if _time < TITLE_AT:
		return
	var font_size := int(170.0 * s)
	var widths: Array[float] = []
	var total := 0.0
	for ch in TITLE:
		var w := DISPLAY_FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		widths.append(w)
		total += w
	var x := at.x - total * 0.5
	var baseline := at.y + font_size * 0.32
	for i in TITLE.length():
		var u := clampf((_time - TITLE_AT - i * LETTER_STAGGER) / LETTER_TIME, 0.0, 1.0)
		if u <= 0.0:
			x += widths[i]
			continue
		var scale := _ease_back(u)
		var wave := sin(_time * 2.2 - i * 0.55) * 4.0 * s * clampf((_time - PROMPT_AT) / 0.5, 0.0, 1.0)
		var pivot := Vector2(x + widths[i] * 0.5, baseline - font_size * 0.3 + wave - (1.0 - u) * 60.0 * s)
		draw_set_transform(pivot, (1.0 - u) * 0.4 * (1 if i % 2 == 0 else -1), Vector2(scale, scale))
		var origin := Vector2(-widths[i] * 0.5, font_size * 0.3)
		draw_string(DISPLAY_FONT, origin + Vector2(0, 10.0 * s), TITLE[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.SUN.darkened(0.2))
		draw_string_outline(DISPLAY_FONT, origin, TITLE[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, int(10.0 * s), Palette.INK)
		draw_string(DISPLAY_FONT, origin, TITLE[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.PAPER)
		x += widths[i]
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_sparkle(Vector2(at.x + total * 0.5 + 10.0 * s, at.y - font_size * 0.42), s)


## Destello de estrella junto al título.
func _draw_sparkle(at: Vector2, s: float) -> void:
	var u := (_time - SPARKLE_AT) / 0.7
	if u < 0.0:
		return
	var pulse := sin(clampf(u, 0.0, 1.0) * PI) if u < 1.0 else 0.35 + 0.15 * sin(_time * 3.0)
	var r := 34.0 * s * pulse
	if r <= 0.5:
		return
	var points := PackedVector2Array()
	for k in 8:
		var angle := k * PI / 4.0 + _time * 0.6
		var radius := r if k % 2 == 0 else r * 0.28
		points.append(at + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, Palette.SUN_LIGHT)


func _draw_prompt(center: Vector2, s: float) -> void:
	var appear := clampf((_time - PROMPT_AT) / 0.4, 0.0, 1.0)
	if appear <= 0.0:
		return
	var blink := 1.0 if _still else 0.45 + 0.55 * (0.5 + 0.5 * cos((_time - PROMPT_AT) * 3.2))
	var font_size := int(36.0 * s)
	var text := tr(PROMPT)
	var color := Palette.PAPER
	color.a = appear * (0.3 if _leaving else blink)
	var w := BODY_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(center.x - w * 0.5, size.y - 120.0 * s)
	draw_string(BODY_FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	var small := int(18.0 * s)
	var muted := Palette.MUTED
	muted.a = appear
	var version := "v%s" % str(ProjectSettings.get_setting("application/config/version", ""))
	var edition := get_node_or_null("/root/Edition")
	if edition != null and bool(edition.get("demo")):
		version += " · Demo"
	var vw := BODY_FONT.get_string_size(version, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
	draw_string(BODY_FONT, Vector2(size.x - vw - 28.0 * s, size.y - 28.0 * s), version, HORIZONTAL_ALIGNMENT_LEFT, -1, small, muted)


# --- Curvas ----------------------------------------------------------------------

static func _bounce(x: float) -> float:
	var n1 := 7.5625
	var d1 := 2.75
	if x < 1.0 / d1:
		return n1 * x * x
	if x < 2.0 / d1:
		x -= 1.5 / d1
		return n1 * x * x + 0.75
	if x < 2.5 / d1:
		x -= 2.25 / d1
		return n1 * x * x + 0.9375
	x -= 2.625 / d1
	return n1 * x * x + 0.984375


## Aplastamiento en cada bote de la curva _bounce.
static func _squash(u: float) -> float:
	var total := 0.0
	var contacts := [[0.3636, 0.26], [0.7273, 0.12], [0.9091, 0.05]]
	for contact in contacts:
		var since: float = u - float(contact[0])
		if since >= 0.0:
			total += float(contact[1]) * exp(-since * 28.0)
	return total


static func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func _ease_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


static func _pips(face: int) -> Array[Vector2]:
	match face:
		1:
			return [Vector2.ZERO]
		2:
			return [Vector2(-1, -1), Vector2(1, 1)]
		3:
			return [Vector2(-1, -1), Vector2.ZERO, Vector2(1, 1)]
		4:
			return [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
		5:
			return [Vector2(-1, -1), Vector2(1, -1), Vector2.ZERO, Vector2(-1, 1), Vector2(1, 1)]
	return [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]
