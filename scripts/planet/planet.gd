class_name Planet
extends MarchingCubes

@export var radius := 30.0:
	set(val):
		if !is_node_ready():
			await ready
		
		radius = val
		
		# Chunk grid size
		var num_chunks := int(radius / 10) + 2
		chunks_amount = Vector3i(num_chunks, num_chunks, num_chunks)
		var st := -num_chunks * 10
		start_at = Vector3i(st, st, st)
		
		# Density Generator
		if "radius" in density_generator:
			density_generator.radius = radius
		
		# Gravity
		gravity_source.planet_radius = radius
		
		# Water
		_update_water_radius()

@export_group("Gravity Settings")
@export var gravity_radius_multiplier := 1.5:
	set(val):
		if !is_node_ready():
			await ready
		
		gravity_radius_multiplier = val
		gravity_source.gravity_radius_multiplier = gravity_radius_multiplier

@export var gravity_strength := 20.0:
	set(val):
		if !is_node_ready():
			await ready
		
		gravity_strength = val
		gravity_source.gravity_strength = gravity_strength

@export var constant_gravity := false:
	set(val):
		if !is_node_ready():
			await ready
		
		constant_gravity = val
		gravity_source.constant_gravity = constant_gravity

@export_group("Water Settings")
@export var generate_water := true:
	set(val):
		if !is_node_ready():
			await ready
		
		generate_water = val
		_update_water_radius()

@export var water_radius_mult := 2.0:
	set(val):
		if !is_node_ready():
			await ready
		
		water_radius_mult = val
		_update_water_radius()

@export var water_color := Color(0.059, 0.592, 1.0):
	set(val):
		if !is_node_ready():
			await ready
		
		water_color = val
		_update_water_color()

@export var directional_light : DirectionalLight3D:
	set(val):
		if !is_node_ready():
			await ready
		
		directional_light = val
		_update_water_color()

@onready var gravity_source : GravitySource = $GravitySource
@onready var water : MeshInstance3D = $Water




func _ready() -> void:
	if "radius" in density_generator:
		density_generator.radius = radius
	
	# Gravity source
	gravity_source.planet_radius = radius
	
	gravity_source.gravity_radius_multiplier = gravity_radius_multiplier
	gravity_source.gravity_strength = gravity_strength
	gravity_source.constant_gravity = constant_gravity
	
	# Water
	_update_water_radius()
	_update_water_color()
	
	super._ready()


func _finalize_chunk(chunk_coords : Vector3i, chunk_node : MeshInstance3D) -> void:
	super._finalize_chunk(chunk_coords, chunk_node)
	if processed_chunks == total_chunks:
		gravity_source.generation_done()


func _update_water_radius() -> void:
	var water_r := radius * water_radius_mult
	water.visible = generate_water
	water.get_node("WaterArea").set_enabled(generate_water)
	
	if !generate_water:
		water_r = 1
	
	water.scale = Vector3(water_r,water_r,water_r)

func _update_water_color() -> void:
	var deep_color := _make_deep_water_color(water_color)
	water.get_node("WaterArea").water_tint_color = Color(deep_color, 0.4)
	
	var mat = water.get_active_material(0)
	mat = mat.duplicate()
	water.set_surface_override_material(0, mat)
	mat.set_shader_parameter("shallow_color", water_color)
	mat.set_shader_parameter("deep_color", deep_color)
	
	if directional_light:
		var sun_dir = -directional_light.global_transform.basis.z.normalized()
		mat.set_shader_parameter("light_dir", sun_dir)


func _make_deep_water_color(shallow: Color, value_mul := 0.6, hue_shift := -0.04, saturation_mul := 1.35) -> Color:
	var h = shallow.h
	var s = shallow.s
	var v = shallow.v
	
	# Shift hue
	h = wrapf(h + hue_shift, 0.0, 1.0)
	
	# Increase saturation
	s = clamp(s * saturation_mul, 0.0, 1.0)
	
	# Darken
	v = clamp(v * value_mul, 0.0, 1.0)
	
	return Color.from_hsv(h, s, v, shallow.a)
