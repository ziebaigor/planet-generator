extends MarchingCubes

@export var radius := 30

@export_group("Gravity Settings")
@export var gravity_radius_multiplier := 1.5
@export var gravity_strength := 20.0
@export var constant_gravity := false

@onready var gravity_source : GravitySource = $GravitySource


func _ready() -> void:
	# Density generator
	mesh_generator.density_generator = density_generator
	
	if "radius" in density_generator:
		density_generator.base_radius = radius
	
	density_generator.initialize()
	
	
	# Gravity source
	gravity_source.planet_radius = radius
	
	gravity_source.gravity_radius_multiplier = gravity_radius_multiplier
	gravity_source.gravity_strength = gravity_strength
	gravity_source.constant_gravity = constant_gravity
	
	
	# Color generator
	mat.vertex_color_use_as_albedo = true
	mesh_generator.color_generator = color_generator
	
	
	# Make mesh 
	regenerate_mesh()


func _finalize_chunk() -> void:
	super._finalize_chunk()
	if processed_chunks == total_chunks:
		gravity_source.generation_done()
