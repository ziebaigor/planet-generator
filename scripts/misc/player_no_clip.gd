extends CharacterBody3D

@export var move_speed := 10.0
@export var mouse_sensitivity := 0.002
@export var roll_speed := 2.5
@export var sprint_mult := 8.0

var yaw := 0.0
var pitch := 0.0
var roll := 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		
		# Clamp pitch
		pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))
		
		_update_rotation()
	
	elif event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	elif event is InputEventMouseButton:
		if event.button_index == 1 and event.pressed:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(_delta : float) -> void:
	var input_forward := Input.get_axis("backward", "forward")
	var input_right := Input.get_axis("left", "right")
	var input_up := Input.get_axis("down", "up")
	var is_sprinting := Input.is_action_pressed("sprint")
	
	# Optional roll input
	# var input_roll := Input.get_axis("roll_left", "roll_right")
	# roll += input_roll * roll_speed * delta
	
	_update_rotation()
	
	var _basis := global_transform.basis
	
	var forward := -_basis.z
	var right := _basis.x
	var up := _basis.y
	
	var direction := \
		forward * input_forward + \
		right * input_right + \
		up * input_up
	
	var speed_mult := 1.0 if !is_sprinting else sprint_mult
	
	if direction != Vector3.ZERO:
		direction = direction.normalized()
		velocity = direction * move_speed * speed_mult
	else:
		velocity = Vector3.ZERO
	
	move_and_slide()

func _update_rotation() -> void:
	rotation = Vector3(pitch, yaw, roll)
