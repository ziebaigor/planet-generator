## Prints debug information about time of MarchingCubes generation
##
## Make this node a child of a [MarchingCubes] for it to work
extends Node

@export var disable := false

var planet_start : float
var chunk_starts : Dictionary[Vector3, float] = {}
var time := 0.0

var chunk_times_raport_string := ""
var total_mesh_vertices := 0
var total_mesh_indices := 0

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
	print("Chunk generation times:")
	print(chunk_times_raport_string)
	
	var total_elapsed := time - planet_start
	print("Mesh generation time: %.2f" % total_elapsed)
	
	print("Total mesh vertices: %d" % total_mesh_vertices)
	print("Total mesh indices: %d" % total_mesh_indices)

func _on_chunk_generation_started(coords : Vector3) -> void:
	chunk_starts[coords] = time

func _on_chunk_generation_finished(coords : Vector3, chunk_node : MeshInstance3D) -> void:
	# Calculate generation time
	var elapsed := time - chunk_starts[coords]
	#print(elapsed)
	
	if !chunk_times_raport_string.is_empty():
		chunk_times_raport_string += ","
	chunk_times_raport_string += "%.4f" % elapsed
	
	
	
	# Calculate vertices and indices
	var total_vertices = 0
	var total_indices = 0
	
	if chunk_node != null:
		for surface in range(chunk_node.mesh.get_surface_count()):
			var arrays = chunk_node.mesh.surface_get_arrays(surface)
			
			# Vertices
			var vertices = arrays[Mesh.ARRAY_VERTEX]
			total_vertices += vertices.size()
			
			# Indices
			var indices = arrays[Mesh.ARRAY_INDEX]
			if indices != null:
				total_indices += indices.size()
		
		#print("Vertices:", total_vertices)
		#print("Indices:", total_indices)
		
		total_mesh_vertices += total_vertices
		total_mesh_indices += total_indices
