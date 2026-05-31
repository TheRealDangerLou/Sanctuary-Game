extends CanvasLayer
class_name LegacyScreen
## LegacyScreen: Shown after DeathScreen. Displays run statistics and offers
## Play Again (restarts the session) or Quit (exits the application).
## Full controller and keyboard navigation — no mouse required.

@onready var _days_value: Label         = $Overlay/Panel/Stats/DaysRow/Value
@onready var _kills_value: Label        = $Overlay/Panel/Stats/KillsRow/Value
@onready var _cause_value: Label        = $Overlay/Panel/Stats/CauseRow/Value
@onready var _mode_value: Label         = $Overlay/Panel/Stats/ModeRow/Value
@onready var _play_again_btn: Button    = $Overlay/Panel/Buttons/PlayAgain
@onready var _quit_btn: Button          = $Overlay/Panel/Buttons/Quit

func _ready() -> void:
	visible = false
	_play_again_btn.pressed.connect(_on_play_again_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)

func show_legacy(stats: Dictionary) -> void:
	_days_value.text  = str(stats.get("days_survived", 0))
	_kills_value.text = str(stats.get("zombies_killed", 0))
	_cause_value.text = stats.get("cause_of_death", "unknown").capitalize()
	var mode_int: int = stats.get("game_mode", GameManager.GameMode.STORY)
	_mode_value.text  = "HARDCORE" if mode_int == GameManager.GameMode.HARDCORE else "STORY"
	visible = true
	_play_again_btn.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_quit_pressed()

func _on_play_again_pressed() -> void:
	GameManager.session_stats.reset() if GameManager.session_stats else null
	GameManager.new_game()
	get_tree().change_scene_to_file("res://scenes/core/main.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
