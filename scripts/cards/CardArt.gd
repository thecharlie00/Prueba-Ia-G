class_name CardArt
extends Control
## Arte de carta simple y bonito (docs/ARTE.md): anverso crema con marco fino del color del
## palo, índices en dos esquinas y un motivo central grande; reverso coral con celosía de
## puntos y un dado. También las cartas de recurso y de desarrollo de la isla.
## Todo se dibuja con formas (no depende de que la fuente tenga ♠♥♦♣) y se guarda como
## textura compartida: CardArt.texture("playing", "A ♠").

const SIZE := Vector2i(256, 362)
const SUIT_COLORS := {
	"♠": Color("2a2552"), "♣": Color("2a2552"), "♥": Color("e2504a"), "♦": Color("e2504a"),
	"O": Color("d99a00"), "C": Color("e2504a"), "E": Color("3f6fd9"), "B": Color("8a4f2a"),
}
const FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const DEV_COLORS := [Color("8a7fd6"), Color("e3a92a"), Color("c9643a"), Color("2f8f4e"), Color("d99a00")]

static var _cache := {}
static var _holder: Node

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
	viewport.size = SIZE
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
	# Marco interior fino del color del palo.
	_round_rect(Rect2(18, 18, SIZE.x - 36, SIZE.y - 36), 16, Color(color, 0.0), color, 3.0)
	# Índices: arriba a la izquierda y, girado, abajo a la derecha.
	for flip in [false, true]:
		if flip:
			draw_set_transform(Vector2(SIZE), PI, Vector2.ONE)
		_text(rank, Vector2(44, 70), 46, color)
		_suit(suit, Vector2(44, 104), 30.0, color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var center := Vector2(SIZE) * 0.5
	var spanish := suit in ["O", "C", "E", "B"]
	if (spanish and rank in ["10", "11", "12"]) or (not spanish and rank in ["J", "Q", "K"]):
		# Figura: medallón del color del palo con la letra y el palo pequeño debajo.
		draw_circle(center, 74, Palette.INK)
		draw_circle(center, 69, color)
		draw_circle(center, 56, Color(Palette.PAPER, 0.18))
		_text(_figure_letter(rank, suit), center + Vector2(0, 22), 76, Palette.PAPER)
		_suit(suit, center + Vector2(0, 104), 34.0, color)
	elif rank in ["A", "1"]:
		_suit(suit, center, 150.0, color)
	else:
		_suit(suit, center, 108.0, color)


func _figure_letter(rank: String, suit: String) -> String:
	if suit in ["O", "C", "E", "B"]:
		return {"10": "S", "11": "C", "12": "R"}.get(rank, rank)
	return rank


func _draw_back() -> void:
	_card_base(Palette.CORAL)
	_round_rect(Rect2(16, 16, SIZE.x - 32, SIZE.y - 32), 16, Color(0, 0, 0, 0), Palette.PAPER, 4.0)
	# Celosía de puntos crema.
	for y in range(40, SIZE.y - 30, 24):
		for x in range(36 + (y / 24 % 2) * 12, SIZE.x - 30, 24):
			draw_circle(Vector2(x, y), 3.5, Color(Palette.PAPER, 0.55))
	# Dado en el centro (el logotipo de Dice on!!).
	var center := Vector2(SIZE) * 0.5
	_round_rect(Rect2(center - Vector2(46, 46), Vector2(92, 92)), 20, Palette.PAPER, Palette.INK, 5.0)
	for p in [Vector2(-22, -22), Vector2(22, 22), Vector2.ZERO, Vector2(22, -22), Vector2(-22, 22)]:
		draw_circle(center + p, 8, Palette.PANEL)


# --- Isla ------------------------------------------------------------------

func _draw_resource() -> void:
	var tint: Color = IslandTerrain.CARD[resource]
	var deep: Color = IslandTerrain.GROUND[resource]
	_card_base(Palette.PAPER)
	_round_rect(Rect2(16, 16, SIZE.x - 32, 238), 18, tint, deep, 4.0)
	_text(IslandBoard.RESOURCE_NAMES[resource], Vector2(SIZE.x * 0.5, 306), 40, Palette.INK)
	for x in [-1, 1]:
		draw_circle(Vector2(SIZE.x * 0.5 + x * 70, 330), 4, deep)


func _draw_development() -> void:
	var color: Color = DEV_COLORS[dev]
	_card_base(Palette.PAPER)
	_round_rect(Rect2(16, 16, SIZE.x - 32, 238), 18, Color(color, 0.22), color, 4.0)
	var center := Vector2(SIZE.x * 0.5, 135)
	match dev:
		0:  # Caballero: escudo.
			var shield := PackedVector2Array(
				[center + Vector2(-56, -62), center + Vector2(56, -62), center + Vector2(56, 0),
				center + Vector2(0, 66), center + Vector2(-56, 0)]
			)
			_poly(shield, color)
			_poly(PackedVector2Array([center + Vector2(-8, -44), center + Vector2(8, -44), center + Vector2(8, 40), center + Vector2(-8, 40)]), Palette.PAPER)
		1:  # Punto: estrella.
			_poly(_star(center, 70, 30, 5), color)
		2:  # Caminos: dos tablones cruzados.
			for angle in [-0.5, 0.5]:
				draw_set_transform(center, angle, Vector2.ONE)
				_round_rect(Rect2(-74, -16, 148, 32), 10, color, Palette.INK, 4.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		3:  # Abundancia: dos destellos.
			_poly(_star(center + Vector2(-26, 10), 52, 16, 4), color)
			_poly(_star(center + Vector2(40, -36), 30, 10, 4), color)
		_:  # Monopolio: pila de monedas.
			for i in 4:
				var c := center + Vector2(0, 46 - i * 26)
				_ellipse(c, Vector2(58, 22), color)
	_text(IslandRules.DEV_NAMES[dev], Vector2(SIZE.x * 0.5, 306), 38, Palette.INK)


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
	draw_colored_polygon(points, color)
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
	match suit:
		"♥":
			_heart(c, h, color, false)
		"♦":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 0.75, 0), c + Vector2(0, h), c + Vector2(-h * 0.75, 0)]), color)
		"♠":
			_heart(c + Vector2(0, -h * 0.12), h * 0.92, color, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, h * 0.2), c + Vector2(h * 0.32, h), c + Vector2(-h * 0.32, h)]), color)
		"♣":
			for p in [Vector2(0, -h * 0.45), Vector2(-h * 0.46, h * 0.12), Vector2(h * 0.46, h * 0.12)]:
				draw_circle(c + p, h * 0.36, color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, 0), c + Vector2(h * 0.3, h), c + Vector2(-h * 0.3, h)]), color)
		"O":  # Oros: moneda.
			draw_circle(c, h * 0.95, Palette.INK)
			draw_circle(c, h * 0.86, color)
			draw_arc(c, h * 0.58, 0, TAU, 32, Color(Palette.PAPER, 0.7), maxf(2.0, s * 0.04), true)
			draw_circle(c, h * 0.18, Color(Palette.PAPER, 0.7))
		"C":  # Copas: cáliz.
			_poly(PackedVector2Array([c + Vector2(-h * 0.7, -h * 0.8), c + Vector2(h * 0.7, -h * 0.8), c + Vector2(h * 0.4, -h * 0.05), c + Vector2(-h * 0.4, -h * 0.05)]), color)
			draw_rect(Rect2(c + Vector2(-h * 0.1, -h * 0.05), Vector2(h * 0.2, h * 0.6)), color)
			_poly(PackedVector2Array([c + Vector2(-h * 0.45, h * 0.55), c + Vector2(h * 0.45, h * 0.55), c + Vector2(h * 0.55, h * 0.85), c + Vector2(-h * 0.55, h * 0.85)]), color)
		"E":  # Espadas: hoja, guarda y empuñadura.
			_poly(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 0.16, -h * 0.75), c + Vector2(h * 0.16, h * 0.35), c + Vector2(-h * 0.16, h * 0.35), c + Vector2(-h * 0.16, -h * 0.75)]), color)
			draw_rect(Rect2(c + Vector2(-h * 0.55, h * 0.35), Vector2(h * 1.1, h * 0.16)), Palette.INK)
			draw_rect(Rect2(c + Vector2(-h * 0.1, h * 0.5), Vector2(h * 0.2, h * 0.38)), Color("8a4f2a"))
			draw_circle(c + Vector2(0, h * 0.92), h * 0.13, Palette.INK)
		"B":  # Bastos: garrote grueso con nudos, inclinado.
			draw_set_transform(c, 0.35, Vector2.ONE)
			_poly(PackedVector2Array([Vector2(-h * 0.2, h), Vector2(h * 0.2, h), Vector2(h * 0.36, -h * 0.8), Vector2(0, -h), Vector2(-h * 0.36, -h * 0.8)]), color)
			for p in [Vector2(-h * 0.3, -h * 0.3), Vector2(h * 0.32, h * 0.05), Vector2(-h * 0.26, h * 0.45)]:
				draw_circle(p, h * 0.15, color.darkened(0.3))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _heart(c: Vector2, h: float, color: Color, upside_down: bool) -> void:
	var dir := -1.0 if upside_down else 1.0
	draw_circle(c + Vector2(-h * 0.42, -h * 0.28 * dir), h * 0.48, color)
	draw_circle(c + Vector2(h * 0.42, -h * 0.28 * dir), h * 0.48, color)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-h * 0.88, -h * 0.12 * dir), c + Vector2(h * 0.88, -h * 0.12 * dir), c + Vector2(0, h * 0.95 * dir)]), color)
