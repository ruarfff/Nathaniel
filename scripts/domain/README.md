# Gameplay boundary

`GameSimulation` contains mutable gameplay state without scene-tree, input,
projection, or disk dependencies. `step(delta)` uses logical seconds and y-up
world points. Level dimensions are cells; `tile_size` converts them to points.

Call `configure(level_scene.data())` to begin a fresh level. Render `entities`,
`corpses`, `projectiles`, and `weapon_pickups`; use simulation methods to add or remove them.
Do not append to or erase the public arrays. Combat keeps private indexes of
the same dictionary objects. Individual state values can be changed by debug
setup and tests. `take_events()` consumes presentation/audio events exactly once.

| Intent | API |
| --- | --- |
| Move Nathaniel | `move_to(world_point)`, `stop_player()` |
| Aim/fire Nathaniel | `target_enemy(id)`, `fire_at(world_point)` |
| Equip Nathaniel | `equip_weapon("rifle")` or `equip_weapon("heavy_rifle")`; returns whether the request was accepted |
| Saved camera focus | `focused_character = "nathaniel"` or `"hermes"`; presentation focuses Hermes only for Build |
| Hermes control | `set_hermes_mode("building")` or `"following"` |
| Build | `hermes_build_range()`, `placement_error(point)`, `place_tower(kind, point)` |
| Editor/map setup | `spawn_enemy(kind, point)`, `place_map_tower(kind, point)` |
| Weapon pickup setup | `spawn_weapon_pickup(weapon_id, point)`; level data accepts `weapon_pickups: [{weapon_id, position}]` |
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

Nathaniel's `aim_direction` is independent of movement `facing`. His gun turns
at 360 degrees per second and fires within one degree of the requested direction.
`fire_at` returns true for a ready, in-range request, including one that still
needs to turn. It stores one pending point; a later valid request replaces it.
Movement commands, enemy selection, an equipment change, or death cancel that
point. Cooldown and equip time reject manual fire; automatic targeting waits.

Weapon identity is `equipped_weapon_id`; the existing `weapon` field still names
the firing mechanism. Both rifles use bullets. Rifle damage/delay are 25/0.8;
heavy rifle damage/delay are 50/1.6. Changing guns takes 0.35 seconds and preserves
elapsed cooldown. Fire also waits for the last shot's `recovery_delay`, so changing
to a faster gun cannot shorten recovery. The `shot` event and projectile capture
their own `weapon_id`; presentation must use that ID for an existing bullet.

Only Nathaniel collects guns, within 32 logical points. Collection adds the ID
to `owned_weapon_ids` without equipping it. Duplicate pickups give no reward.
Each pickup has a stable entity-allocator ID and produces one `weapon_collected`
event with `pickup_id`, `weapon_id`, `position`, and `newly_owned`. Save/load and
spare-life respawn keep the loadout. A fresh level starts with the rifle only.
Snapshots preserve pickups, pending aim, equip time, and recovery; old saves
receive the rifle defaults without spawning new pickups.

`GameBalance` contains the shipped release constants. The legacy implementation
is retained in Git history at `824c8f1`. Current rules include:

- Campaign starts with three spare lives; survival ends on the first death.
  Losing Hermes ends the game. A boss death wins campaign levels, including waves.
- Hermes starts following Nathaniel, only moves by following him, and stops within
  100 points. Camera focus does not change ground or enemy-target commands.
- Construction is limited to a 240-point radius from living Hermes. Presentation
  draws the ring from `hermes_build_range()`; `GameBalance.HERMES_BUILD_RANGE`
  owns the starting radius. Opening Build does not change his mode. A successful
  placement anchors Hermes; rejected placements preserve his mode and movement.
  All towers have a 48-point footprint. Costs are 5, 10, and 15.
- Building mode deploys Hermes as a stationary cannon: 80 damage per shot,
  0.8-second delay and 300-point attack range. Following restores his mobile
  weapon. The derived `anchored` entity flag drives the visual pose; the saved
  mode identifiers remain `following` and `building`.
- All towers depend on living, anchored Hermes, including authored map towers.
  Map setup anchors him without charging resources. Following dismantles the
  surviving towers and their shots, refunding `floor(paid_cost / 4)` for each
  paid owned tower once. Hermes's death removes all towers without a refund.
- Enemies retain a living target outside sight. Idle acquisition visits players,
  then towers, retaining the last eligible object. Friendlies use the original
  distance, low-health, and threat scores, then retain their target within sight.
- Player shots update before enemy shots. Death rewards are immediate, and enemy
  shots continue after death. Victory cannot be replaced by a later lethal hit.
- Hermes and tower lasers carry fractional damage. The spawner beam pays whole
  seconds of damage. Each healing tick restores up to five HP to both Nathaniel
  and Hermes if they are alive, injured, and strictly inside the tower's range.
  Healing ticks have a one-second interval; an idle tower stays ready to heal.
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
