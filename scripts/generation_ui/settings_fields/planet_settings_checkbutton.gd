class_name PlanetSettingsCheckbutton
extends PlanetSettingsField


func _on_toggled(toggled_on: bool) -> void:
	value_changed.emit(connected_property, toggled_on)
	if causes_regeneration:
		request_regeneration.emit()

func fill(_on) -> void:
	call("set_pressed_no_signal", bool(_on))
