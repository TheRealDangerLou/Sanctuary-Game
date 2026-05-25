extends Node
class_name InventorySystem
## InventorySystem: Manages the player's item inventory.
## Registers itself in GameManager on _ready. All changes emit EventBus signals.

## Maximum total carry weight in kilograms.
@export var max_weight: float = 30.0

## item_id → current quantity
var _items: Dictionary = {}
var _current_weight: float = 0.0
var _item_data_cache: Dictionary = {}

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	GameManager.inventory_manager = self
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.item_dropped.connect(_on_item_dropped)

# ─────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────

## Add qty of item_id. Returns false if the item would exceed carry weight.
func add_item(item_id: String, qty: int = 1) -> bool:
	var data: ItemData = _get_item_data(item_id)
	var added_weight: float = data.weight * qty if data else 0.0
	if _current_weight + added_weight > max_weight:
		EventBus.inventory_full.emit()
		return false
	_items[item_id] = _items.get(item_id, 0) + qty
	_current_weight += added_weight
	EventBus.inventory_weight_changed.emit(_current_weight, max_weight)
	return true

## Remove qty of item_id. Returns false if the player does not have enough.
func remove_item(item_id: String, qty: int = 1) -> bool:
	if not has_item(item_id, qty):
		return false
	_items[item_id] -= qty
	if _items[item_id] <= 0:
		_items.erase(item_id)
	var data: ItemData = _get_item_data(item_id)
	if data:
		_current_weight = maxf(0.0, _current_weight - data.weight * qty)
		EventBus.inventory_weight_changed.emit(_current_weight, max_weight)
	return true

## Returns true if the player holds at least qty of item_id.
func has_item(item_id: String, qty: int = 1) -> bool:
	return _items.get(item_id, 0) >= qty

## Returns the quantity held of item_id (0 if absent).
func get_quantity(item_id: String) -> int:
	return _items.get(item_id, 0)

## Returns a snapshot copy of all held items (item_id → quantity).
func get_all_items() -> Dictionary:
	return _items.duplicate()

func get_current_weight() -> float:
	return _current_weight

# ─────────────────────────────────────────────
# Signal handlers
# ─────────────────────────────────────────────

func _on_item_picked_up(item_id: String, qty: int) -> void:
	add_item(item_id, qty)

func _on_item_dropped(item_id: String, _world_pos: Vector3) -> void:
	remove_item(item_id, 1)

# ─────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────

func _get_item_data(item_id: String) -> ItemData:
	if _item_data_cache.has(item_id):
		return _item_data_cache[item_id]
	var path: String = "res://resources/items/%s.tres" % item_id
	if ResourceLoader.exists(path):
		var data: ItemData = ResourceLoader.load(path)
		_item_data_cache[item_id] = data
		return data
	return null
