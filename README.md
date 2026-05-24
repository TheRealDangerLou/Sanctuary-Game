# Sanctuary

> *Find your daughters. Survive the dead.*

A 3D open-world survival RPG built in **Godot 4 (GDScript)**. Gritty and grounded — *28 Days Later* meets *Seven Days to Die*. One life. No second chances.

---

## Game Concept

You wake up in a world that has already ended. Somewhere out there, your daughters are still alive — or so you believe. Every decision you make, every person you help or betray, every building you raise or let fall, moves you either closer to them or seals their fate. Death is permanent. The world remembers what you did.

---

## Tech Stack

| Area | Choice |
|---|---|
| Engine | Godot 4.3+ |
| Language | GDScript (no C#) |
| Renderer | Forward+ (3D, high quality) |
| Physics | Jolt Physics 3D (built-in, Godot 4.3+) |
| Platform | PC — Windows primary |
| Target CPU | AMD Ryzen 5 2600 / 16 GB RAM |
| Target FPS | 60 outdoors · 30 minimum in dense areas |

---

## Input Compatibility

The game is fully compatible with **keyboard/mouse and controller** simultaneously. All gameplay actions are mapped to both in `project.godot` — no keyboard-only assumptions anywhere in the codebase. Code always uses `Input.is_action_pressed("action_name")` and never raw key queries.

**Controller layout** — Xbox buttons listed; PlayStation equivalents in parentheses.

| Action | Keyboard / Mouse | Controller |
|---|---|---|
| Move Forward | `W` | Left Stick ↑ |
| Move Backward | `S` | Left Stick ↓ |
| Move Left | `A` | Left Stick ← |
| Move Right | `D` | Left Stick → |
| Jump | `Space` | `A` (`Cross`) |
| Sprint | `Left Shift` | `L3` (click left stick) |
| Crouch | `C` | `B` (`Circle`) |
| Interact | `E` | `Y` (`Triangle`) |
| Primary Attack | `LMB` | `RT` (`R2`) |
| Aim | `RMB` | `LT` (`L2`) |
| Reload | `R` | `X` (`Square`) |
| Melee Attack | `F` | `RB` (`R1`) |
| Use Item | `Q` | `LB` (`L1`) |
| Open Inventory | `Tab` | `Back` (`Select`) |
| Pause | `Escape` | `Start` (`Options`) |
| Open Map | `M` | D-Pad `↑` |
| Open Journal | `J` | D-Pad `↓` |
| Hotbar Next | `]` or Scroll Down | D-Pad `→` |
| Hotbar Prev | `[` or Scroll Up | D-Pad `←` |
| Hotbar 1–8 | `1` – `8` | cycle via Hotbar Next/Prev |
| Drop Item | `G` | inventory screen |

**Analogue deadzone:** 0.5 on all axes.

---

## Setup

### Prerequisites

- **Godot 4.3** or newer (download from godotengine.org)
- No additional plugins required — Jolt Physics is bundled since 4.3

### Opening the Project

1. Clone this repository:
   ```
   git clone https://github.com/TheRealDangerLou/sanctuary-game.git
   ```
2. Open **Godot 4**.
3. Click **Import** and navigate to `sanctuary-game/project.godot`.
4. Wait for the initial asset import to complete (~30 seconds on first open).
5. Press **F5** or click **Play** to run the main scene.

### Running the EventBus Test

1. In the Godot editor, open `tests/test_event_bus.tscn`.
2. Press **F6** (Run Current Scene).
3. Check the **Output** panel — all lines should read `[PASS]`.

---

## Project Structure

```
sanctuary-game/
├── project.godot          ← Godot project config & autoloads
├── .gitignore
├── README.md
├── addons/                ← Third-party Godot plugins
├── art/
│   ├── characters/        ← Character meshes, rigs, textures
│   ├── environments/      ← World geometry, terrain, props
│   ├── ui/                ← UI sprites, fonts, themes
│   └── audio/             ← Sound effects, music, ambience
├── scenes/
│   ├── core/              ← main.tscn (entry point)
│   ├── player/            ← Player scene
│   ├── npc/               ← NPC scenes
│   ├── world/             ← Zone / level scenes
│   ├── ui/                ← HUD, inventory, journal screens
│   └── menus/             ← Title screen, settings, death screen
├── scripts/
│   ├── core/              ← EventBus, GameManager, SaveSystem, Main
│   ├── player/            ← PlayerStateMachine + controller (Agent 02)
│   ├── npc/               ← NPC AI, dialogue (Agent 08-10)
│   ├── world/             ← Zones, weather, time (Agent 05-07)
│   ├── gameplay/          ← Combat, crafting, building (Agent 03-04)
│   └── utils/             ← Shared helpers, math, extensions
├── resources/
│   ├── items/             ← ItemData resources
│   ├── recipes/           ← CraftingRecipe resources
│   └── narrative/         ← QuestData, DialogueData resources
├── docs/                  ← Design documents, agent briefs
└── tests/                 ← Test scenes and scripts
```

---

## Autoloaded Singletons

These three nodes are available globally from any script:

| Singleton | Path | Purpose |
|---|---|---|
| `EventBus` | `scripts/core/event_bus.gd` | All inter-system signals |
| `GameManager` | `scripts/core/game_manager.gd` | Game state, scene transitions, in-game time |
| `SaveSystem` | `scripts/core/save_system.gd` | Save/load data schema and stub API |

---

## Coding Standards

| Rule | Detail |
|---|---|
| Language | GDScript only — no C# |
| Variables and functions | `snake_case` |
| Classes and nodes | `PascalCase` |
| Constants | `UPPER_SNAKE_CASE` |
| Inter-system comms | `EventBus` signals only — never direct node refs |
| One responsibility | One script = one job. No God classes. |
| Type hints | Required on all variables and function signatures |
| Public comments | Required on all public functions |
| Test scenes | Every major system needs a scene in `/tests/` |

---

## Multi-Agent Development

This project is built by 36 specialised agents in sequence:

| Agent | Responsibility |
|---|---|
| **01 - Architecture** *(this file)* | Project foundation, EventBus, GameManager, SaveSystem, PlayerStateMachine |
| 02 - Player Controller | CharacterBody3D movement, input, camera |
| 03 - Combat System | Melee, ranged, hit detection, wound model |
| 04 - Crafting and Building | Recipes, compound construction |
| 05 - World and Zones | Open world, zone streaming, loot spawning |
| 06 - Weather and Time | Dynamic weather, seasons, day/night cycle |
| 07 - Noise and Horde AI | Noise propagation, zombie attraction, siege events |
| 08-10 - NPC Systems | Recruitment, AI, morale, dialogue |
| 11 - Save System | Full serialisation, slot management |

**Rules for all agents:**
- Communicate exclusively through `EventBus`.
- Do not modify files owned by another agent without coordination.
- Register your manager node reference in `GameManager` on `_ready()`.

---

## Licence

Private — all rights reserved.
