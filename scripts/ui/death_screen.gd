extends CanvasLayer
class_name DeathScreen
## DeathScreen: Full-screen death splash shown immediately on Dad or Rose death.
## Displays "SANCTUARY LOST" and cause of death, then auto-advances to LegacyScreen
## after 2 seconds. No input required — the transition is timer-driven.

signal transition_to_legacy

const DISPLAY_DURATION: float = 2.0

@onready var _overlay: ColorRect      = $Overlay
@onready var _title_label: Label       = $Overlay/VBox/Title
@onready var _cause_label: Label       = $Overlay/VBox/Cause
@onready var _timer: Timer             = $TransitionTimer

func _ready() -> void:
	visible = false
	_timer.wait_time = DISPLAY_DURATION
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)

func show_death(cause: String) -> void:
	_cause_label.text = cause
	visible = true
	_timer.start()

func _on_timer_timeout() -> void:
	transition_to_legacy.emit()
