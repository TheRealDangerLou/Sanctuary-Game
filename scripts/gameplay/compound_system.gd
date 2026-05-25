extends Node
class_name CompoundSystem
## CompoundSystem: Manages compound building placement, tier progression, and morale.
## Emits building_placed, compound_tier_unlocked, and settlement_morale_changed via EventBus.

## Buildings required to unlock each tier (index = tier number).
const TIER_THRESHOLDS: Array[int] = [0, 3, 6, 10, 15]

## Placed instances per building_id → Array of placement metadata Dictionaries.
var _placed_buildings: Dictionary = {}
## BuildingData registry loaded from disk: building_id → BuildingData.
var _building_registry: Dictionary = {}
## Currently active crafting stations provided by placed buildings.
var _active_stations: Array[String] = []

var compound_tier: int = 0
var settlement_morale: float = 0.5

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	EventBus.building_destroyed.connect(_on_building_destroyed)
	_load_building_registry()

# ─────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────

## Attempt to place building_id at world_pos. Deducts cost from inventory.
## Returns false if tier, cap, or ingredient requirements are not met.
func place_building(building_id: String, world_pos: Vector3) -> bool:
	var data: BuildingData = _building_registry.get(building_id)
	if data == null:
		return false
	if compound_tier < data.tier_required:
		return false
	if data.max_per_compound >= 0:
		if get_placed_count(building_id) >= data.max_per_compound:
			return false
	var inv: InventorySystem = GameManager.inventory_manager as InventorySystem
	if inv:
		for item_id: String in data.cost.keys():
			if not inv.has_item(item_id, data.cost[item_id]):
				return false
		for item_id: String in data.cost.keys():
			inv.remove_item(item_id, data.cost[item_id])

	if not _placed_buildings.has(building_id):
		_placed_buildings[building_id] = []
	_placed_buildings[building_id].append({"pos": world_pos})

	if data.provides_station != "" and not _active_stations.has(data.provides_station):
		_active_stations.append(data.provides_station)

	if data.morale_bonus > 0.0:
		_adjust_morale(data.morale_bonus)

	EventBus.building_placed.emit(building_id, world_pos)
	_check_tier_progression()
	return true

## Returns true if a crafting station of the given type is active in the compound.
func has_station(station_id: String) -> bool:
	return _active_stations.has(station_id)

## Returns number of placed instances of building_id.
func get_placed_count(building_id: String) -> int:
	return _placed_buildings.get(building_id, []).size()

## Returns total number of placed buildings across all types.
func get_total_building_count() -> int:
	var total: int = 0
	for list: Array in _placed_buildings.values():
		total += list.size()
	return total

## Returns BuildingData for all buildings unlocked at the current compound tier.
func get_available_buildings() -> Array:
	var result: Array = []
	for data: BuildingData in _building_registry.values():
		if compound_tier >= data.tier_required:
			result.append(data)
	return result

## Adjust settlement morale by delta (positive or negative, clamped 0–1).
func adjust_morale(delta: float) -> void:
	_adjust_morale(delta)

## Register a BuildingData at runtime (for dynamically added mods/content).
func register_building(data: BuildingData) -> void:
	_building_registry[data.building_id] = data

# ─────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────

func _adjust_morale(delta: float) -> void:
	settlement_morale = clamp(settlement_morale + delta, 0.0, 1.0)
	EventBus.settlement_morale_changed.emit(settlement_morale)

func _check_tier_progression() -> void:
	var total: int = get_total_building_count()
	var new_tier: int = compound_tier
	for i: int in range(TIER_THRESHOLDS.size() - 1, -1, -1):
		if total >= TIER_THRESHOLDS[i]:
			new_tier = i
			break
	if new_tier > compound_tier:
		compound_tier = new_tier
		EventBus.compound_tier_unlocked.emit(compound_tier)

func _on_building_destroyed(building_id: String) -> void:
	if not _placed_buildings.has(building_id):
		return
	var list: Array = _placed_buildings[building_id]
	if not list.is_empty():
		list.pop_back()
	if list.is_empty():
		_placed_buildings.erase(building_id)
		var data: BuildingData = _building_registry.get(building_id)
		if data and data.provides_station != "" and get_placed_count(building_id) == 0:
			_active_stations.erase(data.provides_station)
	_adjust_morale(-0.05)

func _load_building_registry() -> void:
	var dir: DirAccess = DirAccess.open("res://resources/buildings/")
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var data: BuildingData = ResourceLoader.load("res://resources/buildings/" + fname)
			if data and data is BuildingData:
				_building_registry[data.building_id] = data
		fname = dir.get_next()
	dir.list_dir_end()
