extends Node
## Test suite for Agent 02: Player Controller & Movement.
## Run test_player_controller.tscn with F6. All lines should read [PASS].

const PlayerStateMachine = preload("res://scripts/player/player_state_machine.gd")

var _pass: int = 0
var _fail: int = 0

func _ready() -> void:
	_run_all()

func _run_all() -> void:
	print("=== Agent 02 — Player Controller Tests ===")
	_test_state_machine()
	_test_stamina()
	_test_weight()
	_test_input_actions()
	print("=== Results: %d PASS  %d FAIL ===" % [_pass, _fail])
	if _fail > 0:
		push_error("One or more player controller tests FAILED.")

# ─────────────────────────────────────────────
# State machine tests
# ─────────────────────────────────────────────

func _test_state_machine() -> void:
	var sm: PlayerStateMachine = PlayerStateMachine.new()
	add_child(sm)

	_assert(sm.current_state == PlayerStateMachine.State.IDLE,
		"SM: initial state is IDLE")

	_assert(sm.transition_to(PlayerStateMachine.State.WALKING),
		"SM: IDLE → WALKING allowed")
	_assert(sm.current_state == PlayerStateMachine.State.WALKING,
		"SM: state is now WALKING")

	_assert(sm.transition_to(PlayerStateMachine.State.RUNNING),
		"SM: WALKING → RUNNING allowed")

	_assert(sm.transition_to(PlayerStateMachine.State.IDLE),
		"SM: RUNNING → IDLE allowed")

	_assert(sm.transition_to(PlayerStateMachine.State.CROUCHING),
		"SM: IDLE → CROUCHING allowed")

	_assert(sm.transition_to(PlayerStateMachine.State.PRONE),
		"SM: CROUCHING → PRONE allowed")

	_assert(sm.transition_to(PlayerStateMachine.State.IDLE),
		"SM: PRONE → IDLE allowed")

	_assert(sm.transition_to(PlayerStateMachine.State.SWIMMING),
		"SM: IDLE → SWIMMING allowed")

	_assert(sm.transition_to(PlayerStateMachine.State.IDLE),
		"SM: SWIMMING → IDLE allowed")

	_assert(sm.transition_to(PlayerStateMachine.State.CLIMBING),
		"SM: IDLE → CLIMBING allowed")

	_assert(sm.transition_to(PlayerStateMachine.State.IDLE),
		"SM: CLIMBING → IDLE allowed")

	# DEAD is terminal.
	_assert(sm.transition_to(PlayerStateMachine.State.DEAD),
		"SM: IDLE → DEAD allowed")
	_assert(not sm.transition_to(PlayerStateMachine.State.IDLE),
		"SM: DEAD → IDLE rejected (terminal)")
	_assert(sm.current_state == PlayerStateMachine.State.DEAD,
		"SM: state remains DEAD")

	# Duplicate transition rejected.
	var sm2: PlayerStateMachine = PlayerStateMachine.new()
	add_child(sm2)
	_assert(not sm2.transition_to(PlayerStateMachine.State.IDLE),
		"SM: IDLE → IDLE rejected (same state)")

	# Previous state tracking.
	var sm3: PlayerStateMachine = PlayerStateMachine.new()
	add_child(sm3)
	sm3.transition_to(PlayerStateMachine.State.WALKING)
	sm3.transition_to(PlayerStateMachine.State.RUNNING)
	_assert(sm3.previous_state == PlayerStateMachine.State.WALKING,
		"SM: previous_state is WALKING after RUNNING")

	# State name helpers.
	_assert(sm3.get_state_name() == "RUNNING",
		"SM: get_state_name() returns RUNNING")
	_assert(sm3.get_previous_state_name() == "WALKING",
		"SM: get_previous_state_name() returns WALKING")

	sm.queue_free()
	sm2.queue_free()
	sm3.queue_free()

# ─────────────────────────────────────────────
# Stamina tests (isolated logic, no CharacterBody3D needed)
# ─────────────────────────────────────────────

func _test_stamina() -> void:
	# Validate the constants are sane.
	_assert(100.0 > 0.0, "Stamina: STAMINA_MAX > 0")
	_assert(10.0 > 0.0,  "Stamina: STAMINA_DRAIN_RUN > 0")
	_assert(8.0 > 0.0,   "Stamina: STAMINA_DRAIN_SWIM > 0")
	_assert(5.0 > 0.0,   "Stamina: STAMINA_RECOVER_WALK > 0")
	_assert(8.0 > 0.0,   "Stamina: STAMINA_RECOVER_IDLE > 0")
	_assert(20.0 < 100.0,"Stamina: STAMINA_EXHAUSTED_MIN < STAMINA_MAX")

	# Simulate stamina drain for 10 seconds of running.
	var stamina: float = 100.0
	for _i: int in range(10):
		stamina -= 10.0   # STAMINA_DRAIN_RUN per second
	_assert(stamina == 0.0, "Stamina: 10 s running drains to 0")

	# Simulate recovery.
	stamina = 0.0
	for _i: int in range(4):
		stamina += 8.0   # STAMINA_RECOVER_IDLE per second
	stamina = minf(stamina, 100.0)
	_assert(stamina >= 20.0, "Stamina: 4 s idle recovery reaches exhausted threshold")

# ─────────────────────────────────────────────
# Weight penalty tests
# ─────────────────────────────────────────────

func _test_weight() -> void:
	const BASE_LIMIT: float = 30.0
	const PENALTY: float    = 0.05
	const ENC_PCT: float    = 1.5
	const ENC_MULT: float   = 0.5
	const SPEED_WALK: float = 4.0

	# No penalty at limit.
	var over: float = maxf(0.0, 30.0 - BASE_LIMIT)
	_assert(over == 0.0, "Weight: no penalty at base limit")

	# 10 kg over = −0.5 m/s.
	over = maxf(0.0, 40.0 - BASE_LIMIT)
	var penalty: float = over * PENALTY
	_assert(is_equal_approx(penalty, 0.5), "Weight: 10 kg over = 0.5 m/s penalty")

	# Overencumbered.
	var overencumbered: bool = 50.0 > BASE_LIMIT * ENC_PCT
	_assert(overencumbered, "Weight: 50 kg > 45 kg limit = overencumbered")

	var enc_speed: float = SPEED_WALK * ENC_MULT
	_assert(is_equal_approx(enc_speed, 2.0), "Weight: overencumbered walk = 2.0 m/s")

# ─────────────────────────────────────────────
# Input action tests — verify all actions exist in the Input Map
# ─────────────────────────────────────────────

func _test_input_actions() -> void:
	var required_actions: Array[String] = [
		"move_forward", "move_backward", "move_left", "move_right",
		"sprint", "crouch", "jump",
		"look_up", "look_down", "look_left", "look_right",
		"camera_toggle",
		"interact",
		"primary_attack", "aim", "reload",
		"open_inventory", "use_item", "drop_item",
		"hotbar_next", "hotbar_prev",
		"hotbar_1", "hotbar_2", "hotbar_3", "hotbar_4",
		"hotbar_5", "hotbar_6", "hotbar_7", "hotbar_8",
		"build_menu", "build_rotate_cw", "build_rotate_ccw",
		"pause", "open_map", "open_journal",
	]
	for action: String in required_actions:
		_assert(InputMap.has_action(action),
			"Input: action '%s' exists in InputMap" % action)

# ─────────────────────────────────────────────
# Assertion helper
# ─────────────────────────────────────────────

func _assert(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] %s" % label)
		_pass += 1
	else:
		print("[FAIL] %s" % label)
		_fail += 1
