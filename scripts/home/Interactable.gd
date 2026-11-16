class_name Interactable
extends Area3D
## Objeto de la habitación que se usa al acercarse (E, Intro o A) o con un clic.
## Home le da la acción; el objeto solo sabe su nombre, su texto y dónde hay que ponerse.

signal used(item: Interactable)

## Identificador estable (pruebas y guardado): «mesa», «estanteria», «puerta»…
@export var id := ""
## Texto de la etiqueta: «Jugar contra bots».
@export var label := ""
## Distancia desde la que se puede usar.
@export var reach := 2.2
## Altura de la etiqueta sobre el objeto.
@export var label_height := 2.6
## Bloqueado en esta edición (la demo): se ve, pero avisa en vez de abrir.
var locked := false
## Punto del suelo al que camina el peón cuando se hace clic en el objeto.
var approach := Vector3.ZERO


func _init() -> void:
	monitoring = false
	monitorable = false
	input_ray_pickable = true
	collision_layer = 1 << 3  # Capa 4: solo para el rayo del ratón.
	collision_mask = 0


## Forma para el rayo del ratón: una caja del tamaño del mueble.
func set_pick_box(size: Vector3, center := Vector3.ZERO) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	add_child(shape)


func prompt_text() -> String:
	if locked:
		return tr("%s · en el juego completo") % tr(label)
	return tr(label)


func use() -> void:
	used.emit(self)
