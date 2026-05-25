extends Node
class_name CraftingSystem
## CraftingSystem: Manages recipe knowledge, ingredient validation, and craft execution.
## Registers itself in GameManager on _ready. Uses InventorySystem via GameManager ref.

## Known recipes keyed by recipe_id. Populated from disk on _ready, extended by signals.
var _known_recipes: Dictionary = {}
var _active_craft: CraftingRecipe = null
var _craft_timer: float = 0.0
var _is_crafting: bool = false

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	GameManager.crafting_system = self
	EventBus.knowledge_unlocked.connect(_on_knowledge_unlocked)
	_load_recipes_from_disk()

func _process(delta: float) -> void:
	if not _is_crafting:
		return
	_craft_timer -= delta
	if _craft_timer <= 0.0:
		_complete_craft()

# ─────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────

## Start crafting recipe_id at the given station.
## Returns false if the recipe is unknown, station is wrong, or ingredients are missing.
func start_craft(recipe_id: String, station: String = "") -> bool:
	if _is_crafting:
		return false
	var recipe: CraftingRecipe = _known_recipes.get(recipe_id)
	if recipe == null:
		return false
	if recipe.required_station != station:
		return false
	var inv: InventorySystem = GameManager.inventory_manager as InventorySystem
	if inv == null:
		return false
	if not _has_ingredients(recipe, inv):
		EventBus.crafting_failed.emit(recipe_id)
		return false
	_consume_ingredients(recipe, inv)
	_active_craft = recipe
	_craft_timer = recipe.craft_time
	_is_crafting = true
	EventBus.crafting_started.emit(recipe_id)
	return true

## Cancel the active craft. Ingredients are NOT refunded (already consumed).
func cancel_craft() -> void:
	if not _is_crafting:
		return
	_is_crafting = false
	_active_craft = null

## Returns true if the player knows the given recipe.
func knows_recipe(recipe_id: String) -> bool:
	return _known_recipes.has(recipe_id)

## Returns all known recipe IDs usable at the given station ("" = hand-crafting).
func get_recipes_for_station(station: String) -> Array:
	var result: Array = []
	for recipe: CraftingRecipe in _known_recipes.values():
		if recipe.required_station == station:
			result.append(recipe)
	return result

## Returns all known recipe IDs.
func get_known_recipe_ids() -> Array:
	return _known_recipes.keys()

## Directly unlock a recipe (for pickups, story events, etc.).
func unlock_recipe(recipe: CraftingRecipe) -> void:
	if _known_recipes.has(recipe.recipe_id):
		return
	_known_recipes[recipe.recipe_id] = recipe
	EventBus.recipe_unlocked.emit(recipe.recipe_id)

## Returns true if a craft is currently in progress.
func is_crafting() -> bool:
	return _is_crafting

# ─────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────

func _complete_craft() -> void:
	_is_crafting = false
	var recipe: CraftingRecipe = _active_craft
	_active_craft = null
	EventBus.item_picked_up.emit(recipe.output_item_id, recipe.output_quantity)
	EventBus.crafting_completed.emit(recipe.recipe_id, recipe.output_item_id)

func _has_ingredients(recipe: CraftingRecipe, inv: InventorySystem) -> bool:
	for item_id: String in recipe.ingredients.keys():
		if not inv.has_item(item_id, recipe.ingredients[item_id]):
			return false
	return true

func _consume_ingredients(recipe: CraftingRecipe, inv: InventorySystem) -> void:
	for item_id: String in recipe.ingredients.keys():
		inv.remove_item(item_id, recipe.ingredients[item_id])

func _load_recipes_from_disk() -> void:
	var dir: DirAccess = DirAccess.open("res://resources/recipes/")
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var recipe: CraftingRecipe = ResourceLoader.load("res://resources/recipes/" + fname)
			if recipe and recipe is CraftingRecipe and recipe.required_knowledge == "":
				_known_recipes[recipe.recipe_id] = recipe
		fname = dir.get_next()
	dir.list_dir_end()

func _on_knowledge_unlocked(knowledge_id: String) -> void:
	var dir: DirAccess = DirAccess.open("res://resources/recipes/")
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var recipe: CraftingRecipe = ResourceLoader.load("res://resources/recipes/" + fname)
			if recipe and recipe is CraftingRecipe and recipe.required_knowledge == knowledge_id:
				if not _known_recipes.has(recipe.recipe_id):
					_known_recipes[recipe.recipe_id] = recipe
					EventBus.recipe_unlocked.emit(recipe.recipe_id)
		fname = dir.get_next()
	dir.list_dir_end()
