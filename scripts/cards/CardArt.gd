class_name CardArt
extends Control
## Arte de carta simple y bonito (docs/ARTE.md): anverso crema con marco fino del color del
## palo, índices en dos esquinas y un motivo central grande; reverso coral con celosía de
## puntos y un dado. También las cartas de recurso y de desarrollo de la isla.
## Todo se dibuja con formas (no depende de que la fuente tenga ♠♥♦♣) y se guarda como
## textura compartida: CardArt.texture("playing", "A ♠").

## Tamaño lógico del dibujo; la textura se rasteriza a RESOLUTION veces para verse nítida de cerca.
const SIZE := Vector2i(256, 362)
const RESOLUTION := 2.0
## Color de las sombras planas desplazadas (estilo vectorial).
const SHADOW := Color(0.11, 0.1, 0.23, 0.18)
const SUIT_COLORS := {
	"♠": Color("2a2552"), "♣": Color("2a2552"), "♥": Color("e2504a"), "♦": Color("e2504a"),
	"O": Color("d99a00"), "C": Color("e2504a"), "E": Color("3f6fd9"), "B": Color("8a4f2a"),
}
const FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const DEV_COLORS := [Color("8a7fd6"), Color("e3a92a"), Color("c9643a"), Color("2f8f4e"), Color("d99a00")]

static var _cache := {}
static var _holder: Node

## Durante la pasada de sombra, _poly no dibuja contorno.
var _flat := false

var kind := "playing"
var label := ""
var resource := 0
var dev := 0


## Textura de una carta, dibujada la primera vez y compartida después.
## kind: "playing" (label "A ♠" o "7 O"), "back", "resource" (value 0..4),
## "development" (value 0..4, índice de IslandRules.DEV_NAMES).
static func texture(kind_name: String, value: Variant = "") -> Texture2D:
	var key := "%s|%s" % [kind_name, value]
	if _cache.has(key) and is_instance_valid(_cache[key]["viewport"]):
		return _cache[key]["texture"]
	if not is_instance_valid(_holder):
		# Contenedor permanente bajo la raíz; diferido porque puede pedirse durante un _ready.
		_holder = Node.new()
		_holder.name = "CardArtCache"
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_holder)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(Vector2(SIZE) * RESOLUTION)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.disable_3d = true
	var art := CardArt.new()
	art.kind = kind_name
	if kind_name == "playing":
		art.label = str(value)
	elif kind_name == "resource":
		art.resource = int(value)
	elif kind_name == "development":
		art.dev = int(value)
	art.size = Vector2(SIZE)
	art.scale = Vector2.ONE * RESOLUTION
	viewport.add_child(art)
	_holder.add_child(viewport)
	var result := viewport.get_texture()
	_cache[key] = {"viewport": viewport, "texture": result}
	return result


func _ready() -> void:
	if kind == "resource":
		var icon := ResourceIcon.new()
		icon.resource = resource
		icon.position = Vector2(48, 70)
		icon.size = Vector2(160, 160)
		add_child(icon)


func _draw() -> void:
	match kind:
		"back":
			_draw_back()
		"resource":
			_draw_resource()
		"development":
			_draw_development()
		_:
			_draw_playing()


# --- Baraja ----------------------------------------------------------------

func _draw_playing() -> void:
	var parts := label.split(" ")
	var rank := parts[0]
	var suit := parts[1] if parts.size() > 1 else "♠"
	var color: Color = SUIT_COLORS.get(suit, Palette.INK)
	_card_base(Palette.PAPER)
	_round_rect(Rect2(14, 14, SIZE.x - 28, SIZE.y - 28), 18, Color(0, 0, 0, 0), Color(color, 0.55), 2.0)
	# Índices: arriba a la izquierda y, girado, abajo a la derecha.
	for flip in [false, true]:
		if flip:
			draw_set_transform(Vector2(SIZE), PI, Vector2.ONE)
		_text(rank, Vector2(40, 62), 42, color)
		_suit(suit, Vector2(40, 90), 24.0, color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var spanish := suit in ["O", "C", "E", "B"]
	if (spanish and rank in ["10", "11", "12"]) or (not spanish and rank in ["J", "Q", "K"]):
		_draw_figure(rank, suit, color, spanish)
	elif rank in ["A", "1"]:
		var center := Vector2(SIZE) * 0.5
		draw_circle(center, 86, Color(color, 0.1))
		_suit_shaded(suit, center, 132.0, color)
	else:
		_draw_pips(int(rank), suit, color)


## Distribución clásica de palos para 2–10. Los de la mitad inferior van invertidos.
func _draw_pips(count: int, suit: String, color: Color) -> void:
	var l := 88.0
	var m := 128.0
	var rr := 168.0
	var rows3 := [96.0, 181.0, 266.0]
	var rows4 := [96.0, 153.0, 209.0, 266.0]
	var spots: Array[Vector2] = []
	match count:
		2:
			spots = [Vector2(m, rows3[0]), Vector2(m, rows3[2])]
		3:
			spots = [Vector2(m, rows3[0]), Vector2(m, rows3[1]), Vector2(m, rows3[2])]
		4, 5:
			spots = [Vector2(l, rows3[0]), Vector2(rr, rows3[0]), Vector2(l, rows3[2]), Vector2(rr, rows3[2])]
			if count == 5:
				spots.append(Vector2(m, rows3[1]))
		6, 7, 8:
			for y in rows3:
				spots.append(Vector2(l, y))
				spots.append(Vector2(rr, y))
			if count >= 7:
				spots.append(Vector2(m, (rows3[0] + rows3[1]) * 0.5))
			if count == 8:
				spots.append(Vector2(m, (rows3[1] + rows3[2]) * 0.5))
		_:
			for y in rows4:
				spots.append(Vector2(l, y))
				spots.append(Vector2(rr, y))
			if count == 9:
				spots.append(Vector2(m, 181.0))
			else:
				spots.append(Vector2(m, 124.0))
				spots.append(Vector2(m, 238.0))
	var pip := 40.0 if count <= 8 else 36.0
	if suit in ["E", "B"]:
		pip *= 1.3  # Espadas y bastos son alargados: más altos para que pesen igual.
	for spot in spots:
		# Baraja francesa: los palos de la mitad inferior van invertidos; la española no.
		if spot.y > SIZE.y * 0.5 + 1.0 and suit in ["♠", "♥", "♦", "♣"]:
			draw_set_transform(spot, PI, Vector2.ONE)
			_suit_shaded(suit, Vector2.ZERO, pip, color)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			_suit_shaded(suit, spot, pip, color)


## Figura: arco del color del palo con su emblema y una cinta con la letra.
func _draw_figure(rank: String, suit: String, color: Color, spanish: bool) -> void:
	var arch := Rect2(58, 66, 140, 196)
	_round_rect(Rect2(arch.position + Vector2(5, 6), arch.size), 70, SHADOW, Color(0, 0, 0, 0), 0.0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color, 0.16)
	box.border_color = color
	box.set_border_width_all(4)
	box.corner_radius_top_left = 70
	box.corner_radius_top_right = 70
	box.corner_radius_bottom_left = 16
	box.corner_radius_bottom_right = 16
	box.anti_aliasing = true
	draw_style_box(box, arch)
	var center := arch.get_center() + Vector2(0, -6)
	var letter := _figure_letter(rank, suit)
	match letter:
		"K", "R":
			_crown(center, color)
		"Q":
			_tiara(center, color)
		"C":
			_horse(center, color)
		_:
			_cap(center, color)
	_suit_shaded(suit, Vector2(arch.get_center().x, arch.end.y - 30), 30.0, color)
	# Cinta con la letra, sobre el pie del arco.
	var ribbon := Rect2(76, arch.end.y - 4, 104, 40)
	_round_rect(Rect2(ribbon.position + Vector2(3, 4), ribbon.size), 12, SHADOW, Color(0, 0, 0, 0), 0.0)
	_round_rect(ribbon, 12, color, Palette.INK, 3.0)
	_text(letter, ribbon.get_center() + Vector2(0, 13), 36, Palette.PAPER)


func _crown(c: Vector2, color: Color) -> void:
	var base := PackedVector2Array(
		[c + Vector2(-52, 30), c + Vector2(-58, -26), c + Vector2(-28, 4), c + Vector2(0, -40),
		c + Vector2(28, 4), c + Vector2(58, -26), c + Vector2(52, 30)]
	)
	_shadowed_poly(base, Color("ffc83d"))
	_round_rect(Rect2(c + Vector2(-54, 26), Vector2(108, 18)), 6, Color("e3a92a"), Palette.INK, 3.0)
	for p in [Vector2(-58, -30), Vector2(0, -44), Vector2(58, -30)]:
		draw_circle(c + p, 9, Palette.INK)
		draw_circle(c + p, 6, color)
	draw_circle(c + Vector2(0, 8), 9, color)
	draw_circle(c + Vector2(-3, 5), 3, Color(1, 1, 1, 0.6))


func _tiara(c: Vector2, color: Color) -> void:
	var band := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		band.append(c + Vector2(cos(a) * 56, sin(a) * 30 + 26))
	for i in range(12, -1, -1):
		var a := PI + PI * i / 12.0
		band.append(c + Vector2(cos(a) * 44, sin(a) * 20 + 30))
	_shadowed_poly(band, Color("ffc83d"))
	for i in 5:
		var a := PI + PI * (i + 1) / 6.0
		var tip := c + Vector2(cos(a) * 54, sin(a) * 30 + 6)
		_shadowed_poly(PackedVector2Array([tip + Vector2(-9, 14), tip + Vector2(0, -12 - (8 if i == 2 else 0)), tip + Vector2(9, 14)]), Color("ffc83d"))
	draw_circle(c + Vector2(0, -22), 10, Palette.INK)
	draw_circle(c + Vector2(0, -22), 7, color)


func _cap(c: Vector2, color: Color) -> void:
	# Gorro con pluma.
	var feather := PackedVector2Array(
		[c + Vector2(10, 0), c + Vector2(38, -54), c + Vector2(58, -60), c + Vector2(46, -30), c + Vector2(20, 6)]
	)
	_shadowed_poly(feather, Palette.PAPER)
	draw_line(c + Vector2(16, 2), c + Vector2(52, -56), Palette.INK, 3.0, true)
	_shadowed_ellipse(c + Vector2(0, 12), Vector2(60, 26), color)
	_shadowed_ellipse(c + Vector2(-4, -2), Vector2(40, 26), color.lightened(0.15))
	draw_circle(c + Vector2(30, 4), 8, Color("ffc83d"))


func _horse(c: Vector2, color: Color) -> void:
	# Cabeza de caballo de perfil.
	var head := PackedVector2Array(
		[c + Vector2(-34, 52), c + Vector2(-30, -8), c + Vector2(-14, -40), c + Vector2(-4, -60),
		c + Vector2(4, -44), c + Vector2(40, -24), c + Vector2(52, 2), c + Vector2(40, 14),
		c + Vector2(10, 4), c + Vector2(14, 52)]
	)
	_shadowed_poly(head, color.lightened(0.25))
	var mane := PackedVector2Array(
		[c + Vector2(-30, -8), c + Vector2(-14, -40), c + Vector2(-4, -60), c + Vector2(-20, -30), c + Vector2(-36, 8), c + Vector2(-40, 48), c + Vector2(-34, 52)]
	)
	_poly(mane, Palette.INK)
	draw_circle(c + Vector2(12, -24), 6, Palette.INK)
	draw_circle(c + Vector2(44, 2), 3, Palette.INK)


func _figure_letter(rank: String, suit: String) -> String:
	if suit in ["O", "C", "E", "B"]:
		return {"10": "S", "11": "C", "12": "R"}.get(rank, rank)
	return rank


func _draw_back() -> void:
	_card_base(Palette.CORAL)
	# Rombos geométricos en dos tonos de coral.
	var inner := Rect2(16, 16, SIZE.x - 32, SIZE.y - 32)
	var light := Palette.CORAL.lightened(0.18)
	var step := 32.0
	for row in range(-1, int(inner.size.y / step) + 2):
		for col in range(-1, int(inner.size.x / step) + 2):
			var p := inner.position + Vector2(col * step + (step * 0.5 if row % 2 else 0.0), row * step * 0.62)
			var diamond := PackedVector2Array([p + Vector2(0, -11), p + Vector2(10, 0), p + Vector2(0, 11), p + Vector2(-10, 0)])
			var clipped := Geometry2D.intersect_polygons(diamond, _rect_poly(inner.grow(-6)))
			for piece in clipped:
				_fill(piece, light)
	_round_rect(inner, 18, Color(0, 0, 0, 0), Palette.PAPER, 4.0)
	_round_rect(inner.grow(-10), 12, Color(0, 0, 0, 0), Color(Palette.PAPER, 0.5), 2.0)
	# Medallón central con el dado de Dice on!!.
	var center := Vector2(SIZE) * 0.5
	_shadowed_ellipse(center, Vector2(70, 84), Palette.PAPER)
	var die := Rect2(center - Vector2(40, 40), Vector2(80, 80))
	_round_rect(Rect2(die.position + Vector2(4, 5), die.size), 18, SHADOW, Color(0, 0, 0, 0), 0.0)
	_round_rect(die, 18, Color("ffc83d"), Palette.INK, 4.0)
	for p in [Vector2(-20, -20), Vector2(20, 20), Vector2.ZERO, Vector2(20, -20), Vector2(-20, 20)]:
		draw_circle(center + p, 7.5, Palette.PANEL)


# --- Isla ------------------------------------------------------------------

func _draw_resource() -> void:
	var tint: Color = IslandTerrain.CARD[resource]
	var deep: Color = IslandTerrain.GROUND[resource]
	_card_base(Palette.PAPER)
	_window(tint, deep)
	_ribbon(IslandBoard.RESOURCE_NAMES[resource], deep)


func _draw_development() -> void:
	var color: Color = DEV_COLORS[dev]
	_card_base(Palette.PAPER)
	_window(Color(color, 0.22).blend(Color(Palette.PAPER, 0.0)), color)
	var center := Vector2(SIZE.x * 0.5, 128)
	_shadowed_ellipse(center, Vector2(70, 70), Palette.PAPER)
	match dev:
		0:  # Caballero: escudo.
			var shield := PackedVector2Array(
				[center + Vector2(-44, -50), center + Vector2(44, -50), center + Vector2(44, 0),
				center + Vector2(0, 52), center + Vector2(-44, 0)]
			)
			_shadowed_poly(shield, color)
			_poly(PackedVector2Array([center + Vector2(-7, -36), center + Vector2(7, -36), center + Vector2(7, 32), center + Vector2(-7, 32)]), Palette.PAPER)
			_poly(PackedVector2Array([center + Vector2(-28, -12), center + Vector2(28, -12), center + Vector2(28, 0), center + Vector2(-28, 0)]), Palette.PAPER)
		1:  # Punto: estrella.
			_shadowed_poly(_star(center, 56, 24, 5), color)
		2:  # Caminos: dos tablones cruzados.
			for angle in [-0.5, 0.5]:
				draw_set_transform(center, angle, Vector2.ONE)
				_round_rect(Rect2(-60, -13, 120, 26), 9, color, Palette.INK, 3.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		3:  # Abundancia: destellos.
			_shadowed_poly(_star(center + Vector2(-16, 8), 44, 13, 4), color)
			_shadowed_poly(_star(center + Vector2(30, -28), 24, 8, 4), color)
		_:  # Monopolio: pila de monedas.
			for i in 4:
				_shadowed_ellipse(center + Vector2(0, 34 - i * 20), Vector2(46, 17), color)
	_ribbon(IslandRules.DEV_NAMES[dev], color)


# Ventana de ilustración a dos tonos (cielo claro y suelo del color).
func _window(light: Color, deep: Color) -> void:
	var rect := Rect2(16, 16, SIZE.x - 32, 232)
	_round_rect(rect, 18, light, deep, 4.0)
	var ground := PackedVector2Array(
		[Vector2(20, 186), Vector2(80, 172), Vector2(150, 182), Vector2(236, 168), Vector2(236, 228),
		Vector2(222, 244), Vector2(34, 244), Vector2(20, 228)]
	)
	_fill(ground, Color(deep, 0.25))


# Cinta con el nombre bajo la ventana.
func _ribbon(text: String, color: Color) -> void:
	var rect := Rect2(28, 268, SIZE.x - 56, 54)
	for side in [-1, 1]:
		var x := rect.position.x if side < 0 else rect.end.x
		var tail := PackedVector2Array(
			[Vector2(x, rect.position.y + 10), Vector2(x - side * 0.0 + side * 18, rect.position.y + 18),
			Vector2(x + side * 6, rect.get_center().y + 4), Vector2(x + side * 18, rect.end.y + 6), Vector2(x, rect.end.y - 4)]
		)
		_poly(tail, color.darkened(0.25))
	_round_rect(Rect2(rect.position + Vector2(3, 4), rect.size), 10, SHADOW, Color(0, 0, 0, 0), 0.0)
	_round_rect(rect, 10, color, Palette.INK, 3.0)
	_text(text, rect.get_center() + Vector2(0, 12), 32 if text.length() < 9 else 26, Palette.PAPER)


# --- Formas ----------------------------------------------------------------

func _card_base(fill: Color) -> void:
	_round_rect(Rect2(Vector2.ZERO, Vector2(SIZE)), 28, fill, Palette.INK, 8.0)


func _round_rect(rect: Rect2, radius: int, fill: Color, border: Color, width: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.draw_center = fill.a > 0.0
	box.border_color = border
	box.set_border_width_all(int(width))
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	draw_style_box(box, rect)


func _text(value: String, baseline_center: Vector2, size: int, color: Color) -> void:
	var width := FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(FONT, baseline_center - Vector2(width * 0.5, 0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _poly(points: PackedVector2Array, color: Color) -> void:
	_fill(points, color)
	if _flat:
		return
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, Palette.INK, 4.0, true)


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	_poly(points, color)


func _star(center: Vector2, outer: float, inner: float, tips: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in tips * 2:
		var a := -PI / 2.0 + PI * i / tips
		var r := outer if i % 2 == 0 else inner
		points.append(center + Vector2(cos(a), sin(a)) * r)
	return points


## Palo dibujado con formas, centrado en c y de tamaño s (alto aproximado).
func _suit(suit: String, c: Vector2, s: float, color: Color) -> void:
	var h := s * 0.5
	# En la pasada de sombra todo el palo (también tinta, madera y brillos) es sombra plana.
	var flat := color == SHADOW
	var ink := SHADOW if flat else Palette.INK
	var wood := SHADOW if flat else Color("8a4f2a")
	var shine := SHADOW if flat else Color(Palette.PAPER, 0.7)
	var knot := SHADOW if flat else color.darkened(0.3)
	_flat = flat
	match suit:
		"♥":
			_heart(c, h, color, false)
		"♦":
			_fill(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 0.75, 0), c + Vector2(0, h), c + Vector2(-h * 0.75, 0)]), color)
		"♠":
			_heart(c + Vector2(0, -h * 0.12), h * 0.92, color, true)
			_fill(PackedVector2Array([c + Vector2(0, h * 0.2), c + Vector2(h * 0.32, h), c + Vector2(-h * 0.32, h)]), color)
		"♣":
			for p in [Vector2(0, -h * 0.45), Vector2(-h * 0.46, h * 0.12), Vector2(h * 0.46, h * 0.12)]:
				draw_circle(c + p, h * 0.36, color)
			_fill(PackedVector2Array([c + Vector2(0, 0), c + Vector2(h * 0.3, h), c + Vector2(-h * 0.3, h)]), color)
		"O":  # Oros: moneda.
			draw_circle(c, h * 0.95, ink)
			draw_circle(c, h * 0.86, color)
			draw_arc(c, h * 0.58, 0, TAU, 32, shine, maxf(2.0, s * 0.04), true)
			draw_circle(c, h * 0.18, shine)
		"C":  # Copas: cáliz.
			_poly(PackedVector2Array([c + Vector2(-h * 0.7, -h * 0.8), c + Vector2(h * 0.7, -h * 0.8), c + Vector2(h * 0.4, -h * 0.05), c + Vector2(-h * 0.4, -h * 0.05)]), color)
			draw_rect(Rect2(c + Vector2(-h * 0.1, -h * 0.05), Vector2(h * 0.2, h * 0.6)), color)
			_poly(PackedVector2Array([c + Vector2(-h * 0.45, h * 0.55), c + Vector2(h * 0.45, h * 0.55), c + Vector2(h * 0.55, h * 0.85), c + Vector2(-h * 0.55, h * 0.85)]), color)
		"E":  # Espadas: hoja, guarda y empuñadura.
			_poly(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 0.16, -h * 0.75), c + Vector2(h * 0.16, h * 0.35), c + Vector2(-h * 0.16, h * 0.35), c + Vector2(-h * 0.16, -h * 0.75)]), color)
			draw_rect(Rect2(c + Vector2(-h * 0.55, h * 0.35), Vector2(h * 1.1, h * 0.16)), ink)
			draw_rect(Rect2(c + Vector2(-h * 0.1, h * 0.5), Vector2(h * 0.2, h * 0.38)), wood)
			draw_circle(c + Vector2(0, h * 0.92), h * 0.13, ink)
		"B":  # Bastos: garrote grueso con nudos, inclinado.
			draw_set_transform(c, 0.35, Vector2.ONE)
			_poly(PackedVector2Array([Vector2(-h * 0.2, h), Vector2(h * 0.2, h), Vector2(h * 0.36, -h * 0.8), Vector2(0, -h), Vector2(-h * 0.36, -h * 0.8)]), color)
			for p in [Vector2(-h * 0.3, -h * 0.3), Vector2(h * 0.32, h * 0.05), Vector2(-h * 0.26, h * 0.45)]:
				draw_circle(p, h * 0.15, knot)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_flat = false


func _heart(c: Vector2, h: float, color: Color, upside_down: bool) -> void:
	var dir := -1.0 if upside_down else 1.0
	draw_circle(c + Vector2(-h * 0.42, -h * 0.28 * dir), h * 0.48, color)
	draw_circle(c + Vector2(h * 0.42, -h * 0.28 * dir), h * 0.48, color)
	_fill(PackedVector2Array([c + Vector2(-h * 0.88, -h * 0.12 * dir), c + Vector2(h * 0.88, -h * 0.12 * dir), c + Vector2(0, h * 0.95 * dir)]), color)


# --- Estilo vectorial: sombra plana desplazada y brillo ------------------------

func _suit_shaded(suit: String, c: Vector2, size: float, color: Color) -> void:
	_suit(suit, c + Vector2(size * 0.06, size * 0.08), size, SHADOW)
	_suit(suit, c, size, color)
	# Brillo: un pequeño óvalo claro arriba a la izquierda.
	if suit in ["♥", "♠", "♣", "O"]:
		draw_set_transform(c + Vector2(-size * 0.2, -size * 0.18), -0.5, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, size * 0.08, Color(1, 1, 1, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _shadowed_poly(points: PackedVector2Array, color: Color) -> void:
	var shadow := PackedVector2Array()
	for p in points:
		shadow.append(p + Vector2(4, 5))
	_fill(shadow, SHADOW)
	_poly(points, color)


func _shadowed_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var shadow := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		shadow.append(center + Vector2(4, 5) + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	_fill(shadow, SHADOW)
	_ellipse(center, radii, color)


func _rect_poly(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


## Relleno de polígono tolerante: si la forma no se puede triangular (puntos alineados o
## cruzados), se rellena su envolvente convexa en lugar de fallar.
func _fill(points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	if Geometry2D.triangulate_polygon(points).is_empty():
		points = Geometry2D.convex_hull(points)
		if points.size() < 4:
			return
	draw_colored_polygon(points, color)
