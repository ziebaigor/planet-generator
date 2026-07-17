shader_type spatial;

render_mode blend_mix, depth_prepass_alpha;

uniform sampler2D depth_texture : hint_depth_texture;
uniform vec3 shallow_color : source_color = vec3(0.1, 0.8, 1.0);
uniform vec3 deep_color : source_color = vec3(0.0, 0.25, 0.7);
uniform float depth_max = 25.0;

// Waves
uniform sampler2D wave_normal;
uniform float wave_height = 0.02;
uniform float wave_speed = 1.2;
uniform float wave_scale = 0.2;

// Specular
uniform float normal_scale = 0.25;
uniform float specular_exponent = 32.0;
// Direction from the water surface towards the sun, in world space
uniform vec3 specular_light_dir = vec3(0.3, 0.8, 0.2);

void vertex() {
	float t = TIME * wave_speed;
	
	// Double wave
	float wave1 = sin(VERTEX.x * wave_scale + t);
	float wave2 = cos(VERTEX.z * wave_scale * 0.8 + t * 1.2);
	
	float combined_wave = (wave1 + wave2) * 0.5;
	
	VERTEX += NORMAL * combined_wave * wave_height;
}


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
	
	
	// Wave reflections + normal map
	vec2 wave_uv = UV + TIME * vec2(0.005, 0.003);
	vec3 wave_normal_sample = texture(wave_normal, wave_uv).rgb;
	wave_normal_sample = wave_normal_sample * 2.0 - 1.0; // 0, 1 -> -1, 1
	
	vec3 final_normal = normalize(NORMAL + wave_normal_sample * normal_scale);
	
	// The light direction is given in world space, while NORMAL and VIEW are
	// in view space, so it has to be transformed before lighting calculations
	vec3 light_dir = normalize((VIEW_MATRIX * vec4(specular_light_dir, 0.0)).xyz);
	
	vec3 half_vector = normalize(light_dir + VIEW);
	float spec = pow(max(dot(final_normal, half_vector), 0.0), specular_exponent);
	
	spec = smoothstep(0.0, 1.0, spec);
	spec = floor(spec * 4.0) / 4.0; // banding
	water_color += spec * 0.8;
	
	
	ALBEDO = water_color;
	ALPHA = 0.85;
}