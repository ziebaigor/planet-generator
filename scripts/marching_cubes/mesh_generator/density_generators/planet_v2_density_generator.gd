class_name PlanetV2DensityGenerator
extends DensityGenerator

@export var base_radius : float = 30.0
@export var noise_amplitude : float = 1.0
@export var noise_frequency : float = 0.05
@export var noise_octaves : int = 4
@export var noise_lacunarity : float = 2.0
@export var noise_gain : float = 0.5

var noise : FastNoiseLite

func initialize() -> void:
	randomize()
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_frequency
	noise.fractal_octaves = noise_octaves
	noise.fractal_lacunarity = noise_lacunarity
	noise.fractal_gain = noise_gain

func get_density(pos: Vector3) -> float:
	# Distance from (0,0,0)
	var dist := pos.length()
	var density := dist - base_radius

	density += noise.get_noise_3d(pos.x, pos.y, pos.z) * noise_amplitude
	
	return density
