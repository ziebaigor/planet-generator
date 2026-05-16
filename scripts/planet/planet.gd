extends MarchingCubes

@export var radius := 30

@export_group("Gravity Settings")
@export var gravity_radius_multiplier := 1.5
@export var gravity_strength := 20.0
@export var constant_gravity := false

@export_group("Water Settings")
@export var generate_water := true
@export var water_radius_mult := 2.0

@onready var gravity_source : GravitySource = $GravitySource
@onready var water : MeshInstance3D = $Water
@onready var water_b : MeshInstance3D = $WaterBackside



func _ready() -> void:
	if "radius" in density_generator:
		density_generator.base_radius = radius
	
	# Gravity source
	gravity_source.planet_radius = radius
	
	gravity_source.gravity_radius_multiplier = gravity_radius_multiplier
	gravity_source.gravity_strength = gravity_strength
	gravity_source.constant_gravity = constant_gravity
	
	# Water
	var water_r := radius * water_radius_mult
	if !generate_water:
		water_r = 1
		water.hide()
		water.get_node("WaterArea").set_enabled(false)
		water_b.hide()
	
	water.scale = Vector3(water_r,water_r,water_r)
	water_b.scale = Vector3(water_r,water_r,water_r)
	
	super._ready()


func _finalize_chunk(chunk_coords : Vector3, chunk_node : MeshInstance3D) -> void:
	super._finalize_chunk(chunk_coords, chunk_node)
	if processed_chunks == total_chunks:
		gravity_source.generation_done()
