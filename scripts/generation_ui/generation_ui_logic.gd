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
		_refill_all_input_fields()

var settings_fields : Array[PlanetSettingsField] = []

var needs_to_be_regenerated_queue : Array[Planet] = []


func _ready() -> void:
	randomize()
	
	# Connect position field
	var pos_input : PositionInput = %PositionInput
	pos_input.position_changed.connect(_on_position_input_position_changed)
	pos_input.request_fill_me.connect(_fill_position_input)
	
	# Find and connect input fields
	_find_field_children_recursively(generation_ui_root, settings_fields)
	
	for input_field in settings_fields:
		input_field.request_fill_me.connect(_fill_input_field)
		input_field.request_regeneration.connect(_regenerate_planet)
		input_field.value_changed.connect(_input_field_value_changed)
	
	_refill_all_input_fields()
	
	# Configure default planet
	selected_planet.planet_generation_finished.connect(_on_planet_fully_generated)
	_add_planet_entry_for_planet(selected_planet)


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
	for input_field in settings_fields:
		_fill_input_field(input_field, input_field.connected_property)
	
	_fill_position_input()
	%SurfuceGradient.texture.gradient = selected_planet.color_generator.color_gradient

func _on_explore_button_pressed() -> void:
	generation_ui_root.hide()
	
	var player : PlayerController = PLAYER_SCENE.instantiate()
	player.global_position = generation_cam.global_position
	player.rotation = generation_cam.rotation
	player.get_node("Camera3D").current = true
	world_root.add_child(player)

func _fill_input_field(field, property : String) -> void:
	var value = 0
	var found := false
	if property in selected_planet:
		value = selected_planet.get(property)
		found = true
	elif property in selected_planet.density_generator:
		value = selected_planet.density_generator.get(property)
		found = true
	
	if !found:
		print("GenerationUILogic: Property \'%s\' not found!" % property)
		return
	
	field.fill(value)

func _input_field_value_changed(property : String, new_value) -> void:
	if property in selected_planet:
		selected_planet.set(property, new_value)
	elif property in selected_planet.density_generator:
		selected_planet.density_generator.set(property, new_value)
	else:
		print("GenerationUILogic: Property \'%s\' not found!" % property)

func _regenerate_planet() -> void:
	if selected_planet.is_fully_generated():
		selected_planet.regenerate()
	elif !needs_to_be_regenerated_queue.has(selected_planet):
		print("Cannot regenerate now, adding to queue...")
		needs_to_be_regenerated_queue.append(selected_planet)

func _on_planet_fully_generated() -> void:
	var to_regen : Array[Planet] = []
	for planet in _get_planets():
		if needs_to_be_regenerated_queue.has(planet) &&\
		   planet.is_fully_generated():
			to_regen.append(planet)
	
	for planet in to_regen:
		planet.regenerate()
		needs_to_be_regenerated_queue.erase(planet)

func _on_randomize_seed_button_pressed() -> void:
	_input_field_value_changed("random_seed", randi())
	_refill_all_input_fields()

#
# POSITION INPUT FIELD
#
func _on_position_input_position_changed(new_pos : Vector3) -> void:
	selected_planet.global_position = new_pos

func _fill_position_input() -> void:
	var pos_input : PositionInput = %PositionInput
	pos_input.set_pos(selected_planet.global_position)



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
	new_planet.position = _get_default_position_for_planet(num_planets)
	planets_parent.add_child(new_planet)
	
	new_planet.density_generator.random_seed = randi()
	new_planet.water_color = Color(randf(), randf(), randf())
	new_planet.color_generator.color_gradient = make_random_gradient(randi_range(2,6))
	
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
	selected_planet.color_generator.color_gradient = make_random_gradient(randi_range(2,6))
	_refill_all_input_fields()
	_regenerate_planet()
