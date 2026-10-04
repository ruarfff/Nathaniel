# Terrain and building authoring

The environment set follows `concept-art/iron-and-ink/01-scene.png` and the
three Earth building sheets, `07` through `09`. Ground uses muted olive earth,
sand, gravel, cracked concrete, and asphalt. Buildings use worn cream plaster,
brick, terracotta roofs, dark openings, and faded teal metal.

All six levels use the new terrain and scenery. Their routes, occupied cells,
spawn markers, and level rules remain unchanged. Existing earth paths retain
their broad shapes. Concrete and asphalt tiles are also available in the native
palette for new authoring; this pass does not redesign the roads.

## Files and commands

Use the installed Blender **5.2.2** and its bundled Python. No new Python
environment, packages, or add-ons are required. See [setup](blender-assets.md).

| Location | Contents |
| --- | --- |
| `art/blender/sources/environment_terrain.blend` | Editable ground materials and one collection per tile |
| `art/blender/sources/environment_*.blend` | Buildings, ruins, trees, rocks, and windmill |
| `tools/blender/generate_environment_*.py` | Optional generators for new sources |
| `tools/blender/iron_ink_environment.py` | Shared wall, roof, opening, rubble, and vegetation parts |
| `art/blender/settings.json` | Shared camera, lighting, density, and export profiles |
| `assets/generated/environment_*.png` and `.json` | Runtime images and export records |
| `resources/environment_tileset.tres` | Shared native terrain palette |
| `scenes/scenery/generated/environment_*.tscn` | Upright props with exported scale and anchor |

Open a saved source in Blender, edit it, save, then export:

```sh
rtk make art-render ASSET=environment_house
rtk make art-render ASSET=environment_terrain
rtk make import
rtk make art-environment
```

To render all saved environment sources:

```sh
rtk make art-environment-regenerate
```

These commands read saved models and materials. They do not rerun generators or
save over `.blend` files. Export records contain the Blender/Python versions,
source and settings hashes, image dimensions, and anchors or tile addresses.

To create a new building variant without overwriting the current source:

```sh
rtk make art-generate ASSET=environment_house_variant \
  GENERATOR=tools/blender/generate_environment_house.py \
  PROFILE=iron_ink_environment
rtk make art-render ASSET=environment_house_variant
```

## Terrain

The game still uses a **64×32 diamond** and 32 logical world points per Blender
unit. The native TileSet uses **512×256** cells, and each TileMapLayer has scale
`(0.125, 0.125)` and position `(-32, 0)`. Keep `LevelDefinition.tile_size = 32`.
Use the native TileMap paint tools; no runtime conversion rebuilds authored maps.

The `iron_ink_terrain` profile renders a 72×40 logical canvas at density 8.
The ground plane is 1.10 units wide. Its small overlap prevents transparent
seams under minification. Atlas regions are 576×320, with 16-pixel outer gutters
and 32-pixel separation. Atlas pages are at most 4096 pixels per side.
PNG files store straight alpha. Godot imports the terrain atlases with
premultiplied alpha, alpha-border fixing, and mipmaps. Each tile shares the
matching native blend material. This prevents dark joins from transparent
pixels when mipmaps reduce the textures. Layers use linear mipmap filtering.
Automatic TileSet texture padding is off because its generated texture drops
mipmaps in the installed Godot version.

The terrain source contains 110 named tile collections. Ground noise repeats
across tile edges. Sand path tiles have a packed, editable coverage image and
a material ramp that controls their broad edges. The old path silhouettes were
measured to retain the routes; their old colored pixels are not reused. Fully
transparent tiles retain occupancy where upright scenery supplies the artwork.

Only the scrub collection starts visible in the Blender viewport. Use the
Outliner to show the tile being edited; exporting selects each collection in
memory and preserves those saved visibility choices. Edit materials, packed
masks, or meshes in their existing collections. The scene's `asset_terrain`
JSON property selects the exported collections. Append
new entries to add tiles. Keep existing names and order; to retire a tile, keep
its entry and mark it empty. The exporter rejects changes that would move an
existing tile address and silently alter painted levels.

## Buildings and scenery

House, shop, garage, and warehouse each have standing and ruined sources. A
pair shares its ground origin, scale, and foundation. Ruins remove large roof
and wall sections and use a few slabs and beams. These are static appearances;
they do not add destructible-building gameplay.

Building and vegetation sprites use the shared `iron_ink_environment` profile:
416×384 logical framing, anchor `(208, 256)`, density 8. The exporter trims empty
borders and subtracts the crop origin from the anchor. Generated scenes apply
the resulting offset and scale. Re-exporting a changed silhouette updates its
anchor without moving placed scene instances.

Place generated scene instances under a level's `Scenery` node. Their origins
are ground anchors used by the existing actor/scenery Y sorting. Keep the
Scenery parent at unit scale. Paint movement blocking separately on `Collision`;
mesh bounds, image alpha, and building state do not determine navigation.

The migration replaces 119 existing tree, rock, and windmill placements and six
building mosaics. Existing building collision rectangles are preserved, including
two missing back corners and one small shop setback. Review those explicit
footprints when moving a building. The original PNG-only art remains on disk
for provenance; it was not reconstructed into these Blender sources.

`art/blender/environment_layout.json` records the original tile meanings,
building anchors and path coverage still used by the terrain generator.
The level migration is complete. Edit the native scenes directly; normal
startup and asset export do not rebuild levels.

## Checks and review

```sh
rtk make test-art
rtk make test-environment-art
rtk make test
rtk make format-check
```

`test-art` checks saved material edits, static crop anchors, unchanged source
hashes, identical repeated PNGs, and stable terrain addresses. The environment
checks compare level data and scenery origins with the pre-migration baseline,
then check imports, scale, transparency, tile seams, and front/behind sorting.

`art-environment` writes building, terrain, native-level, and 3840×2160 captures
under `test-artifacts/`. Inspect those at native resolution. A 4K render is not
a physical-display, frame-rate, mobile-memory, or real-input acceptance test.

The complete environment set is about 396 MiB of RGBA texture data including
mipmaps when all variants are loaded together. This is a desktop detail set;
it is not a verified mobile memory budget. Shared scene instances reuse textures.

See [dated verification results](verification.md#environment-assets--2026-10-03) for the original
asset checks and platform limits. Current commands and contracts are above.
