shader_type sky;

// Sun disk, drawn exactly where the sunlight comes from.
// The parameters are updated by the SunSystem every frame.
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_angular_size = 0.066;
uniform float sun_intensity = 3.0;
uniform float sun_halo_strength = 0.25;

// Stars
uniform float star_brightness = 1.0;
uniform float star_twinkle : hint_range(0.0, 1.0) = 0.5;

// Background color of space
uniform vec3 space_color : source_color = vec3(0.0, 0.0, 0.0);

// Pseudo-random vector for a grid cell
vec3 hash33(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yxz + 19.19);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// One layer of stars placed on a 3D grid over the view direction.
// scale controls the star frequency, density controls how many cells
// contain a star and size controls the star radius.
float star_layer(vec3 dir, float scale, float density, float size) {
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	vec3 rnd = hash33(cell);
	
	// Only some cells contain a star
	if (rnd.x > density) {
		return 0.0;
	}
	
	// Position of the star inside its cell
	vec3 star_pos = cell + 0.5 + (rnd - 0.5) * 0.6;
	float dist = length(p - star_pos);
	
	// Small round point with a soft edge
	float star = 1.0 - smoothstep(0.0, size, dist);
	
	// Per-star brightness with a gentle twinkle over time
	float brightness = 0.4 + 0.6 * rnd.y;
	float twinkle = 1.0 - star_twinkle * 0.5 * (0.5 + 0.5 * sin(TIME * (1.0 + rnd.z * 4.0) + rnd.x * 40.0));
	
	return star * brightness * twinkle;
}

void sky() {
	vec3 dir = EYEDIR;
	vec3 col = space_color;
	
	// Two layers of stars: many small dim ones and a few bigger bright ones
	float stars = 0.0;
	stars += star_layer(dir, 60.0, 0.08, 0.12);
	stars += star_layer(dir + 31.7, 25.0, 0.03, 0.2) * 1.6;
	col += vec3(stars) * star_brightness;
	
	// Sun disk with a soft edge, drawn over the stars
	float sun_dot = max(dot(dir, normalize(sun_direction)), 0.0);
	float disk = smoothstep(cos(sun_angular_size * 1.1), cos(sun_angular_size * 0.9), sun_dot);
	col = mix(col, sun_color * sun_intensity, disk);
	
	// Subtle halo around the disk
	col += sun_color * pow(sun_dot, 64.0) * sun_halo_strength * (1.0 - disk);
	
	COLOR = col;
}