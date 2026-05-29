extends Node
## SaveSystem: Two-mode save architecture — STORY and HARDCORE.
##
## STORY MODE (default):
##   Saves ONLY when the player sleeps in a shelter they own.
##   Each shelter gets its own save slot (up to MAX_SAVE_SLOTS).
##   On death: respawn at last shelter save with all progress from that point.
##   No shelter save = no respawn; dying before first sleep ends the run.
##
## HARDCORE MODE:
##   True permadeath. Single slot (slot 0). Autosaves every HARDCORE_AUTOSAVE_INTERVAL seconds.
##   Death fires character_died_permanently → DeathSystem wipes slot 0 → legacy screen.
##
## BOTH MODES:
##   Legacy records (user://legacy_records.json) persist forever.
##   Rose death = game over, no exceptions.

# ─────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────

const SAVE_DIR: String = "user://saves/"
const SAVE_EXTENSION: String = ".sav"
const MAX_SAVE_SLOTS: int = 5
const HARDCORE_AUTOSAVE_SLOT: int = 0
const SAVE_VERSION: int = 1

## Real seconds between autosaves in HARDCORE mode.
const HARDCORE_AUTOSAVE_INTERVAL: float = 60.0

# ─────────────────────────────────────────────
# Canonical save data schema
# Vector3 stored as {x,y,z} dicts for JSON compatibility.
# injuries stored as Dictionary (location → {severity, is_bleeding, is_infected}).
# ─────────────────────────────────────────────

var save_data: Dictionary = {
	"meta": {
		"save_version": SAVE_VERSION,
		"game_version": "0.1.0",
		"timestamp": "",
		"play_time_seconds": 0,
		"slot": 0,
		"character_name": "",
	},

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
		"injuries": {},
		"infection_status": false,
		"infection_stage": 0,
	},

	"rose": {
		"health": 80.0,
		"max_health": 80.0,
		"hunger": 80.0,
		"max_hunger": 80.0,
		"thirst": 80.0,
		"max_thirst": 80.0,
		"stamina": 80.0,
		"max_stamina": 80.0,
		"sanity": 80.0,
		"max_sanity": 80.0,
		"temperature": 37.0,
		"injuries": {},
	},

	"inventory": {
		"items": [],
		"equipped_weapon": "",
		"equipped_armor": {
			"head": "", "chest": "", "legs": "", "feet": "", "hands": "",
		},
		"current_weight": 0.0,
		"max_weight": 30.0,
		"hotbar": ["", "", "", "", "", "", "", ""],
	},

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

	"shelters": {
		"points": [],
		"last_shelter_id": "",
		"game_mode": "story",
	},

	"settlement": {
		"buildings": [],
		"compound_tier": 0,
		"morale": 0.5,
		"resources": {
			"wood": 0, "stone": 0, "metal": 0,
			"food": 0, "water": 0, "medicine": 0,
		},
		"walls": [],
		"perimeter_state": {},
	},

	"npcs": {
		"recruited": [],
		"dead": [],
		"relationships": {},
		"npc_states": {},
	},

	"narrative": {
		"daughter_clues_found": [],
		"total_clues": 12,
		"quests_active": [],
		"quests_completed": [],
		"narrative_events_triggered": [],
		"player_choices": {},
	},

	"reputation": {
		"moral_alignment": 0.0,
		"faction_reputations": {},
	},

	"knowledge": {
		"unlocked_recipes": [],
		"unlocked_knowledge": [],
		"skill_levels": {},
	},

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
# Runtime state
# ─────────────────────────────────────────────

## Seconds elapsed in PLAYING state this session. Stored in meta on every save.
var _play_time_seconds: float = 0.0
## Slot most recently saved to or loaded from (-1 = none this session).
var _current_slot: int = -1
## True when load_game() was called before game systems entered the tree.
var _pending_load: bool = false
## Prevents re-entrant calls inside apply_pending_load().
var _is_loading: bool = false

## STORY: shelter_id → ShelterSavePoint for all registered shelters.
var _shelters: Dictionary = {}
## STORY: shelter_id of the last shelter the player slept at.
var _last_shelter_id: String = ""
## STORY: next save slot index to assign to a new shelter (cycles 0–MAX_SAVE_SLOTS-1).
var _next_slot: int = 0

## HARDCORE: accumulates real time; fires autosave each HARDCORE_AUTOSAVE_INTERVAL.
var _hardcore_autosave_accumulator: float = 0.0

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	_ensure_save_directory()
	EventBus.player_slept.connect(_on_player_slept)
	EventBus.shelter_created.connect(_on_shelter_created)
	EventBus.shelter_destroyed.connect(_on_shelter_destroyed)
	EventBus.player_respawning.connect(_on_player_respawning)

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	_play_time_seconds += delta
	if GameManager.game_mode == GameManager.GameMode.HARDCORE:
		_hardcore_autosave_accumulator += delta
		if _hardcore_autosave_accumulator >= HARDCORE_AUTOSAVE_INTERVAL:
			_hardcore_autosave_accumulator = 0.0
			autosave()

# ─────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────

## Serialises live game state and writes it to the given slot.
## Emits EventBus.game_saved on success.
func save_game(slot: int) -> void:
	_collect_save_data(slot)
	var path: String = get_save_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		Logger.error("SaveSystem: cannot open %s for write" % path)
		return
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	_current_slot = slot
	Logger.info("SaveSystem: saved slot %d (day %d)" % [slot, GameManager.game_day])
	EventBus.game_saved.emit(slot)

## Reads the specified slot and restores all live system state.
## If game systems are already in the scene tree, state is applied immediately.
## Otherwise marks a pending load — call apply_pending_load() once systems are ready.
## Emits EventBus.game_loaded on success.
func load_game(slot: int) -> void:
	var path: String = get_save_path(slot)
	if not FileAccess.file_exists(path):
		Logger.error("SaveSystem: slot %d not found" % slot)
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		Logger.error("SaveSystem: cannot open %s for read" % path)
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		Logger.error("SaveSystem: slot %d is corrupted" % slot)
		return
	save_data = parsed
	var file_version: int = int(save_data.get("meta", {}).get("save_version", 0))
	if file_version != SAVE_VERSION:
		Logger.warn("SaveSystem: slot %d has version %d, current is %d" % [slot, file_version, SAVE_VERSION])
	_play_time_seconds = float(save_data.get("meta", {}).get("play_time_seconds", 0.0))
	_current_slot = slot
	_is_loading = true
	if GameManager.player_stats != null:
		_apply_save_data()
		_pending_load = false
	else:
		_pending_load = true
	_is_loading = false
	Logger.info("SaveSystem: loaded slot %d (day %d)" % [slot, int(save_data.get("world", {}).get("game_day", 1))])
	EventBus.game_loaded.emit(slot)

## Apply a previously-pending load. Call from the gameplay scene after all
## systems have entered the tree (e.g., at the end of the game scene's _ready()).
func apply_pending_load() -> void:
	if not _pending_load:
		return
	_is_loading = true
	_apply_save_data()
	_pending_load = false
	_is_loading = false

## HARDCORE mode only: writes slot 0.
## No-op in STORY mode — saves only happen when sleeping at a shelter.
func autosave() -> void:
	if GameManager.game_mode != GameManager.GameMode.HARDCORE:
		return
	EventBus.autosave_triggered.emit()
	save_game(HARDCORE_AUTOSAVE_SLOT)

## Story mode: save the game at the shelter with the given ID.
## The shelter must be registered (via shelter_created signal or register_shelter()).
## Emits game_saved on success.
func save_at_shelter(shelter_id: String) -> void:
	if not _shelters.has(shelter_id):
		Logger.error("SaveSystem: save_at_shelter — unknown shelter '%s'" % shelter_id)
		return
	_last_shelter_id = shelter_id
	_collect_shelters()
	var sp: ShelterSavePoint = _shelters[shelter_id]
	save_game(sp.save_slot)

## Register a player-built shelter as a save point and assign it a save slot.
## No-op in HARDCORE mode. No-op if shelter_id is already registered.
func register_shelter(
	shelter_id: String,
	display_name: String,
	position: Vector3,
	quality: int,
) -> void:
	if GameManager.game_mode == GameManager.GameMode.HARDCORE:
		return
	if _shelters.has(shelter_id):
		return
	var slot: int = _next_slot
	_next_slot = (_next_slot + 1) % MAX_SAVE_SLOTS
	_shelters[shelter_id] = ShelterSavePoint.new(
		shelter_id, display_name, position, quality, slot, GameManager.game_day
	)
	Logger.info("SaveSystem: registered shelter '%s' on slot %d" % [shelter_id, slot])

## Remove a shelter from the registry (e.g., structure destroyed).
## If it was the last slept-at shelter, falls back to the next available one.
func unregister_shelter(shelter_id: String) -> void:
	if not _shelters.has(shelter_id):
		return
	_shelters.erase(shelter_id)
	if _last_shelter_id == shelter_id:
		_last_shelter_id = "" if _shelters.is_empty() else _shelters.keys()[0]
	Logger.info("SaveSystem: unregistered shelter '%s'" % shelter_id)

## Returns the ShelterSavePoint for the last shelter the player slept at, or null if none.
func get_last_shelter() -> ShelterSavePoint:
	return _shelters.get(_last_shelter_id, null)

## Returns a copy of all registered shelter save points (shelter_id → ShelterSavePoint).
func get_all_shelters() -> Dictionary:
	return _shelters.duplicate()

## Returns a lightweight Dictionary for the save-slot selection UI.
## Keys: slot, timestamp, character_name, game_day, play_time_seconds, save_version,
##       game_mode, last_shelter_id.
## Returns {} if the slot is empty or unreadable.
func get_save_preview(slot: int) -> Dictionary:
	var path: String = get_save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {}
	var meta: Dictionary     = parsed.get("meta", {})
	var world: Dictionary    = parsed.get("world", {})
	var shelters: Dictionary = parsed.get("shelters", {})
	return {
		"slot":              slot,
		"timestamp":         str(meta.get("timestamp", "")),
		"character_name":    str(meta.get("character_name", "")),
		"game_day":          int(world.get("game_day", 1)),
		"play_time_seconds": int(meta.get("play_time_seconds", 0)),
		"save_version":      int(meta.get("save_version", SAVE_VERSION)),
		"game_mode":         str(shelters.get("game_mode", "story")),
		"last_shelter_id":   str(shelters.get("last_shelter_id", "")),
	}

## Returns true if the given slot contains a valid save file on disk.
func slot_has_data(slot: int) -> bool:
	return FileAccess.file_exists(get_save_path(slot))

## Returns the file path for a given slot index.
func get_save_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d%s" % [slot, SAVE_EXTENSION]

# ─────────────────────────────────────────────
# Collect — snapshot live systems into save_data
# ─────────────────────────────────────────────

func _collect_save_data(slot: int) -> void:
	save_data["meta"]["save_version"]      = SAVE_VERSION
	save_data["meta"]["timestamp"]         = Time.get_datetime_string_from_system()
	save_data["meta"]["play_time_seconds"] = int(_play_time_seconds)
	save_data["meta"]["slot"]              = slot
	_collect_player()
	_collect_rose()
	_collect_injuries()
	_collect_sanity()
	_collect_inventory()
	_collect_world()
	_collect_shelters()
	_collect_settlement()
	_collect_knowledge()
	_collect_statistics()

func _collect_player() -> void:
	var ps: SurvivalStats = GameManager.player_stats as SurvivalStats
	if not ps:
		return
	var p: Dictionary = save_data["player"]
	p["health"]      = ps.health
	p["hunger"]      = ps.hunger
	p["thirst"]      = ps.thirst
	p["stamina"]     = ps.stamina
	p["temperature"] = ps.temperature
	var node: Node3D = ps.get_parent() as Node3D
	if node:
		p["position"] = {"x": node.position.x, "y": node.position.y, "z": node.position.z}
		p["rotation"] = {"x": node.rotation.x, "y": node.rotation.y, "z": node.rotation.z}

func _collect_rose() -> void:
	var rs: RoseStats = GameManager.rose_stats as RoseStats
	if not rs:
		return
	var r: Dictionary = save_data["rose"]
	r["health"]      = rs.health
	r["hunger"]      = rs.hunger
	r["thirst"]      = rs.thirst
	r["stamina"]     = rs.stamina
	r["sanity"]      = rs.sanity
	r["temperature"] = rs.temperature

func _collect_injuries() -> void:
	var inj: InjurySystem = GameManager.injury_system as InjurySystem
	if not inj:
		return
	var all: Dictionary          = inj.get_all_injuries()
	var dad_injuries: Dictionary  = {}
	var rose_injuries: Dictionary = {}
	for loc: String in all.keys():
		if loc.begins_with("rose_"):
			rose_injuries[loc] = all[loc].duplicate()
		else:
			dad_injuries[loc] = all[loc].duplicate()
	save_data["player"]["injuries"]         = dad_injuries
	save_data["player"]["infection_status"] = inj.has_any_infection()
	save_data["rose"]["injuries"]           = rose_injuries

func _collect_sanity() -> void:
	var san: SanitySystem = GameManager.sanity_system as SanitySystem
	if not san:
		return
	save_data["player"]["sanity"] = san.sanity

func _collect_inventory() -> void:
	var inv: InventorySystem = GameManager.inventory_manager as InventorySystem
	if not inv:
		return
	var items: Array = []
	for item_id: String in inv.get_all_items().keys():
		items.append({"id": item_id, "qty": inv.get_quantity(item_id)})
	save_data["inventory"]["items"]          = items
	save_data["inventory"]["current_weight"] = inv.get_current_weight()

func _collect_world() -> void:
	save_data["world"]["game_day"]    = GameManager.game_day
	save_data["world"]["game_hour"]   = GameManager.game_hour
	save_data["world"]["game_minute"] = GameManager.game_minute

func _collect_shelters() -> void:
	var points: Array = []
	for sp: ShelterSavePoint in _shelters.values():
		points.append(sp.to_dict())
	save_data["shelters"]["points"]          = points
	save_data["shelters"]["last_shelter_id"] = _last_shelter_id
	save_data["shelters"]["game_mode"]       = "hardcore" if \
		GameManager.game_mode == GameManager.GameMode.HARDCORE else "story"

func _collect_settlement() -> void:
	var comp: CompoundSystem = GameManager.compound_system as CompoundSystem
	if not comp:
		return
	save_data["settlement"]["compound_tier"] = comp.compound_tier
	save_data["settlement"]["morale"]        = comp.settlement_morale
	var buildings: Array = []
	for building_id: String in comp._placed_buildings.keys():
		for placement: Dictionary in comp._placed_buildings[building_id]:
			var pos: Vector3 = placement.get("pos", Vector3.ZERO)
			buildings.append({
				"id":  building_id,
				"pos": {"x": pos.x, "y": pos.y, "z": pos.z},
			})
	save_data["settlement"]["buildings"] = buildings

func _collect_knowledge() -> void:
	var craft: CraftingSystem = GameManager.crafting_system as CraftingSystem
	if not craft:
		return
	save_data["knowledge"]["unlocked_recipes"] = craft.get_known_recipe_ids()

func _collect_statistics() -> void:
	save_data["statistics"]["days_survived"]           = GameManager.game_day
	save_data["statistics"]["total_play_time_seconds"] = int(_play_time_seconds)
	var ds: DeathSystem = GameManager.death_system as DeathSystem
	if ds:
		var run_stats: Dictionary = ds.get_run_stats()
		save_data["statistics"]["enemies_killed"] = run_stats.get("enemies_killed", 0)

# ─────────────────────────────────────────────
# Apply — push loaded save_data into live systems
# ─────────────────────────────────────────────

func _apply_save_data() -> void:
	_apply_world()
	_apply_player()
	_apply_rose()
	_apply_injuries()
	_apply_sanity()
	_apply_inventory()
	_apply_shelters()
	_apply_settlement()
	_apply_knowledge()

func _apply_player() -> void:
	var ps: SurvivalStats = GameManager.player_stats as SurvivalStats
	if not ps:
		return
	var p: Dictionary = save_data.get("player", {})
	ps.health      = float(p.get("health", 100.0))
	ps.hunger      = float(p.get("hunger", 100.0))
	ps.thirst      = float(p.get("thirst", 100.0))
	ps.stamina     = float(p.get("stamina", 100.0))
	ps.temperature = float(p.get("temperature", 37.0))
	ps.is_dead     = false
	var node: Node3D = ps.get_parent() as Node3D
	if node:
		var pos: Dictionary = p.get("position", {})
		var rot: Dictionary = p.get("rotation", {})
		node.position = Vector3(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)), float(pos.get("z", 0.0)))
		node.rotation = Vector3(float(rot.get("x", 0.0)), float(rot.get("y", 0.0)), float(rot.get("z", 0.0)))
	EventBus.player_health_changed.emit(ps.health, ps.MAX_HEALTH)
	EventBus.player_hunger_changed.emit(ps.hunger, ps.MAX_HUNGER)
	EventBus.player_stamina_changed.emit(ps.stamina, ps.MAX_STAMINA)
	EventBus.player_temperature_changed.emit(ps.temperature)

func _apply_rose() -> void:
	var rs: RoseStats = GameManager.rose_stats as RoseStats
	if not rs:
		return
	var r: Dictionary = save_data.get("rose", {})
	rs.health      = float(r.get("health", 80.0))
	rs.hunger      = float(r.get("hunger", 80.0))
	rs.thirst      = float(r.get("thirst", 80.0))
	rs.stamina     = float(r.get("stamina", 80.0))
	rs.sanity      = float(r.get("sanity", 80.0))
	rs.temperature = float(r.get("temperature", 37.0))
	rs.is_dead     = false

func _apply_injuries() -> void:
	var inj: InjurySystem = GameManager.injury_system as InjurySystem
	if not inj:
		return
	inj._injuries.clear()
	var dad_injuries: Dictionary  = save_data.get("player", {}).get("injuries", {})
	var rose_injuries: Dictionary = save_data.get("rose", {}).get("injuries", {})
	for loc: String in dad_injuries.keys():
		var e: Dictionary = dad_injuries[loc]
		inj._injuries[loc] = {
			"severity":    float(e.get("severity", 0.0)),
			"is_bleeding": bool(e.get("is_bleeding", false)),
			"is_infected": bool(e.get("is_infected", false)),
		}
	for loc: String in rose_injuries.keys():
		var e: Dictionary = rose_injuries[loc]
		inj._injuries[loc] = {
			"severity":    float(e.get("severity", 0.0)),
			"is_bleeding": bool(e.get("is_bleeding", false)),
			"is_infected": bool(e.get("is_infected", false)),
		}

func _apply_sanity() -> void:
	var san: SanitySystem = GameManager.sanity_system as SanitySystem
	if not san:
		return
	san.sanity = float(save_data.get("player", {}).get("sanity", 100.0))
	EventBus.player_sanity_changed.emit(san.sanity, san.MAX_SANITY)

func _apply_inventory() -> void:
	var inv: InventorySystem = GameManager.inventory_manager as InventorySystem
	if not inv:
		return
	inv._items.clear()
	inv._current_weight = 0.0
	for entry: Dictionary in save_data.get("inventory", {}).get("items", []):
		var item_id: String = str(entry.get("id", ""))
		var qty: int        = int(entry.get("qty", 0))
		if item_id != "" and qty > 0:
			inv._items[item_id] = qty
	inv._current_weight = float(save_data.get("inventory", {}).get("current_weight", 0.0))
	EventBus.inventory_weight_changed.emit(inv._current_weight, inv.max_weight)

func _apply_world() -> void:
	var w: Dictionary = save_data.get("world", {})
	GameManager.game_day    = int(w.get("game_day", 1))
	GameManager.game_hour   = int(w.get("game_hour", 6))
	GameManager.game_minute = int(w.get("game_minute", 0))
	EventBus.time_of_day_changed.emit(GameManager.game_hour)

func _apply_shelters() -> void:
	_shelters.clear()
	var sh: Dictionary = save_data.get("shelters", {})
	_last_shelter_id = str(sh.get("last_shelter_id", ""))
	var max_used_slot: int = -1
	for d: Dictionary in sh.get("points", []):
		var sp: ShelterSavePoint = ShelterSavePoint.from_dict(d)
		if sp.shelter_id != "":
			_shelters[sp.shelter_id] = sp
			max_used_slot = max(max_used_slot, sp.save_slot)
	_next_slot = (max_used_slot + 1) % MAX_SAVE_SLOTS

func _apply_settlement() -> void:
	var comp: CompoundSystem = GameManager.compound_system as CompoundSystem
	if not comp:
		return
	comp._placed_buildings.clear()
	comp._active_stations.clear()
	comp.compound_tier     = int(save_data.get("settlement", {}).get("compound_tier", 0))
	comp.settlement_morale = float(save_data.get("settlement", {}).get("morale", 0.5))
	for entry: Dictionary in save_data.get("settlement", {}).get("buildings", []):
		var bid: String = str(entry.get("id", ""))
		if bid == "":
			continue
		var pd: Dictionary = entry.get("pos", {})
		var pos: Vector3 = Vector3(float(pd.get("x", 0.0)), float(pd.get("y", 0.0)), float(pd.get("z", 0.0)))
		if not comp._placed_buildings.has(bid):
			comp._placed_buildings[bid] = []
		comp._placed_buildings[bid].append({"pos": pos})
		var bdata: BuildingData = comp._building_registry.get(bid)
		if bdata and bdata.provides_station != "" and not comp._active_stations.has(bdata.provides_station):
			comp._active_stations.append(bdata.provides_station)

func _apply_knowledge() -> void:
	var craft: CraftingSystem = GameManager.crafting_system as CraftingSystem
	if not craft:
		return
	var saved_ids: Array = save_data.get("knowledge", {}).get("unlocked_recipes", [])
	if saved_ids.is_empty():
		return
	var dir: DirAccess = DirAccess.open("res://resources/recipes/")
	if not dir:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var recipe: CraftingRecipe = ResourceLoader.load("res://resources/recipes/" + fname)
			if recipe and recipe is CraftingRecipe:
				if saved_ids.has(recipe.recipe_id) and not craft._known_recipes.has(recipe.recipe_id):
					craft._known_recipes[recipe.recipe_id] = recipe
		fname = dir.get_next()
	dir.list_dir_end()

# ─────────────────────────────────────────────
# Signal handlers
# ─────────────────────────────────────────────

func _on_player_slept(shelter_id: String) -> void:
	save_at_shelter(shelter_id)

func _on_shelter_created(shelter_id: String, position: Vector3, quality: int) -> void:
	var display_name: String
	match quality:
		1:    display_name = "Camp"
		2:    display_name = "Tent"
		_:    display_name = "Shelter"
	register_shelter(shelter_id, display_name, position, quality)

func _on_shelter_destroyed(shelter_id: String) -> void:
	unregister_shelter(shelter_id)

func _on_player_respawning(_legacy_data: Dictionary) -> void:
	## STORY mode: load the last shelter save and respawn the player there.
	## HARDCORE mode never emits player_respawning — this handler is a no-op for it.
	var sp: ShelterSavePoint = get_last_shelter()
	if not sp:
		Logger.error("SaveSystem: story death with no shelter save — cannot respawn (run ends)")
		return
	var spawn_pos: Vector3 = sp.world_position
	load_game(sp.save_slot)
	GameManager.set_state(GameManager.GameState.PLAYING)
	EventBus.player_spawned.emit(spawn_pos)

# ─────────────────────────────────────────────
# Internal
# ─────────────────────────────────────────────

func _ensure_save_directory() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
