extends Node
## TestNoiseSystem: Unit tests for Agent 06 — Noise & Detection System.
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
# NoiseSystem tests
# ─────────────────────────────────────────────

func test_initial_state() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	assert_near("NoiseSystem: global threat starts at 0", ns.get_global_threat(), 0.0)
	assert_true("NoiseSystem: is_silent() true initially", ns.is_silent())
	assert_false("NoiseSystem: is_siege_active() false initially", ns.is_siege_active())
	assert_eq("NoiseSystem: event count starts at 0", ns.get_event_count(), 0)
	ns.queue_free()

func test_emit_noise_known_type_emits_signal() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	var signal_emitted: bool = false
	EventBus.noise_generated.connect(func(_pos: Vector3, _r: float, _l: int) -> void:
		signal_emitted = true)
	ns.emit_noise("pistol_shot", Vector3.ZERO)
	assert_true("NoiseSystem: emit_noise emits noise_generated signal", signal_emitted)
	ns.queue_free()

func test_emit_noise_known_type_correct_level() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	var received_level: int = -1
	EventBus.noise_generated.connect(func(_pos: Vector3, _r: float, lvl: int) -> void:
		received_level = lvl)
	ns.emit_noise("rifle_shot", Vector3.ZERO)
	assert_eq("NoiseSystem: rifle_shot emits level 9", received_level, 9)
	ns.queue_free()

func test_emit_noise_silent_type_no_signal() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	var signal_emitted: bool = false
	EventBus.noise_generated.connect(func(_pos: Vector3, _r: float, _l: int) -> void:
		signal_emitted = true)
	ns.emit_noise("footstep_crouch", Vector3.ZERO)
	assert_false("NoiseSystem: footstep_crouch (level 0) emits no signal", signal_emitted)
	ns.queue_free()

func test_emit_noise_unknown_type_uses_defaults() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	var received_level: int = -1
	var received_radius: float = -1.0
	EventBus.noise_generated.connect(func(_pos: Vector3, r: float, lvl: int) -> void:
		received_level = lvl
		received_radius = r)
	ns.emit_noise("unknown_source_type", Vector3.ZERO)
	assert_eq("NoiseSystem: unknown type defaults to level 1", received_level, 1)
	assert_near("NoiseSystem: unknown type defaults to radius 5.0", received_radius, 5.0)
	ns.queue_free()

func test_noise_event_tracked_after_emission() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	ns.emit_noise("door_break", Vector3.ZERO)
	assert_eq("NoiseSystem: one event tracked after emission", ns.get_event_count(), 1)
	ns.queue_free()

func test_global_threat_accumulates() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	ns.emit_noise("pistol_shot", Vector3.ZERO)
	ns.emit_noise("pistol_shot", Vector3.ZERO)
	## pistol_shot = level 8, two shots = 16 threat
	assert_near("NoiseSystem: threat accumulates from multiple events",
		ns.get_global_threat(), 16.0)
	ns.queue_free()

func test_global_threat_decays() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	ns.emit_noise("pistol_shot", Vector3.ZERO)  ## +8 threat
	ns._tick_threat(1.0)
	## After 1 second: 8.0 - 3.0 = 5.0
	assert_near("NoiseSystem: global threat decays by THREAT_DECAY_RATE per second",
		ns.get_global_threat(), 5.0)
	ns.queue_free()

func test_global_threat_does_not_go_below_zero() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	ns._global_threat = 1.0
	ns._tick_threat(100.0)
	assert_near("NoiseSystem: global threat never goes below 0", ns.get_global_threat(), 0.0)
	ns.queue_free()

func test_is_silent_below_threshold() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	ns._global_threat = 4.9
	assert_true("NoiseSystem: is_silent() true below SILENCE_THRESHOLD", ns.is_silent())
	ns.queue_free()

func test_is_not_silent_above_threshold() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	ns._global_threat = 5.1
	assert_false("NoiseSystem: is_silent() false above SILENCE_THRESHOLD", ns.is_silent())
	ns.queue_free()

func test_get_noise_level_at_within_radius() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	ns._noise_events.append({
		"position": Vector3.ZERO,
		"radius":   10.0,
		"level":    8,
		"age":      0.0,
	})
	var level: float = ns.get_noise_level_at(Vector3(5.0, 0.0, 0.0))
	assert_greater("NoiseSystem: get_noise_level_at > 0 inside radius", level, 0.0)
	ns.queue_free()

func test_get_noise_level_at_outside_radius() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	ns._noise_events.append({
		"position": Vector3.ZERO,
		"radius":   10.0,
		"level":    8,
		"age":      0.0,
	})
	var level: float = ns.get_noise_level_at(Vector3(20.0, 0.0, 0.0))
	assert_near("NoiseSystem: get_noise_level_at = 0 outside radius", level, 0.0)
	ns.queue_free()

func test_get_noise_level_at_origin_is_full() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	ns._noise_events.append({
		"position": Vector3.ZERO,
		"radius":   10.0,
		"level":    8,
		"age":      0.0,
	})
	assert_near("NoiseSystem: noise at origin equals event level", ns.get_noise_level_at(Vector3.ZERO), 8.0)
	ns.queue_free()

func test_get_noise_level_at_midpoint_falloff() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	ns._noise_events.append({
		"position": Vector3.ZERO,
		"radius":   10.0,
		"level":    10,
		"age":      0.0,
	})
	assert_near("NoiseSystem: midpoint falloff is half the level",
		ns.get_noise_level_at(Vector3(5.0, 0.0, 0.0)), 5.0)
	ns.queue_free()

func test_horde_triggered_at_threshold() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	var horde_emitted: bool = false
	EventBus.horde_triggered.connect(func(_pos: Vector3, _size: int) -> void:
		horde_emitted = true)
	ns._global_threat = NoiseSystem.HORDE_THREAT_THRESHOLD
	ns._check_thresholds(Vector3.ZERO)
	assert_true("NoiseSystem: horde_triggered emitted at threshold", horde_emitted)
	ns.queue_free()

func test_horde_not_double_triggered_during_cooldown() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	var horde_count: int = 0
	EventBus.horde_triggered.connect(func(_pos: Vector3, _size: int) -> void: horde_count += 1)
	ns._global_threat = NoiseSystem.HORDE_THREAT_THRESHOLD
	ns._check_thresholds(Vector3.ZERO)
	ns._global_threat = NoiseSystem.HORDE_THREAT_THRESHOLD
	ns._check_thresholds(Vector3.ZERO)
	assert_eq("NoiseSystem: horde not triggered twice within cooldown", horde_count, 1)
	ns.queue_free()

func test_horde_cooldown_resets_threat() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	EventBus.horde_triggered.connect(func(_pos: Vector3, _size: int) -> void: pass)
	ns._global_threat = NoiseSystem.HORDE_THREAT_THRESHOLD
	ns._check_thresholds(Vector3.ZERO)
	assert_near("NoiseSystem: global threat reset to 0 after horde trigger", ns.get_global_threat(), 0.0)
	ns.queue_free()

func test_horde_size_scales_with_threat() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	var small_horde: int = -1
	var large_horde: int = -1
	EventBus.horde_triggered.connect(func(_pos: Vector3, size: int) -> void:
		if small_horde == -1:
			small_horde = size
		else:
			large_horde = size)
	ns._global_threat = NoiseSystem.HORDE_THREAT_THRESHOLD
	ns._check_thresholds(Vector3.ZERO)
	ns._horde_cooldown = 0.0
	ns._global_threat = NoiseSystem.HORDE_THREAT_THRESHOLD * 1.5
	ns._check_thresholds(Vector3.ZERO)
	assert_greater("NoiseSystem: higher threat yields larger horde",
		float(large_horde), float(small_horde))
	ns.queue_free()

func test_siege_triggered_at_threshold() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	var siege_started: bool = false
	EventBus.compound_siege_started.connect(func() -> void: siege_started = true)
	ns._global_threat = NoiseSystem.SIEGE_THREAT_THRESHOLD
	ns._check_thresholds(Vector3.ZERO)
	assert_true("NoiseSystem: compound_siege_started emitted at threshold", siege_started)
	assert_true("NoiseSystem: is_siege_active() true after siege start", ns.is_siege_active())
	ns.queue_free()

func test_siege_ends_after_cooldown() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	var siege_ended: bool = false
	EventBus.compound_siege_started.connect(func() -> void: pass)
	EventBus.compound_siege_ended.connect(func() -> void: siege_ended = true)
	ns._global_threat = NoiseSystem.SIEGE_THREAT_THRESHOLD
	ns._check_thresholds(Vector3.ZERO)
	ns._siege_cooldown = 0.01
	ns._tick_cooldowns(1.0)
	assert_true("NoiseSystem: compound_siege_ended emitted after cooldown", siege_ended)
	assert_false("NoiseSystem: is_siege_active() false after siege ends", ns.is_siege_active())
	ns.queue_free()

func test_weapon_fired_emits_noise_generated() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	var noise_emitted: bool = false
	EventBus.noise_generated.connect(func(_pos: Vector3, _r: float, _l: int) -> void:
		noise_emitted = true)
	EventBus.weapon_fired.emit("pistol_9mm", Vector3.ZERO, 8)
	assert_true("NoiseSystem: weapon_fired triggers noise_generated", noise_emitted)
	ns.queue_free()

func test_weapon_fired_zero_level_no_signal() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	var noise_emitted: bool = false
	EventBus.noise_generated.connect(func(_pos: Vector3, _r: float, _l: int) -> void:
		noise_emitted = true)
	EventBus.weapon_fired.emit("silenced_pistol", Vector3.ZERO, 0)
	assert_false("NoiseSystem: weapon_fired with level 0 emits no noise_generated", noise_emitted)
	ns.queue_free()

func test_events_expire_after_lifetime() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	ns._noise_events.append({
		"position": Vector3.ZERO,
		"radius":   10.0,
		"level":    5,
		"age":      NoiseSystem.EVENT_LIFETIME - 0.1,
	})
	assert_eq("NoiseSystem: event present before expiry", ns.get_event_count(), 1)
	ns._tick_events(0.2)
	assert_eq("NoiseSystem: event removed after EVENT_LIFETIME", ns.get_event_count(), 0)
	ns.queue_free()

func test_max_events_cap_drops_oldest() -> void:
	var ns: NoiseSystem = preload("res://scripts/gameplay/noise_system.gd").new()
	add_child(ns)
	for i: int in range(NoiseSystem.MAX_NOISE_EVENTS):
		ns._noise_events.append({
			"position": Vector3(float(i), 0.0, 0.0),
			"radius": 5.0,
			"level": 1,
			"age": 0.0,
		})
	EventBus.noise_generated.emit(Vector3(999.0, 0.0, 0.0), 5.0, 1)
	assert_eq("NoiseSystem: event count stays at MAX_NOISE_EVENTS after cap",
		ns.get_event_count(), NoiseSystem.MAX_NOISE_EVENTS)
	ns.queue_free()

func test_eventbus_noise_signals_exist() -> void:
	for sig: String in ["noise_generated", "horde_triggered", "compound_siege_started", "compound_siege_ended"]:
		assert_true("EventBus has signal: %s" % sig, EventBus.has_signal(sig))

func test_noise_levels_table_has_expected_keys() -> void:
	for key: String in ["footstep_walk", "footstep_run", "pistol_shot", "rifle_shot",
		"shotgun_shot", "melee_hit", "door_break", "explosion"]:
		assert_true("NoiseSystem: NOISE_LEVELS has key '%s'" % key,
			NoiseSystem.NOISE_LEVELS.has(key))

func test_noise_radii_table_has_expected_keys() -> void:
	for key: String in ["footstep_walk", "footstep_run", "pistol_shot", "rifle_shot",
		"shotgun_shot", "melee_hit", "door_break", "explosion"]:
		assert_true("NoiseSystem: NOISE_RADII has key '%s'" % key,
			NoiseSystem.NOISE_RADII.has(key))

# ─────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────

func _ready() -> void:
	print("=== Noise System Tests (Agent 06) ===")
	test_initial_state()
	test_emit_noise_known_type_emits_signal()
	test_emit_noise_known_type_correct_level()
	test_emit_noise_silent_type_no_signal()
	test_emit_noise_unknown_type_uses_defaults()
	test_noise_event_tracked_after_emission()
	test_global_threat_accumulates()
	test_global_threat_decays()
	test_global_threat_does_not_go_below_zero()
	test_is_silent_below_threshold()
	test_is_not_silent_above_threshold()
	test_get_noise_level_at_within_radius()
	test_get_noise_level_at_outside_radius()
	test_get_noise_level_at_origin_is_full()
	test_get_noise_level_at_midpoint_falloff()
	test_horde_triggered_at_threshold()
	test_horde_not_double_triggered_during_cooldown()
	test_horde_cooldown_resets_threat()
	test_horde_size_scales_with_threat()
	test_siege_triggered_at_threshold()
	test_siege_ends_after_cooldown()
	test_weapon_fired_emits_noise_generated()
	test_weapon_fired_zero_level_no_signal()
	test_events_expire_after_lifetime()
	test_max_events_cap_drops_oldest()
	test_eventbus_noise_signals_exist()
	test_noise_levels_table_has_expected_keys()
	test_noise_radii_table_has_expected_keys()
	print("=== Results: %d passed, %d failed ===" % [_pass, _fail])
