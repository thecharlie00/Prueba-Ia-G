# DiceDefinition.gd
# Definición de un dado personalizado con N caras.
class_name DiceDefinition
extends Resource

@export var dice_id: String = ""
@export var face_count: int = 6  # D4, D6, D8, D10, D12, D20, D100, o N personalizado
@export var faces: Array[DiceFace] = []
@export var mass: float = 1.0
@export var bounciness: float = 0.4
@export var tint_color: Color = Color.WHITE

func _init(p_dice_id: String = ""):
	dice_id = p_dice_id if p_dice_id != "" else str(Time.get_ticks_msec())

# Devuelve la cara cuyo valor coincide, o null si no existe.
func get_face_by_value(value: int) -> DiceFace:
	for face in faces:
		if face.value == value:
			return face
	return null
