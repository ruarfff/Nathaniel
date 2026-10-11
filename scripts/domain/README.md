# Gameplay boundary

`GameSimulation` owns gameplay state and use cases without scene-tree, input,
projection, or disk dependencies. `step(delta)` uses seconds and logical Y-up
world points; level dimensions are cells scaled by `tile_size`.

Call `configure(level_scene.data())` for a fresh run. Use simulation methods to
add or remove entities: combat keeps indexes of the same dictionary objects.
Presentation reads `entities`, `corpses`, `projectiles`, and `weapon_pickups`.
Debug setup and tests may change individual values.

## APIs

| Intent | API |
| --- | --- |
| Movement | `move_to(point)`, `stop_player()` |
| Aim/fire | `target_enemy(id)`, `fire_at(point)` |
| Equip | `equip_weapon("rifle" / "heavy_rifle")` returns whether accepted |
| Hermes mode | `set_hermes_mode("building" / "following")` |
| Build | `hermes_build_range()`, `placement_error(point)`, `place_tower(kind, point)` |
| Map/debug setup | `spawn_enemy(kind, point)`, `place_map_tower(kind, point)`, `damage_entity(id, amount, attacker_id)`, `spawn_resource(...)` |
| Weapon pickup setup | `spawn_weapon_pickup(weapon_id, point)` |
| Backpack | `return_to_hermes()`, `gathering_state()`, `gathering_upgrade_cost(kind)`, `upgrade_gathering(kind)`; upgrade kinds are `capacity` and `reach` |
| Winch display | `recovery_state()` returns the active body or an empty dictionary |
| Pause | `set_paused(bool)` |
| Save | `snapshot()` returns JSON primitives; `restore(state)` rebuilds navigation |
| Visibility | `visibility_at(point)`: 0 unexplored, 1 explored, 2 visible |
| Events | `take_events()` consumes transient presentation/audio events once |

IDs are allocator integers. Canonical tower kinds are `gunTower`, `laserTower`,
and `healTower`; build APIs accept snake case too. Level data may include
`weapon_pickups: [{weapon_id, position}]`.

## Contracts

- Nathaniel remains the controlled character. Presentation owns Build focus,
  ring state, input gating, and projection. Saved `focused_character` remains
  compatible but does not restore a temporary ring or camera interaction.
- Hermes follows Nathaniel or deploys as a stationary cannon. Building anchors
  him; following dismantles towers and their shots. Only surviving paid owned
  towers refund one quarter of their cost, rounded down. Hermes death ends the
  run and removes towers without refunds.
- Campaign uses spare lives and ends immediately on boss death. Survival ends
  on the first player death. Victory cannot become a later defeat.
- Player combat precedes enemies, corpse handling, then tower combat. Enemy
  projectiles can finish after their owner dies. Target acquisition retains
  the existing side order, distance/health/threat scoring, and target persistence.
- Navigation prevents corner cutting, keeps tower clearance, and replans after
  tower changes. When a route fails, movement retains collision and axis sliding.
  Restored routes are rebuilt from requested destinations.
- Survival is mode number `0`, separate from `survival_map_id`. All mobile
  Survival enemies pursue immediately, retain valid targets, and reacquire
  Nathaniel then living Hermes without a vision gate. Firing still uses weapon
  range and cooldown. Campaign waves retain their own acquisition rules.
- Authored `entry_sectors` contain `{id, enabled, positions}` values in logical
  coordinates. Survival births use bounded terrain, occupancy, distance and
  route checks. Blocked births wait without spending their budget. A proposed
  tower must retain a route from every enabled sector to the player area.

`aim_direction` is independent of movement `facing`. An accepted `fire_at`
request may wait for aim; a later valid request replaces its pending point.
Movement, enemy selection, equipment changes, and death cancel that point.
Cooldown and equip time reject manual fire. Changing weapons preserves the
last shot's `recovery_delay`.

`equipped_weapon_id` identifies Nathaniel's gun; `weapon` identifies its firing
mechanism. Existing projectiles retain their own `weapon_id`. Only Nathaniel
collects weapon pickups. Collection adds ownership without equipping or paying
for duplicates; a new run starts with the rifle.

Positive damage emits `hit` before `death`. Hits carry `target_id`,
`attacker_id`, `position`, `amount`, `target_kind`, and `target_enemy`.
Death carries `entity_id`, `kind`, `position`, and `facing`. Effects finish
after removal but cannot apply damage or create matter. Events are not saved.

Use [resource gathering](../../docs/resource-gathering.md) for ownership,
expiry, winch arbitration, and intake rules; [saves](../../docs/saves.md) for
compatibility; and [balance](../../docs/balance.md) for units and timing.
`GameBalance` owns numerical defaults; native markers may override encounter
parameters. `tests/test_gameplay.gd` checks gameplay contracts;
`tests/profile_gameplay.gd` measures a fixed workload.
