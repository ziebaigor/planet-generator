class_name Player
extends CharacterBody3D

@export var walk_speed        : float = 6.0
@export var sprint_speed      : float = 12.0
@export var acceleration      : float = 12.0
@export var deceleration      : float = 16.0
@export var jump_velocity     : float = 12.0
@export var air_multiplier    : float = 0.2
@export var noclip_speed      : float = 15.0
@export var mag_boots_force   : float = 20.0
@export var mouse_sensitivity : float = 0.002
@export var gravity_interpolation_speed  : float = 10.0
@export var rotation_interpolation_speed : float = 8.0

var gravity_sources : Array[Node3D] = []
var noclip          : bool = false
var mag_boots       : bool = false

var _gravity_vector : Vector3 = Vector3.ZERO
var _camera_pitch   : float = 0.0

@onready var camera         : Camera3D = $Camera3D
@onready var floor_detector : ShapeCast3D = $FloorDetector


func _ready() -> void:
	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Set not sliding from steep slops
	floor_stop_on_slope = true
	# Set detecting floor that are up to 60 degrees steep
	floor_max_angle = deg_to_rad(60.0)


func _unhandled_input(event: InputEvent) -> void:
	var is_mouse_captured := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	
	# Rotate camera when mouse is captured
	if event is InputEventMouseMotion and is_mouse_captured:
		_rotate_camera(event.relative)

	# Uncapture mouse when pressed Escape
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Capture mouse when clicked in game window
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_mouse_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Noclip switch
	if event.is_action_pressed("noclip"):
		noclip = not noclip
		# Reset player velocity
		velocity = Vector3.ZERO
		print("Enabled" if noclip else "Disabled", " noclip.")

	# Magnetic boots switch
	if event.is_action_pressed("mag_boots"):
		mag_boots = not mag_boots
		print("Enabled" if mag_boots else "Disabled", " magnetic boots.")


func _physics_process(delta: float) -> void:
	if noclip:
		# Apply noclip movement
		_apply_noclip(delta)
		# Skip the rest
		return

	# Update gravity vector direction and strength
	_process_gravity_vector(delta)
	if not _gravity_vector.is_zero_approx():
		# Set up direction if gravity vector is not zero
		up_direction = -_gravity_vector.normalized()
	
	# Rotate player to alighn to gravity vector
	_align_to_gravity(delta)
	# Apply movement from keyboard
	_apply_movement(delta)
	# Move the player and process collisions
	move_and_slide()


func add_gravity_source(source: Node3D) -> void:
	if not source in gravity_sources:
		# Add gravity source to player
		gravity_sources.append(source)


func remove_gravity_source(source: Node3D) -> void:
	# Remove gravity source from player
	gravity_sources.erase(source)


func _rotate_camera(delta: Vector2) -> void:
	# Rotate player (left/right) (x)
	rotate(transform.basis.y, -delta.x * mouse_sensitivity)
	# Rotate camera (up/down) (y)
	_camera_pitch -= delta.y * mouse_sensitivity
	# Limit up/down rotation to -90 and 90 degrees
	_camera_pitch = clamp(_camera_pitch, deg_to_rad(-90), deg_to_rad(90))
	# Set camera rotation
	camera.rotation.x = _camera_pitch


# This function sets _gravity_vector
func _process_gravity_vector(delta: float) -> void:
	var target_gravity := Vector3.ZERO
	var mag_contact := false

	# If magnetic boots are enabled
	if mag_boots:
		var surface_normal := Vector3.ZERO
		# Get surface normal
		if is_on_floor():
			surface_normal = get_floor_normal()
			mag_contact = true
		elif floor_detector.is_colliding():
			surface_normal = floor_detector.get_collision_normal(0)
			mag_contact = true

		# If player is on surface and has enabled magnetic boots set target gravity to surface normal
		if mag_contact:
			target_gravity = -surface_normal * mag_boots_force
	
	# Default gravity
	# Magnetic boots are disabled or player is in the air
	if not mag_contact:
		for source in gravity_sources:
			if source.has_method("get_gravity_vector"):
				# Add all gravity vectors that influences player
				target_gravity += source.get_gravity_vector(global_position)

	# Gravity vector smoothing
	if _gravity_vector.is_zero_approx() or _gravity_vector.distance_squared_to(target_gravity) < 0.01:
		# Set gravity vector withour smoothing if it was zero or changed very little
		_gravity_vector = target_gravity
	else:
		# Set gravity vector with interpolation (smoothing)
		_gravity_vector = _gravity_vector.lerp(target_gravity, delta * gravity_interpolation_speed)


# Rotate the player to align to gravity vector
func _align_to_gravity(delta: float) -> void:
	if _gravity_vector.is_zero_approx():
		# Skip if there are no gravity vector
		return

	# Target up direction
	var target_up  : Vector3 = -_gravity_vector.normalized()
	# Current up direction
	var current_up : Vector3 = global_transform.basis.y
	# Angle between target and current up direction
	var angle: float = current_up.angle_to(target_up)

	if angle < 0.01:
		# Skip if angle is small (removes micro movements)
		return

	# Find rotation axis (Axis that is perpendicular to target and current up axis)
	var rotation_axis : Vector3 = current_up.cross(target_up)
	
	if rotation_axis.length_squared() < 0.0001:
		# If there are no rotation axis (target and current up axis are paraller) set the x player axis for rotationn
		rotation_axis = global_transform.basis.x 

	# Normalize rotation axis because we only need its direction
	rotation_axis = rotation_axis.normalized()
	# Calculate target basis for player that is rotated on rotation axis
	var target_basis := global_transform.basis.rotated(rotation_axis, angle)
	# Use interpolation for smooth rotation
	global_transform.basis = global_transform.basis.slerp(target_basis, delta * rotation_interpolation_speed).orthonormalized()


func _apply_movement(delta: float) -> void:
	# If player is standing on ground
	var on_ground := is_on_floor()
	# Get gravity direction (get normalized gravity vector or set direction to be under the player)
	var gravity_dir := _gravity_vector.normalized() if not _gravity_vector.is_zero_approx() else -transform.basis.y
	# Get movement vector
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	# Direction to what player wants to move (some math shit)
	var wish_dir := (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Separate velocity to vertical and horizontal
	var vertical_vel := velocity.project(gravity_dir)
	var horiz_vel    := velocity - vertical_vel

	# Vertically movement
	if on_ground:
		if vertical_vel.dot(gravity_dir) > 0.0:
			vertical_vel = Vector3.ZERO
		if Input.is_action_just_pressed("up"):
			vertical_vel = -gravity_dir * jump_velocity

	vertical_vel += _gravity_vector * delta

	# Horizontal movement
	var control       := 1.0 if on_ground else air_multiplier
	var current_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed

	if wish_dir.length_squared() > 0.0001:
		horiz_vel = horiz_vel.lerp(wish_dir * current_speed, acceleration * control * delta)
	else:
		horiz_vel = horiz_vel.lerp(Vector3.ZERO, deceleration * control * delta)

	# Add horizontal and vertical velocity together
	velocity = horiz_vel + vertical_vel


func _apply_noclip(delta: float) -> void:
	# Get movement direction (left/right/forward/backward)
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	# Get vertical movement direction (up/down)
	var vertical_input := Input.get_axis("down", "up")

	# Movement is based on camera rotation
	var cam_basis := camera.global_transform.basis
	var wish_dir  := (cam_basis * Vector3(input_dir.x, vertical_input, input_dir.y)).normalized()

	var current_speed := noclip_speed * (2.0 if Input.is_action_pressed("sprint") else 1.0)

	if wish_dir.length_squared() > 0.0001:
		velocity = velocity.lerp(wish_dir * current_speed, acceleration * delta)
	else:
		velocity = velocity.lerp(Vector3.ZERO, deceleration * delta)

	global_position += velocity * delta
