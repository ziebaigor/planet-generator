class_name PlanetSettingsInputField
extends PlanetSettingsField

# TODO: Type formating

@export var constrain_min := -9999999999
@export var constrain_max := 9999999999

var old_text := ""

func _ready() -> void:
	old_text = get("text")

func _on_text_submitted(new_text: String) -> void:
	if new_text == old_text:
		return
	
	if !new_text.is_valid_float():
		request_fill_me.emit(self, connected_property)
		return
	
	var new_val := new_text.to_float()
	if new_val > constrain_max or new_val < constrain_min:
		request_fill_me.emit(self, connected_property)
		return
	
	old_text = new_text
	
	value_changed.emit(connected_property, new_val)
	if causes_regeneration:
		request_regeneration.emit()

func _on_focus_exited() -> void:
	_on_text_submitted(get("text"))


func fill(_val) -> void:
	set("text", str(_val))
	old_text = str(_val)
