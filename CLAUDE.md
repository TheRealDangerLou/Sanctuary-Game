# Sanctuary — Developer Reference

## Save System Design

### Two Modes

**Story Mode** (default — `GameManager.game_mode = GameMode.STORY`)

Saving is a deliberate, earned action. The player never saves automatically — they must build shelter and sleep.

- Saving only happens when the player sleeps in a shelter they own
- Crafting a **bedroll** (quality 1) creates the first save point — this is the minimum requirement
- **Tent** (quality 2) and **permanent shelter** (quality 3: bed + walls + roof) are better save points and map markers
- Each shelter gets its own save slot (up to MAX_SAVE_SLOTS = 5); slots are assigned dynamically
- On death: respawn at the last shelter the player slept at, with all progress from that save
- If the player dies before sleeping for the first time, there is no respawn — the run ends (legacy screen)
- No autosave, no background saves, no time-based saves — the player lives with the consequences of not sleeping

**Hardcore Mode** (`GameManager.game_mode = GameMode.HARDCORE`)

True permadeath. No shelter-based saves.

- Single save slot (slot 0)
- Autosaves every 60 real seconds while in PLAYING state
- Death fires `character_died_permanently` → DeathSystem wipes slot 0 → legacy screen → new game only
- No respawning, no second chances

**Both Modes**
- Legacy records (`user://legacy_records.json`) persist forever across all playthroughs
- Burial sites remain permanently on the map (future system)
- **Rose death = immediate game over, no exceptions, no mode override**

---

### Signal Flow

**Story mode death:**
```
player_died
  → GameManager._on_player_died()
  → EventBus.player_respawning(legacy_data)
  → SaveSystem._on_player_respawning()
      → load_game(last_shelter_slot)
      → GameManager.set_state(PLAYING)
      → EventBus.player_spawned(shelter_position)
```

**Hardcore mode death:**
```
player_died
  → GameManager._on_player_died()
  → EventBus.character_died_permanently(legacy_data)
  → DeathSystem._on_character_died_permanently()
      → _append_legacy_record()
      → _wipe_save_data()   ← deletes slot 0 only
```

**Shelter save (story mode):**
```
shelter_created(id, pos, quality)
  → SaveSystem._on_shelter_created()
  → SaveSystem.register_shelter()   ← assigns save slot

player_slept(shelter_id)
  → SaveSystem._on_player_slept()
  → SaveSystem.save_at_shelter()
  → save_game(shelter.save_slot)
```

**Zombie hit pipeline:**
```
weapon.attack()
  → EventBus.combat_hit(zombie.name, scaled_dmg, hit_location)
  → zombie.receive_hit(scaled_dmg, hit_location, hit_pos)
      → headshot if hit_pos.y > origin.y + 1.3  → _die() instantly
      → otherwise _health -= damage; _die() at 0
  → EventBus.enemy_killed("zombie", position)  [on death]
  → CorpseLootSystem registers loot
```

---

### Key Classes and Files

| File | Purpose |
|---|---|
| `scripts/core/save_system.gd` | Autoloaded as `SaveSystem`. Orchestrates all save/load for both modes. |
| `scripts/core/shelter_save_point.gd` | Data class — one instance per registered shelter. Serialises to/from JSON. |
| `scripts/core/game_manager.gd` | `GameMode` enum (STORY/HARDCORE). Routes `player_died` to correct signal. |
| `scripts/gameplay/death_system.gd` | Handles legacy records and save wipe. Only reacts to `character_died_permanently`. |
| `scripts/core/event_bus.gd` | All inter-system signals. Never reference nodes directly between systems. |
| `scripts/enemies/zombie_controller.gd` | ZombieController: 5-state AI, noise awareness, melee attack, headshot death. |

### Save File Layout

`user://saves/slot_N.sav` (JSON, one file per slot):

- **Story mode**: each slot = one shelter save. Slot assignment is dynamic (shelter A → slot 0, shelter B → slot 1, …). The `"shelters"` section in every save includes the full shelter list so it can be restored on load.
- **Hardcore mode**: slot 0 is the only slot used.

`user://legacy_records.json` — append-only array of death records. Never wiped.

---

## Scene Wiring (Phase 2 Step 4)

### Spawn order in `main.gd`

1. Instantiate `game_world.tscn` → add to `WorldLayer`
   - All system nodes self-register on `GameManager` in their `_ready()`
2. Instantiate `player.tscn` → add to `PlayerLayer`, add to `"player"` group
   - `SurvivalStats` is a direct child — registers `GameManager.player_stats = self`
   - `save_system._apply_player()` uses `SurvivalStats.get_parent()` to teleport the player on load
3. Instantiate `rose.tscn` → add to `PlayerLayer`, 1.5m beside Dad
   - `RoseStats` is a direct child — registers `GameManager.rose_stats = self`
4. If `SaveSystem._pending_load`: `apply_pending_load()` → restores all live state from disk
   Else: `GameManager.new_game()` → fresh start, emits `player_spawned`
5. `Input.mouse_mode = MOUSE_MODE_CAPTURED`

---

## Sacred Rules

These rules apply to every agent, every PR, every session. Non-negotiable.

1. **NEVER merge any PR without Lou explicitly saying "merge PR"**
2. **NEVER touch `actor-companion-app` or `PocketLou-Guitar`**
3. **GDScript ONLY** — never C#
4. **EventBus signals ONLY** — never direct node references between systems
5. **Full controller + keyboard dual input** on EVERY interactive system
6. **No placeholders** — every function fully implemented, no stubs
7. **Every agent creates a PR** — never merge without Lou's explicit "merge PR"**
8. **Rose death ALWAYS triggers game over immediately** — no exceptions, no mode override
9. **Every system that affects Dad must also account for Rose** (Rose stats = 80% of Dad's)

## Vertical Slice Plan (Phase 2)

| Step | Status | Description |
|---|---|---|
| 1 | ✅ Merged (PR #10) | Stabilisation — audit all systems, fix crashes, add Logger + DebugOverlay |
| 2 | ✅ Merged (PR #12) | Save system — full shelter-based + hardcore implementation |
| 3 | ✅ Merged (PR #13) | Small playable map (500×500 m, hospital + town + forest) |
| 4 | ✅ Merged (PR #14) | Connect all systems to map, spawn Dad + Rose, call `apply_pending_load()` |
| 5 | ✅ PR open | Basic civilian zombie — shamble, noise reaction, headshot kill, loot drop |
| 6 | PR open | Basic HUD (vignette, desaturation, stat bars) |
| 7 | Pending | Death and legacy screen |
| 8 | Pending | Game feel pass |
