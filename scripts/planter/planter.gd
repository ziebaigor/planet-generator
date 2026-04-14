class_name Planter
extends Node3D

var planet_radius : float = 0.0
var radius_multiplier : float = 1.5
var radius : float = 0.0

var target_bodies : Array[CollisionObject3D] = []

@export var plant_scenes : Array[PackedScene]
@export var plant_count : int = 500


func initialize():
	radius = planet_radius * radius_multiplier
	
	var root_node = get_parent()
	_find_all_physics_bodies(root_node)
	
	if not target_bodies.is_empty():
		call_deferred("_generate_plants")
	else:
		push_error("Planter: Not found any physics body in root node!")


func _find_all_physics_bodies(node: Node):
	if node is CollisionObject3D:
		target_bodies.append(node)
		
	for child in node.get_children():
		_find_all_physics_bodies(child)


func _generate_plants():
	if plant_scenes.is_empty():
		push_error("Planter: Not added any plants!")
		return

	var space_state = get_world_3d().direct_space_state
	var plants_placed = 0
	var attempts = 0
	var max_attempts = plant_count * 3
	
	while plants_placed < plant_count and attempts < max_attempts:
		attempts += 1
		
		var random_dir = Vector3(
			randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
		).normalized()
		
		var planet_center = get_parent().global_position
		var start_pos = planet_center + (random_dir * radius)
		var end_pos = planet_center 
		
		var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
		var result = space_state.intersect_ray(query)
		
		if result and result.collider in target_bodies:
			var hit_position = result.position
			var surface_normal = result.normal
			
			_spawn_plant(hit_position, surface_normal)
			plants_placed += 1

	if plants_placed < plant_count:
		print("Planter: Plant attempts limit reached! Planted ", plants_placed, "/", plant_count, " objects.")


func _spawn_plant(pos: Vector3, normal: Vector3):
	var random_plant_scene = plant_scenes.pick_random()
	var plant = random_plant_scene.instantiate() as Node3D
	add_child(plant)

	plant.global_position = pos
	plant.scale *= 1.5
	
	var axis = Vector3.UP.cross(normal)
	var plant_basis: Basis

	if axis.length_squared() > 0.001:
		axis = axis.normalized()
		var angle = Vector3.UP.angle_to(normal)
		plant_basis = Basis(axis, angle)
	else:
		plant_basis = Basis()
		if normal.y < 0:
			plant_basis = plant_basis.rotated(Vector3.RIGHT, PI) 

	plant_basis = plant_basis.rotated(normal, randf_range(0, TAU))
	plant.global_basis = plant_basis

	var random_scale = randf_range(0.8, 1.5)
	plant.scale = Vector3(random_scale, random_scale, random_scale)
