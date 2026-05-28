extends CanvasLayer
## DebugOverlay: Real-time survival stat readout for development. Toggle with F3.
## Add as child of Main scene. Reads live values from EventBus and NoiseSystem.

var _panel: PanelContainer = null
var _label: Label = null
var _showing: bool = false

var _health: float = 100.0
var _hunger: float = 100.0
var _stamina: float = 100.0
var _sanity: float = 100.0
var _temperature: float = 20.0
var _recent_signals: Array[String] = []

const _MAX_SIGNALS: int = 6

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	layer = 100
	_build_ui()
	visible = false

	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.player_hunger_changed.connect(_on_hunger_changed)
	EventBus.player_stamina_changed.connect(_on_stamina_changed)
	EventBus.player_sanity_changed.connect(_on_sanity_changed)
	EventBus.player_temperature_changed.connect(_on_temperature_changed)
	EventBus.horde_triggered.connect(_on_horde_triggered)
	EventBus.compound_siege_started.connect(_on_siege_started)
	EventBus.compound_siege_ended.connect(_on_siege_ended)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_overlay"):
		_showing = not _showing
		visible = _showing

	if _showing:
		_update_label()

# ─────────────────────────────────────────────
# UI construction
# ─────────────────────────────────────────────

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(10.0, 10.0)
	add_child(_panel)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_panel.add_child(_label)

# ─────────────────────────────────────────────
# Label refresh
# ─────────────────────────────────────────────

func _update_label() -> void:
	var threat: float = 0.0
	var siege: bool = false
	var event_count: int = 0
	if GameManager.noise_system:
		threat = GameManager.noise_system.get_global_threat()
		siege = GameManager.noise_system.is_siege_active()
		event_count = GameManager.noise_system.get_event_count()

	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== DEBUG (F3) ===")
	lines.append("HP       %.1f" % _health)
	lines.append("Hunger   %.1f" % _hunger)
	lines.append("Stamina  %.1f" % _stamina)
	lines.append("Sanity   %.1f" % _sanity)
	lines.append("Temp     %.1f C" % _temperature)
	lines.append("Threat   %.1f%s" % [threat, " [SIEGE]" if siege else ""])
	lines.append("Noise ev %d" % event_count)
	if not _recent_signals.is_empty():
		lines.append("--- Events ---")
		for sig: String in _recent_signals:
			lines.append(sig)
	_label.text = "\n".join(lines)

func _push_event(text: String) -> void:
	_recent_signals.push_front(text)
	if _recent_signals.size() > _MAX_SIGNALS:
		_recent_signals.resize(_MAX_SIGNALS)

# ─────────────────────────────────────────────
# Signal handlers
# ─────────────────────────────────────────────

func _on_health_changed(val: float, _max: float) -> void:
	_health = val

func _on_hunger_changed(val: float, _max: float) -> void:
	_hunger = val

func _on_stamina_changed(val: float, _max: float) -> void:
	_stamina = val

func _on_sanity_changed(val: float, _max: float) -> void:
	_sanity = val

func _on_temperature_changed(val: float) -> void:
	_temperature = val

func _on_horde_triggered(pos: Vector3, size: int) -> void:
	_push_event("HORDE x%d @ (%.0f,%.0f)" % [size, pos.x, pos.z])

func _on_siege_started() -> void:
	_push_event("SIEGE STARTED")

func _on_siege_ended() -> void:
	_push_event("siege ended")
