extends MarchingCubes

@export var radius := 30

@export_group("Gravity Settings")
@export var gravity_radius_multiplier := 1.5
@export var gravity_strength := 20.0
@export var constant_gravity := false

@export_group("Water Settings")
@export var generate_water := true
@export var water_radius_mult := 2.0
@export var water_color := Color(0.059, 0.592, 1.0)
@export var directional_light : DirectionalLight3D

@onready var gravity_source : GravitySource = $GravitySource
@onready var water : MeshInstance3D = $Water



func _ready() -> void:
	if "radius" in density_generator:
		density_generator.base_radius = radius
	
	
	# Gravity source
	gravity_source.planet_radius = radius
	
	gravity_source.gravity_radius_multiplier = gravity_radius_multiplier
	gravity_source.gravity_strength = gravity_strength
	gravity_source.constant_gravity = constant_gravity
	
	
	# Water
	var water_r := radius * water_radius_mult
	if !generate_water:
		water_r = 1
		water.hide()
		water.get_node("WaterArea").set_enabled(false)
	
	water.scale = Vector3(water_r,water_r,water_r)
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
	
	
	super._ready()


func _finalize_chunk(chunk_coords : Vector3i, chunk_node : MeshInstance3D) -> void:
	super._finalize_chunk(chunk_coords, chunk_node)
	if processed_chunks == total_chunks:
		gravity_source.generation_done()


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
