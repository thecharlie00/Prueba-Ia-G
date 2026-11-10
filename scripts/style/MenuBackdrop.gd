class_name MenuBackdrop
extends Control
## Fondo ilustrado procedural para todos los menús de Tablerama (docs/ARTE.md):
## ambiente nocturno cálido de habitación de juegos, tapete acolchado sutil, foco
## cenital cálido, cantos de madera con remaches de latón y siluetas de piezas en las
## esquinas para enmarcar pantallas 16:9 y panorámicas sin recargar el centro.

var accent_color := Palette.SUN


func _init() -> void:
	name = "MenuBackdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 1.0 or h <= 1.0:
		return

	# 1. Base profunda de habitación cálida + tapete central en bandas cartoon.
	draw_rect(Rect2(Vector2.ZERO, size), Color("1e193b"))
	var center := Vector2(w * 0.5, h * 0.46)
	var max_r := maxf(w, h) * 0.68
	draw_circle(center, max_r, Color("25204a"))
	draw_circle(center, max_r * 0.74, Color("2b2554"))
	draw_circle(center, max_r * 0.46, accent_color.lerp(Color("332c63"), 0.86))

	# 2. Retícula diagonal sutil estilo tapete/reverso de naipe.
	var step := 64.0
	var grid_col := Color(Palette.INK.r, Palette.INK.g, Palette.INK.b, 0.24)
	var dot_col := Color(Palette.LAVENDER.r, Palette.LAVENDER.g, Palette.LAVENDER.b, 0.08)
	var span := w + h
	var d := -h
	while d < span:
		draw_line(Vector2(d, 0.0), Vector2(d + h, h), grid_col, 1.5)
		draw_line(Vector2(d + h, 0.0), Vector2(d, h), grid_col, 1.5)
		d += step
	var gy := step * 0.5
	while gy < h - 18.0:
		var gx := step * 0.5
		while gx < w - 18.0:
			draw_circle(Vector2(gx, gy), 2.2, dot_col)
			gx += step
		gy += step

	# 3. Halo superior de lámpara de mesa.
	var lamp := Vector2(w * 0.5, -h * 0.08)
	draw_circle(lamp, w * 0.34, Color(accent_color.r, accent_color.g, accent_color.b, 0.08))
	draw_circle(lamp, w * 0.20, Color(Palette.SUN_LIGHT.r, Palette.SUN_LIGHT.g, Palette.SUN_LIGHT.b, 0.07))

	# 4. Siluetas decorativas discretas en las cuatro esquinas (no invaden el área central).
	_draw_corner_die(Vector2(58.0, h - 62.0), 42.0, -0.18)
	_draw_corner_card(Vector2(w - 64.0, h - 66.0), Vector2(40.0, 56.0), 0.20)
	_draw_corner_hex(Vector2(56.0, 68.0), 28.0)
	_draw_corner_tokens(Vector2(w - 62.0, 68.0), 17.0)

	# 5. Listones superior e inferior de madera de mesa con contorno de tinta y remaches.
	var rail_h := 12.0
	draw_rect(Rect2(0.0, 0.0, w, rail_h), Palette.WOOD)
	draw_rect(Rect2(0.0, rail_h - 3.0, w, 3.0), Palette.INK)
	draw_rect(Rect2(0.0, h - rail_h, w, rail_h), Palette.WOOD.darkened(0.28))
	draw_rect(Rect2(0.0, h - rail_h, w, 3.0), Palette.INK)

	for rx in [22.0, w - 22.0]:
		for ry in [rail_h * 0.5, h - rail_h * 0.5]:
			draw_circle(Vector2(rx, ry), 4.5, Palette.INK)
			draw_circle(Vector2(rx, ry), 2.6, Palette.SUN)


func _draw_corner_die(pos: Vector2, s: float, angle: float) -> void:
	draw_set_transform(pos, angle, Vector2.ONE)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.SUN.r, Palette.SUN.g, Palette.SUN.b, 0.16)
	box.border_color = Color(Palette.INK.r, Palette.INK.g, Palette.INK.b, 0.42)
	box.set_border_width_all(3)
	box.set_corner_radius_all(10)
	draw_style_box(box, Rect2(Vector2(-s * 0.5, -s * 0.5), Vector2(s, s)))
	var pip := Color(Palette.INK.r, Palette.INK.g, Palette.INK.b, 0.36)
	for offset in [Vector2(-0.22, -0.22), Vector2(0.22, -0.22), Vector2.ZERO, Vector2(-0.22, 0.22), Vector2(0.22, 0.22)]:
		draw_circle(offset * s, 3.0, pip)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_corner_card(pos: Vector2, card_size: Vector2, angle: float) -> void:
	draw_set_transform(pos, angle, Vector2.ONE)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(Palette.PAPER.r, Palette.PAPER.g, Palette.PAPER.b, 0.13)
	box.border_color = Color(Palette.INK.r, Palette.INK.g, Palette.INK.b, 0.42)
	box.set_border_width_all(3)
	box.set_corner_radius_all(8)
	draw_style_box(box, Rect2(-card_size * 0.5, card_size))
	draw_circle(Vector2.ZERO, 8.5, Color(Palette.CORAL.r, Palette.CORAL.g, Palette.CORAL.b, 0.24))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_corner_hex(pos: Vector2, radius: float) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var a := PI / 6.0 + float(i) * PI / 3.0
		pts.append(pos + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, Color(Palette.FELT.r, Palette.FELT.g, Palette.FELT.b, 0.20))
	pts.append(pts[0])
	draw_polyline(pts, Color(Palette.INK.r, Palette.INK.g, Palette.INK.b, 0.40), 2.5, true)


func _draw_corner_tokens(pos: Vector2, radius: float) -> void:
	var offsets: Array[Vector2] = [Vector2(-10.0, 6.0), Vector2(10.0, -5.0)]
	var cols: Array[Color] = [Palette.PLAYER_RED, Palette.PLAYER_BLUE]
	for i in 2:
		var c: Vector2 = pos + offsets[i]
		draw_circle(c, radius + 2.0, Color(Palette.INK.r, Palette.INK.g, Palette.INK.b, 0.38))
		draw_circle(c, radius - 1.0, Color(cols[i].r, cols[i].g, cols[i].b, 0.20))
