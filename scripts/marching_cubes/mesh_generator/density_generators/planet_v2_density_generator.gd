class_name PlanetV2DensityGenerator
extends DensityGenerator

@export var random_seed : int = 0

@export_category("Main parameters")
@export var base_radius : float = 30.0
@export var noise_amplitude : float = 1.0
@export var noise_frequency : float = 0.05
@export var noise_octaves : int = 4
@export var noise_lacunarity : float = 2.0
@export var noise_gain : float = 0.5

@export_category("Cave parameters")
#@export var cave_radius : float = 2.5
@export var cave_threshold : float = 0.4
@export var cave_frequency : float = 0.08
@export var cave_strength : float = 8.0
@export var cave_warp_strength : float = 6.0
@export var cave_lacunarity : float = 2.0


var noise_main : FastNoiseLite
var cave_noise : FastNoiseLite




func initialize() -> void:
	seed(random_seed)
	
	# Terrain noise
	noise_main = FastNoiseLite.new()
	noise_main.seed = random_seed
	noise_main.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_main.frequency = noise_frequency
	noise_main.fractal_octaves = noise_octaves
	noise_main.fractal_lacunarity = noise_lacunarity
	noise_main.fractal_gain = noise_gain
	
	# Cave noise (separate field)
	cave_noise = FastNoiseLite.new()
	cave_noise.seed = random_seed
	cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cave_noise.frequency = cave_frequency
	cave_noise.fractal_octaves = 3
	cave_noise.fractal_lacunarity = cave_lacunarity
	cave_noise.fractal_gain = 0.5


func get_density(pos: Vector3) -> float:
	var dist = pos.length()

	# --- Base planet ---
	var n = noise_main.get_noise_3d(pos.x, pos.y, pos.z)
	var displacement = n * noise_amplitude
	var radius = base_radius + displacement

	var planet_density = dist - radius   # < 0 -> inside

	# --- Early exit: don't touch empty space ---
	if planet_density > 0.0:
		return planet_density

	# --- Cave field (true volumetric mask) ---

	# Domain warp → gives "worm-like" flow
	var warp = Vector3(
		cave_noise.get_noise_3d(pos.x, pos.y, pos.z),
		cave_noise.get_noise_3d(pos.y, pos.z, pos.x),
		cave_noise.get_noise_3d(pos.z, pos.x, pos.y)
	) * cave_warp_strength

	var p = pos + warp

	# Main cave noise
	var c = cave_noise.get_noise_3d(p.x, p.y, p.z)

	# Convert to "tube" field
	var cave_field = abs(c)

	# Turn into signed distance-like value
	var cave_density = cave_field - cave_threshold

	# --- Boolean subtraction ---
	# max() = subtract cave from solid
	return max(planet_density, -cave_density * cave_strength)
