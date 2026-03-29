extends Node3D

@export var cubes_parent : Node3D
@export var player : Node3D
@export var planet : Node3D
const debug_cube := preload("res://scripts/misc/debug_cube.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_E and event.pressed:
		var new_cube := debug_cube.instantiate()
		new_cube.gravity_center = planet.global_position
		cubes_parent.add_child(new_cube)
		new_cube.global_position = player.global_position + player.basis.z*(-10)
