# Nathaniel

An isometric strategy/action game built with Godot. Control Nathaniel and his robot companion Hermes through five campaign levels and survival mode.

## Run and develop

Use **Godot 4.7.2 stable**. Python 3 and Node.js 18+ with npm are used by the checks and developer tools. iOS exports also need Xcode and matching Godot export templates.

```sh
npm --prefix game-mcp-server ci  # Install the test adapter dependencies once
make                      # Run the game
make editor               # Open the visual editor
make level LEVEL=1        # Start a campaign level; 0 is survival
make test                 # Native content, gameplay, saves, UI, tooling and MCP
make format-check
make profile              # Simulation workload
make profile-rendered     # Rendered workload and screenshot
make export-macos         # Local release app
make export-ios           # Unsigned Xcode project
make help                 # Commands and options
```

Open `project.godot` directly in the editor if preferred. Native scenes in `levels/` are authoritative: edit a level and press **F6** to play it. **F5** opens the menu. `make import` refreshes Godot's resource imports.

Exports go to `exports/macos/Nathaniel.app` and `exports/ios/Nathaniel.xcodeproj`. [Authoring and exports](docs/authoring.md) covers scene editing, templates, and iOS setup. [Verification](docs/verification.md) records the tested platforms and remaining device checks.

## Play

- Click or tap the ground to move Nathaniel; select an enemy to target it.
- Select Hermes to focus the camera. He starts stationary in build mode. Focus does not change his mode.
- Stop Hermes and select him to open Build. Drag a tower onto clear ground. Gun, laser, and heal towers cost 5, 10, and 15 resources.
- Make Hermes follow to remove his surviving towers and refund 25% of each paid cost, rounded down. Enemy destruction gives no refund.
- Collect Soldier corpses with Nathaniel, then contact stationary Hermes to deliver them. Each is worth 10 resources. Loose corpses expire after 10 seconds; carried corpses do not.
- Campaign levels start with three spare lives. Nathaniel respawns at the level start; losing Hermes ends the game. Defeat a boss to advance. Survival has no spare lives.

Desktop controls: **Space** switches focus, **R** changes Hermes mode, **S** stops Nathaniel, **Escape** pauses or closes the top menu, and the mouse wheel zooms. **F** or right-click fires at the pointer; the HUD Fire button uses the current target. Touch uses the HUD and world controls, with zoom buttons and a two-finger camera gesture.

Pause to save into one of three slots. Settings and campaign records are stored separately. Existing Swift saves can be imported from an explicit exported file into an empty slot; see [saves and compatibility](docs/saves.md).

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
| `tests/`, `tools/`, `game-mcp-server/` | Automated checks, local developer tools and MCP adapter |

`GameSimulation` owns gameplay use cases and uses logical world coordinates with positive Y up. It has no scene-tree, rendering, input, or disk dependency. Presentation converts between that world and the isometric viewport. Infrastructure owns persistence and external protocols. There is no separate application wrapper around the simulation. See [architecture](docs/architecture.md) for dependencies. Read the [domain boundary](scripts/domain/README.md) before changing simulation state directly.

Use [testing](docs/testing.md) for validation and [debug/MCP](docs/debug-interface.md) for inspection and repeatable setup. The former Swift/SpriteKit and Windows Phone projects are retired from the working tree; Git commit `824c8f1` retains their source and migration provenance. Save formats and app storage identifiers remain compatible with the existing Godot edition.
