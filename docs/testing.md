# Testing

Use native GDScript tests for gameplay rules, real computer input for controls, and the debug interface for exact state and repeatable setup. Each test process must use explicit isolated storage.

## Automated checks

```sh
make test
make test-mcp
make format-check
```

`make test` imports the root project, checks source formatting, runs Python tooling tests and native content/gameplay/persistence/presentation suites, and exercises the MCP adapter against a separate headless game. `make test-mcp` runs the adapter checks. The runners treat engine/script errors as failures even when Godot returns exit code zero. These checks do not read live saves.

Run a native suite directly when investigating a failure:

```sh
python3 tools/run_checked.py godot --headless --path . --script res://tests/test_gameplay.gd
python3 tools/run_checked.py godot --headless --path . --script res://tests/test_services.gd
python3 tools/run_checked.py godot --headless --path . --script res://tests/test_presentation.gd -- --storage-dir="$(mktemp -d /tmp/nathaniel-presentation.XXXXXX)"
```

Presentation tests instantiate the actual scenes and check menu paths, all three slots, settings, input dispatch, scrolling, and camera conversion. Synthetic input proves event dispatch, not OS gesture recognition. Audio assertions inspect player state, not audible output. The [verification record](verification.md) distinguishes prior evidence from current checks.

## Real input playtest

Use [export instructions](authoring.md#export-and-platform-checks) to build and run macOS and iOS. Launch a debug build with an explicit unused `--storage-dir` before save or progression checks. Add `--debug-port=18766` for state inspection when needed. On each platform:

1. Start a campaign level and survival through visible menus.
2. Move Nathaniel, target an enemy, and switch camera focus to Hermes.
3. Stop Hermes, open Build, and drag a tower onto clear ground. Check placement rejection on blocked ground.
4. Make Hermes follow. Check tower removal and the rounded 25% refund for each surviving paid tower.
5. Pause, open Settings, return, and resume. Exercise save/load and replacement/cancel in the isolated slots.
6. Check desktop keys and wheel zoom, touch zoom buttons, and two-finger pinch where the available input tool supports it. Check HUD input after zoom.
7. Scroll long menus; test both a drag over a button and an ordinary tap. Verify the last menu item is reachable.

Inspect rendered screenshots; an accessibility match alone does not establish visibility. Simulator automation can take time while gameplay continues, so pause between checks or prepare a repeatable scenario through debug setup. Report the platform, input method, outcome, and gestures that could not be tested.

## Debug inspection and profiling

The [debug interface](debug-interface.md) documents the opt-in loopback server, coordinates, actions, and MCP setup. Actions and fallback taps bypass OS input. `killAllEnemies` uses normal death handling and can record campaign progress; use survival and isolated storage for fixtures.

`make profile` measures the logical simulation. `make profile-rendered` measures the complete rendered game and saves a viewport image. Record hardware, engine version, workload, warmup, sample count and frame settings with results. Build success and average FPS alone do not establish input correctness or consistent frame pacing.
