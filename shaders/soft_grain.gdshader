// Acabado de pantalla del estilo «arcilla»: un grano muy suave y una viñeta en las esquinas.
// Va en una capa por debajo de la interfaz, así que no ensucia textos ni botones.
shader_type canvas_item;
render_mode unshaded;

uniform float grain = 0.02;
uniform float vignette = 0.2;
// 0 deja el grano quieto (opción «Reducir animaciones»).
uniform float animate = 1.0;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

void fragment() {
	// Grano en celdas de 2 px, renovado 12 veces por segundo.
	vec2 cell = floor(FRAGCOORD.xy / 2.0);
	float frame = floor(TIME * 12.0) * animate;
	float n = hash(cell + vec2(frame * 17.0, frame * 31.0));
	vec2 centered = UV - 0.5;
	float edge = smoothstep(0.35, 0.9, length(centered * vec2(1.0, 0.85)) * 1.35);
	float dark = edge * vignette;
	float speck = grain * (1.0 - edge * 0.5);
	// Mezcla de un punto claro u oscuro (grano) y negro (viñeta) en una sola capa.
	float alpha = dark + speck;
	float value = alpha > 0.0 ? (step(0.5, n) * speck) / alpha : 0.0;
	COLOR = vec4(vec3(value), alpha);
}
