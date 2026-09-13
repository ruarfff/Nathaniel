# Godot saves and Swift save import

Godot uses three independent save slots under `user://saves/slot_1.json` through
`slot_3.json`. On macOS, this project resolves `user://` to
`~/Library/Application Support/NathanielGodot/`. Settings use `settings.json`;
campaign records use `progress.json`. Neither shares a file or preferences domain
with the Swift app. Audio defaults remain off, as in Swift. The Godot Settings
menu also exposes a persisted fog visibility switch; fog defaults to enabled.
This moves the equivalent Swift developer visibility control into normal settings.

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

## Import a Swift save

The Swift app stores JSON `Data` values in UserDefaults keys `save_slot_1`,
`save_slot_2`, and `save_slot_3`. A JSON export of one of those values is the input.
The Godot app does **not** search for or read the live Swift preferences. First
obtain a copy of the save or an exported preferences plist through the platform's
normal export or backup access. On iOS, access to another app's container requires
an available export or backup; Godot cannot read it directly.

If you have an exported plist, extract one slot with the standard-library tool:

```sh
python3 godot/tools/import_swift_save.py /path/to/exported-preferences.plist /path/to/swift-slot.json --plist-slot 2
```

If you already have JSON, use it directly. The extraction tool also accepts JSON
as its source and can make a checked copy. It opens output files exclusively and
refuses to replace existing files, including its own source.

Import the explicit JSON path into an **empty** Godot slot:

```sh
godot --path godot -- --import-swift=/path/to/swift-slot.json --slot=2
```

The game checks the source schema, loads the matching migrated level, writes the
new Godot slot, and opens the restored session. `--slot` defaults to `1`. An
occupied slot, including a corrupt slot file, is never replaced by an import.
The source JSON is read-only. Source versions 1 and 2 are supported; future
versions are rejected with a specific error.

For a trial import, select an isolated directory:

```sh
godot --path godot -- --storage-dir=/private/tmp/nathaniel-import-trial --import-swift=/path/to/swift-slot.json --slot=1
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
godot --headless --path godot --script res://tests/test_services.gd
python3 -m unittest discover -s godot/tests -p 'test_import*.py'
```

The service suite creates a unique temporary directory and removes only its own
fixtures. It checks three-slot isolation, atomic replacement, corrupt data,
explicit import without overwrites, the literal Swift Codable schema, version 1
compatibility, and restoration through the actual simulation, including routes,
corpses, production timers, random state, and tower refunds. Python checks explicit
JSON/plist extraction and refusal to replace sources or existing output.
