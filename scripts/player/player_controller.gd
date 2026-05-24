extends CharacterBody3D
## PlayerController: Drives player movement, stamina, weight penalties, and
## injury modifiers. Owns the PlayerStateMachine and receives processed input
## from PlayerInput. Communicates outward exclusively through EventBus signals.

const PlayerStateMachine = preload("res://scripts/player/player_state_machine.gd")

# ─────────────────────────────────────────────
# Movement constants
# ─────────────────────────────────────────────

const SPEED_WALK: float   = 4.0   ## m/s
const SPEED_RUN: float    = 7.0   ## m/s
const SPEED_CROUCH: float = 2.0   ## m/s
const SPEED_PRONE: float  = 1.0   ## m/s
const SPEED_SWIM: float   = 2.5   ## m/s

const ACCEL: float  = 8.0    ## m/s² — ramp-up rate
const DECEL: float  = 10.0   ## m/s² — ramp-down rate

const JUMP_HEIGHT: float   = 1.2   ## metres
const GRAVITY: float       = 9.8   ## m/s²

## Derived jump velocity: v = sqrt(2 * g * h)
const JUMP_VELOCITY: float = sqrt(2.0 * GRAVITY * JUMP_HEIGHT)

# ─────────────────────────────────────────────
# Stamina constants
# ─────────────────────────────────────────────

const STAMINA_MAX: float          = 100.0
const STAMINA_DRAIN_RUN: float    = 10.0   ## per second
const STAMINA_DRAIN_SWIM: float   = 8.0    ## per second
const STAMINA_RECOVER_WALK: float = 5.0    ## per second
const STAMINA_RECOVER_IDLE: float = 8.0    ## per second
const STAMINA_EXHAUSTED_MIN: float = 20.0  ## must reach this before running again

# ─────────────────────────────────────────────
# Weight constants
# ─────────────────────────────────────────────

const WEIGHT_BASE_LIMIT: float     = 30.0   ## kg — no penalty below this
const WEIGHT_ENCUMBERED_PCT: float = 1.5    ## 150 % = overencumbered
const WEIGHT_SPEED_PENALTY: float  = 0.05   ## m/s per kg over limit
const WEIGHT_ENCUMBERED_MULT: float = 0.5   ## 50 % speed when overencumbered

# ─────────────────────────────────────────────
# Slope / step constants
# ─────────────────────────────────────────────

const SLOPE_SLIDE_ANGLE: float = deg_to_rad(45.0)   ## steeper → slide down
const STEP_HEIGHT: float       = 0.35               ## max step the player can climb

# ─────────────────────────────────────────────
# Noise constants (noise_level on 1-10 scale)
# ─────────────────────────────────────────────

const NOISE_FOOTSTEP_INTERVAL: float = 0.45   ## seconds between footstep events

# surface → [noise_level, radius_m]
const NOISE_TABLE: Dictionary = {
	"default":   [1, 5.0],
	"grass":     [1, 5.0],
	"dirt":      [1, 5.0],
	"gravel":    [2, 10.0],
	"metal":     [3, 15.0],
	"concrete":  [3, 15.0],
	"wood":      [2, 10.0],
}

# ─────────────────────────────────────────────
# Node references (set in _ready via NodePath)
# ─────────────────────────────────────────────

@export var stand_collision_path: NodePath
@export var crouch_collision_path: NodePath
@export var camera_mount_path: NodePath
@export var interact_ray_path: NodePath

@onready var _stand_col: CollisionShape3D    = get_node(stand_collision_path) if stand_collision_path else null
@onready var _crouch_col: CollisionShape3D  = get_node(crouch_collision_path) if crouch_collision_path else null
@onready var _camera_mount: Node3D           = get_node(camera_mount_path) if camera_mount_path else null
@onready var _interact_ray: RayCast3D        = get_node(interact_ray_path) if interact_ray_path else null

# ─────────────────────────────────────────────
# Child systems (found at runtime)
# ─────────────────────────────────────────────

var _state_machine: PlayerStateMachine = null
var _input: Node = null   ## PlayerInput node

# ─────────────────────────────────────────────
# Runtime state
# ─────────────────────────────────────────────

var stamina: float = STAMINA_MAX
var _stamina_exhausted: bool = false

var current_weight: float = 0.0
var max_carry_weight: float = WEIGHT_BASE_LIMIT

var _in_water: bool = false
var _current_surface: String = "default"
var _footstep_timer: float = 0.0
var _prone_toggled: bool = false

## Injury flags — set externally via listen_to_injuries().
var _injury_leg: bool = false
var _injury_shoulder: bool = false
var _injury_head: bool = false

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	_state_machine = PlayerStateMachine.new()
	add_child(_state_machine)

	# Find PlayerInput sibling or child.
	_input = _find_node_of_script("player_input.gd")

	# Connect EventBus listeners.
	EventBus.injury_applied.connect(_on_injury_applied)
	EventBus.injury_treated.connect(_on_injury_treated)
	EventBus.inventory_weight_changed.connect(_on_weight_changed)

	# Lock cursor for mouse look when gameplay starts.
	_set_mouse_mode_for_state(GameManager.current_state)
	GameManager.current_state  # evaluated once to register

	# Camera snap to standing position.
	_update_camera_mount_height(false)

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if _state_machine.current_state == PlayerStateMachine.State.DEAD:
		return

	_handle_water_detection()
	_handle_state_transitions()
	_apply_gravity(delta)
	_apply_movement(delta)
	_handle_jump()
	_handle_stamina(delta)
	_handle_footsteps(delta)
	move_and_slide()

	if _input:
		_input.consume_frame()

# ─────────────────────────────────────────────
# State machine integration
# ─────────────────────────────────────────────

func on_state_entered(state: PlayerStateMachine.State) -> void:
	match state:
		PlayerStateMachine.State.CROUCHING:
			_swap_collision(true)
			_update_camera_mount_height(true)
		PlayerStateMachine.State.PRONE:
			_swap_collision(true)
			_update_camera_mount_height(true)
		_:
			_swap_collision(false)
			_update_camera_mount_height(false)

func on_state_exited(_state: PlayerStateMachine.State) -> void:
	pass

# ─────────────────────────────────────────────
# State transition logic (called each physics tick)
# ─────────────────────────────────────────────

func _handle_state_transitions() -> void:
	if not _input:
		return

	var state: PlayerStateMachine.State = _state_machine.current_state

	# Death is terminal.
	if state == PlayerStateMachine.State.DEAD:
		return

	# Water overrides most transitions.
	if _in_water:
		if state != PlayerStateMachine.State.SWIMMING:
			_state_machine.transition_to(PlayerStateMachine.State.SWIMMING)
		return
	if state == PlayerStateMachine.State.SWIMMING:
		_state_machine.transition_to(PlayerStateMachine.State.IDLE)

	# Prone toggle.
	if _input.want_prone:
		if state == PlayerStateMachine.State.PRONE:
			_state_machine.transition_to(PlayerStateMachine.State.CROUCHING)
		elif state == PlayerStateMachine.State.CROUCHING or state == PlayerStateMachine.State.IDLE or state == PlayerStateMachine.State.WALKING:
			_state_machine.transition_to(PlayerStateMachine.State.PRONE)

	# Crouch held.
	if _input.want_crouch and state != PlayerStateMachine.State.PRONE:
		if state != PlayerStateMachine.State.CROUCHING:
			_state_machine.transition_to(PlayerStateMachine.State.CROUCHING)
	elif not _input.want_crouch and state == PlayerStateMachine.State.CROUCHING:
		_state_machine.transition_to(
			PlayerStateMachine.State.WALKING if _input.move_direction.length() > 0.05
			else PlayerStateMachine.State.IDLE
		)

	# Movement-based transitions.
	var moving: bool = _input.move_direction.length() > 0.05
	var can_run: bool = (
		_input.want_run
		and not _stamina_exhausted
		and not _injury_leg
		and not _is_overencumbered()
	)

	match state:
		PlayerStateMachine.State.IDLE:
			if moving:
				_state_machine.transition_to(
					PlayerStateMachine.State.RUNNING if can_run
					else PlayerStateMachine.State.WALKING
				)
		PlayerStateMachine.State.WALKING:
			if not moving:
				_state_machine.transition_to(PlayerStateMachine.State.IDLE)
			elif can_run:
				_state_machine.transition_to(PlayerStateMachine.State.RUNNING)
		PlayerStateMachine.State.RUNNING:
			if not moving:
				_state_machine.transition_to(PlayerStateMachine.State.IDLE)
			elif not can_run:
				_state_machine.transition_to(PlayerStateMachine.State.WALKING)

# ─────────────────────────────────────────────
# Physics helpers
# ─────────────────────────────────────────────

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

func _apply_movement(delta: float) -> void:
	if not _input:
		return

	var target_speed: float = _get_target_speed()
	var dir_local: Vector3 = Vector3(_input.move_direction.x, 0.0, _input.move_direction.y)
	var dir_world: Vector3 = global_transform.basis * dir_local

	# Steep slope — push away from slope.
	if is_on_wall() and get_wall_normal().y < -0.1:
		dir_world += get_wall_normal() * 0.5

	var target_vel: Vector3 = dir_world * target_speed
	var rate: float = ACCEL if dir_world.length() > 0.05 else DECEL
	velocity.x = move_toward(velocity.x, target_vel.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, rate * delta)

	# Slope slide: push down steep surfaces.
	if is_on_floor() and get_floor_angle() > SLOPE_SLIDE_ANGLE:
		var slide_dir: Vector3 = get_floor_normal().cross(Vector3.UP).cross(get_floor_normal())
		velocity += slide_dir * GRAVITY * delta

func _handle_jump() -> void:
	if not _input:
		return
	if _input.want_jump and is_on_floor():
		var state: PlayerStateMachine.State = _state_machine.current_state
		if state == PlayerStateMachine.State.PRONE or state == PlayerStateMachine.State.SWIMMING:
			return
		velocity.y = JUMP_VELOCITY
		EventBus.noise_generated.emit(global_position, 8.0, 2)

# ─────────────────────────────────────────────
# Speed calculation
# ─────────────────────────────────────────────

func _get_target_speed() -> float:
	var state: PlayerStateMachine.State = _state_machine.current_state

	var base: float
	match state:
		PlayerStateMachine.State.RUNNING:   base = SPEED_RUN
		PlayerStateMachine.State.CROUCHING: base = SPEED_CROUCH
		PlayerStateMachine.State.PRONE:     base = SPEED_PRONE
		PlayerStateMachine.State.SWIMMING:  base = SPEED_SWIM
		_:                                  base = SPEED_WALK

	# Leg injury.
	if _injury_leg:
		base *= 0.6

	# Weight penalties.
	var over_kg: float = maxf(0.0, current_weight - WEIGHT_BASE_LIMIT)
	base -= over_kg * WEIGHT_SPEED_PENALTY

	if _is_overencumbered():
		base *= WEIGHT_ENCUMBERED_MULT
		if state == PlayerStateMachine.State.RUNNING:
			base = minf(base, SPEED_WALK * WEIGHT_ENCUMBERED_MULT)

	return maxf(0.0, base)

func _is_overencumbered() -> bool:
	return current_weight > max_carry_weight * WEIGHT_ENCUMBERED_PCT

# ─────────────────────────────────────────────
# Stamina
# ─────────────────────────────────────────────

func _handle_stamina(delta: float) -> void:
	var state: PlayerStateMachine.State = _state_machine.current_state
	var prev: float = stamina

	match state:
		PlayerStateMachine.State.RUNNING:
			stamina -= STAMINA_DRAIN_RUN * delta
		PlayerStateMachine.State.SWIMMING:
			stamina -= STAMINA_DRAIN_SWIM * delta
		PlayerStateMachine.State.WALKING, PlayerStateMachine.State.CROUCHING, PlayerStateMachine.State.PRONE:
			stamina += STAMINA_RECOVER_WALK * delta
		_:
			stamina += STAMINA_RECOVER_IDLE * delta

	stamina = clampf(stamina, 0.0, STAMINA_MAX)

	if stamina <= 0.0:
		_stamina_exhausted = true
	elif stamina >= STAMINA_EXHAUSTED_MIN:
		_stamina_exhausted = false

	if not is_equal_approx(stamina, prev):
		EventBus.player_stamina_changed.emit(stamina, STAMINA_MAX)

# ─────────────────────────────────────────────
# Footstep noise
# ─────────────────────────────────────────────

func _handle_footsteps(delta: float) -> void:
	var state: PlayerStateMachine.State = _state_machine.current_state
	var moving: bool = velocity.length_squared() > 0.25

	if not is_on_floor() or not moving:
		_footstep_timer = 0.0
		return

	match state:
		PlayerStateMachine.State.PRONE:
			return   # silent crawl
		PlayerStateMachine.State.SWIMMING:
			return

	var interval: float = NOISE_FOOTSTEP_INTERVAL
	if state == PlayerStateMachine.State.RUNNING:
		interval *= 0.65

	_footstep_timer += delta
	if _footstep_timer < interval:
		return
	_footstep_timer = 0.0

	var entry: Array = NOISE_TABLE.get(_current_surface, NOISE_TABLE["default"])
	var level: int = entry[0]
	var radius: float = entry[1]

	if state == PlayerStateMachine.State.RUNNING:
		level = mini(level * 2, 10)
		radius *= 2.0
	elif state == PlayerStateMachine.State.CROUCHING:
		radius *= 0.5
		level = maxi(1, level / 2)

	EventBus.noise_generated.emit(global_position, radius, level)

# ─────────────────────────────────────────────
# Water detection
# ─────────────────────────────────────────────

func _handle_water_detection() -> void:
	pass   ## WaterVolume areas set _in_water via _on_body_entered; see scene.

## Called by WaterVolume Area3D.body_entered signal wired up in the scene.
func enter_water() -> void:
	_in_water = true

## Called by WaterVolume Area3D.body_exited signal wired up in the scene.
func exit_water() -> void:
	_in_water = false

# ─────────────────────────────────────────────
# Collision shape swap (stand ↔ crouch/prone)
# ─────────────────────────────────────────────

func _swap_collision(crouching: bool) -> void:
	if _stand_col:
		_stand_col.disabled = crouching
	if _crouch_col:
		_crouch_col.disabled = not crouching

func _update_camera_mount_height(crouching: bool) -> void:
	if not _camera_mount:
		return
	var state: PlayerStateMachine.State = _state_machine.current_state if _state_machine else PlayerStateMachine.State.IDLE
	var target_y: float
	if state == PlayerStateMachine.State.PRONE:
		target_y = 0.25
	elif crouching:
		target_y = 0.85
	else:
		target_y = 1.6
	_camera_mount.position.y = target_y

# ─────────────────────────────────────────────
# Surface material (called by world/zone systems)
# ─────────────────────────────────────────────

## Notify the controller which surface material the player is standing on.
func set_surface(surface_name: String) -> void:
	_current_surface = surface_name if NOISE_TABLE.has(surface_name) else "default"

# ─────────────────────────────────────────────
# Injury / weight listeners
# ─────────────────────────────────────────────

func _on_injury_applied(location: String, _severity: float) -> void:
	match location:
		"leg", "left_leg", "right_leg":
			_injury_leg = true
		"shoulder", "left_shoulder", "right_shoulder":
			_injury_shoulder = true
		"head":
			_injury_head = true

func _on_injury_treated(location: String) -> void:
	match location:
		"leg", "left_leg", "right_leg":
			_injury_leg = false
		"shoulder", "left_shoulder", "right_shoulder":
			_injury_shoulder = false
		"head":
			_injury_head = false

func _on_weight_changed(new_weight: float, new_max: float) -> void:
	current_weight = new_weight
	max_carry_weight = new_max

# ─────────────────────────────────────────────
# Utilities
# ─────────────────────────────────────────────

func _set_mouse_mode_for_state(state: GameManager.GameState) -> void:
	if state == GameManager.GameState.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Searches children for a node whose script filename matches script_name.
func _find_node_of_script(script_name: String) -> Node:
	for child in get_children():
		if child.get_script() and child.get_script().resource_path.ends_with(script_name):
			return child
	return null

# ─────────────────────────────────────────────
# Public accessors (for camera, HUD, etc.)
# ─────────────────────────────────────────────

## Returns the current stamina percentage 0.0-1.0.
func get_stamina_pct() -> float:
	return stamina / STAMINA_MAX

## Returns true if the player is currently exhausted.
func is_exhausted() -> bool:
	return _stamina_exhausted

## Returns true if the player is submerged in water.
func is_swimming() -> bool:
	return _in_water

## Returns true if the player is overencumbered.
func is_overencumbered() -> bool:
	return _is_overencumbered()

## Returns the current PlayerStateMachine state enum value.
func get_movement_state() -> PlayerStateMachine.State:
	return _state_machine.current_state if _state_machine else PlayerStateMachine.State.IDLE
