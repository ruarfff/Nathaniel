# Testing

Use XCTest for gameplay rules, computer use for real input, and the small debug interface for exact state and test setup.

## Automated checks

- `make test-unit`: macOS XCTest suite, including gameplay, saves, menus, camera input, and isolated HTTP transport tests.
- `make test-tooling`: build-command tests with stubbed platform tools.
- `npm --prefix game-mcp-server test`: MCP stdio integration tests against an isolated HTTP fixture. No running game is required.
- `make test`: resource/map checks on macOS, then an iOS Simulator launch and screenshot. These smoke checks do not establish gameplay correctness.

See [automation.md](automation.md) for build paths and smoke-test options.

## Computer-use playtest

Build and launch with `make macos` and `make ios`. On each platform:

1. Open Level Select and start a level through the visible menus.
2. Move Nathaniel, target an enemy, and switch camera focus to Hermes.
3. Make Hermes stop. Open Build and drag a tower to clear ground.
4. Make Hermes follow. Check that his towers disappear and each refunds 25% of its build cost, rounded down.
5. Pause, open Settings, return to Pause, and resume. Inspect the save selector and cancel without replacing existing saves.
6. Check desktop wheel zoom and iOS pinch zoom where the available input tools support the gesture. Verify HUD buttons still work after zoom.

Use screenshots to inspect the visible UI. Accessibility may expose hidden SpriteKit labels, so an accessibility match alone does not prove a control is visible. Simulator automation can take seconds while gameplay continues; pause between checks or use debug setup to prepare a repeatable situation. Report the platform and any input that could not be tested.

Known desktop limitation: the HUD assumes a landscape window and does not relayout when the window changes shape. Narrow windows and some full-screen transitions can clip controls.

## Debug inspection and setup

The DEBUG-only `GameCommandServer` uses port 8765 on macOS and iOS Simulator. Run only one game instance when using this port. Release builds omit the interface. Configure the optional MCP adapter as described in [its README](../game-mcp-server/README.md).

Start with `game_state` and `game_list_actions`. State includes score, lives, resources, elapsed time, pause/result status, player positions and health, enemy count, Hermes mode, and tower count. Gameplay-only fields are omitted in menu scenes.

`game_action` supports `loadLevel`, `mainMenu`, `pause`, `resume`, `spawnEnemy`, `killAllEnemies`, `healPlayer`, `addResources`, and `setHermesMode`. Discovery returns the actions available in the current scene and their parameter hints. Pass parameter values as strings. For example:

```json
{"name":"loadLevel","params":{"level":"1"}}
```

`loadLevel` accepts campaign levels 1–5 and survival level 0. It starts a fresh scene without changing saves. `mainMenu` discards the current unsaved session. `killAllEnemies` uses normal death handling and can record campaign completion; use survival for automated fixtures that must not change campaign progress. Setup actions bypass UI; their success does not prove the corresponding button or gesture works.

`game_nodes` returns names and bounds in SpriteKit scene coordinates (origin at bottom-left). Covered controls are excluded while a modal menu is open. `game_tap` accepts a node name or scene x,y. `game_swipe` is a fallback for tower dragging; elsewhere it taps the endpoint. It does not simulate OS gesture recognition or elapsed drag time. Use computer use for real input validation.

`game_screenshot` captures the SpriteKit scene as a PNG. Inspect screenshots directly; this project does not maintain image baselines or pixel-diff tests.

## Maintaining the interface

Keep setup actions in `GameDebugAction`. Its enum is the source for both dispatch and discovery. Prefer exposing a missing value in structured state to adding another query action. Add gameplay regression tests directly in XCTest.

The HTTP transport accepts one request per connection, buffers fragmented requests, and uses `Content-Length`. It limits headers to 16 KiB and bodies to 16 MiB and rejects transfer encoding. The MCP client supplies the HTTP framing.
