## Prints debug information about time of MarchingCubes generation
##
## Make this node a child of a [MarchingCubes] for it to work
extends Node

@export var disable := false

var planet_start : float
var chunk_starts : Dictionary[Vector3, float] = {}
var time := 0.0

var raport_string := ""


func _ready() -> void:
	if disable:
		return
	
	var parent := get_parent()
	if parent is MarchingCubes:
		parent.planet_generation_started.connect(_on_planet_generation_started)
		parent.planet_generation_finished.connect(_on_planet_generation_finished)
		parent.chunk_generation_started.connect(_on_chunk_generation_started)
		parent.chunk_generation_finished.connect(_on_chunk_generation_finished)

func _process(delta: float) -> void:
	time += delta


func _on_planet_generation_started() -> void:
	print("Starting planet generation timer...")
	planet_start = time

func _on_planet_generation_finished() -> void:
	var elapsed := time - planet_start
	#print("Planet generation time: %.2f" % elapsed)
	
	raport_string += "\n%.2f" % elapsed
	print(raport_string)

func _on_chunk_generation_started(coords : Vector3) -> void:
	chunk_starts[coords] = time

func _on_chunk_generation_finished(coords : Vector3) -> void:
	var elapsed := time - chunk_starts[coords]
	#print("%.4f" % elapsed)
	
	if !raport_string.is_empty():
		raport_string += ","
	raport_string += "%.4f" % elapsed
