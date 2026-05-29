extends Area3D

@export var zone_id: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		EventBus.zone_entered.emit(zone_id)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		EventBus.zone_exited.emit(zone_id)
