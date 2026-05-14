class_name MarchingCubesMeshGeneratorV2
extends RefCounted


var density_generator : DensityGenerator = PlanetDensityGenerator.new()
var iso_level := 0.0

var color_generator : ColorGenerator = RadialColorGenerator.new()


const CUBE_CORNERS : Array[Vector3i] = [
	Vector3i(0,0,0),
	Vector3i(1,0,0),
	Vector3i(1,1,0),
	Vector3i(0,1,0),
	Vector3i(0,0,1),
	Vector3i(1,0,1),
	Vector3i(1,1,1),
	Vector3i(0,1,1),
]


func generate_mesh_arrays(chunk_origin : Vector3i, size : int) -> Array:
	var vertices : PackedVector3Array = []
	var indices : PackedInt32Array = []
	var normals : PackedVector3Array = []
	var colors : PackedColorArray = []
	
	# Cached density samples
	var density_cache : Dictionary = {}
	
	# Shared edge vertex cache
	var vertex_cache : Dictionary = {}
	
	# 1-cube padding
	for x in range(-1, size + 1):
		for y in range(-1, size + 1):
			for z in range(-1, size + 1):
	
	# No padding
	#for x in range(size):
	#	for y in range(size):
	#		for z in range(size):
				
				var local_pos = Vector3i(x, y, z)
				var world_pos = chunk_origin + local_pos
				
				# Padding cubes don't edit geometry, but
				# affect normals to avoid chunk borders
				var is_padding = (
					x < 0 || y < 0 || z < 0 ||
					x >= size || y >= size || z >= size
				)
				
				_calculate_cube_verts(
					world_pos,
					chunk_origin,
					density_cache,
					vertex_cache,
					vertices,
					indices,
					normals,
					colors,
					is_padding
				)
	
	# Normalize normals
	for i in range(normals.size()):
		var n = normals[i]
		
		if n.length_squared() > 0.000001:
			normals[i] = n.normalized()
		else:
			normals[i] = Vector3.UP
	
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	
	return arrays


func _calculate_cube_verts(
	start_pos : Vector3i,
	chunk_origin : Vector3i,
	density_cache : Dictionary,
	vertex_cache : Dictionary,
	vertices : PackedVector3Array,
	indices : PackedInt32Array,
	normals : PackedVector3Array,
	colors : PackedColorArray,
	is_padding : bool
) -> void:
	
	var corner_positions : Array[Vector3i] = []
	var corner_values : PackedFloat32Array = []
	
	var cube_index := 0
	
	# Sample cube corners
	for i in range(8):
		var pos = start_pos + CUBE_CORNERS[i]
		
		corner_positions.append(pos)
		
		if !density_cache.has(pos):
			density_cache[pos] = _get_density(pos)
		
		var density = density_cache[pos]
		
		corner_values.append(density)
		
		if density < iso_level:
			cube_index |= 1 << i
	
	# Fully empty/full
	if cube_index == 0 or cube_index == 255:
		return
	
	var edge_vertex_indices : Array[int] = []
	edge_vertex_indices.resize(12)
	
	# Create/reuse edge vertices
	for edge in range(12):
		var a : int = MCTables.EDGE_CONNECTIONS[edge][0]
		var b : int = MCTables.EDGE_CONNECTIONS[edge][1]
		
		var val_a := corner_values[a]
		var val_b := corner_values[b]
		
		# Surface crosses edge
		if (val_a < iso_level) != (val_b < iso_level):
			
			var p1 : Vector3i = corner_positions[a]
			var p2 : Vector3i = corner_positions[b]
			
			var vertex_index = _get_or_create_vertex(
				p1,
				p2,
				val_a,
				val_b,
				chunk_origin,
				vertex_cache,
				vertices,
				normals,
				colors,
			)
			
			edge_vertex_indices[edge] = vertex_index
	
	# Generate triangles
	var triangles : Array = MCTables.TRI_TABLE[cube_index]
	
	for i in range(0, 16, 3):
		if triangles[i] == -1:
			break
		
		var i0 : int = edge_vertex_indices[triangles[i]]
		var i1 : int = edge_vertex_indices[triangles[i + 1]]
		var i2 : int = edge_vertex_indices[triangles[i + 2]]
		
		var v0 : Vector3 = vertices[i0]
		var v1 : Vector3 = vertices[i1]
		var v2 : Vector3 = vertices[i2]
		
		# Skip bad triangles
		if \
		v0.distance_squared_to(v1) < 0.000001 || \
		v1.distance_squared_to(v2) < 0.000001 || \
		v2.distance_squared_to(v0) < 0.000001:
			continue
		
		var face_normal = (v2 - v0).cross(v1 - v0)
		
		if face_normal.length_squared() < 0.000001:
			continue
		
		face_normal = face_normal.normalized()
		
		# ALWAYS accumulate normals
		normals[i0] += face_normal
		normals[i1] += face_normal
		normals[i2] += face_normal
		
		# ONLY real chunk cubes edit geometry
		if !is_padding:
			indices.append(i0)
			indices.append(i1)
			indices.append(i2)


func _get_or_create_vertex(
	p1 : Vector3i,
	p2 : Vector3i,
	val1 : float,
	val2 : float,
	chunk_origin : Vector3i,
	vertex_cache : Dictionary,
	vertices : PackedVector3Array,
	normals : PackedVector3Array,
	colors : PackedColorArray,
) -> int:
	
	var key = _make_edge_key(p1, p2)
	
	# Reuse shared vertex
	if vertex_cache.has(key):
		return vertex_cache[key]
	
	# Padding cubes cannot create new vertices
	#if !allow_creation:
	#	return -1
	
	# Create vertex
	var vertex = _vertex_interp(p1, p2, val1, val2)
	
	var index = vertices.size()
	
	vertices.append(vertex - Vector3(chunk_origin))
	normals.append(Vector3.ZERO)
	colors.append(_get_color(vertex))
	
	vertex_cache[key] = index
	
	return index


func _make_edge_key(a : Vector3i, b : Vector3i) -> String:
	if a.x < b.x:
		return str(a) + "|" + str(b)
	
	if a.x > b.x:
		return str(b) + "|" + str(a)
	
	if a.y < b.y:
		return str(a) + "|" + str(b)
	
	if a.y > b.y:
		return str(b) + "|" + str(a)
	
	if a.z < b.z:
		return str(a) + "|" + str(b)
	
	return str(b) + "|" + str(a)


func _vertex_interp(
	p1 : Vector3i,
	p2 : Vector3i,
	val1 : float,
	val2 : float
) -> Vector3:
	
	# Avoid dividing by zero
	if abs(val1 - val2) < 0.00001:
		return Vector3(p1)
	
	var t = (iso_level - val1) / (val2 - val1)
	
	return Vector3(p1) + t * Vector3(p2 - p1)


func _get_density(pos : Vector3) -> float:
	return density_generator.get_density(pos)


func _get_color(pos : Vector3) -> Color:
	return color_generator.get_color(pos)
