extends CharacterBody3D


@export var gravity_force := 9.8
@export var gravity_center := Vector3.ZERO


func _physics_process(delta: float) -> void:
	if !is_on_floor():
		velocity += global_position.direction_to(gravity_center) * gravity_force * delta
	
	move_and_slide()
