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
	# Head shot should have a high multiplier.
	var head_dmg: float = HitDetection.get_scaled_damage(10.0, "head")
	assert_near("HitDetection: head multiplier × 10.0 = 100.0", head_dmg, 100.0)

	# Torso is baseline.
	var torso_dmg: float = HitDetection.get_scaled_damage(10.0, "torso")
	assert_near("HitDetection: torso multiplier × 10.0 = 10.0", torso_dmg, 10.0)

	# Foot should be less than torso.
	var foot_dmg: float = HitDetection.get_scaled_damage(10.0, "foot_l")
	assert_true("HitDetection: foot_l damage < torso damage", foot_dmg < torso_dmg)

	# Unknown location should fall back to 1.0×.
	var unknown_dmg: float = HitDetection.get_scaled_damage(10.0, "made_up_location")
	assert_near("HitDetection: unknown location falls back to 1.0×", unknown_dmg, 10.0)

func test_instakill_logic() -> void:
	# Firearm headshot (>= 15 base) should be instakill.
	assert_true("HitDetection: rifle headshot is instakill", HitDetection.is_instakill(55.0, "head"))
	assert_true("HitDetection: pistol headshot (35) is instakill", HitDetection.is_instakill(35.0, "head"))
	# Low-damage hit to head (e.g. fists, 8) should NOT be instakill.
	assert_false("HitDetection: fist headshot (8) not instakill", HitDetection.is_instakill(8.0, "head"))
	# Torso shot from rifle is NOT instakill.
	assert_false("HitDetection: rifle torso not instakill", HitDetection.is_instakill(55.0, "torso"))

func test_area_location_resolve() -> void:
	assert_eq("HitDetection: 'head' resolves to 'head'", HitDetection.resolve_area_location("head"), "head")
	assert_eq("HitDetection: unknown resolves to 'torso'", HitDetection.resolve_area_location("garbage"), "torso")
	assert_eq("HitDetection: 'thigh_l' resolves correctly", HitDetection.resolve_area_location("thigh_l"), "thigh_l")

# ─────────────────────────────────────────────
# WeaponBase tests
# ─────────────────────────────────────────────

func test_weapon_base_condition() -> void:
	var wb: Node3D = preload("res://scripts/gameplay/weapon_base.gd").new()
	wb.max_condition = 100.0
	wb.condition_drain_per_use = 10.0
	wb.current_condition = 100.0
	assert_near("WeaponBase: condition starts full", wb.get_condition_pct(), 1.0)
	assert_false("WeaponBase: not broken at full", wb.is_broken())

	# Drain manually.
	wb.current_condition = 0.0
	assert_true("WeaponBase: broken at 0", wb.is_broken())
	wb.queue_free()

func test_weapon_base_damage_penalty() -> void:
	var wb: Node3D = preload("res://scripts/gameplay/weapon_base.gd").new()
	wb.damage = 100.0
	wb.condition_poor_threshold = 30.0
	wb.current_condition = 50.0   # Above threshold.
	assert_near("WeaponBase: full damage above threshold", wb.get_effective_damage(), 100.0)
	wb.current_condition = 20.0   # Below threshold.
	assert_near("WeaponBase: 60% damage below threshold", wb.get_effective_damage(), 60.0)
	wb.queue_free()

# ─────────────────────────────────────────────
# CombatSystem bleed tests
# ─────────────────────────────────────────────

func test_combat_system_bleed_tracking() -> void:
	var cs: Node = preload("res://scripts/gameplay/combat_system.gd").new()
	add_child(cs)

	assert_false("CombatSystem: target not bleeding initially", cs.is_bleeding("zombie_01"))
	EventBus.bleed_started.emit("zombie_01", 3.0)
	assert_true("CombatSystem: target bleeding after signal", cs.is_bleeding("zombie_01"))
	cs.clear_bleed("zombie_01")
	assert_false("CombatSystem: bleed cleared", cs.is_bleeding("zombie_01"))
	cs.queue_free()

func test_combat_system_multiple_bleeds() -> void:
	var cs: Node = preload("res://scripts/gameplay/combat_system.gd").new()
	add_child(cs)

	EventBus.bleed_started.emit("zombie_a", 2.0)
	EventBus.bleed_started.emit("zombie_b", 4.0)
	var bleeding: Array = cs.get_bleeding_targets()
	assert_true("CombatSystem: two bleeding targets tracked", bleeding.size() == 2)
	assert_true("CombatSystem: zombie_a in list", bleeding.has("zombie_a"))
	assert_true("CombatSystem: zombie_b in list", bleeding.has("zombie_b"))
	cs.queue_free()

func test_combat_system_npc_die_clears_bleed() -> void:
	var cs: Node = preload("res://scripts/gameplay/combat_system.gd").new()
	add_child(cs)

	EventBus.bleed_started.emit("npc_07", 2.5)
	assert_true("CombatSystem: npc_07 bleeding before death", cs.is_bleeding("npc_07"))
	EventBus.npc_died.emit("npc_07", "shot")
	assert_false("CombatSystem: bleed cleared on npc death", cs.is_bleeding("npc_07"))
	cs.queue_free()

# ─────────────────────────────────────────────
# Ranged weapon stat tests (data checks — no scene tree needed)
# ─────────────────────────────────────────────

func test_ranged_weapon_ammo_state() -> void:
	var rw: Node3D = preload("res://scripts/gameplay/ranged_weapon.gd").new()
	rw.magazine_capacity = 12
	# _ready not called (no tree) so set ammo manually.
	rw.current_ammo = 12
	var state: Array = rw.get_ammo_state()
	assert_eq("RangedWeapon: get_ammo_state current", state[0], 12)
	assert_eq("RangedWeapon: get_ammo_state max", state[1], 12)
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
	for sig: String in ["combat_hit", "bleed_started", "ragdoll_triggered", "blood_impact",
						"weapon_fired", "weapon_reloading", "player_hit", "enemy_killed"]:
		assert_true("EventBus has signal: %s" % sig, EventBus.has_signal(sig))

# ─────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────

func _ready() -> void:
	print("=== Combat System Tests ===")
	test_hit_detection_multipliers()
	test_instakill_logic()
	test_area_location_resolve()
	test_weapon_base_condition()
	test_weapon_base_damage_penalty()
	test_combat_system_bleed_tracking()
	test_combat_system_multiple_bleeds()
	test_combat_system_npc_die_clears_bleed()
	test_ranged_weapon_ammo_state()
	test_weapon_scenes_exist()
	test_eventbus_signals()
	print("=== Results: %d passed, %d failed ===" % [_pass, _fail])
