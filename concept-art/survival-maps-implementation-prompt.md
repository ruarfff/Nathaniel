# Implement the four survival maps

Build and integrate four authored survival maps, random map selection for new
runs, and immediate enemy pursuit for the Nathaniel demo. Complete the native
content, runtime behavior, save handling, visuals, and validation.

Work in `/Users/ruairi/dev/Nathaniel` on the current branch, verified as `main`
when this handoff was prepared. Preserve existing changes, including the map
plan and concept index. If the checkout has changed, report that before any
branch change. Create no commits, pushes, or pull requests unless requested.
Prefix shell commands with `rtk` and follow the repository's `AGENTS.md`.

## Read before implementing

Read the approved [survival map plan](survival-maps.md) for the four layouts,
deployment spaces, terrain appearance, and playtest goals. Implement its demo
scope; the later terrain experiments remain outside this task.

Use the [README task map](../README.md#find-the-right-files),
[domain guide](../scripts/domain/README.md),
[architecture](../docs/architecture.md),
[authoring guide](../docs/authoring.md), and
[save contract](../docs/saves.md) before changing the relevant boundaries.
For scenery or export changes, read [environment assets](../docs/environment-assets.md)
and the [Blender pipeline](../docs/blender-assets.md). Read
[testing](../docs/testing.md) before playtesting. Inspect current code before
editing; the behavior described in the plan is a planning-time baseline.

## Build the four maps

Author four distinct native scenes, each **52 × 52 cells at 32 logical units
per cell**: 1,664 × 1,664 logical units, approximately three times the old
30 × 30 map's area. Preserve normal unit scale and camera zoom.

| Map | Required layout and appearance |
| --- | --- |
| Abandoned Crossroads | Sandy town junction, four approaches, small ruined building groups, outer road loop, three open deployment spaces. |
| Dry Wash | Pale dry riverbed, separate rock ribs, three broad crossings, routes along both banks, no single unavoidable firing lane. |
| Freight Yard | Sandy depot, staggered warehouses and short container groups, three main lanes with broad cross-lanes and perimeter access. |
| Open Countryside | Muted grassland, tree groups, a winding country road, and three clearings. No buildings, ruins, containers, or industrial structures. |

Use the plan's A–C clearings as layout guidance, not fixed build sockets.
Each useful base site needs at least two independent approaches. Keep route
widths suitable for Hermes and bosses, including their visible silhouettes.
Countryside enemies can cross grass directly; the road does not constrain them.

Each scene needs full ground coverage, explicit collision, correct camera
bounds, valid Nathaniel and Hermes starts near a central clearing, a reachable
heavy-rifle pickup, and at least four authored enemy entry sectors with
multiple possible spawn positions. Preserve the current starting lives,
resources, weapon ranges, movement speeds, and wave budget/progression.

Deliver readable Iron & Ink terrain and scenery in all four maps. Reuse the
existing ground palette and saved Blender models. Add only the small missing
asset pieces needed for the layouts. Edit saved sources and use the normal
export pipeline. Keep native scenes authoritative at startup. A collision-only
blockout is an intermediate stage, not the completed deliverable.

Keep one flat gameplay plane and the existing terrain rules. Paint movement
blocking explicitly; sprite bounds and tree canopies do not define collision.
Keep grass quiet and crowns sparse around play areas. Shot blocking, cover,
movement costs, special build surfaces, elevation bonuses, destructible scenery,
and hazards belong to later work.

## Select and restore the correct map

Keep one survival mode. Separate its mode identity from a stable map identifier
resolved through an allowlisted catalog of the four scenes.

- **New survival run:** select once with equal 25% probability per map.
  Repeats are allowed. Normal starts must not reset selection to the same
  fixed seed. Keep a deterministic selection override for tests and captures.
- **Retry:** restart the same map from its authored initial state, including
  retries reached through buttons and keyboard handling.
- **Resume:** restore the saved map and simulation state without rerolling.
- **Legacy survival saves:** retain `levels/level_0.tscn` as their original
  30 × 30 map, outside the new-run catalog. Loading, retrying, and saving those
  runs must preserve that identity.

Save the chosen map identifier and resolve both scenery and simulation data
from it. Keep existing save format identifiers and storage identity compatible.
An unknown map identifier must fail clearly rather than substitute another
layout. Keep map-selection randomness separate from combat randomness.

The shared numeric level loader also serves retry, restore, tests, and captures;
put random choice at the new-run boundary. Show the map name briefly at run
start. Include all four maps and the legacy scene in the demo export.

## Make survival enemies attack immediately

Every mobile survival enemy must receive a valid pursuit target on spawn and
start moving toward it on the first active simulation step, even outside its
vision range. Cover grunts, soldiers, gun soldiers, bosses, later wave variants,
and spawner children through a consistent survival rule.

Use Nathaniel as the initial target. Preserve existing valid combat target
retention. If a target becomes invalid during an active run, reacquire without
a sight gate: Nathaniel first, then living Hermes. Repair missing or invalid
pursuit targets on restore. Preserve existing end-of-run outcomes.

Pursuit follows valid routes around obstacles. Firing still obeys normal range,
cooldown, and damage. Keep spawners stationary; they produce children without
requiring sight, and those children immediately pursue. A spawner's own weapon
still obeys range. Scope these rules to survival, not every wave-based level;
campaign levels can also have waves.

## Keep spawns and routes valid

Replace fixed survival spawn coordinates with the authored entry sectors.
Validate bounds, occupied space, terrain, and a usable route into the fight.
Validate nearby birth positions for spawner children as well; a fixed offset
can place them inside obstacles or outside the enlarged map.

Use bounded candidate searches. If no valid candidate exists, defer the spawn
without losing its wave budget, and expose the reason for testing. Keep a
world-space safety distance from heroes and the deployed base. Spawn validity
must not depend on camera position, screen size, or player sight.

For survival tower placement, reject a placement that seals the last route
from any enabled entry sector to the player area, including sectors unused by
the current wave. Keep validation in the domain and provide clear invalid
placement feedback. Check alternate routes after tower placement and teardown.

Keep combat and spawn state in `scripts/domain/`, with `GameSimulation` owning
entity changes. Presentation reads native markers and displays the scene.
Likely integration points are `game_simulation.gd`, `battlefield_rules.gd`,
`combat_rules.gd`, `world_navigation.gd`, the native level adapter, `game_app.gd`,
`game_input.gd`, and save validation. Use current source structure rather than
introducing a parallel map or combat system.

## Validate and finish

Add focused regression coverage for:

- All four scenes: dimensions, complete ground, starts, pickup, entry sectors,
  connectivity, camera bounds, and largest-unit clearance. Confirm Countryside
  has no building assets and canopy art does not create collision.
- Controlled random selection of all four maps, same-map retry through each
  input route, save/resume, legacy-save round trips, unknown IDs, and unchanged
  combat randomness. Avoid flaky short-run frequency tests.
- Every survival enemy kind and spawn source outside vision, late-wave
  variants, missing targets on restore, stationary spawner production,
  legal firing range, and unchanged campaign acquisition.
- Blocked spawn candidates, deferred births, spawner child placement, and
  attempted tower route sealing across every enabled sector.
- Nathaniel movement, build/teardown, cargo delivery, and Hermes recovery
  around the new obstacles. Preserve existing resource and corpse rules.

Run `rtk make format-check` and the relevant targets: `test-content`,
`test-gameplay`, `test-resource-gathering`, `test-services`, `test-presentation`,
`test-demo`, and `test-environment-art`, then the full `rtk make test` suite.
Use `rtk make help` for current export and capture commands. Update intended
survival content baselines while preserving campaign checks.

Play each map with the same wave seeds. Compare first contact, peak enemy
count, frame time, base relocation, and resource recovery. Include the new
terrain layouts in profiling; an open-ground stress test is insufficient.
Correct long empty approaches or dominant camping sites through layout first.

Export and run desktop and web where supported. Verify real mouse, keyboard,
and available touch input; report iOS and any other untested platform plainly.
Capture each finished map at gameplay zoom. Update runtime authoring and save
documentation to describe the implemented behavior.

Finish with the changed files, screenshots, test and export results, and any
remaining limitations. Completion requires all four playable maps, correct
new-run/retry/resume identity, immediate pursuit, and valid spawn routes.
