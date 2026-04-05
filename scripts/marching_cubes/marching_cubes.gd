class_name MarchingCubes
extends Node3D

@export_group("Generation Settings")
@export var start_at := Vector3(-50,-50,-50)
@export var chunk_size := 20
@export var chunks := Vector3i(5,5,5)
@export var density_generator : DensityGenerator = PlanetDensityGenerator.new()

@export_group("Gravity Settings")
@export var gravity_radius_multiplier := 1.5
@export var gravity_strength := 20.0
@export var constant_gravity := false

var mesh_generator := MarchingCubesMeshGenerator.new()

# If processed_chunks == total_chunks the planet is fully generated
var total_chunks := 0
var processed_chunks := 0

@onready var gravity_source : GravitySource = $GravitySource
@onready var chunks_parent : Node3D = $Chunks


func _ready() -> void:
	mesh_generator.density_generator = density_generator
	density_generator.initialize()
	
	# Set variables in GravitySource
	if density_generator is PlanetDensityGenerator:
		gravity_source.planet_radius = density_generator.base_radius
		
	gravity_source.gravity_radius_multiplier = gravity_radius_multiplier
	gravity_source.gravity_strength = gravity_strength
	gravity_source.constant_gravity = constant_gravity
	
	regenerate_mesh()


func regenerate_mesh() -> void:
	# Delete old chunks
	for ch in chunks_parent.get_children():
		ch.queue_free()
	
	processed_chunks = 0
	
	# TODO: TEMPORARY!
	var chunk_coords : PackedVector3Array = []
	for chunk_x in chunks.x:
		for chunk_y in chunks.y:
			for chunk_z in chunks.z:
				var chunk_coord := start_at + Vector3(
					chunk_size*chunk_x,
					chunk_size*chunk_y,
					chunk_size*chunk_z
				)
				
				chunk_coords.append(chunk_coord)
	
	total_chunks = chunk_coords.size()
	
	var tasks : Array = []
	for coord in chunk_coords:
		var start_pos := coord
		WorkerThreadPool.add_task(generate_chunk_task.bind(start_pos))
	
	for task in tasks:
		WorkerThreadPool.wait_for_task_completion(task)


func generate_chunk_task(start_pos : Vector3) -> void:
	var arrays := mesh_generator.generate_mesh_arrays(start_pos, chunk_size)
	
	if arrays[0].size() != 0:
		call_deferred("_apply_chunk_mesh", start_pos, arrays)
	else:
		call_deferred("_finalize_chunk")


func _apply_chunk_mesh(chunk_coord : Vector3, arrays : Array) -> void:
	var new_chunk := MeshInstance3D.new()
	new_chunk.position = chunk_coord
	chunks_parent.add_child(new_chunk)
	
	new_chunk.mesh = ArrayMesh.new()
	new_chunk.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	#new_chunk.material_override = mat
	
	# Add collisions
	new_chunk.create_trimesh_collision()
	
	_finalize_chunk()


func _finalize_chunk() -> void:
	processed_chunks += 1
	if processed_chunks == total_chunks:
		gravity_source.generation_done()
