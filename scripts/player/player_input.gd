extends Node
## PlayerInput: Reads the Godot Input Map each frame and exposes a clean struct
## of booleans and vectors to PlayerController and PlayerCamera.
## All action names match project.godot input map exactly.
## No raw key checks — controller and keyboard are transparent to callers.

# ─────────────────────────────────────────────
# Movement
# ─────────────────────────────────────────────

## Normalised 2-D movement direction from WASD or left stick. Never exceeds length 1.
var move_direction: Vector2 = Vector2.ZERO

var want_run: bool = false       ## Sprint held.
var want_crouch: bool = false    ## Crouch held.
var want_prone: bool = false     ## Prone held (toggle on release).
var want_jump: bool = false      ## Jump pressed this frame.

# ─────────────────────────────────────────────
# Camera
# ─────────────────────────────────────────────

## Raw look delta from mouse movement this frame (pixels, unscaled).
var mouse_delta: Vector2 = Vector2.ZERO
## Normalised right-stick axis reading for controller look.
var stick_look: Vector2 = Vector2.ZERO
## True the frame the camera-mode toggle is pressed.
var want_camera_toggle: bool = false

# ─────────────────────────────────────────────
# Interaction
# ─────────────────────────────────────────────

var want_interact: bool = false       ## Pressed this frame.
var want_interact_held: bool = false  ## Held for hold-interact.

# ─────────────────────────────────────────────
# Combat
# ─────────────────────────────────────────────

var want_attack_primary: bool = false    ## Pressed this frame (or held for auto).
var want_attack_secondary: bool = false
var want_reload: bool = false
var want_aim: bool = false               ## Held.

# ─────────────────────────────────────────────
# Inventory & hotbar
# ─────────────────────────────────────────────

var want_inventory_open: bool = false
var want_item_use: bool = false
var hotbar_slot: int = -1   ## 1-8, or -1 if no slot pressed. Delta cycle handled by controller.
var hotbar_next: bool = false
var hotbar_prev: bool = false
var want_drop_item: bool = false

# ─────────────────────────────────────────────
# Building
# ─────────────────────────────────────────────

var want_build_menu: bool = false
var build_rotate_cw: bool = false
var build_rotate_ccw: bool = false

# ─────────────────────────────────────────────
# Game
# ─────────────────────────────────────────────

var want_pause: bool = false
var want_map: bool = false
var want_journal: bool = false

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_delta += event.relative

func _process(_delta: float) -> void:
	_read_movement()
	_read_camera()
	_read_interaction()
	_read_combat()
	_read_inventory()
	_read_building()
	_read_game()

## Call once per frame after all reads, from PlayerController, to clear per-frame fields.
func consume_frame() -> void:
	mouse_delta = Vector2.ZERO
	want_jump = false
	want_camera_toggle = false
	want_interact = false
	want_attack_primary = false
	want_attack_secondary = false
	want_reload = false
	want_inventory_open = false
	want_item_use = false
	hotbar_next = false
	hotbar_prev = false
	hotbar_slot = -1
	want_drop_item = false
	want_build_menu = false
	build_rotate_cw = false
	build_rotate_ccw = false
	want_pause = false
	want_map = false
	want_journal = false
	want_prone = false

# ─────────────────────────────────────────────
# Private readers
# ─────────────────────────────────────────────

func _read_movement() -> void:
	var raw: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_backward")
	)
	# Clamp to unit circle so diagonal is not faster than cardinal.
	move_direction = raw if raw.length() <= 1.0 else raw.normalized()

	want_run = Input.is_action_pressed("sprint")
	want_crouch = Input.is_action_pressed("crouch")
	want_jump = Input.is_action_just_pressed("jump")
	# Prone uses a separate action; toggle is managed by controller.
	if Input.is_action_just_pressed("prone"):
		want_prone = true

func _read_camera() -> void:
	# Stick look uses raw axis values; sensitivity applied in PlayerCamera.
	stick_look = Vector2(
		Input.get_axis("look_left", "look_right"),
		Input.get_axis("look_up", "look_down")
	)
	if Input.is_action_just_pressed("camera_toggle"):
		want_camera_toggle = true

func _read_interaction() -> void:
	want_interact = Input.is_action_just_pressed("interact")
	want_interact_held = Input.is_action_pressed("interact")

func _read_combat() -> void:
	want_attack_primary = Input.is_action_pressed("primary_attack")
	want_attack_secondary = Input.is_action_pressed("aim")
	want_reload = Input.is_action_just_pressed("reload")
	want_aim = Input.is_action_pressed("aim")

func _read_inventory() -> void:
	want_inventory_open = Input.is_action_just_pressed("open_inventory")
	want_item_use = Input.is_action_just_pressed("use_item")
	want_drop_item = Input.is_action_just_pressed("drop_item")
	hotbar_next = Input.is_action_just_pressed("hotbar_next")
	hotbar_prev = Input.is_action_just_pressed("hotbar_prev")
	hotbar_slot = -1
	for i: int in range(1, 9):
		if Input.is_action_just_pressed("hotbar_%d" % i):
			hotbar_slot = i
			break

func _read_building() -> void:
	want_build_menu = Input.is_action_just_pressed("build_menu")
	build_rotate_cw = Input.is_action_just_pressed("build_rotate_cw")
	build_rotate_ccw = Input.is_action_just_pressed("build_rotate_ccw")

func _read_game() -> void:
	want_pause = Input.is_action_just_pressed("pause")
	want_map = Input.is_action_just_pressed("open_map")
	want_journal = Input.is_action_just_pressed("open_journal")
