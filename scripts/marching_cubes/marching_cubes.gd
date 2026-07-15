# TODO: SERIOUS refactorization

class_name MarchingCubes
extends Node3D

@export_group("Generation Settings")
@export var start_at := Vector3(-50,-50,-50)
@export var chunk_size := 20
@export var chunks_amount := Vector3i(5,5,5)

# Updates the internal mesh generator's reference and re-initializes the generator 
# whenever a new density generator is assigned. This ensures the node is fully 
# synchronized with the exported resource.
@export var density_generator : DensityGenerator = PlanetDensityGenerator.new():
	set(val):
		density_generator = val
		if is_node_ready() and mesh_generator != null:
			mesh_generator.density_generator = density_generator
			if density_generator:
				density_generator.initialize()

# Updates the internal mesh generator's reference whenever a new color generator 
# is assigned. This ensures the node is fully synchronized with the exported resource 
# so color gradients are properly applied to the generated mesh.
@export var color_generator : ColorGenerator = RadialColorGenerator.new():
	set(val):
		color_generator = val
		if is_node_ready() and mesh_generator != null:
			mesh_generator.color_generator = color_generator

@export var mesh_material := StandardMaterial3D.new()

var mesh_generator := MarchingCubesMeshGeneratorV2.new()

var total_chunks := 0
var processed_chunks := 0

# Unique ID assigned to each regeneration cycle.
# Background tasks check this ID to discard their results if a newer generation has started.
var current_generation_id := 0

# Flag to prevent automatic generation in _ready().
# Used when creating new planets so properties can be set before the first generation.
var generation_paused := false

@onready var chunks_parent : Node3D = $Chunks

var chunks : Dictionary[Vector3i, Node3D] = {}

signal chunk_generation_started(chunk_coords : Vector3)
signal chunk_generation_finished(chunk_coords : Vector3, chunk_node : MeshInstance3D)
signal planet_generation_started()
signal planet_generation_finished()



func _ready() -> void:
	mesh_generator.density_generator = density_generator
	density_generator.initialize()
	
	if color_generator != null:
		mesh_material.vertex_color_use_as_albedo = true
	mesh_generator.color_generator = color_generator
	
	# Only auto-generate if not paused. 
	# New planets pause generation until their properties are fully initialized.
	if not generation_paused:
		regenerate()


func regenerate() -> void:
	# Increment the generation ID to invalidate any currently running background tasks
	current_generation_id += 1
	var gen_id = current_generation_id
	
	for ch in chunks_parent.get_children():
		ch.queue_free()
	
	chunks.clear()
	
	# Create isolated snapshots of generators for this specific generation.
	# This prevents race conditions where a background task reads a partially 
	# updated gradient or noise object while the user is changing properties.
	var gen_density = density_generator.duplicate()
	var gen_color = null
	if color_generator:
		gen_color = color_generator.duplicate()
	
	var gen_mesh_generator = MarchingCubesMeshGeneratorV2.new()
	gen_mesh_generator.iso_level = mesh_generator.iso_level
	gen_mesh_generator.density_generator = gen_density
	gen_mesh_generator.color_generator = gen_color
	
	# Initialize the duplicated density generator to build its internal noise object
	gen_density.initialize()
	
	_generate_preview(gen_mesh_generator)
	_generate_mesh(gen_id, gen_mesh_generator)


func is_fully_generated() -> bool:
	return total_chunks == processed_chunks

func _generate_mesh(gen_id: int, gen_mesh_generator: MarchingCubesMeshGeneratorV2) -> void:
	planet_generation_started.emit()
	processed_chunks = 0
	
	var chunk_coords := make_chunk_coords()
	total_chunks = chunk_coords.size()
	
	# Generate all chunks as async tasks
	# Tasks run in background and apply results via call_deferred
	# Completion is tracked by processed_chunks counter in _finalize_chunk
	for coord in chunk_coords:
		var start_pos := coord
		WorkerThreadPool.add_task(generate_chunk_task.bind(start_pos, chunk_size, gen_id, gen_mesh_generator))

func _generate_preview(gen_mesh_generator: MarchingCubesMeshGeneratorV2) -> void:
	# Generate a low-resolution preview mesh for each chunk
	# This gives instant visual feedback while the full mesh generates
	# Resolution of 20 means very coarse mesh (1 cube per 20 units)
	for chunk_pos in make_chunk_coords():
		var arrays := gen_mesh_generator.generate_mesh_arrays(chunk_pos, chunk_size, 20)
		_apply_chunk_mesh(chunk_pos, arrays)


func make_chunk_coords() -> PackedVector3Array:
	# TODO: TEMPORARY!
	var chunk_coords : PackedVector3Array = []
	for chunk_x in chunks_amount.x:
		for chunk_y in chunks_amount.y:
			for chunk_z in chunks_amount.z:
				var chunk_coord := start_at + Vector3(
					chunk_size*chunk_x,
					chunk_size*chunk_y,
					chunk_size*chunk_z
				)
				
				chunk_coords.append(chunk_coord)
	
	return chunk_coords


func generate_chunk_task(start_pos : Vector3, size : int, gen_id : int, gen_mesh_generator: MarchingCubesMeshGeneratorV2) -> void:
	# Discard the task if it belongs to an outdated generation
	if gen_id != current_generation_id:
		return
		
	chunk_generation_started.emit.call_deferred(start_pos)
	var arrays := gen_mesh_generator.generate_mesh_arrays(start_pos, size)
	
	# Check if mesh has valid data
	# Both vertices AND indices must be non-empty for a valid mesh
	# Chunks entirely inside or outside the surface will have empty arrays
	var has_vertices := not (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty()
	var has_indices := not (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty()
	
	if has_vertices and has_indices:
		call_deferred("_apply_chunk_mesh_and_finailize", start_pos, arrays, gen_id)
	else:
		# No mesh data (chunk is fully solid or fully empty)
		call_deferred("_finalize_chunk", start_pos, null, gen_id)


func _apply_chunk_mesh(chunk_coord : Vector3i, arrays : Array) -> MeshInstance3D:
	if chunks.has(chunk_coord):
		chunks[chunk_coord].queue_free()
	
	var new_chunk := MeshInstance3D.new()
	new_chunk.position = chunk_coord
	chunks_parent.add_child(new_chunk)
	
	# Many chunks will have no surface crossings and will produce empty arrays
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	
	if vertices.is_empty() or indices.is_empty():
		# Store the empty chunk node and return
		chunks[chunk_coord] = new_chunk
		return new_chunk
	
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	# Verify that surface was created successfully
	if mesh.get_surface_count() == 0:
		chunks[chunk_coord] = new_chunk
		return new_chunk
	
	new_chunk.mesh = mesh
	
	# Collision 
	var body := StaticBody3D.new()
	new_chunk.add_child(body)
	
	var collision := CollisionShape3D.new()
	body.add_child(collision)
	
	# Create trimesh collision shape from generated mesh
	var trimesh_shape := mesh.create_trimesh_shape()
	if trimesh_shape != null:
		collision.shape = trimesh_shape
	else:
		collision.disabled = true
	
	new_chunk.mesh.surface_set_material(0, mesh_material)
	
	chunks[chunk_coord] = new_chunk
	return new_chunk


func _finalize_chunk(chunk_coords : Vector3i, chunk_node : MeshInstance3D, gen_id : int) -> void:
	# Discard results from outdated generations
	if gen_id != current_generation_id:
		return
		
	processed_chunks += 1
	
	chunk_generation_finished.emit(chunk_coords, chunk_node)
	
	if processed_chunks == total_chunks:
		planet_generation_finished.emit()


func _apply_chunk_mesh_and_finailize(chunk_coord : Vector3i, arrays : Array, gen_id : int) -> void:
	# Discard results from outdated generations
	if gen_id != current_generation_id:
		return
		
	var new_chunk := _apply_chunk_mesh(chunk_coord, arrays)
	_finalize_chunk(chunk_coord, new_chunk, gen_id)
