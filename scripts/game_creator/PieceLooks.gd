# PieceLooks.gd
# Aspecto generado de las piezas del editor: dibujos de tablero (ajedrez, casillas,
# recorrido, cruces de go), veta de madera, puntos de los dados y lectura de la cara de un
# dado. Todo se dibuja por código: no hace falta importar ninguna imagen.
class_name PieceLooks
extends RefCounted

const TEXTURE_SIZE := 512
const CORNER_COLORS := [Palette.PLAYER_RED, Palette.PLAYER_BLUE, Palette.PLAYER_GREEN, Palette.PLAYER_YELLOW]

## Caras del dado: eje local que mira hacia fuera → número (las opuestas suman 7).
const DIE_FACES := {
	Vector3.UP: 1, Vector3.DOWN: 6,
	Vector3.BACK: 2, Vector3.FORWARD: 5,
	Vector3.RIGHT: 3, Vector3.LEFT: 4,
}
## Puntos de cada cara en una rejilla de -1 a 1.
const PIPS := {
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 0), Vector2(1, 1)],
}

static var _cache := {}


## Imagen del dibujo `pattern` con `cells` casillas por lado sobre el color `base`.
static func pattern_texture(pattern: String, cells: int, base: Color) -> Texture2D:
	if pattern == "liso" or not pattern in PieceShapes.PATTERNS:
		return null
	cells = clampi(cells, PieceShapes.MIN_CELLS, PieceShapes.MAX_CELLS)
	var key := "%s:%d:%s" % [pattern, cells, base.to_html()]
	if _cache.has(key):
		return _cache[key]
	var n := TEXTURE_SIZE
	var image := Image.create(n, n, false, Image.FORMAT_RGBA8)
	image.fill(base)
	var dark := base.darkened(0.45)
	var line := base.darkened(0.35)
	var cell := float(n) / cells
	match pattern:
		"ajedrez":
			for row in cells:
				for col in cells:
					if (row + col) % 2 == 1:
						image.fill_rect(_cell_rect(col, row, cell), dark)
		"casillas":
			_grid_lines(image, cells, cell, line, 4)
		"recorrido":
			# Una vuelta de casillas por el borde; las esquinas, de colores de jugador.
			var light := base.lightened(0.18)
			for i in cells:
				for edge in [Vector2i(i, 0), Vector2i(i, cells - 1), Vector2i(0, i), Vector2i(cells - 1, i)]:
					image.fill_rect(_cell_rect(edge.x, edge.y, cell), light)
			var corners := [Vector2i(0, 0), Vector2i(cells - 1, 0), Vector2i(cells - 1, cells - 1), Vector2i(0, cells - 1)]
			for c in 4:
				image.fill_rect(_cell_rect(corners[c].x, corners[c].y, cell), (CORNER_COLORS[c] as Color).lightened(0.15))
			for i in cells:
				for edge in [Vector2i(i, 0), Vector2i(i, cells - 1), Vector2i(0, i), Vector2i(cells - 1, i)]:
					_outline(image, _cell_rect(edge.x, edge.y, cell), line, 3)
			# El centro, con un rombo suave.
			var middle := Rect2i(int(cell * 1.6), int(cell * 1.6), int(n - cell * 3.2), int(n - cell * 3.2))
			_outline(image, middle, line.lerp(base, 0.5), 3)
		"go":
			# Líneas que unen centros de casilla y puntos de estrella.
			for i in cells:
				var at := int(cell * (i + 0.5))
				image.fill_rect(Rect2i(at - 1, int(cell * 0.5), 3, int(n - cell)), dark)
				image.fill_rect(Rect2i(int(cell * 0.5), at - 1, int(n - cell), 3), dark)
			var stars: Array[int] = []
			if cells >= 9:
				var edge := 3 if cells >= 13 else 2
				stars = [edge, cells / 2, cells - 1 - edge]
			for sx in stars:
				for sy in stars:
					_dot(image, Vector2((sx + 0.5) * cell, (sy + 0.5) * cell), maxf(5.0, cell * 0.12), dark)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## Veta de madera en grises: se multiplica por el color de la pieza.
static func wood_texture() -> Texture2D:
	if _cache.has("wood"):
		return _cache["wood"]
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.02
	var n := 256
	var image := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var warp := noise.get_noise_2d(x * 0.6, y * 3.0) * 6.0
			var ring := 0.5 + 0.5 * sin((x * 0.09 + warp) * TAU * 0.5)
			var shade := lerpf(0.78, 1.0, pow(ring, 3.0))
			image.set_pixel(x, y, Color(shade, shade * 0.97, shade * 0.93))
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_cache["wood"] = texture
	return texture


## Puntos de un dado de lado `side`, como hijos de `parent` (centrado en el origen).
static func add_pips(parent: Node3D, side: float, color: Color) -> void:
	var holder := Node3D.new()
	holder.name = "Pips"
	parent.add_child(holder)
	var radius := side * 0.085
	var dot := SphereMesh.new()
	dot.radius = radius
	dot.height = radius * 2.0
	dot.radial_segments = 12
	dot.rings = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.set_meta(&"toon_style_applied", true)
	var spread := side * 0.26
	for axis in DIE_FACES:
		var normal: Vector3 = axis
		var t1 := Vector3.RIGHT if absf(normal.x) < 0.5 else Vector3.BACK
		var t2 := t1.cross(normal)
		for pip in PIPS[DIE_FACES[axis]]:
			var mesh := MeshInstance3D.new()
			mesh.mesh = dot
			mesh.material_override = material
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Aplastado contra la cara: el eje Y local del punto mira hacia fuera.
			mesh.basis = Basis(t1, normal, t2).scaled_local(Vector3(1, 0.32, 1))
			mesh.position = normal * (side * 0.5 - radius * 0.05) + t1 * (pip as Vector2).x * spread + t2 * (pip as Vector2).y * spread
			holder.add_child(mesh)


## Número que queda arriba en un dado con esta orientación.
static func die_value(basis: Basis) -> int:
	var best := 1
	var best_dot := -INF
	for axis in DIE_FACES:
		var up := (basis * (axis as Vector3)).normalized().dot(Vector3.UP)
		if up > best_dot:
			best_dot = up
			best = DIE_FACES[axis]
	return best


## Color de texto que se lee bien sobre `background`.
static func ink_for(background: Color) -> Color:
	return Palette.INK if background.get_luminance() > 0.55 else Palette.PAPER


static func _cell_rect(col: int, row: int, cell: float) -> Rect2i:
	var from := Vector2i(int(col * cell), int(row * cell))
	var to := Vector2i(int((col + 1) * cell), int((row + 1) * cell))
	return Rect2i(from, to - from)


static func _grid_lines(image: Image, cells: int, cell: float, color: Color, width: int) -> void:
	var n := image.get_width()
	for i in cells + 1:
		var at := clampi(int(i * cell) - width / 2, 0, n - width)
		image.fill_rect(Rect2i(at, 0, width, n), color)
		image.fill_rect(Rect2i(0, at, n, width), color)


static func _outline(image: Image, rect: Rect2i, color: Color, width: int) -> void:
	image.fill_rect(Rect2i(rect.position.x, rect.position.y, rect.size.x, width), color)
	image.fill_rect(Rect2i(rect.position.x, rect.end.y - width, rect.size.x, width), color)
	image.fill_rect(Rect2i(rect.position.x, rect.position.y, width, rect.size.y), color)
	image.fill_rect(Rect2i(rect.end.x - width, rect.position.y, width, rect.size.y), color)


static func _dot(image: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(int(center.y - radius), int(center.y + radius) + 1):
		for x in range(int(center.x - radius), int(center.x + radius) + 1):
			if Vector2(x, y).distance_to(center) <= radius and x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
				image.set_pixel(x, y, color)
