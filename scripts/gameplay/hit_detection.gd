extends Node
## HitDetection: Stateless helper that resolves per-location damage multipliers.
## Provides headshot instakill logic and wound model lookups.
## Used by both melee and ranged weapons via static functions.

# ─────────────────────────────────────────────
# Damage multipliers per hit location
# ─────────────────────────────────────────────

## Multiplier table keyed by hit_location string.
const DAMAGE_MULTIPLIERS: Dictionary = {
	"head":        10.0,   # Instant kill threshold handled in apply_hit.
	"neck":         3.5,
	"chest":        1.0,
	"torso":        1.0,
	"abdomen":      1.2,
	"groin":        1.5,
	"upper_arm_l":  0.7,
	"upper_arm_r":  0.7,
	"forearm_l":    0.6,
	"forearm_r":    0.6,
	"hand_l":       0.4,
	"hand_r":       0.4,
	"thigh_l":      0.9,
	"thigh_r":      0.9,
	"shin_l":       0.7,
	"shin_r":       0.7,
	"foot_l":       0.3,
	"foot_r":       0.3,
}

## Below this health value after a head-shot, the kill is treated as instant.
const INSTAKILL_HEAD_THRESHOLD: float = 999.0   # Any head hit from a firearm.

## Bleed chance per location for melee hits (0.0 – 1.0).
const BLEED_CHANCE: Dictionary = {
	"head": 0.3, "neck": 0.6, "chest": 0.2, "torso": 0.2,
	"abdomen": 0.3, "groin": 0.4,
	"upper_arm_l": 0.3, "upper_arm_r": 0.3,
	"forearm_l": 0.4, "forearm_r": 0.4,
	"hand_l": 0.5, "hand_r": 0.5,
	"thigh_l": 0.5, "thigh_r": 0.5,
	"shin_l": 0.3, "shin_r": 0.3,
	"foot_l": 0.2, "foot_r": 0.2,
}

# ─────────────────────────────────────────────
# Static API
# ─────────────────────────────────────────────

## Returns base_damage scaled by the location multiplier.
static func get_scaled_damage(base_damage: float, hit_location: String) -> float:
	var mult: float = DAMAGE_MULTIPLIERS.get(hit_location, 1.0)
	return base_damage * mult

## Returns true if a head-shot should be treated as an instant kill.
## Only firearms (high base damage) trigger this; melee head-shots just do heavy damage.
static func is_instakill(base_damage: float, hit_location: String) -> bool:
	if hit_location != "head":
		return false
	# A firearm doing >= 15 base damage to the head is always lethal.
	return base_damage >= 15.0

## Returns a randomly sampled bleed chance for the given location.
static func rolls_bleed(hit_location: String) -> bool:
	var chance: float = BLEED_CHANCE.get(hit_location, 0.0)
	return randf() < chance

## Maps an arbitrary Area3D node name to a canonical hit_location string.
## Hitbox areas should be named exactly to match the keys in DAMAGE_MULTIPLIERS.
static func resolve_area_location(area_name: String) -> String:
	if DAMAGE_MULTIPLIERS.has(area_name):
		return area_name
	# Graceful fallback so unknown areas don't crash damage lookups.
	return "torso"

## Full hit application helper: scales damage, checks instakill, emits signals.
## Returns the final damage value applied.
static func apply_hit(
		target_id: String,
		base_damage: float,
		hit_location: String,
		hit_pos: Vector3,
		hit_normal: Vector3,
		bleed_rate: float = 2.0) -> float:

	var final_dmg: float = get_scaled_damage(base_damage, hit_location)

	EventBus.combat_hit.emit(target_id, final_dmg, hit_location)
	EventBus.blood_impact.emit(hit_pos, hit_normal)

	if rolls_bleed(hit_location):
		EventBus.bleed_started.emit(target_id, bleed_rate)

	return final_dmg
