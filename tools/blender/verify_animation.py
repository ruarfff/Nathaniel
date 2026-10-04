"""Check directional atlas export using small saved poses and real Blender renders."""

from array import array
import json

import bpy


def verify_animation(pipeline, settings, source):
    from animation_export import pixels_and_bounds, save_pixels

    # Packing must not run display-encoded PNG values through color management twice.
    pixels = array("f", [0]) * (6 * 3 * 4)
    for x, alpha in enumerate([255, 128, 26, 0], start=1):
        pixels[(6 + x) * 4:(6 + x + 1) * 4] = array("f", [89 / 255, 149 / 255, 218 / 255, alpha / 255])
    color_probe = pipeline.IMAGES / "color_probe.png"
    save_pixels(color_probe, pixels, 6, 3, pipeline)
    actual, _ = pixels_and_bounds(color_probe)
    assert [round(v * 255) for v in actual] == [round(v * 255) for v in pixels], "Atlas packing changed RGBA"
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    scene = bpy.context.scene
    root = bpy.data.objects.new("AssetFacing", None)
    scene.collection.objects.link(root)
    prop = bpy.data.objects["ArtistEditedProp"]
    prop.parent = root
    base_height = prop.location.z
    prop.keyframe_insert(data_path="location", frame=1)
    prop.location.z = base_height + 0.15
    prop.keyframe_insert(data_path="location", frame=2)
    scene["asset_animation"] = json.dumps({"directions": 8, "clips": [
        {"name": "idle", "frames": [1], "fps": 1, "loop": True},
        {"name": "walk", "frames": [1, 2], "fps": 8, "loop": True},
        {"name": "fire", "frames": [2, 1], "fps": 10, "loop": False},
    ]})
    from animation_export import animation_spec

    valid_spec = scene["asset_animation"]
    invalid = json.loads(valid_spec)
    invalid["clips"][2]["loop"] = True
    scene["asset_animation"] = json.dumps(invalid)
    try:
        animation_spec(scene)
    except ValueError as error:
        assert "fire must finish" in str(error)
    else:
        raise AssertionError("Looping fire clip would prevent native playback recovery")
    scene["asset_animation"] = valid_spec
    prop.parent = None
    try:
        animation_spec(scene)
    except ValueError as error:
        assert "under AssetFacing" in str(error)
    else:
        raise AssertionError("Unparented geometry would stay fixed while the actor turns")
    prop.parent = root
    scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    saved_hash = pipeline.digest(source)
    pipeline.render("probe", settings)
    record = json.loads((pipeline.IMAGES / "probe.json").read_text())
    assert len(record["frames"]) == 40
    assert record["trimmed"]
    assert record["anchor"] == [a - b for a, b in zip(settings["anchor"], record["crop_origin"])]
    assert all([frame["region"][2] + frame["margin"][2], frame["region"][3] + frame["margin"][3]]
               == record["canvas"] for frame in record["frames"])
    assert record["unique_frames"] < len(record["frames"]), "Identical poses were packed repeatedly"
    assert record["canvas"][0] < 128 and record["canvas"][1] < 128
    resources = (pipeline.IMAGES / "probe_frames.tres").read_text()
    assert '"name": &"walk_7"' in resources and "filter_clip = true" in resources
    assert "metadata/ground_anchor" in resources
    # Compare a shifted pose against its original render, including the atlas's
    # top-origin region and restored margins. Size checks alone miss flipped Y.
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    scene = pipeline.configure(settings)
    scene.frame_set(2)
    pipeline.render_still("expected_pose", scene, settings["canvas"], source, saved_hash)
    original_pixels, _ = pixels_and_bounds(pipeline.IMAGES / "expected_pose.png")
    shifted = next(frame for frame in record["frames"] if frame["animation"] == "walk_0" and frame["source_frame"] == 2)
    page = record["atlas_pages"][shifted["page"]]
    atlas_pixels, _ = pixels_and_bounds(pipeline.IMAGES / page["file"])
    x, y, width, height = shifted["region"]
    margin_x, margin_y, _, _ = shifted["margin"]
    crop_x, crop_y = record["crop_origin"]
    for row in range(height):
        atlas_start = ((page["canvas"][1] - y - height + row) * page["canvas"][0] + x) * 4
        original_start = ((128 - crop_y - margin_y - height + row) * 128 + crop_x + margin_x) * 4
        actual_row = atlas_pixels[atlas_start:atlas_start + width * 4]
        expected_row = original_pixels[original_start:original_start + width * 4]
        assert [round(v * 255) for v in actual_row] == [round(v * 255) for v in expected_row], "Atlas margin moved pose pixels"
    files = [pipeline.IMAGES / page["file"] for page in record["atlas_pages"]]
    files += [pipeline.IMAGES / "probe.png", pipeline.IMAGES / "probe_frames.tres"]
    first = [pipeline.digest(path) for path in files]
    pipeline.render("probe", settings)
    assert first == [pipeline.digest(path) for path in files], "Repeat animation export changed atlas bytes"
    assert pipeline.digest(source) == saved_hash, "Animation render overwrote saved keyframes"
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    assert bpy.data.objects["ArtistEditedProp"]["artist_note"] == "Keep this edit"
    assert bpy.data.objects["AssetFacing"].rotation_euler.z == 0
    print("PASS: saved keyframes; eight directions; common crop/anchor; deterministic atlases; source edits retained")
