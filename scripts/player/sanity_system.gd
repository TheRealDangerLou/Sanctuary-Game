extends Node
class_name SanitySystem
## SanitySystem: Tracks Dad's psychological state throughout the run.
## Sanity erodes from trauma, injury, and isolation; recovers through safety and Rose's presence.
## Crossing threshold bands fires narrative_event_triggered so other systems can react.

# ─────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────

const MAX_SANITY: float = 100.0

## Passive per-second rates (applied each _process tick).
const PASSIVE_DECAY_RATE: float = 0.005       ## constant low-level horror drain
const ROSE_NEARBY_REGEN: float = 0.010        ## Rose alive and healthy = anchor
const REST_REGEN_RATE: float = 0.050          ## safe, sheltered, resting

## One-time flat impacts from events.
const HIT_NPC_DEATH: float = -5.0
const HIT_INJURY_SEVERE: float = -8.0         ## Dad's own injury, severity ≥ 0.7
const HIT_ROSE_INJURED_SEVERE: float = -15.0  ## Rose hurt badly, severity ≥ 0.5
const HIT_FRIENDLY_FIRE: float = -20.0
const HIT_CRITICAL_HEALTH: float = -10.0      ## entering < 20% HP (one-time per dip)

const GAIN_EAT: float = 2.0
const GAIN_REST_BONUS: float = 3.0            ## reward for sleeping in shelter

## Sanity band boundaries (descending).
const THRESHOLD_LOW: float = 60.0       ## band "low"      — subtle audio distortions
const THRESHOLD_STRESSED: float = 40.0  ## band "stressed" — vignette, aim tremor
const THRESHOLD_UNSTABLE: float = 20.0  ## band "unstable" — hallucinations possible
const THRESHOLD_BREAKING: float = 10.0  ## band "breaking" — severe impairment, panic

# ─────────────────────────────────────────────
# State
# ─────────────────────────────────────────────

var sanity: float = MAX_SANITY
var _is_resting: bool = false
var _rose_is_healthy: bool = true
var _current_band: String = "normal"
var _was_critically_low_health: bool = false

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	GameManager.sanity_system = self
	EventBus.npc_died.connect(_on_npc_died)
	EventBus.injury_applied.connect(_on_injury_applied)
	EventBus.narrative_event_triggered.connect(_on_narrative_event)
	EventBus.player_health_changed.connect(_on_player_health_changed)

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	_tick_sanity(delta)

# ─────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────

## Apply a flat sanity change. Negative values drain; positive values restore.
## Clamps to 0–MAX_SANITY and emits player_sanity_changed.
func adjust_sanity(amount: float) -> void:
	sanity = clampf(sanity + amount, 0.0, MAX_SANITY)
	EventBus.player_sanity_changed.emit(sanity, MAX_SANITY)
	_check_band_crossing()

## Notify that Dad is in a safe, sheltered resting area.
func set_resting(resting: bool) -> void:
	_is_resting = resting
	if resting:
		adjust_sanity(GAIN_REST_BONUS)

## Notify the system of Rose's current health state.
## Called by RoseStats or any system that tracks Rose's condition.
func set_rose_healthy(healthy: bool) -> void:
	_rose_is_healthy = healthy

## Returns sanity as a 0.0–1.0 fraction.
func get_sanity_percent() -> float:
	return sanity / MAX_SANITY

## Returns an aim stability multiplier (0.5–1.0) based on current sanity.
## Below THRESHOLD_STRESSED, tremor begins to affect accuracy.
func get_aim_stability() -> float:
	if sanity >= THRESHOLD_STRESSED:
		return 1.0
	return lerpf(0.5, 1.0, sanity / THRESHOLD_STRESSED)

## Returns true if current sanity is at or below the given threshold value.
func is_below_threshold(threshold: float) -> bool:
	return sanity <= threshold

## Returns the current named sanity band: "normal", "low", "stressed", "unstable", "breaking".
func get_current_band() -> String:
	return _current_band

# ─────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────

func _tick_sanity(delta: float) -> void:
	var net: float = -PASSIVE_DECAY_RATE
	if _is_resting:
		net += REST_REGEN_RATE
	if _rose_is_healthy:
		net += ROSE_NEARBY_REGEN
	adjust_sanity(net * delta)

func _check_band_crossing() -> void:
	var new_band: String
	if sanity <= THRESHOLD_BREAKING:
		new_band = "breaking"
	elif sanity <= THRESHOLD_UNSTABLE:
		new_band = "unstable"
	elif sanity <= THRESHOLD_STRESSED:
		new_band = "stressed"
	elif sanity <= THRESHOLD_LOW:
		new_band = "low"
	else:
		new_band = "normal"
	## Only fire the event when crossing into a worse band, not on every tick.
	if new_band != _current_band:
		_current_band = new_band
		if new_band != "normal":
			EventBus.narrative_event_triggered.emit("sanity_" + new_band)

func _on_npc_died(npc_id: String, _cause: String) -> void:
	if npc_id == "rose":
		return  ## Game is ending — sanity no longer matters.
	adjust_sanity(HIT_NPC_DEATH)

func _on_injury_applied(location: String, severity: float) -> void:
	if location.begins_with("rose_") and severity >= 0.5:
		adjust_sanity(HIT_ROSE_INJURED_SEVERE)
		set_rose_healthy(false)
	elif not location.begins_with("rose_") and severity >= 0.7:
		adjust_sanity(HIT_INJURY_SEVERE)

func _on_narrative_event(event_id: String) -> void:
	## Only react to events we care about; ignore our own sanity_* events.
	if event_id.begins_with("friendly_fire_"):
		adjust_sanity(HIT_FRIENDLY_FIRE)

func _on_player_health_changed(new_health: float, max_health: float) -> void:
	var is_critical: bool = (new_health / max_health) < 0.2
	## Apply the hit only once per dip into critical — not on every tick.
	if is_critical and not _was_critically_low_health:
		adjust_sanity(HIT_CRITICAL_HEALTH)
	_was_critically_low_health = is_critical
