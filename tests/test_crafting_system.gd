extends Node
## TestCraftingSystem: Unit tests for Agent 04 — Crafting and Building System.
## Run this scene (F6) and check Output for [PASS] / [FAIL] lines.

var _pass: int = 0
var _fail: int = 0

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

func assert_eq(label: String, got: Variant, expected: Variant) -> void:
	if got == expected:
		print("[PASS] %s" % label)
		_pass += 1
	else:
		print("[FAIL] %s  →  got %s, expected %s" % [label, str(got), str(expected)])
		_fail += 1

func assert_near(label: String, got: float, expected: float, tol: float = 0.001) -> void:
	if abs(got - expected) <= tol:
		print("[PASS] %s" % label)
		_pass += 1
	else:
		print("[FAIL] %s  →  got %.4f, expected %.4f (tol %.4f)" % [label, got, expected, tol])
		_fail += 1

func assert_true(label: String, value: bool) -> void:
	assert_eq(label, value, true)

func assert_false(label: String, value: bool) -> void:
	assert_eq(label, value, false)

# ─────────────────────────────────────────────
# InventorySystem tests
# ─────────────────────────────────────────────

func test_inventory_add_remove() -> void:
	var inv: InventorySystem = preload("res://scripts/gameplay/inventory_system.gd").new()
	inv.max_weight = 100.0
	add_child(inv)

	assert_false("Inventory: empty initially", inv.has_item("wood_plank"))
	assert_eq("Inventory: qty is 0 before add", inv.get_quantity("wood_plank"), 0)

	inv.add_item("wood_plank", 5)
	assert_true("Inventory: has 5 wood_plank", inv.has_item("wood_plank", 5))
	assert_false("Inventory: does not have 6 wood_plank", inv.has_item("wood_plank", 6))
	assert_eq("Inventory: qty is 5", inv.get_quantity("wood_plank"), 5)

	var removed: bool = inv.remove_item("wood_plank", 3)
	assert_true("Inventory: remove returns true", removed)
	assert_eq("Inventory: qty is 2 after remove", inv.get_quantity("wood_plank"), 2)

	var failed: bool = inv.remove_item("wood_plank", 5)
	assert_false("Inventory: remove too many returns false", failed)

	inv.queue_free()

func test_inventory_weight_limit() -> void:
	var inv: InventorySystem = preload("res://scripts/gameplay/inventory_system.gd").new()
	inv.max_weight = 2.0
	add_child(inv)

	var added_first: bool = inv.add_item("test_heavy", 1)
	assert_true("Inventory: first add succeeds within limit", added_first)

	inv.queue_free()

func test_inventory_snapshot() -> void:
	var inv: InventorySystem = preload("res://scripts/gameplay/inventory_system.gd").new()
	inv.max_weight = 100.0
	add_child(inv)

	inv.add_item("cloth_rag", 10)
	inv.add_item("scrap_metal", 3)
	var snapshot: Dictionary = inv.get_all_items()
	assert_eq("Inventory: snapshot has cloth_rag", snapshot.get("cloth_rag", 0), 10)
	assert_eq("Inventory: snapshot has scrap_metal", snapshot.get("scrap_metal", 0), 3)

	inv.queue_free()

func test_inventory_item_picked_up_signal() -> void:
	var inv: InventorySystem = preload("res://scripts/gameplay/inventory_system.gd").new()
	inv.max_weight = 100.0
	add_child(inv)

	EventBus.item_picked_up.emit("bandage", 4)
	assert_eq("Inventory: item_picked_up signal adds to inventory", inv.get_quantity("bandage"), 4)

	inv.queue_free()

# ─────────────────────────────────────────────
# CraftingSystem tests
# ─────────────────────────────────────────────

func _make_test_recipe(rid: String, output: String, qty: int, station: String, ingredients: Dictionary, knowledge: String = "") -> CraftingRecipe:
	var recipe: CraftingRecipe = CraftingRecipe.new()
	recipe.recipe_id = rid
	recipe.output_item_id = output
	recipe.output_quantity = qty
	recipe.craft_time = 0.01
	recipe.required_station = station
	recipe.ingredients = ingredients
	recipe.required_knowledge = knowledge
	return recipe

func test_crafting_unlock_and_query() -> void:
	var cs: CraftingSystem = preload("res://scripts/gameplay/crafting_system.gd").new()
	add_child(cs)

	var recipe: CraftingRecipe = _make_test_recipe("r_bandage", "bandage", 2, "", {"cloth_rag": 3})
	assert_false("CraftingSystem: recipe not known before unlock", cs.knows_recipe("r_bandage"))
	cs.unlock_recipe(recipe)
	assert_true("CraftingSystem: recipe known after unlock", cs.knows_recipe("r_bandage"))
	assert_true("CraftingSystem: recipe appears in station list", cs.get_recipes_for_station("").has(recipe))

	cs.queue_free()

func test_crafting_start_missing_ingredients() -> void:
	var inv: InventorySystem = preload("res://scripts/gameplay/inventory_system.gd").new()
	inv.max_weight = 100.0
	add_child(inv)
	GameManager.inventory_manager = inv

	var cs: CraftingSystem = preload("res://scripts/gameplay/crafting_system.gd").new()
	add_child(cs)

	var recipe: CraftingRecipe = _make_test_recipe("r_knife", "knife", 1, "workbench", {"scrap_metal": 2, "cloth_rag": 1})
	cs.unlock_recipe(recipe)

	var result: bool = cs.start_craft("r_knife", "workbench")
	assert_false("CraftingSystem: start_craft fails with missing ingredients", result)
	assert_false("CraftingSystem: not crafting after failed start", cs.is_crafting())

	inv.queue_free()
	cs.queue_free()

func test_crafting_start_wrong_station() -> void:
	var inv: InventorySystem = preload("res://scripts/gameplay/inventory_system.gd").new()
	inv.max_weight = 100.0
	add_child(inv)
	GameManager.inventory_manager = inv
	inv.add_item("scrap_metal", 5)
	inv.add_item("cloth_rag", 5)

	var cs: CraftingSystem = preload("res://scripts/gameplay/crafting_system.gd").new()
	add_child(cs)

	var recipe: CraftingRecipe = _make_test_recipe("r_knife2", "knife", 1, "workbench", {"scrap_metal": 2, "cloth_rag": 1})
	cs.unlock_recipe(recipe)

	var result: bool = cs.start_craft("r_knife2", "")
	assert_false("CraftingSystem: start_craft fails at wrong station", result)

	inv.queue_free()
	cs.queue_free()

func test_crafting_success() -> void:
	var inv: InventorySystem = preload("res://scripts/gameplay/inventory_system.gd").new()
	inv.max_weight = 100.0
	add_child(inv)
	GameManager.inventory_manager = inv
	inv.add_item("cloth_rag", 10)

	var cs: CraftingSystem = preload("res://scripts/gameplay/crafting_system.gd").new()
	add_child(cs)

	var recipe: CraftingRecipe = _make_test_recipe("r_bandage2", "bandage", 2, "", {"cloth_rag": 3})
	recipe.craft_time = 0.001
	cs.unlock_recipe(recipe)

	var started: bool = cs.start_craft("r_bandage2", "")
	assert_true("CraftingSystem: start_craft succeeds with ingredients", started)
	assert_true("CraftingSystem: is_crafting after start", cs.is_crafting())
	assert_eq("CraftingSystem: ingredients consumed on start", inv.get_quantity("cloth_rag"), 7)

	inv.queue_free()
	cs.queue_free()

func test_crafting_cancel() -> void:
	var inv: InventorySystem = preload("res://scripts/gameplay/inventory_system.gd").new()
	inv.max_weight = 100.0
	add_child(inv)
	GameManager.inventory_manager = inv
	inv.add_item("cloth_rag", 10)

	var cs: CraftingSystem = preload("res://scripts/gameplay/crafting_system.gd").new()
	add_child(cs)

	var recipe: CraftingRecipe = _make_test_recipe("r_cancel_test", "bandage", 2, "", {"cloth_rag": 3})
	recipe.craft_time = 999.0
	cs.unlock_recipe(recipe)
	cs.start_craft("r_cancel_test", "")

	cs.cancel_craft()
	assert_false("CraftingSystem: not crafting after cancel", cs.is_crafting())
	assert_eq("CraftingSystem: ingredients not refunded on cancel", inv.get_quantity("cloth_rag"), 7)

	inv.queue_free()
	cs.queue_free()

# ─────────────────────────────────────────────
# CompoundSystem tests
# ─────────────────────────────────────────────

func _make_test_building(bid: String, tier: int, station: String, cost: Dictionary, cap: int = -1, morale: float = 0.0) -> BuildingData:
	var data: BuildingData = BuildingData.new()
	data.building_id = bid
	data.display_name = bid
	data.tier_required = tier
	data.provides_station = station
	data.cost = cost
	data.max_per_compound = cap
	data.morale_bonus = morale
	return data

func test_compound_place_building() -> void:
	var cs: CompoundSystem = preload("res://scripts/gameplay/compound_system.gd").new()
	add_child(cs)
	cs.register_building(_make_test_building("shelter_a", 0, "", {}))

	assert_eq("CompoundSystem: 0 placed initially", cs.get_placed_count("shelter_a"), 0)
	var placed: bool = cs.place_building("shelter_a", Vector3.ZERO)
	assert_true("CompoundSystem: place_building returns true", placed)
	assert_eq("CompoundSystem: 1 placed after placement", cs.get_placed_count("shelter_a"), 1)

	cs.queue_free()

func test_compound_tier_progression() -> void:
	var cs: CompoundSystem = preload("res://scripts/gameplay/compound_system.gd").new()
	add_child(cs)
	for i: int in range(10):
		cs.register_building(_make_test_building("bld_%d" % i, 0, "", {}))

	assert_eq("CompoundSystem: starts at tier 0", cs.compound_tier, 0)
	for i: int in range(3):
		cs.place_building("bld_%d" % i, Vector3.ZERO)
	assert_eq("CompoundSystem: tier 1 at 3 buildings", cs.compound_tier, 1)
	for i: int in range(3, 6):
		cs.place_building("bld_%d" % i, Vector3.ZERO)
	assert_eq("CompoundSystem: tier 2 at 6 buildings", cs.compound_tier, 2)

	cs.queue_free()

func test_compound_station_tracking() -> void:
	var cs: CompoundSystem = preload("res://scripts/gameplay/compound_system.gd").new()
	add_child(cs)
	cs.register_building(_make_test_building("wb", 0, "workbench", {}, 1))

	assert_false("CompoundSystem: workbench not available before placement", cs.has_station("workbench"))
	cs.place_building("wb", Vector3.ZERO)
	assert_true("CompoundSystem: workbench available after placement", cs.has_station("workbench"))

	cs.queue_free()

func test_compound_cap_enforcement() -> void:
	var cs: CompoundSystem = preload("res://scripts/gameplay/compound_system.gd").new()
	add_child(cs)
	cs.register_building(_make_test_building("unique_bld", 0, "", {}, 1))

	cs.place_building("unique_bld", Vector3.ZERO)
	var second: bool = cs.place_building("unique_bld", Vector3(5, 0, 5))
	assert_false("CompoundSystem: second placement blocked by cap", second)
	assert_eq("CompoundSystem: still only 1 placed", cs.get_placed_count("unique_bld"), 1)

	cs.queue_free()

func test_compound_morale_on_destroy() -> void:
	var cs: CompoundSystem = preload("res://scripts/gameplay/compound_system.gd").new()
	add_child(cs)
	cs.register_building(_make_test_building("shelter_b", 0, "", {}, -1, 0.1))
	cs.place_building("shelter_b", Vector3.ZERO)
	var morale_after_build: float = cs.settlement_morale

	EventBus.building_destroyed.emit("shelter_b")
	assert_true("CompoundSystem: morale drops after building destroyed", cs.settlement_morale < morale_after_build)

	cs.queue_free()

func test_compound_tier_gate() -> void:
	var cs: CompoundSystem = preload("res://scripts/gameplay/compound_system.gd").new()
	add_child(cs)
	cs.register_building(_make_test_building("advanced_bld", 2, "", {}))

	var placed: bool = cs.place_building("advanced_bld", Vector3.ZERO)
	assert_false("CompoundSystem: tier-gated building rejected at tier 0", placed)

	cs.queue_free()

# ─────────────────────────────────────────────
# Resource file existence checks
# ─────────────────────────────────────────────

func test_resource_files_exist() -> void:
	var items: Array[String] = [
		"res://resources/items/wood_plank.tres",
		"res://resources/items/scrap_metal.tres",
		"res://resources/items/cloth_rag.tres",
		"res://resources/items/bandage.tres",
		"res://resources/items/9mm_ammo.tres",
	]
	for p: String in items:
		assert_true("Item resource exists: %s" % p, ResourceLoader.exists(p))

	var recipes: Array[String] = [
		"res://resources/recipes/bandage_recipe.tres",
		"res://resources/recipes/workbench_recipe.tres",
		"res://resources/recipes/improvised_knife_recipe.tres",
	]
	for p: String in recipes:
		assert_true("Recipe resource exists: %s" % p, ResourceLoader.exists(p))

	var buildings: Array[String] = [
		"res://resources/buildings/shelter_basic.tres",
		"res://resources/buildings/workbench.tres",
		"res://resources/buildings/watchtower.tres",
	]
	for p: String in buildings:
		assert_true("Building resource exists: %s" % p, ResourceLoader.exists(p))

# ─────────────────────────────────────────────
# EventBus signal presence checks
# ─────────────────────────────────────────────

func test_eventbus_crafting_signals() -> void:
	for sig: String in ["crafting_started", "crafting_completed", "crafting_failed",
						"recipe_unlocked", "knowledge_unlocked",
						"item_picked_up", "item_dropped",
						"inventory_weight_changed", "inventory_full",
						"building_placed", "building_destroyed",
						"compound_tier_unlocked", "settlement_morale_changed"]:
		assert_true("EventBus has signal: %s" % sig, EventBus.has_signal(sig))

# ─────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────

func _ready() -> void:
	print("=== Crafting & Building System Tests ===")
	test_inventory_add_remove()
	test_inventory_weight_limit()
	test_inventory_snapshot()
	test_inventory_item_picked_up_signal()
	test_crafting_unlock_and_query()
	test_crafting_start_missing_ingredients()
	test_crafting_start_wrong_station()
	test_crafting_success()
	test_crafting_cancel()
	test_compound_place_building()
	test_compound_tier_progression()
	test_compound_station_tracking()
	test_compound_cap_enforcement()
	test_compound_morale_on_destroy()
	test_compound_tier_gate()
	test_resource_files_exist()
	test_eventbus_crafting_signals()
	print("=== Results: %d passed, %d failed ===" % [_pass, _fail])
