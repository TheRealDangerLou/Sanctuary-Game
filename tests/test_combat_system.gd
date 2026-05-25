extends Node
## TestCombatSystem: Unit tests for Agent 03 — Combat & Ballistics System.
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
# HitDetection tests
# ─────────────────────────────────────────────

func test_hit_detection_multipliers() -> void:
	var head_dmg: float = HitDetection.get_scaled_damage(10.0, "head")
	assert_near("HitDetection: head 10× = 100.0", head_dmg, 100.0)

	var torso_dmg: float = HitDetection.get_scaled_damage(10.0, "torso")
	assert_near("HitDetection: torso 1× = 10.0", torso_dmg, 10.0)

	var foot_dmg: float = HitDetection.get_scaled_damage(10.0, "foot_l")
	assert_true("HitDetection: foot_l < torso", foot_dmg < torso_dmg)

	var unknown_dmg: float = HitDetection.get_scaled_damage(10.0, "made_up_location")
	assert_near("HitDetection: unknown falls back to 1×", unknown_dmg, 10.0)

func test_instakill_uses_base_damage_not_falloff() -> void:
	# Rifle (55 base) headshot — must instakill regardless of range.
	assert_true("Instakill: rifle headshot (55 base)", HitDetection.is_instakill(55.0, "head"))
	assert_true("Instakill: pistol headshot (35 base)", HitDetection.is_instakill(35.0, "head"))
	# Simulate post-falloff value (55 * 0.2 = 11.0) — must NOT instakill (falloff path is wrong).
	assert_false("Instakill: falloff-reduced 11.0 does NOT instakill", HitDetection.is_instakill(11.0, "head"))
	# Fists (8 base) never instakill on head.
	assert_false("Instakill: fists headshot (8 base)", HitDetection.is_instakill(8.0, "head"))
	# Torso shot never instakills regardless of damage.
	assert_false("Instakill: rifle torso never instakill", HitDetection.is_instakill(55.0, "torso"))

func test_area_location_resolve() -> void:
	assert_eq("Resolve: 'head' → 'head'", HitDetection.resolve_area_location("head"), "head")
	assert_eq("Resolve: unknown → 'torso'", HitDetection.resolve_area_location("garbage"), "torso")
	assert_eq("Resolve: 'thigh_l' → 'thigh_l'", HitDetection.resolve_area_location("thigh_l"), "thigh_l")

# ─────────────────────────────────────────────
# WeaponBase tests
# ─────────────────────────────────────────────

func test_weapon_base_condition() -> void:
	var wb: Node3D = preload("res://scripts/gameplay/weapon_base.gd").new()
	wb.max_condition = 100.0
	wb.current_condition = 100.0
	assert_near("WeaponBase: condition starts full", wb.get_condition_pct(), 1.0)
	assert_false("WeaponBase: not broken at full", wb.is_broken())
	wb.current_condition = 0.0
	assert_true("WeaponBase: broken at 0", wb.is_broken())
	wb.queue_free()

func test_weapon_base_damage_penalty() -> void:
	var wb: Node3D = preload("res://scripts/gameplay/weapon_base.gd").new()
	wb.damage = 100.0
	wb.condition_poor_threshold = 30.0
	wb.current_condition = 50.0
	assert_near("WeaponBase: full damage above threshold", wb.get_effective_damage(), 100.0)
	wb.current_condition = 20.0
	assert_near("WeaponBase: 60% damage below threshold", wb.get_effective_damage(), 60.0)
	wb.queue_free()

func test_weapon_jam_probability() -> void:
	var wb: Node3D = preload("res://scripts/gameplay/weapon_base.gd").new()
	wb.max_condition = 100.0
	wb.condition_poor_threshold = 30.0
	wb.jam_chance_max = 0.15

	# Above poor threshold: zero jam chance.
	wb.current_condition = 50.0
	assert_near("Jam: 0% chance above poor threshold", wb.get_jam_probability(), 0.0)

	# At threshold boundary: still 0.
	wb.current_condition = 30.0
	assert_near("Jam: 0% chance at exact threshold", wb.get_jam_probability(), 0.0)

	# Below threshold: chance scales up.
	wb.current_condition = 15.0   # halfway between 0 and 30 → severity 0.5 → 7.5%
	assert_near("Jam: 7.5% at half-poor condition", wb.get_jam_probability(), 0.075, 0.001)

	# Near 0 condition: approaches max.
	wb.current_condition = 1.0
	var prob: float = wb.get_jam_probability()
	assert_true("Jam: probability > 0.14 near-zero condition", prob > 0.14)
	assert_true("Jam: probability <= jam_chance_max", prob <= wb.jam_chance_max)

	# Disabled: jam_chance_max = 0.
	wb.jam_chance_max = 0.0
	wb.current_condition = 1.0
	assert_near("Jam: 0% when jam_chance_max = 0", wb.get_jam_probability(), 0.0)
	wb.queue_free()

func test_weapon_jam_signal_emitted() -> void:
	assert_true("EventBus has signal: weapon_jammed", EventBus.has_signal("weapon_jammed"))

# ─────────────────────────────────────────────
# CombatSystem bleed tests
# ─────────────────────────────────────────────

func test_combat_system_bleed_tracking() -> void:
	var cs: Node = preload("res://scripts/gameplay/combat_system.gd").new()
	add_child(cs)

	assert_false("Bleed: target not bleeding initially", cs.is_bleeding("zombie_01"))
	EventBus.bleed_started.emit("zombie_01", 3.0)
	assert_true("Bleed: target bleeding after signal", cs.is_bleeding("zombie_01"))
	cs.clear_bleed("zombie_01")
	assert_false("Bleed: bleed cleared via clear_bleed()", cs.is_bleeding("zombie_01"))
	cs.queue_free()

func test_combat_system_multiple_bleeds() -> void:
	var cs: Node = preload("res://scripts/gameplay/combat_system.gd").new()
	add_child(cs)

	EventBus.bleed_started.emit("zombie_a", 2.0)
	EventBus.bleed_started.emit("zombie_b", 4.0)
	var bleeding: Array = cs.get_bleeding_targets()
	assert_true("Bleed: two targets tracked", bleeding.size() == 2)
	assert_true("Bleed: zombie_a in list", bleeding.has("zombie_a"))
	assert_true("Bleed: zombie_b in list", bleeding.has("zombie_b"))
	cs.queue_free()

func test_combat_system_npc_die_clears_bleed() -> void:
	var cs: Node = preload("res://scripts/gameplay/combat_system.gd").new()
	add_child(cs)

	EventBus.bleed_started.emit("npc_07", 2.5)
	assert_true("Bleed: npc_07 bleeding before death", cs.is_bleeding("npc_07"))
	EventBus.npc_died.emit("npc_07", "shot")
	assert_false("Bleed: cleared on npc_died", cs.is_bleeding("npc_07"))
	cs.queue_free()

func test_combat_system_injury_treated_clears_player_bleed() -> void:
	var cs: Node = preload("res://scripts/gameplay/combat_system.gd").new()
	add_child(cs)

	EventBus.bleed_started.emit("player", 2.0)
	assert_true("Bleed: player bleeding before treatment", cs.is_bleeding("player"))
	EventBus.injury_treated.emit("leg")
	assert_false("Bleed: player bleed cleared by injury_treated", cs.is_bleeding("player"))
	cs.queue_free()

# ─────────────────────────────────────────────
# Location damage applied for ranged hits (logic path test)
# ─────────────────────────────────────────────

func test_location_damage_scaling() -> void:
	# Verify the scaled values that _cast_ray will produce.
	var rifle_dmg: float = 55.0
	var head_scaled: float = HitDetection.get_scaled_damage(rifle_dmg, "head")
	assert_near("Location: rifle head = 550.0", head_scaled, 550.0)

	var torso_scaled: float = HitDetection.get_scaled_damage(rifle_dmg, "torso")
	assert_near("Location: rifle torso = 55.0", torso_scaled, 55.0)

	# Instakill bypass: base damage is used for is_instakill check, not falloff-reduced.
	var falloff_reduced: float = rifle_dmg * 0.1   # simulating long-range (90% falloff)
	assert_false("Location: falloff-reduced (5.5) does NOT instakill", HitDetection.is_instakill(falloff_reduced, "head"))
	assert_true("Location: base rifle (55) DOES instakill", HitDetection.is_instakill(rifle_dmg, "head"))

# ─────────────────────────────────────────────
# Ranged weapon ammo state
# ─────────────────────────────────────────────

func test_ranged_weapon_ammo_state() -> void:
	var rw: Node3D = preload("res://scripts/gameplay/ranged_weapon.gd").new()
	rw.magazine_capacity = 12
	rw.current_ammo = 12
	var state: Array = rw.get_ammo_state()
	assert_eq("Ammo: get_ammo_state current", state[0], 12)
	assert_eq("Ammo: get_ammo_state max", state[1], 12)
	rw.queue_free()

# ─────────────────────────────────────────────
# Weapon scene existence checks
# ─────────────────────────────────────────────

func test_weapon_scenes_exist() -> void:
	var paths: Array[String] = [
		"res://scenes/gameplay/weapons/pistol.tscn",
		"res://scenes/gameplay/weapons/suppressed_pistol.tscn",
		"res://scenes/gameplay/weapons/shotgun.tscn",
		"res://scenes/gameplay/weapons/rifle.tscn",
		"res://scenes/gameplay/weapons/bow.tscn",
		"res://scenes/gameplay/weapons/crossbow.tscn",
		"res://scenes/gameplay/weapons/knife.tscn",
		"res://scenes/gameplay/weapons/bat.tscn",
		"res://scenes/gameplay/weapons/axe.tscn",
		"res://scenes/gameplay/weapons/spear.tscn",
		"res://scenes/gameplay/weapons/machete.tscn",
		"res://scenes/gameplay/weapons/fists.tscn",
	]
	for p: String in paths:
		assert_true("Scene exists: %s" % p, ResourceLoader.exists(p))

# ─────────────────────────────────────────────
# EventBus signal presence checks
# ─────────────────────────────────────────────

func test_eventbus_signals() -> void:
	for sig: String in [
		"combat_hit", "bleed_started", "ragdoll_triggered", "blood_impact",
		"weapon_fired", "weapon_reloading", "weapon_jammed",
		"player_hit", "enemy_killed", "narrative_event_triggered",
	]:
		assert_true("EventBus has signal: %s" % sig, EventBus.has_signal(sig))

# ─────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────

func _ready() -> void:
	print("=== Combat System Tests ===")
	test_hit_detection_multipliers()
	test_instakill_uses_base_damage_not_falloff()
	test_area_location_resolve()
	test_weapon_base_condition()
	test_weapon_base_damage_penalty()
	test_weapon_jam_probability()
	test_weapon_jam_signal_emitted()
	test_combat_system_bleed_tracking()
	test_combat_system_multiple_bleeds()
	test_combat_system_npc_die_clears_bleed()
	test_combat_system_injury_treated_clears_player_bleed()
	test_location_damage_scaling()
	test_ranged_weapon_ammo_state()
	test_weapon_scenes_exist()
	test_eventbus_signals()
	print("=== Results: %d passed, %d failed ===" % [_pass, _fail])
