extends Node
## Prueba de arranque de las exportaciones (fase 0). Solo se activa con el argumento
## `-- --prueba-arranque`: abre cada mesa, espera unos fotogramas, vuelve al menú y cierra
## el juego con código 0. Sirve para comprobar en CI (y en cualquier equipo) que el ejecutable
## exportado arranca y carga todas las escenas. Los errores se buscan en la salida.

const SCENES := [
	"res://scenes/Main.tscn", "res://scenes/Chess.tscn", "res://scenes/GuidedPhysicalChess.tscn",
	"res://scenes/PhysicalChess.tscn", "res://scenes/Checkers.tscn",
	"res://scenes/GuidedPhysicalCheckers.tscn", "res://scenes/PhysicalCheckers.tscn",
	"res://scenes/GuidedDomino.tscn", "res://scenes/PhysicalDomino.tscn", "res://scenes/Ludo.tscn",
	"res://scenes/Ludo3.tscn", "res://scenes/Ludo4.tscn", "res://scenes/Island.tscn",
	"res://scenes/IslandFour.tscn", "res://scenes/CardTable.tscn", "res://scenes/Brisca.tscn",
	"res://scenes/Parchis.tscn", "res://scenes/Parchis2.tscn", "res://scenes/Menu.tscn",
	"res://scenes/BotMenu.tscn",
	"res://scenes/ModeSelect.tscn",
	"res://scenes/BotSelect.tscn",
]
const FRAMES_PER_SCENE := 45


func _ready() -> void:
	if not "--prueba-arranque" in OS.get_cmdline_user_args():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	for i in 30:
		await tree.process_frame
	print("PRUEBA DE ARRANQUE: menú cargado (%s)" % OS.get_name())
	var edition := get_node_or_null("/root/Edition")
	if edition != null and edition.demo:
		print("PRUEBA DE ARRANQUE: edición demo")
	for path in SCENES:
		if edition != null and not edition.allows(path):
			continue
		if tree.change_scene_to_file(path) != OK:
			printerr("PRUEBA DE ARRANQUE: no se pudo abrir ", path)
			tree.quit(1)
			return
		for i in FRAMES_PER_SCENE:
			await tree.process_frame
		if tree.current_scene == null or tree.current_scene.scene_file_path != path:
			printerr("PRUEBA DE ARRANQUE: la escena no quedó cargada: ", path)
			tree.quit(1)
			return
		print("PRUEBA DE ARRANQUE: ", path.get_file(), " · ", Engine.get_frames_per_second(), " FPS")
	print("PRUEBA DE ARRANQUE: correcta")
	tree.quit(0)
