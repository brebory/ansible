shader_type canvas_item;

// Neon Spaghetti Western holographic scanline & edge-glow shader (WebGL2 safe)
uniform vec4 base_tint : source_color = vec4(0.07, 0.04, 0.12, 0.88);
uniform vec4 glow_color : source_color = vec4(1.0, 0.70, 0.28, 1.0);
uniform float scanline_density : hint_range(20.0, 300.0) = 110.0;
uniform float scanline_alpha : hint_range(0.0, 0.35) = 0.08;
uniform float flicker_strength : hint_range(0.0, 0.15) = 0.025;

void fragment() {
	float scan = sin(UV.y * scanline_density + TIME * 3.5) * 0.5 + 0.5;
	float edge_x = min(UV.x, 1.0 - UV.x);
	float edge_y = min(UV.y, 1.0 - UV.y);
	float border = 1.0 - smoothstep(0.0, 0.035, min(edge_x, edge_y));
	float pulse = 1.0 + sin(TIME * 4.2) * flicker_strength;

	vec3 col = base_tint.rgb * pulse;
	col += glow_color.rgb * (scan * scanline_alpha);
	col = mix(col, glow_color.rgb, border * 0.45);
	COLOR = vec4(col, base_tint.a);
}
