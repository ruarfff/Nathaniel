# Content authoring and exports

Open `project.godot` with **Godot 4.7.2 stable**, or run `make editor`. Native
`.tscn` levels are authoritative. Normal startup and resource import preserve
the authored scenes; no source-map conversion runs.

## Edit and run a level

1. Open `levels/level_1.tscn` in the 2D editor. The other campaign scenes
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
   level. Zero spare lives permits the current life. `-1` ends
   campaign progression. Change dimensions with care: painted cells and
   markers are not stretched or moved automatically.
6. Press **F6 / Run Current Scene**. The game starts with this edited scene,
   including its in-memory resource values and markers. F5 starts the menu.

`Objectives/VictoryRule` labels the existing encounter goal in the editor.
It is an annotation: the level resource's `has_boss` field controls victory.
The marker is an editor annotation, not an arbitrary trigger system.

Levels use logical points with positive Y up. Rendering uses
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
campaign beyond the current six scenes. Update save-level validation and
regression coverage when adding a new level number.

## Add or change an enemy or tower

Reusable scenes are in `scenes/actors/`. Nathaniel, Hermes, Grunt,
Soldier, Boss, Spawner, all three towers, and corpses each have a scene.
Their **Visual** resources are in `resources/actors/`. Inspect the
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
Reusable full tree and windmill scenes are also in `scenes/scenery/`;
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

Open `scenes/effects/world_effects.tscn` and select its root. The Inspector
groups corpse size and opacity, projectile radius and colors, laser width and
height, event-ring lifetime and expansion, and placement-preview size and colors.
The application instantiates this reusable scene for its effects layer. Change
the scene's properties and run a level with F6 to inspect the result. Duplicate
the scene for a variant and select that scene in `GameApp`'s effects preload.
These settings change presentation only; damage, attack ranges, collision
radii, and tower-placement rules remain in the simulation. The scene defaults
preserve the existing visual output.

## Artwork and provenance

The native assets reuse the original character, tower, and audio content. Ground
atlases were projected into diamonds. Upright tree and windmill textures preserve
107 original placements, feet anchors, transparency, and actor depth sorting.
Their blocked cells remain part of the native Collision layer. These derivatives
and the original wall/cliff and character viewing angles are temporary until a
purpose-made isometric art pass replaces them.

Projectiles use colored circles; beams and event cues use procedural lines and
rings in the effects scene. The original bullet and arrow images remain in
`assets/Sprites/Objects/`. Some sprite sheets have fractional frame dimensions;
the view uses texture regions rather than assuming evenly divided integer frames.
Visual changes do not change logical damage, range, or navigation.

The retired TMX files and one-time converter are available in Git history at
`824c8f1`. They are provenance, not an active authoring or synchronization path.
Current content checks validate the native scenes and resources.

## Export and platform checks

`export_presets.cfg` defines macOS, iOS, and Web exports. Keep the bundle identifier
`dev.ruarfff.nathaniel.godot` and custom user directory `NathanielGodot` stable so
existing saves remain accessible. The visible app is named Nathaniel. The macOS
preset uses local ad-hoc signing; the iOS preset creates an Xcode project.

Use matching **4.7.2 stable export templates**. The helper finds the standard
installed templates or `test-artifacts/export-templates/`; set
`GODOT_TEMPLATE_DIR` or pass `--templates DIRECTORY` for another location.
It stages a private project and self-contained editor, preserving the tracked
preset, global editor settings, and managed Godot installation. It checks the
pinned version and fails on logged engine errors. It does not download tools.

```sh
make export-macos
make export-ios
make export-web
```

Outputs are `exports/macos/Nathaniel.app` and
`exports/ios/Nathaniel.xcodeproj`. `python3 tools/export_project.py --help` lists
custom output and template options. The iOS Make target exports an unsigned test
project with a placeholder team in its staged preset; it grants no signing
access and does not create an installable App Store archive.

The Web export produces `exports/web/index.html` and its companion files.
Use `make serve-web` for a local preview. See [browser setup and limits](web.md)
for templates, persistence, and static hosting.

The official template used during local verification lacked its advertised ARM64
Simulator library. A separate template copy adds a debug Simulator library built
from the matching 4.7.2 source. Device and release libraries remain unchanged.
Use that corrected template for the ARM64 Simulator on the tested host; the
[verification record](verification.md) contains provenance and limits.

Build the exported Simulator project with the installed Xcode tools:

```sh
xcodebuild -project exports/ios/Nathaniel.xcodeproj \
  -scheme Nathaniel -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/nathaniel-ios-simulator \
  CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM= ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build
```

Install and launch the resulting app in the selected Simulator to test touch
input. Use an explicit isolated `--storage-dir` for tests. Device deployment
requires local signing configuration and a physical device; an unsigned build
does not establish device input or distribution readiness.

Godot 4.7 references: [TileMapLayer](https://docs.godotengine.org/en/4.7/classes/class_tilemaplayer.html),
[TileSet](https://docs.godotengine.org/en/4.7/classes/class_tileset.html),
[macOS export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_macos.html),
and [iOS export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html).
