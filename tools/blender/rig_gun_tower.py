"""Add gun controls to an existing tower without replacing its authored geometry."""

import bpy
from mathutils import Matrix, Vector


def rig_gun_tower():
    scene = bpy.context.scene
    if scene.get("asset_model"):
        from model_export import validate_rig

        validate_rig(scene)
        return False
    if any(scene.objects.get(name) for name in ("AimPivot", "Recoil", "Muzzle")):
        raise ValueError("Partial gun rig found. Restore or complete AimPivot/Recoil/Muzzle before migration.")
    pivot = scene.objects.get("Turret pivot | future animation")
    barrel = scene.objects.get("Hollow octagonal cannon")
    if pivot is None or barrel is None or barrel.parent != pivot:
        raise ValueError("Expected the existing gun tower pivot and hollow barrel; no source changes made.")
    if (pivot.matrix_world.translation - Vector((0, 0, 0.71))).length > 0.0001:
        raise ValueError("Gun pivot has moved. Add the rig manually so the artist's intended pivot is retained.")
    # The open ring is the frontmost group of vertices, including any saved mesh edit.
    world_vertices = [barrel.matrix_world @ vertex.co for vertex in barrel.data.vertices]
    front = max(vertex.x for vertex in world_vertices)
    ring = [vertex for vertex in world_vertices if abs(vertex.x - front) < 0.0001]
    if len(ring) < 8:
        raise ValueError("Cannot identify the hollow barrel's front ring. Place a Muzzle marker manually.")
    muzzle_position = sum(ring, Vector()) / len(ring)
    pivot.name = "AimPivot"
    collection = pivot.users_collection[0]
    recoil = bpy.data.objects.new("Recoil", None)
    collection.objects.link(recoil)
    recoil.parent = pivot
    recoil.matrix_basis = Matrix.Identity(4)
    recoil.empty_display_type = "ARROWS"
    recoil.empty_display_size = 0.12
    bpy.context.view_layer.update()
    # The yaw bearing turns but does not slide. All other moving parts recoil together.
    for obj in list(pivot.children):
        if obj == recoil or obj.name == "Gun yaw bearing":
            continue
        authored_transform = obj.matrix_world.copy()
        obj.parent = recoil
        obj.matrix_parent_inverse = Matrix.Identity(4)
        obj.matrix_world = authored_transform
    muzzle = bpy.data.objects.new("Muzzle", None)
    collection.objects.link(muzzle)
    muzzle.parent = recoil
    muzzle.location = recoil.matrix_world.inverted() @ muzzle_position
    muzzle.empty_display_type = "ARROWS"
    muzzle.empty_display_size = 0.09
    scene["asset_model"] = True
    scene["weapon_rig_revision"] = 1
    scene["weapon_forward_axis"] = "+X"
    bpy.context.view_layer.update()
    return True


def migrate(pipeline, asset):
    source = pipeline.source_path(asset)
    if not source.is_file():
        raise ValueError(f"Source not found: {source}")
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    pipeline.validate_dependencies()
    if rig_gun_tower():
        from model_export import validate_rig

        validate_rig(bpy.context.scene)
        bpy.ops.wm.save_as_mainfile(filepath=str(source))
        print(f"Added gun controls to {source.name}; retained authored meshes and materials")
    else:
        print(f"{source.name} already has a valid gun rig; source unchanged")
