extends Node
## SaveSystem: Manages persistence of all game state across sessions.
## Agent 11 (Save & Load System) will fully implement serialisation logic.
## This file defines the canonical save data schema and stub entry points.
## Autoloaded as SaveSystem at startup.

# ─────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────

const SAVE_DIR: String = "user://saves/"
const SAVE_EXTENSION: String = ".sav"
const MAX_SAVE_SLOTS: int = 5
const AUTOSAVE_SLOT: int = 0

# ─────────────────────────────────────────────
# Canonical save data schema
# All fields are defined here so every agent knows what to read/write.
# Vector3 values are stored as sub-Dictionaries {x, y, z} for JSON compatibility.
# ─────────────────────────────────────────────

var save_data: Dictionary = {
	# Metadata
	"meta": {
		"save_version": 1,
		"game_version": "0.1.0",
		"timestamp": "",
		"play_time_seconds": 0,
		"slot": 0,
		"character_name": "",
	},

	# Player vitals and body state
	"player": {
		"health": 100.0,
		"max_health": 100.0,
		"hunger": 100.0,
		"max_hunger": 100.0,
		"thirst": 100.0,
		"max_thirst": 100.0,
		"temperature": 37.0,
		"sanity": 100.0,
		"max_sanity": 100.0,
		"stamina": 100.0,
		"max_stamina": 100.0,
		"position": {"x": 0.0, "y": 0.0, "z": 0.0},
		"rotation": {"x": 0.0, "y": 0.0, "z": 0.0},
		"injuries": [],
		"infection_status": false,
		"infection_stage": 0,
	},

	# Inventory
	"inventory": {
		"items": [],
		"equipped_weapon": "",
		"equipped_armor": {
			"head": "",
			"chest": "",
			"legs": "",
			"feet": "",
			"hands": "",
		},
		"current_weight": 0.0,
		"max_weight": 30.0,
		"hotbar": ["", "", "", "", "", "", "", ""],
	},

	# World / environment state
	"world": {
		"game_day": 1,
		"game_hour": 6,
		"game_minute": 0,
		"weather_type": "clear",
		"weather_intensity": 0.0,
		"season": "summer",
		"zone_id": "start_zone",
		"discovered_zones": [],
		"loot_container_states": {},
	},

	# Settlement / compound
	"settlement": {
		"buildings": [],
		"compound_tier": 0,
		"morale": 50.0,
		"resources": {
			"wood": 0,
			"stone": 0,
			"metal": 0,
			"food": 0,
			"water": 0,
			"medicine": 0,
		},
		"walls": [],
		"perimeter_state": {},
	},

	# NPCs
	"npcs": {
		"recruited": [],
		"dead": [],
		"relationships": {},
		"npc_states": {},
	},

	# Narrative and quests
	"narrative": {
		"daughter_clues_found": [],
		"total_clues": 12,
		"quests_active": [],
		"quests_completed": [],
		"narrative_events_triggered": [],
		"player_choices": {},
	},

	# Reputation
	"reputation": {
		"moral_alignment": 0.0,
		"faction_reputations": {},
	},

	# Knowledge / skills
	"knowledge": {
		"unlocked_recipes": [],
		"unlocked_knowledge": [],
		"skill_levels": {},
	},

	# Statistics
	"statistics": {
		"enemies_killed": 0,
		"days_survived": 0,
		"distance_traveled": 0.0,
		"items_crafted": 0,
		"times_died": 0,
		"total_play_time_seconds": 0,
		"buildings_placed": 0,
		"npcs_saved": 0,
	},
}

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	_ensure_save_directory()

# ─────────────────────────────────────────────
# Public API - implemented by Agent 11
# ─────────────────────────────────────────────

## Serialises the current game state and writes it to the given save slot.
## Emits EventBus.game_saved on success.
func save_game(slot: int) -> void:
	pass

## Reads the specified save slot from disk and restores all game state.
## Emits EventBus.game_loaded on success.
func load_game(slot: int) -> void:
	pass

## Writes a save to AUTOSAVE_SLOT (slot 0) without player interaction.
## Emits EventBus.autosave_triggered before writing.
func autosave() -> void:
	EventBus.autosave_triggered.emit()

## Returns a lightweight Dictionary suitable for a save-slot preview UI.
## Includes: day, play_time, timestamp, character_name. Returns {} if slot is empty.
func get_save_preview(slot: int) -> Dictionary:
	return {}

## Returns true if the given save slot contains valid save data.
func slot_has_data(slot: int) -> bool:
	return FileAccess.file_exists(get_save_path(slot))

## Returns the file path for a given save slot index.
func get_save_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d%s" % [slot, SAVE_EXTENSION]

# ─────────────────────────────────────────────
# Internal
# ─────────────────────────────────────────────

## Creates the save directory on disk if it does not already exist.
func _ensure_save_directory() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
