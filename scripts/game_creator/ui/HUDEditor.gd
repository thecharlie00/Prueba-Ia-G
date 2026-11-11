# HUDEditor.gd
# Constructor de HUDs in-game con arrastrar y soltar de elementos Canvas.
# Vincula elementos de UI con variables del RuleEngine (Módulo 4).
extends Control

@export var ui_screen_name: String = "HUD Principal"

# Elementos de UI instanciados en este editor.
@export var ui_elements: Array[Control] = []

# Señal cuando cambia una variable vinculada.
signal ui_variable_changed(variable_name: String, value: Variant)

func _ready() -> void:
	pass

# Agrega un elemento de UI al HUD.
func add_element(element: Control) -> void:
	ui_elements.append(element)
	add_child(element)

# Vincula una propiedad de un elemento de UI a una variable del RuleEngine.
func bind_element_to_variable(element: Control, property_name: String, variable_name: String, player_id: int = -1) -> void:
class_name HUDEditor
	# Placeholder: en una implementación completa se conectaría al
	# GameCreatorCore.core.rule_engine para escuchar cambios de variable.
	print("[HUDEditor] Vinculando ", element.name, ".", property_name, " -> ", variable_name)
