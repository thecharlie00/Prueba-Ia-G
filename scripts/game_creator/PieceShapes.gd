# PieceShapes.gd
# Catálogo de formas que el editor de juegos sabe poner en la mesa: su malla, su cuerpo
# físico y su tamaño. Todas apoyan la base en y = 0 (el origen de la pieza) para que al
# colocarlas queden sobre la mesa o encima de otra pieza sin hundirse.
class_name PieceShapes
extends RefCounted

const SHAPES := ["ficha", "carta", "dado", "disco", "peon", "bloque", "moneda", "tablero"]
const NAMES := {
	"ficha": "Ficha",
	"carta": "Carta",
	"dado": "Dado",
	"disco": "Disco",
	"peon": "Peón",
	"bloque": "Bloque",
	"moneda": "Moneda",
	"tablero": "Tablero",
}
const ICONS := {
	"ficha": "▭",
	"carta": "🂠",
	"dado": "⚄",
	"disco": "●",
	"peon": "♟",
	"bloque": "■",
	"moneda": "◉",
	"tablero": "▦",
}
const DEFAULT := "ficha"
const MIN_SCALE := 0.25
const MAX_SCALE := 4.0

## Tamaño base (ancho, alto, fondo) de cada forma a escala 1.
const SIZES := {
	"ficha": Vector3(0.6, 0.08, 0.84),
	"carta": Vector3(0.5, 0.02, 0.72),
	"dado": Vector3(0.34, 0.34, 0.34),
	"disco": Vector3(0.48, 0.09, 0.48),
	"peon": Vector3(0.34, 0.56, 0.34),
	"bloque": Vector3(0.3, 0.3, 0.3),
	"moneda": Vector3(0.3, 0.035, 0.3),
	"tablero": Vector3(2.0, 0.05, 2.0),
}
## Formas redondas: su cuerpo físico es un cilindro.
const ROUND := ["disco", "peon", "moneda"]


static func valid(shape: String) -> String:
	return shape if SIZES.has(shape) else DEFAULT


static func size_of(shape: String, scale_factor := 1.0) -> Vector3:
	return SIZES[valid(shape)] * clampf(scale_factor, MIN_SCALE, MAX_SCALE)


## Malla de la forma, centrada en el origen (el editor la sube media altura).
static func mesh_for(shape: String, scale_factor := 1.0) -> Mesh:
	shape = valid(shape)
	var s := size_of(shape, scale_factor)
	match shape:
		"ficha":
			return PieceKit.rounded_slab(s, minf(s.x, s.z) * 0.12, s.y * 0.45)
		"carta":
			return PieceKit.rounded_slab(s, minf(s.x, s.z) * 0.1, s.y * 0.45, 5)
		"dado":
			return PieceKit.rounded_box(s, s.x * 0.18)
		"bloque":
			return PieceKit.rounded_box(s, s.x * 0.08)
		"tablero":
			return PieceKit.rounded_slab(s, s.x * 0.03, s.y * 0.4)
		"disco", "moneda":
			return PieceKit.rounded_disc(s.x * 0.5, s.y, s.y * 0.4)
		"peon":
			return PieceKit.lathe(_pawn_profile(s.x * 0.5, s.y), 32)
	return PieceKit.rounded_slab(s, 0.05, 0.03)


## Forma de colisión equivalente, centrada en el origen como la malla.
static func collision_for(shape: String, scale_factor := 1.0) -> Shape3D:
	shape = valid(shape)
	var s := size_of(shape, scale_factor)
	if shape in ROUND:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = s.x * 0.5
		cylinder.height = s.y
		return cylinder
	var box := BoxShape3D.new()
	box.size = s
	return box


## Silueta de peón (radio, altura) de abajo arriba, centrada en altura.
static func _pawn_profile(radius: float, height: float) -> PackedVector2Array:
	var points := [
		Vector2(1.0, 0.0), Vector2(1.0, 0.1), Vector2(0.82, 0.16), Vector2(0.5, 0.24),
		Vector2(0.38, 0.4), Vector2(0.34, 0.56), Vector2(0.52, 0.6), Vector2(0.34, 0.64),
		Vector2(0.52, 0.72), Vector2(0.6, 0.82), Vector2(0.5, 0.94), Vector2(0.26, 0.995),
		Vector2(0.0, 1.0),
	]
	var profile := PackedVector2Array()
	for p in points:
		profile.append(Vector2(p.x * radius, p.y * height - height * 0.5))
	return profile
