# Testing

Use native GDScript tests for gameplay rules, real computer input for controls, and the debug interface for exact state and repeatable setup. Each test process must use explicit isolated storage.

## Automated checks

```sh
make test
make test-mcp
make format-check
```

`make test` imports the root project, checks source formatting, runs Python tooling tests and native content/gameplay/persistence/presentation suites, and exercises the MCP adapter against a separate headless game. `make test-mcp` runs the adapter checks. The runners treat engine/script errors as failures even when Godot returns exit code zero. These checks do not read live saves.

Use `make test-content`, `make test-gameplay`, `make test-services`, or
`make test-presentation` for a focused headless check while editing. The
[task map](../README.md#find-the-right-files) links source paths to these checks.
`make test` is the final regression check. Asset-specific Make targets also run
graphical assertions; `make test-art` additionally starts Blender and checks
source preservation. Capture targets produce review images rather than test results.

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
2. Move Nathaniel and target an enemy. Check target feedback and that clicking Hermes cannot select him. Approach a Soldier body and check the grab, crush, and occupied rack. Leave another body to warn and dissolve; confirm that it cannot be collected after expiry. Check that a warning stops at grip and that cargo dropped after death stays safe. With cargo, click mobile Hermes or use Deliver cargo; check physical feeding and a single ten-resource credit. Repeat with deployed Hermes. Buy each backpack upgrade in Build; check separate reach and capacity effects. Move away during grab and feed to check that no body is lost or credited early.
3. Make Hermes follow, then open Build. Check that the camera focuses Hermes, the amber range appears, and he keeps following. Reject placement outside the ring and on blocked ground, then place a tower on clear ground inside the ring. Only valid placement deploys Hermes. Check the low base, raised cannon, ground cable, and stationary combat. Check that Deploy leaves Build open.
4. Make Hermes follow. Check that Build closes, the camera returns to Nathaniel, all towers and links are removed, and each surviving paid tower refunds its cost divided by four, rounded down. Hermes returns to his walking form. Check B to toggle Build, Space to return to Nathaniel without packing the base, and Escape to cancel an armed tower before closing Build or pausing.
5. Pause, open Settings, return, and resume. Exercise save/load and replacement/cancel in the isolated slots.
6. Check desktop keys and wheel zoom, touch zoom buttons, and two-finger pinch where the available input tool supports it. Check HUD input after zoom.
7. Scroll long menus; test both a drag over a button and an ordinary tap. Verify the last menu item is reachable.
8. Collect a weapon crate. Confirm that collection keeps the rifle equipped,
   then use 1/2 and the named buttons to switch. Move while aiming at enemies,
   check muzzle flashes and recoil, and save/load with the heavy rifle equipped.

Launch an exported macOS app directly, without the editor's `--path` argument:

```sh
exports/macos/Nathaniel.app/Contents/MacOS/Nathaniel -- \
  --storage-dir=/tmp/nathaniel-playtest --level=0
```

Use a fresh temporary storage directory for each test. Select this running
window in Computer Use; opening the app again can create a second instance
without the isolated-storage arguments. Current live models require a Godot
template with 3D enabled; see [Simulator limits](authoring.md#export-and-platform-checks).

Inspect rendered screenshots; an accessibility match alone does not establish visibility. Simulator automation can take time while gameplay continues, so pause between checks or prepare a repeatable scenario through debug setup. Report the platform, input method, outcome, and gestures that could not be tested.

## Debug inspection and profiling

The [debug interface](debug-interface.md) documents the opt-in loopback server, coordinates, actions, and MCP setup. Actions and fallback taps bypass OS input. `killAllEnemies` uses normal death handling and can record campaign progress; use survival and isolated storage for fixtures.

`make profile` measures the logical simulation. `make profile-rendered` measures the complete rendered game and saves a viewport image. Record hardware, engine version, workload, warmup, sample count and frame settings with results. Build success and average FPS alone do not establish input correctness or consistent frame pacing.
