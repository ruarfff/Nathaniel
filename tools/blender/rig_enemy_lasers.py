"""Add the selected enemy emitters to saved alien sources, preserving body art."""

import json
import math

import bpy
from mathutils import Matrix

from iron_ink_towers import _collection, _finish, _material
from rig_nathaniel import _empty, _reparent


REFERENCES = {"spawner": "13-spawner-crown-laser", "soldier": "14-soldier-lance-laser",
              "boss": "15-boss-siege-laser"}


def _retire(scene, names):
    for name in names:
        obj = scene.objects[name]
        for part in [obj, *obj.children_recursive]:
            part.hide_render = True
            part.hide_set(True)
            part["retained_original_weapon"] = True


def _prism(name, outline, back, front, parent, collection, material, edge=None):
    count = len(outline)
    vertices = [(x, y, z) for x in (back, front) for y, z in outline]
    faces = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
    faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    _finish(obj, name, collection, material, edge, 0.009 if edge else 0)
    obj.parent = parent
    return obj


def _triangle(size):
    return [(-size * 0.52, size * 0.34), (0, -size * 0.62), (size * 0.52, size * 0.34)]


def _emitter(parent, collection, palette, length, size):
    outer, inner = _triangle(size), _triangle(size * 0.62)
    for i in range(3):
        j = (i + 1) % 3
        outline = [outer[i], inner[i], inner[j], outer[j]]
        _prism(f"Laser shell plate {i}", outline, 0.05, length, parent, collection,
               palette["plum"], palette["pale"])
    _prism("Laser recessed aperture", _triangle(size * 0.61), length - 0.025, length + 0.008,
           parent, collection, palette["joint"])
    _prism("Laser crimson rim", _triangle(size * 0.47), length + 0.009, length + 0.012,
           parent, collection, palette["rim"])
    _prism("Laser optical core", _triangle(size * 0.34), length + 0.013, length + 0.017,
           parent, collection, palette["lens"])
    return length + 0.018


def _joint(name, parent, collection, palette, radius, depth, location=(0, 0, 0), tilt=False):
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=radius, depth=depth)
    obj = bpy.context.object
    _finish(obj, name, collection, palette["joint"], palette["pale"], 0.008)
    obj.parent = parent
    obj.location = location
    if tilt:
        obj.rotation_euler.x = math.pi / 2
    return obj


def rig_enemy(kind):
    scene = bpy.context.scene
    if kind not in REFERENCES:
        raise ValueError("Enemy laser migration supports spawner, soldier and boss only.")
    if scene.get("enemy_laser_revision"):
        from model_export import validate_rig

        validate_rig(scene)
        if scene["enemy_laser_revision"] == 1:
            _refine_shells(kind)
            return True
        if kind == "spawner" and scene["enemy_laser_revision"] == 2:
            _raise_crown()
            return True
        return False
    required = {"soldier": ["Soldier shoulder 1", "Soldier chest carapace"],
                "boss": ["Boss dominant pale crest", "Boss broad tissue body"],
                "spawner": ["Spire dark crown", "Dark emergence opening"]}[kind]
    if any(scene.objects.get(name) is None for name in ["AssetFacing", "BodyMotion", "Spine", *required]):
        raise ValueError(f"Expected the saved {kind} source; no source changes made.")
    if any(scene.objects.get(name) for name in ("LocomotionPivot", "ShoulderMount", "AimPivot", "PitchPivot", "Recoil", "Muzzle")):
        raise ValueError("Partial mounted rig found; complete it before migration.")
    scene.frame_set(1)
    collection = _collection(f"{kind.title()} | laser controls and shell")
    palette = {key: bpy.data.materials.get("Alien | " + name) for key, name in
               {"plum": "dark plum shell", "pale": "pale shell edge", "joint": "exposed dark joint"}.items()}
    if any(value is None for value in palette.values()):
        raise ValueError("Saved alien palette is missing.")
    palette["rim"] = _material("Alien | crimson aperture", (0.75, 0.025, 0.07), 0.5)
    palette["lens"] = _material("Alien | pink white lens", (1.0, 0.65, 0.73), 0.7)
    lower = _empty("LocomotionPivot", collection, scene.objects["AssetFacing"])
    _reparent(scene.objects["BodyMotion"], lower)
    mount = _empty("ShoulderMount", collection, scene.objects["Spine"])
    position = {"soldier": (0.39, -0.015, 1.37), "boss": (0, 0.30, 1.13),
                "spawner": (0, -0.58, 2.78)}[kind]
    mount.matrix_world = Matrix.Translation(position) @ Matrix.Rotation(math.pi / 2, 4, "Z")
    bpy.context.view_layer.update()
    aim = _empty("AimPivot", collection, mount)
    height = 0.30 if kind == "spawner" else 0.0
    pitch = _empty("PitchPivot", collection, aim, (0, 0, height))
    recoil = _empty("Recoil", collection, pitch)
    controls = [obj.name for obj in scene.objects if obj.type == "EMPTY" and obj.animation_data
                and obj.animation_data.action and obj in lower.children_recursive]
    if kind == "soldier":
        _retire(scene, ["Soldier shoulder 1"])
        controls = [name for name in controls if not scene.objects[name].hide_render]
        _joint("Laser shoulder joint", pitch, collection, palette, 0.115, 0.20, tilt=True)
        _prism("Laser upper arm", [(-0.10, 0.10), (-0.11, -0.10), (0.11, -0.10), (0.10, 0.10)],
               0.02, 0.21, recoil, collection, palette["plum"], palette["pale"])
        muzzle = _emitter(recoil, collection, palette, 0.63, 0.34)
        scene["model_body_aim"] = "target"
    elif kind == "spawner":
        _retire(scene, ["Spawn spire shell -1", "Spawn spire shell 1", "Spawn acid heart", "Spire dark crown"])
        _joint("Crown rooted bearing", mount, collection, palette, 0.32, 0.18)
        _joint("Crown tilt bearing", pitch, collection, palette, 0.18, 0.67, tilt=True)
        muzzle = _emitter(recoil, collection, palette, 0.43, 0.78)
        controls = ["BodyMotion"]
        scene["model_body_aim"] = "fixed"
    else:
        _retire(scene, ["Boss dominant pale crest"])
        _joint("Siege protected swivel", pitch, collection, palette, 0.25, 0.38, tilt=True)
        muzzle = _emitter(recoil, collection, palette, 0.41, 0.49)
        for side, name in [(-1, "ApertureLeft"), (1, "ApertureRight")]:
            shutter = _empty(name, collection, recoil, (0.14, side * 0.20, -0.40))
            outline = [(side * y, z) for y, z in [(0.04, 0), (-0.12, 0.30), (-0.10, 0.62),
                       (-0.13, 1.02), (0.20, 0.78), (0.36, 0.40), (0.29, 0.11)]]
            if side < 0:
                outline.reverse()
            _prism(f"Siege crest shutter {side}", outline, -0.06, 0.10,
                   shutter, collection, palette["plum"], palette["pale"])
            inset = [(y * 0.77, z * 0.87 + 0.06) for y, z in outline]
            _prism(f"Siege pale crest inset {side}", inset, 0.105, 0.111,
                   shutter, collection, palette["pale"])
        scene["model_body_aim"] = "target"
    _empty("Muzzle", collection, recoil, (muzzle, 0, 0))
    scene["asset_model"] = "mounted_character"
    scene["weapon_forward_axis"] = "+X"
    scene["enemy_laser_revision"] = 1
    scene["asset_profile"] = "iron_ink_structure" if kind == "spawner" else "iron_ink_mounted"
    scene["model_clips"] = json.dumps({"controls": controls, "clips": [
        {"name": "idle", "start": 1, "end": 1, "fps": 8},
        {"name": "walk", "start": 10 if kind != "spawner" else 1,
         "end": 18 if kind != "spawner" else 1, "fps": 16}]})
    scene["concept_reference"] = f"concept-art/iron-and-ink/{REFERENCES[kind]}.png"
    scene.frame_set(1)
    bpy.context.view_layer.update()
    from model_export import validate_rig

    validate_rig(scene)
    _refine_shells(kind)
    return True


def _refine_shells(kind):
    scene = bpy.context.scene
    for index in range(3):
        mesh = scene.objects[f"Laser shell plate {index}"].data
        for vertex in list(mesh.vertices)[:len(mesh.vertices) // 2]:
            vertex.co.y *= 0.72
            vertex.co.z *= 0.72
        mesh.update()
    if kind == "boss":
        for obj in scene.objects:
            if obj.name.startswith(("Siege crest shutter", "Siege pale crest inset")):
                for vertex in obj.data.vertices:
                    vertex.co.x -= vertex.co.z * 0.55
                obj.data.update()
    if kind == "spawner":
        mount = scene.objects["ShoulderMount"]
        collection = mount.users_collection[0]
        palette = {key: bpy.data.materials["Alien | " + name] for key, name in
                   {"plum": "dark plum shell", "pale": "pale shell edge", "joint": "exposed dark joint"}.items()}
        _prism("Crown rooted spire", [(-0.36, -0.80), (-0.23, 0.06), (0.23, 0.06), (0.36, -0.80)],
               -0.28, 0.26, mount, collection, palette["plum"], palette["pale"])
        _joint("Crown short riser", scene.objects["AimPivot"], collection, palette,
               0.20, 0.40, (0, 0, 0.16))
    scene["enemy_laser_revision"] = 2
    if kind == "spawner":
        _raise_crown()


def _raise_crown():
    scene = bpy.context.scene
    scene.objects["ShoulderMount"].location.z += 0.25
    mesh = scene.objects["Crown rooted spire"].data
    for vertex in mesh.vertices:
        if vertex.co.z < 0:
            vertex.co.z -= 0.25
    mesh.update()
    scene["enemy_laser_revision"] = 3


def migrate(pipeline, asset):
    source = pipeline.source_path(asset)
    if asset not in REFERENCES or not source.is_file():
        raise ValueError("Choose the saved spawner, soldier or boss source.")
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    pipeline.validate_dependencies()
    if rig_enemy(asset):
        bpy.ops.wm.save_as_mainfile(filepath=str(source))
        print(f"Added {asset} laser; saved body art and original weapon meshes retained")
    else:
        print(f"{asset} already has its laser; source unchanged")
