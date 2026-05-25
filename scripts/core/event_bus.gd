extends Node
## EventBus: Global signal hub for all inter-system communication.
## Every system emits and receives through this singleton exclusively.
## No system ever references another system's nodes directly.

# ─────────────────────────────────────────────
# Player signals
# ─────────────────────────────────────────────

## Emitted when the player dies. Carries last known world position.
signal player_died(position: Vector3)
## Emitted when the player spawns or respawns into the world.
signal player_spawned(position: Vector3)
## Emitted whenever the player's health value changes.
signal player_health_changed(new_health: float, max_health: float)
## Emitted whenever the player's hunger value changes.
signal player_hunger_changed(new_hunger: float, max_hunger: float)
## Emitted whenever the player's core body temperature changes.
signal player_temperature_changed(new_temp: float)
## Emitted whenever the player's sanity value changes.
signal player_sanity_changed(new_sanity: float, max_sanity: float)
## Emitted whenever the player's stamina value changes.
signal player_stamina_changed(new_stamina: float, max_stamina: float)

# ─────────────────────────────────────────────
# Injury signals
# ─────────────────────────────────────────────

## Emitted when a limb injury is applied. location = body part string, severity = 0.0-1.0.
signal injury_applied(location: String, severity: float)
## Emitted when a limb injury has been treated.
signal injury_treated(location: String)
## Emitted when the player contracts an infection.
signal infection_started()
## Emitted when the player's infection is fully cured.
signal infection_cured()

# ─────────────────────────────────────────────
# Inventory signals
# ─────────────────────────────────────────────

## Emitted when an item is added to the player's inventory.
signal item_picked_up(item_id: String, quantity: int)
## Emitted when an item is dropped into the world.
signal item_dropped(item_id: String, position: Vector3)
## Emitted when the carried weight total changes.
signal inventory_weight_changed(current_weight: float, max_weight: float)
## Emitted when the inventory has no remaining capacity.
signal inventory_full()

# ─────────────────────────────────────────────
# Combat signals
# ─────────────────────────────────────────────

## Emitted when an enemy is killed.
signal enemy_killed(enemy_type: String, position: Vector3)
## Emitted when the player takes a hit. hit_location = body part string.
signal player_hit(damage: float, hit_location: String)
## Emitted when any entity takes a hit. target_id is the node name or NPC ID.
signal combat_hit(target_id: String, damage: float, hit_location: String)
## Emitted when a weapon is discharged. noise_level is on a 1-10 scale.
signal weapon_fired(weapon_id: String, position: Vector3, noise_level: int)
## Emitted when a weapon begins its reload sequence.
signal weapon_reloading(weapon_id: String)
## Emitted when a weapon jams due to low condition. Clears after the unjam delay.
signal weapon_jammed(weapon_id: String)
## Emitted when a bleed effect begins on a target.
signal bleed_started(target_id: String, bleed_rate: float)
## Emitted when a death triggers the ragdoll physics sequence.
signal ragdoll_triggered(target_id: String, hit_direction: Vector3)
## Emitted when a projectile or melee blow connects — drives blood VFX (Agent 27).
signal blood_impact(position: Vector3, hit_normal: Vector3)

# ─────────────────────────────────────────────
# Noise signals
# ─────────────────────────────────────────────

## Emitted when any noise event occurs. radius is world-space metres. noise_level is 1-10.
signal noise_generated(position: Vector3, radius: float, noise_level: int)
## Emitted when a horde is drawn to a location by accumulated noise.
signal horde_triggered(position: Vector3, horde_size: int)
## Emitted when a siege event begins on the player's compound.
signal compound_siege_started()
## Emitted when a siege event concludes.
signal compound_siege_ended()

# ─────────────────────────────────────────────
# World signals
# ─────────────────────────────────────────────

## Emitted when the player enters a named world zone.
signal zone_entered(zone_id: String)
## Emitted when the player exits a named world zone.
signal zone_exited(zone_id: String)
## Emitted when the weather transitions to a new state.
signal weather_changed(weather_type: String, intensity: float)
## Emitted once per in-game hour rollover.
signal time_of_day_changed(hour: int)
## Emitted when the in-game season transitions.
signal season_changed(season: String)

# ─────────────────────────────────────────────
# Settlement signals
# ─────────────────────────────────────────────

## Emitted when a building is placed in the compound.
signal building_placed(building_type: String, position: Vector3)
## Emitted when a building is destroyed.
signal building_destroyed(building_id: String)
## Emitted when the compound reaches a new progression tier.
signal compound_tier_unlocked(tier: int)
## Emitted when the settlement's collective morale changes.
signal settlement_morale_changed(new_morale: float)

# ─────────────────────────────────────────────
# NPC signals
# ─────────────────────────────────────────────

## Emitted when an NPC joins the player's group.
signal npc_recruited(npc_id: String)
## Emitted when an NPC dies. cause is a short descriptor string.
signal npc_died(npc_id: String, cause: String)
## Emitted when an NPC's personal morale changes.
signal npc_morale_changed(npc_id: String, new_morale: float)
## Emitted when the player's relationship tier with an NPC changes.
signal npc_relationship_changed(npc_id: String, new_relationship: String)
## Emitted when an NPC is assigned a compound role.
signal npc_role_assigned(npc_id: String, role: String)

# ─────────────────────────────────────────────
# Narrative signals
# ─────────────────────────────────────────────

## Emitted when a clue about the player's daughters is discovered.
signal daughter_clue_found(clue_id: String, clue_number: int)
## Emitted when a quest becomes active.
signal quest_started(quest_id: String)
## Emitted when a quest reaches its completion condition.
signal quest_completed(quest_id: String)
## Emitted when a scripted narrative event fires.
signal narrative_event_triggered(event_id: String)

# ─────────────────────────────────────────────
# Reputation signals
# ─────────────────────────────────────────────

## Emitted when the player's moral alignment score shifts. Range: -1.0 (ruthless) to 1.0 (noble).
signal moral_alignment_changed(new_alignment: float)
## Emitted when the player's standing with a faction changes.
signal faction_reputation_changed(faction_id: String, new_value: float)

# ─────────────────────────────────────────────
# Crafting signals
# ─────────────────────────────────────────────

## Emitted when the player begins crafting a recipe.
signal crafting_started(recipe_id: String)
## Emitted when a craft completes successfully. output_item is the resulting item_id.
signal crafting_completed(recipe_id: String, output_item: String)
## Emitted when a craft attempt fails.
signal crafting_failed(recipe_id: String)
## Emitted when a recipe becomes available to the player.
signal recipe_unlocked(recipe_id: String)
## Emitted when a knowledge node is unlocked in the skill tree.
signal knowledge_unlocked(knowledge_id: String)

# ─────────────────────────────────────────────
# Save signals
# ─────────────────────────────────────────────

## Emitted after a successful manual save.
signal game_saved(slot: int)
## Emitted after a save slot is successfully loaded.
signal game_loaded(slot: int)
## Emitted when the autosave routine is triggered.
signal autosave_triggered()
## Emitted on permanent death. legacy_data carries stats for the legacy screen.
signal character_died_permanently(legacy_data: Dictionary)
