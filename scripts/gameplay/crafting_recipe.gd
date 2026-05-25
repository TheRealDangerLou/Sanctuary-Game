extends Resource
class_name CraftingRecipe
## CraftingRecipe: Defines inputs, output, and constraints for one crafting operation.
## Stored as .tres in resources/recipes/. Loaded at runtime by CraftingSystem.

@export var recipe_id: String = ""
@export var output_item_id: String = ""
@export var output_quantity: int = 1
## Seconds to complete the craft once ingredients are consumed.
@export var craft_time: float = 3.0
## Crafting station required: "" = hand-craft anywhere, or "workbench" | "forge" | "med_table".
@export var required_station: String = ""
## Ingredients: Dictionary of item_id → required quantity.
@export var ingredients: Dictionary = {}
## knowledge_id that must be unlocked before this recipe appears.
## Empty string means the recipe is available from the start.
@export var required_knowledge: String = ""
