"""Create death sources from saved alien meshes; ordinary exports never rebuild them."""

import json
import math
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

from iron_ink_aliens import Alien, _crest_inset
from iron_ink_towers import _material
from rig_enemy_lasers import _prism, _triangle


ROOT = Path(__file__).resolve().parents[2]


def _empty(name, parent=None, position=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = position
    return obj


def _saved_parts(kind):
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / "art/blender/sources" / (kind + ".blend")), use_scripts=False)
    scene = bpy.context.scene
    scene.frame_set(1)
    bpy.context.view_layer.update()
    graph = bpy.context.evaluated_depsgraph_get()
    parts = []
    for obj in list(scene.objects):
        if obj.type == "MESH" and not obj.hide_render:
            mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(graph), depsgraph=graph)
            mesh.transform(obj.matrix_world)
            parts.append((obj.name, mesh))
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for key in list(scene.keys()):
        del scene[key]
    scene["asset_profile"] = "iron_ink_death_structure" if kind == "spawner" else "iron_ink_death"
    scene["art_direction"] = "Iron & Ink"
    scene["derived_from"] = "art/blender/sources/" + kind + ".blend"
    root = _empty("AssetFacing")
    result = []
    for name, mesh in parts:
        obj = bpy.data.objects.new(name, mesh)
        scene.collection.objects.link(obj)
        obj.parent = root
        result.append(obj)
    # A spent prism must stay dark in every pose.
    for material in bpy.data.materials:
        if material.use_nodes and any(word in material.name for word in ("acid", "lens", "aperture")):
            shader = material.node_tree.nodes.get("Principled BSDF")
            if shader:
                shader.inputs["Base Color"].default_value = (0.035, 0.047, 0.025, 1)
                shader.inputs["Emission Strength"].default_value = 0
    return root, result


def _group(name, objects, root):
    points = [vertex.co for obj in objects for vertex in obj.data.vertices]
    center = sum(points, Vector()) / len(points)
    group = _empty(name, root, center)
    for obj in objects:
        obj.data.transform(Matrix.Translation(-center))
        obj.parent = group
    return group


def _seat(group, height=0.025):
    bpy.context.view_layer.update()
    bottom = min((obj.matrix_world @ vertex.co).z for obj in group.children_recursive
                 if obj.type == "MESH" and not obj.hide_render for vertex in obj.data.vertices)
    group.location.z += height - bottom


def build_boss_corpse():
    root, parts = _saved_parts("boss")
    legs = []
    for side in ("Left", "Right"):
        for row in ("front", "rear"):
            pieces = [obj for obj in parts if obj.name.startswith(side + " " + row)]
            sign = -1 if side == "Left" else 1
            if row == "front":
                pieces += [obj for obj in parts if obj.name.startswith("Boss front cannon " + str(sign))]
            leg = _group(side + " " + row + " folded leg", pieces, root)
            leg.rotation_euler = (0.45 if row == "front" else -0.45, sign * 0.95, sign * 0.28)
            leg.location.x += sign * 0.13
            _seat(leg)
            legs.extend(pieces)
    body = _group("Collapsed body and tilted crest", [obj for obj in parts if obj not in legs], root)
    body.rotation_euler = (1.0, 0.14, -0.12)
    _seat(body, 0.09)
    bpy.context.scene["concept_reference"] = "concept-art/iron-and-ink/20-boss-corpse.png"


def build_boss_bundle():
    c = Alien("Boss compressed matter")
    c.root.name = "MatterRoot"
    c.core("Compressed shell folds", (0, 0, 0), (0.15, 0.12, 0.09), c.root)
    crest = c.shell("Pale crest shard", (0, 0.01, 0.07), (0.22, 0.035, 0.25), c.root,
                    rotation=(1.05, 0.10, -0.18))
    _crest_inset(crest, c.parts, c.p["pale"])
    for side in (-1, 1):
        c.shell("Folded plum shell " + str(side), (side * 0.095, -0.005, 0),
                (0.14, 0.055, 0.17), c.root, rotation=(0.7, side * 0.7, 0), pale=False)
    prism = c.pivot("Dark prism face", (0, 0.13, 0.005), c.root)
    prism.rotation_euler.z = math.pi / 2
    _prism("Dark prism rim", _triangle(0.10), 0, 0.018, prism, c.parts, c.p["pale"])
    _prism("Unlit prism lens", _triangle(0.071), 0.019, 0.022, prism, c.parts, c.p["joint"])
    bpy.context.scene["asset_model"] = "matter"
    bpy.context.scene["concept_reference"] = "concept-art/iron-and-ink/20-boss-corpse.png"


def _key(obj, frame):
    for channel in ("location", "rotation_euler", "scale"):
        obj.keyframe_insert(data_path=channel, frame=frame, group="Death rigid motion")


def spawner_heading_and_light():
    root = bpy.data.objects["AssetFacing"]
    fixed = _empty("FixedBodyHeading", root)
    for obj in list(root.children):
        if obj != fixed:
            obj.parent = fixed
    # Live mounted models normalize +Y source geometry to Blender +X.
    fixed.rotation_euler.z = -math.pi / 2
    shader = bpy.data.materials["Alien | acid openings"].node_tree.nodes["Principled BSDF"]
    for frame, color, strength in [(1, (0.16, 0.28, 0.025, 1), 0.15),
                                   (2, (0.6, 0.9, 0.2, 1), 0.9),
                                   (3, (0.8, 1.0, 0.42, 1), 1.2),
                                   (4, (0.035, 0.047, 0.025, 1), 0.0)]:
        shader.inputs["Base Color"].default_value = color
        shader.inputs["Base Color"].keyframe_insert(data_path="default_value", frame=frame)
        shader.inputs["Emission Strength"].default_value = strength
        shader.inputs["Emission Strength"].keyframe_insert(data_path="default_value", frame=frame)


def refine_explosion(kind):
    scene = bpy.context.scene
    large = kind == "spawner"
    count = 8 if large else 5
    scene.frame_set(1)
    core = scene.objects.get("Spawner dark inner chamber" if large else "Grunt joint body")
    if core:
        core.hide_render = False
        core.keyframe_insert(data_path="hide_render", frame=1)
        core.hide_render = True
        core.keyframe_insert(data_path="hide_render", frame=3 if large else 2)
    groups = [scene.objects.get("Shell fragment %d" % i) for i in range(5)]
    if large:
        groups[4] = scene.objects["Falling crown"]
    starts = {}
    scene.frame_set(1)
    for obj in groups:
        starts[obj] = obj.location.copy()
        obj.animation_data_clear()
    for frame in range(1, count + 1):
        scene.frame_set(frame)
        t = (frame - 1) / (count - 1)
        flight = max(0, (t - (0.16 if large else 0)) / (0.84 if large else 1))
        for index, obj in enumerate(groups):
            start = starts[obj]
            heading = Vector((math.cos(index * math.tau / 5 + 0.3), math.sin(index * math.tau / 5 + 0.3), 0))
            obj.location = start + heading * flight * (1.05 if large else 0.52)
            obj.rotation_euler = (flight * 0.35, flight * (1.6 if large and index == 4 else 0.25), flight * 0.3)
            obj.location.z += math.sin(flight * math.pi) * (0.22 if large else 0.18)
            if t > 0.5:
                _seat(obj, 0.025)
            _key(obj, frame)
        flash = scene.objects["Core flash"]
        flash.location.z = 1.4 if large else 0.67
        flash.location.y = 0.7 if large else 0.12
        flash.keyframe_insert(data_path="location", frame=frame)
    scene.frame_set(1)


def build_explosion(kind):
    root, parts = _saved_parts(kind)
    large = kind == "spawner"
    # Keep four broad shell groups and one identifiable crown/body piece.
    groups = [[] for _ in range(5)]
    for obj in parts:
        if large and (obj.name.startswith(("Laser", "Crown"))):
            index = 4
        elif not large and obj.name.startswith(("Grunt broad", "Pointed", "Mandible", "Acid eye")):
            index = 4
        else:
            center = sum((v.co for v in obj.data.vertices), Vector()) / len(obj.data.vertices)
            index = (0 if center.x < 0 else 1) + (0 if center.y < 0 else 2)
        groups[index].append(obj)
    duration = 0.8 if large else 0.4
    count = 8 if large else 5
    for index, objects in enumerate(groups):
        group = _group("Falling crown" if large and index == 4 else "Shell fragment %d" % index, objects, root)
        start = group.location.copy()
        angle = index * math.tau / 5 + 0.3
        heading = Vector((math.cos(angle), math.sin(angle), 0))
        for frame in range(1, count + 1):
            t = (frame - 1) / (count - 1)
            flight = max(0, (t - (0.16 if large else 0)) / (0.84 if large else 1))
            group.location = start + heading * flight * (0.70 if large else 0.30)
            group.rotation_euler = (flight * 0.9, flight * (1.5 if index == 4 else 0.6), flight * 0.55)
            group.scale = (1, 1, 1)
            group.location.z += math.sin(flight * math.pi) * (0.45 if large else 0.24) - flight * start.z * 0.70
            if t > 0.67:
                _seat(group, 0.025)
            _key(group, frame)
    # Three low dust shapes and a contained, faceted lime-white flash.
    light = _material("Death | lime white", (0.80, 1.0, 0.42), 1.0)
    dust = _material("Death | low sand dust", (0.36, 0.31, 0.23))
    for index in range(4):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1)
        obj = bpy.context.object
        obj.name = "Core flash" if index == 0 else "Low dust %d" % index
        obj.parent = root
        obj.data.materials.append(light if index == 0 else dust)
        radius = (0.7 if large else 0.23) if index == 0 else (0.60 if large else 0.19)
        obj.location = (0, 0.45 if large else 0.1, 0.85 if large else 0.35) if index == 0 else (
            math.cos(index * 2.1) * radius, math.sin(index * 2.1) * radius, 0.09)
        for frame in range(1, count + 1):
            t = (frame - 1) / (count - 1)
            strength = (0.3 if large and frame == 1 else 1.0) if frame <= (3 if large else 2) else 0.001
            if index:
                strength = max(0.001, min(1, (t - 0.15) * 2))
            obj.scale = (radius * strength, radius * strength, radius * strength * (1.15 if index == 0 else 0.22))
            _key(obj, frame)
    scene = bpy.context.scene
    scene["asset_animation"] = json.dumps({"directions": 1 if large else 8, "clips": [
        {"name": "death", "frames": list(range(1, count + 1)), "fps": count / duration, "loop": False}]})
    scene["concept_reference"] = "concept-art/iron-and-ink/" + ("22-spawner-death.png" if large else "21-grunt-death.png")
    scene.frame_start, scene.frame_end = 1, count
    if large:
        spawner_heading_and_light()
    refine_explosion(kind)
    scene.frame_set(1)
