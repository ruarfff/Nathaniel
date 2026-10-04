"""Exercise source safety and repeat exports using temporary, editable .blend files."""

import json
from pathlib import Path
import tempfile

import bpy


def verify(pipeline, settings):
    with tempfile.TemporaryDirectory(prefix="nathaniel-art-check-") as temporary:
        pipeline.ROOT = Path(temporary)
        pipeline.SOURCES = pipeline.ROOT / "sources"
        pipeline.IMAGES = pipeline.ROOT / "images"
        pipeline.SCENES = pipeline.ROOT / "scenes"
        generator = Path(__file__).with_name("generate_placeholder.py")
        pipeline.generate("probe", generator, settings)
        source = pipeline.source_path("probe")
        original_source = pipeline.digest(source)
        try:
            pipeline.generate("probe", generator, settings)
        except ValueError as error:
            assert "already exists" in str(error)
        else:
            raise AssertionError("Generation overwrote an existing source")
        assert pipeline.digest(source) == original_source
        pipeline.render("probe", settings)
        original_png = (pipeline.IMAGES / "probe.png").read_bytes()
        assert b"tEXt" not in original_png and str(source).encode() not in original_png
        # Metadata varies even with identical pixels. It must not enter runtime PNGs.
        fake_date_chunk = (4).to_bytes(4, "big") + b"tEXt" + b"date" + bytes(4)
        assert pipeline.png_without_metadata(original_png[:8] + fake_date_chunk + original_png[8:]) == original_png

        # Save the same edits an artist can make in Blender. Rendering must retain them.
        obj = bpy.data.objects["PlaceholderProp"]
        obj.name = "ArtistEditedProp"
        obj["artist_note"] = "Keep this edit"
        for vertex in obj.data.vertices:
            if vertex.co.z > 0:
                vertex.co.z += 0.25
        shader = obj.active_material.node_tree.nodes["Principled BSDF"]
        shader.inputs["Base Color"].default_value = (0.12, 0.4, 0.65, 1)
        bpy.ops.wm.save_as_mainfile(filepath=str(source))
        edited_source = pipeline.digest(source)
        assert edited_source != original_source
        pipeline.render("probe", settings)
        edited_png = (pipeline.IMAGES / "probe.png").read_bytes()
        assert edited_png != original_png, "Saved geometry/material edits did not reach the PNG"
        pipeline.render("probe", settings)
        assert pipeline.digest(source) == edited_source, "Re-export changed the saved .blend"
        assert (pipeline.IMAGES / "probe.png").read_bytes() == edited_png, "Repeat export changed pixels"
        bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
        assert bpy.data.objects["ArtistEditedProp"]["artist_note"] == "Keep this edit"
        metadata = json.loads((pipeline.IMAGES / "probe.json").read_text())
        assert metadata["source_sha256"] == edited_source
        assert metadata["anchor"] == settings["anchor"]

        bpy.context.scene.render.use_motion_blur = True
        bpy.context.scene.cycles.filter_width = 3
        bpy.context.view_layer.samples = 128
        pipeline.configure(settings)
        assert not bpy.context.scene.render.use_motion_blur
        assert bpy.context.scene.cycles.filter_width == settings["filter_width"]
        assert bpy.context.view_layer.samples == 0

        image = bpy.data.images.new("Unsupported sequence", width=1, height=1)
        image.source = "SEQUENCE"
        try:
            pipeline.validate_dependencies()
        except ValueError as error:
            assert "Unsupported image source" in str(error)
        else:
            raise AssertionError("Sequence texture escaped dependency checks")
        bpy.data.images.remove(image)

        # A larger canvas changes framing, never the pixel scale of the model.
        larger = dict(settings, canvas=[256, 192], anchor=[128, 144])
        pipeline.configure(larger)
        # configure checks the real Blender camera's origin and all three basis vectors.
        pipeline.generate("hd_probe", generator, settings, "iron_ink")
        hd_source = pipeline.source_path("hd_probe")
        hd_hash = pipeline.digest(hd_source)
        pipeline.render("hd_probe", settings)
        hd_metadata = json.loads((pipeline.IMAGES / "hd_probe.json").read_text())
        assert hd_metadata["canvas"] == [1024, 1024]
        assert hd_metadata["anchor"] == [512, 768]
        assert hd_metadata["logical_canvas"] == settings["canvas"]
        assert hd_metadata["render_density"] == 8
        assert pipeline.digest(hd_source) == hd_hash
        hd_png = (pipeline.IMAGES / "hd_probe.png").read_bytes()
        pipeline.render("hd_probe", settings)
        assert (pipeline.IMAGES / "hd_probe.png").read_bytes() == hd_png, "Repeat HD export changed PNG bytes"
        assert pipeline.digest(hd_source) == hd_hash
        scene_text = (pipeline.SCENES / "hd_probe.tscn").read_text()
        assert "scale = Vector2(0.125, 0.125)" in scene_text
        import_text = (pipeline.IMAGES / "hd_probe.png.import").read_text()
        assert "mipmaps/generate=true" in import_text
        print("PASS: projection on two canvases and HD density; overwrite refusal; saved edits retained; identical repeat PNG")
        # Environment exports crop transparent borders without moving ground contact.
        bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
        bpy.context.scene["asset_profile"] = "trim_probe"
        bpy.ops.wm.save_as_mainfile(filepath=str(source))
        trimmed_settings = dict(settings, profiles=dict(settings["profiles"], trim_probe={
            "canvas": [160, 144], "anchor": [80, 112], "render_density": 2, "trim": True}))
        trim_hash = pipeline.digest(source)
        pipeline.render("probe", trimmed_settings)
        trimmed = json.loads((pipeline.IMAGES / "probe.json").read_text())
        assert trimmed["trimmed"]
        assert trimmed["canvas"][0] < 320 and trimmed["canvas"][1] < 288
        assert trimmed["anchor"] == [160 - trimmed["crop_origin"][0], 224 - trimmed["crop_origin"][1]]
        assert trimmed["uncropped_canvas"] == [320, 288]
        trimmed_png = (pipeline.IMAGES / "probe.png").read_bytes()
        pipeline.render("probe", trimmed_settings)
        assert pipeline.digest(source) == trim_hash
        assert (pipeline.IMAGES / "probe.png").read_bytes() == trimmed_png
        print("PASS: static transparent crop retains anchor, saved edits and identical repeat PNG")
        bpy.data.objects["ArtistEditedProp"].location.y += 1.8
        off_axis = pipeline.source_path("offset_probe")
        bpy.ops.wm.save_as_mainfile(filepath=str(off_axis))
        offset_settings = dict(trimmed_settings, profiles=dict(trimmed_settings["profiles"], trim_probe={
            "canvas": [256, 192], "anchor": [128, 144], "render_density": 2, "trim": True}))
        pipeline.render("offset_probe", offset_settings)
        offset_record = json.loads((pipeline.IMAGES / "offset_probe.json").read_text())
        assert offset_record["anchor"][0] < 0
        offset_scene = (pipeline.SCENES / "offset_probe.tscn").read_text()
        assert "--" not in offset_scene
        assert f'offset = Vector2({-offset_record["anchor"][0]}, {-offset_record["anchor"][1]})' in offset_scene
        bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
        bpy.context.scene["asset_profile"] = "default"
        bpy.ops.wm.save_as_mainfile(filepath=str(source))
        from verify_animation import verify_animation

        verify_animation(pipeline, settings, source)
        from verify_terrain import verify_terrain

        verify_terrain(pipeline, settings)
        from verify_model import verify_model

        verify_model(pipeline, settings)
        from verify_character_model import verify_character_model

        verify_character_model(pipeline, settings)
