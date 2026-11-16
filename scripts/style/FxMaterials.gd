class_name FxMaterials
## Materiales de los efectos efímeros (polvo, confeti, anillos, sombras, paracaídas).
##
## Por qué existe: en Godot, el shader de un StandardMaterial3D se comparte entre los
## materiales con la misma configuración y se LIBERA cuando desaparece el último que lo usa.
## Si cada nubecilla de polvo crea su material y todas mueren al pararse el peón, el shader se
## libera y al volver a andar se compila otra vez: un tirón cada vez que el peón arranca.
## Aquí se guarda un material base por tipo durante toda la sesión (mantiene vivo el shader)
## y cada efecto usa una copia, que puede cambiar de color y transparencia por su cuenta.

## Sin luz y con transparencia (polvo, anillos, sombras, motas).
const GLOW_ALPHA := "glow_alpha"
## Sin luz, opaco y visible por las dos caras (confeti).
const GLOW_TWO_SIDED := "glow_two_sided"
## Con luz de arcilla y visible por las dos caras (tela del paracaídas).
const CLOTH := "cloth"

## Misma marca que usa ToonStyle para no retocar un material.
const DONE_META := &"toon_style_applied"

static var _bases := {}


static func base(kind: String) -> StandardMaterial3D:
	if _bases.has(kind):
		return _bases[kind]
	var material := StandardMaterial3D.new()
	match kind:
		GLOW_ALPHA:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		GLOW_TWO_SIDED:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		CLOTH:
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
			material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			material.roughness = 1.0
	# ToonStyle no debe retocarlos: cambiaría su configuración y, con ella, el shader.
	material.set_meta(DONE_META, true)
	_bases[kind] = material
	return material


## Copia lista para usar, con su color.
static func make(kind: String, color: Color) -> StandardMaterial3D:
	var material := base(kind).duplicate() as StandardMaterial3D
	material.set_meta(DONE_META, true)
	material.albedo_color = color
	return material


## Dibuja una vez cada tipo bajo el suelo para que su shader se compile al cargar la escena
## y no la primera vez que aparece el efecto.
static func prewarm(parent: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "FxPrewarm"
	holder.position = Vector3(0, -3.0, 0)
	parent.add_child(holder)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	for kind in [GLOW_ALPHA, GLOW_TWO_SIDED, CLOTH]:
		var mesh := MeshInstance3D.new()
		mesh.mesh = quad
		mesh.material_override = make(kind, Color(1, 1, 1, 0.5))
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mesh)
