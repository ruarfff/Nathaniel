# Saves and Swift save import

Godot uses three independent save slots under `user://saves/slot_1.json` through
`slot_3.json`. On macOS, this project resolves `user://` to
`~/Library/Application Support/NathanielGodot/`. Settings use `settings.json`;
campaign records use `progress.json`. The retired Swift app used a different
preferences domain. Audio defaults to off. Fog visibility is a persisted setting
and defaults to enabled.

Use Pause → Save or the main menu's Load control. Slot metadata comes from each
validated save, so a missing metadata cache cannot hide a valid slot. A save writes
and flushes a sibling temporary file, checks its JSON, then renames it over the
selected slot. Invalid input or a failed write preserves the previous slot. Save
files are limited to 16 MiB and level grids to 1,048,576 cells.

Native snapshots include the level definition, logical positions, requested move
destinations, health, target IDs, towers and their actual costs, weapon phase,
projectiles, spawner production, carried/loose corpses, resource wallet, score,
spare lives, wave phase, explored fog, focus, and random generator state. Loading
rebuilds tower obstacles before requesting routes. A loaded session resumes play.
Older saves with Hermes camera focus reopen the Build menu without changing his
saved following/stopped mode. The saved focus field and format remain unchanged.

Hermes's saved mode also restores his deployed cannon or mobile laser profile.
Older stopped saves receive the cannon and discard incompatible laser-burst
state. Deployed cannon cooldown survives a current save/load round trip. The
derived `anchored` flag does not change the schema. Following reclaims all
towers, including unowned map towers; only paid owned towers refund resources.
Restoring a dead Hermes removes the dependent towers without a refund.

Nathaniel's owned and equipped weapons, aim, equip timer, shot recovery and
pending manual aim are saved with his state. Remaining weapon pickups and each
projectile's weapon ID are also saved. Older snapshots without these fields use
the original rifle and no pending equip or manual shot. The envelope and snapshot
schema stay at version 1. A spare-life respawn retains weapons; a fresh level
uses its authored default loadout and pickups.

Soldier and boss saves with the old `gun` or `bow` mechanism upgrade to
`pulse_laser` while retaining their damage, range and elapsed cooldown. Already
travelling projectiles finish normally. Current pulse saves retain their brief
firing phase without replaying damage. The save format and schema are unchanged.

The separate `gunSoldier` kind retains its projectile gun, cooldown and active
bullets on load. Soldier corpses now save `source_kind` as `soldier` or
`gunSoldier`, including when carried. Older corpses without this optional field
use the default soldier image. Loading does not change delivery rewards.

Backpack saves include reach and capacity, each body's handling phase and cargo
slot, the return-to-Hermes command, and Hermes's remaining furnace time.
In-flight collection and delivery resume without repeating a credit.
Old saves receive the one-slot starter rack;
extra carried bodies drop beside Nathaniel, permanently disarmed. Their
values and source types remain intact. The envelope and schema stay at version 1.
See [resource gathering](resource-gathering.md) for interruption and upgrade rules.

Corpses save their remaining armed lifetime and permanent `disarmed` flag.
Older held cargo loads as disarmed, including overflow dropped from the rack.
Older loose bodies remain armed with their saved time remaining. Loading never
resets that countdown. Expired bodies are absent from snapshots; the short
dissolve effect is presentation-only and is not restored as collectible matter.

## Storage identity

Keep `config/use_custom_user_dir=true`, `config/custom_user_dir_name="NathanielGodot"`, and the export bundle identifier `dev.ruarfff.nathaniel.godot`. Moving the project or renaming the displayed app does not require a new storage location. Changing the iOS bundle identifier creates a different app container. Native files retain envelope format `nathaniel-godot`, version `1`, and gameplay snapshot schema `1`. The slot filenames and settings/progress filenames are part of this compatibility contract.

## Import a Swift save

The retired Swift app stored JSON `Data` values in UserDefaults keys `save_slot_1`,
`save_slot_2`, and `save_slot_3`. A JSON export of one of those values is the input.
The Godot app does **not** search for or read the live Swift preferences. First
obtain a copy of the save or an exported preferences plist through the platform's
normal export or backup access. On iOS, access to another app's container requires
an available export or backup; Godot cannot read it directly.

If you have an exported plist, extract one slot with the standard-library tool:

```sh
python3 tools/import_swift_save.py /path/to/exported-preferences.plist /path/to/swift-slot.json --plist-slot 2
```

If you already have JSON, use it directly. The extraction tool also accepts JSON
as its source and can make a checked copy. It opens output files exclusively and
refuses to replace existing files, including its own source.

Import the explicit JSON path into an **empty** Godot slot:

```sh
godot --path . -- --import-swift=/path/to/swift-slot.json --slot=2
```

The game checks the source schema, loads the matching native level, writes the
new Godot slot, and opens the restored session. `--slot` defaults to `1`. An
occupied slot, including a corrupt slot file, is never replaced by an import.
The source JSON is read-only. Source versions 1 and 2 are supported; future
versions are rejected with a specific error.

For a trial import, select an isolated directory:

```sh
godot --path . -- --storage-dir=/private/tmp/nathaniel-import-trial --import-swift=/path/to/swift-slot.json --slot=1
```

## Compatibility details

Positions stay in Swift logical pixels with positive y pointing up; isometric
projection does not change saved coordinates. The importer preserves requested
destinations, enemy target references, spawner countdowns and initial production,
corpse expiration/carried state, and actual tower construction cost. A corpse does
not credit the resource wallet again during load.

Version 1's total-life count converts to spare lives with `max(0, lives - 1)`.
A saved pending Nathaniel respawn restores at the level start without spending
another life. Dead Hermes restores as defeat. Old `locked` Hermes mode becomes
independent. Hermes movement and tower cooldown reset as they do in Swift load.
Old saves without corpses or production fields receive the same fresh defaults.

Swift saves do not contain explored fog, active projectiles, weapon timers,
random generator state, or camera state; import starts those fields fresh. Swift
debug settings are not imported. Where an older owned tower has no stored cost,
the shipped costs 5/10/15 are used for gun/laser/heal towers. If it was built with
a customized old debug cost, that absent value cannot be recovered. Following
Hermes still refunds 25% of the stored/default cost, rounded down.

Settings and campaign completion records are separate from resumable saves and
are not copied by the slot importer. Importing a slot does not mark levels complete.

## Verification

```sh
godot --headless --path . --script res://tests/test_services.gd
python3 -m unittest discover -s tests -p 'test_import*.py'
```

The service suite creates a unique temporary directory and removes only its own
fixtures. It checks three-slot isolation, atomic replacement, corrupt data,
explicit import without overwrites, the literal Swift Codable schema, version 1
compatibility, and restoration through the actual simulation, including routes,
corpses, production timers, random state, and tower refunds. Python checks explicit
JSON/plist extraction and refusal to replace sources or existing output.
