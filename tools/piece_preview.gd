extends Node3D
## Escena de revisión del kit de piezas: muestra cada pieza rediseñada sobre la mesa.
## Se usa con tools/screenshot.gd: tools/shots.sh <carpeta> godot PiecePreview (escena en tools/).

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.5, 2.3)
	cam.look_at_from_position(cam.position, Vector3(0, 0.2, 0.1))
	add_child(cam)
	var table := MeshInstance3D.new()
	table.mesh = PieceKit.rounded_box(Vector3(6, 0.2, 3.4), 0.06)
	var felt := StandardMaterial3D.new()
	felt.albedo_color = Color("1e7a5f")
	table.material_override = felt
	table.position.y = -0.1
	add_child(table)
	var x := -2.4
	for path in ["res://scenes/Dice3D.tscn", "res://scenes/Token3D.tscn", "res://scenes/Domino3D.tscn", "res://scenes/Card3D.tscn", "res://scenes/Deck3D.tscn"]:
		var node := (load(path) as PackedScene).instantiate() as RigidBody3D
		node.freeze = true
		node.position = Vector3(x, 0.3, -0.6)
		add_child(node)
		x += 1.1
	var kinds := [1, 2, 3, 4, 5, 6]
	for i in kinds.size():
		var piece := ChessPieceModel.create(kinds[i], i % 2 == 0, _mat(Color("fff8ec") if i % 2 == 0 else Color("3a3470")))
		piece.position = Vector3(-1.6 + i * 0.62, 0.0, 0.7)
		piece.scale = Vector3.ONE * 1.6
		add_child(piece)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m
