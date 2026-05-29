class_name PlanetSelectEntry
extends Control

@export var connected_planet : Planet:
	set(val):
		connected_planet = val
		
		if !is_node_ready():
			await ready
		
		if connected_planet:
			main_button.text = connected_planet.name
		else:
			main_button.text = "NOT SET"

@export var selected := false:
	set(val):
		selected = val
		
		if !is_node_ready():
			await ready
		
		selection_frame.visible = selected

@export var can_delete := false:
	set(val):
		can_delete = val
		
		if !is_node_ready():
			await ready
		
		delete_button.visible = can_delete

@onready var selection_frame := %SelectionFrame
@onready var main_button := %MainButton
@onready var delete_button := %DeleteButton

signal select_planet(planet : Planet)
signal delete_button_pressed(planet : Planet)



func _on_main_button_pressed() -> void:
	if connected_planet:
		select_planet.emit(connected_planet)

func _on_delete_button_pressed() -> void:
	if connected_planet:
		delete_button_pressed.emit(connected_planet)
