# Iron & Ink production assets

The first replacement batch is the gun, laser, and healing towers, based on
`concept-art/iron-and-ink/03-human-structures.png`. They use one shared pedestal
and palette: petrol-blue armor, ochre panels, dark joints, and pale metal edges.
The barrel, split laser emitter, and open healing mast identify each role.
These are editable Blender models. The concept images are visual references.

The second batch replaces Nathaniel, Hermes, the grunt, soldier, boss, alien
spawner, and spent soldier body. Mobile actors have directional animation;
the spawner and body are static renders. The [environment batch](environment-assets.md)
replaces terrain, paths, buildings, and upright scenery using the Earth concepts.

Nathaniel now uses a live character with interchangeable rifles, independent
movement and aim, and hand recoil. See [Nathaniel's weapons](nathaniel-weapons.md)
for the source rig, exports and pickup authoring. His directional PNG clips
remain available as a fallback.

## Resolution and game scale

The `iron_ink` profile in `art/blender/settings.json` renders at **8 texture pixels
per logical screen pixel**. Each tower has a 1024×1024 RGBA preview, with its ground
anchor at `(512, 768)`. Its logical canvas remains 128×128 with anchor `(64, 96)`.
The orthographic projection and 32-world-point Blender unit stay unchanged.
The gun tower now uses a live model in gameplay; laser and healing towers use
their PNGs. The gun's render resolution follows its on-screen size, up to density 8.

At 3840×2160, the game's 1280×800 expanding canvas scales by 2.7. At the current
maximum camera zoom of 2, one logical pixel occupies 5.4 screen pixels. Density 8
supplies enough source pixels for this view. Increasing resolution does not
increase tower collision size, range, speed, or placement footprint.

Godot uses linear filtering and mipmaps for the new towers. Legacy pixel sprites
retain nearest filtering. Three 1024×1024 RGBA textures use about 12 MiB before
mipmaps, or 16 MiB including them; this is a texture-memory estimate, not a
measurement of the game's total GPU memory.

`ActorVisual.pixels_per_world_pixel` selects the fixed-density rendering path.
`ground_anchor` gives the anchor within a frame in source pixels. A zero density
keeps the legacy display-size and bottom-center convention. The existing
`display_size` still positions health bars. Transparent canvas padding does not
set the visible art size or movement footprint.

If a profile's density or canvas anchor changes, update the actor resource's
density and anchor from the new export record as well. Generated scenery scenes
already receive these values on each export; authored actor resources remain
explicit Godot resources. The HD tests check the tower values against the records.

## Sources and commands

| Asset | Editable source | Generator |
| --- | --- | --- |
| Gun tower | `art/blender/sources/gun_tower.blend` | `tools/blender/generate_gun_tower.py` |
| Laser tower | `art/blender/sources/laser_tower.blend` | `tools/blender/generate_laser_tower.py` |
| Healing tower | `art/blender/sources/heal_tower.blend` | `tools/blender/generate_heal_tower.py` |

`tools/blender/iron_ink_towers.py` contains the shared parts and palette. The
models separate the base and turret parts for manual editing and later animation.
Runtime images and export records are in `assets/generated/`. The three existing
resources in `resources/actors/` select the replacement art for normal gameplay.

Open a saved source in Blender, edit it, save it, and export:

```sh
rtk make art-render ASSET=gun_tower
rtk make art-regenerate
rtk make import
rtk make art-review
```

To make a new source from one of the generators:

```sh
rtk make art-generate ASSET=gun_tower_variant \
  GENERATOR=tools/blender/generate_gun_tower.py PROFILE=iron_ink
```

The selected profile is saved as the scene's `asset_profile` custom property.
Rendering reads that property and the current shared settings. Generating never
overwrites a saved source; rendering never saves it. Changes to a generator do
not automatically change existing models. Edit those models or generate a new
variant explicitly. See [Blender authoring](blender-assets.md) for dependencies,
ground coordinates, source safety, and export checks.

## Live gun tower

The gun tower rotates its 3D turret continuously while the pedestal stays fixed.
Godot draws the model through a transparent orthographic viewport, then places
that image at the same ground anchor as the sprites. Terrain, gameplay coordinates,
camera controls, and actor Y sorting keep their existing conventions.

Open `art/blender/sources/gun_tower.blend` to edit it. The saved source contains:

- `AimPivot`: the vertical turning joint. Keep it at zero rotation when saving.
- `Recoil`: the sliding gun assembly below the pivot. Keep its rest location zero.
- `Muzzle`: the barrel opening, parented to `Recoil`. Move this marker when the
  barrel length changes. Local +X points out of the barrel; keep local Y zero.

The fixed pedestal is outside `AimPivot`. Geometry and materials remain editable.
The original source was migrated by adding these controls and preserving mesh
coordinates and materials. New gun generators include the controls. For another
unmodified copy of the earlier source, run the one-time migration explicitly:

```sh
rtk sh tools/blender.sh rig-gun gun_tower_variant
```

The migration refuses ambiguous or partial rigs. Repeating it on a valid source
does not save or alter the file. It is never part of rendering or game startup.

After saving an art edit, use the same export command as before:

```sh
rtk make art-render ASSET=gun_tower
rtk make import
rtk make art-gun-turret-preview
```

The saved `asset_model` flag adds a self-contained `assets/generated/gun_tower.glb`
and `scenes/actors/generated/gun_tower_model.tscn` to the normal PNG/JSON outputs.
Blender's bundled glTF exporter is the only extra export dependency. The generated
scene records the shared camera, lighting, canvas, anchor, and maximum density.
`ActorVisual.model_scene` selects it; the PNG remains available as a fallback.
Do not edit generated models or scene files. Render/regenerate read the saved
source and never rebuild or save it.

`model_sun_energy_scale` converts the shared Blender sun strength to the native
Godot light. It is currently 0.1. The matte palette is matched, but Godot's direct
lighting does not reproduce all Cycles indirect light and soft shadows.
Exports need Godot templates with 3D support. The earlier custom iOS Simulator
template recorded in `docs/verification.md` disabled 3D and cannot run this model.

`ActorModelView` owns projection, continuous yaw, short recoil, and the transformed
muzzle marker. `ActorView.weapon_muzzle(direction, weapon_id)` returns the launch
offset without turning the displayed gun; omit the weapon ID for a tower.
Nathaniel uses the same contract with [modular guns](nathaniel-weapons.md).
Other actors retain their sprite path. The tower rig supports horizontal aiming
and sliding recoil; the character guide describes independent legs and hand grips.

Shot events carry the projectile ID and its logical direction at emission.
`WorldEffects` captures the muzzle offset once and uses it for both the flash and
bullet. The visible bullet travels parallel to its logical path at muzzle height;
turning the tower cannot redirect it. Damage, range, projectile collision, and
movement-blocking footprints remain in the simulation. Saves keep logical shots;
loading reconstructs their visual offsets from their saved directions without
replaying firing effects.

Visible model viewports render when the pose or resolution changes. Idle and
off-screen towers retain their last image without rendering again. Resolution
follows screen scale, rounded up to a whole density and capped at 8. A transparent
viewport uses premultiplied blending; ordinary PNG sprites retain straight alpha.

```sh
rtk make test-gun-turret
rtk make art-gun-turret
rtk make test-art
```

The isolated preview uses mouse movement to aim, Space to fire, and P to pause.
It does not use player storage. The capture tool writes front, rear, exact
3840×2160, and game-scene views under `test-artifacts/`, plus JSON measurements of
30 visible turning towers at 1280×800 and 3840×2160. An offscreen viewport avoids
desktop window-size limits during the 4K check.
That workload excludes terrain and other units; it is not a full-game or mobile
performance result. The Blender checks cover repeated exports and saved edits.

### Reuse the weapon rig

Normal gameplay uses this model for both authored gun towers and towers built by
Hermes. The actor resource selects the model; aiming and muzzle placement have
no gun-tower-specific branch.

To make a weapon variant:

1. Open `gun_tower.blend` and use **Save As** to create
   `art/blender/sources/weapon_variant.blend`. This keeps the profile and rig
   properties. Leave the original source in place.
2. Edit the geometry and materials. Keep the fixed body outside `AimPivot`,
   turning parts below `AimPivot`, and sliding parts below `Recoil`. Place
   `Muzzle` at the new barrel opening. Keep the same world scale and ground origin.
3. Save the source, then run `rtk make art-render ASSET=weapon_variant` and
   `rtk make import`.
4. Duplicate the intended actor's `ActorVisual` resource. Set its `model_scene`
   to `scenes/actors/generated/weapon_variant_model.tscn`, set its PNG fallback
   and anchor from the export record, and assign the resource to the actor scene.

For an existing Blender model, add the same three controls manually and set the
scene properties `asset_model = true` and `weapon_forward_axis = "+X"`. The
`rig-gun` migration only recognizes the original gun tower geometry. The exporter
checks the shared control hierarchy and rest pose before writing the model.

Each actor gets its own aim and recoil state. The shared actor view supplies the
muzzle position, and the shared effects code places each shot from that position.
Changing the model does not require another aiming or projectile implementation.
Adding a new gameplay kind still follows the [actor authoring steps](authoring.md#add-or-change-an-enemy-or-tower).
Walking cycles, multiple barrels, and vertical aiming need additional rig support;
assigning this model does not add those animations.

## Live laser tower

The laser tower uses its saved 3D head in normal gameplay. The head turns toward
the target and tilts to the enemy's contact height. The folding pedestal stays
fixed. A cyan lens marks the firing point; the cyan-white beam starts there,
with a short aperture flash, a contact glow and repeated sparks. Laser firing
does not use gun recoil. The shared `LaserVisual` resource controls these effects.

Combat keeps the existing ten-resource cost, 350-point range, 20 damage per
second, 1.5-second burst and 3.5-second recovery. Pause freezes damage and beam
effects. Losing the target or removing the tower ends the beam. Save/load keeps
the firing phase and direction, then rebuilds the visual connection.

Edit `art/blender/sources/laser_tower.blend`, then export the saved source:

```sh
rtk make art-render ASSET=laser_tower
rtk make test-laser-tower
rtk make art-laser-tower
```

The rig is `AimPivot > PitchPivot > Recoil > Muzzle`. `AimPivot` stays at the
bearing; `PitchPivot` sits directly above it at the lens height. Keep controls at
zero rotation and unit scale. Keep `Recoil` at zero location and `Muzzle` on
local +X, at the lens opening. The side supports turn with yaw; the saved head
tilts with pitch. The PNG remains the static fallback.

For an older unmodified source, run
`rtk sh tools/blender.sh rig-laser-tower laser_tower` once. This explicit migration
retains the saved geometry, adds tilt supports, raises the head for clearance,
and changes the lens to cyan. It rejects partial rigs. Repeating it on a complete
rig leaves the source unchanged. Normal rendering does not run the migration.

`resources/actors/laser_tower.tres` selects the model and
`resources/weapons/tower_laser.tres` selects the beam appearance. `ActorModelView`
uses the same yaw/tilt calculation as mounted lasers. `WorldEffects` reads the
live muzzle after aiming; neither presentation component applies damage.

## Healing tower lights

The healing tower keeps its Blender-rendered PNG and fixed pedestal. Its three
cyan strips breathe slowly while idle, then brighten together on each successful
heal. A small ground ripple fades with the pulse. The healed character gets a
short cyan glint that follows its movement. All healing effects freeze on pause
and at the end of a game.

`HealingPulse` in `scenes/actors/heal_tower.tscn` owns the tower effect. Its
`light_segments` are pairs of endpoints in the source image's pixel coordinates.
The light overlay follows the sprite's scale and ground anchor. When changing
the image or cropping its canvas, update these endpoints to match the strips.
Duplicate the actor scene for a visual variant, then adjust its image, endpoints,
light color, and ripple radius. The timing code can stay shared.

Each healing tick restores up to 5 HP to both Nathaniel and Hermes when they
are alive, injured, and inside the tower's range. Full-health characters produce
no healing event. Successful `heal` events carry `owner_id` and `target_id`.
The application pulses the tower once per tick; `WorldEffects` shows a glint on
each healed character. Heal amount, range, and cadence remain in the domain.

Click a healing tower to show its range as a cyan ground outline. The outline
uses that tower's actual logical range and the same projection as the actors.
Selection leaves Nathaniel's orders and camera focus unchanged. Click elsewhere,
press Escape, return focus to Nathaniel, or open Build to clear it. A removed or
fog-hidden tower also loses selection. Range selection is not saved.

Run `rtk make test-healing-tower` for event-routing and rendered light checks.
The rendered check saves its comparison image under `test-artifacts/`.

## Animated characters

Nathaniel, Hermes, the grunt, soldier, and boss use editable Blender models with
saved keyframes. The `iron_ink` profile keeps the same density of 8 and camera as
the towers. Their generators are `tools/blender/generate_<asset>.py`; sources are
`art/blender/sources/<asset>.blend`. Nathaniel and Hermes share modelling helpers
in `iron_ink_characters.py`; the aliens use `iron_ink_aliens.py`.

Each source contains an unkeyed `AssetFacing` Empty at the ground origin. It has
zero rotation and unit scale. The model faces Blender +Y, which is logical +X in
the game. Model parts and limb controls are children of this root. Edit their
meshes, materials, transforms, and keyframes in Blender, then save and run:

```sh
rtk make art-render ASSET=nathaniel
rtk make import
rtk make art-characters
```

The scene's `asset_animation` JSON property lists the clips and sampled frames:

| Clip | Blender frames | Playback |
| --- | --- | --- |
| idle | 1 | One held pose |
| walk | 10, 12, 14, 16 | Four poses at 8 fps, looping |
| fire | 30, 32 | Recoil and recovery at 10 fps |

Frame 18 closes the walk cycle in the source. The exporter rotates `AssetFacing`
in memory for eight directions, samples the saved keyframes, and never saves the
source. It does not call the generator during export. Changing a generator does
not change an existing source. To add poses, edit the saved keyframes and the
scene's clip list together. Blender drivers that require Python execution and
external animation files are not part of this workflow.

Every frame is rendered on the fixed 1024×1024 canvas. One bounding rectangle
across all poses and directions removes unused borders. The exporter subtracts
that crop's origin from the ground anchor. It never fits individual models or
poses. Each atlas region removes more empty space, and native `AtlasTexture`
margins restore that same common canvas at playback. Identical rendered poses
share a region. Atlas pages have a maximum side of 4096 pixels, transparent
gutters, and lossless import with mipmaps. Packing preserves the rendered PNG's
RGBA values.

Exports include `<asset>.png` for a still preview, `<asset>_atlas_<page>.png`,
`<asset>_frames.tres`, and `<asset>.json`. The record contains the source/settings
hashes, source frames, crop, anchor, atlas regions, and Blender/Python versions.
The native `SpriteFrames` resource contains `idle_0` through `idle_7`, and matching
`walk` and `fire` names. Direction zero is logical +X; each index adds 45 degrees
to the logical heading. Godot's `AnimatedSprite2D` controls playback and timing.
The actor resource selects the frame resource. Its generated metadata carries
the density and ground anchor, so a changed crop is applied automatically after
re-export and import. Static and legacy sprites retain their actor-resource
settings.

Walking and attack poses follow existing simulation state and events. Pausing
freezes playback. Damage timing, collision sizes, movement rules, and death rules
stay in the domain. These clips do not add deployment, harvesting, or death
sequences. The laser tower remains static; the healing tower uses the light
overlay above. The live gun tower uses the
muzzle contract above; other units' beam and projectile origins retain their
existing presentation behavior. Terrain and scenery use the separate environment set.

The spawner uses `iron_ink_structure`: a 320×288 logical canvas with anchor
`(160, 224)`, still at density 8. This larger canvas changes framing only. Its
source is `spawner.blend`. `soldier_corpse.blend` uses the normal `iron_ink`
profile and the same armour parts as the living soldier. `WorldEffects` reads
its `ActorVisual` resource for scale and anchor; carried-body alpha and resource
delivery rules are unchanged.

Review commands:

```sh
rtk make test-animated-art
rtk make art-characters
rtk godot --path . --script res://tools/render_character_art.gd -- --preview
```

The preview uses the real actor scenes. `--animate` with Godot `--fixed-fps 12`
saves 48 review frames under `test-artifacts/character-animation/`. Test artifacts
are ignored and can be regenerated. Existing PNG-only assets remain available;
the new models were authored from the concept references, not reconstructed from
the old sprite sheets.

The current five animated actors contain 280 clip frames and 240 unique rendered
poses. Their lossless RGBA atlases use about **500 MiB including mipmaps**; the
boss accounts for about 186 MiB. This is the desktop detail profile, not a mobile
memory budget. The current GameApp capture reported 583 MiB of texture memory
for the whole scene on this host. That monitor value is not total GPU memory or
a frame-rate measurement. Keep these costs in view before adding longer clips
or more directions.

## Checks

```sh
rtk make test
rtk make test-art
rtk make test-hd-art
rtk make test-animated-art
rtk make test-static-art
rtk make format-check
```

The HD checks cover density, alpha, import settings, anchors, legacy sprite
placement, and rendered occlusion. `art-review` writes a comparison board and a
3840×2160 capture under `test-artifacts/`. Inspect these at their native resolution
to judge edges and small details. A texture-resolution check alone does not prove
performance on a physical 4K monitor or a mobile device.

See [dated verification results](verification.md#iron--ink-sprite-batches--2026-10-03) for the original
asset checks and platform limits. Current commands and contracts are above.
