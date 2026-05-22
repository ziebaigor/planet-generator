extends Node

@export var world_root : Node3D
@export var generation_ui_root : Control
@export var generation_cam : Camera3D

@export var selected_planet : Planet

const PLAYER_SCENE := preload("res://scripts/player_controller/player_controller.tscn")


func _ready() -> void:
	# Connect position field
	var pos_input : PositionInput = %PositionInput
	pos_input.position_changed.connect(_on_position_input_position_changed)
	pos_input.request_fill_me.connect(_fill_position_input)
	
	# Find and connect input fields
	var fields : Array[PlanetSettingsField] = []
	_find_field_children_recursively(generation_ui_root, fields)
	
	for input_field in fields:
		input_field.request_fill_me.connect(_fill_input_field)
		input_field.request_regeneration.connect(_regenerate_planet)
		input_field.value_changed.connect(_input_field_value_changed)
		
		_fill_input_field(input_field, input_field.connected_property)


func _find_field_children_recursively(parent : Node, found : Array[PlanetSettingsField]) -> void:
	if parent is PlanetSettingsField:
		found.append(parent)
	
	if parent.get_child_count() == 0:
		return
	
	for child in parent.get_children():
		_find_field_children_recursively(child, found)


func _on_explore_button_pressed() -> void:
	generation_ui_root.hide()
	#generation_cam.current = false
	
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
	selected_planet.regenerate()


func _on_position_input_position_changed(new_pos : Vector3) -> void:
	selected_planet.global_position = new_pos

func _fill_position_input(pos_input : PositionInput) -> void:
	pos_input.set_pos(selected_planet.global_position)
