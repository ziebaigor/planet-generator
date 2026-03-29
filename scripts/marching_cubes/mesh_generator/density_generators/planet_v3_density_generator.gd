## Uses FBM Generation.
class_name PlanetV3DensityGenerator
extends DensityGenerator

@export var use_seed := true
@export var random_seed : int = 0

@export var planet_size : float = 100.0   # full diameter
@export var noise_scale : float = 1.0
@export var noise_height_multiplier : float = 0.5
## Value used to "sharpen" the edges of the noise - the absolute value of the final
## noise is raised to the power equal to this value. Smaller values mean more
## sharpening. A value of 1.0 results in a linear relationship (no sharpening).
@export_range(0.001, 1.00, 0.001) var sharpen : float = 0.7

var noise: FastNoiseLite

func initialize() -> void:
	if(use_seed):
		seed(random_seed)
	else:
		randomize()
		random_seed = randi()
	
	noise = FastNoiseLite.new()
	noise.seed = random_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	noise.frequency = noise_scale / 100.0


func get_density(pos: Vector3) -> float:
	# Match shader scaling
	var r = planet_size * 0.5
	var max_d = Vector3(r, r, r).length()
	
	# Base spherical falloff
	var density = pos.length() / (max_d + 1.0) - 0.5
	
	# Noise
	var n := noise.get_noise_3d(
		pos.x,
		pos.y,
		pos.z
	) * noise_height_multiplier
	
	n = sign(n) * pow(abs(n), sharpen)
	density += n
	
	return density
