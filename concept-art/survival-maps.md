# Survival demo map plan

Create four authored survival maps: **Abandoned Crossroads**, **Dry Wash**,
**Freight Yard**, and **Open Countryside**. The first three use a sandy Earth
setting; the fourth adds grassland, trees, and a road, with no buildings.
They test open defense, crossing control, connected lanes, and movement between
clearings. All four use the same survival rules and enemy roster.

The user confirmed **three times the current area** on 2026-10-11. Use
**52 × 52 cells** per map. Keep unit scale, weapon ranges, movement speed, and
normal camera zoom unchanged. The four map directions and demo scope are
approved for implementation. Refine exact layouts during blockout testing;
later terrain mechanics remain proposals. This design pass changes no gameplay
or native level scenes. Use the [implementation handoff](survival-maps-implementation-prompt.md)
to build the approved demo scope.

## Size and useful space

The current [survival scene](../levels/level_0.tscn) is 30 × 30 cells at
32 logical units per cell: 960 × 960 units. It has 900 ground cells, 52 blocked
cells, and six tree props. Most of the center is open.

The new footprint is 2,704 cells, or 1,664 × 1,664 logical units: **3.004 times
the current area**. The four extra cells above the 2,700-cell target keep the
map square. This measures the map boundary; blocked terrain reduces the
walkable area. Track both areas so added terrain does not consume the expansion.

Keep broad open routes and three useful deployment spaces on each map. A
starting target is 8–15% blocked cells, with similar walkable area across the
four layouts. Countryside can use fewer blocked cells if its arrival times
and pressure remain comparable. Adjust this after blockout testing. Place
visual rubble and ground detail outside the collision layer when they should
remain walkable.

The larger map should support retreat, flanking, and a new base position.
It should not require a long walk before combat. Start Nathaniel and Hermes
together near a useful central clearing. Retain the current starting resources,
lives, and heavy-rifle pickup opportunity on all four maps. Give the pickup a
comparable short route from the start.

## Four proposed maps

The layouts use one flat gameplay plane. North and south below refer to the
top-down planning view; the game keeps its current isometric projection.
Each named base site is an ordinary clearing, not a fixed build socket or
special bonus tile. The player remains free to deploy elsewhere.

| Map | Main structure | Decision to test | Main landmark |
| --- | --- | --- | --- |
| Abandoned Crossroads | Four roads, broken town blocks, outer loop | Wide firing area or a more restricted approach? | Ruined shop at the junction |
| Dry Wash | Winding dry channel, broken rock ribs, three crossings | Hold one crossing or move between banks? | Exposed rock shelf and dead trees |
| Freight Yard | Three lanes, staggered warehouses, two cross-lanes | Concentrate fire or preserve room to retreat? | Roofless freight warehouse |
| Open Countryside | Grass meadows, tree groups, winding road | Hold an exposed meadow or move between clearings? | A broad road bend beside a grove |

### Abandoned Crossroads

Use a small desert town where two cracked roads meet. Put a ruined house,
shop, garage, and low rubble court in separate blocks. Join the roads with an
outer loop, and leave gaps through the blocks. Four entry sectors feed the
main roads and side approaches.

- **A — Junction:** the starting area. Clear fire and grapple paths, with
  attacks possible from four directions.
- **B — Garage yard:** a broad court west of the junction. Two open exits
  reduce the number of immediate approaches, but the side lane remains exposed.
- **C — Ruined court:** east of the junction. More room for a base, with
  longer collection trips around nearby foundations.

Keep the middle readable and the building groups small. Do not build a ring
of walls around A. This is the first map to block out because it gives the
clearest baseline for combat, delivery, and the Hermes winch.

### Dry Wash

Use a pale, dry riverbed between scattered rock ribs. Give it three broad
crossings, plus routes along both outer banks. The channel bends, but gaps in
the rocks must let enemies bypass the bend. It must not become one long,
unavoidable shooting lane.

- **A — Middle crossing:** the starting area. Short routes to both banks,
  but two flanks need attention.
- **B — West bank:** a wider deployment space with a clear retreat route.
  Bodies on the far side of the rocks may need Nathaniel to collect them.
- **C — East shelf:** a flat clearing with quick access to two crossings.
  A rear route keeps it vulnerable to flanking.

Use wedges and low cliff faces to suggest erosion. In the first pass, the
rock footprints block movement; the channel and crossings remain ordinary
walkable ground. There is no height advantage, water penalty, or bridge system.
Keep every crossing wide enough for Hermes and the boss, including their art.

### Freight Yard

Use a disused rail and road depot with concrete loading courts, two warehouse
ruins, short container groups, and rails buried in sand. Three long lanes
connect through the central loading apron and a second broad cross-lane.
Keep perimeter access open.

- **A — Loading apron:** the starting area. Three approaches converge near
  good deployment space, but each lane has an alternate route.
- **B — Repair yard:** a western court with two exits. It can concentrate
  attacks while leaving a longer flank to defend.
- **C — East apron:** room for towers and fast access to the cross-lanes.
  Enemy fire can still pass through scenery under the current combat rules.

Stagger the solid groups. Avoid long container tunnels, closed courtyards,
and a single gate that every enemy must use. Reuse the existing warehouse
and garage kit; containers need only simple boxes with large door shapes.

### Open Countryside

Use open grassland, scattered living trees, a few dead trees, and one winding
country road. No buildings, ruins, containers, or industrial structures.
Use muted olive and dry green grass, pale worn road edges, and large simple
tree crowns. This keeps the Iron & Ink style while giving the demo a greener
area. Grass detail must remain quieter than units, corpses, and grapple cables.

- **A — Roadside meadow:** the starting area. A broad clearing with open
  collection routes, exposed to attacks across the fields as well as the road.
- **B — West glade:** a clearing between separate tree groups. Nearby trunks
  interrupt a few pull routes, while wide gaps allow approach and retreat.
- **C — East road bend:** a second open deployment space beside the road.
  A grove on one side changes the approach angles; the other sides remain open.

Four entry sectors use the two road ends and two field edges. Trees form
separate groups, not a continuous forest wall. Preserve broad routes through
and around each group for Hermes and the boss. Make trunk and root footprints
explicit in Collision; canopies must not become invisible solid discs. Grass,
road surfaces, and canopy overhangs add no cover, speed, or sight rules in this
pass. Keep crowns small and sparse near the clearings so they do not hide units.

Enemies can cross the grass directly. They do not follow the winding road
unless it is their best route. Measure those direct approaches when comparing
arrival times. Open ground may also let Hermes collect more bodies, so compare
resource income as well as combat pressure with the other maps. Use tree
placement to vary the clearings without making every corpse hard to retrieve.

## Immediate enemy attacks

Every mobile survival enemy should receive attack intent when it spawns and
start to pursue on its first active simulation step. “Straight to attack”
means the shortest valid route toward a target, including routes around
obstacles. It does not mean walking through walls or firing from anywhere.

Current behavior is inconsistent. Grunts, spawner children, early soldiers,
and wave spawners already receive Nathaniel as a target. Wave bosses and
later soldier choices can start without a target and wait for vision-based
acquisition. Fix the rule for all survival spawn paths rather than raising
vision range or patching only the boss.

For this demo, recommend Nathaniel as the initial pursuit target. Preserve
existing valid combat target retention. If an enemy loses its target while
the run is still active, give it a new living player-side target without a
sight gate; use Nathaniel first, then Hermes. Apply this to restored enemies
as well. Preserve the existing loss outcome when the run ends.

Spawners remain stationary. Their production starts without sight, and every
child immediately pursues. Their own laser still obeys its normal range and
cooldown. All attacks retain current range, cadence, and damage. Future line
of sight rules can limit firing without removing pursuit intent.

Gate this policy on survival mode. Some campaign levels also use waves;
`wave_based` alone is not a safe mode check.

## Spawn sectors and pressure

The current wave system uses fixed positions near one logical edge. New maps
need authored entry regions and valid routes, not larger random coordinates.
Use at least four entry sectors per map, with multiple candidate positions.
Keep the current wave budget and progression for the first comparison.

Validate each spawn against bounds, terrain, occupied space, and connectivity
to the active fight. Spawner children also need a valid nearby birth position;
the current fixed offset can put them inside new obstacles. If a candidate
fails, try another valid position or sector. If none is valid, defer that spawn
and report the blocked condition for testing; do not create a stuck unit or
silently erase the wave budget.

Choose among valid sectors so new waves can approach different flanks. Avoid
spawning inside the deployed base or directly on a hero. Use an actual world
distance for safety, rather than making spawns depend on phone screen size or
where the user pans the camera. Enemies can be visible on entry; hide them with
authored approach space only where it does not delay the fight.

Measure route distance and time to first contact. Match the maps against the
current baseline before changing spawn cadence. A larger map can accumulate
more living enemies while they travel, even with unchanged wave counts.
Do not triple the enemy count because the area tripled.

Every attractive base position needs at least two independent approach routes.
Towers can currently seal routes. For survival, validate placement so it cannot
close the last route from any enabled entry sector to the player area, including
sectors not used by the current wave. Do not rely only on a wide-looking gap.
This rule needs domain checks and a clear invalid placement cue. Destructible
barricades and siege AI can be explored later.

## Terrain options

Ground art currently has no movement cost. Occupied Collision cells block
movement and tower footprints. Building sprites do not create collision, and
terrain does not block bullets or lasers. Use those facts when judging the
first layouts: a wall can delay an attacker without protecting the defender.

| Terrain | Visual treatment for the demo | Later gameplay option |
| --- | --- | --- |
| Cracked road and concrete pad | Quiet, broad surfaces; ordinary movement and building | Faster travel on a road, if route choices need more contrast |
| Rock island and cliff foot | Large angular forms with an explicit blocked footprint | Block fire and sight; use the existing footprint as the starting shape |
| Ruined wall and foundation | Solid wall sections block movement; gaps stay clearly open | Low walls protect against selected attacks while tall walls block shots |
| Rubble fan and loose sand | Flat, walkable scatter with few large pieces | Slower movement for both sides; pathfinding must price the slower route |
| Dry channel | Pale sediment bands and interrupted rock banks | Walkable ground where towers cannot deploy |
| Container group and wreck | Short, solid groups with broad alternate routes | Destructible blockers that open a new route |
| Dead trees and scrub | Sparse clusters; only explicit solid footprints block | Sight reduction in denser patches, without hiding attack cues |
| Grass meadow and living grove | Muted grass, small crowns, clear trunk footprints; open routes between groups | Taller grass or dense foliage could affect sight in a later experiment |
| Rock shelf and ramp | Low visual relief around a flat route | Real elevation, ramp access, and firing advantage |
| Shallow water or mud | Reserve for a later area; distinct surface and clear banks | Slow crossing with limited build access |
| Alien residue patch | Reserve for a later encounter; local acid-green marks | Temporary hazard that makes the player relocate |

For the next mechanics pass, test **solid obstacles that block fire** first,
then **one rough-ground movement cost**. These give clear tactical choices
without a height system. Firing checks, projectiles, aiming, visibility, and
navigation need coherent rules; do not add shot blocking as a visual effect.
Decide weapon exceptions explicitly before implementation. Keep height,
destructible scenery, and damage hazards for separate experiments.

The Hermes winch makes terrain useful even before those systems. Mix clear
kill areas with a few blocked collection routes. Nathaniel should have useful
short rescue trips, while the base can still consume a good share of nearby
corpses. Check both the build radius and the actual pull route. Do not alter
corpse lifetime or resource value to compensate for a poor layout.

## Random map selection and saved runs

Recommend an equal one-in-four selection (25% each) when the player starts a
**new survival run**. A repeated map is allowed. Keep one survival mode and show the
selected map name briefly at the start; no map selection menu is needed.

- **New run:** choose once, then load the selected authored scene.
- **Retry:** restart the same map so the player can improve their approach.
- **Resume:** restore the saved map and state without another random choice.
- **Tests and captures:** choose an explicit map and seed.

Use a stable map identifier with an allowlisted catalog, while keeping the
survival mode identity separate. Save the selected identifier with the run.
Map selection must not consume combat random values as a side effect.
Keep authored scenes authoritative; normal startup must not regenerate them.

The current save restores the visual scene by numeric level while restoring
the simulation's saved level data separately. Randomizing that shared loader
would risk different scenery and collision. Resolve both from the same map
identity and check this during restore.

Keep the existing `level_0.tscn` as a legacy save target, outside the new-run
random catalog. Keyless old survival saves can then retain their original
30 × 30 scene. An unknown new map identifier should produce a clear load
failure, not quietly substitute a different map. Preserve save format and
storage compatibility as specified in the [save guide](../docs/saves.md).

## Implementation sequence

1. **Fix pursuit and spawn placement.** Centralize survival attack intent,
   validate all birth positions, and add regression checks. Use the current
   map to isolate behavior changes.
2. **Block out Crossroads.** Author the 52 × 52 ground, collision, starts,
   pickup, deployment spaces, and entry sectors. Test travel, range, collection,
   tower placement, and retreat before adding detail.
3. **Build Dry Wash, Freight Yard, and Open Countryside.** Reuse the same scale,
   start budget, and waves. Check connectivity and route sealing on all four
   layouts.
4. **Connect the map catalog.** Add new-run selection, same-map retry,
   save/resume identity, and legacy-save handling. Keep deterministic access
   for tests and captures. Include all four scenes in the demo export.
5. **Add the visual pass and compare runs.** Reuse saved Blender sources for
   buildings and ruins. Add a small rock-rib kit, container kit, and flat rail
   crossing. Reuse the tree sources with a few crown variants for Countryside;
   keep grass mostly in ground tiles. Use low foreground props so units remain
   visible on small screens.

After the demo map pass, prototype solid shot blockers as a separate task.
Rebalance routes with that rule enabled before adding movement costs or other
terrain systems. These later mechanics are not required to deliver the four
new maps.

Relevant integration points are [native level authoring](../docs/authoring.md),
[environment assets](../docs/environment-assets.md),
[wave and child spawning](../scripts/domain/battlefield_rules.gd),
[spawn and simulation state](../scripts/domain/game_simulation.gd),
[target acquisition](../scripts/domain/combat_rules.gd),
[navigation](../scripts/domain/world_navigation.gd), and
[new run, retry, and restore](../scripts/presentation/game_app.gd).
Gameplay decisions belong in the domain; presentation translates authored
markers and displays the selected scene and placement feedback.

## Acceptance and playtest

For each map, verify the complete 52 × 52 ground, matching camera bounds,
valid starts and pickup, all spawn sectors, and alternate routes. Test actual
Hermes and boss movement through each opening. Current terrain checks use
unit centers in places, so a connected cell path alone does not prove that
a large unit fits visually or physically.

For Countryside, verify that only authored trunk/root footprints block movement,
the road does not constrain enemy pursuit, and tree crowns do not hide units,
corpses, or touch targets. Confirm the scene contains no building or ruin assets.

Check every survival enemy type beyond its vision range, including later
soldier choices, bosses, spawner children, and restored enemies. They should
move immediately while retaining legal attack range. Check campaign behavior
separately. Test blocked spawn positions and attempted tower route sealing.

Test new-run randomness with controlled seeds, same-map retry, saved map
identity, a legacy save, and an unknown map identifier. Do not use a flaky
short-run frequency test to prove an equal distribution.

Compare identical wave seeds on all maps. Record first contact time, peak live
enemies, frame time, time spent walking, base relocations, and corpses consumed,
collected by Nathaniel, or lost. If one map strongly favors camping, review
its alternate approaches before changing enemy statistics. Extend profiling
to the new scenes; the current open-ground stress case is not enough.

Implementation checks include `rtk make format-check`, `rtk make test-content`,
`rtk make test-gameplay`, `rtk make test-resource-gathering`,
`rtk make test-services`, `rtk make test-presentation`, `rtk make test-demo`,
and `rtk make test-environment-art`, followed by `rtk make test`.
Update deliberate survival content baselines while preserving campaign checks.
Run desktop and exported web playtests, then real touch tests where supported.
Builds and synthetic input do not establish touch usability or iOS performance.

Planning validation: local documentation links resolve, and
`rtk make format-check` passed. The interactive planning diagrams
were checked at desktop, 360-pixel, and 320-pixel browser widths. These are
diagram checks, not game or device tests. Gameplay, navigation clearance,
balance, performance, and device behavior require the implementation and
playtests above.
