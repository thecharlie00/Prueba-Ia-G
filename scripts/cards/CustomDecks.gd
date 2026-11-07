class_name CustomDecks
extends RefCounted
## Barajas propias hechas con imágenes, sin conexión: cada carpeta dentro de user://mazos es
## una baraja y cada imagen (PNG, JPG o WebP) es una carta. La etiqueta de la carta es
## "img:<carpeta>/<archivo>", y su cara se lee de ese archivo al dibujarla.
##
## Los nombres se limitan a letras, números, espacios, guiones y puntos para que una etiqueta
## guardada nunca pueda apuntar fuera de la carpeta de mazos.

const ROOT := "user://mazos"
const PREFIX := "img:"
const EXTENSIONS := ["png", "jpg", "jpeg", "webp"]
const MAX_DECKS := 12
const MAX_CARDS := 100
const MAX_FILE_BYTES := 8 * 1024 * 1024
## Tamaño máximo de la cara en memoria (las fotos grandes se reducen).
const FACE_SIZE := Vector2i(512, 724)
const README := "LEEME.txt"

static var _textures := {}
static var _folder_regex: RegEx
static var _file_regex: RegEx


static func _regexes() -> void:
	if _folder_regex == null:
		_folder_regex = RegEx.create_from_string("^[\\p{L}\\p{N}_\\- ]{1,24}$")
		_file_regex = RegEx.create_from_string("^[\\p{L}\\p{N}_\\-. ]{1,48}\\.(png|jpg|jpeg|webp)$")


static func valid_folder(folder: String) -> bool:
	_regexes()
	return _folder_regex.search(folder) != null and folder.strip_edges() == folder


static func valid_file(file: String) -> bool:
	_regexes()
	return (
		_file_regex.search(file.to_lower()) != null
		and not file.begins_with(".")
		and not ".." in file
	)


## Una etiqueta de carta de baraja propia bien formada.
static func is_label(label: String) -> bool:
	if not label.begins_with(PREFIX):
		return false
	var rest := label.substr(PREFIX.length())
	var parts := rest.split("/")
	return parts.size() == 2 and valid_folder(parts[0]) and valid_file(parts[1])


static func folder_of(label: String) -> String:
	return label.substr(PREFIX.length()).get_slice("/", 0) if is_label(label) else ""


## Nombre del nodo de la baraja en la mesa.
static func deck_name(folder: String) -> String:
	return "Mazo_" + folder.replace(" ", "_")


## Nombre legible: el archivo sin extensión y la baraja entre paréntesis.
static func pretty(label: String) -> String:
	if not is_label(label):
		return label
	var file := label.get_slice("/", 1)
	return "%s (%s)" % [file.get_basename(), folder_of(label)]


## Crea la carpeta de mazos con un archivo de instrucciones. Devuelve su ruta en el sistema.
static func ensure_root() -> String:
	DirAccess.make_dir_recursive_absolute(ROOT)
	var readme := ROOT.path_join(README)
	if not FileAccess.file_exists(readme):
		var file := FileAccess.open(readme, FileAccess.WRITE)
		if file != null:
			file.store_string(
				"Barajas propias de Tablerama\n\n"
				+ "Crea una carpeta por baraja (por ejemplo «Mi baraja») y pon dentro una imagen por carta:\n"
				+ "PNG, JPG o WebP, de hasta 8 MB cada una y 100 cartas por baraja.\n"
				+ "Los nombres solo pueden llevar letras, números, espacios, guiones y puntos.\n"
				+ "Después pulsa «Cargar barajas propias» en la mesa de cartas.\n"
			)
	return ProjectSettings.globalize_path(ROOT)


## Barajas encontradas: {carpeta: [etiquetas ordenadas]}. Ignora lo que no cumple las reglas.
static func scan() -> Dictionary:
	var found := {}
	var root := DirAccess.open(ROOT)
	if root == null:
		return found
	var folders := root.get_directories()
	folders.sort()
	for folder in folders:
		if found.size() >= MAX_DECKS:
			break
		if not valid_folder(folder):
			continue
		var dir := DirAccess.open(ROOT.path_join(folder))
		if dir == null:
			continue
		var labels: Array[String] = []
		var files := dir.get_files()
		files.sort()
		for file in files:
			if labels.size() >= MAX_CARDS:
				break
			if not valid_file(file) or file.get_extension().to_lower() not in EXTENSIONS:
				continue
			var path := ROOT.path_join(folder).path_join(file)
			var handle := FileAccess.open(path, FileAccess.READ)
			if handle == null or handle.get_length() > MAX_FILE_BYTES or handle.get_length() == 0:
				continue
			labels.append(PREFIX + folder + "/" + file)
		if not labels.is_empty():
			found[folder] = labels
	return found


## Textura de la cara de una carta propia, o null si la imagen no se puede leer.
static func texture(label: String) -> Texture2D:
	if _textures.has(label):
		return _textures[label]
	if not is_label(label):
		return null
	var path := ROOT.path_join(label.substr(PREFIX.length()))
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null or handle.get_length() > MAX_FILE_BYTES:
		return null
	handle.close()
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	var scale := minf(float(FACE_SIZE.x) / image.get_width(), float(FACE_SIZE.y) / image.get_height())
	if scale < 1.0:
		image.resize(maxi(1, int(image.get_width() * scale)), maxi(1, int(image.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	var result := ImageTexture.create_from_image(image)
	_textures[label] = result
	return result


## Olvida las imágenes ya leídas (al volver a cargar las barajas, por si han cambiado).
static func clear_cache() -> void:
	_textures.clear()
