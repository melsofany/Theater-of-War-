; GlassFacade building window-grid shader (Polyhaven-style glass, fully procedural).
; Renders dark glass with a repeating mullion/window grid and a fraction of
; emissive "lit" windows, so towers read as real buildings instead of flat boxes.
; No external textures — CC0, offline-safe.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 albedo : source_color = vec4(0.165, 0.227, 0.290, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.85;
uniform float roughness : hint_range(0.0, 1.0) = 0.15;
uniform vec4 window_tint : source_color = vec4(0.30, 0.50, 0.70, 1.0);
uniform vec4 lit_color : source_color = vec4(1.0, 0.82, 0.48, 1.0);
uniform float rows = 26.0;
uniform float cols = 6.0;
uniform float frame = 0.10;       // mullion width as fraction of a pane
uniform float lit_fraction = 0.22; // share of windows that glow
uniform float lit_intensity = 0.7;

// Deterministic per-cell pseudo-random in [0,1).
float cell_rand(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 cell = floor(vec2(uv.x * cols, uv.y * rows));
	vec2 g = fract(vec2(uv.x * cols, uv.y * rows));
	// Mullion mask: near the edges of each pane.
	float mullion = step(g.x, frame) + step(1.0 - frame, g.x)
		+ step(g.y, frame) + step(1.0 - frame, g.y);
	mullion = clamp(mullion, 0.0, 1.0);
	float r = cell_rand(cell);
	float lit = step(1.0 - lit_fraction, r);
	// Pane colour: tinted glass, brightened where lit.
	vec3 pane = mix(window_tint.rgb, lit_color.rgb, lit * 0.85);
	vec3 col = mix(pane, albedo.rgb * 0.35, mullion);
	ALBEDO = col;
	METALLIC = mix(metallic, 0.2, mullion);
	ROUGHNESS = mix(roughness, 0.55, mullion);
	EMISSION = lit_color.rgb * lit * lit_intensity;
}
