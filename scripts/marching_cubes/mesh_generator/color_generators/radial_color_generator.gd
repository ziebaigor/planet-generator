class_name RadialColorGenerator
extends ColorGenerator

@export var color_gradient : Gradient = Gradient.new()
@export var color_gradient_height := 50



func get_color(pos: Vector3) -> Color:
	var dist = pos.length()
	return color_gradient.sample( remap(dist, 0.0, color_gradient_height, 0.0, 1.0) )
