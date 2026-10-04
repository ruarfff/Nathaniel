"""Add live actor controls and extract editable rifles from saved Nathaniel art."""

import json
import math
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


LEG_NAMES = ("LeftHip", "LeftKnee", "LeftAnkle", "RightHip", "RightKnee", "RightAnkle")


def _empty(name, collection, parent=None, location=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.parent = parent
    obj.location = location
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = 0.08
    bpy.context.view_layer.update()
    return obj


def _reparent(obj, parent):
    old_parent = obj.parent.matrix_world.copy() if obj.parent else Matrix.Identity(4)
    inverse = obj.matrix_parent_inverse.copy()
    basis = obj.matrix_basis.copy()
    obj.parent = parent
    obj.matrix_parent_inverse = parent.matrix_world.inverted() @ old_parent @ inverse
    obj.matrix_basis = basis
    bpy.context.view_layer.update()


def rig_character():
    scene = bpy.context.scene
    if scene.get("asset_model") == "character":
        from model_export import validate_rig

        validate_rig(scene)
        return False
    required = ("AssetFacing", "BodyMotion", "Spine", "Rifle grip", "Left shoulder", "Right shoulder")
    if any(scene.objects.get(name) is None for name in required):
        raise ValueError("Expected Nathaniel's saved rigid-part character source; no source changes made.")
    if any(scene.objects.get(name) for name in ("AimPivot", "LocomotionPivot", "WeaponMount", "WeaponHands")):
        raise ValueError("Partial character rig found; restore or complete it before migration.")
    scene.frame_set(1)
    root, body, spine = (scene.objects[name] for name in required[:3])
    collection = root.users_collection[0]
    lower = _empty("LocomotionPivot", collection, root)
    _reparent(body, lower)
    aim = _empty("AimPivot", collection, root, tuple(spine.matrix_world.translation))
    # Keep saved actions for the fallback sprite. Live export only samples legs.
    _reparent(spine, aim)
    mount = _empty("WeaponMount", collection, spine)
    mount.matrix_world = Matrix.Translation(scene.objects["Rifle grip"].matrix_world.translation)
    mount.rotation_euler.z = math.pi / 2
    bpy.context.view_layer.update()
    hands = _empty("WeaponHands", collection, mount)
    for name in ("Left shoulder", "Right shoulder"):
        _reparent(scene.objects[name], hands)
    for side in ("Left", "Right"):
        for part in ("hip", "knee", "ankle"):
            scene.objects[f"{side} {part}"].name = f"{side}{part.title()}"
    for obj in scene.objects:
        if obj.name.startswith("Rifle"):
            obj["sprite_only"] = True
    scene["asset_model"] = "character"
    scene["character_rig_revision"] = 1
    scene["model_clips"] = json.dumps({
        "controls": ["BodyMotion", *LEG_NAMES],
        "clips": [{"name": "idle", "start": 1, "end": 1, "fps": 8},
                  {"name": "walk", "start": 10, "end": 18, "fps": 16}],
    })
    scene["live_animation_notes"] = "Stable upper body; live model exports lower-body tracks only. Original rifle is sprite fallback."
    scene.frame_set(1)
    bpy.context.view_layer.update()
    return True


def extract_weapon(kind):
    """Keep the saved rifle geometry/materials, place it in a weapon-local frame."""
    scene = bpy.context.scene
    scene.frame_set(1)
    grip = scene.objects.get("Rifle grip")
    if grip is None:
        raise ValueError("Nathaniel source is missing Rifle grip.")
    origin = grip.matrix_world.translation.copy()
    basis = Matrix.Rotation(-math.pi / 2, 4, "Z") @ Matrix.Translation(-origin)
    meshes = [obj for obj in scene.objects if obj.type == "MESH" and obj.name.startswith("Rifle")]
    if len(meshes) < 8:
        raise ValueError("Saved source is missing rifle mesh parts; extraction cancelled.")
    transforms = {obj: basis @ obj.matrix_world for obj in meshes}
    hands = [basis @ scene.objects[name].matrix_world.translation for name in ("Right wrist", "Left wrist")]
    for obj in meshes:
        obj.parent = None
        obj.animation_data_clear()
        obj.data = obj.data.copy()
        obj.data.transform(transforms[obj])
        obj.matrix_world = Matrix.Identity(4)
        obj.pop("sprite_only", None)
        if kind == "heavy_rifle":
            # Keep both hand grips and stock fixed. Only the forward barrel grows.
            for vertex in obj.data.vertices:
                if vertex.co.x > 0.18:
                    vertex.co.x = 0.18 + (vertex.co.x - 0.18) * 1.5
            if obj.name in {"Rifle receiver", "Rifle top housing", "Rifle barrel", "Rifle muzzle"}:
                center = sum((v.co for v in obj.data.vertices), Vector()) / len(obj.data.vertices)
                for vertex in obj.data.vertices:
                    vertex.co.y = center.y + (vertex.co.y - center.y) * 1.3
                    vertex.co.z = center.z + (vertex.co.z - center.z) * 1.25
    for obj in list(bpy.data.objects):
        if obj not in meshes:
            bpy.data.objects.remove(obj, do_unlink=True)
    collection = bpy.data.collections.new("Weapon | editable geometry and controls")
    scene.collection.children.link(collection)
    root = _empty("WeaponRoot", collection)
    recoil = _empty("Recoil", collection, root)
    for obj in meshes:
        for owner in list(obj.users_collection):
            owner.objects.unlink(obj)
        collection.objects.link(obj)
        obj.parent = recoil
    # Barrel exit follows the authored forward end of the bore geometry.
    bore = bpy.data.objects["Rifle dark bore"]
    front = max(v.co.x for v in bore.data.vertices)
    front_vertices = [v.co for v in bore.data.vertices if abs(v.co.x - front) < 0.0001]
    muzzle = sum(front_vertices, Vector()) / len(front_vertices)
    _empty("Muzzle", collection, recoil, tuple(muzzle))
    _empty("PrimaryGrip", collection, recoil, tuple(hands[0]))
    _empty("SupportGrip", collection, recoil, tuple(hands[1]))
    for key in list(scene.keys()):
        del scene[key]
    scene["asset_profile"] = "iron_ink"
    scene["asset_model"] = "weapon"
    scene["weapon_forward_axis"] = "+X"
    scene["weapon_id"] = kind
    scene["recoil_distance"] = 0.025 if kind == "rifle" else 0.04
    scene["recoil_duration"] = 0.12 if kind == "rifle" else 0.20
    scene["art_direction"] = "Iron & Ink"
    scene["ground_anchor"] = "Weapon grip origin; Blender +X forward, Z up"
    scene["weapon_notes"] = "Shared Nathaniel rifle grip family; separate saved source, no live library dependency."
    scene.frame_set(1)
    bpy.context.view_layer.update()


def migrate(pipeline, asset, settings):
    source = pipeline.source_path(asset)
    if not source.is_file():
        raise ValueError(f"Source not found: {source}")
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    pipeline.validate_dependencies()
    if rig_character():
        bpy.ops.wm.save_as_mainfile(filepath=str(source))
        print(f"Added live controls to {source.name}; retained meshes, materials and authored actions")
    else:
        print(f"{source.name} already has a live character rig; source unchanged")
    for kind in ("rifle", "heavy_rifle"):
        target = pipeline.source_path(f"weapon_{kind}")
        if target.exists():
            print(f"Kept existing editable source {target.name}")
            continue
        bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
        extract_weapon(kind)
        pipeline.configure(pipeline.export_settings(settings))
        pipeline.validate_dependencies()
        bpy.ops.wm.save_as_mainfile(filepath=str(target), check_existing=False)
        print(f"Created editable weapon source: {target.name}")


def build_weapon(kind):
    source = Path(__file__).resolve().parents[2] / "art/blender/sources/nathaniel.blend"
    if not source.is_file():
        raise ValueError("Create Nathaniel's editable source before deriving a rifle.")
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    extract_weapon(kind)
