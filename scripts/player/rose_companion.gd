extends CharacterBody3D
## RoseCompanion: Rose follows Dad at a safe distance.
## Gravity, acceleration, and a FOLLOW_DISTANCE guard keep her close without clipping.
## Finds Dad via the "player" group each frame — tolerates Dad not yet being in the tree.

const FOLLOW_DISTANCE: float = 2.5
const CHASE_SPEED: float = 4.5
const GRAVITY: float = 9.8
const ACCEL: float = 8.0
const DECEL: float = 10.0
const MAX_FALL_SPEED: float = 50.0

var _target: Node3D = null

func _ready() -> void:
	add_to_group("rose")

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL_SPEED)

	if _target == null or not is_instance_valid(_target):
		_target = _find_player()

	var h_vel := Vector2(velocity.x, velocity.z)

	if _target != null and is_instance_valid(_target):
		var flat_self := Vector3(global_position.x, 0.0, global_position.z)
		var flat_target := Vector3(_target.global_position.x, 0.0, _target.global_position.z)
		var dist := flat_self.distance_to(flat_target)
		if dist > FOLLOW_DISTANCE:
			var dir := (flat_target - flat_self).normalized()
			h_vel = h_vel.move_toward(Vector2(dir.x, dir.z) * CHASE_SPEED, ACCEL * delta)
		else:
			h_vel = h_vel.move_toward(Vector2.ZERO, DECEL * delta)
	else:
		h_vel = h_vel.move_toward(Vector2.ZERO, DECEL * delta)

	velocity.x = h_vel.x
	velocity.z = h_vel.y
	move_and_slide()

func _find_player() -> Node3D:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node3D
	return null
