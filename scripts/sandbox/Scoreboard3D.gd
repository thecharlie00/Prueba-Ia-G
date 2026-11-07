class_name Scoreboard3D
extends TableUtility
## Marcador de 4 jugadores: pizarra con una fila por color. 1–4 elige la fila, + / − suman o
## restan a esa fila y R pone todo a cero.

const PLAYERS := 4
const ROW_COLORS := [Palette.PLAYER_RED, Palette.PLAYER_BLUE, Palette.PLAYER_YELLOW, Palette.PLAYER_GREEN]
const MIN_SCORE := -999
const MAX_SCORE := 9999

var scores: Array[int] = [0, 0, 0, 0]
var selected := 0
var _rows: Array[Label3D] = []
var _marker: MeshInstance3D


func _ready() -> void:
	super._ready()
	$Visual.mesh = PieceKit.rounded_box(Vector3(1.0, 0.08, 0.86), 0.06)
	$Visual.material_override = _material(piece_color)
	var slate := MeshInstance3D.new()
	slate.name = "Slate"
	slate.mesh = PieceKit.rounded_box(Vector3(0.88, 0.02, 0.74), 0.03)
	slate.position.y = 0.045
	slate.material_override = _material(Color("2b2f45"), 0.9)
	$Visual.add_child(slate)
	_marker = MeshInstance3D.new()
	_marker.name = "Marker"
	_marker.mesh = PieceKit.rounded_box(Vector3(0.84, 0.006, 0.16), 0.02)
	var marker_material := _material(Color(1, 1, 1, 0.16), 0.9)
	marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker.material_override = marker_material
	$Visual.add_child(_marker)
	var style := get_node_or_null("/root/ToonStyle")
	for row in PLAYERS:
		var z := -0.27 + row * 0.18
		var dot := MeshInstance3D.new()
		dot.mesh = PieceKit.rounded_disc(0.05, 0.02, 0.008)
		dot.position = Vector3(-0.33, 0.06, z)
		dot.material_override = _material(ROW_COLORS[row])
		$Visual.add_child(dot)
		var label := Label3D.new()
		label.name = "Row%d" % (row + 1)
		label.rotation_degrees.x = -90.0
		label.position = Vector3(0.06, 0.058, z)
		label.pixel_size = 0.0026
		label.font_size = 56
		label.outline_size = 0
		label.modulate = Palette.PAPER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.width = 260.0
		if style != null:
			label.font = style.DISPLAY_FONT
		$Visual.add_child(label)
		_rows.append(label)
	_refresh()


func select_row(row: int) -> void:
	selected = clampi(row, 0, PLAYERS - 1)
	_refresh()


func change(amount: int) -> void:
	scores[selected] = clampi(scores[selected] + amount, MIN_SCORE, MAX_SCORE)
	_bump()
	_refresh()


func _refresh() -> void:
	for row in _rows.size():
		_rows[row].text = "J%d   %d" % [row + 1, scores[row]]
	if _marker != null:
		_marker.position = Vector3(0, 0.057, -0.27 + selected * 0.18)


func handle_shortcut(keycode: int) -> bool:
	if keycode >= KEY_1 and keycode <= KEY_4:
		select_row(keycode - KEY_1)
	elif keycode in KEYS_PLUS:
		change(1)
	elif keycode in KEYS_MINUS:
		change(-1)
	elif keycode == KEY_R:
		scores = [0, 0, 0, 0]
		_bump()
		_refresh()
	else:
		return false
	return true


func radial_actions() -> Array[Dictionary]:
	return [
		{"label": "+1", "key": "+", "keycode": KEY_PLUS},
		{"label": "−1", "key": "−", "keycode": KEY_MINUS},
		{"label": "Siguiente fila", "key": str(posmod(selected + 1, PLAYERS) + 1), "keycode": KEY_1 + posmod(selected + 1, PLAYERS)},
		{"label": "A cero", "key": "R", "keycode": KEY_R},
	]


func shortcut_hint() -> String:
	return "Marcador · 1–4 elegir jugador · + / − puntos · R a cero"


func extra_data() -> Dictionary:
	return {
		"scores": scores.duplicate(),
		"selected": selected,
		"color": [piece_color.r, piece_color.g, piece_color.b, piece_color.a],
	}


func apply_extra(data: Dictionary) -> void:
	for row in PLAYERS:
		scores[row] = int(data["scores"][row])
	select_row(int(data["selected"]))
