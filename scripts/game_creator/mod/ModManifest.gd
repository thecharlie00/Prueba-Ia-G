# ModManifest.gd
# Metadatos para exportación e importación de creaciones de la comunidad (.gmod).
class_name ModManifest
extends Resource

@export var mod_id: String = ""
@export var name: String = ""
@export var author: String = ""
@export var version: String = "1.0.0"
@export var min_players: int = 2
@export var max_players: int = 4
@export var tags: Array[String] = []
@export var checksum: String = ""
@export var created_at: String = ""
@export var updated_at: String = ""
@export var scene_path: String = "res://scene.tscn"

func _init(p_mod_id: String = "", p_name: String = ""):
	mod_id = p_mod_id if p_mod_id != "" else str(Time.get_ticks_msec())
	name = p_name if p_name != "" else "Mi Mod"
	var now: String = Time.get_datetime_string_from_system()
	created_at = now
	updated_at = now
