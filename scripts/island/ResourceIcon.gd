class_name ResourceIcon
extends Control
## Icono plano de un recurso de la isla dibujado con formas simples y contorno de tinta,
## para las cartas de la mano (docs/ARTE.md). 0 madera, 1 ladrillo, 2 lana, 3 trigo, 4 mineral.

@export_range(0, 4) var resource := 0:
	set(value):
		resource = value
		queue_redraw()

const LINE := 3.0


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	match resource:
		0:
			_trunk(o + Vector2(0.44, 0.62) * s, Vector2(0.12, 0.3) * s)
			_tri(o, s, [Vector2(0.5, 0.06), Vector2(0.8, 0.5), Vector2(0.2, 0.5)], IslandTerrain.TREE)
			_tri(o, s, [Vector2(0.5, 0.26), Vector2(0.88, 0.74), Vector2(0.12, 0.74)], IslandTerrain.TREE)
		1:
			for b in [Vector2(0.1, 0.56), Vector2(0.52, 0.56), Vector2(0.31, 0.3)]:
				_box(o + b * s, Vector2(0.38, 0.22) * s, IslandTerrain.BRICK)
		2:
			for leg in [0.32, 0.45, 0.58, 0.7]:
				draw_line(o + Vector2(leg, 0.6) * s, o + Vector2(leg, 0.86) * s, Palette.INK, LINE + 1.0)
			for p in [Vector2(0.38, 0.45), Vector2(0.55, 0.4), Vector2(0.66, 0.52), Vector2(0.46, 0.58)]:
				_circle(o + p * s, 0.17 * s, IslandTerrain.SHEEP)
			_circle(o + Vector2(0.2, 0.42) * s, 0.1 * s, Palette.INK)
		3:
			for x in [0.3, 0.5, 0.7]:
				draw_line(o + Vector2(x, 0.9) * s, o + Vector2(x, 0.3) * s, IslandTerrain.WHEAT.darkened(0.3), LINE + 1.0)
				for y in [0.18, 0.34, 0.5]:
					_ellipse(o + Vector2(x, y) * s, Vector2(0.065, 0.1) * s, IslandTerrain.WHEAT)
		4:
			_tri(o, s, [Vector2(0.36, 0.14), Vector2(0.66, 0.86), Vector2(0.06, 0.86)], IslandTerrain.ROCK)
			_tri(o, s, [Vector2(0.66, 0.3), Vector2(0.94, 0.86), Vector2(0.4, 0.86)], IslandTerrain.ROCK.lightened(0.15))
			_tri(o, s, [Vector2(0.36, 0.14), Vector2(0.45, 0.36), Vector2(0.27, 0.36)], IslandTerrain.SNOW)


func _tri(o: Vector2, s: float, points: Array, color: Color) -> void:
	var poly := PackedVector2Array()
	for p: Vector2 in points:
		poly.append(o + p * s)
	draw_colored_polygon(poly, color)
	poly.append(poly[0])
	draw_polyline(poly, Palette.INK, LINE, true)


func _box(position: Vector2, extent: Vector2, color: Color) -> void:
	var rect := Rect2(position, extent)
	draw_rect(rect, color)
	draw_rect(rect, Palette.INK, false, LINE)


func _trunk(position: Vector2, extent: Vector2) -> void:
	_box(position, extent, IslandTerrain.TRUNK)


func _circle(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius + LINE * 0.5, Palette.INK)
	draw_circle(center, radius - LINE * 0.5, color)


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var poly := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		poly.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(poly, color)
	poly.append(poly[0])
	draw_polyline(poly, Palette.INK, LINE - 0.5, true)
