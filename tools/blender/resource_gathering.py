"""Add the resource backpack and furnace controls to saved character sources."""

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))

from iron_ink_towers import _beam, _box, _collection, _finish, _material
from model_export import glb_document, validate_rig
from pipeline import validate_dependencies
from rig_nathaniel import _empty, _reparent


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ("nathaniel", "hermes", "hermes_anchor")
REVISIONS = {"nathaniel": 2, "hermes": 1, "hermes_anchor": 1}
LINK_LENGTH = 0.36
PALETTE = {
    "ink": "dark joints", "blue": "petrol armour", "top": "top armour",
    "ochre": "ochre", "steel": "worn steel", "bore": "bore",
}


class Mechanism:
    def __init__(self, name):
        self.collection = _collection(name)
        self.materials = {
            key: bpy.data.materials["Iron Ink | " + value]
            for key, value in PALETTE.items()
        }
        self.materials["shell"] = _material("Gathering | plum shell", (0.19, 0.095, 0.17))
        self.materials["edge"] = _material("Gathering | pale shell edge", (0.51, 0.46, 0.34))
        self.materials["fold"] = _material("Gathering | dark shell folds", (0.05, 0.042, 0.052))
        self.materials["furnace"] = _material("Gathering | furnace chamber", (0.025, 0.011, 0.004))

    def empty(self, name, position, parent=None):
        obj = _empty(name, self.collection, parent)
        obj.matrix_world = Matrix.Translation(position)
        bpy.context.view_layer.update()
        return obj

    def box(self, name, position, dimensions, color, parent, edge="steel", bevel=0.008):
        obj = _box(name, position, dimensions, self.collection, self.materials[color],
                   self.materials.get(edge), bevel)
        _reparent(obj, parent)
        return obj

    def beam(self, name, start, end, width, depth, color, parent):
        obj = _beam(name, start, end, width, depth, self.collection,
                    self.materials[color], self.materials["steel"])
        _reparent(obj, parent)
        return obj

    def axle(self, name, position, radius, depth, parent):
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=radius,
                                           depth=depth, location=position)
        obj = bpy.context.object
        obj.rotation_euler.y = math.pi / 2
        _finish(obj, name, self.collection, self.materials["ink"],
                self.materials["steel"], 0.006)
        _reparent(obj, parent)
        return obj

    def shell(self, name, position, parent):
        root = self.empty(name, position, parent)
        root["model_only"] = True
        # The two broad plates retain the body colour after compression.
        for index, (offset, scale, color) in enumerate([
            ((0, 0, 0), (0.15, 0.12, 0.087), "fold"),
            ((-0.028, -0.028, 0.019), (0.139, 0.108, 0.079), "shell"),
            ((0.058, 0.025, 0.008), (0.092, 0.086, 0.064), "shell"),
        ]):
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=Vector(position) + Vector(offset))
            obj = bpy.context.object
            obj.scale = scale
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            _finish(obj, name + " plate " + str(index), self.collection,
                    self.materials[color], self.materials["edge"], 0.009)
            _reparent(obj, root)
        self.box(name + " pale shell seam", Vector(position) + Vector((-0.025, -0.089, 0.030)),
                 (0.15, 0.018, 0.026), "edge", root, edge=None, bevel=0.005)
        return root


def _align_link(node, start, end):
    direction = Vector(end) - Vector(start)
    node.matrix_world = Matrix.Translation(start) @ direction.to_track_quat("Z", "Y").to_matrix().to_4x4()
    bpy.context.view_layer.update()


def _nathaniel():
    scene = bpy.context.scene
    m = Mechanism("Nathaniel | resource backpack")
    root = m.empty("BackpackRoot", (0, 0, 0), scene.objects["Spine"])
    root["gather_link_length"] = LINK_LENGTH
    for side in (-1, 1):
        m.beam(f"Pack rigid shoulder harness {side}", (side * 0.14, 0.06, 1.40),
               (side * 0.14, -0.31, 1.40), 0.055, 0.065, "ink", root)
        m.beam(f"Pack belt harness {side}", (side * 0.16, -0.14, 0.94),
               (side * 0.16, -0.36, 0.94), 0.055, 0.065, "ink", root)
        m.box(f"Pack harness ochre latch {side}", (side * 0.14, -0.30, 1.409),
              (0.068, 0.105, 0.035), "ochre", root)
        m.box(f"Pack rigid vertical rail {side}", (side * 0.145, -0.346, 1.115),
              (0.045, 0.065, 0.54), "ink", root)
    m.box("Pack drive housing", (0, -0.285, 1.34), (0.36, 0.17, 0.16), "blue", root,
          edge="top", bevel=0.021)
    m.box("Pack drive ochre band", (-0.126, -0.377, 1.34), (0.045, 0.025, 0.145), "ochre", root)
    m.box("Pack drive top plate", (0, -0.285, 1.425), (0.29, 0.13, 0.02), "top", root)
    for index, height in enumerate((0.93, 1.11, 1.29), 1):
        slot = m.empty(f"CargoSlot{index}", (0, -0.478, height), root)
        rack = m.empty(f"CargoRack{index}", (0, -0.478, height), slot)
        if index > 1:
            rack["model_only"] = True
        m.box(f"Cargo cradle floor {index}", (0, -0.48, height - 0.095),
              (0.365, 0.285, 0.035), "ink", rack)
        m.box(f"Cargo rear rail {index}", (0, -0.623, height - 0.065),
              (0.36, 0.045, 0.065), "blue", rack)
        for side in (-1, 1):
            m.box(f"Cargo clamp {index} {side}", (side * 0.172, -0.52, height - 0.029),
                  (0.055, 0.20, 0.132), "ochre", rack, bevel=0.012)
        m.shell(f"CargoBundle{index}", (0, -0.478, height), slot)
    for side, name in ((-1, "Left"), (1, "Right")):
        shoulder_position = Vector((side * 0.276, -0.305, 1.34))
        elbow_position = shoulder_position + Vector((side * 0.025, -0.065, -0.353))
        wrist_position = elbow_position + Vector((side * 0.005, -0.132, 0.335))
        shoulder = m.empty("GatherShoulder" + name, shoulder_position, root)
        upper = m.empty("GatherUpper" + name, shoulder_position, shoulder)
        _align_link(upper, shoulder_position, elbow_position)
        elbow = m.empty("GatherElbow" + name, elbow_position, root)
        forearm = m.empty("GatherForearm" + name, elbow_position, elbow)
        _align_link(forearm, elbow_position, wrist_position)
        wrist = m.empty("GatherWrist" + name, wrist_position, root)
        jaw = m.empty("GatherJaw" + name, wrist_position, wrist)
        for pivot, position, label in ((shoulder, shoulder_position, "shoulder"),
                                       (elbow, elbow_position, "elbow"), (wrist, wrist_position, "wrist")):
            m.axle(f"Gather {name} {label} axle", position, 0.065 if label != "wrist" else 0.05, 0.11, pivot)
        # Both link origins sit at their first joint. Godot receives local +Y.
        for pivot, prefix, color in ((upper, "upper", "blue"), (forearm, "forearm", "ochre")):
            for suffix, center, size, finish in (
                ("link", 0.18, (0.087, 0.075, LINK_LENGTH), "ink"),
                ("armour", 0.145, (0.112, 0.097, 0.235), color),
                ("sliding end", 0.305, (0.062, 0.06, 0.11), "steel"),
            ):
                obj = _box(f"Gather {name} {prefix} {suffix}", (0, 0, center), size,
                           m.collection, m.materials[finish], m.materials["steel"], 0.009)
                obj.parent = pivot
            pivot["rest_length"] = LINK_LENGTH
        m.box("Gather " + name + " broad clamp", wrist_position, (0.12, 0.12, 0.135),
              "ochre", jaw, bevel=0.016)
        for z in (-0.069, 0.069):
            m.box(f"Gather {name} crushing pad {z}", wrist_position + Vector((-side * 0.055, -0.035, z)),
                  (0.12, 0.10, 0.038), "ink", jaw, bevel=0.008)
    scene["resource_gathering_notes"] = "Two backpack arms; individual cargo racks; independent of gun recoil and leg clips."


def _hermes():
    scene = bpy.context.scene
    m = Mechanism("Hermes | resource furnace")
    parent = scene.objects["Spine"]
    center = scene.objects["Deep chest intake"].matrix_world.translation.copy()
    root = m.empty("IntakeRoot", center, parent)
    target = center + Vector((0, 0.112, 0))
    m.empty("IntakeTarget", target, root)
    lip_position = center + Vector((0, 0.076, -0.208))
    lip = m.empty("IntakeLip", lip_position, root)
    m.box("Intake lower hinged lip", lip_position + Vector((0, 0.075, 0)),
          (0.52, 0.20, 0.045), "ochre", lip, bevel=0.014)
    for side in (-1, 1):
        m.axle(f"Intake lip hinge {side}", lip_position + Vector((side * 0.265, 0, 0)), 0.036, 0.05, root)
    grille = m.empty("IntakeGrille", center + Vector((0, 0.056, 0)), root)
    for index, height in enumerate((-0.095, 0.025, 0.135)):
        m.box(f"Intake crusher rib {index}", center + Vector((0, 0.067, height)),
              (0.455, 0.058, 0.036), "ink", grille, edge="steel", bevel=0.006)
    glow = m.box("FurnaceGlow", center + Vector((0, 0.035, 0)),
                 (0.445, 0.011, 0.321), "furnace", root, edge=None, bevel=0.008)
    glow["furnace_dark_at_rest"] = True
    m.shell("IntakeBundle", target, root)
    scene["resource_gathering_notes"] = "Contained furnace behind the chest grille; hinged lower lip; independent shoulder laser and cannon."


def _telescoping_rods():
    scene = bpy.context.scene
    collection = scene.objects["BackpackRoot"].users_collection[0]
    for side in ("Left", "Right"):
        name = "GatherExtension" + side
        if name in scene.objects:
            continue
        forearm = scene.objects["GatherForearm" + side]
        rod = _empty(name, collection, scene.objects["GatherElbow" + side])
        rod.matrix_world = forearm.matrix_world.copy()
        rod["rest_length"] = LINK_LENGTH
        mesh = _box("Gather " + side + " telescoping rod", (0, 0, LINK_LENGTH / 2),
                    (0.058, 0.048, LINK_LENGTH), collection,
                    bpy.data.materials["Iron Ink | worn steel"],
                    bpy.data.materials["Iron Ink | dark joints"], 0.006)
        mesh.parent = rod
    bpy.context.view_layer.update()


def _assert_contract(asset):
    scene = bpy.context.scene
    validate_rig(scene)
    names = (["BackpackRoot"] + [f"{prefix}{side}" for side in ("Left", "Right")
                                for prefix in ("GatherShoulder", "GatherUpper", "GatherElbow", "GatherForearm", "GatherExtension", "GatherWrist", "GatherJaw")]
             + [f"{prefix}{index}" for index in (1, 2, 3) for prefix in ("CargoSlot", "CargoRack", "CargoBundle")]
             if asset == "nathaniel" else ["IntakeRoot", "IntakeTarget", "IntakeLip", "IntakeGrille", "FurnaceGlow", "IntakeBundle"])
    for name in names:
        if name not in scene.objects:
            raise ValueError(f"{asset} is missing gathering control {name}")
    if asset == "nathaniel":
        root = scene.objects["BackpackRoot"]
        if root.parent != scene.objects["Spine"]:
            raise ValueError("Backpack must attach to the torso independently of hands and weapon")
        for index in (1, 2, 3):
            if not scene.objects[f"CargoBundle{index}"].get("model_only"):
                raise ValueError("Cargo is runtime-visible; source sprites must remain empty")
    else:
        target = scene.objects["IntakeTarget"].matrix_world.translation
        expected = 1.30 if asset == "hermes" else 0.78
        if abs(target.z - expected) > 0.001:
            raise ValueError("Resource intake must follow the saved body height")
    print(f"{asset}: gathering controls, original weapon rig and intake heights valid")


def _assert_export(asset):
    source = ROOT / "art/blender/sources" / (asset + ".blend")
    manifest = json.loads((ROOT / "assets/generated" / (asset + ".json")).read_text())
    model = ROOT / manifest["model"]["path"]
    if manifest["source_sha256"] != hashlib.sha256(source.read_bytes()).hexdigest():
        raise ValueError(f"{asset}: export does not match the saved Blender source")
    if manifest["model"]["sha256"] != hashlib.sha256(model.read_bytes()).hexdigest():
        raise ValueError(f"{asset}: GLB does not match the export record")
    document = glb_document(model.read_bytes())
    names = {node.get("name") for node in document["nodes"]}
    expected = {obj.name for obj in bpy.context.scene.objects
                if obj.users_collection and obj.users_collection[0].name.endswith(("resource backpack", "resource furnace"))}
    if expected - names:
        raise ValueError(f"{asset}: GLB lost gathering parts: {sorted(expected - names)}")
    source_animation = bpy.context.scene.get("asset_animation")
    if source_animation and not document.get("animations"):
        raise ValueError(f"{asset}: GLB lost the original locomotion clips")
    print(f"{asset}: all {len(expected)} gathering parts exported; source and GLB hashes match")


def migrate(asset):
    path = ROOT / "art/blender/sources" / (asset + ".blend")
    bpy.ops.wm.open_mainfile(filepath=str(path), use_scripts=False)
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()
    scene = bpy.context.scene
    validate_dependencies()
    if scene.get("resource_gathering_revision") == REVISIONS[asset]:
        _assert_contract(asset)
        print(f"{asset}: saved gathering rig retained")
        return
    revision = scene.get("resource_gathering_revision", 0)
    if not revision and (scene.objects.get("BackpackRoot") or scene.objects.get("IntakeRoot")):
        raise ValueError("Partial gathering rig found; complete it before migration")
    original = {obj.name: (obj.data, obj.matrix_world.copy(), obj.parent)
                for obj in scene.objects}
    if not revision:
        (_nathaniel if asset == "nathaniel" else _hermes)()
    if asset == "nathaniel":
        _telescoping_rods()
    scene["resource_gathering_revision"] = REVISIONS[asset]
    _assert_contract(asset)
    for name, (data, transform, parent) in original.items():
        obj = scene.objects[name]
        if obj.data != data or obj.matrix_world != transform or obj.parent != parent:
            raise ValueError(f"Gathering migration modified existing body part: {name}")
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    print(f"{asset}: saved gathering mechanism; {len(original)} original objects preserved")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("migrate", "verify"))
    parser.add_argument("asset", choices=(*ASSETS, "all"), default="all", nargs="?")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    expected = tuple(json.loads((ROOT / "art/blender/settings.json").read_text())["blender_version"])
    if bpy.app.version != expected:
        raise ValueError(f"Resource source migration requires pinned Blender {expected}; found {bpy.app.version}")
    for asset in ASSETS if args.asset == "all" else (args.asset,):
        if args.command == "migrate":
            migrate(asset)
        else:
            bpy.ops.wm.open_mainfile(filepath=str(ROOT / "art/blender/sources" / (asset + ".blend")), use_scripts=False)
            bpy.context.scene.frame_set(1)
            _assert_contract(asset)
            _assert_export(asset)


if __name__ == "__main__":
    main()
