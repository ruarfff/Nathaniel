"""Render saved animation poses into cropped atlases and native Godot SpriteFrames."""

from array import array
import hashlib
import json
import math
from pathlib import Path
import tempfile

import bpy


def animation_spec(scene):
    spec = json.loads(scene["asset_animation"])
    if spec.get("directions") != 8 or not isinstance(spec.get("clips"), list):
        raise ValueError("asset_animation requires eight directions and a clips list.")
    names = set()
    for clip in spec["clips"]:
        name = clip.get("name")
        frames = clip.get("frames", [])
        if name not in {"idle", "walk", "fire"} or name in names:
            raise ValueError("Animation clips must have unique idle, walk or fire names.")
        if not frames or len(frames) > 32 or any(type(frame) is not int for frame in frames):
            raise ValueError("Each clip needs 1–32 integer source frames.")
        fps = clip.get("fps", 0)
        if type(fps) not in {int, float} or not 0 < fps <= 60 or type(clip.get("loop")) is not bool:
            raise ValueError("Each clip needs an fps from 0 to 60 and a boolean loop.")
        if clip["loop"] != (name != "fire"):
            raise ValueError("Idle and walk must loop; fire must finish so the actor can return to movement.")
        names.add(name)
    if names != {"idle", "walk", "fire"}:
        raise ValueError("Animated actors require idle, walk and fire clips.")
    root = bpy.data.objects.get("AssetFacing")
    if root is None or root.type != "EMPTY" or root.animation_data:
        raise ValueError("Animated sources require an unkeyed AssetFacing Empty at the ground origin.")
    if root.location.length > 0.0001 or any(abs(v) > 0.0001 for v in root.rotation_euler):
        raise ValueError("AssetFacing must have zero location/rotation; model forward is Blender +Y.")
    if any(abs(v - 1) > 0.0001 for v in root.scale):
        raise ValueError("AssetFacing must have unit scale. Set scale on the model parts.")
    if root.parent is not None:
        raise ValueError("AssetFacing must be the top-level root.")
    geometry = {"MESH", "CURVE", "SURFACE", "FONT", "META", "VOLUME", "POINTCLOUD", "GREASEPENCIL"}
    descendants = set(root.children_recursive)
    for obj in scene.objects:
        if obj.type in geometry and not obj.hide_render and obj not in descendants:
            raise ValueError(f"Parent visible geometry '{obj.name}' under AssetFacing so every direction turns together.")
    return spec, root


def pixels_and_bounds(path):
    image = bpy.data.images.load(str(path), check_existing=False)
    width, height = image.size
    pixels = array("f", [0]) * (width * height * 4)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    left, bottom, right, top = width, height, -1, -1
    for y in range(height):
        alpha = pixels[(y * width) * 4 + 3:((y + 1) * width) * 4:4]
        occupied = [x for x, value in enumerate(alpha) if value > 0]
        if occupied:
            left = min(left, occupied[0])
            right = max(right, occupied[-1])
            bottom = min(bottom, y)
            top = max(top, y)
    if right < left:
        raise ValueError(f"Empty animation frame: {path.name}")
    if left == 0 or bottom == 0 or right == width - 1 or top == height - 1:
        raise ValueError(f"Animation reaches canvas edge: {path.name}. Enlarge shared canvas, never fit each pose.")
    return pixels, (left, bottom, right + 1, top + 1)


def save_pixels(path, pixels, width, height, pipeline):
    # Loaded PNG pixels are already display encoded. A float image/save_render
    # would apply the view transform again and brighten colors and alpha edges.
    image = bpy.data.images.new("Pipeline_Atlas", width=width, height=height, alpha=True, float_buffer=False)
    image.alpha_mode = "STRAIGHT"
    image.pixels.foreach_set(pixels)
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)
    path.write_bytes(pipeline.png_without_metadata(path.read_bytes()))


def sprite_frames_text(asset, pages, records, clips, anchor, density):
    lines = ['[gd_resource type="SpriteFrames" format=3]', ""]
    for index in range(len(pages)):
        lines.append(f'[ext_resource type="Texture2D" path="res://assets/generated/{asset}_atlas_{index}.png" id="p{index}"]')
    for index, record in enumerate(records):
        x, y, width, height = record["region"]
        lines.extend(["", f'[sub_resource type="AtlasTexture" id="f{index}"]',
                      f'atlas = ExtResource("p{record["page"]}")',
                      f'region = Rect2({x}, {y}, {width}, {height})',
                      'margin = Rect2(' + ', '.join(map(str, record["margin"])) + ')',
                      'filter_clip = true'])
    animations = []
    for direction in range(8):
        for clip in clips:
            name = f'{clip["name"]}_{direction}'
            frames = [f'{{"duration": 1.0, "texture": SubResource("f{i}")}}'
                      for i, record in enumerate(records) if record["animation"] == name]
            animations.append('{"frames": [' + ', '.join(frames) + '], '
                              f'"loop": {str(clip["loop"]).lower()}, "name": &"{name}", "speed": {float(clip["fps"])}' + '}')
    lines.extend(["", "[resource]", f"metadata/ground_anchor = Vector2({anchor[0]}, {anchor[1]})",
                  f"metadata/pixels_per_world_pixel = {density}",
                  "animations = [\n" + ",\n".join(animations) + "\n]", ""])
    return "\n".join(lines)


def render_animation(pipeline, asset, scene, settings, source, source_hash):
    """Only read saved geometry/keyframes; rotate the facing root in memory."""
    spec, root = animation_spec(scene)
    density = settings["render_density"]
    full_width, full_height = [value * density for value in settings["canvas"]]
    bounds = [full_width, full_height, 0, 0]
    records = []
    unique = []
    hashes = {}
    with tempfile.TemporaryDirectory(prefix="nathaniel-animation-") as temporary:
        temporary = Path(temporary)
        for direction in range(8):
            root.rotation_euler.z = -direction * math.pi / 4
            for clip in spec["clips"]:
                for frame in clip["frames"]:
                    scene.frame_set(frame)
                    path = temporary / f"frame_{len(records)}.png"
                    scene.render.filepath = str(path)
                    bpy.ops.render.render(write_still=True)
                    _, box = pixels_and_bounds(path)
                    bounds = [min(bounds[0], box[0]), min(bounds[1], box[1]),
                              max(bounds[2], box[2]), max(bounds[3], box[3])]
                    frame_hash = hashlib.sha256(pipeline.png_without_metadata(path.read_bytes())).hexdigest()
                    if frame_hash not in hashes:
                        hashes[frame_hash] = len(unique)
                        unique.append({"path": path, "bounds": box})
                    records.append({"animation": f'{clip["name"]}_{direction}', "source_frame": frame,
                                    "unique_frame": hashes[frame_hash]})
            print(f"Rendered {asset} facing {direction + 1}/8", flush=True)

        # One union crop for the complete animation preserves size and foot contact.
        padding = 2 * density
        left, bottom = max(0, bounds[0] - padding), max(0, bounds[1] - padding)
        right, top = min(full_width, bounds[2] + padding), min(full_height, bounds[3] + padding)
        width, height = right - left, top - bottom
        crop_top = full_height - top
        anchor = [settings["anchor"][0] * density - left, settings["anchor"][1] * density - crop_top]
        gutter = 2 * density
        # AtlasTexture margins restore the common canvas after tighter per-frame
        # crops. Simple deterministic shelves avoid paying for empty rifle/limb space.
        for frame in unique:
            box = frame["bounds"]
            frame["crop"] = [max(left, box[0] - padding), max(bottom, box[1] - padding),
                             min(right, box[2] + padding), min(top, box[3] + padding)]
        ordered = sorted(range(len(unique)), key=lambda i: (-(unique[i]["crop"][3] - unique[i]["crop"][1]), i))
        plans = [{"frames": [], "width": 0, "height": 0}]
        x, y, row_height = 0, 0, 0
        for index in ordered:
            frame = unique[index]
            frame_left, frame_bottom, frame_right, frame_top = frame["crop"]
            frame_width, frame_height = frame_right - frame_left, frame_top - frame_bottom
            cell_width, cell_height = frame_width + 2 * gutter, frame_height + 2 * gutter
            if max(cell_width, cell_height) > 4096:
                raise ValueError("Cropped animation exceeds the 4096-pixel atlas limit.")
            if x + cell_width > 4096:
                x, y, row_height = 0, y + row_height, 0
            if y + cell_height > 4096:
                plans.append({"frames": [], "width": 0, "height": 0})
                x, y, row_height = 0, 0, 0
            frame.update(page=len(plans) - 1, region=[x + gutter, y + gutter, frame_width, frame_height],
                         margin=[frame_left - left, top - frame_top, width - frame_width, height - frame_height])
            plan = plans[-1]
            plan["frames"].append(index)
            plan["width"] = max(plan["width"], x + cell_width)
            plan["height"] = max(plan["height"], y + cell_height)
            x += cell_width
            row_height = max(row_height, cell_height)
        pages = []
        for plan in plans:
            page_width, page_height = plan["width"], plan["height"]
            output = array("f", [0]) * (page_width * page_height * 4)
            for index in plan["frames"]:
                frame = unique[index]
                pixels, _ = pixels_and_bounds(frame["path"])
                x, y, frame_width, frame_height = frame["region"]
                frame_left, frame_bottom, _, _ = frame["crop"]
                for row in range(frame_height):
                    start = ((frame_bottom + row) * full_width + frame_left) * 4
                    destination = ((page_height - y - frame_height + row) * page_width + x) * 4
                    output[destination:destination + frame_width * 4] = pixels[start:start + frame_width * 4]
                if index == 0:
                    preview = array("f")
                    for row in range(bottom, top):
                        start = (row * full_width + left) * 4
                        preview.extend(pixels[start:start + width * 4])
                    save_pixels(temporary / f"{asset}.png", preview, width, height, pipeline)
            filename = f"{asset}_atlas_{len(pages)}.png"
            save_pixels(temporary / filename, output, page_width, page_height, pipeline)
            pages.append({"file": filename, "canvas": [page_width, page_height]})
        for record in records:
            frame = unique[record["unique_frame"]]
            record.update({key: frame[key] for key in ["page", "region", "margin"]})
        if pipeline.digest(source) != source_hash:
            raise ValueError("Source changed during animation rendering. Export cancelled.")
        for filename in [f"{asset}.png"] + [page["file"] for page in pages]:
            (pipeline.IMAGES / filename).write_bytes((temporary / filename).read_bytes())
            pipeline.write_import_settings(Path(filename).stem, density)
        (pipeline.IMAGES / f"{asset}_frames.tres").write_text(sprite_frames_text(asset, pages, records, spec["clips"], anchor, density))
        expected = {page["file"] for page in pages}
        for old in pipeline.IMAGES.glob(f"{asset}_atlas_*.png"):
            if old.name not in expected:
                old.unlink()
                old.with_suffix(".png.import").unlink(missing_ok=True)
    return {"canvas": [width, height], "anchor": anchor, "trimmed": True,
            "crop_origin": [left, crop_top], "uncropped_canvas": [full_width, full_height],
            "uncropped_anchor": [v * density for v in settings["anchor"]],
            "animation": spec, "atlas_pages": pages, "frames": records,
            "unique_frames": len(unique),
            "logical_canvas": [width / density, height / density],
            "logical_anchor": [v / density for v in anchor]}
