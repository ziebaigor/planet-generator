class_name Player
extends CharacterBody3D

@export var walk_speed    : float = 6.0
@export var sprint_speed  : float = 12.0
@export var acceleration  : float = 12.0
@export var deceleration  : float = 16.0
@export var jump_velocity : float = 8.0
@export var air_control   : float = 0.4		# Moving speed multiplier when character is in air
@export var noclip_speed  : float = 15.0
@export var mouse_sensitivity : float = 0.002
@export var camera_pitch_limit : float = 90.0

var gravity_sources: Array[Node3D] = []
var noclip : bool = false
var _gravity_vector : Vector3 = Vector3.ZERO

var _camera_pitch : float = 0.0
@onready var camera : Camera3D = $Camera3D


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_rotate_camera(event.relative)
 
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
 
 
func _rotate_camera(delta: Vector2) -> void:
	rotate(transform.basis.y, -delta.x * mouse_sensitivity)
 
	_camera_pitch -= delta.y * mouse_sensitivity
	_camera_pitch = clamp(_camera_pitch, deg_to_rad(-camera_pitch_limit), deg_to_rad(camera_pitch_limit))
	camera.rotation.x = _camera_pitch

func _physics_process(delta: float) -> void:
	_update_gravity_vector()
	_align_to_gravity(delta)
	_apply_movement(delta)
	move_and_slide()


func add_gravity_source(source: Node3D) -> void:
	if not source in gravity_sources:
		gravity_sources.append(source)
		print("Added gravity from '", source.name, "' to player '", self.name, "'.")


func remove_gravity_source(source: Node3D) -> void:
	gravity_sources.erase(source)
	print("Removed gravity from '", source.name, "' in player '", self.name, "'.")


func _update_gravity_vector() -> void:
	_gravity_vector = Vector3.ZERO
 
	for source in gravity_sources:
		if source.has_method("get_gravity_vector"):
			_gravity_vector += source.get_gravity_vector(self.global_position)


func _align_to_gravity(delta: float) -> void:
	var target_up : Vector3 = -_gravity_vector
	var current_up: Vector3 = transform.basis.y
 
	# If player is aligned to gravity vector skip the rest
	if current_up.is_equal_approx(target_up):
		return
 
	var rotation_axis : Vector3 = current_up.cross(target_up)
	if rotation_axis.length_squared() < 0.0001:
		return
 
	rotation_axis = rotation_axis.normalized()
	var angle: float = current_up.angle_to(target_up)
 
	var max_angle: float = deg_to_rad(180.0) * delta * 5.0   # prędkość wyrównania
	angle = minf(angle, max_angle)
 
	var rot_basis := Basis(rotation_axis, angle)
	global_transform.basis = rot_basis * global_transform.basis
	global_transform.basis = global_transform.basis.orthonormalized()


func _apply_movement(delta: float) -> void:
	var on_ground: bool = is_on_floor()
 
	if not on_ground:
		velocity += _gravity_vector * delta
	else:
		var grav_component: float = velocity.dot(_gravity_vector)
		if grav_component > 0.0:
			velocity -= _gravity_vector * grav_component
 
	if Input.is_action_just_pressed("up") and on_ground:
		velocity -= _gravity_vector * jump_velocity
 
	var input_dir := Vector2(
		Input.get_axis("left",    "right"),
		Input.get_axis("forward", "backward")
	)
 
	var forward: Vector3 = -global_transform.basis.z
	var right:   Vector3 =  global_transform.basis.x
 
	var wish_dir: Vector3 = (forward * -input_dir.y + right * input_dir.x)
	wish_dir = wish_dir - _gravity_vector * wish_dir.dot(_gravity_vector)
	if wish_dir.length_squared() > 0.0001:
		wish_dir = wish_dir.normalized()
 
	var control: float = 1.0 if on_ground else air_control
 
	var grav_vel:  float   = velocity.dot(_gravity_vector)
	var horiz_vel: Vector3 = velocity - _gravity_vector * grav_vel
 
	if wish_dir.length_squared() > 0.0001:
		horiz_vel = horiz_vel.lerp(wish_dir * walk_speed, acceleration * control * delta)
	else:
		horiz_vel = horiz_vel.lerp(Vector3.ZERO, deceleration * control * delta)
 
	# Łączymy z powrotem składową grawitacyjną
	velocity = horiz_vel + _gravity_vector * grav_vel
