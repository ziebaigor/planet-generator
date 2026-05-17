extends Node

@export var scene_root : Node3D
@export var generation_ui_root : Control
@export var generation_cam : Camera3D

const PLAYER_SCENE := preload("res://scripts/player_controller/player_controller.tscn")

func _on_explore_button_pressed() -> void:
	generation_ui_root.hide()
	generation_cam.current = false
	
	var player : PlayerController = PLAYER_SCENE.instantiate()
	player.global_position = generation_cam.global_position
	player.rotation = generation_cam.rotation
	player.get_node("Camera3D").current = true
	scene_root.add_child(player)
