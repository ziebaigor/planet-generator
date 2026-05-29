class_name PositionInput
extends Control

@onready var x_input : LineEdit = $xInput
@onready var y_input : LineEdit = $yInput
@onready var z_input : LineEdit = $zInput

signal position_changed(new_pos : Vector3)
signal request_fill_me(me : PositionInput)


func _ready() -> void:
	x_input.text_submitted.connect(_field_text_submitted)
	y_input.text_submitted.connect(_field_text_submitted)
	z_input.text_submitted.connect(_field_text_submitted)
	
	x_input.focus_exited.connect(_field_focus_exited)
	y_input.focus_exited.connect(_field_focus_exited)
	z_input.focus_exited.connect(_field_focus_exited)
	
	request_fill_me.emit(self)

func set_pos(new_pos : Vector3) -> void:
	if !is_node_ready():
		await ready
	
	x_input.text = str(new_pos.x)
	y_input.text = str(new_pos.y)
	z_input.text = str(new_pos.z)


func _field_text_submitted(_new_text : String) -> void:
	if not (x_input.text.is_valid_float() and y_input.text.is_valid_float() and z_input.text.is_valid_float()):
		request_fill_me.emit(self)
		return
	
	var new_pos : Vector3
	new_pos.x = x_input.text.to_float()
	new_pos.y = y_input.text.to_float()
	new_pos.z = z_input.text.to_float()
	
	position_changed.emit(new_pos)

func _field_focus_exited() -> void:
	_field_text_submitted("")
