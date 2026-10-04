"""Check weapon source migration and reproducible exports through the real exporter."""

import json
from pathlib import Path
import subprocess

import bpy

from iron_ink_towers import build_tower
from model_export import BLENDER_TO_GODOT, glb_document
from rig_gun_tower import migrate, rig_gun_tower


def verify_model(pipeline, settings):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_tower("gun")
    breech = bpy.data.objects["Gun breech armour"]
    breech["artist_note"] = "Retain hand edits through rigging and export"
    breech.data.vertices[0].co.z += 0.012
    original = {obj.name: (obj.matrix_world.copy(), [v.co.copy() for v in obj.data.vertices])
                for obj in bpy.context.scene.objects if obj.type == "MESH"}
    assert rig_gun_tower()
    for name, (matrix, vertices) in original.items():
        obj = bpy.data.objects[name]
        assert max(abs(obj.matrix_world[row][column] - matrix[row][column])
                   for row in range(4) for column in range(4)) < 0.000001, name
        assert all((vertex.co - expected).length < 0.000001
                   for vertex, expected in zip(obj.data.vertices, vertices)), name
    assert not rig_gun_tower(), "Repeated rigging must be a no-op"
    assert breech["artist_note"] == "Retain hand edits through rigging and export"
    muzzle = bpy.data.objects["Muzzle"].matrix_world.translation
    assert abs(muzzle.x - 0.96) < 0.00001 and abs(muzzle.z - 1.09) < 0.00001
    assert abs((BLENDER_TO_GODOT @ muzzle).y - 1.09) < 0.00001
    pipeline.configure(settings)
    source = pipeline.source_path("model_probe")
    bpy.ops.wm.save_as_mainfile(filepath=str(source), check_existing=False)
    source_hash = pipeline.digest(source)
    migrate(pipeline, "model_probe")
    assert pipeline.digest(source) == source_hash, "Idempotent migration saved the source again"
    pipeline.render("model_probe", settings)
    glb_path = pipeline.IMAGES / "model_probe.glb"
    original_glb = glb_path.read_bytes()
    document = glb_document(original_glb)
    nodes = {node["name"]: node for node in document["nodes"]}
    assert all(name in nodes for name in ("AimPivot", "Recoil", "Muzzle"))
    assert not any(name.startswith("Pipeline_") for name in nodes)
    assert document["materials"] and len(document["meshes"]) == len(original)
    assert not any("uri" in buffer for buffer in document["buffers"])
    # Edit source mesh/material directly, as an artist does, and render twice.
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    breech = bpy.data.objects["Gun breech armour"]
    breech.data.vertices[0].co.z += 0.035
    material = breech.active_material
    material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.12, 0.22, 0.3, 1)
    bpy.data.objects["Hollow octagonal cannon"].hide_viewport = True
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    edited_hash = pipeline.digest(source)
    pipeline.render("model_probe", settings)
    edited_glb = glb_path.read_bytes()
    assert edited_glb != original_glb, "Saved geometry/material edits did not reach GLB"
    edited_png = (pipeline.IMAGES / "model_probe.png").read_bytes()
    pipeline.render("model_probe", settings)
    assert glb_path.read_bytes() == edited_glb, "Repeat model export changed GLB bytes"
    assert (pipeline.IMAGES / "model_probe.png").read_bytes() == edited_png
    assert pipeline.digest(source) == edited_hash, "Model export changed the saved source"
    # Separate processes used to differ by one ULP in evaluated bevel vertices.
    # Use Blender's own interpreter again to catch that production export failure.
    expression = (
        "import sys,json; from pathlib import Path; "
        f"sys.path.insert(0, {str(Path(__file__).parent)!r}); import pipeline; "
        f"pipeline.ROOT=Path({str(pipeline.ROOT)!r}); "
        f"pipeline.SOURCES=Path({str(pipeline.SOURCES)!r}); "
        f"pipeline.IMAGES=Path({str(pipeline.IMAGES)!r}); "
        f"pipeline.SCENES=Path({str(pipeline.SCENES)!r}); "
        f"pipeline.render('model_probe', json.loads({json.dumps(settings)!r}))"
    )
    result = subprocess.run(
        [bpy.app.binary_path, "--background", "--factory-startup", "--disable-autoexec",
         "--python-exit-code", "1", "--python-expr", expression],
        capture_output=True, text=True, check=False,
    )
    if result.returncode:
        raise AssertionError("Separate Blender process failed: " + (result.stdout + result.stderr)[-2000:])
    assert glb_path.read_bytes() == edited_glb, "Independent Blender processes changed GLB bytes"
    assert (pipeline.IMAGES / "model_probe.png").read_bytes() == edited_png
    assert pipeline.digest(source) == edited_hash
    metadata = json.loads((pipeline.IMAGES / "model_probe.json").read_text())
    assert metadata["source_sha256"] == edited_hash
    assert metadata["model"]["sha256"] == pipeline.digest(glb_path)
    scene_text = (pipeline.ROOT / "scenes/actors/generated/model_probe_model.tscn").read_text()
    assert 'metadata/logical_ground_anchor = Vector2(64, 96)' in scene_text
    assert 'ambient_light_energy = 0.35' in scene_text
    # Bad control names must fail before publishing a replacement model or PNG.
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    bpy.data.objects["Muzzle"].name = "RenamedMuzzle"
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    try:
        pipeline.render("model_probe", settings)
    except ValueError as error:
        assert "Muzzle" in str(error)
    else:
        raise AssertionError("Model with a missing muzzle control was published")
    assert glb_path.read_bytes() == edited_glb
    assert (pipeline.IMAGES / "model_probe.png").read_bytes() == edited_png
    print("PASS: model rig preserves source geometry; manual edits export; GLB/PNG identical across processes; invalid rig refused")
