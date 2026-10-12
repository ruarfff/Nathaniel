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

`make test-survival` checks all four native maps, map selection/retry/restore,
legacy identities, pursuit and birth rules, route protection, and movement,
building, cargo and Hermes recovery on authored terrain. The original scene
and campaign baselines remain separate.

`make test-research` checks tech conservation, ownership, reach and navigation,
the center singleton, rank effects, paused purchases, nested pause owners,
native menu input, old saves, real JSON round trips, and the full loop on each
Survival map. It also checks 667×375 output with desktop and mobile virtual
viewports; Research controls must remain at least 48 display pixels high.
Tests use temporary storage. `make test-research-art` validates
saved Blender sources, controls, export hashes, and bounded geometry.
`make art-research` captures the world and menu at desktop and landscape phone
sizes. `make profile-research` writes `test-artifacts/research/profile.json` for
10,000 drops and a six-minute spawner fixture. The fixture kills each child
immediately, so its income excludes combat risk and travel cost.

`make profile-survival` compares seeds 137 and 733 for six simulated minutes
on the original map and all four new layouts. Hero HP is raised so each run
reaches the later waves; normal weapons, wave cadence, and resource rules stay
active. Nathaniel holds the start while Hermes is deployed. The report records
first enemy hit, peak enemies, recovered matter, and simulation frame times.
This is a repeatable stationary-base workload, not a full balance playtest.

`make art-survival` captures each map at 1280×800 and normal camera zoom, then
measures 360 rendered opening-wave frames after 60 warmup frames. Fog is off
for art review; the frame cap is 60 and VSync is off. Reports and PNGs go to
`test-artifacts/survival-maps/`. Check relocation and input separately.

The existing 200-enemy/30-tower rendered stress test also accepts an authored
map. Its JSON includes the actual viewport, hardware, samples, and frame cap:

```sh
rtk godot --path . --script res://tests/profile_rendered.gd -- --survival-map=freight_yard
```

Reports and images use the map ID under `test-artifacts/rendered-profile/`.
The profile disables waves and raises unit HP to retain the workload. It is
separate from the normal wave comparison and opening-wave captures.

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

The rendered stress test uses a fixed 1280×800 render viewport, 60 physics ticks
per second, a 60 FPS cap, and VSync off. It retains 200 enemies, 30 towers, and
both heroes with high HP; waves and fog are disabled. Normal movement, aiming,
attacks, effects, and animations run. It warms up for 60 drawn frames and measures
600 more. Run one graphical workload at a time:

```sh
rtk python3 tools/run_checked.py godot --path . --script res://tests/profile_rendered.gd -- --survival-map=abandoned_crossroads --label=baseline
```

Reports and captures go to `test-artifacts/rendered-profile/`. `--frames=N`
changes the sample count. Reports include wall frame intervals, engine time,
GameApp physics and view-sync time, draw calls, entity count, and elapsed physics
ticks. The simulation runs in real time: faster rendering changes the number of
physics ticks in a fixed number of drawn frames. Compare the same map and fixture,
and report that limit; this is not an identical simulation trace.

`--diagnostic=frozen-models` disables primary actor model updates and rendering
after warmup. It also skips their render-time pose work; mobile Hermes keeps its
separate model viewport. Use this as a lower-bound diagnostic, not an isolated
GPU measurement or playable performance result.
`--shadow-size=N` overrides the global directional shadow atlas for a diagnostic
run; the report records its size. Omit it for normal project settings.
