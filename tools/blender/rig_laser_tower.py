"""Give the saved laser tower yaw, tilt and an emitter marker without rebuilding it."""

import math

import bpy
from mathutils import Matrix, Vector

from iron_ink_towers import _box, _finish, _material


def rig_laser_tower():
    scene = bpy.context.scene
    if scene.get("laser_tower_rig_revision"):
        from model_export import validate_rig

        validate_rig(scene)
        return False
    if any(scene.objects.get(name) for name in ("AimPivot", "PitchPivot", "Recoil", "Muzzle")):
        raise ValueError("Partial laser rig found; complete it before migration.")
    pivot = scene.objects.get("Turret pivot | future animation")
    lens = scene.objects.get("Amber chamber window")
    bearing = scene.objects.get("Laser yaw bearing")
    if pivot is None or lens is None or bearing is None or lens.parent != pivot:
        raise ValueError("Expected the saved laser turret and chamber window; source unchanged.")
    if (pivot.matrix_world.translation - Vector((0, 0, 0.71))).length > 0.0001:
        raise ValueError("Laser pivot has moved; rig the artist's saved pivot manually.")
    ink = bpy.data.materials.get("Iron Ink | dark joints")
    steel = bpy.data.materials.get("Iron Ink | worn steel")
    armour = bpy.data.materials.get("Iron Ink | petrol armour")
    if any(material is None for material in (ink, steel, armour)):
        raise ValueError("Saved tower palette is missing.")
    moving = [obj for obj in pivot.children if obj != bearing]
    center = lens.matrix_world.translation.copy()
    front = max((lens.matrix_world @ vertex.co).x for vertex in lens.data.vertices)
    collection = pivot.users_collection[0]
    pivot.name = "AimPivot"

    def control(name, parent, location):
        obj = bpy.data.objects.new(name, None)
        collection.objects.link(obj)
        obj.parent = parent
        obj.location = location
        obj.empty_display_type = "ARROWS"
        obj.empty_display_size = 0.1
        bpy.context.view_layer.update()
        return obj

    def parent_at_rest(obj, parent):
        transform = obj.matrix_world.copy()
        obj.parent = parent
        obj.matrix_parent_inverse = Matrix.Identity(4)
        obj.matrix_world = transform

    # Lift the saved head enough to clear the pedestal when aiming down.
    lift = 0.14
    height = center.z + lift
    pitch = control("PitchPivot", pivot, (0, 0, height - pivot.location.z))
    recoil = control("Recoil", pitch, (0, 0, 0))
    for obj in moving:
        transform = obj.matrix_world.copy()
        transform.translation.z += lift
        obj.matrix_world = transform
        parent_at_rest(obj, recoil)
    control("Muzzle", recoil, (front + 0.006, 0, 0))
    for side in (-1, 1):
        support = _box(f"Laser tilt support {side}", (0, side * 0.39, 0.98),
                       (0.20, 0.085, 0.38), collection, armour, steel)
        parent_at_rest(support, pivot)
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.10, depth=0.09,
                                           location=(0, side * 0.40, height),
                                           rotation=(math.pi / 2, 0, 0))
        joint = _finish(bpy.context.object, f"Laser tilt trunnion {side}", collection, ink, steel)
        parent_at_rest(joint, pivot)
    lens.data.materials.clear()
    lens.data.materials.append(_material("Iron Ink | cyan laser lens", (0.24, 0.88, 1.0), 1.3))
    scene["asset_model"] = True
    scene["weapon_forward_axis"] = "+X"
    scene["laser_tower_rig_revision"] = 1
    bpy.context.view_layer.update()
    return True


def migrate(pipeline, asset):
    source = pipeline.source_path(asset)
    if not source.is_file():
        raise ValueError(f"Source not found: {source}")
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    pipeline.validate_dependencies()
    if rig_laser_tower():
        from model_export import validate_rig

        validate_rig(bpy.context.scene)
        bpy.ops.wm.save_as_mainfile(filepath=str(source))
        print(f"Added laser turret controls to {source.name}; retained authored meshes")
    else:
        print(f"{source.name} already has laser controls; source unchanged")
