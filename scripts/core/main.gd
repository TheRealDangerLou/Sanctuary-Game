extends Node
## Main: Root scene controller. Wires the initial game state on startup.
## All heavy lifting is delegated to autoloaded singletons via EventBus signals.

func _ready() -> void:
	_initialize_game()

## Sets the initial game state and transitions to the main menu.
func _initialize_game() -> void:
	GameManager.set_state(GameManager.GameState.MENU)
