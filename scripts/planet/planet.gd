extends MarchingCubes

@export var radius := 30

@export_group("Gravity Settings")
@export var gravity_radius_multiplier := 1.5
@export var gravity_strength := 20.0
@export var constant_gravity := false

@onready var gravity_source : GravitySource = $GravitySource


func _ready() -> void:
	if "radius" in density_generator:
		density_generator.base_radius = radius
	
	# Gravity source
	gravity_source.planet_radius = radius
	
	gravity_source.gravity_radius_multiplier = gravity_radius_multiplier
	gravity_source.gravity_strength = gravity_strength
	gravity_source.constant_gravity = constant_gravity
	
	super._ready()


func _finalize_chunk(chunk_coords : Vector3) -> void:
	super._finalize_chunk(chunk_coords)
	if processed_chunks == total_chunks:
		gravity_source.generation_done()
