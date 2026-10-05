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
   and one enabled Hermes start. Enemy kinds are `grunt`, `soldier`, `gunSoldier`, `boss`, and
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

Hermes uses a live mobile model with an independent shoulder laser and a separate
live deployed model. The mobile source is `art/blender/sources/hermes.blend`;
export saved edits with `rtk make art-render ASSET=hermes`. Keep the shoulder's
`AimPivot/PitchPivot/Recoil/Muzzle` controls and its `LocomotionPivot` hierarchy.
The complete body and pod share one viewport, so the shoulder keeps its physical
side through turns and walking. The original SpriteFrames remain the fallback.
For an older unmodified Hermes source, `rtk sh tools/blender.sh rig-hermes hermes`
adds the shoulder controls and geometry once. It preserves saved body meshes and
walk actions, and does nothing when the complete rig already exists. Rendering
never runs this migration.

For the deployed model, edit
`art/blender/sources/hermes_anchor.blend`, then run
`rtk make art-render ASSET=hermes_anchor`. Keep `DeployBody`, the named limb
pivots, the four `Anchor` pivots, and `AimPivot/Recoil/Muzzle` intact:
`HermesView` uses those saved parts for the folding transition and cannon.
`make test-hermes-base` checks the pose, pause, range, cables, and rendering;
`make art-hermes-base` captures mobile, deployed, and reclaimed gameplay.
The [design reference](../concept-art/hermes-build-mode.md) separates current
behavior from the remaining tower assembly animation target.

Legacy PNG sheets keep their display-size and bottom-center convention. Their
fallback renderer selects columns from projected motion and retains the original
row and Hermes moving-sheet mappings. Reusing old PNGs does not require Blender.

### Laser appearance and contacts

`soldier` is the lance-laser type; `gunSoldier` fires travelling bullets from a
barrel arm. Both use the same health, movement, range, damage, shot interval and
rewards. Campaign maps 1–3 mix their existing soldier placements. Wave modes
split soldier selections equally between the two types, keeping total soldier
weight and wave timing unchanged. Spawner production still creates grunts.

The gun model is saved in `art/blender/sources/gun_soldier.blend`. Both corpse
sources keep the existing collapsed body, with their matching weapon at rest:
`soldier_corpse.blend` and `gun_soldier_corpse.blend`. Export saved edits with
`make art-render ASSET=gun_soldier`, `ASSET=soldier_corpse`, or
`ASSET=gun_soldier_corpse`. `rtk sh tools/blender.sh prepare-soldier-variants`
creates the gun source and fits the corpse weapons once; completed sources
remain unchanged on later runs. Rendering never runs this preparation step.

The effects scene assigns both corpse resources. The corpse's `source_kind`
selects its image, including while carried. Both types still give ten resources
on delivery. Run `make test-soldiers` for combat, saves and rendered gun checks;
`make art-soldiers` captures both living types and their death images.

`ActorVisual.laser` selects a `LaserVisual` resource. Hermes uses
`resources/weapons/hermes_laser.tres`: a narrow amber edge, ivory core, brief
aperture flash, and three short contact sparks. Duplicate this resource to make
another straight laser style, then assign it to the actor's Visual resource.
The existing tower beam retains its original appearance when no
laser resource is assigned. A resource changes presentation only; combat damage,
range and firing duration stay in the domain.

Spawner, soldier and boss use live models from their saved `.blend` sources.
The spawner crown turns above a fixed body. The soldier turns its body toward
the target and points its single lance arm. The boss opens two pale crest
shutters around the siege prism. Their `*_laser.tres` resources use a pink-white
core and crimson edge; the boss beam is wider. Nathaniel's authored contact
height places their impact on his upper body.

`rtk sh tools/blender.sh rig-enemy-laser spawner` migrates an older saved source;
the same command accepts `soldier` or `boss`. Existing body meshes, edited
vertices and walk actions are retained. Replaced weapon parts remain hidden
in the source for reference. Export saved edits with `make art-render ASSET=...`.
The generated `body_aim` metadata selects a fixed body, target-facing body or
movement-facing body. The muzzle and pitch-axis contracts are shared with
Hermes. Boss `ApertureLeft` and `ApertureRight` are optional presentation joints;
their opening does not delay damage.

Soldier and boss fire instant pulses with their previous damage, range and
shot interval. The spawner retains its timed continuous beam and production
rules. Pulse contact records keep lethal hits visible briefly and resume an
active nonlethal pulse after loading without applying damage again.

For another moving emitter, reuse the mobile source's `mounted_character` rig
and assign its exported scene to `ActorVisual.model_scene`. The body follows
`LocomotionPivot`; the shoulder uses `ShoulderMount > AimPivot > PitchPivot >
Recoil > Muzzle`. Keep the muzzle centered on local +X and the pitch joint
directly above the yaw joint. The exporter rejects offsets that would make the
aperture disagree with the aiming calculation. Body clips must not animate the
weapon aim controls. `rtk sh tools/blender.sh verify-hermes` checks the saved
Hermes source and exporter without changing production art.

`ActorVisual.contact_height` is the contact height above the target's ground
origin, in logical world points. `WorldEffects` converts it to the isometric
view. `ActorView` supplies `aim_laser(target_offset, target_height)` and
`laser_muzzle()` for live models. The first receives a logical offset from the firing actor to
the target; the second returns the current projected muzzle offset from the
actor's ground point. It must include the current walk and tilt pose. Keep
`weapon_muzzle(direction, weapon_id)` for projectile launches: that method uses
the saved weapon's rest pose so later turns cannot steer an existing bullet.

The beam follows current `firing` and target state. Contact effects add no damage.
A `hit` event retains the target's contact position for a lethal impact after
the actor is removed. Pause freezes the beam cues. Deploying Hermes selects the
cannon and ends the mobile beam; opening Build alone does not change weapons.

Run `rtk make test-lasers` and `rtk make test-hermes-base` after rig or effects
changes. `rtk make art-hermes-laser` captures the shoulder beam at normal zoom,
in detail, and while walking. `rtk make art-hermes-base` captures the cannon and
mode transitions. These commands use scripted setups; real input and platform
acceptance are recorded separately in [verification](verification.md).
Use `rtk sh tools/blender.sh verify-enemy-lasers` for source preservation and
body-clearance checks, and `make art-enemy-lasers` for actual-level captures.

## Edit effects

The backpack and both Hermes intake rigs are saved in the live character
sources. Keep their gathering nodes separate from weapon and locomotion mounts.
See [resource gathering](resource-gathering.md) for ownership phases, timings,
upgrades, and focused checks.

Corpse warning and dissolution use the existing corpse textures with
`scripts/presentation/corpse_self_destruct.gdshader`. `WorldEffects` drives the
warning from the saved armed countdown and keeps a short visual tail after
expiry. The existing clamp pad flashes amber at successful grip. These effects
use gameplay state rather than shader wall-clock time, so pause freezes them.
The lifetime, warning window, and dissolve duration are in `GameBalance`.

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
