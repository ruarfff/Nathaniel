# Blender asset pipeline

Use Blender to author terrain, props, and actors, then export PNG sprites or
live GLB models for the existing Godot presentation. The placeholder cube proves the workflow; its material is temporary
and does not define the game's art style. Existing PNG sprites remain usable.
They do not have editable Blender originals unless someone models new sources.

## Setup and files

The pipeline requires Blender **5.2.2**, pinned in
`art/blender/settings.json`. It uses Blender's bundled Python and `bpy`, with no
separate Python environment, pip packages, add-ons, or Blender MCP service.
Godot preview and checks use the project's existing Godot installation.

```sh
rtk make art-doctor
```

The wrapper checks `BLENDER`, then `blender` on `PATH`, then the standard macOS
application and Home Manager application paths. To select another installation:

```sh
rtk make art-doctor BLENDER=/Applications/Blender.app/Contents/MacOS/Blender
```

`art-doctor` reports the executable, Blender version, and bundled Python version.
A missing executable or version mismatch stops the command with an error. Change
the version pin only after checking the exports with the new version.

| Location | Purpose |
| --- | --- |
| `art/blender/sources/*.blend` | Editable, saved source artwork |
| `art/blender/settings.json` | Shared projection, canvas, anchor, lighting, and render settings |
| `tools/blender/generate_*.py` | Optional source generators |
| `tools/blender/pipeline.py`, `tools/blender.sh` | Export code and Blender launcher |
| `assets/generated/*.png` | Runtime RGBA sprites |
| `assets/generated/*.json` | Source/settings hashes, versions, projection, and anchor records |
| `assets/generated/*_frames.tres` | Native SpriteFrames for saved animation clips |
| `assets/generated/*.glb` | Self-contained live character and weapon models, when enabled in the source |
| `scenes/actors/generated/*_model.tscn` | Live model with shared camera, light, and ground anchor |
| `scenes/scenery/generated/*.tscn` | Generated Sprite2D scenes with the correct anchor |

`art/.gdignore` keeps source art outside Godot import. Keep the `.blend`, generator
when used, shared settings, and exported files together in version control.
Change source art rather than editing the generated PNG, JSON, or scene files.

Manifest hashes record the source and settings **at export time**. The settings
hash covers the whole file, so adding an unrelated profile changes it even when
an asset's effective settings are unchanged. Re-export to refresh provenance;
do not edit hashes by hand or treat that mismatch alone as evidence of bad pixels.

## Projection and scale

One Blender unit equals **32 logical world points**. Blender X and Y are ground
axes; Z is height. Put the prop's ground-contact anchor at `(0, 0, 0)`, with the
model above Z = 0. The placeholder is a one-unit cube with its bottom center at
that origin.

The shared orthographic camera has 45° azimuth and 30° elevation. At the exported
scale, one unit along Blender X projects to `(-32, 16)` pixels and one unit along
Blender Y to `(32, 16)` pixels, using image coordinates with positive Y down.
The mapping is `logical (x, y) = 32 * Blender (Y, X)`: Blender Y follows logical X,
and Blender X follows logical Y. This matches `IsoProjection` and the game's
**64×32 diamond**. One unit of height projects about 39.192 pixels upward. The
exporter checks these basis points each time.

The default profile's canvas is **128×128**, and its ground anchor is pixel **(64, 96)**
from its top-left corner. The generated Sprite2D is not centered and has offset
`(-64, -96)`, so its node origin is the ground anchor. Keep sprite scale at 1;
the game applies its own world zoom.

The [Iron & Ink profile](iron-and-ink-assets.md) multiplies both dimensions and
the anchor by a shared render density of 8, then uses sprite scale 1/8. This
adds source pixels for 4K screens without changing world scale. Select it when
creating a source with `PROFILE=iron_ink`; its saved `asset_profile` property
controls later exports. The original placeholder retains the default profile.

Models are never fitted independently to their canvas. An export that reaches
the image edge fails. For larger art, enlarge the shared canvas and place its
anchor so the art fits, then regenerate all exports. Keep the world scale fixed.
Default static exports retain transparent borders. The environment profile trims
them and adjusts the exported anchor. Animated actors use common frame
dimensions with tight atlas crops and native margins, as described in the
[animation guide](iron-and-ink-assets.md#animated-characters).
If another tool trims an image, subtract
the crop's top-left origin from the anchor and update the sprite offset to the
negative of that new anchor. Cropping without this adjustment moves the prop.

## Create an asset

Generate a new source from the sample generator, then render it:

```sh
rtk make art-generate ASSET=my_prop
rtk make art-render ASSET=my_prop
```

Names start with a lowercase letter and use lowercase letters, digits, and
underscores. Generation creates `art/blender/sources/my_prop.blend` and refuses
to overwrite an existing source. Rendering is a separate command.

To create different geometry, copy `tools/blender/generate_placeholder.py`, keep
its `build()` entry point, and use your script:

```sh
rtk make art-generate ASSET=custom_prop GENERATOR=tools/blender/generate_my_prop.py
```

The generator runs once to create the editable source. Do not rerun it to update
a manually edited asset. You can also create a source directly in Blender and
save it under `art/blender/sources/` with the same scale and origin conventions.

## Edit and export

1. In Blender, open `art/blender/sources/placeholder_prop.blend`, or your own
   source. Edit its geometry and materials, keeping the ground anchor at the
   origin. Save the file before exporting.
2. Make linked Blender data local. For image textures, use **File > External
   Data > Pack Resources** and save. Export rejects linked `.blend` libraries
   and unpacked image textures. Use static images; sequence, movie, and tiled
   textures are outside this first pass. Other external asset dependencies must
   also be packed or converted to local static geometry.
3. Render the saved source:

   ```sh
   rtk make art-render ASSET=placeholder_prop
   ```

Rendering opens the saved file in a separate Blender process. It applies the
shared camera, light, world, and output settings in memory; source camera and
light edits do not control the export. Static sources render frame 1. Sources
with an `asset_animation` scene property render their saved clip frames in eight
directions. Terrain sources render their named tile collections into padded
atlases and a native TileSet. None of these paths saves the source. A source hash check guards against
source changes during rendering. A source with `asset_model` also exports its
saved weapon geometry and markers as a GLB and a native 3D scene. See the
[live gun tower guide](iron-and-ink-assets.md#live-gun-tower) for its rig and commands.

The default settings use CPU Cycles, 32 samples (64 for Iron & Ink), a fixed seed, no denoising,
transparent film, no motion blur, a box pixel filter, and 8-bit RGBA PNG.
Per-layer sample overrides are reset to use the shared sample count.
The output record includes the Blender and
Python versions and the source/settings hashes. Repeatable results require the
same source, settings, and Blender environment; identical bytes across different
Blender versions or platforms are not guaranteed.
The exporter removes PNG text, timestamp, and EXIF metadata because Blender
includes render timings and local source paths in those chunks. Image pixels and
color information remain unchanged; provenance stays in the JSON export record.

To render every saved source after a shared settings change:

```sh
rtk make art-regenerate
```

This command renders existing `.blend` files. It does not rerun generators or
rebuild their contents.

## Use the export in Godot

Open the project or run `rtk make import`. The exporter records lossless
compression, alpha-border fixing, and straight alpha in sprite import settings.
Terrain atlases use premultiplied imports and a matching TileData material to
prevent dark joins under mipmap filtering.
The default profile has mipmaps off and nearest filtering. Higher-density
profiles enable mipmaps and linear filtering for smooth scale changes.
Use the scene in `scenes/scenery/generated/` to retain its exported anchor.

Place an instance under a level's `Scenery` node and move the node to the intended
ground position. The existing presentation joins scenery to actor Y sorting;
the ground-anchor Y position determines front/behind order. Keep the same
Y-sort conventions when placing the prop in another container.

Paint blocked cells on the level's `Collision` layer separately. Image dimensions,
transparent pixels, mesh bounds, and the generated scene do not define movement
blocking. See [level authoring](authoring.md) for the native map conventions.

## Preview and check

```sh
rtk make art-preview
rtk make test-art
rtk make format-check
```

The isolated `scenes/tests/blender_asset_preview.tscn` uses the sample prop,
projected ground diamonds, and the existing Nathaniel actor. It shows the prop
alone and with the actor behind and in front, using nested Y sorting as the game
does. It does not replace a campaign asset or add gameplay collision.

`test-art` checks the Blender projection, transparent output, and source-edit
preservation through repeated exports, then runs Godot structure and rendered
sorting checks. The rendered check requires a working display and writes
`test-artifacts/blender-preview.png`. For manual validation, save a visible
geometry or material edit in Blender, render twice, reopen the source, and check
that the edit remains. Use the preview to inspect scale, ground alignment,
transparency, and front/behind order. See the [environment guide](environment-assets.md)
for terrain, buildings, ruins, and scenery.

See [dated verification results](verification.md#base-blender-pipeline--2026-10-03) for the original
asset checks and platform limits. Current commands and contracts are above.
