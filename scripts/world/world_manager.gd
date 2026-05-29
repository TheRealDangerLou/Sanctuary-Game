extends Node

var _current_zone: String = ""
var _discovered_zones: Array[String] = []

func _ready() -> void:
	GameManager.world_manager = self
	EventBus.zone_entered.connect(_on_zone_entered)
	EventBus.zone_exited.connect(_on_zone_exited)
	Logger.info("WorldManager: ready")

func get_current_zone() -> String:
	return _current_zone

func get_discovered_zones() -> Array[String]:
	return _discovered_zones.duplicate()

func is_zone_discovered(zone_id: String) -> bool:
	return _discovered_zones.has(zone_id)

func _on_zone_entered(zone_id: String) -> void:
	_current_zone = zone_id
	if not _discovered_zones.has(zone_id):
		_discovered_zones.append(zone_id)
	Logger.info("WorldManager: entered '%s'" % zone_id)

func _on_zone_exited(zone_id: String) -> void:
	if _current_zone == zone_id:
		_current_zone = ""
	Logger.info("WorldManager: exited '%s'" % zone_id)
