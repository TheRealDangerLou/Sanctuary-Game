extends Node
## PlayerCamera: Manages first-person and third-person cameras, mouse/stick look,
## camera bob, FOV shift, and crouch tilt.
## Attach as a child of the player's camera mount Node3D.
## This node never touches other systems directly — output goes through EventBus
## only when camera state is meaningful to others (currently none needed).

# ─────────────────────────────────────────────
# Tunables (exposed for Settings screen)
# ─────────────────────────────────────────────

@export var mouse_sensitivity: float    = 0.2
@export var controller_sensitivity: float = 2.5

@export var fov_default: float          = 75.0
@export var fov_running: float          = 82.0
@export var fov_transition_speed: float = 8.0

@export var bob_intensity_walk: float   = 0.015
@export var bob_intensity_run: float    = 0.03
@export var bob_speed_walk: float       = 1.8
@export var bob_speed_run: float        = 2.8

@export var third_person_distance: float = 3.0
@export var third_person_height: float   = 1.0

# ─────────────────────────────────────────────
# Node paths
# ─────────────────────────────────────────────

@export var fp_camera_path: NodePath
@export var tp_arm_path: NodePath    ## SpringArm3D for third-person
@export var tp_camera_path: NodePath

# ─────────────────────────────────────────────
# Internal state
# ─────────────────────────────────────────────

var _fp_camera: Camera3D = null
var _tp_arm: SpringArm3D = null
var _tp_camera: Camera3D = null

var _is_third_person: bool = false

## Accumulated yaw (horizontal) on the camera mount parent.
var _yaw: float = 0.0
## Accumulated pitch (vertical) on the FP camera itself.
var _pitch: float = 0.0

var _bob_time: float = 0.0
var _bob_offset: float = 0.0

var _player: CharacterBody3D = null
var _input: Node = null

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	_fp_camera = get_node_or_null(fp_camera_path) as Camera3D
	_tp_arm    = get_node_or_null(tp_arm_path) as SpringArm3D
	_tp_camera = get_node_or_null(tp_camera_path) as Camera3D

	# Walk up to find CharacterBody3D owner.
	var n: Node = get_parent()
	while n:
		if n is CharacterBody3D:
			_player = n as CharacterBody3D
			break
		n = n.get_parent()

	if _player:
		_input = _find_sibling_of_script("player_input.gd")

	_apply_camera_mode()

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	_handle_camera_toggle()
	_handle_look(delta)
	_handle_fov(delta)
	_handle_bob(delta)

# ─────────────────────────────────────────────
# Camera mode toggle
# ─────────────────────────────────────────────

func _handle_camera_toggle() -> void:
	if not _input:
		return
	if _input.want_camera_toggle:
		_is_third_person = not _is_third_person
		_apply_camera_mode()

func _apply_camera_mode() -> void:
	if _fp_camera:
		_fp_camera.current = not _is_third_person
	if _tp_camera:
		_tp_camera.current = _is_third_person
	if _tp_arm:
		_tp_arm.spring_length = third_person_distance
		_tp_arm.position.y = third_person_height

# ─────────────────────────────────────────────
# Look (mouse + right stick)
# ─────────────────────────────────────────────

func _handle_look(delta: float) -> void:
	if not _input:
		return

	var look_delta: Vector2 = Vector2.ZERO

	# Mouse (captured mode).
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_delta += _input.mouse_delta * mouse_sensitivity * 0.01

	# Right stick (normalised axis, scaled by sensitivity and delta).
	look_delta += _input.stick_look * controller_sensitivity * delta

	_yaw   -= look_delta.x
	_pitch -= look_delta.y
	_pitch = clampf(_pitch, deg_to_rad(-80.0), deg_to_rad(80.0))

	# Yaw rotates the camera mount (parent of this node).
	get_parent().rotation.y = _yaw

	# Pitch rotates only the FP camera / spring arm.
	if not _is_third_person and _fp_camera:
		_fp_camera.rotation.x = _pitch
	if _tp_arm:
		_tp_arm.rotation.x = _pitch

# ─────────────────────────────────────────────
# FOV shift
# ─────────────────────────────────────────────

func _handle_fov(delta: float) -> void:
	if not _fp_camera or not _player:
		return

	var running: bool = false
	if _player.has_method("get_movement_state"):
		var st = _player.get_movement_state()
		# Avoid importing the script constant; compare by value index.
		running = (st == 2)   # State.RUNNING = 2

	var target_fov: float = fov_running if running else fov_default
	_fp_camera.fov = move_toward(_fp_camera.fov, target_fov, fov_transition_speed * delta)
	if _tp_camera:
		_tp_camera.fov = _fp_camera.fov

# ─────────────────────────────────────────────
# Camera bob
# ─────────────────────────────────────────────

func _handle_bob(delta: float) -> void:
	if _is_third_person or not _fp_camera or not _player:
		return

	var on_floor: bool = _player.is_on_floor()
	var speed_sq: float = (_player.velocity.x ** 2 + _player.velocity.z ** 2)
	var moving: bool = speed_sq > 0.25 and on_floor

	var intensity: float
	var bob_speed: float

	if moving:
		var running: bool = false
		if _player.has_method("get_movement_state"):
			running = (_player.get_movement_state() == 2)
		intensity  = bob_intensity_run if running else bob_intensity_walk
		bob_speed  = bob_speed_run if running else bob_speed_walk
		_bob_time += delta * bob_speed
	else:
		intensity  = 0.0
		_bob_time  = 0.0

	var target_bob: float = sin(_bob_time * PI) * intensity
	_bob_offset = lerp(_bob_offset, target_bob, 10.0 * delta)
	_fp_camera.position.y = _bob_offset

# ─────────────────────────────────────────────
# Utility
# ─────────────────────────────────────────────

func _find_sibling_of_script(script_name: String) -> Node:
	if not get_parent():
		return null
	for child in get_parent().get_children():
		if child == self:
			continue
		if child.get_script() and child.get_script().resource_path.ends_with(script_name):
			return child
	return null

## Injects yaw directly (used by scene setup or cutscene system).
func set_yaw(yaw_radians: float) -> void:
	_yaw = yaw_radians
	get_parent().rotation.y = _yaw

## Returns whether third-person mode is active.
func is_third_person() -> bool:
	return _is_third_person
