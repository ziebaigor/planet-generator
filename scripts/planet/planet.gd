class_name Planet
extends MarchingCubes

@export var radius := 30.0:
	set(val):
		radius = val
		if is_node_ready():
			_update_radius()

@export_group("Gravity Settings")
@export var gravity_radius_multiplier := 1.5:
	set(val):
		gravity_radius_multiplier = val
		if is_node_ready():
			gravity_source.gravity_radius_multiplier = gravity_radius_multiplier

@export var gravity_strength := 20.0:
	set(val):
		gravity_strength = val
		if is_node_ready():
			gravity_source.gravity_strength = gravity_strength

@export var constant_gravity := false:
	set(val):
		constant_gravity = val
		if is_node_ready():
			gravity_source.constant_gravity = constant_gravity

@export_group("Water Settings")
@export var generate_water := true:
	set(val):
		generate_water = val
		if is_node_ready():
			_update_water_radius()

# Multiplier for the water sphere radius. 
# 1.0 aligns the water level exactly with the planet's base radius.
@export var water_radius_mult := 1.0:
	set(val):
		water_radius_mult = val
		if is_node_ready():
			_update_water_radius()

@export var water_color := Color(0.059, 0.592, 1.0):
	set(val):
		water_color = val
		if is_node_ready():
			_update_water_color()

@export var directional_light : DirectionalLight3D:
	set(val):
		directional_light = val
		if is_node_ready():
			_update_water_color()

@export_group("Flora Settings")
@export var flora_generator : FloraGenerator

@onready var gravity_source : GravitySource = $GravitySource
@onready var water : MeshInstance3D = $Water

var flora_parent : Node3D

# Duplicated water material cached after _update_water_color,
# used to update the light direction without creating new copies.
var _water_material : ShaderMaterial


func _ready() -> void:
	# Apply all initial property values now that the node is ready
	_update_radius()
	gravity_source.gravity_radius_multiplier = gravity_radius_multiplier
	gravity_source.gravity_strength = gravity_strength
	gravity_source.constant_gravity = constant_gravity
	
	_update_water_radius()
	_update_water_color()
	
	# Setup parent node for flora instances
	if flora_generator:
		flora_parent = Node3D.new()
		flora_parent.name = "Flora"
		add_child(flora_parent)
	
	super._ready()


func _process(_delta: float) -> void:
	# Keep the water reflections aligned with the current sun position
	_update_water_light_dir()

# Consolidates radius update logic to be called from setter and _ready
func _update_radius() -> void:
	# Chunk grid size scales with the planet's radius
	var num_chunks := int(radius / 10) + 2
	chunks_amount = Vector3i(num_chunks, num_chunks, num_chunks)
	var st := -num_chunks * 10
	start_at = Vector3i(st, st, st)
	
	# Sync radius with the density generator, regardless of which version is used
	if "base_radius" in density_generator:
		density_generator.base_radius = radius
	elif "planet_size" in density_generator:
		density_generator.planet_size = radius * 2.0
	elif "radius" in density_generator:
		density_generator.radius = radius
	
	gravity_source.planet_radius = radius
	_update_water_radius()


func regenerate() -> void:
	# Clear old flora immediately when regeneration starts
	if is_instance_valid(flora_parent):
		for child in flora_parent.get_children():
			child.queue_free()
	
	super.regenerate()

# Regenerates only the flora without rebuilding the terrain mesh.
# Used when flora settings or water level are changed in the UI.
func regenerate_flora() -> void:
	if is_instance_valid(flora_parent):
		for child in flora_parent.get_children():
			child.queue_free()
	
	# Only generate if the terrain is fully generated
	if flora_generator and flora_parent and is_fully_generated():
		var seed_val = randi()
		if "random_seed" in density_generator:
			seed_val = density_generator.random_seed
		flora_generator.initialize(seed_val)
		
		var water_r = radius * water_radius_mult
		if !generate_water:
			water_r = 0.0
		
		# Defer generation to ensure physics shapes are registered in the physics server
		call_deferred("_generate_flora", water_r)


func _finalize_chunk(chunk_coords : Vector3i, chunk_node : MeshInstance3D, gen_id : int) -> void:
	super._finalize_chunk(chunk_coords, chunk_node, gen_id)
	
	# Skip flora generation if this chunk belongs to an outdated generation
	if gen_id != current_generation_id:
		return
		
	if processed_chunks == total_chunks:
		gravity_source.generation_done()
		
		# Generate flora after the whole planet and collisions are fully generated
		if flora_generator and flora_parent:
			var seed_val = randi()
			if "random_seed" in density_generator:
				seed_val = density_generator.random_seed
			flora_generator.initialize(seed_val)
			
			var water_r = radius * water_radius_mult
			if !generate_water:
				water_r = 0.0
			
			# Defer generation to ensure physics shapes are registered in the physics server
			call_deferred("_generate_flora", water_r)

func _generate_flora(water_r: float) -> void:
	if is_instance_valid(flora_generator) and is_instance_valid(flora_parent):
		flora_generator.generate(self, radius, water_r, flora_parent)


func _update_water_radius() -> void:
	var water_r := radius * water_radius_mult
	water.visible = generate_water
	water.get_node("WaterArea").set_enabled(generate_water)
	
	if !generate_water:
		water_r = 1
	
	# A default SphereMesh has a radius of 0.5, so scaling by 2.0 matches the visual radius to the target value.
	var scale_factor = water_r * 2.0
	var scale_vec = Vector3(scale_factor, scale_factor, scale_factor)
	water.scale = scale_vec
	
	var water_backside = get_node_or_null("WaterBackside")
	if water_backside:
		water_backside.scale = scale_vec

func _update_water_color() -> void:
	var deep_color := _make_deep_water_color(water_color)
	water.get_node("WaterArea").water_tint_color = Color(deep_color, 0.4)
	
	var mat = water.get_active_material(0)
	mat = mat.duplicate()
	water.set_surface_override_material(0, mat)
	mat.set_shader_parameter("shallow_color", water_color)
	mat.set_shader_parameter("deep_color", deep_color)
	
	# Cache the duplicated material so the light direction can be updated
	# every frame without creating new copies
	_water_material = mat
	_update_water_light_dir()

# Updates the water shader with the current direction towards the sun,
# so the specular reflections follow the sun across the sky.
func _update_water_light_dir() -> void:
	if directional_light and _water_material:
		var sun_dir = directional_light.global_transform.basis.z.normalized()
		_water_material.set_shader_parameter("specular_light_dir", sun_dir)


func _make_deep_water_color(shallow: Color, value_mul := 0.6, hue_shift := -0.04, saturation_mul := 1.35) -> Color:
	var h = shallow.h
	var s = shallow.s
	var v = shallow.v
	
	# Shift hue for visual variety
	h = wrapf(h + hue_shift, 0.0, 1.0)
	
	# Increase saturation and darken the color for deep water effect
	s = clamp(s * saturation_mul, 0.0, 1.0)
	v = clamp(v * value_mul, 0.0, 1.0)
	
	return Color.from_hsv(h, s, v, shallow.a)
