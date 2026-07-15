extends Node

const PLAYER_SCENE := preload("res://scripts/player_controller/player_controller.tscn")

const PLANET_SCENE := preload("res://scripts/planet/planet.tscn")
const MAX_PLANETS := 8
const PLANETS_DEFAULT_DISTANCE := 300.0
const PLANET_SELECT_ENTRY := preload("res://scripts/generation_ui/planet_select_entry.tscn")

@export var world_root : Node3D
@export var generation_ui_root : Control
@export var generation_cam : Camera3D
@export var cam_root : GenerationCam
@export var planets_parent : Node3D
@export var ui_planet_entries_parent : Control

@export var selected_planet : Planet:
	set(val):
		selected_planet = val
		# Only update UI if the node is fully initialized
		if is_inside_tree() and is_node_ready():
			_refill_all_input_fields()

var settings_fields : Array[PlanetSettingsField] = []

var needs_to_be_regenerated_queue : Array[Planet] = []

var player : Node3D


func _ready() -> void:
	randomize()
	
	# Connect position field
	var pos_input : PositionInput = %PositionInput
	pos_input.position_changed.connect(_on_position_input_position_changed)
	pos_input.request_fill_me.connect(_fill_position_input)
	
	# Find and connect input fields
	_find_field_children_recursively(generation_ui_root, settings_fields)
	
	# Disable automatic regeneration for all fields.
	# Regeneration is handled manually in _input_field_value_changed
	# to allow different regeneration types (terrain vs flora).
	for input_field in settings_fields:
		input_field.causes_regeneration = false
		input_field.request_fill_me.connect(_fill_input_field)
		input_field.value_changed.connect(_input_field_value_changed)
	
	# Refill all fields now that we are ready and all connections are made
	_refill_all_input_fields()
	
	# Configure default planet
	selected_planet.planet_generation_finished.connect(_on_planet_fully_generated)
	_add_planet_entry_for_planet(selected_planet)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if player != null:
			player.queue_free()
			player = null
		
		generation_ui_root.show()


#
# SETTINGS INPUT FIELDS
#
func _find_field_children_recursively(parent : Node, found : Array[PlanetSettingsField]) -> void:
	if parent is PlanetSettingsField:
		found.append(parent)
	
	if parent.get_child_count() == 0:
		return
	
	for child in parent.get_children():
		_find_field_children_recursively(child, found)

func _refill_all_input_fields() -> void:
	# Prevent interaction with invalid planets
	if !is_instance_valid(selected_planet):
		return
	
	for input_field in settings_fields:
		_fill_input_field(input_field, input_field.connected_property)
	
	_fill_position_input()
	
	# Update gradient preview if color_generator exists
	if selected_planet.color_generator != null:
		%SurfuceGradient.texture.gradient = selected_planet.color_generator.color_gradient

func _on_explore_button_pressed() -> void:
	# Ensure camera is valid before use
	if !is_instance_valid(generation_cam) or !generation_cam.is_inside_tree():
		return
	
	generation_ui_root.hide()
	
	player = PLAYER_SCENE.instantiate()
	
	# Nodes must be inside the SceneTree to set global transforms
	world_root.add_child(player)
	
	player.global_position = generation_cam.global_position
	player.rotation = generation_cam.rotation
	
	var cam := player.get_node_or_null("Camera3D")
	if cam is Camera3D:
		cam.current = true

func _fill_input_field(field, property : String) -> void:
	# Prevent interaction with invalid planets
	if !is_instance_valid(selected_planet):
		return
	
	var value = 0
	var found := false
	
	# Check planet properties
	if property in selected_planet:
		value = selected_planet.get(property)
		found = true
	# Check density_generator properties
	elif property in selected_planet.density_generator:
		value = selected_planet.density_generator.get(property)
		found = true
	# Check flora_generator properties
	elif selected_planet.flora_generator != null and property in selected_planet.flora_generator:
		value = selected_planet.flora_generator.get(property)
		found = true
	
	if !found:
		print("GenerationUILogic: Property \'%s\' not found!" % property)
		return
	
	field.fill(value)

func _input_field_value_changed(property : String, new_value) -> void:
	# Prevent interaction with invalid planets
	if !is_instance_valid(selected_planet):
		return
	
	var needs_terrain_regen := false
	var needs_flora_regen := false
	
	# Properties that update their visuals immediately via setters and don't require
	# a full mesh or flora regeneration.
	var no_regen_props = ["gravity_radius_multiplier", "gravity_strength", "constant_gravity", "water_color"]
	
	if property in selected_planet:
		selected_planet.set(property, new_value)
		# Changing water level or enabling/disabling water requires flora regeneration
		# to update underwater/surface placement, but does not require terrain mesh regeneration.
		if property == "generate_water" or property == "water_radius_mult":
			needs_flora_regen = true
		elif not property in no_regen_props:
			needs_terrain_regen = true
	elif property in selected_planet.density_generator:
		selected_planet.density_generator.set(property, new_value)
		needs_terrain_regen = true
	elif selected_planet.flora_generator != null and property in selected_planet.flora_generator:
		selected_planet.flora_generator.set(property, new_value)
		needs_flora_regen = true
	else:
		print("GenerationUILogic: Property \'%s\' not found!" % property)
		return
	
	# Trigger the appropriate regeneration type immediately.
	# The generation ID system in MarchingCubes will automatically discard
	# any ongoing generation if a new one starts.
	if needs_terrain_regen:
		_regenerate_planet()
	elif needs_flora_regen:
		selected_planet.regenerate_flora()

func _regenerate_planet() -> void:
	# Prevent interaction with invalid planets
	if !is_instance_valid(selected_planet):
		return
	
	# If the planet is fully generated, regenerate immediately.
	# Otherwise, queue it for regeneration when it finishes.
	if selected_planet.is_fully_generated():
		selected_planet.regenerate()
	elif !needs_to_be_regenerated_queue.has(selected_planet):
		print("Cannot regenerate now, adding to queue...")
		needs_to_be_regenerated_queue.append(selected_planet)

func _on_planet_fully_generated() -> void:
	var to_regen : Array[Planet] = []
	for planet in _get_planets():
		if needs_to_be_regenerated_queue.has(planet) && planet.is_fully_generated():
			to_regen.append(planet)
	
	for planet in to_regen:
		planet.regenerate()
		needs_to_be_regenerated_queue.erase(planet)

# Randomizes the seed, updates the input field, and triggers planet regeneration
func _on_randomize_seed_button_pressed() -> void:
	_input_field_value_changed("random_seed", randi())
	_refill_all_input_fields()
	# _input_field_value_changed already calls _regenerate_planet

#
# POSITION INPUT FIELD
#
func _on_position_input_position_changed(new_pos : Vector3) -> void:
	# Prevent interaction with invalid planets
	if !is_instance_valid(selected_planet):
		return
	
	selected_planet.global_position = new_pos

func _fill_position_input() -> void:
	var pos_input : PositionInput = %PositionInput
	
	# Ensure the planet is valid and in the tree before getting its global position
	if is_instance_valid(selected_planet) and selected_planet.is_inside_tree():
		pos_input.set_pos(selected_planet.global_position)
	else:
		# Default to zero if the planet is not ready
		pos_input.set_pos(Vector3.ZERO)

#
# PLANETS MANAGEMENT
#
func _get_planets() -> Array[Planet]:
	var planets : Array[Planet] = []
	
	for ch in planets_parent.get_children():
		if ch is Planet && !ch.is_queued_for_deletion():
			planets.append(ch as Planet)
	
	return planets

func _get_default_position_for_planet(ix : int) -> Vector3:
	return Vector3.RIGHT.rotated(Vector3.UP, (ix-1)*30.0) * PLANETS_DEFAULT_DISTANCE


func _on_add_planet_button_pressed() -> void:
	var num_planets := _get_planets().size()
	if num_planets >= MAX_PLANETS:
		print("Can't add more planets, reached max!")
		return
	
	# Add planet
	var new_planet := PLANET_SCENE.instantiate()
	
	# Prevent auto-generation in _ready() so we can set properties first.
	# This ensures the planet generates with the correct settings from the UI.
	new_planet.generation_paused = true
	
	# Ensure each planet has unique resource instances.
	if new_planet.density_generator:
		new_planet.density_generator = new_planet.density_generator.duplicate()
	if new_planet.color_generator:
		new_planet.color_generator = new_planet.color_generator.duplicate()
	if new_planet.flora_generator:
		new_planet.flora_generator = new_planet.flora_generator.duplicate()
	
	new_planet.position = _get_default_position_for_planet(num_planets)
	planets_parent.add_child(new_planet)
	
	# Now that the node is in the tree and ready, set properties from the currently selected planet.
	# This ensures the new planet matches the settings currently visible in the UI.
	new_planet.radius = selected_planet.radius
	new_planet.gravity_radius_multiplier = selected_planet.gravity_radius_multiplier
	new_planet.gravity_strength = selected_planet.gravity_strength
	new_planet.constant_gravity = selected_planet.constant_gravity
	new_planet.generate_water = selected_planet.generate_water
	new_planet.water_radius_mult = selected_planet.water_radius_mult
	new_planet.water_color = Color(randf(), randf(), randf())
	
	new_planet.density_generator.random_seed = randi()
	new_planet.color_generator.color_gradient = make_random_gradient(randi_range(2,6))
	
	# Manually trigger generation with the correct properties
	new_planet.generation_paused = false
	new_planet.regenerate()
	
	_add_planet_entry_for_planet(new_planet)
	_set_selected_planet(new_planet)

func _add_planet_entry_for_planet(planet : Planet) -> void:
	var new_entry = PLANET_SELECT_ENTRY.instantiate()
	new_entry.connected_planet = planet
	ui_planet_entries_parent.add_child(new_entry)
	
	new_entry.select_planet.connect(_set_selected_planet)
	new_entry.delete_button_pressed.connect(_delete_planet)
	
	_refresh_planets_ui_visuals()

func _refresh_planets_ui_visuals() -> void:
	var num_planets := _get_planets().size() 
	for ch in ui_planet_entries_parent.get_children():
		if ch is PlanetSelectEntry:
			ch.selected = (ch.connected_planet == selected_planet)
			ch.can_delete = (num_planets > 1)


func _set_selected_planet(planet : Planet) -> void:
	selected_planet = planet
	cam_root.target = planet
	_refill_all_input_fields()
	_refresh_planets_ui_visuals()

func _delete_planet(planet : Planet) -> void:
	if !planet.is_fully_generated():
		print("Cannot delete until generation finishes!")
		return
	
	var needs_to_change_selected := false
	if selected_planet == planet:
		needs_to_change_selected = true
	
	planet.queue_free()
	for ch in ui_planet_entries_parent.get_children():
		if ch is PlanetSelectEntry:
			if ch.connected_planet == planet:
				ch.queue_free()
				break
	
	if needs_to_change_selected:
		_set_selected_planet(_get_planets()[0])
	
	_refresh_planets_ui_visuals()


func make_random_gradient(color_count: int = 4) -> Gradient:
	var gradient := Gradient.new()
	
	var colors: PackedColorArray = []
	var offsets: PackedFloat32Array = []
	
	for i in range(color_count):
		# Random color
		colors.append(Color(
			randf(),
			randf(),
			randf(),
			1.0
		))
	
		# Randomized offset
		var t := float(i) / float(max(color_count - 1, 1))
	
		# Add some randomness while keeping order
		var random_offset : float = clamp(
			t + randf_range(-0.15, 0.15),
			0.0,
			1.0
		)
		
		offsets.append(random_offset)
	
	# Ensure offsets stay sorted
	offsets.sort()
	
	# Force exact endpoints
	offsets[0] = 0.0
	offsets[offsets.size() - 1] = 1.0
	
	gradient.colors = colors
	gradient.offsets = offsets
	
	return gradient


func _on_randomize_surfuce_color_pressed() -> void:
	# Prevent interaction with invalid planets
	if !is_instance_valid(selected_planet):
		return
	
	selected_planet.color_generator.color_gradient = make_random_gradient(randi_range(2,6))
	_refill_all_input_fields()
	_regenerate_planet()
