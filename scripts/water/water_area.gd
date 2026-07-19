extends Area3D

var water_tint_color := Color(0.059, 0.592, 1.0)


func _ready() -> void:
	# Add this area to the "water" group so the player's water detector
	# can recognise it as a water volume and trigger splash/wading sounds.
	add_to_group("water")


func set_enabled(val : bool) -> void:
	monitorable = val
	monitoring = val

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("water_tint_area"):
		# Set color
		area.get_node("WaterTint").get_active_material(0).albedo_color = water_tint_color
		area.show()

func _on_area_exited(area: Area3D) -> void:
	if area.is_in_group("water_tint_area"):
		area.hide()
