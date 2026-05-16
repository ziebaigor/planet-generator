extends Area3D


func set_enabled(val : bool) -> void:
	monitorable = val
	monitoring = val

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("water_tint_area"):
		area.show()

func _on_area_exited(area: Area3D) -> void:
	if area.is_in_group("water_tint_area"):
		area.hide()
