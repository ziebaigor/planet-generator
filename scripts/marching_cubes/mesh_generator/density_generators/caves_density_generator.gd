class_name CavesDensityGenerator
extends DensityGenerator

@export var noise_frequency : float = 0.05
@export var noise_octaves : int = 2
@export var noise_lacunarity : float = 2.0
@export var noise_gain : float = 0.5

# Controls how "thick" caves are.
# Lower = more solid, Higher = more empty
@export var surface_threshold : float = 0.2

var noise : FastNoiseLite

func initialize() -> void:
	randomize()
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = noise_frequency
	noise.fractal_octaves = noise_octaves
	noise.fractal_lacunarity = noise_lacunarity
	noise.fractal_gain = noise_gain

func get_density(pos: Vector3) -> float:
	var n = noise.get_noise_3d(pos.x, pos.y, pos.z)
	
	# FastNoiseLite returns roughly [-1, 1]
	# We treat 0 as the isosurface
	return n - surface_threshold
