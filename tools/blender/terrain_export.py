"""Render saved terrain collections into padded atlases and a native TileSet."""

from array import array
import json
from pathlib import Path
import sys
import tempfile

import bpy

from animation_export import save_pixels


def render_terrain(pipeline, asset, scene, settings, source, source_hash):
    if settings["anchor"] != [value / 2 for value in settings["canvas"]]:
        raise ValueError("Terrain requires a centered canvas anchor to match native tile centers.")
    spec = json.loads(scene["asset_terrain"])
    entries = spec["tiles"]
    if not entries or len({entry["name"] for entry in entries}) != len(entries):
        raise ValueError("Terrain tile names must be nonempty and unique.")
    collections = []
    for entry in entries:
        collection = bpy.data.collections.get(entry["collection"])
        if collection is None:
            raise ValueError(f"Missing terrain collection: {entry['collection']}")
        collections.append(collection)
    included = {obj for collection in collections for obj in collection.all_objects}
    geometry = {"MESH", "CURVE", "SURFACE", "FONT", "META", "VOLUME", "POINTCLOUD", "GREASEPENCIL"}
    for obj in scene.objects:
        if obj.type in geometry and not obj.hide_render and obj not in included:
            raise ValueError(f"Put visible terrain geometry '{obj.name}' in a named tile collection.")
    density = settings["render_density"]
    width, height = [value * density for value in settings["canvas"]]
    gutter = 2 * density
    pitch_x, pitch_y = width + 2 * gutter, height + 2 * gutter
    columns, rows = 4096 // pitch_x, 4096 // pitch_y
    capacity = columns * rows
    if capacity == 0:
        raise ValueError("Terrain tile plus gutters exceeds the 4096-pixel atlas limit.")
    metadata_path = pipeline.IMAGES / f"{asset}.json"
    addresses = {entry["name"]: (index // capacity, [index % columns, (index % capacity) // columns])
                 for index, entry in enumerate(entries)}
    if metadata_path.exists():
        previous = json.loads(metadata_path.read_text())
        for tile in previous.get("tiles", []):
            if addresses.get(tile["name"]) != (tile["source_id"], tile["atlas_coords"]):
                raise ValueError(f"Terrain address would change for '{tile['name']}'. Append new tiles; keep existing entries and atlas capacity so painted levels remain valid.")
    pages, records = [], []
    with tempfile.TemporaryDirectory(prefix="nathaniel-terrain-") as temporary:
        temporary = Path(temporary)
        for collection in collections:
            collection.hide_viewport = False
            collection.hide_render = True
        for start in range(0, len(entries), capacity):
            batch = entries[start:start + capacity]
            page_width = min(columns, len(batch)) * pitch_x
            page_height = ((len(batch) + columns - 1) // columns) * pitch_y
            output = array("f", [0]) * (page_width * page_height * 4)
            for index, entry in enumerate(batch):
                collection = collections[start + index]
                collection.hide_render = False
                path = temporary / "tile.png"
                scene.render.filepath = str(path)
                bpy.ops.render.render(write_still=True)
                collection.hide_render = True
                image = bpy.data.images.load(str(path), check_existing=False)
                if tuple(image.size) != (width, height):
                    raise ValueError("Terrain render dimensions changed.")
                pixels = array("f", [0]) * (width * height * 4)
                image.pixels.foreach_get(pixels)
                bpy.data.images.remove(image)
                if not entry.get("empty", False) and max(pixels[3::4]) == 0:
                    raise ValueError(f"Empty terrain render: {entry['name']}")
                x, y = index % columns, index // columns
                for row in range(height):
                    destination = ((page_height - y * pitch_y - gutter - height + row) * page_width + x * pitch_x + gutter) * 4
                    output[destination:destination + width * 4] = pixels[row * width * 4:(row + 1) * width * 4]
                records.append(dict(entry, source_id=len(pages), atlas_coords=[x, y]))
                print(f"Rendered terrain {start + index + 1}/{len(entries)}: {entry['name']}", flush=True)
            filename = f"{asset}_atlas_{len(pages)}.png"
            save_pixels(temporary / filename, output, page_width, page_height, pipeline)
            pages.append({"file": filename, "canvas": [page_width, page_height]})
        if pipeline.digest(source) != source_hash:
            raise ValueError("Source changed during terrain rendering. Export cancelled.")
        for page in pages:
            (pipeline.IMAGES / page["file"]).write_bytes((temporary / page["file"]).read_bytes())
            pipeline.write_import_settings(Path(page["file"]).stem, density, premultiplied=True)
    tile_set = ['[gd_resource type="TileSet" format=3]', ""]
    for index, page in enumerate(pages):
        tile_set.append(f'[ext_resource type="Texture2D" path="res://assets/generated/{page["file"]}" id="p{index}"]')
    tile_set.extend(["", '[sub_resource type="CanvasItemMaterial" id="TerrainBlend"]',
                     'blend_mode = 4'])
    for index in range(len(pages)):
        tile_set.extend(["", f'[sub_resource type="TileSetAtlasSource" id="Atlas_{index}"]',
                         f'texture = ExtResource("p{index}")',
                         f'margins = Vector2i({gutter}, {gutter})',
                         f'separation = Vector2i({2 * gutter}, {2 * gutter})',
                         f'texture_region_size = Vector2i({width}, {height})',
                         'use_texture_padding = false'])
        for entry in records:
            if entry["source_id"] == index:
                x, y = entry["atlas_coords"]
                tile_set.extend([f'{x}:{y}/0 = 0', f'{x}:{y}/0/probability = 1.0',
                                 f'{x}:{y}/0/material = SubResource("TerrainBlend")'])
    tile_set.extend(["", "[resource]", "tile_shape = 1", "tile_layout = 5",
                     f'tile_size = Vector2i({64 * density}, {32 * density})'])
    tile_set.extend(f'sources/{index} = SubResource("Atlas_{index}")' for index in range(len(pages)))
    resource_name = asset.removesuffix("_terrain") + "_tileset.tres"
    resource = pipeline.ROOT / "resources" / resource_name
    resource.parent.mkdir(parents=True, exist_ok=True)
    resource.write_text("\n".join(tile_set) + "\n")
    metadata = {"source": source.relative_to(pipeline.ROOT).as_posix(),
                "source_sha256": source_hash, "settings_sha256": pipeline.digest(pipeline.SETTINGS),
                "blender_version": bpy.app.version_string, "python_version": sys.version.split()[0],
                "render_density": density, "tileset": f"resources/{resource_name}",
                "import_premultiplied_alpha": True,
                "tile_size": [64 * density, 32 * density], "canvas": [width, height],
                "gutter": gutter, "atlas_pages": pages, "tiles": records,
                "dependencies": ["Blender (bundled bpy and Python standard library)"]}
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n")
    expected = {page["file"] for page in pages}
    for old in pipeline.IMAGES.glob(f"{asset}_atlas_*.png"):
        if old.name not in expected:
            old.unlink()
            old.with_suffix(".png.import").unlink(missing_ok=True)
    print(f"Exported {len(records)} terrain tiles in {len(pages)} atlases; source SHA256 unchanged")
