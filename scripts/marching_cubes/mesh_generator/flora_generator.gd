class_name FloraGenerator
extends Resource

# Enum defining how flora is distributed on the planet
enum DistributionMode {
	RANDOM,       # Uniform random distribution
	CLUSTERED     # Grouped distribution in clusters
}

@export var flora_entries : Array[FloraEntry] = []
@export var distribution_mode : DistributionMode = DistributionMode.RANDOM

# Probability (0.0 to 1.0) of spawning a plant at a valid raycast hit point
@export_range(0.0, 1.0, 0.01) var density : float = 0.5

# Maximum number of attempts to find a valid spawn point
@export var max_attempts : int = 500

@export_group("Cluster Settings")
# Radius around a cluster center where plants will spawn
@export var cluster_radius : float = 5.0
# Number of plants to spawn in a single cluster
@export var cluster_count : int = 10

@export_group("Transform Settings")
# If true, plants will be aligned to the surface normal (slopes)
@export var align_to_normal : bool = true
# If true, plants will be randomly rotated on the Y axis
@export var random_rotation_y : bool = true
# Minimum random scale multiplier
@export var scale_min : float = 0.8
# Maximum random scale multiplier
@export var scale_max : float = 1.2

var _rng := RandomNumberGenerator.new()


func initialize(p_seed: int) -> void:
	# Assign the generation seed for deterministic results
	_rng.seed = p_seed


# Main function to generate flora for the whole planet
func generate(planet_node: Node3D, planet_radius: float, water_radius: float, parent_node: Node3D) -> void:
	if flora_entries.is_empty():
		return

	var space_state = planet_node.get_world_3d().direct_space_state
	var planet_center = planet_node.global_position

	match distribution_mode:
		DistributionMode.RANDOM:
			_generate_random(space_state, planet_center, planet_radius, water_radius, parent_node)
		DistributionMode.CLUSTERED:
			_generate_clustered(space_state, planet_center, planet_radius, water_radius, parent_node)


# Generate flora uniformly at random within the chunk
func _generate_random(space_state: PhysicsDirectSpaceState3D, planet_center: Vector3, planet_radius: float, water_radius: float, parent_node: Node3D) -> void:
	var attempts := 0
	var spawned := 0
	var target_count := int(max_attempts * density)

	while spawned < target_count and attempts < max_attempts:
		attempts += 1

		var random_dir = Vector3(
			_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)
		).normalized()

		var start_pos = planet_center + (random_dir * (planet_radius * 1.5))
		var end_pos = planet_center

		var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
		query.collide_with_areas = false
		query.collide_with_bodies = true

		var result = space_state.intersect_ray(query)

		if result:
			var hit_pos = result.position
			var normal = result.normal
			var is_underwater = hit_pos.distance_to(planet_center) <= water_radius

			if _spawn_plant(hit_pos, normal, is_underwater, parent_node):
				spawned += 1


# Generate flora in groups (clusters) within the chunk
func _generate_clustered(space_state: PhysicsDirectSpaceState3D, planet_center: Vector3, planet_radius: float, water_radius: float, parent_node: Node3D) -> void:
	var attempts := 0
	var spawned_clusters := 0
	var target_clusters := int((max_attempts * density) / cluster_count)

	while spawned_clusters < target_clusters and attempts < max_attempts:
		attempts += 1

		var random_dir = Vector3(
			_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)
		).normalized()

		var start_pos = planet_center + (random_dir * (planet_radius * 1.5))
		var end_pos = planet_center

		var query = PhysicsRayQueryParameters3D.create(start_pos, end_pos)
		query.collide_with_areas = false
		query.collide_with_bodies = true

		var result = space_state.intersect_ray(query)

		if result:
			var cluster_center = result.position
			var cluster_normal = result.normal
			var is_underwater = cluster_center.distance_to(planet_center) <= water_radius

			# Check if we can spawn at least one plant in this area
			if _get_valid_entry(is_underwater) != null:
				spawned_clusters += 1
				
				# Spawn plants around the cluster center
				for i in range(cluster_count):
					var offset_x = _rng.randf_range(-cluster_radius, cluster_radius)
					var offset_z = _rng.randf_range(-cluster_radius, cluster_radius)
					
					# Raycast from the sky onto the offset position to find the ground
					var tangent_offset = Vector3(offset_x, 0, offset_z)
					var plant_start = cluster_center + (cluster_normal * 10.0) + tangent_offset
					var plant_end = plant_start - (cluster_normal * 15.0)

					var p_query = PhysicsRayQueryParameters3D.create(plant_start, plant_end)
					var p_result = space_state.intersect_ray(p_query)

					if p_result:
						var p_pos = p_result.position
						var p_norm = p_result.normal
						var p_underwater = p_pos.distance_to(planet_center) <= water_radius
						_spawn_plant(p_pos, p_norm, p_underwater, parent_node)


# Selects a random plant entry that is valid for the current water level
func _get_valid_entry(is_underwater: bool) -> FloraEntry:
	var valid_entries = []
	var total_weight = 0.0
	
	for entry in flora_entries:
		var matches = false
		match entry.spawn_area:
			FloraEntry.SpawnArea.SURFACE: matches = !is_underwater
			FloraEntry.SpawnArea.UNDERWATER: matches = is_underwater
			FloraEntry.SpawnArea.EVERYWHERE: matches = true
			
		if matches:
			valid_entries.append(entry)
			total_weight += entry.weight
			
	if valid_entries.is_empty() or total_weight <= 0.0:
		return null
		
	var r = _rng.randf_range(0.0, total_weight)
	for entry in valid_entries:
		r -= entry.weight
		if r <= 0.0:
			return entry
			
	return valid_entries.back()


func _spawn_plant(pos: Vector3, normal: Vector3, is_underwater: bool, parent_node: Node3D) -> bool:
	var entry = _get_valid_entry(is_underwater)
	if entry == null or entry.scene == null:
		return false

	var instance = entry.scene.instantiate() as Node3D
	parent_node.add_child(instance)

	instance.global_position = pos

	var plant_basis: Basis
	if align_to_normal:
		var axis = Vector3.UP.cross(normal)
		if axis.length_squared() > 0.001:
			axis = axis.normalized()
			var angle = Vector3.UP.angle_to(normal)
			plant_basis = Basis(axis, angle)
		else:
			plant_basis = Basis()
			if normal.y < 0:
				plant_basis = plant_basis.rotated(Vector3.RIGHT, PI) 
	else:
		plant_basis = Basis()

	if random_rotation_y:
		plant_basis = plant_basis.rotated(normal, _rng.randf() * TAU)

	instance.global_basis = plant_basis

	var random_scale = _rng.randf_range(scale_min, scale_max)
	instance.scale = Vector3(random_scale, random_scale, random_scale)
	return true
