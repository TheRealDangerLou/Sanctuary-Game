extends "res://scripts/gameplay/weapon_base.gd"
## MeleeWeapon: Handles close-quarters hit detection via an Area3D hitbox.
## The hitbox shape is activated for one physics frame during the swing window.

# ─────────────────────────────────────────────
# Exports
# ─────────────────────────────────────────────

## Knockback impulse applied to the struck body.
@export var knockback_force: float = 3.0
## If true, a successful hit can trigger a bleed on the target.
@export var can_cause_bleed: bool = false
@export var bleed_rate: float = 2.0
## Hit_location override for all swings of this weapon (e.g. "torso" for bat).
@export var default_hit_location: String = "torso"

# ─────────────────────────────────────────────
# Node references (set up in scene)
# ─────────────────────────────────────────────

## Area3D that represents the swing arc. Assigned in _ready via get_node.
var _hitbox: Area3D = null
## Animation player for swing animation.
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
	# Enable hitbox for one frame; _process will disable it after the swing window.
	if _hitbox:
		_hitbox.monitoring = true
		# Give it two physics frames then close.
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
	var effective_dmg: float = get_effective_damage()

	EventBus.combat_hit.emit(target_id, effective_dmg, default_hit_location)
	EventBus.blood_impact.emit(body.global_position, Vector3.UP)

	if can_cause_bleed:
		EventBus.bleed_started.emit(target_id, bleed_rate)

	# Apply physics impulse if the body supports it.
	if body is RigidBody3D:
		var dir: Vector3 = (body.global_position - global_position).normalized()
		body.apply_central_impulse(dir * knockback_force)
	elif body.has_method("receive_hit"):
		body.receive_hit(effective_dmg, default_hit_location, global_position)
