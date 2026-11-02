class_name Card3D
extends InteractiveTableObject

@export var flip_duration := 0.35
var _flipping := false


func flip() -> void:
	if _flipping or is_grabbed or freeze:
		return
	_flipping = true
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	var end_rotation := quaternion * Quaternion(Vector3.FORWARD, PI)
	var tween := create_tween()
	(
		tween
		. tween_property(self, "quaternion", end_rotation, flip_duration)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	tween.tween_callback(_finish_flip)


func _finish_flip() -> void:
	freeze = false
	sleeping = false
	_flipping = false
