shader_type spatial;
render_mode cull_back, diffuse_toon, specular_toon;

// 4-channel vertex-color mask recoloring for low-poly Drifter models (WebGL2 / Compatibility safe)
// COLOR.r = Primary garment (poncho / duster / carapace)
// COLOR.g = Accent trim (hatband / scarf / armor stripe)
// COLOR.b = Skin / alien chitin base
// COLOR.a = Emissive neon (visor / holo-brim / weapon core)
uniform vec4 primary_color : source_color = vec4(0.82, 0.28, 0.16, 1.0);
uniform vec4 accent_color : source_color = vec4(0.20, 0.96, 1.0, 1.0);
uniform vec4 skin_color : source_color = vec4(0.84, 0.66, 0.54, 1.0);
uniform vec4 emissive_color : source_color = vec4(1.0, 0.72, 0.25, 1.0);
uniform float emissive_strength : hint_range(0.0, 4.0) = 1.65;

uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 hit_flash_color : source_color = vec4(1.0, 0.92, 0.85, 1.0);

uniform float rim_amount : hint_range(0.0, 1.0) = 0.25;
uniform vec4 rim_color : source_color = vec4(0.20, 0.96, 1.0, 1.0);

void fragment() {
	float w_primary = COLOR.r;
	float w_accent = COLOR.g;
	float w_skin = COLOR.b;
	float w_emissive = COLOR.a;

	float base_sum = max(w_primary + w_accent + w_skin, 0.001);
	vec3 base_albedo = (
		primary_color.rgb * w_primary +
		accent_color.rgb * w_accent +
		skin_color.rgb * w_skin
	) / base_sum;

	// Blend emissive surfaces slightly into albedo too so unlit angles stay vivid
	base_albedo = mix(base_albedo, emissive_color.rgb, w_emissive * 0.65);

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.6);
	vec3 rim = rim_color.rgb * fresnel * rim_amount * 1.4;

	ALBEDO = mix(base_albedo, hit_flash_color.rgb, hit_flash);
	ROUGHNESS = 0.78;
	METALLIC = 0.08 + w_accent * 0.18;
	EMISSION = emissive_color.rgb * (w_emissive * emissive_strength) + rim + hit_flash_color.rgb * hit_flash * 1.1;
}
