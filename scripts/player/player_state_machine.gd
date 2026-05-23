extends Node
## PlayerStateMachine: Base class for the player character finite state machine.
## Agent 02 (Player Controller) extends this class and overrides on_state_entered /
## on_state_exited to implement per-state input and animation logic.

# ─────────────────────────────────────────────
# Enums
# ─────────────────────────────────────────────

enum State {
	IDLE,        ## Standing still, no input.
	WALKING,     ## Moving at walk speed.
	RUNNING,     ## Moving at run speed, consuming stamina.
	CROUCHING,   ## Low-profile movement or stealth stance.
	SWIMMING,    ## Moving through a water volume.
	DEAD,        ## Player has died; no transitions out.
	INTERACTING, ## Engaged with a world object or NPC dialogue.
}

# ─────────────────────────────────────────────
# Transition table
# Lists every state that is reachable from each source state.
# Any transition not listed here is rejected by transition_to().
# ─────────────────────────────────────────────

const VALID_TRANSITIONS: Dictionary = {
	State.IDLE: [
		State.WALKING,
		State.RUNNING,
		State.CROUCHING,
		State.SWIMMING,
		State.DEAD,
		State.INTERACTING,
	],
	State.WALKING: [
		State.IDLE,
		State.RUNNING,
		State.CROUCHING,
		State.SWIMMING,
		State.DEAD,
		State.INTERACTING,
	],
	State.RUNNING: [
		State.IDLE,
		State.WALKING,
		State.CROUCHING,
		State.DEAD,
	],
	State.CROUCHING: [
		State.IDLE,
		State.WALKING,
		State.DEAD,
		State.INTERACTING,
	],
	State.SWIMMING: [
		State.IDLE,
		State.WALKING,
		State.DEAD,
	],
	State.DEAD: [],
	State.INTERACTING: [
		State.IDLE,
		State.WALKING,
		State.DEAD,
	],
}

# ─────────────────────────────────────────────
# State tracking
# ─────────────────────────────────────────────

## The currently active state.
var current_state: State = State.IDLE
## The state that was active immediately before the current one.
var previous_state: State = State.IDLE
## Seconds the player has been in the current state; reset on every transition.
var state_duration: float = 0.0

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _process(delta: float) -> void:
	if current_state != State.DEAD:
		state_duration += delta

# ─────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────

## Attempts to move to new_state.
## Returns true on success, false if the transition is not permitted.
func transition_to(new_state: State) -> bool:
	if not can_transition_to(new_state):
		push_warning(
			"PlayerStateMachine: Rejected transition %s to %s" % [
				State.keys()[current_state],
				State.keys()[new_state],
			]
		)
		return false

	on_state_exited(current_state)
	previous_state = current_state
	current_state = new_state
	state_duration = 0.0
	on_state_entered(current_state)
	return true

## Returns true if moving to new_state from current_state is a valid transition.
func can_transition_to(new_state: State) -> bool:
	if new_state == current_state:
		return false
	return new_state in VALID_TRANSITIONS.get(current_state, [])

## Returns the name of the current state as a plain string (e.g. "WALKING").
func get_state_name() -> String:
	return State.keys()[current_state]

## Returns the name of the previous state as a plain string.
func get_previous_state_name() -> String:
	return State.keys()[previous_state]

# ─────────────────────────────────────────────
# Hooks - override in subclass
# ─────────────────────────────────────────────

## Called immediately after entering a new state.
## Override to start animations, enable input modes, etc.
func on_state_entered(_state: State) -> void:
	pass

## Called immediately before leaving the current state.
## Override to stop animations, clear input locks, etc.
func on_state_exited(_state: State) -> void:
	pass
