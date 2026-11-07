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
const BODY_FONT := preload("res://assets/fonts/Nunito.ttf")
## Qué hace cada carta de desarrollo (mismo orden que IslandRules.DEV_NAMES).
const DEV_TEXT := [
	"Mueve el ladrón y roba una carta",
	"Un punto de victoria",
	"Construye dos caminos gratis",
	"Toma dos recursos del banco",
	"Todos te dan un recurso",
]
const DEV_COLORS := [Color("8a7fd6"), Color("e3a92a"), Color("c9643a"), Color("2f8f4e"), Color("d99a00")]

static var _cache := {}
static var _holder: Node

## Durante la pasada de sombra, _poly no dibuja contorno.
var _flat := false
## Transformación base del emblema (identidad, o la escala de la insignia).
var _base := Transform2D.IDENTITY

var kind := "playing"
var label := ""
var resource := 0
var dev := 0


## Textura de una carta, dibujada la primera vez y compartida después.
## kind: "playing" (label "A ♠" o "7 O"), "back", "resource" (value 0..4),
## "development" (value 0..4, índice de IslandRules.DEV_NAMES).
static func texture(kind_name: String, value: Variant = "") -> Texture2D:
	# Carta de una baraja propia: su imagen; si no se puede leer, el reverso.
	if kind_name == "playing" and str(value).begins_with(CustomDecks.PREFIX):
		var custom := CustomDecks.texture(str(value))
		return custom if custom != null else texture("back")
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
		# Insignia de esquina con el icono plano del recurso: se reconoce en el abanico de la
		# mano aunque solo asome el borde izquierdo de la carta.
		var icon := ResourceIcon.new()
		icon.resource = resource
		icon.position = Vector2(19, 19)
		icon.size = Vector2(34, 34)
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
	# Medallón central con el dado de Tablerama.
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
	match resource:
		0:
			_scene_wood(deep)
		1:
			_scene_brick(deep)
		2:
			_scene_wool(deep)
		3:
			_scene_grain(deep)
		_:
			_scene_ore(deep)
	_badge(deep)
	_ribbon(IslandBoard.RESOURCE_NAMES[resource], deep)
	_caption(["Del bosque", "De las colinas", "Del pasto", "Del campo", "De la montaña"][resource], Palette.INK.lerp(deep, 0.35))


func _draw_development() -> void:
	var color: Color = DEV_COLORS[dev]
	_card_base(Palette.PAPER)
	_window(color.lerp(Palette.PAPER, 0.72), color)
	var center := Vector2(SIZE.x * 0.5, 132)
	# Rayos suaves detrás del emblema.
	for i in 12:
		var a := TAU * i / 12.0
		var ray := PackedVector2Array(
			[center, center + Vector2(cos(a - 0.12), sin(a - 0.12)) * 120, center + Vector2(cos(a + 0.12), sin(a + 0.12)) * 120]
		)
		var clipped := Geometry2D.intersect_polygons(ray, _rect_poly(Rect2(22, 22, SIZE.x - 44, 204)))
		for piece in clipped:
			_fill(piece, Color(Palette.PAPER, 0.35))
	_emblem(dev, center, 1.0, color)
	_badge(color)
	# Miniatura del emblema dentro de la insignia.
	_base = Transform2D(0.0, Vector2.ONE * 0.26, 0.0, Vector2(36, 36))
	_pop()
	_emblem(dev, Vector2.ZERO, 1.0, color)
	_base = Transform2D.IDENTITY
	_pop()
	_ribbon(IslandRules.DEV_NAMES[dev], color)
	_caption(DEV_TEXT[dev], Palette.INK.lerp(color, 0.35))


## Emblema de cada carta de desarrollo, centrado en c.
func _emblem(kind_index: int, c: Vector2, k: float, color: Color) -> void:
	match kind_index:
		0:  # Caballero: espada detrás de un escudo.
			_shadowed_poly(PackedVector2Array([c + Vector2(-6, -76), c + Vector2(6, -76), c + Vector2(6, 40), c + Vector2(-6, 40)]), Color("d9dded"))
			_poly(PackedVector2Array([c + Vector2(-34, 30), c + Vector2(34, 30), c + Vector2(34, 42), c + Vector2(-34, 42)]), Palette.INK)
			var shield := PackedVector2Array(
				[c + Vector2(-46, -46), c + Vector2(0, -56), c + Vector2(46, -46), c + Vector2(46, 2),
				c + Vector2(0, 58), c + Vector2(-46, 2)]
			)
			_shadowed_poly(shield, color)
			_fill(PackedVector2Array([c + Vector2(0, -56), c + Vector2(46, -46), c + Vector2(46, 2), c + Vector2(0, 58)]), Color(Palette.INK, 0.12))
			_poly(PackedVector2Array([c + Vector2(-6, -38), c + Vector2(6, -38), c + Vector2(6, 38), c + Vector2(-6, 38)]), Palette.PAPER)
			_poly(PackedVector2Array([c + Vector2(-28, -10), c + Vector2(28, -10), c + Vector2(28, 2), c + Vector2(-28, 2)]), Palette.PAPER)
		1:  # Punto de victoria: estrella con laurel.
			# Ramas de laurel: hojas a lo largo de un arco a cada lado, de abajo hacia arriba.
			for mirror in [1.0, -1.0]:
				for i in 6:
					var a := deg_to_rad(100.0 + i * 20.0)
					var leaf := c + Vector2(cos(a) * 60.0 * mirror, sin(a) * 60.0 - 4.0)
					var tangent := (a + PI / 2.0) if mirror > 0.0 else (PI - a - PI / 2.0)
					_push(leaf, tangent, Vector2(1.0, 0.45))
					draw_circle(Vector2.ZERO, 13, Palette.INK)
					draw_circle(Vector2.ZERO, 10.5, Color("2f8f4e"))
					_pop()
			_shadowed_poly(_star(c + Vector2(0, -6), 50, 22, 5), color)
			_fill(_star(c + Vector2(-10, -18), 12, 5, 4), Color(1, 1, 1, 0.5))
		2:  # Caminos: camino que serpentea con dos tablones.
			var road := PackedVector2Array()
			var edge := PackedVector2Array()
			for i in 11:
				var t := i / 10.0
				var p := c + Vector2(-70 + 140 * t, 40 - 80 * t + sin(t * PI * 2.0) * 22)
				road.append(p + Vector2(0, -14))
				edge.append(p + Vector2(0, 14))
			edge.reverse()
			_shadowed_poly(road + edge, Color("e8cf94"))
			for t in [0.25, 0.7]:
				var p := c + Vector2(-70 + 140 * t, 40 - 80 * t + sin(t * PI * 2.0) * 22)
				_push(p, -0.6, Vector2.ONE)
				_round_rect(Rect2(-30, -9, 60, 18), 6, color, Palette.INK, 3.0)
				_pop()
		3:  # Abundancia: cuerno con recursos.
			var horn := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				horn.append(c + Vector2(-60 + 100 * t, 30 - sin(t * PI * 0.9) * 50 - 30 * t * t) + Vector2(0, -26 * t))
			for i in range(12, -1, -1):
				var t := i / 12.0
				horn.append(c + Vector2(-60 + 100 * t, 30 - sin(t * PI * 0.9) * 50 - 30 * t * t) + Vector2(0, 26 * t + 2))
			_shadowed_poly(horn, Color("e3a92a"))
			# Recursos que se derraman por la boca del cuerno.
			var spill := [Vector2(44, -52), Vector2(62, -34), Vector2(36, -30), Vector2(56, -12), Vector2(72, -54)]
			for i in spill.size():
				var p: Vector2 = c + spill[i]
				draw_circle(p + Vector2(3, 4), 14, SHADOW)
				draw_circle(p, 14, Palette.INK)
				draw_circle(p, 11, IslandTerrain.GROUND[i % 5].lightened(0.1))
				draw_circle(p + Vector2(-4, -4), 3, Color(1, 1, 1, 0.5))
		_:  # Monopolio: dos pilas de monedas.
			for pile: Vector2 in [Vector2(-28, 0), Vector2(30, 14)]:
				var count := 4 if pile.x < 0 else 3
				for i in count:
					_shadowed_ellipse(c + pile + Vector2(0, 38 - i * 18), Vector2(32, 13), color)
				var top: Vector2 = c + pile + Vector2(0, 38 - (count - 1) * 18)
				draw_arc(top, 18, 0, TAU, 24, Color(Palette.PAPER, 0.7), 3.0, true)


# --- Escenas de recurso (dentro de la ventana) ---------------------------------

func _scene_wood(deep: Color) -> void:
	draw_circle(Vector2(196, 62), 22, Color(Palette.PAPER, 0.8))
	_pine(Vector2(98, 196), 118, deep)
	_pine(Vector2(170, 202), 140, deep)
	_pine(Vector2(204, 208), 84, deep)
	# Pila de troncos delante.
	for p in [Vector2(58, 212), Vector2(92, 212), Vector2(75, 186)]:
		draw_circle(p, 17, Palette.INK)
		draw_circle(p, 14, Color("c58a52"))
		draw_arc(p, 8, 0, TAU, 20, Color("8a4f2a"), 2.5, true)
		draw_circle(p, 2.5, Color("8a4f2a"))


func _pine(base: Vector2, height: float, deep: Color) -> void:
	var w := height * 0.42
	_poly(PackedVector2Array([base + Vector2(-6, 0), base + Vector2(6, 0), base + Vector2(6, -18), base + Vector2(-6, -18)]), Color("8a4f2a"))
	for i in 3:
		var y0 := base.y - 14 - i * height * 0.26
		var tip := Vector2(base.x, y0 - height * 0.42)
		var half := w * (1.0 - i * 0.22)
		var tri := PackedVector2Array([tip, Vector2(base.x + half, y0), Vector2(base.x - half, y0)])
		_shadowed_poly(tri, IslandTerrain.TREE.lightened(0.08))
		_fill(PackedVector2Array([tip, Vector2(base.x + half, y0), Vector2(base.x, y0)]), Color(Palette.INK, 0.18))


func _scene_brick(deep: Color) -> void:
	_fill(PackedVector2Array([Vector2(22, 150), Vector2(90, 96), Vector2(160, 140), Vector2(234, 104), Vector2(234, 200), Vector2(22, 200)]), Color(deep, 0.35))
	var brick := Vector2(58, 28)
	for row in 3:
		var count := 3 if row % 2 == 0 else 2
		var offset := 0.0 if row % 2 == 0 else brick.x * 0.5 + 2
		for col in count:
			var pos := Vector2(42 + offset + col * (brick.x + 4), 196 - row * (brick.y + 4))
			_round_rect(Rect2(pos + Vector2(3, 4), brick), 6, SHADOW, Color(0, 0, 0, 0), 0.0)
			_round_rect(Rect2(pos, brick), 6, IslandTerrain.BRICK, Palette.INK, 3.0)
			draw_rect(Rect2(pos + Vector2(6, 5), Vector2(brick.x - 12, 4)), Color(1, 1, 1, 0.28))


func _scene_wool(deep: Color) -> void:
	draw_circle(Vector2(56, 60), 20, Color(Palette.PAPER, 0.8))
	for x in [40, 70, 196, 222]:
		_fill(PackedVector2Array([Vector2(x - 8, 214), Vector2(x - 2, 196), Vector2(x + 2, 210), Vector2(x + 7, 194), Vector2(x + 9, 214)]), deep.darkened(0.15))
	var c := Vector2(132, 150)
	for leg in [-30, -12, 14, 32]:
		_round_rect(Rect2(c + Vector2(leg - 5, 22), Vector2(10, 40)), 4, Palette.INK, Palette.INK, 0.0)
	var puffs := [Vector2(-36, 0), Vector2(-16, -22), Vector2(10, -24), Vector2(34, -8), Vector2(26, 18), Vector2(-4, 22), Vector2(-30, 18), Vector2(0, 0)]
	for p in puffs:
		draw_circle(c + p + Vector2(4, 5), 25, SHADOW)
	for p in puffs:
		draw_circle(c + p, 26, Palette.INK)
	for p in puffs:
		draw_circle(c + p, 22.5, IslandTerrain.SHEEP)
	# Cabeza.
	var head := c + Vector2(-58, -8)
	draw_set_transform(head + Vector2(-14, -10), -0.6, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 12, Palette.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(head, 0.0, Vector2(0.85, 1.0))
	draw_circle(Vector2.ZERO, 22, Palette.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(head + Vector2(-6, -4), 4, Palette.PAPER)
	draw_circle(head + Vector2(-6, -4), 1.8, Palette.INK)


func _scene_grain(deep: Color) -> void:
	for i in 5:
		var y := 150 + i * 16
		draw_line(Vector2(24, y), Vector2(232, y - 10), Color(deep, 0.45), 3.0, true)
	var tie := Vector2(128, 176)
	for i in 9:
		var a := deg_to_rad(-120 + i * 7.5)
		var tip := tie + Vector2(cos(a), sin(a)) * 118
		var bottom := tie + Vector2(-cos(a), -sin(a)) * 40
		draw_line(bottom, tip, Color("b5781c"), 4.0, true)
		for j in 4:
			var p := tip.lerp(tie, 0.06 + j * 0.1)
			draw_set_transform(p, a + PI / 2.0, Vector2(0.55, 1.0))
			draw_circle(Vector2.ZERO, 11, Palette.INK)
			draw_circle(Vector2.ZERO, 8.5, IslandTerrain.WHEAT)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_round_rect(Rect2(tie + Vector2(-26, -8), Vector2(52, 16)), 6, Color("c9643a"), Palette.INK, 3.0)


func _scene_ore(deep: Color) -> void:
	for m in [[Vector2(92, 60), 140.0], [Vector2(174, 88), 100.0]]:
		var peak: Vector2 = m[0]
		var base_w: float = m[1]
		var mountain := PackedVector2Array([peak, peak + Vector2(base_w * 0.55, 150 - (peak.y - 60)), peak + Vector2(-base_w * 0.55, 150 - (peak.y - 60))])
		_shadowed_poly(mountain, IslandTerrain.ROCK.lightened(0.15))
		_fill(PackedVector2Array([peak, mountain[1], peak + Vector2(0, mountain[1].y - peak.y)]), Color(Palette.INK, 0.18))
		_poly(PackedVector2Array([peak, peak + Vector2(18, 26), peak + Vector2(6, 20), peak + Vector2(-4, 28), peak + Vector2(-18, 26)]), IslandTerrain.SNOW)
	# Rocas con gemas delante.
	for g in [[Vector2(70, 204), Color("4d7cfe")], [Vector2(128, 214), Color("2fbfa0")], [Vector2(190, 206), Color("8a7fd6")]]:
		var p: Vector2 = g[0]
		_shadowed_poly(PackedVector2Array([p + Vector2(-26, 14), p + Vector2(-20, -10), p + Vector2(4, -18), p + Vector2(26, -4), p + Vector2(22, 14)]), Color("6b7391"))
		var gem := PackedVector2Array([p + Vector2(-8, -6), p + Vector2(0, -22), p + Vector2(8, -6), p + Vector2(0, 4)])
		_poly(gem, g[1])
		_fill(PackedVector2Array([p + Vector2(0, -22), p + Vector2(8, -6), p + Vector2(0, -6)]), Color(1, 1, 1, 0.45))


# Ventana de ilustración: cielo claro arriba y suelo del color del terreno abajo.
func _window(light: Color, deep: Color) -> void:
	var rect := Rect2(16, 16, SIZE.x - 32, 216)
	_round_rect(rect, 18, light, deep, 4.0)
	var ground := PackedVector2Array(
		[Vector2(20, 170), Vector2(80, 158), Vector2(150, 166), Vector2(236, 154), Vector2(236, 214),
		Vector2(220, 228), Vector2(36, 228), Vector2(20, 214)]
	)
	_fill(ground, Color(deep, 0.3))
	_round_rect(rect, 18, Color(0, 0, 0, 0), deep, 4.0)


# Insignia redonda en la esquina superior izquierda, sobre el borde de la ventana.
func _badge(color: Color) -> void:
	draw_circle(Vector2(39, 40), 25, SHADOW)
	draw_circle(Vector2(36, 36), 25, Palette.INK)
	draw_circle(Vector2(36, 36), 21.5, Palette.PAPER)
	draw_arc(Vector2(36, 36), 21.5, 0, TAU, 32, color, 3.0, true)


# Cinta con el nombre bajo la ventana.
func _ribbon(text: String, color: Color) -> void:
	var rect := Rect2(28, 246, SIZE.x - 56, 50)
	for side in [-1, 1]:
		var x := rect.position.x if side < 0 else rect.end.x
		var tail := PackedVector2Array(
			[Vector2(x, rect.position.y + 10), Vector2(x + side * 18, rect.position.y + 18),
			Vector2(x + side * 6, rect.get_center().y + 4), Vector2(x + side * 18, rect.end.y + 6), Vector2(x, rect.end.y - 4)]
		)
		_poly(tail, color.darkened(0.25))
	_round_rect(Rect2(rect.position + Vector2(3, 4), rect.size), 10, SHADOW, Color(0, 0, 0, 0), 0.0)
	_round_rect(rect, 10, color, Palette.INK, 3.0)
	_text(text, rect.get_center() + Vector2(0, 11), 30 if text.length() < 9 else 25, Palette.PAPER)


# Texto pequeño bajo la cinta, en una o dos líneas centradas.
func _caption(text: String, color: Color) -> void:
	var words := text.split(" ")
	var lines: Array[String] = [""]
	for word in words:
		var candidate: String = (str(lines.back()) + " " + word).strip_edges()
		if BODY_FONT.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x > SIZE.x - 56 and lines.back() != "":
			lines.append(word)
		else:
			lines[lines.size() - 1] = candidate
	var y := 322.0 if lines.size() == 1 else 314.0
	for line in lines:
		var width := BODY_FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(BODY_FONT, Vector2(SIZE.x * 0.5 - width * 0.5, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
		y += 20.0


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


## Transformación local combinada con la base (para dibujar el emblema a cualquier escala).
func _push(origin: Vector2, rotation_angle: float, scale_factor: Vector2) -> void:
	draw_set_transform_matrix(_base * Transform2D(rotation_angle, scale_factor, 0.0, origin))


func _pop() -> void:
	draw_set_transform_matrix(_base)
