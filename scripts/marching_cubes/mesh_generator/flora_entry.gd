class_name FloraEntry
extends Resource

# Enum defining where this specific plant can spawn
enum SpawnArea {
	SURFACE,      # Above water level
	UNDERWATER,   # Below water level
	EVERYWHERE    # Ignore water level
}

@export var scene : PackedScene
@export var spawn_area : SpawnArea = SpawnArea.SURFACE
# Probability weight for this plant to be chosen over others (e.g., 1.0 = normal, 2.0 = twice as likely)
@export_range(0.0, 10.0, 0.1) var weight : float = 1.0
