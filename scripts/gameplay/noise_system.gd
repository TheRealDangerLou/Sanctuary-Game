extends Node
class_name NoiseSystem
## NoiseSystem: Tracks discrete noise events, accumulates global threat, and
## triggers horde / siege responses when thresholds are exceeded.
##
## All systems emit noise via emit_noise() or EventBus.noise_generated directly.
## Enemy AI queries get_noise_level_at() each frame to detect disturbances.
## NoiseSystem never references other node types — EventBus only.

# ─────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────

## Global threat units shed per real-world second during quiet periods.
const THREAT_DECAY_RATE: float = 3.0

## Accumulated threat that triggers a zombie horde response.
const HORDE_THREAT_THRESHOLD: float = 80.0

## Accumulated threat that triggers a full compound siege event.
const SIEGE_THREAT_THRESHOLD: float = 150.0

## Minimum real-world seconds between horde triggers.
const HORDE_COOLDOWN: float = 120.0

## Minimum real-world seconds between siege triggers (also the siege duration).
const SIEGE_COOLDOWN: float = 300.0

## Seconds a noise event remains eligible for positional queries by AI.
const EVENT_LIFETIME: float = 30.0

## Hard cap on simultaneous tracked events. Oldest is dropped when exceeded.
const MAX_NOISE_EVENTS: int = 64

## Global threat below this value is considered silent for stealth purposes.
const SILENCE_THRESHOLD: float = 5.0

## Source type → noise level on the 1–10 EventBus scale. Level 0 = silent.
const NOISE_LEVELS: Dictionary = {
	"footstep_walk":   1,
	"footstep_run":    3,
	"footstep_sprint": 5,
	"footstep_crouch": 0,
	"melee_hit":       4,
	"melee_miss":      2,
	"melee_swing":     1,
	"pistol_shot":     8,
	"rifle_shot":      9,
	"shotgun_shot":    10,
	"smg_shot":        7,
	"door_open":       2,
	"door_close":      2,
	"door_break":      7,
	"window_break":    5,
	"item_drop":       2,
	"item_pickup":     1,
	"crafting":        2,
	"cough":           3,
	"scream":          9,
	"explosion":       10,
	"glass_break":     5,
	"zombie_moan":     1,
	"zombie_growl":    2,
}

## Source type → detection radius in world-space metres.
const NOISE_RADII: Dictionary = {
	"footstep_walk":   4.0,
	"footstep_run":    10.0,
	"footstep_sprint": 15.0,
	"footstep_crouch": 0.0,
	"melee_hit":       8.0,
	"melee_miss":      4.0,
	"melee_swing":     2.0,
	"pistol_shot":     45.0,
	"rifle_shot":      65.0,
	"shotgun_shot":    55.0,
	"smg_shot":        40.0,
	"door_open":       6.0,
	"door_close":      6.0,
	"door_break":      20.0,
	"window_break":    15.0,
	"item_drop":       4.0,
	"item_pickup":     2.0,
	"crafting":        5.0,
	"cough":           8.0,
	"scream":          30.0,
	"explosion":       80.0,
	"glass_break":     12.0,
	"zombie_moan":     8.0,
	"zombie_growl":    5.0,
}

## Default noise radius used when a weapon_id does not match a known keyword.
const DEFAULT_WEAPON_RADIUS: float = 50.0

# ─────────────────────────────────────────────
# State
# ─────────────────────────────────────────────

## Active noise events. Each entry: {position, radius, level, age}.
var _noise_events: Array[Dictionary] = []

## Cumulative noise threat for the current area. Decays over time.
var _global_threat: float = 0.0

## Countdown before another horde can be triggered (seconds).
var _horde_cooldown: float = 0.0

## Countdown before another siege can be triggered / when current siege ends.
var _siege_cooldown: float = 0.0

## True while a compound siege event is active.
var _siege_active: bool = false

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	GameManager.noise_system = self
	EventBus.noise_generated.connect(_on_noise_generated)
	EventBus.weapon_fired.connect(_on_weapon_fired)

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	_tick_events(delta)
	_tick_threat(delta)
	_tick_cooldowns(delta)

# ─────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────

## Primary entry point. Looks up level and radius for source_type, then emits
## EventBus.noise_generated. Silent source types (level == 0) are ignored.
## Unknown source types default to level 1 / radius 5.0.
func emit_noise(source_type: String, position: Vector3) -> void:
	var level: int = NOISE_LEVELS.get(source_type, 1)
	var radius: float = NOISE_RADII.get(source_type, 5.0)
	if level <= 0:
		return
	EventBus.noise_generated.emit(position, radius, level)

## Returns the effective noise level (0.0–10.0) at world position.
## Accounts for linear distance falloff within each event's radius.
## Used by enemy AI every frame to decide whether to investigate.
func get_noise_level_at(position: Vector3) -> float:
	var max_level: float = 0.0
	for event: Dictionary in _noise_events:
		var dist: float = position.distance_to(event["position"])
		if dist <= event["radius"]:
			var falloff: float = 1.0 - (dist / maxf(event["radius"], 0.001))
			var effective: float = float(event["level"]) * falloff
			max_level = maxf(max_level, effective)
	return max_level

## Returns the accumulated global threat value (0.0+).
## Drives horde and siege threshold checks.
func get_global_threat() -> float:
	return _global_threat

## Returns true when global threat is below SILENCE_THRESHOLD.
## Stealth and sanity systems can use this to reward quiet play.
func is_silent() -> bool:
	return _global_threat < SILENCE_THRESHOLD

## Returns true while a compound siege is actively in progress.
func is_siege_active() -> bool:
	return _siege_active

## Returns the number of currently tracked noise events.
func get_event_count() -> int:
	return _noise_events.size()

# ─────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────

func _on_noise_generated(position: Vector3, radius: float, noise_level: int) -> void:
	## Drop the oldest event if we are at capacity.
	if _noise_events.size() >= MAX_NOISE_EVENTS:
		_noise_events.pop_front()
	_noise_events.append({
		"position": position,
		"radius":   radius,
		"level":    noise_level,
		"age":      0.0,
	})
	_global_threat += float(noise_level)
	_check_thresholds(position)

func _on_weapon_fired(weapon_id: String, position: Vector3, noise_level: int) -> void:
	## weapon_fired already carries noise_level — map the weapon to an appropriate radius
	## and forward as noise_generated. Avoids double-counting via emit_noise.
	if noise_level <= 0:
		return
	var radius: float = DEFAULT_WEAPON_RADIUS
	var id_lower: String = weapon_id.to_lower()
	if id_lower.contains("pistol") or id_lower.contains("9mm"):
		radius = NOISE_RADII.get("pistol_shot", 45.0)
	elif id_lower.contains("shotgun"):
		radius = NOISE_RADII.get("shotgun_shot", 55.0)
	elif id_lower.contains("smg") or id_lower.contains("submachine"):
		radius = NOISE_RADII.get("smg_shot", 40.0)
	elif id_lower.contains("rifle"):
		radius = NOISE_RADII.get("rifle_shot", 65.0)
	EventBus.noise_generated.emit(position, radius, noise_level)

## Ages all events and removes expired ones.
func _tick_events(delta: float) -> void:
	var i: int = _noise_events.size() - 1
	while i >= 0:
		_noise_events[i]["age"] += delta
		if _noise_events[i]["age"] >= EVENT_LIFETIME:
			_noise_events.remove_at(i)
		i -= 1

## Decay global threat toward zero. Never goes below zero.
func _tick_threat(delta: float) -> void:
	_global_threat = maxf(0.0, _global_threat - THREAT_DECAY_RATE * delta)

## Count down horde / siege cooldowns. End siege when its timer expires.
func _tick_cooldowns(delta: float) -> void:
	if _horde_cooldown > 0.0:
		_horde_cooldown = maxf(0.0, _horde_cooldown - delta)
	if _siege_cooldown > 0.0:
		_siege_cooldown = maxf(0.0, _siege_cooldown - delta)
		if _siege_cooldown <= 0.0 and _siege_active:
			_siege_active = false
			EventBus.compound_siege_ended.emit()

## Check whether accumulated threat crosses horde or siege thresholds.
## Siege takes priority over horde. Both reset _global_threat on trigger.
func _check_thresholds(last_position: Vector3) -> void:
	if _global_threat >= SIEGE_THREAT_THRESHOLD and _siege_cooldown <= 0.0 and not _siege_active:
		_siege_active = true
		_siege_cooldown = SIEGE_COOLDOWN
		_global_threat = 0.0
		EventBus.compound_siege_started.emit()
		return
	if _global_threat >= HORDE_THREAT_THRESHOLD and _horde_cooldown <= 0.0:
		var horde_size: int = clampi(int(_global_threat / 10.0), 2, 12)
		_horde_cooldown = HORDE_COOLDOWN
		_global_threat = 0.0
		EventBus.horde_triggered.emit(last_position, horde_size)
