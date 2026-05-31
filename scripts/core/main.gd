extends Node
## Main: Root scene controller. Spawns the game world, Dad, and Rose, then starts play.
## No menu UI yet — goes straight to gameplay. Future agents add a proper main menu here.

const GAME_WORLD_SCENE:   PackedScene = preload("res://scenes/world/game_world.tscn")
const PLAYER_SCENE:       PackedScene = preload("res://scenes/player/player.tscn")
const ROSE_SCENE:         PackedScene = preload("res://scenes/player/rose.tscn")
const DEATH_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/death_screen.tscn")
const LEGACY_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/legacy_screen.tscn")

@onready var _world_layer:  Node3D     = $WorldLayer
@onready var _player_layer: Node3D     = $PlayerLayer
@onready var _death_screen: DeathScreen  = $DeathScreen
@onready var _legacy_screen: LegacyScreen = $LegacyScreen

func _ready() -> void:
	EventBus.game_over.connect(_on_game_over)
	_death_screen.transition_to_legacy.connect(_on_transition_to_legacy)
	_start_game()

func _start_game() -> void:
	var world: Node3D = GAME_WORLD_SCENE.instantiate() as Node3D
	_world_layer.add_child(world)

	var spawn_pos: Vector3 = world.get_node("SpawnPoint").global_position

	var player: Node3D = PLAYER_SCENE.instantiate() as Node3D
	player.add_to_group("player")
	_player_layer.add_child(player)
	player.global_position = spawn_pos

	var rose: Node3D = ROSE_SCENE.instantiate() as Node3D
	_player_layer.add_child(rose)
	rose.global_position = spawn_pos + Vector3(1.5, 0.0, 0.0)

	if SaveSystem._pending_load:
		SaveSystem.apply_pending_load()
	else:
		GameManager.new_game()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_game_over(stats: Dictionary) -> void:
	_death_screen.show_death(stats.get("cause_of_death", "unknown"))

func _on_transition_to_legacy() -> void:
	_death_screen.visible = false
	_legacy_screen.show_legacy(GameManager.session_stats.get_stats() \
		if GameManager.session_stats else {})

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		match GameManager.current_state:
			GameManager.GameState.PLAYING:
				GameManager.pause_game()
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			GameManager.GameState.PAUSED:
				GameManager.unpause_game()
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
