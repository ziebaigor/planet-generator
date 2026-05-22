@abstract class_name PlanetSettingsField
extends Control

@export var connected_property := ""
@export var causes_regeneration := true

@warning_ignore("unused_signal")
signal request_fill_me(me : PlanetSettingsInputField, property : String)
@warning_ignore("unused_signal")
signal value_changed(property : String, new_value)
@warning_ignore("unused_signal")
signal request_regeneration()


@abstract func fill(_val) -> void
