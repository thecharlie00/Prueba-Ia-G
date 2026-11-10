shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

// Borde Fresnel multiestado compatible con gl_compatibility:
// Hover = SUN_LIGHT, Grabbed/Legal = MINT, Invalid = CORAL.
uniform vec4 rim_color : source_color = vec4(1.0, 0.85, 0.43, 1.0);
uniform float rim_power : hint_range(1.0, 8.0) = 2.6;
uniform float fill_alpha : hint_range(0.0, 0.4) = 0.05;
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.80;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.6;
uniform float pulse_amount : hint_range(0.0, 0.35) = 0.12;

void fragment() {
	float ndotv = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, rim_power);
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_amount;
	ALBEDO = rim_color.rgb;
	ALPHA = clamp(mix(fill_alpha, rim_alpha, fresnel) * pulse, 0.0, 1.0);
}
