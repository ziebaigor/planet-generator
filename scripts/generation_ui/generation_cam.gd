extends Node3D

@export var target: Node3D

@export var mouse_sensitivity := 1.0
@export var zoom_sensitivity := 1.0

@export var min_pitch := deg_to_rad(-80)
@export var max_pitch := deg_to_rad(80)

@export var min_distance := 50.0
@export var max_distance := 100.0
@export var distance := 70.0

@onready var pitch_pivot : Node3D = $PitchPivot
@onready var camera : Camera3D = $PitchPivot/GenerationCam

var yaw := 0.0
var pitch := 0.0

var dragging := false


func _ready():
	update_camera_position()


func _unhandled_input(event):
	if event is InputEventMouseButton:
		
		# LEFT MOUSE PRESS
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			else:
				dragging = false
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		# MOUSE WHEEL UP
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance -= zoom_sensitivity
			distance = clamp(distance, min_distance, max_distance)
			update_camera_position()
		
		# MOUSE WHEEL DOWN
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance += zoom_sensitivity
			distance = clamp(distance, min_distance, max_distance)
			update_camera_position()
	
	# MOUSE DRAG
	if event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * mouse_sensitivity * 0.001
		pitch -= event.relative.y * mouse_sensitivity * 0.001
		
		pitch = clamp(pitch, min_pitch, max_pitch)
		
		rotation.y = yaw
		pitch_pivot.rotation.x = pitch


func _process(_delta):
	if target == null:
		return
	
	# Keep rig centered on target
	global_position = target.global_position
	camera.look_at(target.global_position)


func update_camera_position():
	camera.position = Vector3(0, 0, distance)
