class_name PlanetDensityGenerator
extends DensityGenerator

@export var random_seed : int = 0
@export var radius : float = 30.0
@export var noise_amplitude : float = 1.0

@export var noise_frequency : float = 0.05:
	set(val):
		noise_frequency = val
		if noise:
			noise.frequency = noise_frequency

@export var noise_octaves : int = 4:
	set(val):
		noise_octaves = val
		if noise:
			noise.fractal_octaves = noise_octaves

@export var noise_lacunarity : float = 2.0:
	set(val):
		noise_lacunarity = val
		if noise:
			noise.fractal_lacunarity = noise_lacunarity

@export var noise_gain : float = 0.5:
	set(val):
		noise_gain = val
		if noise:
			noise.fractal_gain = noise_gain

var noise : FastNoiseLite

func initialize() -> void:
	noise = FastNoiseLite.new()
	noise.seed = random_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = noise_frequency
	noise.fractal_octaves = noise_octaves
	noise.fractal_lacunarity = noise_lacunarity
	noise.fractal_gain = noise_gain

func get_density(pos: Vector3) -> float:
	# Distance from (0,0,0)
	var dist = pos.length()
	var n = noise.get_noise_3d(pos.x, pos.y, pos.z)
	
	# FastNoiseLite returns roughly [-1,1]
	var displacement = n * noise_amplitude
	var r = radius + displacement
	
	return dist - r
