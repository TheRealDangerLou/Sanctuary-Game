extends CanvasLayer
## HUD: Displays Dad's survival bars, Rose's health panel, vignette, and desaturation effect.
## All values update exclusively via EventBus signals — this script never polls node state.

# ─────────────────────────────────────────────
# Thresholds
# ─────────────────────────────────────────────

const VIGNETTE_ONSET_HEALTH: float = 0.60
const DESATURATION_ONSET_HEALTH: float = 0.20
const VIGNETTE_MAX_ALPHA: float = 0.35
const SHADER_LERP_SPEED: float = 2.0

# ─────────────────────────────────────────────
# Node references — wired in hud.tscn, never fetched by path at runtime
# ─────────────────────────────────────────────

@onready var _dad_hp_bar: ColorRect       = $StatsPanel/DadGroup/HpBar/Fill
@onready var _dad_hunger_bar: ColorRect   = $StatsPanel/DadGroup/HungerBar/Fill
@onready var _dad_thirst_bar: ColorRect   = $StatsPanel/DadGroup/ThirstBar/Fill
@onready var _rose_hp_bar: ColorRect      = $StatsPanel/RoseGroup/RoseHpBar/Fill
@onready var _rose_gone_label: Label      = $StatsPanel/RoseGroup/GoneLabel
@onready var _rose_group: Control         = $StatsPanel/RoseGroup
@onready var _vignette: ColorRect         = $Vignette
@onready var _desat_rect: ColorRect       = $DesatLayer/DesatRect

var _desat_material: ShaderMaterial
var _target_desat_intensity: float = 0.0
var _current_desat_intensity: float = 0.0
var _dad_health_fraction: float = 1.0

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	_desat_material = _desat_rect.material as ShaderMaterial
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_hunger_changed.connect(_on_player_hunger_changed)
	EventBus.player_thirst_changed.connect(_on_player_thirst_changed)
	EventBus.rose_health_changed.connect(_on_rose_health_changed)
	EventBus.npc_died.connect(_on_npc_died)
	EventBus.player_spawned.connect(_on_player_spawned)
	_rose_gone_label.visible = false
	_update_vignette(1.0)
	_desat_material.set_shader_parameter("intensity", 0.0)

func _process(delta: float) -> void:
	if _current_desat_intensity != _target_desat_intensity:
		_current_desat_intensity = move_toward(
			_current_desat_intensity,
			_target_desat_intensity,
			SHADER_LERP_SPEED * delta
		)
		_desat_material.set_shader_parameter("intensity", _current_desat_intensity)

# ─────────────────────────────────────────────
# EventBus handlers
# ─────────────────────────────────────────────

func _on_player_health_changed(new_health: float, max_health: float) -> void:
	_dad_health_fraction = new_health / max_health
	_set_bar_fill(_dad_hp_bar, _dad_health_fraction)
	_update_vignette(_dad_health_fraction)
	_target_desat_intensity = 1.0 if _dad_health_fraction <= DESATURATION_ONSET_HEALTH else 0.0

func _on_player_hunger_changed(new_hunger: float, max_hunger: float) -> void:
	_set_bar_fill(_dad_hunger_bar, new_hunger / max_hunger)

func _on_player_thirst_changed(new_thirst: float, max_thirst: float) -> void:
	_set_bar_fill(_dad_thirst_bar, new_thirst / max_thirst)

func _on_rose_health_changed(new_health: float, max_health: float) -> void:
	_set_bar_fill(_rose_hp_bar, new_health / max_health)

func _on_npc_died(npc_id: String, _cause: String) -> void:
	if npc_id == "rose":
		_show_rose_gone()

func _on_player_spawned(_position: Vector3) -> void:
	_rose_gone_label.visible = false
	_rose_group.modulate = Color.WHITE
	_set_bar_fill(_rose_hp_bar, 1.0)

# ─────────────────────────────────────────────
# Internal helpers
# ─────────────────────────────────────────────

func _set_bar_fill(fill_rect: ColorRect, fraction: float) -> void:
	var parent_width: float = fill_rect.get_parent_control().size.x
	fill_rect.size.x = parent_width * clampf(fraction, 0.0, 1.0)

func _update_vignette(health_fraction: float) -> void:
	var alpha: float = 0.0
	if health_fraction < VIGNETTE_ONSET_HEALTH:
		alpha = (VIGNETTE_ONSET_HEALTH - health_fraction) / VIGNETTE_ONSET_HEALTH * VIGNETTE_MAX_ALPHA
	_vignette.color = Color(0.5, 0.0, 0.0, alpha)

func _show_rose_gone() -> void:
	_rose_group.modulate = Color(0.35, 0.35, 0.35, 1.0)
	_rose_gone_label.visible = true
	_set_bar_fill(_rose_hp_bar, 0.0)
