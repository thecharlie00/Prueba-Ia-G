class_name Scenes
extends RefCounted
## Atajo para cambiar de escena con pantalla de carga (autoload SceneLoader). Es una clase
## estática para que los scripts con class_name compilen también sin autoloads (tests).


static func go(path: String, plain := false) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var loader := tree.root.get_node_or_null("SceneLoader")
	if loader != null:
		loader.call("go", path, plain)
	else:
		tree.change_scene_to_file(path)


## Reinicia la escena actual.
static func reload() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var loader := tree.root.get_node_or_null("SceneLoader")
	if loader != null:
		loader.call("reload")
	else:
		tree.reload_current_scene()
