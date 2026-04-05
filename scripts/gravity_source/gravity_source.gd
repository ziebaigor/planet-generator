class_name GravitySource
extends Area3D

var gravity_radius_multiplier := 1.5
var gravity_strength := 20.0
var constant_gravity := false
var planet_radius : float = 0.0

@onready var gravity_shape : CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	# Disable gravity before the planet is fully generated
	gravity_shape.disabled = true


func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		body.add_gravity_source(self)


func _on_body_exited(body: Node3D) -> void:
	if body is PlayerController:
		body.remove_gravity_source(self)


func generation_done() -> void:
	# Set gravity zone radius
	if planet_radius > 0:
		var sphere := SphereShape3D.new()
		sphere.radius = planet_radius * gravity_radius_multiplier
		gravity_shape.shape = sphere
		# Enable gravity
		gravity_shape.disabled = false
	else:
		# Disable gravity if planet_radius is not valid
		gravity_shape.disabled = true
	
	print("Planet '", get_parent().name, "' generation done!")


func get_gravity_vector(object_position: Vector3) -> Vector3:
	if constant_gravity:
		# If constant gravity is set the gravity vector has always the same strength
		return (global_position - object_position).normalized() * gravity_strength
	else:
		# If else calculate gravity strength based on distance from planet center
		var calculated_strength := 0.0
		var direction := global_position - object_position
		var distance := direction.length()
		
		if distance == 0.0:
			return Vector3.ZERO
		
		if distance < planet_radius:
			# Object is below the planet surface
			# Strength decreases linearly (100% on surface and 0% in center)
			calculated_strength = gravity_strength * (distance / planet_radius)
		else:
			# Object is above the planet surface
			# Strength decreases quadratically
			var distance_ratio := planet_radius / distance
			calculated_strength = gravity_strength * (distance_ratio * distance_ratio)
		
		return direction.normalized() * calculated_strength
