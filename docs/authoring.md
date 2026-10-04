# Content authoring and exports

Open `project.godot` with **Godot 4.7.2 stable**, or run `make editor`. Native
`.tscn` levels are authoritative. Normal startup and resource import preserve
the authored scenes; no source-map conversion runs.

| Task | Guide |
| --- | --- |
| Edit levels, encounters, footprints or effects | Sections below |
| Create a Blender source or export a saved edit | [Blender pipeline](blender-assets.md) |
| Edit tower models, healing lights or sprite clips | [Iron & Ink assets](iron-and-ink-assets.md) |
| Edit Nathaniel's live rig, guns or pickups | [Nathaniel's weapons](nathaniel-weapons.md) |
| Edit terrain, buildings or scenery | [Environment assets](environment-assets.md) |

`art-generate` creates a new source. `art-render` exports a saved source without
overwriting it. Godot capture commands write review images under `test-artifacts/`;
they do not author assets. Dated test results are evidence for the named revision
and workload, not setup instructions.

## Edit and run a level

1. Open `levels/level_1.tscn` in the 2D editor. The other campaign scenes
   are `level_2.tscn` through `level_5.tscn`; `level_0.tscn` is survival.
2. Select `Ground` or `NonCollision` and use the native TileMap paint tools.
   The shared environment TileSet contains high-resolution ground and path tiles.
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
The high-resolution TileSet uses 512×256 cells with TileMapLayer scale `(0.125, 0.125)`.
The layer offset `(-32, 0)` makes the transformed tile centers match the projected
logical centers. Keep that scale, offset, and tile layout when editing. Spawn marker
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

Actor scene origins are ground-contact positions, and the gameplay actor
container uses Y sorting. Generated art uses explicit pixel density and anchors.
Sprite-based actors use native SpriteFrames with eight logical headings;
generated metadata preserves anchors after crops change. Nathaniel uses a live
character model with a separate gun and independent leg movement. His PNG clips
remain a tested fallback. Animation playback stays in presentation.

The gun tower uses a live Blender-authored model through `ActorVisual.model_scene`.
Its turret turns continuously and its barrel marker supplies shot and muzzle-flash
positions. It still joins the same 2D ground-anchor Y-sort layer. Use the
[live gun tower guide](iron-and-ink-assets.md#live-gun-tower) to edit or export it.
Model bounds and barrel position do not define movement or collision footprints.

Legacy PNG sheets keep their display-size and bottom-center convention. Their
fallback renderer selects columns from projected motion and retains the original
row and Hermes moving-sheet mappings. Reusing old PNGs does not require Blender.

## Edit effects

Open `scenes/effects/world_effects.tscn` and select its root. The Inspector
groups corpse size and opacity, projectile radius and colors, laser width and
height, event-ring lifetime and expansion, delivery/target pulse timing,
character target colors, and placement-preview size and colors.
The application instantiates this reusable scene for its effects layer. Change
the scene's properties and run a level with F6 to inspect the result. Duplicate
the scene for a variant and select that scene in `GameApp`'s effects preload.
These settings change presentation only; damage, attack ranges, collision
radii, and tower-placement rules remain in the simulation. The scene defaults
preserve the existing visual output.

## Artwork and provenance

For new Blender-authored assets, use the [Blender sprite pipeline](blender-assets.md).
It keeps editable sources separate from runtime PNGs and preserves the existing
64×32 projection, ground anchors, and scenery sorting.

The [Iron & Ink assets](iron-and-ink-assets.md) replace the three human towers,
Nathaniel, Hermes, the enemies, spawner, and spent soldier body with editable
Blender models and high-resolution exports. The [environment set](environment-assets.md)
replaces the ground, paths, buildings, trees, rocks, and windmills.

The native levels preserve 107 distinct original scenery placements (119 across
the six scenes) and their blocked cells on the separate Collision layer.
Six former building mosaics now use upright scenery instances with shared actor
depth sorting. Original PNG-only art remains as provenance and legacy fallback;
the new Blender sources are authored models. Audio content is unchanged.

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
That earlier custom Simulator library was built with `disable_3d=yes`. It cannot
run the current live Nathaniel and gun-tower models. Use or rebuild a matching
template with **3D enabled** before running the current game in the Simulator.
The [verification record](verification.md) contains its provenance and limits;
an earlier successful Simulator run does not validate today's live models.

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
