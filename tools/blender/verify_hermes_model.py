"""Check shoulder migration, authored motion and source-safe live model exports."""

import json
import math
from pathlib import Path
import tempfile

import bpy
from mathutils import Vector

from iron_ink_characters import build_character
from model_animation import animation_spec
from model_export import export_model, glb_document, validate_rig
from rig_hermes import CONTROLS, migrate, rig_character


def _check_head_clearance(scene):
    head = scene.objects["Sensor head"]
    inverse = head.matrix_world.inverted()
    corners = [inverse @ obj.matrix_world @ Vector(corner)
               for obj in head.children_recursive if obj.type == "MESH" for corner in obj.bound_box]
    lower = [min(point[axis] for point in corners) - 0.015 for axis in range(3)]
    upper = [max(point[axis] for point in corners) + 0.015 for axis in range(3)]

    def intersects(start, end):
        near, far = 0.0, 1.0
        for axis in range(3):
            delta = end[axis] - start[axis]
            if abs(delta) < 0.000001:
                if start[axis] < lower[axis] or start[axis] > upper[axis]:
                    return False
                continue
            first, last = sorted(((lower[axis] - start[axis]) / delta, (upper[axis] - start[axis]) / delta))
            near, far = max(near, first), min(far, last)
            if near > far:
                return False
        return True

    root = scene.objects["AssetFacing"]
    for facing in range(8):
        root.rotation_euler.z = facing * math.pi / 4
        for frame in (1, 10, 12, 14, 16, 18):
            scene.frame_set(frame)
            bpy.context.view_layer.update()
            origin = scene.objects["PitchPivot"].matrix_world.translation
            inverse = head.matrix_world.inverted()
            for radius in (60 / 32, 90 / 32, 180 / 32):
                for angle in range(72):
                    target = Vector((radius * math.cos(angle * math.tau / 72),
                                     radius * math.sin(angle * math.tau / 72), 0.75))
                    muzzle = origin + (target - origin).normalized() * scene.objects["Muzzle"].location.x
                    assert not intersects(inverse @ muzzle, inverse @ target), (facing, frame, radius, angle)
    root.rotation_euler.z = 0
    scene.frame_set(1)
    bpy.context.view_layer.update()


def verify_hermes_model(pipeline, settings):
    original_paths = pipeline.ROOT, pipeline.SOURCES, pipeline.IMAGES
    with tempfile.TemporaryDirectory(prefix="nathaniel-hermes-model-") as temporary:
        pipeline.ROOT = Path(temporary)
        pipeline.SOURCES = pipeline.ROOT / "sources"
        pipeline.IMAGES = pipeline.ROOT / "images"
        pipeline.SOURCES.mkdir()
        try:
            _verify(pipeline, settings)
        finally:
            pipeline.ROOT, pipeline.SOURCES, pipeline.IMAGES = original_paths


def _verify(pipeline, settings):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_character("hermes")
    scene = bpy.context.scene
    chest = scene.objects["Intake torso armour"]
    chest.data.vertices[0].co.x += 0.025
    chest["artist_note"] = "Retain saved shoulder-era body edits"
    vertex = tuple(chest.data.vertices[0].co)
    actions = set(bpy.data.actions)
    poses = {}
    for frame in (1, 10, 12, 14, 16, 18, 30):
        scene.frame_set(frame)
        poses[frame] = {obj.name: obj.matrix_world.copy() for obj in scene.objects if obj.type == "MESH"}
    assert rig_character()
    assert actions == set(bpy.data.actions), "Migration replaced authored actions"
    assert tuple(chest.data.vertices[0].co) == vertex
    for frame, pose in poses.items():
        scene.frame_set(frame)
        for name, before in pose.items():
            after = scene.objects[name].matrix_world
            assert max(abs(after[row][column] - before[row][column])
                       for row in range(4) for column in range(4)) < 0.000001, (frame, name)
    scene.frame_set(1)
    assert not rig_character(), "Migration must preserve an existing shoulder rig"
    assert chest["artist_note"] == "Retain saved shoulder-era body edits"
    assert scene.objects["PitchPivot"].location.x == 0 and scene.objects["PitchPivot"].location.y == 0
    assert tuple(scene.objects["Muzzle"].location)[1:] == (0, 0)
    _check_head_clearance(scene)
    spec = json.loads(scene["model_clips"])
    spec["controls"].append("PitchPivot")
    scene["model_clips"] = json.dumps(spec)
    try:
        animation_spec(scene)
    except ValueError as error:
        assert "aim controls" in str(error)
    else:
        raise AssertionError("Locomotion animation took ownership of mounted aim")
    spec["controls"].remove("PitchPivot")
    scene["model_clips"] = json.dumps(spec)
    muzzle = scene.objects["Muzzle"]
    parent = muzzle.parent
    muzzle.parent = scene.objects["AimPivot"]
    try:
        validate_rig(scene)
    except ValueError as error:
        assert "hierarchy" in str(error)
    else:
        raise AssertionError("Broken mounted muzzle hierarchy was accepted")
    muzzle.parent = parent
    for name, axis, message in (("Muzzle", "y", "pitch axis"), ("Muzzle", "z", "pitch axis"),
                                ("PitchPivot", "x", "yaw axis"), ("PitchPivot", "y", "yaw axis")):
        control = scene.objects[name]
        setattr(control.location, axis, 0.01)
        try:
            validate_rig(scene)
        except ValueError as error:
            assert message in str(error)
        else:
            raise AssertionError(f"Invalid {name} {axis} offset was accepted")
        setattr(control.location, axis, 0)
    effective = pipeline.export_settings(settings)
    pipeline.configure(effective)
    source = pipeline.source_path("hermes_probe")
    bpy.ops.wm.save_as_mainfile(filepath=str(source), check_existing=False)
    source_hash = pipeline.digest(source)
    migrate(pipeline, "hermes_probe")
    assert pipeline.digest(source) == source_hash, "Repeated migration changed the saved source"
    scene = bpy.context.scene
    export_model(pipeline, "hermes_probe", scene, effective, source, source_hash)
    output = pipeline.IMAGES / "hermes_probe.glb"
    first = output.read_bytes()
    document = glb_document(first)
    assert {clip["name"] for clip in document["animations"]} == {"idle", "walk"}
    animated = {document["nodes"][channel["target"]["node"]]["name"]
                for clip in document["animations"] for channel in clip["channels"]}
    assert animated == set(CONTROLS), animated
    assert 'metadata/model_role = "mounted_character"' in (
        pipeline.ROOT / "scenes/actors/generated/hermes_probe_model.tscn").read_text()
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    export_model(pipeline, "hermes_probe", bpy.context.scene, effective, source, source_hash)
    assert output.read_bytes() == first, "Repeat export changed live model bytes"
    assert pipeline.digest(source) == source_hash, "Export changed the saved source"
    print("PASS: shoulder migration retains edited body and all authored poses; 10368 beam/head clearance cases; repeated migration is inert; idle/walk export; mounted aim stays independent; repeat model export retains source")
