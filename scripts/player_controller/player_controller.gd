class_name Player
extends CharacterBody3D

@export var walk_speed    : float = 6.0
@export var sprint_speed  : float = 12.0
@export var jump_velocity : float = 8.0
@export var noclip_speed  : float = 15.0
@export var mouse_sensitivity : float = 0.002

@onready var camera : Camera3D = $Camera3D
var _camera_pitch : float = 0.0

var gravity_sources: Array[Node3D] = []
var gravity_source : Node3D = null
var noclip : bool = false
var _gravity_vec : Vector3 = Vector3.ZERO

#TODO: Rewrite this script

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func add_gravity_source(source: Node3D) -> void:
	if not source in gravity_sources:
		gravity_sources.append(source)

func remove_gravity_source(source: Node3D) -> void:
	gravity_sources.erase(source)

func set_gravity_source(planet: Node3D) -> void:
	gravity_source = planet

func clear_gravity_source(planet: Node3D) -> void:
	if gravity_source == planet:
		gravity_source = null

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Left/right rotates the whole player body
		rotate_object_local(Vector3.UP, -event.relative.x * mouse_sensitivity)
		# Up/down only tilts the camera
		_camera_pitch = clamp(_camera_pitch - event.relative.y * mouse_sensitivity, -1.5, 1.5)
		camera.rotation.x = _camera_pitch
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("noclip"):
		noclip = !noclip
		set_collision_layer_value(1, !noclip)
		set_collision_mask_value(1, !noclip)

	if noclip:
		_process_noclip(delta)
	else:
		_process_grounded(delta)

func _process_noclip(delta: float) -> void:
	var dir := _get_input_direction_world()
	if Input.is_action_pressed("up"):
		dir += transform.basis.y
	velocity = dir * noclip_speed
	move_and_slide()

func _process_grounded(delta: float) -> void:
	# Gravity
	if gravity_source:
		_gravity_vec = gravity_source.get_gravity_vector(global_position)

	if not is_on_floor():
		velocity += _gravity_vec * delta

	# Align player upright relative to planet surface
	_align_up_to_gravity(delta)

	# Jump
	if Input.is_action_just_pressed("up") and is_on_floor():
		velocity += -_gravity_vec.normalized() * jump_velocity

	# Movement
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var input_dir := _get_input_direction_local()

	if input_dir != Vector3.ZERO:
		velocity += input_dir * speed * delta * 10.0
		# Clamp horizontal speed so sprinting doesn't accelerate forever
		var up := -_gravity_vec.normalized()
		var horizontal := velocity - up * velocity.dot(up)
		if horizontal.length() > speed:
			velocity = up * velocity.dot(up) + horizontal.normalized() * speed
	else:
		# Friction
		if is_on_floor():
			var up := -_gravity_vec.normalized()
			var horizontal := velocity - up * velocity.dot(up)
			velocity -= horizontal * min(1.0, 12.0 * delta)

	move_and_slide()

func _align_up_to_gravity(delta: float) -> void:
	if _gravity_vec == Vector3.ZERO:
		return
	var target_up := -_gravity_vec.normalized()
	var current_up := transform.basis.y
	var rotation_axis := current_up.cross(target_up)
	if rotation_axis.length() > 0.001:
		var angle := current_up.angle_to(target_up)
		var rot := Quaternion(rotation_axis.normalized(), angle * min(1.0, 10.0 * delta))
		basis = Basis(rot) * basis
		basis = basis.orthonormalized()

func _get_input_direction_local() -> Vector3:
	var input := Vector2.ZERO
	if Input.is_action_pressed("forward"): input.y -= 1
	if Input.is_action_pressed("backward"):    input.y += 1
	if Input.is_action_pressed("left"):    input.x -= 1
	if Input.is_action_pressed("right"):   input.x += 1
	input = input.normalized()
	return transform.basis.x * input.x + (-transform.basis.z) * input.y

func _get_input_direction_world() -> Vector3:
	var input := Vector3.ZERO
	if Input.is_action_pressed("forward"): input -= transform.basis.z
	if Input.is_action_pressed("backward"):    input += transform.basis.z
	if Input.is_action_pressed("left"):    input -= transform.basis.x
	if Input.is_action_pressed("right"):   input += transform.basis.x
	return input.normalized()
