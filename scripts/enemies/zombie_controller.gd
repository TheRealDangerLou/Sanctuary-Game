extends CharacterBody3D
class_name ZombieController
## ZombieController: Civilian zombie — shambles toward noise and the living,
## attacks Dad and Rose on contact, dies to any headshot or enough body damage.
## Integrates with NoiseSystem, CombatSystem, CorpseLootSystem via EventBus only.

# ─────────────────────────────────────────────
const MAX_HEALTH: float          = 80.0
const SPEED_SHAMBLE: float       = 1.4    ## m/s — relentless but slow
const SPEED_LUNGE: float         = 2.3    ## m/s — closes fast once within LUNGE_RANGE
const SPEED_WANDER: float        = 0.4    ## m/s — barely-moving idle shuffle
const LUNGE_RANGE: float         = 3.5    ## m — start lunging
const ATTACK_RANGE: float        = 1.5    ## m — melee swipe distance
const ATTACK_DAMAGE_DAD: float   = 15.0
const ATTACK_DAMAGE_ROSE: float  = 12.0   ## 80% of Dad's — Rose is smaller
const ATTACK_COOLDOWN: float     = 2.2    ## s between swipes
const SIGHT_RANGE: float         = 12.0   ## m detection without noise
const NOISE_DETECT_RANGE: float  = 40.0   ## m detection when noise level is high
const NOISE_ALERT_THRESHOLD: float = 2.0  ## noise level that expands detection
const ALERT_PERSIST: float       = 6.0    ## s to stay alerted after losing target
const GRAVITY: float             = 9.8
const MAX_FALL_SPEED: float      = 50.0
const TURN_SPEED: float          = 2.2    ## rad/s — slow, lumbering head-track
const DETECTION_INTERVAL: float  = 0.4   ## s between proximity sweeps
const MOAN_INTERVAL_MIN: float   = 8.0
const MOAN_INTERVAL_MAX: float   = 16.0
const STUMBLE_INTERVAL_MIN: float = 5.0
const STUMBLE_INTERVAL_MAX: float = 12.0
const STUMBLE_FORCE: float       = 1.6
const WANDER_INTERVAL_MIN: float = 4.0   ## s before picking a new idle wander point
const WANDER_INTERVAL_MAX: float = 8.0
const WANDER_RADIUS: float       = 3.0   ## m from spawn position — max wander range
const HIT_FLASH_DURATION: float  = 0.1   ## s the body mesh stays white on hit
## Y-offset above origin where the head begins (capsule h=1.8, head top ~20% of body).
const HEAD_Y_THRESHOLD: float    = 1.3
## Original body tint — must match the material in zombie_civilian.tscn.
const BODY_COLOR_NORMAL: Color   = Color(0.22, 0.28, 0.22, 1.0)
const BODY_COLOR_HIT: Color      = Color(1.0, 1.0, 1.0, 1.0)

enum State { IDLE, ALERTED, CHASING, ATTACKING, DEAD }

# ─────────────────────────────────────────────
var _state: State = State.IDLE
var _health: float = MAX_HEALTH
var _is_dead: bool = false

var _target: Node3D = null
var _player_node: Node3D = null
var _rose_node: Node3D = null

var _attack_timer: float   = 0.0
var _detection_timer: float = 0.0
var _moan_timer: float     = 0.0
var _stumble_timer: float  = 0.0
var _alert_timer: float    = 0.0    ## counts down while ALERTED with no target

var _spawn_pos: Vector3 = Vector3.ZERO
var _wander_timer: float = 0.0
var _wander_target: Vector3 = Vector3.ZERO
var _is_wandering: bool = false

# ─────────────────────────────────────────────
func _ready() -> void:
	add_to_group("zombie")
	set_meta("is_enemy", true)
	_spawn_pos = global_position
	_wander_timer = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
	_moan_timer    = randf_range(MOAN_INTERVAL_MIN, MOAN_INTERVAL_MAX)
	_stumble_timer = randf_range(STUMBLE_INTERVAL_MIN, STUMBLE_INTERVAL_MAX)
	_detection_timer = randf_range(0.0, DETECTION_INTERVAL)  ## stagger sweeps across instances
	EventBus.combat_hit.connect(_on_combat_hit)

func _physics_process(delta: float) -> void:
	if _is_dead or GameManager.current_state != GameManager.GameState.PLAYING:
		return
	_tick_timers(delta)
	_apply_gravity(delta)
	match _state:
		State.IDLE:     _tick_idle(delta)
		State.ALERTED:  _tick_alerted(delta)
		State.CHASING:  _tick_chasing(delta)
		State.ATTACKING: _tick_attacking(delta)
	move_and_slide()

# ─────────────────────────────────────────────
## Called directly by melee and ranged weapons if this node has the method.
## hit_pos is the world-space contact point; used to detect headshots.
func receive_hit(damage: float, hit_location: String, hit_pos: Vector3) -> void:
	if _is_dead:
		return
	var resolved: String = hit_location
	## Any contact point above the shoulder line is treated as a headshot.
	if hit_pos.y > global_position.y + HEAD_Y_THRESHOLD:
		resolved = "head"
	_flash_hit()
	_take_damage(damage, resolved)
	## Getting hit always breaks IDLE and ALERTED — the zombie locks on.
	if _state == State.IDLE or _state == State.ALERTED:
		_find_character_nodes()
		if _player_node or _rose_node:
			_target = _pick_nearest()
		_enter_chasing()

# ─────────────────────────────────────────────
func _tick_idle(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
		var angle: float = randf() * TAU
		var dist: float = randf_range(0.5, WANDER_RADIUS)
		_wander_target = _spawn_pos + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		_is_wandering = true

	if _is_wandering:
		var flat_dist: float = global_position.distance_to(
				Vector3(_wander_target.x, global_position.y, _wander_target.z))
		if flat_dist < 0.25:
			_is_wandering = false
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			_face_target(_wander_target, delta)
			_move_toward(_wander_target, SPEED_WANDER)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

func _tick_alerted(delta: float) -> void:
	_alert_timer -= delta
	if _alert_timer <= 0.0:
		_state = State.IDLE
		return
	## Drift toward last known target position while alert.
	if _target and is_instance_valid(_target):
		_face_target(_target.global_position, delta)
		_move_toward(_target.global_position, SPEED_SHAMBLE * 0.6)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

func _tick_chasing(delta: float) -> void:
	if not _target or not is_instance_valid(_target):
		_alert_timer = ALERT_PERSIST
		_state = State.ALERTED
		return
	var dist: float = global_position.distance_to(_target.global_position)
	if dist <= ATTACK_RANGE:
		_state = State.ATTACKING
		return
	var speed: float = SPEED_LUNGE if dist <= LUNGE_RANGE else SPEED_SHAMBLE
	_face_target(_target.global_position, delta)
	_move_toward(_target.global_position, speed)

func _tick_attacking(delta: float) -> void:
	if not _target or not is_instance_valid(_target):
		_alert_timer = ALERT_PERSIST
		_state = State.ALERTED
		return
	var dist: float = global_position.distance_to(_target.global_position)
	if dist > ATTACK_RANGE * 1.4:
		_state = State.CHASING
		return
	_face_target(_target.global_position, delta)
	velocity.x = 0.0
	velocity.z = 0.0
	if _attack_timer <= 0.0:
		_do_melee_attack()

# ─────────────────────────────────────────────
func _tick_timers(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta

	_detection_timer -= delta
	if _detection_timer <= 0.0:
		_detection_timer = DETECTION_INTERVAL
		_run_detection()

	_moan_timer -= delta
	if _moan_timer <= 0.0:
		_moan_timer = randf_range(MOAN_INTERVAL_MIN, MOAN_INTERVAL_MAX)
		_moan()

	_stumble_timer -= delta
	if _stumble_timer <= 0.0:
		_stumble_timer = randf_range(STUMBLE_INTERVAL_MIN, STUMBLE_INTERVAL_MAX)
		_stumble()

# ─────────────────────────────────────────────
func _run_detection() -> void:
	_find_character_nodes()

	var noise_level: float = 0.0
	if GameManager.noise_system:
		noise_level = GameManager.noise_system.get_noise_level_at(global_position)

	var detect_range: float = NOISE_DETECT_RANGE if noise_level >= NOISE_ALERT_THRESHOLD \
			else SIGHT_RANGE

	var best: Node3D = _pick_nearest_within(detect_range)

	if best:
		_target = best
		if _state == State.IDLE or _state == State.ALERTED:
			_enter_chasing()
	elif _state == State.CHASING or _state == State.ATTACKING:
		_alert_timer = ALERT_PERSIST
		_state = State.ALERTED

func _find_character_nodes() -> void:
	if _player_node == null or not is_instance_valid(_player_node):
		var p: Array = get_tree().get_nodes_in_group("player")
		_player_node = p[0] as Node3D if p.size() > 0 else null
	if _rose_node == null or not is_instance_valid(_rose_node):
		var r: Array = get_tree().get_nodes_in_group("rose")
		_rose_node = r[0] as Node3D if r.size() > 0 else null

func _pick_nearest() -> Node3D:
	return _pick_nearest_within(INF)

func _pick_nearest_within(max_range: float) -> Node3D:
	var best: Node3D = null
	var best_dist: float = max_range
	for candidate: Node3D in [_player_node, _rose_node]:
		if candidate == null or not is_instance_valid(candidate):
			continue
		var d: float = global_position.distance_to(candidate.global_position)
		if d < best_dist:
			best_dist = d
			best = candidate
	return best

# ─────────────────────────────────────────────
func _face_target(target_pos: Vector3, delta: float) -> void:
	var flat: Vector3 = (target_pos - global_position) * Vector3(1, 0, 1)
	if flat.length_squared() < 0.001:
		return
	var target_angle: float = atan2(flat.x, flat.z)
	rotation.y = lerp_angle(rotation.y, target_angle, TURN_SPEED * delta)

func _move_toward(target_pos: Vector3, speed: float) -> void:
	var flat: Vector3 = (target_pos - global_position) * Vector3(1, 0, 1)
	if flat.length_squared() < 0.001:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var dir: Vector3 = flat.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y = maxf(velocity.y - GRAVITY * delta, -MAX_FALL_SPEED)

func _stumble() -> void:
	if _state == State.DEAD:
		return
	var dir := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	velocity.x += dir.x * STUMBLE_FORCE
	velocity.z += dir.z * STUMBLE_FORCE

# ─────────────────────────────────────────────
func _do_melee_attack() -> void:
	if not _target or not is_instance_valid(_target):
		return
	_attack_timer = ATTACK_COOLDOWN
	var is_rose: bool = _target.is_in_group("rose")
	var damage: float  = ATTACK_DAMAGE_ROSE if is_rose else ATTACK_DAMAGE_DAD
	var tid: String    = "rose" if is_rose else "player"
	EventBus.combat_hit.emit(tid, damage, "torso")
	## Short noise burst — the impact sound. Also wakes nearby idle zombies.
	EventBus.noise_generated.emit(global_position, 6.0, 3)

func _moan() -> void:
	## Low atmospheric noise. Level 2, radius 8 m — audible to nearby zombies.
	## Cascading moans create the creeping sense of a growing horde.
	EventBus.noise_generated.emit(global_position, 8.0, 2)

func _enter_chasing() -> void:
	if _state == State.DEAD:
		return
	_is_wandering = false
	_state = State.CHASING
	## Short alert noise — the moment a zombie locks on.
	EventBus.noise_generated.emit(global_position, 6.0, 3)

# ─────────────────────────────────────────────
func _take_damage(damage: float, hit_location: String) -> void:
	if _is_dead:
		return
	## Head = instant kill regardless of damage value.
	if hit_location == "head":
		_die()
		return
	_health -= damage
	if _health <= 0.0:
		_die()

func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	_state = State.DEAD
	velocity = Vector3.ZERO
	EventBus.enemy_killed.emit("zombie", global_position)
	EventBus.ragdoll_triggered.emit(name, Vector3.ZERO)
	Logger.info("ZombieController: '%s' died at %v" % [name, global_position])
	for child: Node in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true
	set_physics_process(false)
	_animate_death()

func _animate_death() -> void:
	var collapse := create_tween()
	collapse.set_parallel(true)
	collapse.tween_property(self, "rotation:z", PI * 0.45, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	collapse.tween_property(self, "global_position:y", global_position.y - 0.3, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	await collapse.finished
	_fade_corpse()

func _fade_corpse() -> void:
	var mesh: MeshInstance3D = get_node_or_null("BodyMesh") as MeshInstance3D
	if not mesh:
		queue_free()
		return
	var mat := mesh.get_active_material(0).duplicate() as StandardMaterial3D
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.set_surface_override_material(0, mat)
	var fade := create_tween()
	fade.tween_property(mat, "albedo_color:a", 0.0, 8.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_LINEAR)
	await fade.finished
	queue_free()

func _flash_hit() -> void:
	var mesh: MeshInstance3D = get_node_or_null("BodyMesh") as MeshInstance3D
	if not mesh:
		return
	var mat := mesh.get_active_material(0).duplicate() as StandardMaterial3D
	mesh.set_surface_override_material(0, mat)
	mat.albedo_color = BODY_COLOR_HIT
	var t := create_tween()
	t.tween_interval(HIT_FLASH_DURATION)
	t.tween_callback(func() -> void:
		mat.albedo_color = BODY_COLOR_NORMAL
	)

# ─────────────────────────────────────────────
## Only processes BLEED ticks — direct weapon hits are handled by receive_hit().
## Non-bleed combat_hit events targeting this zombie are ignored here because the
## weapon already called receive_hit(); acting on both would double-count damage.
func _on_combat_hit(target_id: String, damage: float, hit_location: String) -> void:
	if target_id != name:
		return
	if hit_location != "bleed":
		return
	_take_damage(damage, "torso")
