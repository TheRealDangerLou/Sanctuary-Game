extends Resource
class_name BuildingData
## BuildingData: Defines a compound structure — cost, prerequisites, and benefits.
## Stored as .tres in resources/buildings/. Loaded at runtime by CompoundSystem.

enum BuildingType {
	SHELTER,    ## Living quarters — raises morale.
	DEFENSE,    ## Wall, gate, watchtower — increases compound security.
	PRODUCTION, ## Workbench, forge, garden — enables crafting stations or food.
	STORAGE,    ## Expands shared item capacity.
	SERVICE,    ## Medical bay, social space — grants morale / healing bonuses.
}

@export var building_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var building_type: BuildingType = BuildingType.SHELTER
## Material cost: Dictionary of item_id → quantity.
@export var cost: Dictionary = {}
## Minimum compound tier before this building can be placed.
@export var tier_required: int = 0
## If non-empty, placing this building activates the named crafting station.
@export var provides_station: String = ""
## Maximum instances per compound. -1 = no limit.
@export var max_per_compound: int = -1
## Flat morale bonus added to the settlement when this building is placed.
@export var morale_bonus: float = 0.0
