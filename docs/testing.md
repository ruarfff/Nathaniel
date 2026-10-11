# Testing

Use GDScript tests for rules, real OS input for controls, and the
[debug interface](debug-interface.md) for repeatable setup. Each test process
must use isolated storage.

## Automated checks

```sh
rtk make format-check
rtk make test
```

`make test` imports the project and runs content, gameplay, persistence, input,
presentation, Python tooling, and live MCP checks. The runner fails on logged
engine/script errors even when Godot exits zero.

Use the [task map](../README.md#find-the-right-files) for focused targets.
`make test-art` also checks Blender sources and exports; asset-specific targets
include rendered assertions. `art-*` targets produce images for inspection.

For a failing native suite, use its runner directly:

```sh
rtk python3 tools/run_checked.py godot --headless --path . --script res://tests/test_gameplay.gd
```

Synthetic input checks dispatch, not OS gesture recognition. Audio assertions
check player state, not audible output. Inspect rendered screenshots for visual
acceptance.

## Native playtest

Follow [exports](authoring.md#export-and-platform-checks). Current live models
need a template with 3D enabled. Test changed flows on each available platform
and report untested platforms or gestures in the task response.

Launch the exported macOS app with fresh storage:

```sh
test_session_dir=$(rtk mktemp -d /private/tmp/nathaniel-playtest.XXXXXX)
rtk exports/macos/Nathaniel.app/Contents/MacOS/Nathaniel -- \
  --storage-dir="$test_session_dir" --level=0
```

Select that running window in Computer Use; reopening the app can start a second
instance without the isolated arguments. Use a debug build with
`--debug-port=18766` when exact state or fixtures are needed. Pause while preparing
input checks so combat does not change the scenario.

Check the flows affected by the change:

- **Movement/focus:** ground and enemy input control Nathaniel; cards and bodies
  obey [control rules](web.md#character-controls). Build gates new manual orders
  without stopping existing movement or combat. Closing clicks are consumed.
- **Gathering:** corpse selection, warning/disarm, cargo, manual delivery, and
  passive recovery follow the [resource contract](resource-gathering.md). Check
  cancellation and one credit per accepted body.
- **Build:** valid placement spends the displayed cost and returns to Build;
  invalid placement keeps its preview. Pack-up refunds surviving paid towers,
  removes them, closes Build, and resumes following.
- **Weapons:** pickups unlock without equipping; weapon buttons and 1/2 work
  with Build closed. Movement and aim remain independent.
- **Menus:** pause/resume, isolated save/load, settings, cancellation, and long
  menu scrolling. A drag over a button must not become a late click.
- **Camera/input:** desktop shortcuts and wheel zoom; touch buttons, drags, and
  pinch where supported. Check focus changes and HUD input after zoom.

Report OS input separately from synthetic checks, captures, and builds. An
accessibility match alone does not prove visibility.

## Debug and performance

Debug actions bypass OS input. `killAllEnemies` uses normal death handling and
can record campaign progress; use Survival and isolated storage for fixtures.

`make profile` measures simulation; `make profile-rendered` measures the rendered
game. Report hardware, engine, workload, warmup, samples, and frame settings.
Build success and average FPS do not establish input correctness or frame pacing.
