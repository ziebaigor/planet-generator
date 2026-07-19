class_name PlayerController
extends CharacterBody3D

@export var mouse_sensitivity : float = 0.002

@export_group("Movement Settings")
@export var walk_speed      : float = 6.0
@export var sprint_speed    : float = 12.0
@export var acceleration    : float = 12.0
@export var deceleration    : float = 16.0
@export var jump_velocity   : float = 12.0
@export var air_multiplier  : float = 0.2
@export var noclip_speed    : float = 25.0
@export var noclip_roll_speed : float = 1
@export var mag_boots_force : float = 20.0

@export_group("Camera Offset Effect")
@export var offset_enabled     : bool = true
@export var jump_offset        : float = 0.5
@export var land_offset        : float = 1.0
@export var set_offset_speed   : float = 15.0
@export var clear_offset_speed : float = 10.0

@export_group("FOV Settings")
@export var fov_enabled     : bool = true
@export var base_fov        : float = 75.0
@export var max_fov         : float = 125.0
@export var max_fall_speed  : float = 30.0
@export var fov_set_speed   : float = 5.0

@export_group("Gravity Set Speeds")
@export var gravity_set_speed  : float = 10.0
@export var rotation_set_speed : float = 8.0

var gravity_sources : Array[Node3D] = []
var noclip          : bool = false
var mag_boots       : bool = false

var _was_on_floor            : bool = false
var _fall_speed              : float = 0.0
var _target_camera_y_offset  : float = 0.0
var _current_camera_y_offset : float = 0.0
var _camera_y_default        : float = 0.0

var _gravity_vector : Vector3 = Vector3.ZERO
var _camera_pitch   : float = 0.0

@onready var camera         : Camera3D = $Camera3D
@onready var floor_detector : ShapeCast3D = $FloorDetector


func _ready() -> void:
	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Set default camera height
	_camera_y_default = camera.position.y
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
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if is_mouse_captured else Input.MOUSE_MODE_CAPTURED)

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
	# Apply movement from input
	_apply_movement(delta)
	# Apply camera offset effect
	if offset_enabled: _process_camera_offset(delta)
	# Apply FOV changes
	if fov_enabled: _process_fov(delta)
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


func _process_camera_offset(delta: float) -> void:
	# Smooth clearing target camera offset by interpolation
	_target_camera_y_offset = lerp(_target_camera_y_offset, 0.0, delta * clear_offset_speed)
	# Smooth setting current camera offset to target camera offset
	_current_camera_y_offset = lerp(_current_camera_y_offset, _target_camera_y_offset, delta * set_offset_speed)
	# Applying smoothed camera offset to camera position
	camera.position.y = _camera_y_default + _current_camera_y_offset


func _process_fov(delta: float) -> void:
	var target_fov := base_fov
	
	# If player has enought falling speed
	if _fall_speed > 2.0:
		# Speed ratio between 0.0 and 1.0
		var speed_ratio : float = clamp((_fall_speed - 2) / max_fall_speed, 0.0, 1.0)
		# Setting target FOV based on speed ratio
		target_fov = lerp(base_fov, max_fov, speed_ratio)
	
	# Smooth setting camera FOV to target FOV
	camera.fov = lerp(camera.fov, target_fov, delta * fov_set_speed)


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
			if source is GravitySource:
				# Add all gravity vectors that influences player
				target_gravity += source.get_gravity_vector(global_position)

	# Gravity vector smoothing
	if _gravity_vector.is_zero_approx() or _gravity_vector.distance_squared_to(target_gravity) < 0.01:
		# Set gravity vector withour smoothing if it was zero before or changed very little
		_gravity_vector = target_gravity
	else:
		# Set gravity vector with interpolation (smoothing)
		_gravity_vector = _gravity_vector.lerp(target_gravity, delta * gravity_set_speed)


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
	global_transform.basis = global_transform.basis.slerp(target_basis, delta * rotation_set_speed).orthonormalized()


func _apply_movement(delta: float) -> void:
	# If player is standing on ground
	var on_ground := is_on_floor()
	# Gravity direction (get normalized gravity vector or set direction to be under the player)
	var gravity_dir := _gravity_vector.normalized() if not _gravity_vector.is_zero_approx() else -transform.basis.y
	# Input direction from keyboard/pad (2d space)
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	# Target direction where player wants to move (applied to 3d space)
	var target_dir := (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# If player has just landed on floor
	if on_ground and not _was_on_floor:
		# Calculate impact force based on fall speed
		var impact_multiplier = clamp(_fall_speed / 10.0, 0.5, 2.5)
		# Set target camera offset based on impact force
		_target_camera_y_offset = -land_offset * impact_multiplier
	
	# Save state for next physics frame
	_was_on_floor = on_ground
	_fall_speed = velocity.dot(gravity_dir)
	
	# Separate velocity to vertical and horizontal
	var vertical_vel := velocity.project(gravity_dir)
	var horiz_vel    := velocity - vertical_vel

	# Vertical movement
	# When player is standing on ground
	if on_ground:
		# If vertical_vel and gravity_dir are pointing similar direction
		if vertical_vel.dot(gravity_dir) > 0.0:
			# Reset vertical velocity
			vertical_vel = Vector3.ZERO
		if Input.is_action_just_pressed("up"):
			# Set jump velocity
			vertical_vel = -gravity_dir * jump_velocity
			# Set target camera offset to jump offset
			_target_camera_y_offset = jump_offset

	# Add gravity velocity
	vertical_vel += _gravity_vector * delta

	# Horizontal movement
	# Movement control multiplier based on player position (on the ground or in the air)
	var control       := 1.0 if on_ground else air_multiplier
	# Current horizonstal speed depending on sprint pressed
	var current_speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed

	# If player wants to move in target direction
	if target_dir.length_squared() > 0.0001:
		# Smooth acceleration towards target_dir by interpolation
		horiz_vel = horiz_vel.lerp(target_dir * current_speed, acceleration * control * delta)
	# If player don't want to move (target direction is zero)
	else:
		# Smooth deceleration towards Vector3.ZERO by interpolation
		horiz_vel = horiz_vel.lerp(Vector3.ZERO, deceleration * control * delta)

	# Add horizontal and vertical velocity together
	velocity = horiz_vel + vertical_vel


func _apply_noclip(delta: float) -> void:
	# Movement direction (left/right/forward/backward)
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	# Vertical movement direction (up/down)
	var vertical_input := Input.get_axis("down", "up")
	# Target direction where player wants to move based on camera basis
	var target_dir := (camera.global_transform.basis * Vector3(input_dir.x, vertical_input, input_dir.y)).normalized()
	# Current speed depending on sprint pressed (sprint multiplies speed by 2)
	var current_speed := noclip_speed * (2.0 if Input.is_action_pressed("sprint") else 1.0)

	# If player wants to move in target direction
	if target_dir.length_squared() > 0.0001:
		# Smooth acceleration towards target_dir by interpolation
		velocity = velocity.lerp(target_dir * current_speed, acceleration * delta)
	# If player don't want to move (target direction is zero)
	else:
		# Smooth deceleration towards Vector3.ZERO by interpolation
		velocity = velocity.lerp(Vector3.ZERO, deceleration * delta)

	# Roll rotation input using Q and E keys.
	# Q rolls left (counterclockwise when looking forward),
	# E rolls right (clockwise when looking forward).
	# This lets the player level themselves while flying around freely.
	var roll_input := 0.0
	if Input.is_action_pressed("roll_right"):
		roll_input -= 1.0
	if Input.is_action_pressed("roll_left"):
		roll_input += 1.0
	
	# Apply roll rotation around the camera's forward axis.
	# The camera's basis Z points backward, so a positive angle
	# produces a clockwise roll when viewed from the player's perspective.
	if abs(roll_input) > 0.01:
		var forward_axis := camera.global_transform.basis.z.normalized()
		rotate(forward_axis, roll_input * noclip_roll_speed * delta)

	# Set new position without collisions
	global_position += velocity * delta
