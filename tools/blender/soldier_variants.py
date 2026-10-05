"""Create a gun soldier and fit matching weapons to the saved corpse art."""

import math

import bpy

from iron_ink_aliens import _seat_corpse
from iron_ink_towers import _material
from rig_enemy_lasers import _prism, _retire
from rig_nathaniel import _empty


def _gun(scene):
    recoil = scene.objects["Recoil"]
    collection = recoil.users_collection[0]
    for obj in list(recoil.children_recursive):
        if obj.type == "MESH":
            obj.hide_render = True
            obj.hide_set(True)
            obj["retained_laser_weapon"] = True
    plum = bpy.data.materials["Alien | dark plum shell"]
    pale = bpy.data.materials["Alien | pale shell edge"]
    joint = bpy.data.materials["Alien | exposed dark joint"]
    _prism("Gun arm receiver", [(-0.15, 0.12), (-0.16, -0.15), (0.16, -0.15), (0.15, 0.12)],
           0.02, 0.46, recoil, collection, plum, pale)
    _prism("Gun lower magazine", [(-0.09, -0.12), (-0.07, -0.32), (0.07, -0.32), (0.09, -0.12)],
           0.16, 0.36, recoil, collection, joint, pale)
    # A hollow hexagonal bore gives this arm a different silhouette from the lance.
    outer = [(math.cos(i * math.tau / 6) * 0.12, math.sin(i * math.tau / 6) * 0.12) for i in range(6)]
    inner = [(y * 0.62, z * 0.62) for y, z in outer]
    for i in range(6):
        j = (i + 1) % 6
        _prism(f"Gun barrel wall {i}", [outer[i], inner[i], inner[j], outer[j]],
               0.41, 0.80, recoil, collection, joint, pale)
    _prism("Gun recessed bore", inner, 0.42, 0.43, recoil, collection, joint)
    scene.objects["Muzzle"].location = (0.81, 0, 0)
    scene["soldier_weapon_kind"] = "gunSoldier"
    scene["concept_reference"] = "concept-art/iron-and-ink/02-alien-enemies.png"
    if "enemy_laser_revision" in scene:
        del scene["enemy_laser_revision"]


def _corpse(pipeline, asset, live_asset, kind):
    source = pipeline.source_path(asset)
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    if bpy.context.scene.get("corpse_weapon_kind") == kind:
        if not bpy.context.scene.get("corpse_weapon_revision"):
            scene = bpy.context.scene
            scene.objects["Spent weapon mount"].rotation_euler.rotate_axis("Y", 1.60)
            _seat_corpse(scene.objects["BodyMotion"], scene.objects)
            scene["corpse_weapon_revision"] = 1
            bpy.ops.wm.save_as_mainfile(filepath=str(source))
            print(f"Rested {asset} weapon beside the collapsed body")
            return
        print(f"{asset} already has its matching weapon; source unchanged")
        return
    bpy.ops.wm.open_mainfile(filepath=str(pipeline.source_path(live_asset)), use_scripts=False)
    mount = bpy.context.scene.objects["ShoulderMount"]
    relative = mount.matrix_local.copy()
    meshes = []
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in mount.children_recursive:
        if obj.type != "MESH" or obj.hide_render:
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        transform = mount.matrix_world.inverted() @ evaluated.matrix_world
        materials = []
        for material in mesh.materials:
            shader = material.node_tree.nodes.get("Principled BSDF")
            color = tuple(shader.inputs["Base Color"].default_value[:3])
            if "aperture" in material.name or "lens" in material.name:
                color = (0.08, 0.025, 0.035)
            materials.append((material.name, color))
        meshes.append((obj.name, [tuple(transform @ v.co) for v in mesh.vertices],
                       [tuple(p.vertices) for p in mesh.polygons],
                       [p.material_index for p in mesh.polygons], materials))
        evaluated.to_mesh_clear()
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    scene = bpy.context.scene
    _retire(scene, ["Soldier shoulder 1"])
    mount = _empty("Spent weapon mount", scene.collection, scene.objects["Spine"])
    mount.matrix_basis = relative
    mount.rotation_euler.rotate_axis("Z", 0.38)
    mount.rotation_euler.rotate_axis("Y", 1.25)
    for name, vertices, faces, indices, materials in meshes:
        mesh = bpy.data.meshes.new("Spent " + name)
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        obj = bpy.data.objects.new(mesh.name, mesh)
        scene.collection.objects.link(obj)
        obj.parent = mount
        for name, color in materials:
            mesh.materials.append(_material("Spent weapon | " + name, color))
        for polygon, index in zip(mesh.polygons, indices):
            polygon.material_index = index
    _seat_corpse(scene.objects["BodyMotion"], scene.objects)
    scene["corpse_weapon_kind"] = kind
    scene["corpse_weapon_revision"] = 1
    pipeline.validate_dependencies()
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    print(f"Updated {asset}: preserved collapsed body and fitted {kind} weapon")


def prepare(pipeline):
    gun = pipeline.source_path("gun_soldier")
    if not gun.exists():
        bpy.ops.wm.open_mainfile(filepath=str(pipeline.source_path("soldier")), use_scripts=False)
        _gun(bpy.context.scene)
        pipeline.validate_dependencies()
        bpy.ops.wm.save_as_mainfile(filepath=str(gun), check_existing=False)
    gun_corpse = pipeline.source_path("gun_soldier_corpse")
    if not gun_corpse.exists():
        bpy.ops.wm.open_mainfile(filepath=str(pipeline.source_path("soldier_corpse")), use_scripts=False)
        bpy.ops.wm.save_as_mainfile(filepath=str(gun_corpse), check_existing=False)
    _corpse(pipeline, "gun_soldier_corpse", "gun_soldier", "gunSoldier")
    _corpse(pipeline, "soldier_corpse", "soldier", "soldier")
