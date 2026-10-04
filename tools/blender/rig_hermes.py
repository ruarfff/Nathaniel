"""Add a shoulder laser to Hermes's saved body without replacing authored art."""

import json
import math

import bpy
from mathutils import Matrix

from iron_ink_towers import _beam, _box, _collection, _finish
from rig_nathaniel import _empty, _reparent


CONTROLS = ("BodyMotion", "Spine", "Left hip", "Left knee", "Left ankle",
            "Right hip", "Right knee", "Right ankle", "Left shoulder", "Right shoulder")
PALETTE = {"ink": "dark joints", "blue": "petrol armour", "top": "top armour",
           "ochre": "ochre", "steel": "worn steel", "bore": "bore", "amber": "amber emitter"}


def rig_character():
    scene = bpy.context.scene
    if scene.get("asset_model") == "mounted_character":
        from model_export import validate_rig

        validate_rig(scene)
        return False
    required = ("AssetFacing", *CONTROLS, "Square sensor head", "Deep chest intake")
    if any(scene.objects.get(name) is None for name in required):
        raise ValueError("Expected Hermes's saved rigid-part source; no source changes made.")
    added = ("LocomotionPivot", "ShoulderMount", "AimPivot", "PitchPivot", "Recoil", "Muzzle")
    if any(scene.objects.get(name) for name in added):
        raise ValueError("Partial mounted rig found; complete it before migration.")
    materials = {key: bpy.data.materials.get("Iron Ink | " + name) for key, name in PALETTE.items()}
    if any(material is None for material in materials.values()):
        raise ValueError("Hermes source is missing its Iron & Ink palette.")
    scene.frame_set(1)
    collection = _collection("Hermes | shoulder laser")
    root = scene.objects["AssetFacing"]
    lower = _empty("LocomotionPivot", collection, root)
    _reparent(scene.objects["BodyMotion"], lower)
    mount = _empty("ShoulderMount", collection, scene.objects["Spine"])
    mount.matrix_world = Matrix.Translation((-0.46, -0.055, 1.62)) @ Matrix.Rotation(math.pi / 2, 4, "Z")
    bpy.context.view_layer.update()
    aim = _empty("AimPivot", collection, mount, (0, -0.26, 0.26))
    pitch = _empty("PitchPivot", collection, aim, (0, 0, 0.38))
    recoil = _empty("Recoil", collection, pitch)
    _empty("Muzzle", collection, recoil, (0.225, 0, 0))

    def box(name, position, size, color, parent, bevel=0.012, edge="steel"):
        obj = _box("Laser " + name, position, size, collection, materials[color],
                   materials[edge] if edge else None, bevel)
        obj.parent = parent
        return obj

    def axle(name, position, radius, depth, parent, axis="Z"):
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=depth, location=position)
        obj = bpy.context.object
        if axis == "Y":
            obj.rotation_euler.x = math.pi / 2
        _finish(obj, "Laser " + name, collection, materials["ink"], materials["steel"], 0.006)
        obj.parent = parent
        return obj

    box("shoulder bracket", (0, 0, 0.045), (0.22, 0.21, 0.09), "blue", mount)
    bracket = _beam("Laser diagonal bracket", (0, 0, 0.055), (0, -0.26, 0.23), 0.17, 0.18,
                    collection, materials["blue"], materials["steel"])
    bracket.parent = mount
    axle("turntable", (0, -0.26, 0.245), 0.105, 0.075, mount)
    box("short riser", (0, 0, 0.175), (0.105, 0.15, 0.37), "blue", aim)
    for side in (-1, 1):
        box(f"tilt fork {side}", (0, side * 0.116, 0.335), (0.12, 0.032, 0.12), "blue", aim)
    axle("tilt axle", (0, 0, 0), 0.070, 0.29, pitch, "Y")
    box("pod housing", (0.025, 0, 0), (0.34, 0.245, 0.225), "blue", recoil, bevel=0.028)
    box("rear cap", (-0.15, 0, 0), (0.045, 0.23, 0.19), "ink", recoil)
    box("top plate", (0.018, 0, 0.119), (0.23, 0.20, 0.028), "top", recoil, bevel=0.008)
    box("ochre rim", (0.192, 0, 0), (0.045, 0.245, 0.225), "ochre", recoil, bevel=0.014)
    box("recessed aperture", (0.216, 0, 0), (0.008, 0.174, 0.145), "bore", recoil, bevel=0.009, edge=None)
    box("amber lens", (0.222, 0, 0), (0.006, 0.109, 0.092), "amber", recoil, bevel=0.009, edge=None)
    for index, y in enumerate((-0.066, 0, 0.066)):
        box(f"rear cooling slot {index}", (-0.177, y, 0.012), (0.012, 0.025, 0.125), "bore", recoil,
            bevel=0.003, edge=None)
    for index, (x, y, z, size) in enumerate([
        (0.08, -0.124, 0.065, (0.052, 0.005, 0.018)),
        (-0.065, 0.124, -0.055, (0.047, 0.005, 0.02)),
        (0.05, 0.035, 0.135, (0.032, 0.024, 0.006)),
        (0.217, -0.101, 0.062, (0.006, 0.031, 0.012)),
    ]):
        box(f"worn edge {index}", (x, y, z), size, "steel", recoil, bevel=0.002, edge=None)
    scene["asset_model"] = "mounted_character"
    scene["asset_profile"] = "iron_ink_mounted"
    scene["weapon_forward_axis"] = "+X"
    scene["mounted_rig_revision"] = 1
    scene["model_clips"] = json.dumps({
        "controls": list(CONTROLS),
        "clips": [{"name": "idle", "start": 1, "end": 1, "fps": 8},
                  {"name": "walk", "start": 10, "end": 18, "fps": 16}],
    })
    scene["concept_reference"] = "concept-art/iron-and-ink/11-hermes-shoulder-laser.png"
    scene["live_animation_notes"] = "Saved body and arm motion; shoulder mount follows Spine; runtime owns yaw and tilt."
    scene.frame_set(1)
    bpy.context.view_layer.update()
    from model_export import validate_rig

    validate_rig(scene)
    return True


def migrate(pipeline, asset):
    source = pipeline.source_path(asset)
    if not source.is_file():
        raise ValueError(f"Source not found: {source}")
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    pipeline.validate_dependencies()
    if rig_character():
        bpy.ops.wm.save_as_mainfile(filepath=str(source))
        print(f"Added shoulder laser to {source.name}; retained saved body meshes, materials and actions")
    else:
        print(f"{source.name} already has a shoulder laser; source unchanged")
