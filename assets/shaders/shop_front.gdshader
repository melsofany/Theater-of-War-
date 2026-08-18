; Shop-front shader for building ground floors (procedural, CC0, offline).
; Dark storefront band with a grid of glowing shop windows / signage.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 albedo : source_color = vec4(0.20, 0.18, 0.16, 1.0);
uniform float rows = 2.0;
uniform float cols = 8.0;
uniform float frame = 0.18;
uniform vec4 lit_color : source_color = vec4(1.0, 0.8, 0.45, 1.0);

float cell_rand(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 cell = floor(vec2(uv.x * cols, uv.y * rows));
	vec2 g = fract(vec2(uv.x * cols, uv.y * rows));
	float mullion = step(g.x, frame) + step(1.0 - frame, g.x)
		+ step(g.y, frame) + step(1.0 - frame, g.y);
	mullion = clamp(mullion, 0.0, 1.0);
	float lit = step(0.6, cell_rand(cell));
	vec3 pane = mix(albedo.rgb * 1.4, lit_color.rgb, lit * 0.7);
	ALBEDO = mix(pane, albedo.rgb * 0.4, mullion);
	METALLIC = 0.0;
	ROUGHNESS = mix(0.4, 0.9, mullion);
	EMISSION = lit_color.rgb * lit * 0.5;
}
