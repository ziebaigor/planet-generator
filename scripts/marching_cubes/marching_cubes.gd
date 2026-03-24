class_name MarchingCubes
extends Node3D

@export var start_at := Vector3(-50,-50,-50)
@export var chunk_size := 20
@export var chunks := Vector3i(5,5,5)
@export var density_generator : DensityGenerator = PlanetDensityGenerator.new()
@export var gravity_radius_multiplier : float = 1.5
@export var gravity_strength : float = 20.0

var mesh_generator := MarchingCubesMeshGenerator.new()
@onready var chunks_parent : Node3D = $Chunks
@onready var gravity_shape : CollisionShape3D = $GravityZone/CollisionShape3D


func _ready() -> void:
	mesh_generator.density_generator = density_generator
	density_generator.initialize()
	
	regenerate_mesh()
	_update_gravity_radius()

func _update_gravity_radius() -> void:
	# Get PlanetDensityGenerator base_radius value and set gravity zone radius
	if density_generator is PlanetDensityGenerator:
		var planet_radius : float = density_generator.base_radius
		var sphere := SphereShape3D.new()
		sphere.radius = planet_radius * gravity_radius_multiplier
		gravity_shape.shape = sphere

func get_gravity_vector(from_position: Vector3) -> Vector3:
	return (global_position - from_position).normalized() * gravity_strength

func _on_gravity_zone_body_entered(body: Node3D) -> void:
	if body.has_method("set_gravity_source"):
		body.set_gravity_source(self)

func _on_gravity_zone_body_exited(body: Node3D) -> void:
	if body.has_method("clear_gravity_source"):
		body.clear_gravity_source(self)

func regenerate_mesh() -> void:
	# Delete old chunks
	for ch in chunks_parent.get_children():
		ch.queue_free()
	
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


func _apply_chunk_mesh(chunk_coord : Vector3, arrays : Array) -> void:
	var new_chunk := MeshInstance3D.new()
	new_chunk.position = chunk_coord
	chunks_parent.add_child(new_chunk)
	
	new_chunk.mesh = ArrayMesh.new()
	new_chunk.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	#new_chunk.material_override = mat
