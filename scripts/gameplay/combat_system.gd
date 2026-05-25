extends Node
## CombatSystem: Central manager for combat state tracking.
## Tracks active bleeds, ragdoll requests, and routes player_hit signal.
## Autoloaded as singleton via GameManager or added as child of Main.

# ─────────────────────────────────────────────
# Bleed tracking
# ─────────────────────────────────────────────

## bleed_rate in health-per-second, keyed by target_id.
var _active_bleeds: Dictionary = {}

# ─────────────────────────────────────────────
# Ragdoll grace period
# ─────────────────────────────────────────────

## How long (seconds) after death before ragdoll is triggered.
const RAGDOLL_DELAY: float = 0.05

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	EventBus.bleed_started.connect(_on_bleed_started)
	EventBus.combat_hit.connect(_on_combat_hit)
	EventBus.npc_died.connect(_on_npc_died)
	EventBus.player_hit.connect(_on_player_hit)
	EventBus.injury_treated.connect(_on_injury_treated)

func _process(delta: float) -> void:
	_tick_bleeds(delta)

# ─────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────

## Stop bleed effect on a target (called when wound is treated).
func clear_bleed(target_id: String) -> void:
	_active_bleeds.erase(target_id)

## Returns true if target currently has an active bleed.
func is_bleeding(target_id: String) -> bool:
	return _active_bleeds.has(target_id)

## Returns all targets currently bleeding.
func get_bleeding_targets() -> Array:
	return _active_bleeds.keys()

## Manually trigger ragdoll for a target (e.g. from death sequence).
func trigger_ragdoll(target_id: String, hit_direction: Vector3) -> void:
	EventBus.ragdoll_triggered.emit(target_id, hit_direction)

# ─────────────────────────────────────────────
# Signal handlers
# ─────────────────────────────────────────────

func _on_bleed_started(target_id: String, bleed_rate: float) -> void:
	# New bleed overwrites old one (higher rate wins implicitly — caller decides).
	_active_bleeds[target_id] = bleed_rate

func _on_combat_hit(target_id: String, damage: float, hit_location: String) -> void:
	# If the hit location is head and damage meets instakill threshold, fire death.
	if HitDetection.is_instakill(damage, hit_location):
		_schedule_ragdoll(target_id, Vector3.UP)

func _on_player_hit(damage: float, hit_location: String) -> void:
	# Route to EventBus so HUD and status systems can react.
	# The actual health deduction lives in the player stats node (Agent 02).
	# We rebroadcast as combat_hit on the "player" target for consistency.
	EventBus.combat_hit.emit("player", damage, hit_location)

func _on_npc_died(npc_id: String, _cause: String) -> void:
	_active_bleeds.erase(npc_id)

func _on_injury_treated(location: String) -> void:
	# Any treated wound on the player stops their bleed.
	# NPC bleed clearance is handled by the NPC health system (Agent 08-10).
	_active_bleeds.erase("player")

# ─────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────

func _tick_bleeds(delta: float) -> void:
	for target_id: String in _active_bleeds.keys():
		var rate: float = _active_bleeds[target_id]
		# Emit a synthetic combat_hit so health systems see continuous damage.
		EventBus.combat_hit.emit(target_id, rate * delta, "bleed")

func _schedule_ragdoll(target_id: String, hit_dir: Vector3) -> void:
	await get_tree().create_timer(RAGDOLL_DELAY).timeout
	EventBus.ragdoll_triggered.emit(target_id, hit_dir)
