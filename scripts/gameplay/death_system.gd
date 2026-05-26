extends Node
class_name DeathSystem
## DeathSystem: Handles permanent death, legacy record persistence, and save wipe.
## Tracks per-run stats (enemies killed, corpses looted) that enrich the legacy screen.
## On character_died_permanently: appends a legacy record to disk and wipes all save slots.

const LEGACY_FILE_PATH: String = "user://legacy_records.json"

# ─────────────────────────────────────────────
# State
# ─────────────────────────────────────────────

var _enemies_killed: int = 0
var _corpses_looted: int = 0
var _is_death_processed: bool = false

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	GameManager.death_system = self
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.corpse_looted.connect(_on_corpse_looted)
	EventBus.character_died_permanently.connect(_on_character_died_permanently)
	EventBus.player_spawned.connect(_on_player_spawned)

# ─────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────

## Returns a snapshot of the current run's tracked statistics.
func get_run_stats() -> Dictionary:
	return {
		"enemies_killed": _enemies_killed,
		"corpses_looted": _corpses_looted,
	}

## Resets all per-run tracking for a new playthrough. Called automatically on player_spawned.
func reset_run_stats() -> void:
	_enemies_killed = 0
	_corpses_looted = 0
	_is_death_processed = false

# ─────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────

func _on_character_died_permanently(legacy_data: Dictionary) -> void:
	if _is_death_processed:
		return
	_is_death_processed = true

	var enriched: Dictionary = legacy_data.duplicate()
	enriched["enemies_killed"] = _enemies_killed
	enriched["corpses_looted"] = _corpses_looted
	enriched["final_inventory"] = GameManager.inventory_manager.get_all_items() \
		if GameManager.inventory_manager else {}

	_append_legacy_record(enriched)
	_wipe_save_data()

func _on_enemy_killed(_enemy_type: String, _position: Vector3) -> void:
	_enemies_killed += 1

func _on_corpse_looted(_corpse_id: String) -> void:
	_corpses_looted += 1

func _on_player_spawned(_position: Vector3) -> void:
	reset_run_stats()

## Appends the enriched death record to the persistent hall-of-fame JSON file.
func _append_legacy_record(record: Dictionary) -> void:
	var existing: Array = []
	if FileAccess.file_exists(LEGACY_FILE_PATH):
		var f: FileAccess = FileAccess.open(LEGACY_FILE_PATH, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Array:
				existing = parsed
	existing.append(record)
	var f2: FileAccess = FileAccess.open(LEGACY_FILE_PATH, FileAccess.WRITE)
	if f2:
		f2.store_string(JSON.stringify(existing, "\t"))
		f2.close()

## Deletes all save slots on disk to enforce permadeath.
## Agent 11 will extend this when full save serialisation is implemented.
func _wipe_save_data() -> void:
	for slot: int in range(SaveSystem.MAX_SAVE_SLOTS):
		var path: String = SaveSystem.get_save_path(slot)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
