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

See [authoring and exports](docs/authoring.md) for scene editing, templates, platform limits, and export paths.

The [browser version](docs/web.md) uses the same game and runs from a static web server. Export it, run `make serve-web`, then open <http://127.0.0.1:8060/>. Browser saves are separate from native saves.

The [web demo](docs/web.md#survival-demo) shows demo mode and offers Survival only.
Use `make export-web-demo` and `make serve-web-demo` to preview it. The regular
exports retain the full campaign and Survival.

The [Railway demo deployment](docs/railway.md) builds and tests the web demo in
Docker, then serves its exported files with Caddy. Use `make image-demo` to
check the same image locally.

## Play

- Nathaniel is always the controlled character. Tap his card or body to focus
  him and close Build. The smaller target portrait is part of the same button.
- Tap Hermes's card to focus him and open Build. Click away from his ring to
  close it and return the camera and controls to Nathaniel. That click is consumed.
  World taps on Hermes never open Build.
- With Build closed and Nathaniel carrying cargo, tap Hermes to deliver immediately.
  Repeated taps keep that action. Collection stays automatic at backpack reach.
- Hermes's ring offers Gun, Laser and Heal for 5, 10 and 15 matter. Select a
  tower, then tap clear ground inside his range. Only a valid placement deploys
  Hermes and spends matter, then returns to Build so you can place another tower.
  Cancel returns to Build; Nathaniel's card or body discards the preview and closes it.
- Pack up & move reclaims surviving connected towers, refunds one quarter of
  each paid cost rounded down, closes Build, and resumes following Nathaniel. Check the
  displayed refund first. Backpack upgrades remain in the separate command tray.
- Use the weapon buttons with Build closed. Collect the heavy rifle
  crate to unlock it. Settings and the empty ability position stay inactive.
- With Build closed, ground taps move Nathaniel and enemy taps target for him.
  Build temporarily disables new manual Nathaniel commands. Existing orders
  and automatic combat continue.
- Campaign levels have three spare lives. Losing Hermes ends the game. Defeat
  a boss to advance. Survival has no spare lives.

Desktop: **B** opens/closes Hermes's ring, **Space** focuses Nathaniel, **R**
deploys/packs Hermes, **S** stops Nathaniel, **1 / 2** select weapons, and
**F** or right-click fires at the pointer. **Escape** returns from placement to
Build, then closes commands, then pauses. Use the wheel or zoom buttons to zoom; touch
also supports a two-finger camera gesture. See the
[control rules](docs/web.md#character-controls) for focus and cancellation.

Pause to save into one of three slots. Settings and campaign records are stored separately. Existing Swift saves can be imported from an explicit exported file into an empty slot; see [saves and compatibility](docs/saves.md).

## Find the right files

Start with the row for the change, then use `make help` for the command list.
Search source directories first; `assets/generated/` contains export output.

| Change | Start here | Guide / focused check |
| --- | --- | --- |
| Character stats, tower stats or balance | `scripts/domain/game_balance.gd` | [Balance reference](docs/balance.md); `make test-gameplay` |
| Combat, weapons or movement | `scripts/domain/game_simulation.gd`, `combat_rules.gd`, `world_navigation.gd` | [Domain APIs](scripts/domain/README.md); `make test-gameplay` |
| Backpack, cargo or Hermes intake | `scripts/domain/battlefield_rules.gd`, `scripts/presentation/actors/`, `tools/blender/resource_gathering.py` | [Resource gathering](docs/resource-gathering.md); `make test-resource-gathering` |
| Input, HUD or camera | `scripts/presentation/game_input.gd`, `game_ui.gd`, `game_app.gd` | [Controls](docs/web.md#character-controls); `make test-presentation` |
| Aiming, recoil or healing visuals | `scripts/presentation/actors/`, `world_effects.gd`, `resources/actors/`, `resources/weapons/` | [Weapons](docs/nathaniel-weapons.md), [tower art](docs/iron-and-ink-assets.md); `make test-nathaniel-weapons` / `make test-healing-tower` |
| Hermes shoulder laser | `scripts/presentation/actors/hermes_view.gd`, `world_effects.gd`, `resources/actors/hermes.tres`, `art/blender/sources/` | [Selected design and implementation brief](concept-art/hermes-lasers.md); `make test-hermes-base` |
| Levels, encounters or blocking cells | `levels/`, `scripts/presentation/levels/level.gd`, `spawn_marker.gd` | [Level authoring](docs/authoring.md); `make test-content` |
| Blender sources or exports | `art/blender/sources/`, `tools/blender/`, `art/blender/settings.json` | [Pipeline](docs/blender-assets.md), [terrain/buildings](docs/environment-assets.md); `make test-art` |
| Saves or Swift compatibility | `scripts/infrastructure/save_store.gd`, `swift_save_import.gd` | [Save contract](docs/saves.md); `make test-services` |
| Debug state or MCP | `scripts/presentation/debug_bridge.gd`, `scripts/infrastructure/debug_server.gd`, `game-mcp-server/` | [Debug protocol](docs/debug-interface.md); `make test-mcp` |
| Platform export or playtest | `tools/export_project.py`, `export_presets.cfg` | [Exports](docs/authoring.md#export-and-platform-checks), [testing](docs/testing.md) |

## Code and content

[Architecture](docs/architecture.md) defines the domain, presentation, and
infrastructure boundaries. Read the [domain APIs](scripts/domain/README.md)
before changing gameplay state. Native scenes/resources and saved Blender files
are authoritative; generated assets are exports. Concept art records design
references, while the implementation guides describe current behavior.

Use [testing](docs/testing.md) for validation and [debug/MCP](docs/debug-interface.md) for inspection and repeatable setup. The former Swift/SpriteKit and Windows Phone projects are retired from the working tree; Git commit `824c8f1` retains their source and migration provenance. Save formats and app storage identifiers remain compatible with the existing Godot edition.
