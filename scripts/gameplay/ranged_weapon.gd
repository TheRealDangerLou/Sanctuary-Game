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
	var hit_location: String = _resolve_hit_location(hit_body, hit_pos)

	var base_dmg: float = get_effective_damage()

	# Instakill is checked against BASE weapon damage — a firearm headshot always kills
	# regardless of distance. Falloff does not apply to instant-kill hits.
	var is_ik: bool = HitDetection.is_instakill(base_dmg, hit_location)

	var dist: float = origin.distance_to(hit_pos)
	var falloff: float = clamp(1.0 - (dist / effective_range), 0.0, 1.0)
	# Instakill hits bypass falloff; all others scale linearly with distance.
	var pre_scale_dmg: float = base_dmg if is_ik else base_dmg * falloff

	# Apply per-location damage multiplier (head = 10×, neck = 3.5×, etc.).
	var final_dmg: float = HitDetection.get_scaled_damage(pre_scale_dmg, hit_location)

	var target_id: String = hit_body.name if hit_body else "world"

	EventBus.combat_hit.emit(target_id, final_dmg, hit_location)
	EventBus.blood_impact.emit(hit_pos, hit_normal)

	# Bleed is probabilistic — rolls against HitDetection.BLEED_CHANCE table.
	if HitDetection.rolls_bleed(hit_location):
		EventBus.bleed_started.emit(target_id, bleed_rate)

	# Friendly fire: notify narrative systems so moral alignment can react.
	if hit_body and hit_body.has_meta("is_friendly") and hit_body.get_meta("is_friendly"):
		EventBus.narrative_event_triggered.emit("friendly_fire_" + target_id)

	if hit_body and hit_body.has_method("receive_hit"):
		hit_body.receive_hit(final_dmg, hit_location, hit_pos)

func _resolve_hit_location(body: Object, _hit_pos: Vector3) -> String:
	if body == null:
		return "world"
	if body.has_meta("hit_location"):
		return HitDetection.resolve_area_location(body.get_meta("hit_location"))
	return "torso"

func _spawn_muzzle_flash() -> void:
	if muzzle_flash_scene == null or _muzzle_point == null:
		return
	var flash: Node3D = muzzle_flash_scene.instantiate() as Node3D
	_muzzle_point.add_child(flash)
