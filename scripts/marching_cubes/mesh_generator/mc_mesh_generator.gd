class_name MarchingCubesMeshGenerator
extends RefCounted

var density_generator : DensityGenerator = PlanetDensityGenerator.new()
var iso_level := 0.0

var color_generator : ColorGenerator = RadialColorGenerator.new()

const CUBE_CORNERS : Array[Vector3] = [
	Vector3i(0,0,0),
	Vector3i(1,0,0),
	Vector3i(1,1,0),
	Vector3i(0,1,0),
	Vector3i(0,0,1),
	Vector3i(1,0,1),
	Vector3i(1,1,1),
	Vector3i(0,1,1),
]


func generate_mesh_arrays(chunk_origin : Vector3, size : int) -> Array:
	var vertices : PackedVector3Array = []
	var indices : PackedInt32Array = []
	var normals : PackedVector3Array = []
	var colors : PackedColorArray = []
	
	var cache : Dictionary[Vector3,float] = {}
	
	for x in range(size):
		for y in range(size):
			for z in range(size):
				var world_pos = chunk_origin + Vector3(x, y, z)
				_calculate_cube_verts(world_pos, chunk_origin, cache, 
					vertices, indices, normals, colors)
	
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	
	return arrays


func _calculate_cube_verts(start_pos : Vector3, 
		chunk_origin : Vector3,
		cache : Dictionary[Vector3,float],
		vertices : PackedVector3Array, 
		indices : PackedInt32Array,
		normals : PackedVector3Array,
		colors : PackedColorArray) -> void:
	
	var corner_positions : PackedVector3Array = []
	var corner_values : PackedFloat32Array = []
	var cube_index := 0
	
	for i in range(8):
		var pos = start_pos + CUBE_CORNERS[i]
		corner_positions.append(pos)
		
		if !cache.has(pos):
			cache[pos] = _get_density(pos)
		
		corner_values.append(cache[pos])
		
		if corner_values[i] < iso_level:
			cube_index |= 1 << i
	
	# Early return - don't need to do anything
	if cube_index == 0:
		return
	
	var edge_vertices = []
	edge_vertices.resize(12)
	
	for edge in range(12):
		var a = MCTables.EDGE_CONNECTIONS[edge][0]
		var b = MCTables.EDGE_CONNECTIONS[edge][1]
		
		var val_a = corner_values[a]
		var val_b = corner_values[b]
		
		# Check if edge crosses surface
		if (val_a < iso_level) != (val_b < iso_level):
			var interpolated := _vertex_interp(
				corner_positions[a],
				corner_positions[b],
				val_a,
				val_b
			)
			edge_vertices[edge] = interpolated
	
	var triangles = MCTables.TRI_TABLE[cube_index]
	for i in range(0, 16, 3):
		if triangles[i] == -1:
			break
		
		var base_index = vertices.size()
		
		var v0 = edge_vertices[triangles[i]]
		var v1 = edge_vertices[triangles[i+1]]
		var v2 = edge_vertices[triangles[i+2]]
		
		vertices.append(v0 - chunk_origin)
		vertices.append(v1 - chunk_origin)
		vertices.append(v2 - chunk_origin)
		
		indices.append(base_index)
		indices.append(base_index + 1)
		indices.append(base_index + 2)
		
		normals.append(_compute_normal(v0))
		normals.append(_compute_normal(v1))
		normals.append(_compute_normal(v2))
		
		colors.append(_get_color(v0))
		colors.append(_get_color(v1))
		colors.append(_get_color(v2))



func _vertex_interp(p1 : Vector3, p2 : Vector3, val1 : float, val2 : float) -> Vector3:
	var t = (iso_level - val1) / (val2 - val1)
	return p1 + t * (p2 - p1)

func _compute_normal(p: Vector3) -> Vector3:
	var e = 0.01
	var dx = _get_density(p + Vector3(e,0,0)) - _get_density(p - Vector3(e,0,0))
	var dy = _get_density(p + Vector3(0,e,0)) - _get_density(p - Vector3(0,e,0))
	var dz = _get_density(p + Vector3(0,0,e)) - _get_density(p - Vector3(0,0,e))
	return Vector3(dx, dy, dz).normalized()

func _get_density(pos : Vector3) -> float:
	return density_generator.get_density(pos)

func _get_color(pos : Vector3) -> Color:
	return color_generator.get_color(pos)
