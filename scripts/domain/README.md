# Gameplay boundary

`GameSimulation` contains mutable gameplay state without scene-tree, input,
projection, or disk dependencies. `step(delta)` uses logical seconds and y-up
world points. Level dimensions are cells; `tile_size` converts them to points.

Call `configure(level_scene.data())` to begin a fresh level. Render `entities`,
`corpses`, and `projectiles`; use the simulation methods to add or remove them.
Do not append to or erase the public arrays. Combat keeps private indexes of
the same dictionary objects. Individual state values can be changed by debug
setup and tests. `take_events()` consumes presentation/audio events exactly once.

| Intent | API |
| --- | --- |
| Move Nathaniel | `move_to(world_point)`, `stop_player()` |
| Aim/fire Nathaniel | `target_enemy(id)`, `fire_at(world_point)` |
| Camera selection | `focused_character = "nathaniel"` or `"hermes"` |
| Hermes control | `set_hermes_mode("building")` or `"following"` |
| Build | `placement_error(point)`, `place_tower(kind, point)` |
| Editor/map setup | `spawn_enemy(kind, point)`, `place_map_tower(kind, point)` |
| Damage/setup | `damage_entity(id, amount, attacker_id)`, `spawn_resource(...)` |
| Pause | `set_paused(bool)` |
| Save state | `snapshot()` returns JSON primitives; `restore(state)` rebuilds routes |
| Visibility | `visibility_at(point)` returns 0 unexplored, 1 explored, 2 visible |

Entity IDs are integers. Canonical tower kinds are `gunTower`, `laserTower`, and
`healTower`; build APIs also accept snake case. Directions are logical `Vector2`
values; the view chooses sprite frames after projection. Native snapshots keep
weapon state, shots, corpse delivery state, exploration, random state, and each
requested destination. Routes are rebuilt after restoring all tower obstacles.
Legacy save conversion and file validation are in `scripts/infrastructure`.

`GameBalance` contains the shipped release constants. The legacy implementation
is retained in Git history at `824c8f1`. Preserved rules include:

- Campaign starts with three spare lives; survival ends on the first death.
  Losing Hermes ends the game. A boss death wins campaign levels, including waves.
- Hermes starts stationary, only moves by following Nathaniel, and stops within
  100 points. Camera focus does not change ground or enemy-target commands.
- Construction has no distance limit from Hermes. All towers have a 48-point
  footprint. Costs are 5, 10, and 15. Following dismantles surviving owned towers
  and their shots, refunding `floor(paid_cost / 4)` for each tower once.
- Enemies retain a living target outside sight. Idle acquisition visits players,
  then towers, retaining the last eligible object. Friendlies use the original
  distance, low-health, and threat scores, then retain their target within sight.
- Player shots update before enemy shots. Death rewards are immediate, and enemy
  shots continue after death. Victory cannot be replaced by a later lethal hit.
- Hermes and tower lasers carry fractional damage. The spawner beam pays whole
  seconds of damage. Healing selects Nathaniel before Hermes, one target per tick.
- Only Soldiers leave corpses, worth ten resources. Loose corpses expire after
  ten seconds. Carried corpses do not expire; Hermes contact credits them once.
- Spawners produce at 30, 60, and 90 seconds, then every 120 seconds. Their child
  position adds `(240, -168)`. Wave intervals change strictly after 60, 120, 180,
  and 240 seconds; the original weighted enemy distribution and edge offsets remain.
- Navigation blocks diagonal corner cutting, retains circular tower clearance,
  replans when towers change, and preserves the collision/axis-slide fallback
  when a complete route is unavailable. Tower pursuit finds an attack position
  outside the tower's blocked center.

`tests/test_gameplay.gd` exercises these rules and actual campaign boss routes.
`tests/profile_gameplay.gd` measures all six levels and a fixed population of 200
enemies, 30 towers, and two players. Its high-health setup preserves the workload
without changing weapon timing, navigation, or targeting rules.
