class_name GameEmblem
extends Control
## Emblema plano de cada juego (GameThemes): dado, carta, peón, damas, dominó, cruz de ludo
## o hexágono de la isla, en el color de acento y con contorno de tinta.

var kind := "sandbox"
var accent := Palette.SUN

const LINE := 2.5


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	var c := o + Vector2(s, s) * 0.5
	match kind:
		"cards":
			_box(Rect2(o + Vector2(0.2, 0.08) * s, Vector2(0.6, 0.84) * s), Palette.PAPER, 0.12 * s)
			draw_circle(c + Vector2(-0.07, -0.05) * s, 0.12 * s, accent)
			draw_circle(c + Vector2(0.07, -0.05) * s, 0.12 * s, accent)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.19, 0.0) * s, c + Vector2(0.19, 0.0) * s, c + Vector2(0, 0.22) * s]), accent)
		"chess":
			_poly([c + Vector2(-0.3, 0.42) * s, c + Vector2(0.3, 0.42) * s, c + Vector2(0.2, 0.26) * s, c + Vector2(0.1, 0.0) * s, c + Vector2(-0.1, 0.0) * s, c + Vector2(-0.2, 0.26) * s], accent)
			_circle(c + Vector2(0, -0.18) * s, 0.2 * s, accent)
		"checkers":
			for i in 2:
				var y := (0.18 - i * 0.24) * s
				_ellipse(c + Vector2(0, y), Vector2(0.4, 0.16) * s, accent if i == 1 else accent.darkened(0.25))
		"domino":
			_box(Rect2(o + Vector2(0.26, 0.04) * s, Vector2(0.48, 0.92) * s), Palette.PAPER, 0.1 * s)
			draw_line(c + Vector2(-0.2, 0) * s, c + Vector2(0.2, 0) * s, Palette.INK, LINE)
			for p in [Vector2(0, -0.24), Vector2(-0.1, 0.16), Vector2(0.1, 0.32)]:
				draw_circle(c + p * s, 0.06 * s, accent.darkened(0.2))
		"brisca":
			# Carta con una moneda de oros.
			_box(Rect2(o + Vector2(0.2, 0.08) * s, Vector2(0.6, 0.84) * s), Palette.PAPER, 0.12 * s)
			_circle(c, 0.2 * s, accent)
			draw_circle(c, 0.08 * s, accent.darkened(0.3))
		"ludo", "parchis":
			var colors := [Palette.PLAYER_RED, Palette.PLAYER_BLUE, Palette.PLAYER_YELLOW, Palette.PLAYER_GREEN]
			for i in 4:
				var a := PI / 4.0 + i * PI / 2.0
				_circle(c + Vector2(cos(a), sin(a)) * 0.24 * s, 0.17 * s, colors[i])
			_circle(c, 0.12 * s, Palette.PAPER)
		"island":
			var hexagon: Array = []
			for i in 6:
				var a := PI / 6.0 + i * PI / 3.0
				hexagon.append(c + Vector2(cos(a), sin(a)) * 0.46 * s)
			_poly(hexagon, accent)
			_poly([c + Vector2(0, -0.26) * s, c + Vector2(0.16, 0.06) * s, c + Vector2(-0.16, 0.06) * s], Color("1f6e3f"))
			draw_rect(Rect2(c + Vector2(-0.04, 0.06) * s, Vector2(0.08, 0.14) * s), Color("8a4f2a"))
		_:
			_box(Rect2(o + Vector2(0.08, 0.08) * s, Vector2(0.84, 0.84) * s), accent, 0.2 * s)
			for p in [Vector2(-0.2, -0.2), Vector2(0.2, 0.2), Vector2.ZERO, Vector2(0.2, -0.2), Vector2(-0.2, 0.2)]:
				draw_circle(c + p * s, 0.07 * s, Palette.INK)


func _box(rect: Rect2, fill: Color, radius: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = Palette.INK
	box.set_border_width_all(int(LINE))
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	draw_style_box(box, rect)


func _poly(points: Array, fill: Color) -> void:
	var polygon := PackedVector2Array(points)
	draw_colored_polygon(polygon, fill)
	polygon.append(polygon[0])
	draw_polyline(polygon, Palette.INK, LINE, true)


func _circle(center: Vector2, radius: float, fill: Color) -> void:
	draw_circle(center, radius + LINE * 0.5, Palette.INK)
	draw_circle(center, radius - LINE * 0.5, fill)


func _ellipse(center: Vector2, radii: Vector2, fill: Color) -> void:
	var points: Array = []
	for i in 24:
		var a := TAU * i / 24.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	_poly(points, fill)
