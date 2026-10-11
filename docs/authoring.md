# Content authoring and exports

Open `project.godot` with **Godot 4.7.2 stable**, or run `rtk make editor`.
Native `.tscn` levels are authoritative; startup and import preserve saved content.

| Task | Guide |
| --- | --- |
| Levels, encounters, footprints, effects | Sections below |
| Saved Blender source and export | [Blender pipeline](blender-assets.md) |
| Tower models, healing lights, sprite clips | [Iron & Ink assets](iron-and-ink-assets.md) |
| Nathaniel's live rig, guns, pickups | [Weapons](nathaniel-weapons.md) |
| Terrain, buildings, scenery | [Environment assets](environment-assets.md) |
| Gathering rigs and body ownership | [Resource gathering](resource-gathering.md) |

`art-generate` creates a new source; `art-render` exports saved edits without
overwriting them. Godot captures write review images under `test-artifacts/`.

## Edit and run a level

1. Open `levels/level_1.tscn` in the 2D editor. Levels 1–5 are campaign.
   `levels/survival/` contains the four new Survival maps; `level_0.tscn`
   remains the original map for older saves and deterministic fixtures.
2. Paint `Ground` and `NonCollision` with the native TileMap tools.
3. Paint `Collision` to block navigation. Every occupied cell blocks, regardless
   of texture; physics polygons and custom tile properties do not define this rule.
4. Edit markers under `Spawns`: position, **Kind**, **Label**, and **Enabled**.
   Keep one enabled Nathaniel start and one enabled Hermes start. Enemy kinds
   are `grunt`, `soldier`, `gunSoldier`, `boss`, and `spawner`. Wave setup ignores
   map enemy markers. Starting towers use `gunTower`, `laserTower`, and `healTower`.
   An enemy or tower's **Parameters / New EncounterParameters** overrides shared
   stats. `-1` retains defaults; zero speed is stationary and zero damage harmless.
   Maximum HP, range, vision, cooldown, and projectile speed must be positive;
   current HP can be zero. Other marker kinds warn about unused parameters.
   Edit shared hero stats in `scripts/domain/game_balance.gd`.
5. Edit the root's **Definition**: dimensions, spare lives, starting resources,
   boss rule, wave mode, and next level. Zero spare lives permits the current life;
   next level `-1` ends progression. Resizing does not move painted cells or markers.
6. Press **F6** to run the edited scene, including in-memory resource changes.
   F5 starts the menu.

`Objectives/VictoryRule` is an editor annotation. `Definition.has_boss` controls
victory; the marker is not a trigger system.

Gameplay coordinates use logical Y up. Projection is `(x - y, (x + y) / 2)`;
a logical 32×32 cell is a 64×32 diamond. TileMaps use Diamond Down, 512×256 cells,
layer scale `(0.125, 0.125)`, and offset `(-32, 0)`. Keep this layout so tile centers
match logical centers. Spawn positions are projected editor points; runtime
converts them back. Combat and navigation never use stretched screen distances.

## Add a level

Duplicate a level and give its Definition a unique number. Use **Make Unique**
before changing shared resources. Paint layers, place starts/encounters, and test
with F6. Extend the level lookup, save-level validation, and regression coverage
when adding a level beyond the six shipped scenes.

### Survival maps

The four maps in `levels/survival/` are 52×52 cells at 32 logical points per
cell. Each has 2,704 ground cells, explicit `Collision`, two hero starts, a
heavy-rifle pickup, and enemy entry markers. `Clearings/A`, `B`, and `C` are
editor guides; they do not restrict building or give bonuses.

Keep Definition's mode number at `0`. Its `survival_map_id` identifies an
allowlisted entry in `scripts/domain/survival_map_catalog.gd`. New runs select
one of its four `NEW_RUN_IDS` with equal probability using a separate random
generator. `load_level(0)` still loads the original map. Retry and resume use
the selected identity without a new draw.

Under `Spawns`, use `enemyEntry` markers. A shared Label groups candidate
positions into an entry sector. Enabled candidates in every sector must have
a route to the hero area with boss/Hermes clearance. Keep several candidates
per sector, enough free space for a spawner, and broad alternate approaches.
The simulation checks world-space hero/base distance, terrain, occupancy, and
routes. If no candidate is valid, it keeps the pending spawn and retries later.
Tower placement cannot close the final route from any enabled sector.

Tree crowns and scenery bounds do not create collision. Paint trunks, walls,
containers, and rock footprints explicitly. Grass and roads have the same
movement rules; scenery does not block shots or provide cover.

To select a map for an isolated capture or playtest:

```sh
rtk godot --path . -- --survival-map=dry_wash --storage-dir=/private/tmp/nathaniel-dry-wash
rtk make test-survival profile-survival art-survival
```

`--survival-map` also pins subsequent new runs in that process. The normal
menu remains random. The demo export includes all four maps and the original
scene for save compatibility.

## Add or change an enemy or tower

Reusable scenes live in `scenes/actors/`; their `ActorVisual` resources live in
`resources/actors/`. Edit model/texture, frame layout, display size, feet offset,
shadow, health color, and animation. Shared resource changes affect every instance;
duplicate or make unique for a variant. Display size never changes collision.

To add a gameplay kind, register it in domain rules/balance, actor scene/visual
lookup, and the marker enum, then add a rule check. A new tower also needs cost,
refund, footprint, combat/healing, and build UI rules.

Actor origins are ground-contact positions. Live models and eight-heading sprite
fallbacks join the same actor Y-sort layer. Export metadata preserves anchors
after cropping. Animation belongs in presentation. See [actor assets](iron-and-ink-assets.md)
for tower rigs and clips, and [weapons](nathaniel-weapons.md) for Nathaniel.

Scenery uses native nodes under `Scenery`, with reusable scenes in
`scenes/scenery/`. Place trees and windmills at their trunk/base origins and paint
blocked cells separately. Upright props join actor Y sorting. Converted mosaics
use transparent alternative tile 1 to retain collision; alternative 0 remains
ground-plane art. Do not paint another visible mosaic under an upright prop.

### Hermes rigs

Edit saved sources, then run `rtk make art-render ASSET=hermes` or
`ASSET=hermes_anchor`:

| Source | Required controls |
| --- | --- |
| `art/blender/sources/hermes.blend` | `LocomotionPivot`; shoulder `AimPivot/PitchPivot/Recoil/Muzzle` |
| `art/blender/sources/hermes_anchor.blend` | `DeployBody`, limb pivots, four `Anchor` pivots, cannon `AimPivot/Recoil/Muzzle` |
| Deployed G1 winch, in the same source | `WinchRoot`, `WinchYoke`, `WinchDrum`, `WinchOutlet`, `WinchGuidePivot`, `WinchGuideArm`, `WinchGuide`, `WinchClamp`, two `WinchJaw` controls |

The mobile body and shoulder share one viewport. The deployed guide clears
stabilizers and conduit sockets and follows the domain route. Presentation uses
the same saved clamp in a separate viewport at recovery reach and poses cable
and cargo from simulation progress. Mobile Hermes has no winch. Use
`rtk make test-hermes-base` and `rtk make art-hermes-base` for pose and capture checks.

### Laser appearance and contacts

`ActorVisual.laser` selects a `LaserVisual` resource under `resources/weapons/`.
Duplicate one for a new style and assign it to the actor. Beam width, color,
aperture flashes, and contact sparks are presentation; damage and timing remain
in the domain. Without a laser resource, the fallback beam keeps its appearance.

Saved live sources include `spawner.blend`, `soldier.blend`, and `boss.blend`.
Their `body_aim` metadata selects fixed, target-facing, or movement-facing bodies.
The boss's optional `ApertureLeft` and `ApertureRight` joints do not delay damage.
`gun_soldier.blend` fires travelling bullets. `soldier_corpse.blend` and
`gun_soldier_corpse.blend` retain the matching weapon at rest; the body's saved
`source_kind` selects its appearance. Export saved edits with `art-render`.

For a moving emitter, use the `mounted_character` rig: body under
`LocomotionPivot`, weapon under `ShoulderMount > AimPivot > PitchPivot > Recoil >
Muzzle`. Center the muzzle on local +X and place pitch directly above yaw;
the exporter rejects offsets which disagree with aiming. Body clips must not
animate weapon aim controls.

`ActorVisual.contact_height` is logical height above the target's ground origin.
`ActorView.aim_laser(target_offset, target_height)` receives a logical offset;
`laser_muzzle()` returns the current projected muzzle offset, including walk/tilt.
Keep projectile `weapon_muzzle(direction, weapon_id)` in the saved rest pose so
later turns cannot steer an existing bullet.

Effects follow `firing` and target state. Lethal `hit` events retain contact
positions after removal. Instant pulses and restored active pulses never apply
damage from effects. Pause freezes cues; deployment switches Hermes to the cannon.

```sh
rtk make test-lasers test-soldiers test-hermes-base
rtk make art-hermes-laser art-enemy-lasers art-soldiers
rtk sh tools/blender.sh verify-hermes
rtk sh tools/blender.sh verify-enemy-lasers
```

## Edit effects

`scenes/effects/world_effects.tscn` exposes corpse, projectile, laser, ring,
delivery pulse, target tint, and placement preview settings. `GameApp` instantiates
it; duplicate and change its preload for a variant. These settings change only
presentation. Targets use amber for Nathaniel and cyan for Hermes, blended for a
shared target. Clicked corpses use Nathaniel's tint until grip; warning/dissolve
remain visible over it.

Corpse warning and dissolution use
`scripts/presentation/corpse_self_destruct.gdshader`. `WorldEffects` reads saved
armed time and retains only a visual tail after expiry. The clamp pad flashes
at disarm. State-based timing freezes with pause; `GameBalance` owns durations.
See [resource gathering](resource-gathering.md) for phase ownership and checks.

`boss_corpse.blend` supplies ground matter; `boss_bundle.blend` uses the `matter`
model role and `MatterRoot` parent for compressed cargo. `grunt_death.blend` and
`spawner_death.blend` supply non-looping `death` clips with `iron_ink_death` and
`iron_ink_death_structure` profiles. Grunts have eight headings; spawners one.
Keep fragments/dust within the shared canvas. `rtk make art-enemy-deaths` captures
deaths and boss delivery. These effects apply no damage.

## Artwork and provenance

Use [Blender](blender-assets.md), [actor](iron-and-ink-assets.md), and
[environment](environment-assets.md) guides for source exports and anchors.
Original PNG art remains provenance and fallback; some sheets have fractional
frame sizes and use texture regions. Retired TMX files and the one-time converter
are in Git at `824c8f1`, outside the active authoring path.

## Export and platform checks

`export_presets.cfg` defines macOS, iOS, Web, and Web Demo. Preserve the
[storage identity](saves.md#storage-identity). macOS uses local ad-hoc signing;
iOS exports an unsigned Xcode test project with a staged placeholder team.

Use matching **4.7.2 stable export templates**. The helper finds installed
templates or `test-artifacts/export-templates/`; set `GODOT_TEMPLATE_DIR` or pass
`--templates DIRECTORY` for another location. It stages a private project/editor,
preserves presets and managed installations, and rejects version or engine errors.
It does not download tools.

```sh
rtk make export-macos export-ios export-web
```

Outputs are `exports/macos/Nathaniel.app`, `exports/ios/Nathaniel.xcodeproj`, and
`exports/web/index.html` with companion files. `rtk python3 tools/export_project.py
--help` lists output/template options. Preview Web with `rtk make serve-web`.
Use `export-web-demo` and `serve-web-demo` for the separate Survival-only build;
see [Web and demo setup](web.md).

The local iOS template copy adds an ARM64 Simulator library because the official
template lacked one. That custom library was built with `disable_3d=yes` and
cannot run current live models. Use a matching template with **3D enabled** before
Simulator runtime or touch checks. Build the exported project with:

```sh
rtk xcodebuild -project exports/ios/Nathaniel.xcodeproj \
  -scheme Nathaniel -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/nathaniel-ios-simulator \
  CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM= ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build
```

Install and launch it in the selected Simulator to check touch. Use an isolated
`--storage-dir` for tests. Physical-device deployment requires local signing and
a device. Export or unsigned build success does not establish runtime, real input,
or distribution readiness. See [testing](testing.md) for the playtest procedure.
