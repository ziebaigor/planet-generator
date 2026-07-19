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

# Water splash sound variants — picked randomly when the player gently enters water.
# The walking and fall sounds are assigned directly in the scene file (.tscn).
var _water_splash_streams : Array[AudioStreamWAV] = [
	preload("res://res/sounds/water_splash_1.wav"),
	preload("res://res/sounds/water_splash_2.wav"),
	preload("res://res/sounds/water_splash_3.wav"),
]

# Fall speed above which a landing is considered a "fall from height" and
# triggers the dedicated fall splash/impact sound instead of nothing.
const FALL_SOUND_THRESHOLD : float = 10.0

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

# Water state tracking.
# _in_water is true while the player body overlaps any water area.
# _was_in_water stores the previous frame state to detect moment of entry.
# _water_area_count tracks how many water areas currently overlap the player
# so that leaving one water area does not clear the state if another still overlaps.
var _in_water        : bool = false
var _was_in_water    : bool = false
var _water_area_count: int = 0

# Base pitch scales read from the AudioStreamPlayer nodes in _ready().
# When sprinting, the code multiplies these values by the ratio of
# sprint_speed to walk_speed so the footsteps speed up proportionally.
var _grass_pitch_base : float = 1.0
var _water_pitch_base : float = 1.0

@onready var camera         : Camera3D = $Camera3D
@onready var floor_detector : ShapeCast3D = $FloorDetector

# Audio players for each sound category.
# Walking players use stream_paused to pause/resume playback so the sound
# continues from where it stopped when the player moves again.
# The water splash player's stream is swapped for a random variant on each entry.
@onready var walking_grass_player    : AudioStreamPlayer = $WalkingGrassSound
@onready var walking_water_player    : AudioStreamPlayer = $WalkingWaterSound
@onready var water_splash_player     : AudioStreamPlayer = $WaterSplashSound
@onready var grass_fall_player       : AudioStreamPlayer = $GrassFallSound
@onready var water_big_splash_player : AudioStreamPlayer = $WaterBigSplashSound


func _ready() -> void:
	# Capture mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Set default camera height
	_camera_y_default = camera.position.y
	# Set not sliding from steep slops
	floor_stop_on_slope = true
	# Set detecting floor that are up to 60 degrees steep
	floor_max_angle = deg_to_rad(60.0)
	
	# Store the base pitch scales of the walking sounds as set in the scene.
	# These values are used to calculate the faster pitch when the player sprints.
	_grass_pitch_base = walking_grass_player.pitch_scale
	_water_pitch_base = walking_water_player.pitch_scale
	
	# Manually loop walking sounds by restarting them when playback finishes.
	# The imported WAVs default to no loop, so we handle looping in code
	# by connecting to the finished signal and replaying if still walking.
	walking_grass_player.finished.connect(_on_walking_grass_finished)
	walking_water_player.finished.connect(_on_walking_water_finished)


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
		# Stop any walking sounds while flying
		_stop_walking_sounds()
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
	# Update looping walking sounds based on current movement and water state
	_update_walking_sound()


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
		
		# Play hard landing sound when hitting the ground from a significant height.
		# Only triggered when not in water (water has its own splash sound).
		if _fall_speed > FALL_SOUND_THRESHOLD and not _in_water:
			grass_fall_player.play()
	
	# Detect the moment the player enters water.
	# A high-speed entry plays the big splash; a gentle entry picks a random small splash.
	if _in_water and not _was_in_water:
		if _fall_speed > FALL_SOUND_THRESHOLD:
			water_big_splash_player.play()
		else:
			var random_index := randi() % _water_splash_streams.size()
			water_splash_player.stream = _water_splash_streams[random_index]
			water_splash_player.play()
	
	# Save state for next physics frame
	_was_in_water = _in_water
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


# Updates the looping walking sounds based on whether the player is moving,
# on the ground, and/or submerged. Called every physics frame after movement.
#
# Pause/resume: stream_paused is used instead of stop/play so the sound
# resumes from the exact position where it was paused when the player
# starts walking again.
#
# Looping: the finished signal is connected in _ready() to restart
# playback when the clip ends, as long as the player is still moving.
#
# Sprint: both grass and water walking sounds are sped up by the same
# ratio of sprint_speed / walk_speed. The base pitch comes from the
# pitch_scale property on each AudioStreamPlayer node in the scene.
func _update_walking_sound() -> void:
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var is_moving := input_dir.length_squared() > 0.01
	var on_ground := is_on_floor()
	var is_sprinting := Input.is_action_pressed("sprint")
	
	# Grass walking: moving on solid ground while not submerged.
	# Start playback the first time, then toggle pause to resume in place.
	if is_moving and on_ground and not _in_water:
		if not walking_grass_player.playing:
			walking_grass_player.play()
		walking_grass_player.stream_paused = false
	else:
		walking_grass_player.stream_paused = true
	
	# Water walking: moving while submerged (wading/swimming).
	# Same pause/resume behavior as grass walking.
	if is_moving and _in_water:
		if not walking_water_player.playing:
			walking_water_player.play()
		walking_water_player.stream_paused = false
	else:
		walking_water_player.stream_paused = true
	
	# When sprinting, speed up both walking sounds proportionally to how
	# much faster the player moves compared to normal walking.
	# The base pitch for each sound comes from the pitch_scale property
	# on the corresponding AudioStreamPlayer node in the scene.
	var pitch_multiplier := sprint_speed / walk_speed if is_sprinting else 1.0
	walking_grass_player.pitch_scale = _grass_pitch_base * pitch_multiplier
	walking_water_player.pitch_scale = _water_pitch_base * pitch_multiplier


# Called when the grass walking sound reaches the end of the clip.
# If the player is still walking (not paused), restart playback to loop seamlessly.
func _on_walking_grass_finished() -> void:
	if not walking_grass_player.stream_paused:
		walking_grass_player.play()


# Called when the water walking sound reaches the end of the clip.
# If the player is still wading (not paused), restart playback to loop seamlessly.
func _on_walking_water_finished() -> void:
	if not walking_water_player.stream_paused:
		walking_water_player.play()


# Stops both looping walking sounds completely.
# Used when entering noclip mode so that walking audio does not linger.
func _stop_walking_sounds() -> void:
	walking_grass_player.stop()
	walking_water_player.stop()


# Called by the WaterDetector Area3D when the player body enters a water volume.
# Only areas in the "water" group are counted.
func _on_water_detector_area_entered(area: Area3D) -> void:
	if area.is_in_group("water"):
		_water_area_count += 1
		_in_water = true


# Called by the WaterDetector Area3D when the player body leaves a water volume.
# The player is considered out of water only when no water areas remain overlapping.
func _on_water_detector_area_exited(area: Area3D) -> void:
	if area.is_in_group("water"):
		_water_area_count -= 1
		if _water_area_count <= 0:
			_water_area_count = 0
			_in_water = false
