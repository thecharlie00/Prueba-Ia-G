class_name AppInfo
## Versión del juego y datos para informar de un fallo.

const FEEDBACK_HINT := "Pega este texto en tu mensaje y cuenta qué pasó. Si puedes, adjunta el archivo de registro."


## «0.2.0» o «0.2.0 demo».
static func version() -> String:
	var base := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	return base + (" demo" if is_demo() else "")


static func is_demo() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return OS.has_feature("demo")
	var edition := tree.root.get_node_or_null("Edition")
	return edition != null and edition.get("demo") == true


## Ruta absoluta del registro de Godot (vacía si el registro a archivo está desactivado).
static func log_path() -> String:
	if not bool(ProjectSettings.get_setting("debug/file_logging/enable_file_logging", false)):
		return ""
	var path := str(ProjectSettings.get_setting("debug/file_logging/log_path", "user://logs/godot.log"))
	return ProjectSettings.globalize_path(path)


## Texto para pegar en un informe: versión, sistema, motor, gráfica, idioma y registro.
static func report_text() -> String:
	var engine := Engine.get_version_info()
	var lines := [
		"Tablerama %s" % version(),
		"Sistema: %s %s" % [OS.get_name(), OS.get_version()],
		"Motor: Godot %s" % str(engine.get("string", "")),
		"Gráfica: %s · %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()],
		"Pantalla: %s" % str(DisplayServer.window_get_size()),
		"Idioma: %s" % TranslationServer.get_locale(),
	]
	var log := log_path()
	lines.append("Registro: %s" % (log if not log.is_empty() else "desactivado"))
	return "\n".join(lines)


## Copia el informe al portapapeles y abre la carpeta del registro. Devuelve el texto copiado.
static func copy_report(open_folder := true) -> String:
	var text := report_text()
	DisplayServer.clipboard_set(text)
	var log := log_path()
	if open_folder and not log.is_empty() and DisplayServer.get_name() != "headless":
		OS.shell_open(log.get_base_dir())
	return text
