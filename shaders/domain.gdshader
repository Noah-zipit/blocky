shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 tint : source_color = vec4(0.45, 0.03, 0.08, 1.0);
uniform float power : hint_range(0.5, 4.0) = 2.0;
uniform float fade : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float fresnel = pow(1.0 - dot(normalize(NORMAL), normalize(VIEW)), power);
	vec3 col = tint.rgb * (0.25 + fresnel * 1.7);
	ALBEDO = col;
	ALPHA = (0.18 + fresnel * 0.65) * (1.0 - fade);
}
