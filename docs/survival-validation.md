# Survival maps implementation and validation

Implemented on 2026-10-11 on `main`. Existing concept-plan changes were kept.
No commit, push, pull request, or remote deployment was created.

## Delivered behavior

Four native 52×52 maps use 32 logical points per cell and the existing unit
scale, camera zoom, lives, resources, weapons, speeds and wave progression.
New Survival runs select each map with 25% probability. Retry keeps the map;
resume restores its identity and simulation state. The original 30×30 map
remains available to legacy saves and `load_level(0)`.

Resume takes static terrain and entry data from the selected native scene,
then restores dynamic state. A stale embedded level definition cannot replace
the scene's collision or bounds. Unknown map IDs fail validation.

Every mobile Survival enemy receives pursuit intent on spawn. Invalid targets
are repaired without a sight check; firing still uses normal range and cooldown.
Stationary spawners produce children without sight. Spawn candidates must fit
the terrain, avoid occupied space and the player base, and reach the fight.
Blocked births retain their budget. A tower cannot close the last route from
any enabled entry sector.

## Changed files

| Area | Files |
| --- | --- |
| Native maps | `levels/survival/abandoned_crossroads.tscn`, `dry_wash.tscn`, `freight_yard.tscn`, `open_countryside.tscn` |
| Map catalog and rules | `scripts/domain/survival_map_catalog.gd`, `game_simulation.gd`, `combat_rules.gd`, `battlefield_rules.gd`, `world_navigation.gd`, `game_balance.gd` |
| Loading, input and UI | `scripts/presentation/game_app.gd`, `game_input.gd`, `game_ui.gd`, `debug_bridge.gd`, `levels/level.gd`, `level_definition.gd`, `spawn_marker.gd` |
| Persistence | `scripts/infrastructure/save_store.gd` |
| Saved art | `art/blender/sources/environment_container.blend`, `environment_rail.blend`, `environment_rock_shelf.blend`, their creation scripts under `tools/blender/`, and pipeline exports under `assets/generated/` and `scenes/scenery/generated/` |
| Regression checks | `tests/test_survival_maps.gd`, `test_survival_rules.gd`, `test_survival_identity.gd`, `test_survival_play.gd`, plus existing environment, gameplay, cargo-control and live MCP checks |
| Profiling and capture | `tests/profile_survival.gd`, `tests/profile_rendered.gd`, `tools/render_survival_maps.gd`, `Makefile` |
| Runtime documentation | `README.md`, `scripts/domain/README.md`, `docs/authoring.md`, `saves.md`, `environment-assets.md`, `testing.md`, `debug-interface.md` |

The six original scenes and their terrain/scenery baselines remain intact.
Countryside contains only natural scenery. Canopy bounds add no collision.

## Captures

All four gameplay captures use a fixed 1280×800 viewport, camera zoom 1.0, and
fog disabled for inspection. Full-map overviews show routes and clearing spacing.

| Map | Gameplay view | Full-map overview |
| --- | --- | --- |
| Abandoned Crossroads | [PNG](../test-artifacts/survival-maps/abandoned_crossroads.png) | [PNG](../test-artifacts/survival-maps/abandoned_crossroads-overview.png) |
| Dry Wash | [PNG](../test-artifacts/survival-maps/dry_wash.png) | [PNG](../test-artifacts/survival-maps/dry_wash-overview.png) |
| Freight Yard | [PNG](../test-artifacts/survival-maps/freight_yard.png) | [PNG](../test-artifacts/survival-maps/freight_yard-overview.png) |
| Open Countryside | [PNG](../test-artifacts/survival-maps/open_countryside.png) | [PNG](../test-artifacts/survival-maps/open_countryside-overview.png) |

The art review replaced regular Dry Wash wedges with fractured rock faces.
Saved Blender sources were edited and exported through the normal pipeline.

## Automated validation

`make format-check`, `test-content`, `test-gameplay`, `test-resource-gathering`,
`test-services`, `test-presentation`, `test-demo`, `test-environment-art`, and
the full `make test` suite passed. The full suite includes Python tooling,
Node tests and live MCP integration. Additional Survival checks cover native
connectivity, all enemy footprints, map identity, deferred births, route sealing,
movement between clearings, build/teardown, cargo, and Hermes recovery.

The final run passed 262 map checks, 196 Survival rules checks, 112 identity
checks, 132 Survival play checks, and 155 live MCP checks. The existing suites,
six Node tests, and 16 Python tests also passed.

Logs are under `test-artifacts/`: `survival-full-test-final.log`,
`survival-full-test-final-continuation.log`, `survival-full-test.log`,
`survival-full-test-continuation.log`, `survival-targets.log`, and
`survival-final-gameplay.log`. Godot needed normal macOS access for certificate
and editor settings operations; the initial sandboxed import failed on those
host operations. The approved run passed.

## Performance and layout checks

Hardware: Apple M4 Pro; Godot 4.7.2 stable; macOS; OpenGL compatibility renderer.
The simulation profile runs seeds 137 and 733 for six minutes per map at 60 Hz,
with 60 warmup frames. Nathaniel stays at the start and Hermes is deployed.
Hero HP is raised to preserve the workload. Weapons, wave cadence and matter
rules are unchanged. Identical seeds do not guarantee identical later enemy
rosters: retry searches consume random values according to the layout.

The profile exposed and corrected spawner footprint rejection and a queue
that let one blocked spawner stop later valid births. Entry candidates were
then spread to reduce congestion without changing wave budgets.

Each range below contains the two seed results. First contact means the first
enemy hit on either hero. Pending enemies retain their wave budget; they are
delayed by occupancy or other placement checks.

| Map | First contact (s) | Peak enemies | Final pending | Delivered bodies | Simulation p95 (ms) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Original Survival | 9.48–9.68 | 110–122 | 25–35 | 1–2 | 0.88–0.89 |
| Abandoned Crossroads | 18.58–20.05 | 131–160 | 15–19 | 13–21 | 1.70–2.21 |
| Dry Wash | 7.13–18.47 | 122–143 | 15–20 | 27–31 | 2.34–3.05 |
| Freight Yard | 16.63–25.45 | 117–125 | 16–22 | 27–30 | 2.85–4.40 |
| Open Countryside | 10.33–12.87 | 118–140 | 14–26 | 25–32 | 1.77–3.12 |

The revised entries reduced final pending counts from 27–74 to 14–26 on the
new maps. One simulation sample reached 126.15 ms on Freight Yard. These runs
used a shared development desktop, so maxima can include other host work.
They establish behavior and expose performance limits, not a hardware baseline.

Final measurements are in
[simulation-profile.json](../test-artifacts/survival-maps/simulation-profile.json)
and [rendered-profile.json](../test-artifacts/survival-maps/rendered-profile.json).
The opening-wave capture measures 360 drawn frames after 60 warmup frames,
with a 60 FPS cap and VSync off. It does not establish late-wave performance.
Final median frame intervals were 16.60–16.75 ms; p95 was 17.96–20.54 ms.
The first map, Crossroads, had a 187.05 ms peak. The other maps peaked at
20.72–23.86 ms in the same process; this does not isolate the cause of the hitch.

The separate stress test retains 200 enemies and 30 towers on each authored
layout for 600 measured frames after 60 warmup frames, with high HP, waves and
fog disabled, and zoom 0.55. Its actual window size is recorded in each JSON
under `test-artifacts/rendered-profile/`. This workload exceeds the tested
renderer’s frame budget: median drawn-frame intervals were 192–200 ms, and
p95 intervals were 256–284 ms. The first three windows were 1133×1361;
Countryside was 848×1361 after the window manager retiled the desktop.
These stress runs establish a large-battle performance limit, not a controlled
comparison between layouts. Do not treat opening-wave results as a guarantee
for large battles.

### Stress-test performance work

The follow-up profile fixes the render viewport at 1280×800 so desktop window
tiling cannot change the measured workload. It keeps the same 200 enemies,
30 towers, two heroes, normal combat, 60 Hz physics, 60 FPS cap, and VSync off.
Runs use 60 warmup draw frames and 600 measured draw frames. Performance changes
are in presentation and asset export; damage, health, movement, attack ranges,
cooldowns, wave budgets, and simulation tick rate are unchanged.

Profiling found repeated animation seeks, full-army laser scans on individual
hits, and repeated canvas redraws during physics catch-up. Pose sampling now
skips unchanged samples; each hit reads only its emitter; unchanged actor and
Hermes ground geometry retain their drawing commands. Active effects draw once
per displayed frame while direct calls retain immediate redraw behavior.
Mounted aiming runs once per direct update, and unchanged gathering poses no
longer invalidate the hero model viewports.

The saved-source exporter also batches rigid geometry in the soldier, gun
soldier, and boss models. Mesh counts fall from 171 to 41 across the three
assets. Saved Blender sources and PNGs are unchanged. Indexed geometry matched
within 1.1×10⁻⁶ model units; animation payloads and material data matched exactly.
At this intermediate stage, twelve idle, walking, aiming, and recoil/aperture poses differed by
at most 12 edge pixels per 81,920-pixel model image. See the
[before/after comparison](../test-artifacts/model-batching-before/comparison.png).

The final export combines compatible opaque paint materials using vertex
colors, reducing the three models from 148 to 50 surfaces. It retains the
10,354 triangles, control hierarchy, animation payloads, and source artwork.
The import adapter restores source colors before sRGB byte packing; it changes
only color bytes and material flags, preserving geometry, UVs, LODs and shadow
meshes. There is no palette conversion during gameplay.

The final 12-pose comparison uses normal `ResourceLoader` imports. Mean channel
error ranged from 0.000175 to 0.000702 on a 0–1 scale; 26–412 pixels per
81,920-pixel image differed by more than 1/255. Visual review found matching
shape, pose, shadows and colors, including dark joints and gun bores. See the
[final imported-model comparison](../test-artifacts/model-palette-before/comparison.png).

| Crossroads measurement | Median frame (ms) | p95 frame (ms) | Median physics tick (ms) | Measured physics ticks |
| --- | ---: | ---: | ---: | ---: |
| Fixed-viewport baseline | 164.332 | 232.651 | 15.511 | 4,800 |
| Pose, laser, and redraw fixes | 49.248 | 98.960 | 6.670 | 1,972 |
| Rigid mesh and gathering fixes | 40.373 | 73.881 | 6.170 | 1,541 |
| Final material batching | 36.423 | 57.628 | 6.247 | 1,349 |

The final Crossroads median frame interval is 77.8% lower than the fixed-viewport
baseline, with a 75.2% lower p95. Maximum reported draw calls fell from 31,459
to 9,575. This stress case still exceeds the 16.7 ms budget for 60 FPS on this
machine. No shadow quality or animation-rate reduction was applied.

All four final runs used the same fixed viewport and normal project settings:

| Map | Median frame (ms) | p95 frame (ms) | Maximum frame (ms) | Measured physics ticks |
| --- | ---: | ---: | ---: | ---: |
| [Abandoned Crossroads](../test-artifacts/rendered-profile/rendered-profile-abandoned_crossroads-final.json) | 36.423 | 57.628 | 66.828 | 1,349 |
| [Dry Wash](../test-artifacts/rendered-profile/rendered-profile-dry_wash-final.json) | 34.904 | 56.276 | 70.846 | 1,334 |
| [Freight Yard](../test-artifacts/rendered-profile/rendered-profile-freight_yard-final.json) | 34.397 | 56.313 | 66.622 | 1,318 |
| [Open Countryside](../test-artifacts/rendered-profile/rendered-profile-open_countryside-final.json) | 31.674 | 54.532 | 64.517 | 1,221 |

The baseline and intermediate reports are
[before](../test-artifacts/rendered-profile/rendered-profile-abandoned_crossroads-before.json)
and [after redraw fixes](../test-artifacts/rendered-profile/rendered-profile-abandoned_crossroads-after-redraw.json).
The [final Crossroads report](../test-artifacts/rendered-profile/rendered-profile-abandoned_crossroads-final.json)
uses normal project render settings. All retained 232 entities. The simulation runs in real time, so these
fixed draw-frame samples cover different numbers of physics ticks and different
later combat states. They compare the same fixture, not an identical state trace.
No other game test ran during these measurements. The desktop was shared with
normal host applications.

Focused final checks passed: 233 palette-import checks, 230 rendered enemy-laser
checks, 72 rendered gun-soldier checks, and 30 Python tests. Import tests cover
saved-resource reloads, unsupported input, repeated conversion, and preservation
of non-color geometry bytes, LODs, and shadow meshes.

The final `make test format-check` passed 7,805 GDScript/live MCP checks,
30 Python tests, and six Node tests, with no failures or logged engine errors.
See [the complete test log](../test-artifacts/performance-full-test-palette.log).

## Exports and input

Local macOS and Web Demo release exports succeeded. Outputs are
`exports/macos/Nathaniel.app` and `exports/web-demo/index.html` with companion
files. Export logs are in `test-artifacts/survival-exports.log`.

Real macOS mouse/keyboard input verified movement, heavy-rifle collection,
the Build shortcut, tower placement, teardown/refund, weapon selection, pause,
save, and load. The loaded run kept Abandoned Crossroads and its resources.
The test used `/private/tmp/nathaniel-survival-desktop-20261011` storage.

The Web Demo ran in the in-app browser at 1280×800 from a fresh loopback origin
on port 18061. Browser mouse/keyboard input verified new-run selection,
movement, Build, tower placement, teardown, pause, save, and load. All four
maps also ran through automated gameplay-zoom captures and domain play checks.
After the final rebuild, the native release ran Dry Wash and the Web Demo
restored the earlier Crossroads save with its resources and elapsed time.
No browser console errors were reported. The test app and local server were
then stopped.

After the performance fixes, both release targets were rebuilt from clean,
isolated project and editor caches. This verified that the palette import
script is present in release staging. See
[performance-exports.log](../test-artifacts/performance-exports.log).
The new native release ran Dry Wash with isolated storage at
`/private/tmp/nathaniel-performance-desktop-20261011`. The new Web Demo ran
Open Countryside at a fresh loopback origin on port 18063. Real mouse movement,
keyboard pause, and mouse resume worked on both. Native logs and browser console
checks found no errors. These were release smoke checks, not new browser stress
measurements. The test app, browser tab, and local server were stopped afterward.

iOS, physical-device touch, pinch gestures, and other browsers were not tested.
The installed iOS Simulator template lacks the 3D support required by the
current live models. Stationary high-HP profiles and automated movement checks
do not replace extended human balance testing of relocation and camping sites.
