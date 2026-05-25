extends Node
## TestDeathSystem: Unit tests for Agent 05 — Death, Permadeath & Corpse Loot.
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

func assert_near(label: String, got: float, expected: float, tol: float = 0.01) -> void:
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

func assert_greater(label: String, got: float, than: float) -> void:
	if got > than:
		print("[PASS] %s" % label)
		_pass += 1
	else:
		print("[FAIL] %s  →  got %.4f, expected > %.4f" % [label, got, than])
		_fail += 1

func assert_less(label: String, got: float, than: float) -> void:
	if got < than:
		print("[PASS] %s" % label)
		_pass += 1
	else:
		print("[FAIL] %s  →  got %.4f, expected < %.4f" % [label, got, than])
		_fail += 1

# ─────────────────────────────────────────────
# DeathSystem tests
# ─────────────────────────────────────────────

func test_death_initial_stats() -> void:
	var ds: DeathSystem = preload("res://scripts/gameplay/death_system.gd").new()
	add_child(ds)
	var stats: Dictionary = ds.get_run_stats()
	assert_eq("DeathSystem: enemies_killed starts at 0", stats["enemies_killed"], 0)
	assert_eq("DeathSystem: corpses_looted starts at 0", stats["corpses_looted"], 0)
	assert_false("DeathSystem: death not yet processed initially", ds._is_death_processed)
	ds.queue_free()

func test_death_tracks_enemy_kills() -> void:
	var ds: DeathSystem = preload("res://scripts/gameplay/death_system.gd").new()
	add_child(ds)
	EventBus.enemy_killed.emit("zombie", Vector3.ZERO)
	EventBus.enemy_killed.emit("zombie", Vector3.ONE)
	EventBus.enemy_killed.emit("bandit", Vector3.ZERO)
	assert_eq("DeathSystem: tracks 3 enemy kills", ds.get_run_stats()["enemies_killed"], 3)
	ds.queue_free()

func test_death_tracks_corpse_loot() -> void:
	var ds: DeathSystem = preload("res://scripts/gameplay/death_system.gd").new()
	add_child(ds)
	EventBus.corpse_looted.emit("corpse_0")
	EventBus.corpse_looted.emit("corpse_1")
	assert_eq("DeathSystem: tracks 2 corpse loot events", ds.get_run_stats()["corpses_looted"], 2)
	ds.queue_free()

func test_death_reset_on_player_spawned() -> void:
	var ds: DeathSystem = preload("res://scripts/gameplay/death_system.gd").new()
	add_child(ds)
	EventBus.enemy_killed.emit("zombie", Vector3.ZERO)
	EventBus.enemy_killed.emit("bandit", Vector3.ZERO)
	EventBus.corpse_looted.emit("corpse_0")
	EventBus.player_spawned.emit(Vector3.ZERO)
	var stats: Dictionary = ds.get_run_stats()
	assert_eq("DeathSystem: enemies_killed reset on player_spawned", stats["enemies_killed"], 0)
	assert_eq("DeathSystem: corpses_looted reset on player_spawned", stats["corpses_looted"], 0)
	assert_false("DeathSystem: _is_death_processed reset on player_spawned", ds._is_death_processed)
	ds.queue_free()

func test_death_not_double_processed() -> void:
	var ds: DeathSystem = preload("res://scripts/gameplay/death_system.gd").new()
	add_child(ds)
	## Emit character_died_permanently twice — only the first should process.
	EventBus.character_died_permanently.emit({"days_survived": 3, "death_hour": 14, "death_minute": 30})
	assert_true("DeathSystem: _is_death_processed set after first death event", ds._is_death_processed)
	## Second emission should be a no-op (guard already set).
	EventBus.character_died_permanently.emit({"days_survived": 5, "death_hour": 8, "death_minute": 0})
	assert_true("DeathSystem: still processed after second death event (not re-processed)", ds._is_death_processed)
	ds.queue_free()

func test_death_enriched_stats_in_record() -> void:
	var ds: DeathSystem = preload("res://scripts/gameplay/death_system.gd").new()
	add_child(ds)
	EventBus.enemy_killed.emit("zombie", Vector3.ZERO)
	EventBus.enemy_killed.emit("zombie", Vector3.ONE)
	EventBus.corpse_looted.emit("corpse_0")
	## Verify get_run_stats reflects the tracked values that will appear in legacy record.
	var stats: Dictionary = ds.get_run_stats()
	assert_eq("DeathSystem: run stats enemies_killed = 2 before death", stats["enemies_killed"], 2)
	assert_eq("DeathSystem: run stats corpses_looted = 1 before death", stats["corpses_looted"], 1)
	ds.queue_free()

func test_death_manual_reset() -> void:
	var ds: DeathSystem = preload("res://scripts/gameplay/death_system.gd").new()
	add_child(ds)
	EventBus.enemy_killed.emit("zombie", Vector3.ZERO)
	ds._is_death_processed = true
	ds.reset_run_stats()
	var stats: Dictionary = ds.get_run_stats()
	assert_eq("DeathSystem: manual reset clears enemies_killed", stats["enemies_killed"], 0)
	assert_false("DeathSystem: manual reset clears _is_death_processed", ds._is_death_processed)
	ds.queue_free()

# ─────────────────────────────────────────────
# CorpseLootSystem tests
# ─────────────────────────────────────────────

func test_corpse_spawned_on_enemy_killed() -> void:
	var cls: CorpseLootSystem = preload("res://scripts/gameplay/corpse_loot_system.gd").new()
	add_child(cls)
	assert_eq("CorpseLootSystem: no corpses before any kills", cls.get_corpse_count(), 0)
	EventBus.enemy_killed.emit("zombie", Vector3.ZERO)
	assert_eq("CorpseLootSystem: one corpse after one kill", cls.get_corpse_count(), 1)
	cls.queue_free()

func test_corpse_spawned_signal_emitted() -> void:
	var cls: CorpseLootSystem = preload("res://scripts/gameplay/corpse_loot_system.gd").new()
	add_child(cls)
	var spawned_id: String = ""
	EventBus.corpse_spawned.connect(func(cid: String, _pos: Vector3) -> void: spawned_id = cid)
	EventBus.enemy_killed.emit("zombie", Vector3.ZERO)
	assert_true("CorpseLootSystem: corpse_spawned signal emitted on enemy_killed", spawned_id != "")
	cls.queue_free()

func test_corpse_loot_returns_true() -> void:
	var cls: CorpseLootSystem = preload("res://scripts/gameplay/corpse_loot_system.gd").new()
	add_child(cls)
	## Inject a known corpse directly so loot is deterministic.
	cls._corpses["test_corpse"] = {
		"position": Vector3.ZERO,
		"items": {"cloth_rag": 2, "bandage": 1},
		"time_remaining": 300.0,
		"looted": false,
	}
	var result: bool = cls.loot_corpse("test_corpse")
	assert_true("CorpseLootSystem: loot_corpse returns true on valid corpse", result)
	cls.queue_free()

func test_corpse_loot_emits_item_picked_up() -> void:
	var cls: CorpseLootSystem = preload("res://scripts/gameplay/corpse_loot_system.gd").new()
	add_child(cls)
	cls._corpses["test_corpse"] = {
		"position": Vector3.ZERO,
		"items": {"cloth_rag": 3},
		"time_remaining": 300.0,
		"looted": false,
	}
	var picked_items: Dictionary = {}
	EventBus.item_picked_up.connect(func(item_id: String, qty: int) -> void:
		picked_items[item_id] = picked_items.get(item_id, 0) + qty)
	cls.loot_corpse("test_corpse")
	assert_eq("CorpseLootSystem: item_picked_up emitted for cloth_rag", picked_items.get("cloth_rag", 0), 3)
	cls.queue_free()

func test_corpse_already_looted_returns_false() -> void:
	var cls: CorpseLootSystem = preload("res://scripts/gameplay/corpse_loot_system.gd").new()
	add_child(cls)
	cls._corpses["test_corpse"] = {
		"position": Vector3.ZERO,
		"items": {"cloth_rag": 1},
		"time_remaining": 300.0,
		"looted": false,
	}
	cls.loot_corpse("test_corpse")
	var second: bool = cls.loot_corpse("test_corpse")
	assert_false("CorpseLootSystem: second loot_corpse call returns false", second)
	cls.queue_free()

func test_corpse_invalid_id_returns_false() -> void:
	var cls: CorpseLootSystem = preload("res://scripts/gameplay/corpse_loot_system.gd").new()
	add_child(cls)
	var result: bool = cls.loot_corpse("nonexistent_corpse")
	assert_false("CorpseLootSystem: loot_corpse with invalid ID returns false", result)
	cls.queue_free()

func test_corpse_peek_does_not_consume() -> void:
	var cls: CorpseLootSystem = preload("res://scripts/gameplay/corpse_loot_system.gd").new()
	add_child(cls)
	cls._corpses["test_corpse"] = {
		"position": Vector3.ZERO,
		"items": {"bandage": 2},
		"time_remaining": 300.0,
		"looted": false,
	}
	var peeked: Dictionary = cls.peek_corpse("test_corpse")
	assert_eq("CorpseLootSystem: peek returns correct item", peeked.get("bandage", 0), 2)
	## Corpse should still be lootable after peek.
	var can_still_loot: bool = cls.loot_corpse("test_corpse")
	assert_true("CorpseLootSystem: corpse still lootable after peek", can_still_loot)
	cls.queue_free()

func test_corpse_has_corpse_true_when_active() -> void:
	var cls: CorpseLootSystem = preload("res://scripts/gameplay/corpse_loot_system.gd").new()
	add_child(cls)
	cls._corpses["test_corpse"] = {
		"position": Vector3.ZERO,
		"items": {},
		"time_remaining": 300.0,
		"looted": false,
	}
	assert_true("CorpseLootSystem: has_corpse true when active", cls.has_corpse("test_corpse"))
	cls.queue_free()

func test_corpse_has_corpse_false_after_loot() -> void:
	var cls: CorpseLootSystem = preload("res://scripts/gameplay/corpse_loot_system.gd").new()
	add_child(cls)
	cls._corpses["test_corpse"] = {
		"position": Vector3.ZERO,
		"items": {},
		"time_remaining": 300.0,
		"looted": false,
	}
	cls.loot_corpse("test_corpse")
	assert_false("CorpseLootSystem: has_corpse false after looting", cls.has_corpse("test_corpse"))
	cls.queue_free()

func test_corpse_get_available_excludes_looted() -> void:
	var cls: CorpseLootSystem = preload("res://scripts/gameplay/corpse_loot_system.gd").new()
	add_child(cls)
	cls._corpses["corpse_a"] = {"position": Vector3.ZERO, "items": {}, "time_remaining": 300.0, "looted": false}
	cls._corpses["corpse_b"] = {"position": Vector3.ONE, "items": {}, "time_remaining": 300.0, "looted": false}
	cls.loot_corpse("corpse_a")
	var available: Dictionary = cls.get_available_corpses()
	assert_false("CorpseLootSystem: looted corpse excluded from available", available.has("corpse_a"))
	assert_true("CorpseLootSystem: unlooted corpse included in available", available.has("corpse_b"))
	cls.queue_free()

func test_corpse_unknown_type_uses_default_table() -> void:
	var cls: CorpseLootSystem = preload("res://scripts/gameplay/corpse_loot_system.gd").new()
	add_child(cls)
	## Should not crash — spawns with default table loot (may be empty if no rolls proc, but corpse exists).
	EventBus.enemy_killed.emit("alien_mutant", Vector3.ZERO)
	assert_eq("CorpseLootSystem: unknown enemy type still spawns a corpse", cls.get_corpse_count(), 1)
	cls.queue_free()

func test_corpse_time_remaining_decreases() -> void:
	var cls: CorpseLootSystem = preload("res://scripts/gameplay/corpse_loot_system.gd").new()
	add_child(cls)
	cls._corpses["test_corpse"] = {
		"position": Vector3.ZERO,
		"items": {},
		"time_remaining": 100.0,
		"looted": false,
	}
	cls._tick_corpse_timers(10.0)
	assert_near("CorpseLootSystem: time_remaining decreases on tick",
		cls._corpses["test_corpse"]["time_remaining"], 90.0)
	cls.queue_free()

func test_corpse_despawned_signal_emitted() -> void:
	var cls: CorpseLootSystem = preload("res://scripts/gameplay/corpse_loot_system.gd").new()
	add_child(cls)
	cls._corpses["test_corpse"] = {
		"position": Vector3.ZERO,
		"items": {},
		"time_remaining": 0.5,
		"looted": false,
	}
	var despawned_id: String = ""
	EventBus.corpse_despawned.connect(func(cid: String) -> void: despawned_id = cid)
	cls._tick_corpse_timers(1.0)
	assert_eq("CorpseLootSystem: corpse_despawned emitted when timer expires", despawned_id, "test_corpse")
	cls.queue_free()

func test_corpse_removed_after_despawn() -> void:
	var cls: CorpseLootSystem = preload("res://scripts/gameplay/corpse_loot_system.gd").new()
	add_child(cls)
	cls._corpses["test_corpse"] = {
		"position": Vector3.ZERO,
		"items": {},
		"time_remaining": 0.1,
		"looted": false,
	}
	cls._tick_corpse_timers(1.0)
	assert_eq("CorpseLootSystem: corpse removed from tracking after despawn", cls.get_corpse_count(), 0)
	cls.queue_free()

func test_corpse_looted_signal_emitted() -> void:
	var cls: CorpseLootSystem = preload("res://scripts/gameplay/corpse_loot_system.gd").new()
	add_child(cls)
	cls._corpses["test_corpse"] = {
		"position": Vector3.ZERO,
		"items": {},
		"time_remaining": 300.0,
		"looted": false,
	}
	var looted_id: String = ""
	EventBus.corpse_looted.connect(func(cid: String) -> void: looted_id = cid)
	cls.loot_corpse("test_corpse")
	assert_eq("CorpseLootSystem: corpse_looted signal emitted on loot", looted_id, "test_corpse")
	cls.queue_free()

func test_corpse_get_time_remaining_valid() -> void:
	var cls: CorpseLootSystem = preload("res://scripts/gameplay/corpse_loot_system.gd").new()
	add_child(cls)
	assert_near("CorpseLootSystem: get_time_remaining returns -1 for unknown id",
		cls.get_time_remaining("no_such_corpse"), -1.0)
	cls._corpses["test_corpse"] = {
		"position": Vector3.ZERO,
		"items": {},
		"time_remaining": 150.0,
		"looted": false,
	}
	assert_near("CorpseLootSystem: get_time_remaining returns correct value",
		cls.get_time_remaining("test_corpse"), 150.0)
	cls.queue_free()

# ─────────────────────────────────────────────
# EventBus signal presence check
# ─────────────────────────────────────────────

func test_eventbus_corpse_signals() -> void:
	for sig: String in ["corpse_spawned", "corpse_looted", "corpse_despawned"]:
		assert_true("EventBus has signal: %s" % sig, EventBus.has_signal(sig))

# ─────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────

func _ready() -> void:
	print("=== Death System Tests (Agent 05) ===")
	test_death_initial_stats()
	test_death_tracks_enemy_kills()
	test_death_tracks_corpse_loot()
	test_death_reset_on_player_spawned()
	test_death_not_double_processed()
	test_death_enriched_stats_in_record()
	test_death_manual_reset()
	test_corpse_spawned_on_enemy_killed()
	test_corpse_spawned_signal_emitted()
	test_corpse_loot_returns_true()
	test_corpse_loot_emits_item_picked_up()
	test_corpse_already_looted_returns_false()
	test_corpse_invalid_id_returns_false()
	test_corpse_peek_does_not_consume()
	test_corpse_has_corpse_true_when_active()
	test_corpse_has_corpse_false_after_loot()
	test_corpse_get_available_excludes_looted()
	test_corpse_unknown_type_uses_default_table()
	test_corpse_time_remaining_decreases()
	test_corpse_despawned_signal_emitted()
	test_corpse_removed_after_despawn()
	test_corpse_looted_signal_emitted()
	test_corpse_get_time_remaining_valid()
	test_eventbus_corpse_signals()
	print("=== Results: %d passed, %d failed ===" % [_pass, _fail])
