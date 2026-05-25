extends Node
class_name InjurySystem
## InjurySystem: Per-limb wound tracking for Dad and Rose.
## Dad's locations use bare names ("head", "torso", …).
## Rose's locations are prefixed with "rose_" ("rose_head", "rose_torso", …).
## Injuries affect movement speed, aim accuracy, and can cause bleeding or infection.

# ─────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────

## Severity threshold above which a fresh hit is considered bleeding.
const BLEED_SEVERITY_THRESHOLD: float = 0.4
## Bleed rate emitted (HP/s) = severity × this multiplier.
const BLEED_RATE_MULTIPLIER: float = 2.0
## Minimum damage-to-severity ratio (damage / 50 = severity, clamped 0–1).
const DAMAGE_TO_SEVERITY_DIVISOR: float = 50.0
## Minimum damage that creates an injury (below this, just a scratch).
const INJURY_MIN_DAMAGE: float = 10.0
## Chance per second that an untreated severe wound (severity ≥ 0.5) becomes infected.
const INFECTION_CHANCE_PER_SECOND: float = 0.0001
## How much a single treatment reduces wound severity.
const TREATMENT_SEVERITY_REDUCTION: float = 0.6

## Max movement penalty at severity 1.0 (leg/foot injuries).
const MAX_MOVEMENT_PENALTY: float = 0.40
## Max aim penalty at severity 1.0 (arm/hand injuries).
const MAX_AIM_PENALTY: float = 0.50

const LEG_LOCATIONS: Array[String] = ["thigh_l", "thigh_r", "leg_l", "leg_r", "foot_l", "foot_r"]
const ARM_LOCATIONS: Array[String] = ["arm_l", "arm_r", "hand_l", "hand_r"]

const VALID_BASE_LOCATIONS: Array[String] = [
	"head", "neck", "torso",
	"arm_l", "arm_r", "hand_l", "hand_r",
	"thigh_l", "thigh_r", "leg_l", "leg_r", "foot_l", "foot_r",
]

# ─────────────────────────────────────────────
# State
# ─────────────────────────────────────────────

## Per-location wound data: location → { severity, is_bleeding, is_infected }
var _injuries: Dictionary = {}

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	GameManager.injury_system = self
	EventBus.combat_hit.connect(_on_combat_hit)

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	_tick_infection_risk(delta)

# ─────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────

## Apply an injury to a body location. severity is 0.0–1.0.
## Emits injury_applied and, if severe enough, bleed_started.
func apply_injury(location: String, severity: float) -> void:
	if not _is_valid_location(location):
		return
	var clamped: float = clampf(severity, 0.0, 1.0)
	var existing: float = _injuries.get(location, {}).get("severity", 0.0)
	var new_severity: float = minf(1.0, maxf(existing, clamped))
	_injuries[location] = {
		"severity": new_severity,
		"is_bleeding": new_severity >= BLEED_SEVERITY_THRESHOLD,
		"is_infected": _injuries.get(location, {}).get("is_infected", false),
	}
	EventBus.injury_applied.emit(location, new_severity)
	if _injuries[location]["is_bleeding"]:
		EventBus.bleed_started.emit(_target_from_location(location), new_severity * BLEED_RATE_MULTIPLIER)

## Treat an injury, reducing its severity and clearing bleed/infection.
## One treatment does not fully heal a severe wound — repeat application may be needed.
## Emits injury_treated.
func treat_injury(location: String) -> void:
	if not _injuries.has(location):
		return
	var data: Dictionary = _injuries[location]
	data["severity"] = maxf(0.0, data["severity"] - TREATMENT_SEVERITY_REDUCTION)
	data["is_bleeding"] = false
	data["is_infected"] = false
	if data["severity"] <= 0.0:
		_injuries.erase(location)
	EventBus.injury_treated.emit(location)

## Returns the current severity at a location (0.0 if uninjured).
func get_severity(location: String) -> float:
	return _injuries.get(location, {}).get("severity", 0.0)

## Returns true if any active injury exists at the given location.
func is_injured(location: String) -> bool:
	return _injuries.has(location)

## Returns true if the injury at the given location is currently infected.
func is_infected(location: String) -> bool:
	return _injuries.get(location, {}).get("is_infected", false)

## Returns a 0.6–1.0 movement speed multiplier driven by leg and foot injuries.
func get_movement_penalty() -> float:
	var worst: float = 0.0
	for loc: String in LEG_LOCATIONS:
		worst = maxf(worst, get_severity(loc))
		worst = maxf(worst, get_severity("rose_" + loc))
	return 1.0 - (worst * MAX_MOVEMENT_PENALTY)

## Returns a 0.5–1.0 aim accuracy multiplier driven by arm and hand injuries.
func get_aim_penalty() -> float:
	var worst: float = 0.0
	for loc: String in ARM_LOCATIONS:
		worst = maxf(worst, get_severity(loc))
	return 1.0 - (worst * MAX_AIM_PENALTY)

## Returns a copy of all active injury entries.
func get_all_injuries() -> Dictionary:
	return _injuries.duplicate(true)

## Returns true if any location on Dad or Rose is currently infected.
func has_any_infection() -> bool:
	for data: Dictionary in _injuries.values():
		if data.get("is_infected", false):
			return true
	return false

# ─────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────

func _tick_infection_risk(delta: float) -> void:
	for location: String in _injuries.keys():
		var data: Dictionary = _injuries[location]
		if data.get("is_infected", false) or data.get("severity", 0.0) < 0.5:
			continue
		if randf() < INFECTION_CHANCE_PER_SECOND * delta:
			data["is_infected"] = true
			EventBus.infection_started.emit()

func _is_valid_location(location: String) -> bool:
	var base: String = location.trim_prefix("rose_")
	return VALID_BASE_LOCATIONS.has(base)

func _target_from_location(location: String) -> String:
	return "rose" if location.begins_with("rose_") else "player"

func _on_combat_hit(target_id: String, damage: float, hit_location: String) -> void:
	## Bleed-tick hits ("bleed") never create new injuries — only weapon impacts do.
	if hit_location == "bleed":
		return
	if target_id != "player" and target_id != "rose":
		return
	if damage < INJURY_MIN_DAMAGE:
		return
	var location: String = hit_location if target_id == "player" else "rose_" + hit_location
	var severity: float = clampf(damage / DAMAGE_TO_SEVERITY_DIVISOR, 0.0, 1.0)
	apply_injury(location, severity)
