// Contorno cartoon por "casco invertido": se dibuja la malla un poco inflada mostrando solo
// sus caras traseras, en un color plano. Funciona en el renderizador Compatibility.
// ToonStyle lo añade como next_pass de los materiales opacos de las piezas y la mesa.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform vec4 outline_color : source_color = vec4(0.11, 0.1, 0.23, 1.0);
// Grosor en unidades del objeto (la mesa mide 6,8 m; un dado unos 0,35 m).
uniform float width = 0.012;
// Dirección de inflado:
// 0 = normal del vértice (mallas suaves generadas, como las piezas de ajedrez);
// 1 = desde el centro (cilindros, esferas, cápsulas);
// 2 = hacia la esquina (cajas: las aristas duras abrirían huecos con la normal).
uniform int mode = 0;

void vertex() {
	vec3 dir = NORMAL;
	if (mode == 1 && length(VERTEX) > 0.0001) {
		dir = normalize(VERTEX);
	} else if (mode == 2) {
		vec3 corner = sign(VERTEX);
		// Sin normalizar: cada eje de la caja crece el mismo grosor.
		dir = length(corner) > 0.0 ? corner : NORMAL;
	}
	VERTEX += dir * width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
