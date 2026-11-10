shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

// Deformación aerodinámica de carta durante el arrastre + brillo satinado ligero.
// Compatible con el renderizador gl_compatibility.
uniform sampler2D card_tex : source_color, filter_linear_mipmap_anisotropic;
uniform vec2 drag_bend = vec2(0.0, 0.0);
uniform float bend_sign = 1.0;
uniform float max_bend : hint_range(0.0, 0.25) = 0.085;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void vertex() {
	// QuadMesh está en el plano local XY con normal +Z.
	float edge_dist = dot(VERTEX.xy, VERTEX.xy);
	float drag_len = clamp(length(drag_bend), 0.0, 1.5);
	float directional = -(VERTEX.x * drag_bend.x + VERTEX.y * drag_bend.y) * 0.52;
	float camber = -edge_dist * drag_len * 0.22;
	float offset = clamp(directional + camber, -max_bend, max_bend) * bend_sign;
	VERTEX += NORMAL * offset;
}

void fragment() {
	vec4 tex = texture(card_tex, UV) * tint_color;
	if (tex.a < 0.5) {
		discard;
	}
	vec3 half_vec = normalize(VIEW + vec3(0.22, 0.65, 0.30));
	float sheen = pow(max(dot(normalize(NORMAL), half_vec), 0.0), 12.0) * 0.06;
	ALBEDO = clamp(tex.rgb + vec3(sheen), vec3(0.0), vec3(1.0));
}
