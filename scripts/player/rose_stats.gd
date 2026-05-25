extends Node
class_name RoseStats
## RoseStats: Rose's survival stats — all maximums are 80% of Dad's.
## Rose's death immediately triggers game over via EventBus.player_died.
## She is Dad's reason for everything — her loss ends the run.

# ─────────────────────────────────────────────
# Constants — exactly 80% of SurvivalStats maximums
# ─────────────────────────────────────────────

const MAX_HEALTH: float = 80.0
const MAX_HUNGER: float = 80.0
const MAX_THIRST: float = 80.0
const MAX_STAMINA: float = 80.0
const MAX_SANITY: float = 80.0

## Rose is younger — less acclimatised to prolonged hardship, needs more care.
const HUNGER_DECAY_RATE: float = 0.0416   ## empties in ~1.6 in-game days without food
const THIRST_DECAY_RATE: float = 0.0833   ## empties in ~0.8 in-game days without water
const STAMINA_SPRINT_DRAIN: float = 12.0
const STAMINA_REGEN_RATE: float = 4.0

const STARVATION_DAMAGE_RATE: float = 0.8
const DEHYDRATION_DAMAGE_RATE: float = 1.5
const HYPOTHERMIA_SEVERE_DAMAGE_RATE: float = 2.0   ## Rose is more vulnerable to cold
const HYPOTHERMIA_MILD_DAMAGE_RATE: float = 0.5
const HYPERTHERMIA_DAMAGE_RATE: float = 1.2

const NORMAL_TEMPERATURE: float = 37.0

# ─────────────────────────────────────────────
# State
# ─────────────────────────────────────────────

var health: float = MAX_HEALTH
var hunger: float = MAX_HUNGER
var thirst: float = MAX_THIRST
var stamina: float = MAX_STAMINA
var sanity: float = MAX_SANITY
var temperature: float = NORMAL_TEMPERATURE

var is_sprinting: bool = false
var is_dead: bool = false

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	GameManager.rose_stats = self
	EventBus.combat_hit.connect(_on_combat_hit)

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING or is_dead:
		return
	_tick_hunger(delta)
	_tick_thirst(delta)
	_tick_stamina(delta)
	_tick_temperature_effects(delta)

# ─────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────

## Apply damage to Rose. Health at zero triggers immediate game over.
func take_damage(amount: float, _source: String = "") -> void:
	if is_dead:
		return
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		_die()

## Restore Rose's health up to MAX_HEALTH.
func heal(amount: float) -> void:
	health = minf(MAX_HEALTH, health + amount)

## Feed Rose. She absorbs 80% of the nutrition Dad would from the same item.
func eat(nutrition: float) -> void:
	hunger = minf(MAX_HUNGER, hunger + nutrition * 0.8)

## Give Rose water. She absorbs 80% of the hydration.
func drink(hydration: float) -> void:
	thirst = minf(MAX_THIRST, thirst + hydration * 0.8)

## Set Rose's body temperature in °C. Called by environment or shelter systems.
func set_temperature(new_temp: float) -> void:
	temperature = new_temp

## Notify whether Rose is currently sprinting alongside Dad.
func set_sprinting(sprinting: bool) -> void:
	is_sprinting = sprinting

## Returns Rose's health as a 0.0–1.0 fraction. Used by SanitySystem and HUD.
func get_health_percent() -> float:
	return health / MAX_HEALTH

## Returns Rose's hunger as a 0.0–1.0 fraction.
func get_hunger_percent() -> float:
	return hunger / MAX_HUNGER

## Returns true if Rose is alive.
func is_alive() -> bool:
	return not is_dead

# ─────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────

func _tick_hunger(delta: float) -> void:
	hunger = maxf(0.0, hunger - HUNGER_DECAY_RATE * delta)
	if hunger <= 0.0:
		take_damage(STARVATION_DAMAGE_RATE * delta, "starvation")

func _tick_thirst(delta: float) -> void:
	thirst = maxf(0.0, thirst - THIRST_DECAY_RATE * delta)
	if thirst <= 0.0:
		take_damage(DEHYDRATION_DAMAGE_RATE * delta, "dehydration")

func _tick_stamina(delta: float) -> void:
	if is_sprinting:
		stamina = maxf(0.0, stamina - STAMINA_SPRINT_DRAIN * delta)
	else:
		stamina = minf(MAX_STAMINA, stamina + STAMINA_REGEN_RATE * delta)

func _tick_temperature_effects(delta: float) -> void:
	if temperature < 34.0:
		take_damage(HYPOTHERMIA_SEVERE_DAMAGE_RATE * delta, "hypothermia")
	elif temperature < 36.0:
		take_damage(HYPOTHERMIA_MILD_DAMAGE_RATE * delta, "hypothermia")
	elif temperature > 39.5:
		take_damage(HYPERTHERMIA_DAMAGE_RATE * delta, "hyperthermia")

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	# Rose's death is game over — no recovery, no continue.
	EventBus.npc_died.emit("rose", "killed")
	EventBus.player_died.emit(Vector3.ZERO)

func _on_combat_hit(target_id: String, damage: float, _hit_location: String) -> void:
	if target_id == "rose":
		take_damage(damage)
