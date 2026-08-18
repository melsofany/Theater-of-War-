; Shop-sign shader (procedural signage, CC0, offline). Emits a warm glow band so
; shop signs read as lit signage on building ground floors.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform float text_idx = 0.0;

void fragment() {
	ALBEDO = vec3(0.85, 0.75, 0.25);
	EMISSION = vec3(0.9, 0.7, 0.2) * 0.6;
	ROUGHNESS = 0.4;
}
