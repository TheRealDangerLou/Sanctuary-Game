extends Node
## GameManager: Central controller for game state, scene transitions, and in-game time.
## Autoloaded as GameManager at startup. Depends on EventBus being loaded first.

# ─────────────────────────────────────────────
# Enums
# ─────────────────────────────────────────────

enum GameState {
	MENU,     ## Title / main menu is active.
	PLAYING,  ## Normal gameplay loop is running.
	PAUSED,   ## Game is paused (physics and gameplay frozen).
	DEAD,     ## Player has died; death sequence is playing.
	LOADING,  ## A scene transition is in progress.
}

enum GameMode {
	STORY,    ## Shelter-based saves; death respawns at last shelter (not permanent).
	HARDCORE, ## True permadeath; continuous autosave; death ends the run forever.
}

# ─────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────

## In-game minutes that pass per real-world second.
## At 1.0 a full 24-hour day takes 24 real minutes.
const GAME_MINUTES_PER_REAL_SECOND: float = 1.0

## Starting hour for a new game session (6 AM).
const NEW_GAME_START_HOUR: int = 6

# ─────────────────────────────────────────────
# State
# ─────────────────────────────────────────────

## The active game state.
var current_state: GameState = GameState.MENU
var _previous_state: GameState = GameState.MENU

## The active game mode. Set before calling new_game().
var game_mode: GameMode = GameMode.STORY

# In-game calendar and clock
var game_day: int = 1
var game_hour: int = NEW_GAME_START_HOUR
var game_minute: int = 0
var _time_accumulator: float = 0.0

# ─────────────────────────────────────────────
# System manager references
# Set by each subsystem when it initialises so other systems can reach it if needed.
# All real communication still goes through EventBus.
# ─────────────────────────────────────────────
var inventory_manager: Node = null
var npc_manager: Node = null
var world_manager: Node = null
var weather_system: Node = null
var crafting_system: Node = null
var combat_system: Node = null
## Agent 04 — survival systems registered on _ready by each script.
var player_stats: Node = null
var rose_stats: Node = null
var injury_system: Node = null
var sanity_system: Node = null
## Agent 05 — death and loot systems registered on _ready by each script.
var death_system: Node = null
var corpse_loot_system: Node = null
## Agent 06 — noise and detection system registered on _ready.
var noise_system: Node = null
var compound_system: Node = null

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)

func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		_advance_game_time(delta)

# ─────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────

## Transitions the game to a new GameState.
## Emits no signal directly; systems that care should watch EventBus events instead.
func set_state(new_state: GameState) -> void:
	if new_state == current_state:
		return
	_previous_state = current_state
	current_state = new_state
	_on_state_changed(current_state)

## Loads a new scene by resource path, transitioning through the LOADING state.
func change_scene_to(scene_path: String) -> void:
	set_state(GameState.LOADING)
	get_tree().change_scene_to_file(scene_path)

## Freezes gameplay. Has no effect if the game is not currently in the PLAYING state.
func pause_game() -> void:
	if current_state != GameState.PLAYING:
		return
	set_state(GameState.PAUSED)
	get_tree().paused = true

## Resumes gameplay from pause. Has no effect if not currently paused.
func unpause_game() -> void:
	if current_state != GameState.PAUSED:
		return
	set_state(GameState.PLAYING)
	get_tree().paused = false

## Resets all in-game state for a fresh playthrough and transitions to PLAYING.
func new_game() -> void:
	game_day = 1
	game_hour = NEW_GAME_START_HOUR
	game_minute = 0
	_time_accumulator = 0.0
	get_tree().paused = false
	set_state(GameState.PLAYING)
	EventBus.player_spawned.emit(Vector3.ZERO)

## Returns the current in-game time formatted as "Day X — HH:MM".
func get_time_string() -> String:
	return "Day %d — %02d:%02d" % [game_day, game_hour, game_minute]

## Returns the previous game state before the last transition.
func get_previous_state() -> GameState:
	return _previous_state

# ─────────────────────────────────────────────
# Internal
# ─────────────────────────────────────────────

## Advances the in-game clock by the scaled delta and fires time events as needed.
func _advance_game_time(delta: float) -> void:
	_time_accumulator += delta * GAME_MINUTES_PER_REAL_SECOND
	while _time_accumulator >= 1.0:
		_time_accumulator -= 1.0
		_tick_minute()

## Increments the clock by one in-game minute, rolling over hours and days.
func _tick_minute() -> void:
	game_minute += 1
	if game_minute < 60:
		return

	game_minute = 0
	game_hour += 1
	EventBus.time_of_day_changed.emit(game_hour)

	if game_hour < 24:
		return

	game_hour = 0
	game_day += 1

## Called whenever current_state changes to apply state-specific side-effects.
func _on_state_changed(state: GameState) -> void:
	match state:
		GameState.DEAD:
			# Unfreeze the tree so the death sequence can animate.
			get_tree().paused = false
		GameState.LOADING:
			get_tree().paused = false
		GameState.MENU:
			get_tree().paused = false

## Transitions to DEAD state then routes to the correct death signal based on mode.
## HARDCORE: emits character_died_permanently — DeathSystem wipes saves, legacy screen appears.
## STORY:    emits player_respawning — SaveSystem loads last shelter, player continues.
func _on_player_died(_position: Vector3) -> void:
	if current_state == GameState.DEAD:
		return
	set_state(GameState.DEAD)
	var legacy_data: Dictionary = {
		"days_survived": game_day,
		"death_hour":    game_hour,
		"death_minute":  game_minute,
	}
	if game_mode == GameMode.HARDCORE:
		EventBus.character_died_permanently.emit(legacy_data)
	else:
		EventBus.player_respawning.emit(legacy_data)
