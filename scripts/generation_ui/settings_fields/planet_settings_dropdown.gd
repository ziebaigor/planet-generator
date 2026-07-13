class_name PlanetSettingsDropdown
extends PlanetSettingsField

@export var options : Dictionary = {}

func _ready() -> void:
	call("clear")
	var i = 0
	for key in options.keys():
		call("add_item", key)
		call("set_item_metadata", i, options[key])
		i += 1
	
	# Connect to the OptionButton's signal dynamically
	var err = connect("item_selected", _on_item_selected)
	if err != OK and err != ERR_INVALID_PARAMETER:
		push_error("Failed to connect item_selected")

func _on_item_selected(index: int) -> void:
	var val = call("get_item_metadata", index)
	value_changed.emit(connected_property, val)
	if causes_regeneration:
		request_regeneration.emit()

func fill(val) -> void:
	# Access item_count property dynamically
	var count = get("item_count")
	for i in range(count):
		if call("get_item_metadata", i) == val:
			call("select", i)
			return
