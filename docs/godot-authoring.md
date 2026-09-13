# Godot content authoring

Open `godot/project.godot` with **Godot 4.7.2 stable**. The converted `.tscn`
levels are the authoritative Godot content. The Swift app continues to use its
original TMX files. Normal Godot startup and import never regenerate a level.

## Edit and run a level

1. Open `godot/levels/level_1.tscn` in the 2D editor. The other campaign scenes
   are `level_2.tscn` through `level_5.tscn`; `level_0.tscn` is survival.
2. Select `Ground` or `NonCollision` and use the native TileMap paint tools.
   The TileSet atlas contains projected copies of the original terrain tiles.
3. Paint or erase cells on `Collision` to block or open the logical grid.
   Every occupied cell blocks navigation, regardless of its texture. Physics
   collision polygons and tile custom properties are not used for this rule.
4. Expand `Spawns`. Move a marker in the 2D view, duplicate it, or change its
   **Kind**, **Label**, and **Enabled** fields. Use one enabled Nathaniel start
   and one enabled Hermes start. Enemy kinds are `grunt`, `soldier`, `boss`, and
   `spawner`. Spawners are stationary enemies with their existing timed spawn
   rule. Map enemy markers are ignored by wave-based encounter setup. Add an
   optional **Parameters / New EncounterParameters** resource to override health,
   speed, attack range, vision, damage, cooldown, or projectile speed for one
   encounter. `-1` uses shared balance. Zero speed makes an actor stationary; zero damage makes it harmless. Health, range, vision, cooldown and projectile speed must be positive. Tower marker
   kinds `gunTower`, `laserTower`, and `healTower` place configured starting
   towers; they are separate from player-purchased construction.
5. Select the level root and expand **Definition** in the Inspector. Set its
   dimensions, spare lives, initial resources, boss rule, wave mode, and next
   level. Zero spare lives permits the current life, as in Swift. `-1` ends
   campaign progression. Change dimensions with care: painted cells and
   markers are not stretched or moved automatically.
6. Press **F6 / Run Current Scene**. The game starts with this edited scene,
   including its in-memory resource values and markers. F5 starts the menu.

`Objectives/VictoryRule` labels the existing encounter goal in the editor.
It is an annotation: the level resource's `has_boss` field controls victory.
There are no arbitrary trigger objectives in the Swift game. The marker does
not add a new trigger system.

Levels use logical points with positive Y up, as Swift does. Rendering uses
`(x - y, (x + y) / 2)`. A logical 32×32 cell is a 64×32 diamond. Native TileMap
cells use the same logical Y-up grid and an isometric Diamond Down layout.
The layer offset `(-32, 0)` makes native tile centers match the projected
logical centers. Keep that offset and tile layout when editing. Spawn marker
positions are screen-projected points; the runtime applies the inverse
projection. Movement speed, attack ranges, footprints, and pathfinding do
not use the stretched screen distances.

## Add a level

Duplicate an existing level scene and give its Definition resource a unique
number. Use **Make Unique** on shared resources before changing parameters
that must differ between levels. Set the map dimensions, paint the three
layers, and place starts and encounters. Test the scene with F6 first. Add
its scene path to the game's level selection/load lookup when extending the
campaign beyond the current six scenes; do not extend the Python converter
for new Godot-authored content.

## Add or change an enemy or tower

Reusable scenes are in `godot/scenes/actors/`. Nathaniel, Hermes, Grunt,
Soldier, Boss, Spawner, all three towers, and corpses each have a scene.
Their **Visual** resources are in `godot/resources/actors/`. Inspect the
texture, sheet rows/columns, display size, feet offset, shadow radius, health
color, and animation fields. Changes to a shared resource update every
instance. Use **Make Unique** or duplicate the resource for a variant.

Place or duplicate a `SpawnMarker` to reuse an existing enemy's rules in an
encounter. To introduce a new gameplay kind, add its rules to the simulation
and balance table, add a reusable actor scene and visual resource, register
the kind in the view lookup and marker enum, and add a rule regression test.
For a new tower, also add its cost, refund, placement footprint, attack/heal
rule, and build UI choice. Sprite display size does not change logical
collision or combat distances.

Trees and windmills are editable native Sprite2D nodes under `Scenery`.
Reusable full tree and windmill scenes are also in `godot/scenes/scenery/`;
drag them into `Scenery` to add a prop, then paint its intended blocked cells. Their
origins are trunk/base positions. Move scenery with the 2D move tool and paint
its blocked footprint on `Collision` separately. At runtime Scenery joins the
actor Y-sort container, so actors can pass behind and in front of it. The
converted mosaic cells use transparent alternative tile 1: these retain
original collision occupancy while the upright sprite supplies the image.
Alternative 0 remains available for ground-plane tile painting. Do not paint
a second visible tree mosaic under an existing scenery sprite.

Actor scene origins are feet positions. Their Sprite2D bottoms sit at the
origin, and the gameplay actor container uses Y sorting. Sprite facing is
selected from projected motion because the old sprite columns depict screen
directions. Nathaniel and Soldier use two sheet rows, Grunt four, Boss eight;
Hermes has separate idle and moving sheets with its original frame mapping.

## Edit effects

Open `godot/scenes/effects/world_effects.tscn` and select its root. The Inspector
groups corpse size and opacity, projectile radius and colors, laser width and
height, event-ring lifetime and expansion, and placement-preview size and colors.
The application instantiates this reusable scene for its effects layer. Change
the scene's properties and run a level with F6 to inspect the result. Duplicate
the scene for a variant and select that scene in `GameApp`'s effects preload.
These settings change presentation only; damage, attack ranges, collision
radii, and tower-placement rules remain in the simulation. The scene defaults
preserve the existing visual output.

## Conversion source and exact supported features

The converter reads the four actual files in `Nathaniel Shared/Assets/Maps/`:

| Original map | Grid | Blocked cells | Enemy markers | Used by |
| --- | --- | --- | --- | --- |
| `levelone.tmx` | 120×30 | 450 | 16 | Campaign 1 |
| `leveltwo.tmx` | 100×30 | 459 | 14 | Campaign 2 |
| `levelthree.tmx` | 100×30 | 165 | 10 | Campaign 3 |
| `survivalmap.tmx` | 30×30 | 52 | 0 | Survival, campaign 4–5 |

All four are finite, orthogonal TMX 1.0 maps with 32×32 tiles, inline atlas
references, and base64/gzip tile arrays containing little-endian unsigned
32-bit GIDs. There are no tile flip flags, external TSX files, tile
properties, image layers, animated tiles, infinite chunks, nested groups,
or rotated objects. Each has `Ground`, `NonCollision`, `Collision`, and an
`Objects` group of rectangles. Object `x,y`, not rectangle centers, defines
spawn positions. `Nathaniel` and `Hermes` are exact player names; the enemy
factory recognizes `Gr`, `So`, `Bo`, and `Sp` name prefixes. The original
map-based levels contain soldiers, bosses, and spawners; grunts enter through
spawners and waves. The converter rejects unknown structural features and
objects rather than silently omitting them.

Four terrain atlases are used: `roughrippleearthdarktograsstileset`,
`treestileset`, `windmilltileset`, and `minetileset2`. Their magenta
transparency key is `#bf7bc7`. The converter uses Python's standard library
to decode the original RGB PNGs, replace that key with alpha, and project
each tile into a diamond PNG. `tileset1.png` and `clouds.png` are not referenced
by the actual maps. All sprite and audio assets are copied without changing
the originals. The inventory is recorded in
`godot/tools/conversion_inventory.json`.

To test conversion in a separate directory:

```sh
python3 godot/tools/convert_tmx.py --output /tmp/nathaniel-converted
```

To deliberately replace all migrated terrain, level scenes, and copied assets
with a fresh conversion from the preserved Swift source:

```sh
python3 godot/tools/convert_tmx.py --force
```

This discards Godot level edits. Without `--force`, existing levels cause an
error before any writes. It is not a synchronization workflow. After initial
conversion, edit Godot levels in Godot and Swift levels in Tiled only when a
separate Swift change is intended.

Conversion and native scene checks:

```sh
python3 -m unittest discover -s godot/tools -p 'test_*.py'
godot --headless --path godot --script tools/test_content.gd
```

The checks compare every migrated blocked cell with TMX data, preserve exact
starts and encounter counts, verify tile-center projection and sprite feet,
and change/repack a native scene to verify editor changes survive.

## Temporary presentation and replacement art

The original art is reused. Ground tiles are projected into diamonds. The
converter recognizes tree and windmill atlas rectangles, collects their
placed tiles across all layers, and bakes only those pixels into upright
scenery textures. This preserves partial mosaics and magenta transparency.
The 107 original scenery placements have feet anchors and share actor depth
sorting. Their logical blocked cells remain exactly as in Swift. Mine terrain
and wall/cliff mosaics remain projected ground tiles. All these projections
are temporary derivatives pending purpose-made isometric art.

Projectiles currently use colored circles; beams and event cues use procedural
lines and rings in the effects scene. These are temporary presentation assets.
The original bullet and arrow images remain copied in `assets/Sprites/Objects/`
for a later visual pass. Logical projectile movement and damage are unchanged.

Priorities for replacement are wall/cliff edge faces, consistent tree and
windmill viewing angles, consistent tower angles, and larger character sheets. Some
legacy sheets have fractional frame dimensions; the view uses texture regions
instead of assuming that image dimensions divide into integer frames. The
projected terrain PNGs are explicitly temporary derivatives, not new original
artwork.

## Stale Swift documentation found during conversion

`docs/adding-levels.md` documents `PlayerStart`/`NathanielStart`, collision tile
properties, and survival with one spare life and 50 resources. Current Swift
code instead requires `Nathaniel` and `Hermes`, treats any nonzero Collision
cell as blocked, and configures survival with zero spare lives and 30
resources. The Godot conversion follows current `GameScene`, `TMXRenderer`,
`EnemyManager`, and `LevelConfig` behavior. The original documentation and
implementation remain intact for this migration.

API references used: Godot stable documentation for
[TileMapLayer](https://docs.godotengine.org/en/4.7/classes/class_tilemaplayer.html)
and [TileSet](https://docs.godotengine.org/en/4.7/classes/class_tileset.html).
Native serialization and grid offsets were also checked with the pinned
4.7.2 executable.

## Export and platform checks

`godot/export_presets.cfg` defines `macOS` and `iOS` with the separate bundle
identifier `dev.ruarfff.nathaniel.godot`. It does not replace the original
Swift app identity. The macOS preset uses local ad-hoc signing. The iOS
preset exports an Xcode project without building or signing an archive.
No real signing identity, team, provisioning profile, or certificate is
stored in this repository.

Use the matching **4.7.2 stable export templates**, available through Godot's
**Editor → Manage Export Templates** and the
[official release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable).
The tested official non-Mono archive has SHA-256:

```text
f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011
```

The repeatable helper creates a private copy of the project and editor. It
uses Godot's self-contained `_sc_` mode, so export never changes the tracked
preset, global editor settings, or managed Godot installation. It checks the
pinned version and fails on engine errors even if Godot exits with code zero.
It finds the standard installed templates or the local checked artifacts in
`test-artifacts/godot/export-templates`; use `--templates DIRECTORY` or
`GODOT_TEMPLATE_DIR` to select another directory. It does not download tools.

```sh
python3 godot/tools/export_project.py macOS --release
python3 godot/tools/export_project.py iOS --unsigned-ios
```

Default outputs are under ignored `godot/exports/macos/` and
`godot/exports/ios/`. `--output PATH` sets another artifact path. Integration
checks completed both exports with no engine errors and verified that the
tracked preset SHA-256 was identical before and after export.

For iOS, set the intended team in the local export configuration when building
for a device. Godot requires a nonempty team even for project-only export.
The helper applies a `0000000000` placeholder only in the staged preset when
`--unsigned-ios` is supplied. The repository preset is never changed.
The subsequent Xcode build used `CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM=`;
no signing attempt or account access took place. Godot generated a sibling
`NathanielGodot.xcodeproj`; project-only export did not create an `.ipa`.

The macOS debug export completed with the official template on Apple M4 Pro.
The exported app was launched with `-- --debug-port=8769
--storage-dir=/tmp/nathaniel-godot-cua-isolated` so testing did not use real
save files. The native content preview was rendered with OpenGL 4.1 / Metal
Compatibility. See the migration verification record for real input checks.

The official iOS template has a confirmed simulator architecture limitation
on this host: its `ios-arm64_x86_64-simulator/Info.plist` advertises both
architectures, but `lipo -info` reports that `libgodot.a` contains only
`x86_64`. The default arm64 Simulator build fails at link with `_main`
undefined. An unsigned arm64 **device** build also succeeds with `ARCHS=arm64` and
`-destination 'generic/platform=iOS'`. No physical-device run has been verified.
An explicit Intel simulator build succeeds:

```sh
xcodebuild -project godot/exports/ios/NathanielGodot.xcodeproj \
  -scheme NathanielGodot -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/nathaniel-godot-ios-simulator \
  CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM= ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO build
```

Installation of that Intel app on the only installed runtime, iOS 26.5 on
an iPhone 17 Pro Simulator, fails because no matching architecture exists.
The migration built the missing arm64 **debug** simulator library from the
same official 4.7.2 source tag, then combined it with the original Intel
library in a separate local template archive. The original downloaded archive
was preserved. The corrected ARM64 Simulator build succeeds; runtime checks
are recorded in the migration verification report. This fix changes only
the debug simulator library; device and release libraries remain original.
The Swift app installation remains separate and intact.

The local template archive and SHA-256/build provenance are in ignored
`test-artifacts/godot/export-templates/`. To reproduce the missing library,
obtain the official source tag and use Xcode, Python, and SCons from the
managed tool environment. No managed installation is modified:

```sh
scons platform=ios arch=arm64 simulator=yes target=template_debug \
  debug_symbols=no optimize=none disable_3d=yes vulkan=no metal=no \
  module_csg_enabled=no module_gltf_enabled=no module_gridmap_enabled=no \
  module_openxr_enabled=no -j12
```

This local build completed in 95 seconds on Apple M4 Pro. Use `lipo -create`
to combine `bin/libgodot.ios.template_debug.arm64.simulator.a` with the
original Intel simulator library. Replace only
`libgodot.ios.debug.xcframework/ios-arm64_x86_64-simulator/libgodot.a`
in a copy of `ios.zip`. Store that copy beside `macos.zip` in the selected
template directory. See the [Godot iOS engine build guide](https://docs.godotengine.org/en/4.7/engine_details/development/compiling/compiling_for_ios.html).

The simulator test build uses `ARCHS=arm64`,
`-destination 'generic/platform=iOS Simulator'`, and
`CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM=`. It uses the Compatibility
renderer, as required by the iOS simulator.

Godot export references:
[macOS](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_macos.html)
and [iOS](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html).
