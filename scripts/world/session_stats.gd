extends Node
class_name SessionStats
## SessionStats: Tracks per-run statistics displayed on the Legacy Screen.
## Placed as a child of GameWorld so it is torn down and recreated each session.
## Connects to EventBus signals only — no direct node references.

var days_survived: int = 0
var zombies_killed: int = 0
var cause_of_death: String = "unknown"

var _real_seconds_elapsed: float = 0.0

const SECONDS_PER_GAME_DAY: float = 300.0

func _ready() -> void:
	GameManager.session_stats = self
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_spawned.connect(_on_player_spawned)

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	_real_seconds_elapsed += delta
	days_survived = GameManager.game_day

func set_cause_of_death(cause: String) -> void:
	cause_of_death = cause

func get_stats() -> Dictionary:
	return {
		"days_survived": days_survived,
		"zombies_killed": zombies_killed,
		"cause_of_death": cause_of_death,
		"game_mode": GameManager.game_mode,
	}

func reset() -> void:
	days_survived = 0
	zombies_killed = 0
	cause_of_death = "unknown"
	_real_seconds_elapsed = 0.0

func _on_enemy_killed(_enemy_type: String, _position: Vector3) -> void:
	zombies_killed += 1

func _on_player_died(_position: Vector3) -> void:
	days_survived = GameManager.game_day

func _on_player_spawned(_position: Vector3) -> void:
	reset()
