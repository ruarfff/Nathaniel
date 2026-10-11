# Blender asset pipeline

Author saved `.blend` sources, then export sprites or live GLB models for Godot.
Use Blender **5.2.2**, pinned in `art/blender/settings.json`. The pipeline uses
Blender's bundled Python and `bpy`; no add-ons or separate Python environment.

## Setup and files

```sh
rtk make art-doctor
```

The wrapper checks `BLENDER`, `blender` on `PATH`, then standard macOS and Home
Manager application paths. Set `BLENDER=/path/to/blender` to select an installation.
The doctor reports executable, Blender, and Python versions and rejects a version
mismatch. Check exports before changing the pin.

| Location | Purpose |
| --- | --- |
| `art/blender/sources/*.blend` | Editable saved sources |
| `art/blender/settings.json` | Shared projection, canvas, anchors, lighting, profiles |
| `tools/blender/generate_*.py` | Optional source generators |
| `tools/blender/pipeline.py`, `tools/blender.sh` | Exporter and launcher |
| `assets/generated/` | PNGs, provenance JSON, SpriteFrames, and optional GLBs |
| `scenes/actors/generated/*_model.tscn` | Live models with shared camera and ground anchor |
| `scenes/scenery/generated/*.tscn` | Sprite scenes with exported anchors |

`art/.gdignore` excludes source art from Godot import. Track sources, generators
when used, shared settings, and exports together. Edit source art, not generated
PNG, JSON, GLB, or scene files. Hashes record provenance at export time. The
settings hash covers the whole file, including unrelated profiles; re-export to
refresh it rather than editing hashes or assuming a mismatch means bad pixels.

## Projection and scale

One Blender unit is **32 logical points**. X and Y are ground axes; Z is height.
Put the ground-contact anchor at `(0, 0, 0)` and geometry above Z = 0.
The orthographic camera uses 45° azimuth and 30° elevation.

`logical (x, y) = 32 * Blender (Y, X)`. At export scale, one Blender X unit
projects to `(-32, 16)` pixels, Y to `(32, 16)`, and height to about 39.192 pixels
upward. Image Y points down. This matches `IsoProjection` and the **64×32 diamond**;
the exporter checks the basis points each time.

The default canvas is **128×128**, with ground anchor **(64, 96)** from the top
left. Sprite offset is `(-64, -96)` with centering disabled and scale 1. Iron &
Ink profiles multiply canvas and anchor by render density 8, then use scale 1/8.
Select `PROFILE=iron_ink` when generating; saved `asset_profile` controls exports.

Never fit each model independently to its canvas. Edge-clipped exports fail.
Enlarge the shared canvas if needed, retaining world scale. Static default
exports retain transparent borders; environment exports trim and adjust anchors.
Animation uses common frame dimensions and atlas margins; see
[animated characters](iron-and-ink-assets.md#animated-characters).
Any crop must subtract its top-left origin from the anchor and set the sprite
offset to the negative of the new anchor.

## Create, edit, and export

Generate only when creating a new source:

```sh
rtk make art-generate ASSET=my_prop
rtk make art-render ASSET=my_prop
```

Names start with a lowercase letter and use lowercase letters, digits, and
underscores. Generation refuses to overwrite a source. For custom geometry,
copy `tools/blender/generate_placeholder.py`, keep `build()`, and pass
`GENERATOR=tools/blender/generate_my_prop.py`. You can also save a new source
directly in Blender using the same scale and origin.

For existing artwork:

1. Open its saved source under `art/blender/sources/`, edit, and save.
2. Make linked data local. Use **File > External Data > Pack Resources** for
   textures and save. Export rejects linked libraries and unpacked images.
   Use static textures; convert or pack other external dependencies.
3. Run `rtk make art-render ASSET=asset_name`.

Do not rerun a generator to update saved edits. Rendering opens a separate
Blender process, applies shared camera/light/output settings in memory, and
never saves the source. A hash check guards against source changes during export.
Static sources render frame 1; `asset_animation` sources render saved clips in
eight directions. Terrain exports named tile collections to padded atlases and
a TileSet. `asset_model` adds saved geometry and markers as GLB and a 3D scene.
Use [actor guides](authoring.md#add-or-change-an-enemy-or-tower) for rig contracts.

The saved deployed Hermes source contains the G1 reel, orbital guide, and clamp.
Its guide follows the domain route; the same clamp subtree renders in a separate
viewport at full recovery reach. Verify controls and export hashes with:

```sh
rtk blender --background --factory-startup --disable-autoexec --python-exit-code 1 --python tools/blender/resource_gathering.py -- verify hermes_anchor
```

Shared exports use CPU Cycles, a fixed seed, transparent film, no denoising or
motion blur, a box pixel filter, and 8-bit RGBA. Sample counts come from shared
settings, including per-layer overrides. JSON records Blender/Python versions and
source/settings hashes. Repeatability requires the same environment; identical
bytes across Blender versions or platforms are not guaranteed. PNG text, timestamps,
and EXIF are removed because they contain timings and local paths; pixel and color
data remain unchanged.

After a shared settings change, `rtk make art-regenerate` renders all saved sources
without rerunning generators.

## Use and check the export

Open Godot or run `rtk make import`. Sprites use lossless imports, alpha-border
fixing, and straight alpha. Terrain uses premultiplied imports with matching
TileData material. Default sprites use nearest filtering without mipmaps;
higher-density profiles use linear filtering and mipmaps.

Instance the generated scenery scene under a level's `Scenery` node to retain its
anchor and actor Y sorting. Paint blocked cells on `Collision` separately:
image dimensions, transparent pixels, and mesh bounds do not block movement.
See [level authoring](authoring.md).

```sh
rtk make art-preview
rtk make test-art format-check
```

The isolated preview checks ground alignment, scale, transparency, and front/behind
sorting. `test-art` checks projection, output, repeated-export source preservation,
and Godot structure/rendering. Rendered checks require a display and write
`test-artifacts/blender-preview.png`. For manual source validation, save a visible
edit, export twice, reopen the source, and confirm the edit remains.
See [environment assets](environment-assets.md) for terrain and
[testing](testing.md) for playtests and platform limits.
