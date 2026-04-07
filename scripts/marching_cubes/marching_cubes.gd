class_name MarchingCubes
extends Node3D

@export_group("Generation Settings")
@export var start_at := Vector3(-50,-50,-50)
@export var chunk_size := 20
@export var chunks := Vector3i(5,5,5)
@export var density_generator : DensityGenerator = PlanetDensityGenerator.new()
@export var color_generator : ColorGenerator = RadialColorGenerator.new()
@export var normal_type := MarchingCubesMeshGenerator.NORMAL_TYPE.SMOOTH

var mesh_generator := MarchingCubesMeshGenerator.new()

# If processed_chunks == total_chunks the mesh is fully generated
var total_chunks := 0
var processed_chunks := 0

@onready var chunks_parent : Node3D = $Chunks

var mat := StandardMaterial3D.new()

signal chunk_generation_started(chunk_coords : Vector3)
signal chunk_generation_finished(chunk_coords : Vector3)
signal planet_generation_started()
signal planet_generation_finished()


func _ready() -> void:
	mesh_generator.density_generator = density_generator
	density_generator.initialize()
	
	mat.vertex_color_use_as_albedo = true
	mesh_generator.color_generator = color_generator
	
	mesh_generator.normal_type = normal_type
	
	regenerate_mesh()


func regenerate_mesh() -> void:
	# Delete old chunks
	for ch in chunks_parent.get_children():
		ch.queue_free()
	
	planet_generation_started.emit()
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
	chunk_generation_started.emit.call_deferred(start_pos)
	var arrays := mesh_generator.generate_mesh_arrays(start_pos, chunk_size)
	
	if arrays[0].size() != 0:
		call_deferred("_apply_chunk_mesh", start_pos, arrays)
	else:
		call_deferred("_finalize_chunk", start_pos)


func _apply_chunk_mesh(chunk_coord : Vector3, arrays : Array) -> void:
	var new_chunk := MeshInstance3D.new()
	new_chunk.position = chunk_coord
	chunks_parent.add_child(new_chunk)
	
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	new_chunk.mesh = mesh
	
	# Collision 
	var body := StaticBody3D.new()
	new_chunk.add_child(body)
	
	var collision := CollisionShape3D.new()
	body.add_child(collision)
	collision.shape = mesh.create_trimesh_shape()
	
	# Material
	new_chunk.mesh.surface_set_material(0, mat)
	
	_finalize_chunk(chunk_coord)


func _finalize_chunk(chunk_coords : Vector3) -> void:
	processed_chunks += 1
	chunk_generation_finished.emit(chunk_coords)
	
	if processed_chunks == total_chunks:
		planet_generation_finished.emit()
