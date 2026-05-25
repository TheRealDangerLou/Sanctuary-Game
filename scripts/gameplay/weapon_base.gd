extends Node3D
## WeaponBase: Abstract base class for all weapons.
## Melee and ranged weapons extend this. Never instantiate directly.

# ─────────────────────────────────────────────
# Enums
# ─────────────────────────────────────────────

enum WeaponType { MELEE, RANGED }

# ─────────────────────────────────────────────
# Exported stats (set per weapon resource or scene)
# ─────────────────────────────────────────────

@export var weapon_id: String = "unknown"
@export var weapon_type: WeaponType = WeaponType.MELEE
@export var damage: float = 10.0
@export var range_metres: float = 1.5
## Attacks per second. For ranged this is the semi-auto/full-auto fire rate.
@export var fire_rate: float = 1.0
## 1-10 scale matching EventBus noise_generated contract.
@export var noise_level: int = 1
## Durability starts at max_condition and degrades toward 0.
@export var max_condition: float = 100.0
## How much condition is lost per attack.
@export var condition_drain_per_use: float = 1.0
## Below this threshold the weapon is considered "poor" — applies penalty.
@export var condition_poor_threshold: float = 30.0
## Noise radius in world-space metres when fired/swung.
@export var noise_radius: float = 5.0

# ─────────────────────────────────────────────
# Runtime state
# ─────────────────────────────────────────────

var current_condition: float = 100.0
var is_equipped: bool = false
var is_aiming: bool = false

## Owner node (player or NPC) that holds this weapon.
var wielder: Node3D = null

# Internal fire-rate throttle.
var _attack_cooldown: float = 0.0

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	current_condition = max_condition

func _process(delta: float) -> void:
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta

# ─────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────

## Attempt an attack. Returns true if the attack actually fired (cooldown clear, weapon alive).
func attack() -> bool:
	if not _can_attack():
		return false
	_attack_cooldown = 1.0 / max(fire_rate, 0.01)
	_degrade_condition()
	_emit_noise()
	_do_attack()
	return true

## Equip or unequip this weapon. Shows/hides the mesh.
func set_equipped(equipped: bool) -> void:
	is_equipped = equipped
	visible = equipped

## Toggle aim-down-sights state. Ranged weapons override to adjust camera FOV etc.
func set_aiming(aiming: bool) -> void:
	is_aiming = aiming

## Returns true if the weapon is too degraded to function.
func is_broken() -> bool:
	return current_condition <= 0.0

## Returns condition as 0.0–1.0 fraction.
func get_condition_pct() -> float:
	return current_condition / max_condition

## Returns the effective damage after applying condition penalty.
func get_effective_damage() -> float:
	if current_condition < condition_poor_threshold:
		return damage * 0.6
	return damage

# ─────────────────────────────────────────────
# Protected virtual — override in subclasses
# ─────────────────────────────────────────────

## Subclasses implement the actual hit logic here.
func _do_attack() -> void:
	pass

# ─────────────────────────────────────────────
# Private helpers
# ─────────────────────────────────────────────

func _can_attack() -> bool:
	if is_broken():
		return false
	if _attack_cooldown > 0.0:
		return false
	return true

func _degrade_condition() -> void:
	current_condition = max(0.0, current_condition - condition_drain_per_use)

func _emit_noise() -> void:
	var world_pos: Vector3 = global_position if is_inside_tree() else Vector3.ZERO
	EventBus.noise_generated.emit(world_pos, noise_radius, noise_level)
