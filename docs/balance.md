# Game balance

[GameBalance](../scripts/domain/game_balance.gd) owns fresh-game defaults.
Edit values there instead of copying stat tables into documentation.
Distances use logical world points; movement and projectile speed use points
per second. The level's `tile_size` converts cells to world points. Screen pixels
and model scale do not change gameplay distances.

| Setting | Source |
| --- | --- |
| Shared health, speed, vision, enemy and tower attacks | `GameBalance.STATS` |
| Nathaniel's weapon catalog | `GameBalance.WEAPONS` |
| Deployed Hermes's cannon | `GameBalance.HERMES_ANCHORED_WEAPON` |
| Tower costs and build radius | `GameBalance.COSTS`, `HERMES_BUILD_RANGE` |
| Corpse value, lifetime, handling and backpack upgrades | `GameBalance.RESOURCE_*`; [resource rules](resource-gathering.md) |
| Survival tech yields, stacking, and collection | `GameBalance.TECH_*` |
| Research catalog, rank values, and tech costs | `GameBalance.RESEARCH` |
| Winch stages and guide clearance | `GameBalance.HERMES_WINCH_*` |
| Follow distance and boss approach ratio | `GameBalance.HERMES_FOLLOW_DISTANCE`, `BOSS_APPROACH_RANGE_RATIO` |
| Spawner production | `GameBalance.SPAWNER_*` |
| Wave pressure | `GameBalance.WAVE_STAGES` |
| Spare lives, starting matter and victory | Level `Definition` resources |
| One enemy or tower override | Level marker's `EncounterParameters`; `-1` keeps the default |

Hero markers set start positions only. Fresh entities copy defaults; visual
resources do not own damage or distances. See [authoring](authoring.md) for
encounter overrides and [the domain guide](../scripts/domain/README.md) for state ownership.

## Timing conventions

`damage` and `delay` retain their saved names but depend on the mechanism:

| Mechanism | `damage` | `delay` |
| --- | --- | --- |
| Projectile or instant pulse | HP per hit | Seconds between shots |
| Continuous beam | HP per active second | Rest after `LASER_BURST_SECONDS` |
| Healing tower | HP restored to each injured hero per tick | Seconds between healing ticks |

Hermes and tower beams carry fractional HP. Spawners pay whole active-second
ticks and retain the remainder between bursts; their cooldown advances only
with a target in range. Other beams can charge without a target. Instant pulse
duration is visual only, and `shot_speed` does not delay its damage.

Healing applies independently to each living hero strictly inside range and
stops at maximum HP. An idle heal tower stays ready. Weapon changes cannot
shorten the previous shot's recovery. These rules live in
[CombatRules](../scripts/domain/combat_rules.gd).

Nominal DPS assumes continuous targets and no misses:
`damage / delay` for projectiles and pulses;
`damage * burst / (burst + rest)` for beams. These comparisons exclude aiming,
travel, switching, overkill, and playtest difficulty.

Wave stages are ordered by elapsed time and use strict `>` thresholds. Soldier
choices split equally between laser and gun soldiers. Check
[BattlefieldRules](../scripts/domain/battlefield_rules.gd) when changing encounter pressure.

## Apply and check changes

Start a fresh level after editing defaults. Saves retain most stored stats;
Hermes's weapon profile refreshes on restore, and Nathaniel's equipment changes
read the current catalog. A loaded save does not prove all defaults were applied.
Keep saved field names stable.

```sh
rtk make format-check test-gameplay test-content
```

Use starting state or explicit timing inputs in rule tests; keep exact catalog
assertions in balance checks. See [testing](testing.md) for isolated playtests.
Build success and rule checks do not establish difficulty.
