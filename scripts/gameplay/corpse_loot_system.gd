extends Node
class_name CorpseLootSystem
## CorpseLootSystem: Spawns lootable corpse containers when enemies are killed.
## Items are determined per enemy type via chance-based loot tables.
## Corpses despawn after CORPSE_LIFETIME real-world seconds if not looted.

const CORPSE_LIFETIME: float = 300.0  ## 5 real minutes before despawn

## Loot tables: enemy_type → Array[{item_id, min_qty, max_qty, chance}]
const LOOT_TABLES: Dictionary = {
	"zombie": [
		{"item_id": "cloth_rag",   "min_qty": 1, "max_qty": 3, "chance": 0.60},
		{"item_id": "bandage",     "min_qty": 1, "max_qty": 1, "chance": 0.20},
		{"item_id": "scrap_metal", "min_qty": 1, "max_qty": 2, "chance": 0.30},
	],
	"bandit": [
		{"item_id": "9mm_ammo",    "min_qty": 5, "max_qty": 15, "chance": 0.70},
		{"item_id": "bandage",     "min_qty": 1, "max_qty": 2,  "chance": 0.40},
		{"item_id": "cloth_rag",   "min_qty": 1, "max_qty": 2,  "chance": 0.50},
		{"item_id": "scrap_metal", "min_qty": 1, "max_qty": 3,  "chance": 0.40},
	],
	"default": [
		{"item_id": "cloth_rag",   "min_qty": 1, "max_qty": 2, "chance": 0.50},
		{"item_id": "scrap_metal", "min_qty": 1, "max_qty": 2, "chance": 0.30},
	],
}

# ─────────────────────────────────────────────
# State
# ─────────────────────────────────────────────

## corpse_id → { position: Vector3, items: Dictionary, time_remaining: float, looted: bool }
var _corpses: Dictionary = {}
var _next_corpse_id: int = 0

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	GameManager.corpse_loot_system = self
	EventBus.enemy_killed.connect(_on_enemy_killed)

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	_tick_corpse_timers(delta)

# ─────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────

## Returns a Dictionary of active (unlooted) corpse IDs mapped to their world positions.
func get_available_corpses() -> Dictionary:
	var result: Dictionary = {}
	for cid: String in _corpses:
		if not _corpses[cid]["looted"]:
			result[cid] = _corpses[cid]["position"]
	return result

## Returns the item contents of a corpse without consuming them (read-only peek).
func peek_corpse(corpse_id: String) -> Dictionary:
	if not _corpses.has(corpse_id):
		return {}
	return _corpses[corpse_id]["items"].duplicate()

## Transfers all items from a corpse to the player's inventory via item_picked_up signals.
## Returns false if the corpse does not exist or has already been looted.
func loot_corpse(corpse_id: String) -> bool:
	if not _corpses.has(corpse_id):
		return false
	var c: Dictionary = _corpses[corpse_id]
	if c["looted"]:
		return false
	c["looted"] = true
	for item_id: String in c["items"]:
		var qty: int = c["items"][item_id]
		if qty > 0:
			EventBus.item_picked_up.emit(item_id, qty)
	EventBus.corpse_looted.emit(corpse_id)
	return true

## Returns true if the corpse exists and has not yet been looted.
func has_corpse(corpse_id: String) -> bool:
	return _corpses.has(corpse_id) and not _corpses[corpse_id]["looted"]

## Returns seconds remaining before a corpse despawns. Returns -1.0 if no such corpse exists.
func get_time_remaining(corpse_id: String) -> float:
	if not _corpses.has(corpse_id):
		return -1.0
	return _corpses[corpse_id]["time_remaining"]

## Returns the total number of tracked corpses (including looted, awaiting cleanup).
func get_corpse_count() -> int:
	return _corpses.size()

# ─────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────

func _on_enemy_killed(enemy_type: String, position: Vector3) -> void:
	var cid: String = "corpse_%d" % _next_corpse_id
	_next_corpse_id += 1
	_corpses[cid] = {
		"position": position,
		"items": _roll_loot(enemy_type),
		"time_remaining": CORPSE_LIFETIME,
		"looted": false,
	}
	EventBus.corpse_spawned.emit(cid, position)

func _roll_loot(enemy_type: String) -> Dictionary:
	var table: Array = LOOT_TABLES.get(enemy_type, LOOT_TABLES["default"])
	var result: Dictionary = {}
	for entry: Dictionary in table:
		if randf() <= entry["chance"]:
			var qty: int = randi_range(entry["min_qty"], entry["max_qty"])
			result[entry["item_id"]] = result.get(entry["item_id"], 0) + qty
	return result

func _tick_corpse_timers(delta: float) -> void:
	var to_remove: Array[String] = []
	for cid: String in _corpses:
		var c: Dictionary = _corpses[cid]
		if c["looted"]:
			to_remove.append(cid)
			continue
		c["time_remaining"] -= delta
		if c["time_remaining"] <= 0.0:
			to_remove.append(cid)
			EventBus.corpse_despawned.emit(cid)
	for cid: String in to_remove:
		_corpses.erase(cid)
