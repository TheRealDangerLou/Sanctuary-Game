extends Node
## TestEventBus: Verifies that every EventBus signal can be emitted and received.
## Run the test scene (tests/test_event_bus.tscn) to execute the suite.
## Results print to the Godot output panel. All tests must show [PASS].

var _tests_run: int = 0
var _tests_passed: int = 0
var _signals_received: Dictionary = {}

# ─────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────

func _ready() -> void:
	print("\n========================================")
	print("  Sanctuary - EventBus Signal Tests")
	print("========================================\n")
	_connect_all_signals()
	_run_all_tests()
	_print_results()

# ─────────────────────────────────────────────
# Signal connections
# ─────────────────────────────────────────────

## Connects every EventBus signal to a generic receiver that records its name.
func _connect_all_signals() -> void:
	# Player
	EventBus.player_died.connect(func(_p): _mark("player_died"))
	EventBus.player_spawned.connect(func(_p): _mark("player_spawned"))
	EventBus.player_health_changed.connect(func(_h, _m): _mark("player_health_changed"))
	EventBus.player_hunger_changed.connect(func(_h, _m): _mark("player_hunger_changed"))
	EventBus.player_temperature_changed.connect(func(_t): _mark("player_temperature_changed"))
	EventBus.player_sanity_changed.connect(func(_s, _m): _mark("player_sanity_changed"))
	EventBus.player_stamina_changed.connect(func(_s, _m): _mark("player_stamina_changed"))

	# Injury
	EventBus.injury_applied.connect(func(_l, _s): _mark("injury_applied"))
	EventBus.injury_treated.connect(func(_l): _mark("injury_treated"))
	EventBus.infection_started.connect(func(): _mark("infection_started"))
	EventBus.infection_cured.connect(func(): _mark("infection_cured"))

	# Inventory
	EventBus.item_picked_up.connect(func(_i, _q): _mark("item_picked_up"))
	EventBus.item_dropped.connect(func(_i, _p): _mark("item_dropped"))
	EventBus.inventory_weight_changed.connect(func(_c, _m): _mark("inventory_weight_changed"))
	EventBus.inventory_full.connect(func(): _mark("inventory_full"))

	# Combat
	EventBus.enemy_killed.connect(func(_t, _p): _mark("enemy_killed"))
	EventBus.player_hit.connect(func(_d, _l): _mark("player_hit"))
	EventBus.weapon_fired.connect(func(_w, _p, _n): _mark("weapon_fired"))
	EventBus.weapon_reloading.connect(func(_w): _mark("weapon_reloading"))

	# Noise
	EventBus.noise_generated.connect(func(_p, _r, _n): _mark("noise_generated"))
	EventBus.horde_triggered.connect(func(_p, _s): _mark("horde_triggered"))
	EventBus.compound_siege_started.connect(func(): _mark("compound_siege_started"))
	EventBus.compound_siege_ended.connect(func(): _mark("compound_siege_ended"))

	# World
	EventBus.zone_entered.connect(func(_z): _mark("zone_entered"))
	EventBus.zone_exited.connect(func(_z): _mark("zone_exited"))
	EventBus.weather_changed.connect(func(_w, _i): _mark("weather_changed"))
	EventBus.time_of_day_changed.connect(func(_h): _mark("time_of_day_changed"))
	EventBus.season_changed.connect(func(_s): _mark("season_changed"))

	# Settlement
	EventBus.building_placed.connect(func(_t, _p): _mark("building_placed"))
	EventBus.building_destroyed.connect(func(_i): _mark("building_destroyed"))
	EventBus.compound_tier_unlocked.connect(func(_t): _mark("compound_tier_unlocked"))
	EventBus.settlement_morale_changed.connect(func(_m): _mark("settlement_morale_changed"))

	# NPC
	EventBus.npc_recruited.connect(func(_i): _mark("npc_recruited"))
	EventBus.npc_died.connect(func(_i, _c): _mark("npc_died"))
	EventBus.npc_morale_changed.connect(func(_i, _m): _mark("npc_morale_changed"))
	EventBus.npc_relationship_changed.connect(func(_i, _r): _mark("npc_relationship_changed"))
	EventBus.npc_role_assigned.connect(func(_i, _r): _mark("npc_role_assigned"))

	# Narrative
	EventBus.daughter_clue_found.connect(func(_c, _n): _mark("daughter_clue_found"))
	EventBus.quest_started.connect(func(_q): _mark("quest_started"))
	EventBus.quest_completed.connect(func(_q): _mark("quest_completed"))
	EventBus.narrative_event_triggered.connect(func(_e): _mark("narrative_event_triggered"))

	# Reputation
	EventBus.moral_alignment_changed.connect(func(_a): _mark("moral_alignment_changed"))
	EventBus.faction_reputation_changed.connect(func(_f, _v): _mark("faction_reputation_changed"))

	# Crafting
	EventBus.crafting_started.connect(func(_r): _mark("crafting_started"))
	EventBus.crafting_completed.connect(func(_r, _o): _mark("crafting_completed"))
	EventBus.crafting_failed.connect(func(_r): _mark("crafting_failed"))
	EventBus.recipe_unlocked.connect(func(_r): _mark("recipe_unlocked"))
	EventBus.knowledge_unlocked.connect(func(_k): _mark("knowledge_unlocked"))

	# Save
	EventBus.game_saved.connect(func(_s): _mark("game_saved"))
	EventBus.game_loaded.connect(func(_s): _mark("game_loaded"))
	EventBus.autosave_triggered.connect(func(): _mark("autosave_triggered"))
	EventBus.character_died_permanently.connect(func(_d): _mark("character_died_permanently"))

# ─────────────────────────────────────────────
# Test groups
# ─────────────────────────────────────────────

## Runs all signal test groups in sequence.
func _run_all_tests() -> void:
	_test_player_signals()
	_test_injury_signals()
	_test_inventory_signals()
	_test_combat_signals()
	_test_noise_signals()
	_test_world_signals()
	_test_settlement_signals()
	_test_npc_signals()
	_test_narrative_signals()
	_test_reputation_signals()
	_test_crafting_signals()
	_test_save_signals()

func _test_player_signals() -> void:
	print("── Player signals ──")
	EventBus.player_died.emit(Vector3.ZERO)
	_assert("player_died")
	EventBus.player_spawned.emit(Vector3.ZERO)
	_assert("player_spawned")
	EventBus.player_health_changed.emit(80.0, 100.0)
	_assert("player_health_changed")
	EventBus.player_hunger_changed.emit(60.0, 100.0)
	_assert("player_hunger_changed")
	EventBus.player_temperature_changed.emit(36.0)
	_assert("player_temperature_changed")
	EventBus.player_sanity_changed.emit(90.0, 100.0)
	_assert("player_sanity_changed")
	EventBus.player_stamina_changed.emit(75.0, 100.0)
	_assert("player_stamina_changed")

func _test_injury_signals() -> void:
	print("── Injury signals ──")
	EventBus.injury_applied.emit("left_arm", 0.5)
	_assert("injury_applied")
	EventBus.injury_treated.emit("left_arm")
	_assert("injury_treated")
	EventBus.infection_started.emit()
	_assert("infection_started")
	EventBus.infection_cured.emit()
	_assert("infection_cured")

func _test_inventory_signals() -> void:
	print("── Inventory signals ──")
	EventBus.item_picked_up.emit("bandage", 3)
	_assert("item_picked_up")
	EventBus.item_dropped.emit("bandage", Vector3.ZERO)
	_assert("item_dropped")
	EventBus.inventory_weight_changed.emit(12.5, 30.0)
	_assert("inventory_weight_changed")
	EventBus.inventory_full.emit()
	_assert("inventory_full")

func _test_combat_signals() -> void:
	print("── Combat signals ──")
	EventBus.enemy_killed.emit("zombie", Vector3.ZERO)
	_assert("enemy_killed")
	EventBus.player_hit.emit(25.0, "chest")
	_assert("player_hit")
	EventBus.weapon_fired.emit("pistol", Vector3.ZERO, 5)
	_assert("weapon_fired")
	EventBus.weapon_reloading.emit("pistol")
	_assert("weapon_reloading")

func _test_noise_signals() -> void:
	print("── Noise signals ──")
	EventBus.noise_generated.emit(Vector3.ZERO, 15.0, 5)
	_assert("noise_generated")
	EventBus.horde_triggered.emit(Vector3.ZERO, 20)
	_assert("horde_triggered")
	EventBus.compound_siege_started.emit()
	_assert("compound_siege_started")
	EventBus.compound_siege_ended.emit()
	_assert("compound_siege_ended")

func _test_world_signals() -> void:
	print("── World signals ──")
	EventBus.zone_entered.emit("downtown")
	_assert("zone_entered")
	EventBus.zone_exited.emit("downtown")
	_assert("zone_exited")
	EventBus.weather_changed.emit("rain", 0.7)
	_assert("weather_changed")
	EventBus.time_of_day_changed.emit(12)
	_assert("time_of_day_changed")
	EventBus.season_changed.emit("winter")
	_assert("season_changed")

func _test_settlement_signals() -> void:
	print("── Settlement signals ──")
	EventBus.building_placed.emit("watchtower", Vector3.ZERO)
	_assert("building_placed")
	EventBus.building_destroyed.emit("building_001")
	_assert("building_destroyed")
	EventBus.compound_tier_unlocked.emit(1)
	_assert("compound_tier_unlocked")
	EventBus.settlement_morale_changed.emit(75.0)
	_assert("settlement_morale_changed")

func _test_npc_signals() -> void:
	print("── NPC signals ──")
	EventBus.npc_recruited.emit("npc_001")
	_assert("npc_recruited")
	EventBus.npc_died.emit("npc_001", "zombie_attack")
	_assert("npc_died")
	EventBus.npc_morale_changed.emit("npc_001", 60.0)
	_assert("npc_morale_changed")
	EventBus.npc_relationship_changed.emit("npc_001", "trusted")
	_assert("npc_relationship_changed")
	EventBus.npc_role_assigned.emit("npc_001", "guard")
	_assert("npc_role_assigned")

func _test_narrative_signals() -> void:
	print("── Narrative signals ──")
	EventBus.daughter_clue_found.emit("clue_001", 1)
	_assert("daughter_clue_found")
	EventBus.quest_started.emit("find_shelter")
	_assert("quest_started")
	EventBus.quest_completed.emit("find_shelter")
	_assert("quest_completed")
	EventBus.narrative_event_triggered.emit("intro_dream")
	_assert("narrative_event_triggered")

func _test_reputation_signals() -> void:
	print("── Reputation signals ──")
	EventBus.moral_alignment_changed.emit(-0.3)
	_assert("moral_alignment_changed")
	EventBus.faction_reputation_changed.emit("traders", 0.6)
	_assert("faction_reputation_changed")

func _test_crafting_signals() -> void:
	print("── Crafting signals ──")
	EventBus.crafting_started.emit("recipe_bandage")
	_assert("crafting_started")
	EventBus.crafting_completed.emit("recipe_bandage", "bandage")
	_assert("crafting_completed")
	EventBus.crafting_failed.emit("recipe_bandage")
	_assert("crafting_failed")
	EventBus.recipe_unlocked.emit("recipe_molotov")
	_assert("recipe_unlocked")
	EventBus.knowledge_unlocked.emit("knowledge_first_aid")
	_assert("knowledge_unlocked")

func _test_save_signals() -> void:
	print("── Save signals ──")
	EventBus.game_saved.emit(1)
	_assert("game_saved")
	EventBus.game_loaded.emit(1)
	_assert("game_loaded")
	EventBus.autosave_triggered.emit()
	_assert("autosave_triggered")
	EventBus.character_died_permanently.emit({})
	_assert("character_died_permanently")

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

## Records that a signal was received. Called by every lambda connector above.
func _mark(signal_name: String) -> void:
	_signals_received[signal_name] = true

## Checks whether signal_name was received since the last emit, then clears the flag.
func _assert(signal_name: String) -> void:
	_tests_run += 1
	if _signals_received.get(signal_name, false):
		_tests_passed += 1
		print("  [PASS]  %s" % signal_name)
	else:
		print("  [FAIL]  %s - signal was not received" % signal_name)
	_signals_received.erase(signal_name)

## Prints the final pass/fail summary.
func _print_results() -> void:
	var failed: int = _tests_run - _tests_passed
	print("\n========================================")
	print("  Results: %d / %d passed" % [_tests_passed, _tests_run])
	if failed == 0:
		print("  All EventBus signals are working correctly.")
	else:
		print("  %d signal(s) failed - check output above." % failed)
	print("========================================\n")
