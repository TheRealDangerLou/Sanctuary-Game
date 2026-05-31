extends Node
class_name SurvivalStats
## SurvivalStats: Dad's resource bars — health, hunger, thirst, stamina, temperature.
## Receives combat_hit("player", …) from the EventBus and delegates to take_damage.
## Emits all player_* EventBus signals so the HUD and other systems can react.

# ─────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────

const MAX_HEALTH: float = 100.0
const MAX_HUNGER: float = 100.0
const MAX_THIRST: float = 100.0
const MAX_STAMINA: float = 100.0

## Hunger empties in ~2 in-game days without food (2 × 1440 real-seconds = 2880 s).
const HUNGER_DECAY_RATE: float = 0.0347
## Thirst empties in ~1 in-game day without water (1440 real-seconds = 24 min play).
const THIRST_DECAY_RATE: float = 0.0694

## Stamina drain per second while sprinting; regen per second otherwise.
const STAMINA_SPRINT_DRAIN: float = 10.0
const STAMINA_REGEN_RATE: float = 5.0

## HP/s dealt when a resource hits zero.
const STARVATION_DAMAGE_RATE: float = 1.0
const DEHYDRATION_DAMAGE_RATE: float = 2.0
const HYPOTHERMIA_SEVERE_DAMAGE_RATE: float = 1.5  ## below 34 °C
const HYPOTHERMIA_MILD_DAMAGE_RATE: float = 0.3    ## 34–36 °C
const HYPERTHERMIA_DAMAGE_RATE: float = 1.0        ## above 39.5 °C

## Below these values movement/sprint penalties begin.
const HUNGER_PENALTY_THRESHOLD: float = 25.0
const THIRST_PENALTY_THRESHOLD: float = 20.0
const LOW_STAMINA_THRESHOLD: float = 15.0

## Normal body temperature in °C.
const NORMAL_TEMPERATURE: float = 37.0

# ─────────────────────────────────────────────
# State
# ─────────────────────────────────────────────

var health: float = MAX_HEALTH
var hunger: float = MAX_HUNGER
var thirst: float = MAX_THIRST
var stamina: float = MAX_STAMINA
var temperature: float = NORMAL_TEMPERATURE

var is_sprinting: bool = false
var is_dead: bool = false

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	GameManager.player_stats = self
	EventBus.combat_hit.connect(_on_combat_hit)
	EventBus.player_died.connect(_on_player_died)

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

## Apply raw damage from any source. Source is informational only.
func take_damage(amount: float, _source: String = "") -> void:
	if is_dead:
		return
	health = maxf(0.0, health - amount)
	EventBus.player_health_changed.emit(health, MAX_HEALTH)
	if health <= 0.0:
		_die()

## Restore health up to MAX_HEALTH.
func heal(amount: float) -> void:
	health = minf(MAX_HEALTH, health + amount)
	EventBus.player_health_changed.emit(health, MAX_HEALTH)

## Consume food. nutrition is hunger units restored (0–100 scale).
func eat(nutrition: float) -> void:
	hunger = minf(MAX_HUNGER, hunger + nutrition)
	EventBus.player_hunger_changed.emit(hunger, MAX_HUNGER)

## Consume water. hydration is thirst units restored (0–100 scale).
func drink(hydration: float) -> void:
	thirst = minf(MAX_THIRST, thirst + hydration)
	EventBus.player_thirst_changed.emit(thirst, MAX_THIRST)

## Update body temperature in °C. Called by WeatherSystem / environment hazards.
func set_temperature(new_temp: float) -> void:
	temperature = new_temp
	EventBus.player_temperature_changed.emit(temperature)

## Notify the stats system whether the player is currently sprinting.
func set_sprinting(sprinting: bool) -> void:
	is_sprinting = sprinting

## Returns 0.0–1.0 movement speed multiplier factoring hunger, thirst, and stamina.
func get_movement_speed_multiplier() -> float:
	var mult: float = 1.0
	if hunger < HUNGER_PENALTY_THRESHOLD:
		mult *= 0.75
	if thirst < THIRST_PENALTY_THRESHOLD:
		mult *= 0.85
	if stamina < LOW_STAMINA_THRESHOLD:
		mult *= 0.80
	return mult

## Returns true when there is any stamina remaining and the player is alive.
func can_sprint() -> bool:
	return stamina > 0.0 and not is_dead

## Returns health as a 0.0–1.0 fraction.
func get_health_percent() -> float:
	return health / MAX_HEALTH

# ─────────────────────────────────────────────
# Private
# ─────────────────────────────────────────────

func _tick_hunger(delta: float) -> void:
	hunger = maxf(0.0, hunger - HUNGER_DECAY_RATE * delta)
	EventBus.player_hunger_changed.emit(hunger, MAX_HUNGER)
	if hunger <= 0.0:
		take_damage(STARVATION_DAMAGE_RATE * delta, "starvation")

func _tick_thirst(delta: float) -> void:
	thirst = maxf(0.0, thirst - THIRST_DECAY_RATE * delta)
	EventBus.player_thirst_changed.emit(thirst, MAX_THIRST)
	if thirst <= 0.0:
		take_damage(DEHYDRATION_DAMAGE_RATE * delta, "dehydration")

func _tick_stamina(delta: float) -> void:
	if is_sprinting:
		stamina = maxf(0.0, stamina - STAMINA_SPRINT_DRAIN * delta)
	else:
		stamina = minf(MAX_STAMINA, stamina + STAMINA_REGEN_RATE * delta)
	EventBus.player_stamina_changed.emit(stamina, MAX_STAMINA)

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
	EventBus.player_died.emit(Vector3.ZERO)

func _on_combat_hit(target_id: String, damage: float, _hit_location: String) -> void:
	if target_id == "player":
		take_damage(damage)

func _on_player_died(_pos: Vector3) -> void:
	is_dead = true
