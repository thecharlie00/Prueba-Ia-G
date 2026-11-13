extends Node
## Edición del juego: completa o demo (docs/MODELO-NEGOCIO.md).
##
## La demo es el mismo proyecto exportado con la característica «demo» (presets «Demo
## Windows» y «Demo Linux»), o arrancado con `-- --demo` para probarla. Incluye la mesa libre
## (con el tutorial) y dos juegos completos, brisca y parchís; el resto de mesas se ven en el
## menú pero no se pueden abrir. Si alguna mesa de la demo intenta abrir otra que no lo está
## (por ejemplo, un botón «Cambiar de modo»), se vuelve al menú con un aviso.
##
## El modo online no está en la demo: antes del lanzamiento nadie tiene el juego completo
## para crear salas, y así la demo no depende de Photon ni gasta su cupo de jugadores.

## Mesas que se pueden abrir en la demo.
const DEMO_SCENES := [
	"res://scenes/Menu.tscn",
	"res://scenes/BotMenu.tscn",
	"res://scenes/ModeSelect.tscn",
	"res://scenes/BotSelect.tscn",
	"res://scenes/Main.tscn",
	"res://scenes/Brisca.tscn",
	"res://scenes/Parchis.tscn",
	"res://scenes/Parchis2.tscn",
]
const MENU := "res://scenes/Menu.tscn"
## Página de la tienda (lista de deseados). Vacía hasta que exista la página de Steam.
const STORE_URL := ""

var demo := false
## Aviso pendiente para el menú (se muestra una vez).
var notice := ""


func _ready() -> void:
	demo = OS.has_feature("demo") or "--demo" in OS.get_cmdline_user_args()
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().scene_changed.connect(_on_scene_changed)


func allows(path: String) -> bool:
	return not demo or path in DEMO_SCENES


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null or allows(scene.scene_file_path):
		return
	var net := get_node_or_null("/root/Net")
	if (
		net != null
		and FusionBridge.available()
		and FusionBridge.sdk().is_in_room()
		and not net.is_singleplayer()
		and not net.is_host()
		and net.room_started
		and scene.scene_file_path == net.start_scene
	):
		return
	notice = "Esa mesa está en el juego completo. La demo incluye la mesa libre, la brisca y el parchís."
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(MENU)
