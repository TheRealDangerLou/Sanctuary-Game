extends Node3D

@onready var spawn_point: Node3D = $SpawnPoint

func get_spawn_position() -> Vector3:
	return spawn_point.global_position
