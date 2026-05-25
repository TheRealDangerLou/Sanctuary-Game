extends "res://scripts/gameplay/weapon_base.gd"
## MeleeWeapon: Handles close-quarters hit detection via an Area3D hitbox.
## The hitbox shape is activated for one physics frame during the swing window.

# ─────────────────────────────────────────────
# Exports
# ─────────────────────────────────────────────

## Knockback impulse applied to the struck body.
@export var knockback_force: float = 3.0
## If true, a successful hit rolls bleed_chance against HitDetection.BLEED_CHANCE table.
@export var can_cause_bleed: bool = false
## Default hit location used when the struck body has no hit_location metadata.
## bleed_rate is inherited from weapon_base.gd.
@export var default_hit_location: String = "torso"

# ─────────────────────────────────────────────
# Node references (set up in scene)
# ─────────────────────────────────────────────

## Area3D that represents the swing arc.
var _hitbox: Area3D = null
var _anim: AnimationPlayer = null

# Track bodies already hit in this swing to prevent multi-hit.
var _hit_this_swing: Array[Node] = []

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	super._ready()
	weapon_type = WeaponType.MELEE
	_hitbox = get_node_or_null("Hitbox")
	_anim = get_node_or_null("AnimationPlayer")
	if _hitbox:
		_hitbox.body_entered.connect(_on_hitbox_body_entered)
		_hitbox.monitoring = false

# ─────────────────────────────────────────────
# Override
# ─────────────────────────────────────────────

func _do_attack() -> void:
	_hit_this_swing.clear()
	if _anim and _anim.has_animation("swing"):
		_anim.play("swing")
	if _hitbox:
		_hitbox.monitoring = true
		await get_tree().physics_frame
		await get_tree().physics_frame
		_hitbox.monitoring = false

# ─────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────

func _on_hitbox_body_entered(body: Node) -> void:
	if _hit_this_swing.has(body):
		return
	if body == wielder:
		return
	_hit_this_swing.append(body)

	var target_id: String = body.name
	var hit_location: String = _resolve_hit_location(body)
	# Apply per-location damage multiplier (head = 10×, neck = 3.5×, etc.).
	var final_dmg: float = HitDetection.get_scaled_damage(get_effective_damage(), hit_location)

	EventBus.combat_hit.emit(target_id, final_dmg, hit_location)
	EventBus.blood_impact.emit(body.global_position, Vector3.UP)

	# Bleed is probabilistic — rolls against HitDetection.BLEED_CHANCE table.
	if can_cause_bleed and HitDetection.rolls_bleed(hit_location):
		EventBus.bleed_started.emit(target_id, bleed_rate)

	# Friendly fire: notify narrative systems so moral alignment can react.
	if body.has_meta("is_friendly") and body.get_meta("is_friendly"):
		EventBus.narrative_event_triggered.emit("friendly_fire_" + target_id)

	# Physics response — all damage goes through EventBus; receive_hit is supplementary
	# so the struck node can play a reaction animation or apply knockback locally.
	if body is RigidBody3D:
		var dir: Vector3 = (body.global_position - global_position).normalized()
		body.apply_central_impulse(dir * knockback_force)
	elif body.has_method("receive_hit"):
		body.receive_hit(final_dmg, hit_location, global_position)

## Resolve hit location from body metadata, falling back to default_hit_location.
## NPCs tag their hitbox Area3D children with set_meta("hit_location", "head") etc.
func _resolve_hit_location(body: Node) -> String:
	if body.has_meta("hit_location"):
		return HitDetection.resolve_area_location(body.get_meta("hit_location"))
	return default_hit_location
