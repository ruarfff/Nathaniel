# Saves and Swift save import

Godot uses three slots at `user://saves/slot_1.json` through `slot_3.json`.
Settings use `settings.json`; campaign records use `progress.json`.
Audio defaults off; fog visibility defaults on and is persisted.
Demo mode uses the same formats under `user://demo/`, loads Survival only, and
does not import Swift saves. See [demo mode](web.md#survival-demo).

Use Pause → Save or the menu's Load control. Metadata comes from validated saves,
so a missing cache cannot hide a valid slot. Writes flush a sibling temporary
file, validate its JSON, and rename it over the slot. Invalid input or a failed
write preserves the previous file. Saves are limited to 16 MiB; grids to
1,048,576 cells. Tests use isolated storage, never live slots or preferences.

## Storage identity

Keep these identifiers stable:

- `config/use_custom_user_dir=true`
- `config/custom_user_dir_name="NathanielGodot"`
- Export bundle identifier `dev.ruarfff.nathaniel.godot`
- Envelope format `nathaniel-godot`, version `1`, gameplay snapshot schema `1`
- Slot, settings, and progress filenames above

On macOS, `user://` resolves to `~/Library/Application Support/NathanielGodot/`.
Moving the checkout or renaming the displayed app does not change storage.
Changing the iOS bundle identifier creates a different app container. The retired
Swift app used a separate preferences domain.

## Native restore

Snapshots retain level definition, logical positions and destinations, health,
targets, towers and paid costs, weapons and timers, projectiles, spawner production,
corpses/cargo, resources, score, spare lives, waves, explored fog, focus, and random
state. Loading rebuilds tower obstacles before requesting routes and resumes play.

| Compatibility case | Restore rule |
| --- | --- |
| Older Hermes camera focus | Return to Nathaniel with Build closed; retain Hermes's saved mode. |
| Hermes following/stopped | Restore mobile laser/deployed cannon; older stopped saves discard incompatible beam state. Current cannon cooldown persists. |
| Dead Hermes | Defeat; remove dependent towers without refund. |
| Missing Nathaniel weapon fields | Original rifle, no pending equip/manual shot. Respawn retains weapons; a fresh level uses authored loadout/pickups. |
| Soldier/boss old `gun` or `bow` mechanism | Upgrade to `pulse_laser`, retaining damage, range, and elapsed cooldown; existing bullets finish. Active pulses restore without replaying damage. |
| `gunSoldier` | Retain projectile gun, cooldown, and bullets. |
| Corpse missing `source_kind` | Soldier appearance; current `soldier`, `gunSoldier`, and `boss` kinds and values persist. |
| Missing backpack fields | Starter rack; excess held bodies drop beside Nathaniel, permanently disarmed, with value/type intact. |
| Older held cargo | Permanently disarmed, including dropped overflow. |
| Older loose corpses | Armed with saved remaining lifetime; never reset the deadline. |
| Missing Hermes recovery fields | No death-time eligibility, pending job, or reset time; proximity does not infer eligibility. |

Following dismantles all connected towers; only paid owned towers refund their
stored cost. The derived `anchored` flag does not change the schema.
Expired bodies are absent; dissolution is a visual effect, not restored matter.

Backpack state includes reach/capacity, handling phase, slot, return order, and
remaining furnace time. Collection and delivery resume without repeating credit.
Recovery stores each body's death-time eligibility, winch phase/time, pull route,
ground position, and safe drop point, plus Hermes's pending body ID and reset time.
Launch retains armed time; secured winch matter stays disarmed and uses no rack slot.

Validation rejects invalid ownership, timers, routes, or shared intake claims.
Active routes must match the guide path; ground position must match phase/time.
Recovery resumes only with living, deployed Hermes during play. Otherwise restore
releases a pre-contact body with its remaining lifetime, or drops secured matter
at its safe point, then clears eligibility. Acceptance removes the body/pending ID
before saving credit and furnace/reset time; load cannot restore or credit it twice.
See [resource rules](resource-gathering.md) for gameplay interruptions.

## Import a Swift save

Swift stored JSON `Data` in UserDefaults keys `save_slot_1` through `save_slot_3`.
Obtain a copy through export or backup access; Godot does not read live Swift
preferences or another iOS app's container. Extract a slot from an exported plist:

```sh
rtk python3 tools/import_swift_save.py /path/to/preferences.plist /path/to/swift-slot.json --plist-slot 2
```

The tool also accepts JSON and makes a checked copy. Output is exclusive: it
never replaces an existing file or its source. Import JSON into an empty slot:

```sh
rtk godot --path . -- --import-swift=/path/to/swift-slot.json --slot=2
```

The game validates the schema, loads the native level, writes the slot, and opens
the session. `--slot` defaults to `1`. Occupied slots, including corrupt files,
are never replaced. Source JSON stays read-only. Swift versions 1 and 2 are
supported; future versions are rejected. For a trial, add
`--storage-dir=/private/tmp/nathaniel-import-trial` using an unused directory.

Positions remain logical Y up. Import retains requested destinations, target
references, production timers, corpse expiry/carried state, and tower costs.
Loading a corpse does not credit the wallet. Version 1 total lives becomes
`max(0, lives - 1)` spare lives. Pending respawn restores at the start without
spending another life. Dead Hermes restores defeat; old `locked` becomes
independent. Hermes movement and tower cooldown reset as in Swift. Missing corpse
or production fields get fresh defaults.

Swift omits explored fog, projectiles, weapon timers, random state, and camera;
these start fresh. Debug settings are not imported. Missing owned-tower costs use
5/10/15 for gun/laser/heal; an absent customized cost cannot be recovered.
Following refunds 25% of stored/default cost, rounded down. Settings and campaign
records are separate; importing does not mark levels complete.

## Checks

```sh
rtk make test-services test-tooling
```

Checks use temporary fixtures for slot isolation, atomic replacement, invalid data,
native and Swift compatibility, simulation restore, and non-overwriting extraction.
