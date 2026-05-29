class_name PlanetSettingsColorPicker
extends PlanetSettingsField


func _on_color_changed(color: Color) -> void:
	value_changed.emit(connected_property, color)
	if causes_regeneration:
		request_regeneration.emit()

func fill(_col) -> void:
	set("color", Color(_col))
