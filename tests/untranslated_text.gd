extends SceneTree
## Con el inglés activo, ninguna pantalla de la demo debe enseñar texto en español.
## Recorre cada escena (también los paneles ocultos: ayuda F1, cajones, avisos) y mira el
## texto que se vería en pantalla. Con `-- --listar` imprime todas las frases sin traducir
## de todas las escenas en vez de fallar (útil para completar UiStrings.gd).

const SCENES := [
	"res://scenes/BotMenu.tscn",
	"res://scenes/ModeSelect.tscn",
	"res://scenes/Menu.tscn",
	"res://scenes/BotSelect.tscn",
	"res://scenes/Credits.tscn",
	"res://scenes/Main.tscn",
	"res://scenes/Brisca.tscn",
	"res://scenes/Parchis.tscn",
	"res://scenes/Parchis2.tscn",
]
## Palabras que delatan una frase en español (en minúsculas y como palabra suelta).
const SPANISH_WORDS := [
	"de", "la", "el", "los", "las", "del", "con", "para", "por", "una", "que", "y", "sin",
	"más", "mesa", "jugar", "partida", "jugador", "jugadores", "turno", "dados", "fichas",
	"cartas", "volver", "salir", "menú", "pulsa", "arrastra", "ganas", "juego", "tu", "tus",
	"sonido", "pantalla", "ajustes", "idioma", "nueva", "nuevo", "esta", "este", "aquí",
]
## Textos que son iguales en todos los idiomas.
const SAME_IN_ALL := ["Tablerama", "Español", "English", "Català", "Lilita One", "Nunito", "Godot Engine"]

## Nombres de juegos que no se traducen.
const PROPER_NOUNS := ["Parchís", "PARCHÍS", "Parchis"]

var _failed := false
var _listing := false


func _initialize() -> void:
	_listing = "--listar" in OS.get_cmdline_user_args()
	_run.call_deferred()


func _run() -> void:
	var locale := root.get_node("Locale")
	locale.set_language("en", false)
	var total := 0
	for path in SCENES:
		if path == "res://scenes/Main.tscn":
			Tutorial.requested = true
		change_scene_to_file(path)
		for i in 12:
			await process_frame
		var found := {}
		_collect(current_scene, found)
		for text in found:
			total += 1
			if _listing:
				print("%s\t%s" % [path.get_file(), text.c_escape()])
			else:
				_fail("%s enseña «%s» sin traducir" % [path.get_file(), text])
	Tutorial.requested = false
	locale.set_language("es", false)
	if _listing:
		print("untranslated_text: %d frases" % total)
		quit(0)
	elif _failed:
		quit(1)
	else:
		print("untranslated_text: ok")
		quit(0)


func _collect(node: Node, found: Dictionary) -> void:
	var texts: Array[String] = []
	if node is Label or node is Button or node is LineEdit:
		texts.append(str(node.get("text")))
	if node is LineEdit:
		texts.append(node.placeholder_text)
	if node is RichTextLabel:
		texts.append(node.get_parsed_text())
	if node is OptionButton:
		for i in node.item_count:
			texts.append(node.get_item_text(i))
	if node is Control:
		texts.append(node.tooltip_text)
	if node is Label3D:
		texts.append(node.text)
	for raw in texts:
		var text := raw.strip_edges()
		if text.is_empty() or text in SAME_IN_ALL:
			continue
		var shown := node.atr(text) if node.can_auto_translate() else text
		if node is RichTextLabel:
			shown = text  # get_parsed_text ya es lo que se ve
		if _looks_spanish(shown):
			found[text] = true
	for child in node.get_children():
		_collect(child, found)


func _looks_spanish(raw: String) -> bool:
	# Nombres propios que se quedan igual en todos los idiomas.
	var text := raw
	for name in PROPER_NOUNS:
		text = text.replace(name, "")
	if text.contains("¿") or text.contains("¡") or text.contains("ñ") or text.contains("Ñ"):
		return true
	for ch in ["á", "é", "í", "ó", "ú", "Á", "É", "Í", "Ó", "Ú"]:
		if text.contains(ch):
			return true
	var words := text.to_lower().replace("·", " ").replace(":", " ").replace(",", " ").replace(".", " ").split(" ", false)
	for word in words:
		if word in SPANISH_WORDS:
			return true
	return false


func _fail(message: String) -> void:
	_failed = true
	push_error("FALLO: " + message)
