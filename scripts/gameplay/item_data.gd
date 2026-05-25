extends Resource
class_name ItemData
## ItemData: Defines a single item type. Stored as .tres in resources/items/.

enum ItemType {
	MATERIAL,           ## Raw crafting material (wood, metal, cloth, etc.).
	CONSUMABLE,         ## Food, medicine, water — consumed on use.
	WEAPON,             ## Held weapon item (references a weapon scene).
	BUILDING_COMPONENT, ## Heavy material only usable in compound construction.
	TOOL,               ## Non-weapon, non-consumable held item.
	AMMO,               ## Ammunition stack for ranged weapons.
}

@export var item_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var item_type: ItemType = ItemType.MATERIAL
## Weight in kilograms; contributes to carry capacity.
@export var weight: float = 0.5
@export var is_stackable: bool = true
@export var max_stack: int = 99
@export var icon: Texture2D = null
## scene_path is used for WEAPON items to reference their weapon .tscn.
@export var scene_path: String = ""
