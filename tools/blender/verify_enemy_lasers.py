"""Verify source preservation, repeat migrations and enemy muzzle clearance."""

import math

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from iron_ink_aliens import build_alien, build_spawner
from model_export import validate_rig
from rig_enemy_lasers import rig_enemy


def verify_enemy_lasers(pipeline, settings):
    for kind in ("soldier", "boss", "spawner"):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        if kind == "spawner":
            build_spawner()
        else:
            build_alien(kind)
        scene = bpy.context.scene
        mesh = next(obj for obj in scene.objects if obj.type == "MESH")
        mesh.data.vertices[0].co.x += 0.017
        edited = tuple(mesh.data.vertices[0].co)
        actions = set(bpy.data.actions)
        poses = {}
        for frame in (1, 10, 14, 18):
            scene.frame_set(frame)
            bpy.context.view_layer.update()
            poses[frame] = {obj.name: obj.matrix_world.copy() for obj in scene.objects if obj.type == "MESH"}
        assert rig_enemy(kind)
        assert not rig_enemy(kind), "Repeated migration must retain artist edits"
        assert tuple(mesh.data.vertices[0].co) == edited and set(bpy.data.actions) == actions
        for frame, before in poses.items():
            scene.frame_set(frame)
            bpy.context.view_layer.update()
            for name, matrix in before.items():
                after = scene.objects[name].matrix_world
                assert max(abs(matrix[r][c] - after[r][c]) for r in range(4) for c in range(4)) < 0.00001, name
        source = pipeline.source_path(kind)
        before = pipeline.digest(source)
        bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
        assert not rig_enemy(kind)
        validate_rig(bpy.context.scene)
        _clearance(kind)
        assert pipeline.digest(source) == before
        print(f"PASS: {kind} retains edited geometry and actions; migration is inert; live muzzle clears body")


def _clearance(kind):
    scene = bpy.context.scene
    root, aim, pitch = (scene.objects[name] for name in ("AssetFacing", "AimPivot", "PitchPivot"))
    for angle in range(16):
        yaw = angle * math.tau / 16
        root.rotation_euler.z = yaw - math.pi / 2 if kind != "spawner" else 0
        for frame in (1, 10, 14, 18):
            scene.frame_set(frame)
            bpy.context.view_layer.update()
            aimed = set(aim.children_recursive)
            vertices, polygons = [], []
            graph = bpy.context.evaluated_depsgraph_get()
            for obj in scene.objects:
                if obj.type != "MESH" or obj.hide_render or obj in aimed:
                    continue
                evaluated = obj.evaluated_get(graph)
                mesh = evaluated.to_mesh()
                offset = len(vertices)
                vertices += [evaluated.matrix_world @ v.co for v in mesh.vertices]
                polygons += [tuple(offset + i for i in face.vertices) for face in mesh.polygons]
                evaluated.to_mesh_clear()
            tree = BVHTree.FromPolygons(vertices, polygons)
            origin = pitch.matrix_world.translation
            for radius in (120 / 32, 180 / 32, 300 / 32):
                target = Vector((math.cos(yaw) * radius, math.sin(yaw) * radius, 40 / 32))
                direction = (target - origin).normalized()
                start = origin + direction * (scene.objects["Muzzle"].location.x + 0.01)
                hit = tree.ray_cast(start, direction, (target - start).length)
                assert hit[0] is None, (kind, angle, frame, radius, tuple(hit[0]))
