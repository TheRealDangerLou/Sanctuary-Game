extends "res://scripts/gameplay/weapon_base.gd"
## RangedWeapon: Raycast-based hit detection with full ballistics model.
## Handles magazine/ammo management, reload sequence, and ADS camera notification.

# ─────────────────────────────────────────────
# Exports
# ─────────────────────────────────────────────

@export var magazine_capacity: int = 10
@export var reload_time: float = 2.0
## True → full-auto: attack() fires every frame while held. False → one shot per press.
@export var is_automatic: bool = false
## ADS FOV reduction in degrees (applied by PlayerCamera on set_aiming(true)).
@export var ads_fov_offset: float = -15.0
## Muzzle flash VFX scene (optional, instanced on fire).
@export var muzzle_flash_scene: PackedScene = null
## Maximum effective range in metres; beyond this damage falls off to 0.
@export var effective_range: float = 50.0

# ─────────────────────────────────────────────
# Ammo tracking
# ─────────────────────────────────────────────

var current_ammo: int = 0
var is_reloading: bool = false

# ─────────────────────────────────────────────
# Node refs
# ─────────────────────────────────────────────

var _muzzle_point: Node3D = null
var _anim: AnimationPlayer = null

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	super._ready()
	weapon_type = WeaponType.RANGED
	current_ammo = magazine_capacity
	_muzzle_point = get_node_or_null("MuzzlePoint")
	_anim = get_node_or_null("AnimationPlayer")

# ─────────────────────────────────────────────
# Override
# ─────────────────────────────────────────────

## Ranged weapons gate on ammo and reload state.
func attack() -> bool:
	if is_reloading:
		return false
	if current_ammo <= 0:
		start_reload()
		return false
	return super.attack()

func _do_attack() -> void:
	current_ammo -= 1
	_spawn_muzzle_flash()
	EventBus.weapon_fired.emit(weapon_id, global_position, noise_level)
	_cast_ray()

func set_aiming(aiming: bool) -> void:
	super.set_aiming(aiming)
	# Future: notify PlayerCamera via signal when camera system is wired up.

# ─────────────────────────────────────────────
# Public
# ─────────────────────────────────────────────

## Triggers reload sequence. Emits weapon_reloading signal then restores ammo.
func start_reload() -> void:
	if is_reloading:
		return
	if current_ammo >= magazine_capacity:
		return
	is_reloading = true
	EventBus.weapon_reloading.emit(weapon_id)
	if _anim and _anim.has_animation("reload"):
		_anim.play("reload")
	await get_tree().create_timer(reload_time).timeout
	current_ammo = magazine_capacity
	is_reloading = false

## Returns ammo as a tuple-style array [current, max].
func get_ammo_state() -> Array:
	return [current_ammo, magazine_capacity]

# ─────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────

func _cast_ray() -> void:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin: Vector3 = global_position if not _muzzle_point else _muzzle_point.global_position
	# Use the camera's forward direction if wielder provides it, else weapon forward.
	var forward: Vector3 = -global_transform.basis.z
	if wielder and wielder.has_method("get_aim_direction"):
		forward = wielder.get_aim_direction()
	var end: Vector3 = origin + forward * effective_range

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [self] if wielder == null else [wielder, self]
	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty():
		return

	var hit_pos: Vector3 = result["position"]
	var hit_normal: Vector3 = result["normal"]
	var hit_body: Object = result["collider"]

	# Distance fall-off — linear from full damage at 0 to 0 at effective_range.
	var dist: float = origin.distance_to(hit_pos)
	var falloff: float = clamp(1.0 - (dist / effective_range), 0.0, 1.0)
	var effective_dmg: float = get_effective_damage() * falloff

	var target_id: String = hit_body.name if hit_body else "world"
	var hit_location: String = _resolve_hit_location(hit_body, hit_pos)

	EventBus.combat_hit.emit(target_id, effective_dmg, hit_location)
	EventBus.blood_impact.emit(hit_pos, hit_normal)

	if hit_body and hit_body.has_method("receive_hit"):
		hit_body.receive_hit(effective_dmg, hit_location, hit_pos)

func _resolve_hit_location(body: Object, _hit_pos: Vector3) -> String:
	# If the hit body has named hitbox areas we can query, use them.
	# Fallback to generic "torso" for now; HitDetection refines this.
	if body == null:
		return "world"
	if body.has_meta("hit_location"):
		return body.get_meta("hit_location")
	return "torso"

func _spawn_muzzle_flash() -> void:
	if muzzle_flash_scene == null or _muzzle_point == null:
		return
	var flash: Node3D = muzzle_flash_scene.instantiate() as Node3D
	_muzzle_point.add_child(flash)
	# Flash destroys itself via its own timer.
