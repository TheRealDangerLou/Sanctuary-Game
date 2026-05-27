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
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	GameManager.combat_system = self
	EventBus.bleed_started.connect(_on_bleed_started)
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

func _on_player_hit(damage: float, hit_location: String) -> void:
	# Route to EventBus so HUD and status systems can react.
	# The actual health deduction lives in the player stats node (Agent 02).
	# We rebroadcast as combat_hit on the "player" target for consistency.
	EventBus.combat_hit.emit("player", damage, hit_location)

func _on_npc_died(npc_id: String, _cause: String) -> void:
	_active_bleeds.erase(npc_id)

func _on_injury_treated(_location: String) -> void:
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
