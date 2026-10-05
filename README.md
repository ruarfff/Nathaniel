# Nathaniel

An isometric strategy/action game built with Godot. Lead Nathaniel and his robot companion Hermes through five campaign levels and survival mode.

## Run and develop

Use **Godot 4.7.2 stable**. Python 3 and Node.js 18+ with npm are used by the checks and developer tools. iOS exports also need Xcode and matching Godot export templates.

```sh
npm --prefix game-mcp-server ci  # Install the test adapter dependencies once
make                      # Run the Survival-only demo
make run                  # Run the full game
make editor               # Open the visual editor
make level LEVEL=1        # Start a campaign level; 0 is survival
make test                 # Native content, gameplay, saves, UI, tooling and MCP
make format-check
make profile              # Simulation workload
make profile-rendered     # Rendered workload and screenshot
make export-macos         # Local release app
make export-ios           # Unsigned Xcode project
make export-web           # Browser release in exports/web/
make serve-web            # Preview at http://127.0.0.1:8060/
make demo                 # Run the Survival-only demo locally
make export-web-demo      # Browser demo in exports/web-demo/
make serve-web-demo       # Preview the browser demo
make help                 # Commands and options
```

Open `project.godot` directly in the editor if preferred. Native scenes in `levels/` are authoritative: edit a level and press **F6** to play it. **F5** opens the menu. `make import` refreshes Godot's resource imports.

Exports go to `exports/macos/Nathaniel.app` and `exports/ios/Nathaniel.xcodeproj`. [Authoring and exports](docs/authoring.md) covers scene editing, templates, and iOS setup. [Verification](docs/verification.md) records the tested platforms and remaining device checks.

The [browser version](docs/web.md) uses the same game and runs from a static web server. Export it, run `make serve-web`, then open <http://127.0.0.1:8060/>. Browser saves are separate from native saves.

The [web demo](docs/web.md#survival-demo) shows demo mode and offers Survival only.
Use `make export-web-demo` and `make serve-web-demo` to preview it. The regular
exports retain the full campaign and Survival.

The [Railway demo deployment](docs/railway.md) builds and tests the web demo in
Docker, then serves its exported files with Caddy. Use `make image-demo` to
check the same image locally.

## Play

- Click or tap the ground to move Nathaniel; select an enemy to target it.
- Walk over a weapon crate to unlock the heavy rifle. Use **1 / 2** or the named weapon buttons to switch; movement and aiming continue during the 0.35-second switch.
- Use Deploy/Follow to direct Hermes. He starts following Nathaniel and cannot be selected directly. Deploy plants him as a stationary cannon base.
- Select Build to focus the camera on Hermes and show his amber build range. Hermes keeps following until a tower is placed. Drag a tower onto clear ground inside the ring, or select a tower and then its location. The starting radius is 240 logical points (7½ tiles). Gun, laser, and heal towers cost 5, 10, and 15 resources.
- A valid build deploys Hermes and connects the tower to his base. His cannon fires while he stays anchored. Towers need Hermes to survive.
- Make Hermes follow to close Build, return the camera to Nathaniel, reclaim all surviving connected towers, and refund 25% of each paid cost, rounded down. Map towers have no paid cost. Losing Hermes removes the base and its towers without a refund; enemy destruction also gives no refund.
- Approach Soldier bodies to collect them with Nathaniel's backpack. The starter rack holds one bundle. Use Deliver cargo or click Hermes to feed him; each accepted bundle gives 10 resources. Hermes can receive in either form. Buy separate cargo and arm-reach upgrades in Build. Bodies warn for the final 3 seconds, then self-destruct at 10 seconds. A successful grip permanently disarms them, including after a drop. See [resource gathering](docs/resource-gathering.md).
- Campaign levels start with three spare lives. Nathaniel respawns at the level start; losing Hermes ends the game. Defeat a boss to advance. Survival has no spare lives.

Desktop controls: **B** opens or closes Build, **Space** returns the camera to Nathaniel and closes Build, **R** switches Hermes between Deploy and Follow, and **S** stops Nathaniel. **Escape** cancels an armed tower first, then closes Build, then pauses; it also closes the top menu. The mouse wheel zooms. **F** or right-click fires at the pointer; the HUD Fire button uses the current target. Touch uses the HUD and world controls, with zoom buttons and a two-finger camera gesture.

Pause to save into one of three slots. Settings and campaign records are stored separately. Existing Swift saves can be imported from an explicit exported file into an empty slot; see [saves and compatibility](docs/saves.md).

## Find the right files

Start with the row for the change, then use `make help` for the command list.
Search source directories first; `assets/generated/` contains export output.

| Change | Start here | Guide / focused check |
| --- | --- | --- |
| Combat, weapons, movement or balance | `scripts/domain/game_simulation.gd`, `combat_rules.gd`, `game_balance.gd`, `world_navigation.gd` | [Domain APIs](scripts/domain/README.md); `make test-gameplay` |
| Backpack, cargo or Hermes intake | `scripts/domain/battlefield_rules.gd`, `scripts/presentation/actors/`, `tools/blender/resource_gathering.py` | [Resource gathering](docs/resource-gathering.md); `make test-resource-gathering` |
| Input, HUD or camera | `scripts/presentation/game_input.gd`, `game_ui.gd`, `game_app.gd` | [Controls](docs/web.md#character-controls); `make test-presentation` |
| Aiming, recoil or healing visuals | `scripts/presentation/actors/`, `world_effects.gd`, `resources/actors/`, `resources/weapons/` | [Weapons](docs/nathaniel-weapons.md), [tower art](docs/iron-and-ink-assets.md); `make test-nathaniel-weapons` / `make test-healing-tower` |
| Hermes shoulder laser | `scripts/presentation/actors/hermes_view.gd`, `world_effects.gd`, `resources/actors/hermes.tres`, `art/blender/sources/` | [Selected design and implementation brief](concept-art/hermes-lasers.md); `make test-hermes-base` |
| Levels, encounters or blocking cells | `levels/`, `scripts/presentation/levels/level.gd`, `spawn_marker.gd` | [Level authoring](docs/authoring.md); `make test-content` |
| Blender sources or exports | `art/blender/sources/`, `tools/blender/`, `art/blender/settings.json` | [Pipeline](docs/blender-assets.md), [terrain/buildings](docs/environment-assets.md); `make test-art` |
| Saves or Swift compatibility | `scripts/infrastructure/save_store.gd`, `swift_save_import.gd` | [Save contract](docs/saves.md); `make test-services` |
| Debug state or MCP | `scripts/presentation/debug_bridge.gd`, `scripts/infrastructure/debug_server.gd`, `game-mcp-server/` | [Debug protocol](docs/debug-interface.md); `make test-mcp` |
| Platform export or playtest | `tools/export_project.py`, `export_presets.cfg` | [Exports](docs/authoring.md#export-and-platform-checks), [testing](docs/testing.md), [dated verification](docs/verification.md) |

## Code and content

| Path | Responsibility |
| --- | --- |
| `scripts/domain/` | Gameplay state and use cases, combat, balance, navigation, snapshots |
| `scripts/presentation/` | Input, camera projection, UI, audio, effects and scene views |
| `scripts/presentation/game_app.gd` | Composition root: connects the simulation, views, and services |
| `scripts/presentation/actors/` | Actor views and visual resources |
| `scripts/presentation/levels/` | Native level resources and encounter markers |
| `scripts/infrastructure/` | Atomic files, save/settings/progress stores, Swift-save conversion and debug HTTP |
| `levels/`, `scenes/`, `resources/`, `assets/` | Editable native content and artwork |
| `art/blender/sources/`, `tools/blender/` | Saved editable models, generators and exporters; excluded from runtime import |
| `assets/generated/`, `scenes/*/generated/` | Committed runtime exports; regenerate from saved sources |
| `concept-art/` | Design references and proposals; not a record of implemented mechanics |
| `tests/`, `tools/`, `game-mcp-server/` | Automated checks, local developer tools and MCP adapter |

`GameSimulation` owns gameplay use cases and uses logical world coordinates with positive Y up. It has no scene-tree, rendering, input, or disk dependency. Presentation converts between that world and the isometric viewport. Infrastructure owns persistence and external protocols. There is no separate application wrapper around the simulation. See [architecture](docs/architecture.md) for dependencies. Read the [domain boundary](scripts/domain/README.md) before changing simulation state directly.

Use [testing](docs/testing.md) for validation and [debug/MCP](docs/debug-interface.md) for inspection and repeatable setup. The former Swift/SpriteKit and Windows Phone projects are retired from the working tree; Git commit `824c8f1` retains their source and migration provenance. Save formats and app storage identifiers remain compatible with the existing Godot edition.
