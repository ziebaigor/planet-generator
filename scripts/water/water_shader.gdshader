shader_type spatial;

render_mode blend_mix, depth_prepass_alpha;

uniform sampler2D depth_texture : hint_depth_texture;
uniform vec3 shallow_color : source_color = vec3(0.1, 0.8, 1.0);
uniform vec3 deep_color : source_color = vec3(0.0, 0.25, 0.7);
uniform float depth_max = 25.0;

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(
		SCREEN_UV * 2.0 - 1.0,
		depth
	);
	
	// ???
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;
	
	float terrain_depth = -view_pos.z;
	float water_surface_depth = -VERTEX.z;
	
	float water_depth = terrain_depth - water_surface_depth;
	water_depth = max(water_depth, 0.0);
	
	// Depth blending
	float depth_blend = clamp(water_depth / depth_max, 0.0, 1.0);
	vec3 water_color = mix(shallow_color, deep_color, depth_blend);
	
	// Fresnel
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	water_color += fresnel * 0.25;
	
	ALBEDO = water_color;
	ALPHA = 0.85;
}