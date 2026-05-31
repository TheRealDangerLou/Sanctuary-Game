extends Node
## CameraShake: Applies a brief translational shake to the main Camera3D when the
## player takes damage. Connects exclusively through EventBus — no direct node
## references to player or damage systems. Finds the camera via the "main_camera" group.

const SHAKE_DURATION: float  = 0.3    ## s total shake window
const SHAKE_FREQUENCY: float = 20.0   ## Hz — ticks per second
const SHAKE_MAX_X: float     = 0.05   ## m max horizontal offset
const SHAKE_MAX_Y: float     = 0.03   ## m max vertical offset

var _camera: Camera3D = null
var _shake_remaining: float = 0.0
var _tick_timer: float = 0.0
var _origin_offset: Vector3 = Vector3.ZERO
var _current_offset: Vector3 = Vector3.ZERO

func _ready() -> void:
	EventBus.player_hit.connect(_on_player_hit)

func _process(delta: float) -> void:
	if _shake_remaining <= 0.0:
		return
	_ensure_camera()
	if not _camera:
		return
	_shake_remaining -= delta
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = 1.0 / SHAKE_FREQUENCY
		var offset := Vector3(
			randf_range(-SHAKE_MAX_X, SHAKE_MAX_X),
			randf_range(-SHAKE_MAX_Y, SHAKE_MAX_Y),
			0.0
		)
		_camera.position -= _current_offset
		_camera.position += offset
		_current_offset = offset
	if _shake_remaining <= 0.0:
		_camera.position -= _current_offset
		_current_offset = Vector3.ZERO

func _ensure_camera() -> void:
	if _camera and is_instance_valid(_camera):
		return
	var cameras: Array = get_tree().get_nodes_in_group("main_camera")
	if cameras.size() > 0:
		_camera = cameras[0] as Camera3D

func _on_player_hit(_damage: float, _hit_location: String) -> void:
	_ensure_camera()
	if not _camera:
		return
	if _shake_remaining > 0.0:
		_camera.position -= _current_offset
		_current_offset = Vector3.ZERO
	_shake_remaining = SHAKE_DURATION
	_tick_timer = 0.0
