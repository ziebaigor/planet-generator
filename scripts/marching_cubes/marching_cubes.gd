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

var planet_radius : float = 0.0
var mesh_generator := MarchingCubesMeshGenerator.new()

# If processed_chunks == total_chunks the planet is fully generated
var total_chunks := 0
var processed_chunks := 0

@onready var chunks_parent : Node3D = $Chunks
@onready var gravity_shape : CollisionShape3D = $GravityZone/CollisionShape3D


func _ready() -> void:
	mesh_generator.density_generator = density_generator
	density_generator.initialize()
	
	# Disable gravity before the planet is fully generated
	gravity_shape.disabled = true
	
	regenerate_mesh()


func _on_gravity_zone_body_entered(body: Node3D) -> void:
	if body.has_method("add_gravity_source"):
		body.add_gravity_source(self)


func _on_gravity_zone_body_exited(body: Node3D) -> void:
	if body.has_method("remove_gravity_source"):
		body.remove_gravity_source(self)


func get_gravity_vector(object_position: Vector3) -> Vector3:
	if constant_gravity:
		# If constant gravity is set the gravity vector has always the same strength
		return (global_position - object_position).normalized() * gravity_strength
	else:
		# If else calculate gravity strength based on distance from planet center
		var calculated_strength := 0.0
		var direction := global_position - object_position
		var distance := direction.length()
		
		if distance == 0.0:
			return Vector3.ZERO
		
		if distance < planet_radius:
			# Object is below the planet surface
			# Strength decreases linearly (100% on surface and 0% in center)
			calculated_strength = gravity_strength * (distance / planet_radius)
		else:
			# Object is above the planet surface
			# Strength decreases quadratically
			var distance_ratio := planet_radius / distance
			calculated_strength = gravity_strength * (distance_ratio * distance_ratio)
		
		return direction.normalized() * calculated_strength


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
		processed_chunks += 1
		if processed_chunks == total_chunks:
			_update_gravity()


func _apply_chunk_mesh(chunk_coord : Vector3, arrays : Array) -> void:
	var new_chunk := MeshInstance3D.new()
	new_chunk.position = chunk_coord
	chunks_parent.add_child(new_chunk)
	
	new_chunk.mesh = ArrayMesh.new()
	new_chunk.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	#new_chunk.material_override = mat
	
	# Add collisions
	new_chunk.create_trimesh_collision()
	
	processed_chunks += 1
	if processed_chunks == total_chunks:
		_update_gravity()


func _update_gravity() -> void:
	# Get PlanetDensityGenerator base_radius value and set gravity zone radius
	if density_generator is PlanetDensityGenerator:
		planet_radius = density_generator.base_radius
		var sphere := SphereShape3D.new()
		sphere.radius = planet_radius * gravity_radius_multiplier
		gravity_shape.shape = sphere
		gravity_shape.disabled = false
	else:
		# Disable gravity zone if there is no planet radius
		gravity_shape.disabled = true
	
	print("Planet '", name, "' generation done!")
