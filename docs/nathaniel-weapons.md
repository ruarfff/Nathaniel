# Nathaniel's weapons

Nathaniel starts each fresh level with the rifle. Walk over the brass-marked
weapon crate near the start to collect the heavy rifle. Collection unlocks the
second slot and keeps the current gun equipped. Press **1** or **2**, or use the
named weapon buttons, to switch. Both buttons work with touch.

A switch takes 0.35 seconds. Movement and the selected target continue. Firing
waits for both the switch and shot recovery. Switching cannot shorten the last
shot's recovery. Both guns use unlimited ammunition in this first version.

| Gun | Damage | Shot interval | Use |
| --- | ---: | ---: | --- |
| Rifle | 25 | 0.8 seconds | Original starting gun |
| Heavy rifle | 50 | 1.6 seconds | Larger single hits and stronger recoil |

The existing click/tap orders and automatic targeting remain. Right-click or
**F** requests a shot toward the pointer. If the gun is ready, Nathaniel turns
and fires once aligned. A later aim request replaces that pending point;
movement, target selection, a weapon switch, or death cancels it. Requests
during recovery do not queue extra shots.

The loadout survives a spare-life respawn and save/load. A fresh level starts
with the rifle and restores its authored pickup. Old native and Swift saves
load with the rifle. Saved pickups and bullets retain their identities; an
existing bullet keeps its original gun's damage and muzzle after a switch.

## Runtime responsibilities

`GameBalance.WEAPONS` holds combat values. `GameSimulation` owns the loadout,
pickup collection, equip timer and aim direction. `CombatRules` turns aim at
360 degrees per second and only fires within one degree of the target.
Presentation reads that same aim direction, so the barrel cannot visibly trail
behind a shot's direction.

`ActorModelView` places the complete character and the selected weapon in one
transparent 3D viewport. Its output uses the existing 64×32 projection, actor
ground anchor and Y sorting. Resolution follows display scale and camera zoom.
Locomotion follows movement independently, with a bounded turn between hips and
upper body. The gun and hands recoil together. Pausing freezes animation.

The character has an `AimPivot`, a `LocomotionPivot` and a fixed `WeaponMount`.
Each weapon has `Recoil`, `Muzzle`, `PrimaryGrip` and `SupportGrip` nodes. Both
first-pass guns share the same grip layout. The fixed mount and cached rest
markers allow a saved bullet's muzzle to be recovered from its weapon ID and
shot direction. Walk cycles and recoil must not move that rest muzzle.

`WeaponVisual` resources hold model scenes and recoil settings. Combat values
stay in the domain. Keep recoil shorter than the gun's shot interval. Reusing
these contracts for another unit does not require a new projectile system.
Different grip layouts or weapon classes will need explicit pose work.

## Editable sources and exports

Use the pinned Blender version and setup in [Blender assets](blender-assets.md).
The workflow uses Blender's bundled Python and no downloaded add-ons.

| File location | Purpose |
| --- | --- |
| `art/blender/sources/nathaniel.blend` | Editable character, node rig and leg clips |
| `art/blender/sources/weapon_rifle.blend` | Editable starting rifle |
| `art/blender/sources/weapon_heavy_rifle.blend` | Editable alternate rifle |
| `tools/blender/rig_nathaniel.py` | Explicit migration of an older character source |
| `tools/blender/generate_weapon_*.py` | New-source generators |
| `assets/generated/` | Runtime GLB, PNG and export metadata |
| `scenes/actors/generated/nathaniel_model.tscn` | Shared camera, lighting and model wrapper |
| `resources/weapons/` | Weapon model and recoil resources |
| `resources/actors/nathaniel.tres` | Character presentation and weapon list |

Open a source in Blender, edit its geometry or materials, save, then export:

```sh
rtk make art-render ASSET=nathaniel
rtk make art-render ASSET=weapon_rifle
rtk make art-render ASSET=weapon_heavy_rifle
rtk sh tools/blender.sh regenerate --prefix weapon_
rtk make import
```

Rendering opens the saved source and does not save over it. New-source
generation refuses to replace an existing source. For an older copy of
Nathaniel's source, run `rtk sh tools/blender.sh rig-character nathaniel` once;
this explicit migration adds the live rig and creates missing weapon sources.
It is not a normal render step. Keep node names and grip positions stable.
The embedded original rifle and sprite exports remain available for PNG
fallback. Existing PNG-only actors do not need Blender originals.

Add a `SpawnMarker` under a level's `Spawns`, choose `weaponPickup`, and set
`weapon_id` to author another pickup. Its marker position uses projected editor
coordinates. Put it on reachable ground. Pickup art is independent of terrain
and tower movement footprints; it has no blocking collision.

## Checks

```sh
rtk make test-nathaniel-weapons
rtk make art-nathaniel-weapons
rtk make test
rtk make format-check
```

The focused suite covers combat timing, save compatibility, native pickups,
controls, modular models, grip recoil, muzzle placement and 4K rendering.
The capture command writes both guns in the normal game at exact 3840×2160
under `test-artifacts/`. These are scripted checks; real platform input and
remaining limits are recorded in [verification](verification.md).
