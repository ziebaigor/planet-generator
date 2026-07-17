class_name SunSystem
extends Node3D

# Simulates a sun orbiting the center of the planet system (geocentric model).
#
# The system moves a directional light along a tilted orbit around the origin,
# which produces day/night cycles on the planets. The visible sun is drawn by
# the skybox shader exactly where the light is coming from, and this node
# keeps the skybox parameters in sync with the orbit.

@export_group("Orbit Settings")
# Distance from the orbit center to the sun.
@export var orbit_distance := 600.0

# Time in seconds for the sun to complete one full orbit (one full day).
@export var day_length := 120.0

# Tilt of the orbit plane in degrees.
# 0 keeps the sun moving on a flat plane, higher values make it
# rise above and sink below the planet plane.
@export var orbit_inclination := 15.0

# When disabled the sun stays in place and the time of day does not pass.
@export var cycle_enabled := true

@export_group("Sun Settings")
# Size of the visible sun disk on the sky.
@export var sun_size := 40.0

# Energy of the sunlight.
@export var sun_brightness := 1.2:
	set(val):
		sun_brightness = val
		if is_node_ready():
			_update_sun_visuals()

# Color of the sunlight and of the visible sun disk.
@export var sun_color := Color(1.0, 0.95, 0.85):
	set(val):
		sun_color = val
		if is_node_ready():
			_update_sun_visuals()

@export_group("Sky Settings")
# Brightness of the stars on the sky.
@export var star_brightness := 1.0

@export_group("Node References")
# World environment holding the skybox.
@export var world_environment : WorldEnvironment

# Current position of the sun on its orbit, in radians.
var _orbit_angle := deg_to_rad(60.0)

# Skybox material taken from the world environment.
var _sky_material : ShaderMaterial

@onready var sun_light : DirectionalLight3D = $DirectionalLight3D


func _ready() -> void:
	# Cache the sky material so its parameters can be updated every frame
	if world_environment and world_environment.environment:
		var sky := world_environment.environment.sky
		if sky and sky.sky_material is ShaderMaterial:
			_sky_material = sky.sky_material
	
	_update_sun_transform()
	_update_sun_visuals()


func _process(delta: float) -> void:
	# Advance the time of day
	if cycle_enabled and day_length > 0.001:
		_orbit_angle = wrapf(_orbit_angle + TAU * delta / day_length, 0.0, TAU)
	
	_update_sun_transform()
	_update_sky()


# Moves the sun light along the orbit
func _update_sun_transform() -> void:
	var sun_pos := to_global(_get_orbit_position())
	sun_light.global_position = sun_pos
	
	# Point the light from the sun towards the orbit center
	if sun_pos.distance_squared_to(global_position) > 0.0001:
		var up := Vector3.UP
		var light_dir := (global_position - sun_pos).normalized()
		if abs(light_dir.dot(Vector3.UP)) > 0.99:
			# look_at fails when the direction is parallel to the up vector
			up = Vector3.FORWARD
		sun_light.look_at(global_position, up)


# Returns the sun position on the orbit for the current orbit angle
func _get_orbit_position() -> Vector3:
	var flat_pos := Vector3(cos(_orbit_angle) * orbit_distance, 0.0, sin(_orbit_angle) * orbit_distance)
	
	# Tilt the orbit plane
	var tilt := Basis(Vector3.FORWARD, deg_to_rad(orbit_inclination))
	return tilt * flat_pos


# Applies the current brightness and color to the sunlight
func _update_sun_visuals() -> void:
	sun_light.light_energy = sun_brightness
	sun_light.light_color = sun_color


# Feeds the current sun direction and appearance to the skybox shader
func _update_sky() -> void:
	if !_sky_material:
		return
	
	_sky_material.set_shader_parameter("sun_direction", _get_orbit_position().normalized())
	_sky_material.set_shader_parameter("sun_angular_size", atan(sun_size / maxf(orbit_distance, 1.0)))
	_sky_material.set_shader_parameter("sun_color", sun_color)
	_sky_material.set_shader_parameter("star_brightness", star_brightness)
