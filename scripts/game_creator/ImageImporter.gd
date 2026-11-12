# ImageImporter.gd
# Sistema de importación de imágenes para el Game Creator Studio.
# Permite al usuario seleccionar archivos de imagen desde el disco, copiarlos
# a la carpeta de assets del proyecto y registrarlos como recursos disponibles
# para usarse como texturas en VisualComponent, CardData, DiceFace, etc.
class_name ImageImporter
extends Node

# Carpeta destino dentro del proyecto para imágenes importadas.
@export var import_folder: String = "res://assets/images/"

# Extensiones de imagen soportadas.
var supported_extensions: Array[String] = [".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif", ".svg"]

# Lista de imágenes importadas: { path, import_path, size, width, height }
var imported_images: Array[Dictionary] = []

# Referencia al directorio de importación.
var _dir: DirAccess = null

# Señal emitida cuando se importa una nueva imagen.
signal image_imported(image_info: Dictionary)

# Señal emitida cuando falla una importación.
signal import_failed(error: String)

func _ready() -> void:
	# Crear la carpeta de destino si no existe.
	var dir: DirAccess = DirAccess.open(import_folder)
	if dir == null:
		DirAccess.make_dir_recursive(import_folder)
		_dir = DirAccess.open(import_folder)
	else:
		_dir = dir
	_scan_existing_images()

# Escanea las imágenes ya presentes en la carpeta de importación.
func _scan_existing_images() -> void:
	if _dir == null:
		return
	_dir.list_dir_begin()
	var file_name: String = _dir.get_next()
	while file_name != "":
		if not _dir.current_is_dir() and _is_supported(file_name):
			var full_path: String = import_folder + file_name
			_imported_images_append(full_path)
		file_name = _dir.get_next()
	_dir.list_dir_end()

# Verifica si un nombre de archivo tiene una extensión de imagen soportada.
func _is_supported(file_name: String) -> bool:
	var ext: String = file_name.get_extension().to_lower()
	return ext in supported_extensions

# Agrega una imagen importada a la lista interna.
func _imported_images_append(full_path: String) -> void:
	var image: Image = Image.create_from_file(full_path)
	if image == null:
		return
	var info: Dictionary = {
		"path": full_path,
		"import_path": full_path,
		"file_name": full_path.get_file(),
		"width": image.get_width(),
		"height": image.get_height(),
		"size_bytes": _file_size(full_path),
	}
	imported_images.append(info)

# Devuelve el tamaño en bytes de un archivo.
func _file_size(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var size: int = f.get_length()
	f.close()
	return size

# Importa una imagen desde una ruta de archivo externa al proyecto.
# Copia el archivo a la carpeta de importación y lo registra.
func import_image(source_path: String) -> Dictionary:
	if source_path == "":
		var error: String = "No se seleccionó ningún archivo."
		import_failed.emit(error)
		return { "success": false, "error": error }

	var ext: String = source_path.get_extension().to_lower()
	if not ext in supported_extensions:
		var error: String = "Extensión no soportada: ." + ext
		import_failed.emit(error)
		return { "success": false, "error": error }

	# Asegurar que la carpeta de destino exista.
	var dir: DirAccess = DirAccess.open(import_folder)
	if dir == null:
		DirAccess.make_dir_recursive(import_folder)
		dir = DirAccess.open(import_folder)

	var file_name: String = source_path.get_file()
	var dest_path: String = import_folder + file_name

	# Si ya existe, agregar sufijo numérico.
	while _file_exists(dest_path):
		var base: String = file_name.get_basename()
		ext = file_name.get_extension()
		var i: int = 1
		while _file_exists(import_folder + base + str(i) + "." + ext):
			i += 1
		dest_path = import_folder + base + str(i) + "." + ext

	# Copiar el archivo.
	var src: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if src == null:
		var error: String = "No se pudo leer el archivo fuente: " + source_path
		import_failed.emit(error)
		return { "success": false, "error": error }

	var dst: FileAccess = FileAccess.open(dest_path, FileAccess.WRITE)
	if dst == null:
		src.close()
		var error: String = "No se pudo escribir en: " + dest_path
		import_failed.emit(error)
		return { "success": false, "error": error }

	var data: PackedByteArray = src.get_buffer(src.get_length())
	dst.store_buffer(data)
	src.close()
	dst.close()

	# Registrar la imagen importada.
	var image: Image = Image.create_from_file(dest_path)
	if image == null:
		var error: String = "No se pudo decodificar la imagen importada."
		import_failed.emit(error)
		return { "success": false, "error": error }

	var info: Dictionary = {
		"path": dest_path,
		"import_path": dest_path,
		"file_name": dest_path.get_file(),
		"width": image.get_width(),
		"height": image.get_height(),
		"size_bytes": data.size(),
	}
	imported_images.append(info)
	image_imported.emit(info)

	return { "success": true, "info": info, "path": dest_path }

# Devuelve la lista de imágenes importadas.
func get_imported_images() -> Array[Dictionary]:
	return imported_images.duplicate()

# Busca una imagen importada por nombre de archivo.
func find_image(file_name: String) -> Dictionary:
	for info in imported_images:
		if info.get("file_name") == file_name:
			return info
	return {}

# Carga una textura desde una ruta de imagen importada.
func load_texture(path: String) -> Texture2D:
	var image: Image = Image.create_from_file(path)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)

# Verifica si un archivo existe usando DirAccess.
func _file_exists(path: String) -> bool:
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	dir.list_dir_begin()
	var exists: bool = false
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name == path.get_file():
			exists = true
			break
		file_name = dir.get_next()
	dir.list_dir_end()
	return exists
