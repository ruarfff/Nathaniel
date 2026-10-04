"""Generate sources or render saved sources; run only with Blender's Python."""

import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import re
import runpy
import sys
import tempfile

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SETTINGS = ROOT / "art/blender/settings.json"
SOURCES = ROOT / "art/blender/sources"
IMAGES = ROOT / "assets/generated"
SCENES = ROOT / "scenes/scenery/generated"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def png_without_metadata(data):
    """Keep PNG pixels/color data; discard Blender's date, timings and local paths."""
    chunks = [data[:8]]
    position = 8
    while position < len(data):
        size = int.from_bytes(data[position:position + 4], "big")
        end = position + size + 12
        kind = data[position + 4:position + 8]
        if kind not in {b"tEXt", b"zTXt", b"iTXt", b"eXIf", b"tIME"}:
            chunks.append(data[position:end])
        position = end
    return b"".join(chunks)


def source_path(asset):
    if not re.fullmatch(r"[a-z][a-z0-9_]*", asset):
        raise ValueError("Asset names must use lowercase letters, digits and underscores.")
    return SOURCES / f"{asset}.blend"


def export_settings(settings):
    profile = bpy.context.scene.get("asset_profile", "default")
    if profile == "default":
        return settings
    if profile not in settings.get("profiles", {}):
        raise ValueError(f"Unknown asset profile '{profile}' in saved source.")
    return dict(settings, **settings["profiles"][profile])


def configure(settings):
    """Apply the shared rig in memory. Geometry and materials remain authored data."""
    scene = bpy.context.scene
    density = settings["render_density"]
    if not isinstance(density, int) or not 1 <= density <= 16:
        raise ValueError("Render density must be an integer from 1 to 16.")
    width, height = [value * density for value in settings["canvas"]]
    anchor_x, anchor_y = [value * density for value in settings["anchor"]]
    if min(width, height) < 1 or not (0 < anchor_x < width and 0 < anchor_y < height):
        raise ValueError("Canvas dimensions must be positive and contain the anchor.")
    # The ground axes must remain identical to IsoProjection, even on a larger canvas.
    if (settings["camera_azimuth_degrees"], settings["camera_elevation_degrees"],
            settings["world_points_per_unit"]) != (45, 30, 32):
        raise ValueError("Nathaniel requires azimuth 45, elevation 30 and 32 world points/unit.")
    for obj in list(bpy.data.objects):
        if obj.name.startswith("Pipeline_") and obj.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(obj, do_unlink=True)
        elif obj.type == "LIGHT":
            obj.hide_render = True
    pixels_per_unit = 32 * math.sqrt(2) * density
    azimuth = math.radians(settings["camera_azimuth_degrees"])
    elevation = math.radians(settings["camera_elevation_degrees"])
    direction = Vector((math.cos(elevation) * math.cos(azimuth),
                        math.cos(elevation) * math.sin(azimuth), math.sin(elevation)))
    camera_data = bpy.data.cameras.new("Pipeline_Camera")
    camera = bpy.data.objects.new("Pipeline_Camera", camera_data)
    scene.collection.objects.link(camera)
    camera.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    rotation = camera.rotation_euler.to_matrix()
    target = (rotation @ Vector((1, 0, 0))) * ((width / 2 - anchor_x) / pixels_per_unit)
    target += (rotation @ Vector((0, 1, 0))) * ((anchor_y - height / 2) / pixels_per_unit)
    camera.location = target + direction * 20
    camera_data.type = "ORTHO"
    camera_data.sensor_fit = "HORIZONTAL"
    camera_data.ortho_scale = width / pixels_per_unit
    camera_data.clip_start = 0.01
    camera_data.clip_end = 100
    scene.camera = camera
    light_data = bpy.data.lights.new("Pipeline_Sun", "SUN")
    light_data.energy = settings["sun_energy"]
    light_data.angle = math.radians(settings["sun_angle_degrees"])
    light = bpy.data.objects.new("Pipeline_Sun", light_data)
    scene.collection.objects.link(light)
    light.rotation_euler = [math.radians(v) for v in settings["sun_rotation_degrees"]]
    world = bpy.data.worlds.new("Pipeline_World")
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = settings["world_strength"]
    scene.world = world
    scene.render.engine = settings["engine"]
    scene.cycles.device = "CPU"
    scene.cycles.samples = settings["samples"]
    scene.cycles.seed = settings["seed"]
    scene.cycles.use_animated_seed = False
    scene.cycles.use_denoising = False
    scene.cycles.use_adaptive_sampling = False
    scene.cycles.pixel_filter_type = settings["pixel_filter"]
    scene.cycles.filter_width = settings["filter_width"]
    for view_layer in scene.view_layers:
        view_layer.samples = 0
    scene.render.use_motion_blur = False
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x = 1
    scene.render.pixel_aspect_y = 1
    scene.render.film_transparent = True
    scene.cycles.film_transparent_glass = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 100
    scene.render.use_border = False
    scene.render.use_compositing = False
    scene.render.use_sequencer = False
    scene.render.use_stamp = False
    scene.render.use_file_extension = True
    scene.render.dither_intensity = 0
    scene.view_settings.view_transform = settings["view_transform"]
    scene.view_settings.look = settings["look"]
    scene.view_settings.exposure = settings["exposure"]
    scene.view_settings.gamma = settings["gamma"]
    scene.view_settings.use_curve_mapping = False
    scene.frame_set(1)
    bpy.context.view_layer.update()
    # Blender X maps to logical Y; Blender Y maps to logical X (Z stays up).
    expected = [(anchor_x, anchor_y), (anchor_x - 32 * density, anchor_y + 16 * density),
                (anchor_x + 32 * density, anchor_y + 16 * density),
                (anchor_x, anchor_y - 16 * math.sqrt(6) * density)]
    for point, target_pixel in zip([(0, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1)], expected):
        ndc = world_to_camera_view(scene, camera, Vector(point))
        actual = Vector((ndc.x * width, (1 - ndc.y) * height))
        if (actual - Vector(target_pixel)).length > 0.001 * density:
            raise ValueError(f"Camera projection mismatch: {point} -> {tuple(actual)}")
    return scene


def validate_dependencies():
    for library in bpy.data.libraries:
        if library:
            raise ValueError("Linked .blend libraries are not supported. Make the asset local first.")
    for image in bpy.data.images:
        if image.source not in {"FILE", "GENERATED", "VIEWER"}:
            raise ValueError(f"Unsupported image source '{image.source}' for '{image.name}'; use a packed static image.")
        if image.source == "FILE" and not image.packed_file:
            raise ValueError(f"Pack image '{image.name}' into the .blend before export.")
    if bpy.utils.blend_paths(absolute=True, packed=False):
        raise ValueError("External asset dependencies remain. Pack resources and use local static geometry before export.")


def generate(asset, generator, settings, profile="default"):
    path = source_path(asset)
    if path.exists():
        raise ValueError(f"Source already exists: {path}. Render it or choose a new ASSET; generation never overwrites.")
    if not generator.is_file():
        raise ValueError(f"Generator not found: {generator}")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene["asset_profile"] = profile
    sys.path.insert(0, str(generator.parent))
    runpy.run_path(str(generator))["build"]()
    configure(export_settings(settings))
    validate_dependencies()
    SOURCES.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(path), check_existing=False)
    print(f"Created source: {path.relative_to(ROOT)}")


def render(asset, settings):
    source = source_path(asset)
    if not source.is_file():
        raise ValueError(f"Source not found: {source}. Generate it or save a .blend there first.")
    before = digest(source)
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    validate_dependencies()
    settings = export_settings(settings)
    scene = configure(settings)
    if scene.get("asset_model"):
        sys.path.insert(0, str(Path(__file__).parent))
        from model_export import validate_rig

        validate_rig(scene)
    density = settings["render_density"]
    canvas = [value * density for value in settings["canvas"]]
    anchor = [value * density for value in settings["anchor"]]
    IMAGES.mkdir(parents=True, exist_ok=True)
    SCENES.mkdir(parents=True, exist_ok=True)
    if scene.get("asset_terrain"):
        sys.path.insert(0, str(Path(__file__).parent))
        from terrain_export import render_terrain

        render_terrain(sys.modules[__name__], asset, scene, settings, source, before)
        return
    export = {}
    if scene.get("asset_animation"):
        sys.path.insert(0, str(Path(__file__).parent))
        from animation_export import render_animation

        export = render_animation(sys.modules[__name__], asset, scene, settings, source, before)
    else:
        export = render_still(asset, scene, canvas, source, before, settings)
    if scene.get("asset_model"):
        sys.path.insert(0, str(Path(__file__).parent))
        from model_export import export_model

        export.update(export_model(sys.modules[__name__], asset, scene, settings, source, before))
    canvas, anchor = export.get("canvas", canvas), export.get("anchor", anchor)
    if digest(source) != before:
        raise ValueError("Source changed during rendering. Export cancelled.")
    anchor_x, anchor_y = anchor
    (SCENES / f"{asset}.tscn").write_text(
        '[gd_scene format=3]\n\n'
        f'[ext_resource type="Texture2D" path="res://assets/generated/{asset}.png" id="1"]\n\n'
        f'[node name="{asset}" type="Sprite2D"]\n'
        f'texture_filter = {4 if density > 1 else 1}\n'
        f'scale = Vector2({1 / density:g}, {1 / density:g})\n'
        'texture = ExtResource("1")\ncentered = false\n'
        f'offset = Vector2({-anchor_x}, {-anchor_y})\n'
    )
    metadata = {
        "source": source.relative_to(ROOT).as_posix(), "source_sha256": before,
        "settings_sha256": digest(SETTINGS), "blender_version": bpy.app.version_string,
        "python_version": sys.version.split()[0], "canvas": canvas,
        "anchor": anchor, "trimmed": False,
        "logical_canvas": settings["canvas"], "logical_anchor": settings["anchor"],
        "render_density": density, "profile": bpy.context.scene.get("asset_profile", "default"),
        "world_points_per_unit": 32,
        "blender_xy_basis_pixels": [[-32 * density, 16 * density], [32 * density, 16 * density]],
        "logical_xy_from_blender": ["32 * Y", "32 * X"],
        "dependencies": ["Blender (bundled bpy and Python standard library)"],
    }
    metadata.update(export)
    (IMAGES / f"{asset}.json").write_text(json.dumps(metadata, indent=2) + "\n")
    write_import_settings(asset, density)
    print(f"Exported {asset}: {canvas[0]}x{canvas[1]}, anchor {anchor}, density {density}; source SHA256 unchanged")


def render_still(asset, scene, canvas, source, before, settings=None):
    with tempfile.TemporaryDirectory(prefix="nathaniel-render-") as temporary:
        png = Path(temporary) / f"{asset}.png"
        scene.render.filepath = str(png)
        bpy.ops.render.render(write_still=True)
        image = bpy.data.images.load(str(png), check_existing=False)
        width, height = image.size
        pixels = array("f", [0]) * (width * height * 4)
        image.pixels.foreach_get(pixels)
        bpy.data.images.remove(image)
        alpha = pixels[3::4]
        if [width, height] != canvas or not any(a > 0 for a in alpha):
            raise ValueError("Render is empty or has incorrect dimensions.")
        border = alpha[:width] + alpha[-width:] + alpha[::width] + alpha[width - 1::width]
        if any(a > 0 for a in border):
            raise ValueError("Artwork reaches the canvas edge. Enlarge canvas and anchor in settings; do not fit the model.")
        if digest(source) != before:
            raise ValueError("Source changed during rendering. Export cancelled.")
        destination = IMAGES / f"{asset}.png"
        if settings and settings.get("trim", False):
            sys.path.insert(0, str(Path(__file__).parent))
            from animation_export import pixels_and_bounds, save_pixels

            pixels, bounds = pixels_and_bounds(png)
            density = settings["render_density"]
            padding = 2 * density
            left, bottom = max(0, bounds[0] - padding), max(0, bounds[1] - padding)
            right, top = min(width, bounds[2] + padding), min(height, bounds[3] + padding)
            cropped = array("f")
            for row in range(bottom, top):
                start = (row * width + left) * 4
                cropped.extend(pixels[start:start + (right - left) * 4])
            save_pixels(destination, cropped, right - left, top - bottom, sys.modules[__name__])
            crop_top = height - top
            anchor = [settings["anchor"][0] * density - left,
                      settings["anchor"][1] * density - crop_top]
            return {"canvas": [right - left, top - bottom], "anchor": anchor,
                    "trimmed": True, "crop_origin": [left, crop_top],
                    "uncropped_canvas": canvas,
                    "uncropped_anchor": [v * density for v in settings["anchor"]],
                    "logical_canvas": [(right - left) / density, (top - bottom) / density],
                    "logical_anchor": [v / density for v in anchor]}
        destination.write_bytes(png_without_metadata(png.read_bytes()))
        return {}


def write_import_settings(asset, density, *, premultiplied=False):
    """Preserve Godot's import identity while enforcing the sprite export contract."""
    path = IMAGES / f"{asset}.png.import"
    if path.exists():
        content = path.read_text()
    else:
        content = ('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n'
                   f'[deps]\n\nsource_file="res://assets/generated/{asset}.png"\n\n[params]\n')
    if "[params]" not in content:
        raise ValueError(f"Missing texture import parameters in {path}")
    for key, value in {
        "compress/mode": "0", "mipmaps/generate": "true" if density > 1 else "false",
        "process/fix_alpha_border": "true",
        "process/premult_alpha": "true" if premultiplied else "false",
        "process/size_limit": "0",
    }.items():
        pattern = rf"(?m)^{re.escape(key)}=.*$"
        if re.search(pattern, content):
            content = re.sub(pattern, f"{key}={value}", content)
        else:
            content = content.replace("[params]", f"[params]\n{key}={value}")
    path.write_text(content)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["doctor", "generate", "render", "regenerate", "verify", "rig-gun", "rig-character"])
    parser.add_argument("asset", nargs="?", default="placeholder_prop")
    parser.add_argument("--generator", type=Path, default=ROOT / "tools/blender/generate_placeholder.py")
    parser.add_argument("--profile", default="default", help="Shared profile saved in a new source; rendering uses its saved profile")
    parser.add_argument("--prefix", default="", help="Limit regenerate to source names with this prefix")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    settings = json.loads(SETTINGS.read_text())
    expected = tuple(settings["blender_version"])
    if bpy.app.version != expected:
        raise ValueError(f"Blender {'.'.join(map(str, expected))} required; found {bpy.app.version_string}. Set BLENDER to the pinned executable.")
    if args.command == "doctor":
        print(f"Blender {bpy.app.version_string}; Python {sys.version.split()[0]}; {bpy.app.binary_path}")
    elif args.command == "verify":
        sys.path.insert(0, str(Path(__file__).parent))
        from verify import verify

        verify(sys.modules[__name__], settings)
    elif args.command == "generate":
        generate(args.asset, args.generator.resolve(), settings, args.profile)
    elif args.command == "render":
        render(args.asset, settings)
    elif args.command == "rig-gun":
        sys.path.insert(0, str(Path(__file__).parent))
        from rig_gun_tower import migrate

        migrate(sys.modules[__name__], args.asset)
    elif args.command == "rig-character":
        sys.path.insert(0, str(Path(__file__).parent))
        from rig_nathaniel import migrate

        migrate(sys.modules[__name__], args.asset, settings)
    else:
        if args.prefix and not re.fullmatch(r"[a-z][a-z0-9_]*", args.prefix):
            raise ValueError("Source prefix must use lowercase letters, digits and underscores.")
        sources = sorted(SOURCES.glob(f"{args.prefix}*.blend"))
        if not sources:
            raise ValueError(f"No .blend sources in {SOURCES}")
        for source in sources:
            render(source.stem, settings)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        raise RuntimeError(f"Asset pipeline: {error}") from error
