"""Export an authored weapon model and its shared isometric camera to Godot."""

import json
import math
from pathlib import Path
import struct
import tempfile

import bpy
from mathutils import Matrix


# glTF maps Blender Z-up into Godot Y-up. Camera/light local axes stay unchanged.
BLENDER_TO_GODOT = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))


def validate_rig(scene):
    role = scene.get("asset_model")
    if role == "mounted_character":
        from model_animation import animation_spec

        names = ("AssetFacing", "LocomotionPivot", "ShoulderMount", "AimPivot", "PitchPivot", "Recoil", "Muzzle")
        nodes = {}
        for name in names:
            node = scene.objects.get(name)
            if node is None or node.type != "EMPTY":
                raise ValueError(f"Mounted character requires an Empty named {name}.")
            nodes[name] = node
        if nodes["LocomotionPivot"].parent != nodes["AssetFacing"]:
            raise ValueError("Mounted character locomotion must be under AssetFacing.")
        if nodes["ShoulderMount"] not in nodes["LocomotionPivot"].children_recursive:
            raise ValueError("ShoulderMount must follow the walking body below LocomotionPivot.")
        for parent, child in zip(names[2:], names[3:]):
            if nodes[child].parent != nodes[parent]:
                raise ValueError("Mounted weapon hierarchy must be ShoulderMount > AimPivot > PitchPivot > Recoil > Muzzle.")
        for name in names[3:]:
            node = nodes[name]
            if max(abs(component - 1) for component in node.scale) > 0.0001:
                raise ValueError(f"Apply scale on mounted weapon control {name} before export.")
            if node.rotation_euler.to_matrix() != Matrix.Identity(3):
                raise ValueError(f"Save {name} at zero rotation; runtime controls mounted aim.")
        if scene.get("weapon_forward_axis") != "+X" or nodes["Muzzle"].location.x <= 0:
            raise ValueError("Mounted weapon muzzle must be forward along local +X.")
        if abs(nodes["Muzzle"].location.y) > 0.0001 or abs(nodes["Muzzle"].location.z) > 0.0001:
            raise ValueError("Mounted muzzle must lie on the local +X pitch axis.")
        if abs(nodes["PitchPivot"].location.x) > 0.0001 or abs(nodes["PitchPivot"].location.y) > 0.0001:
            raise ValueError("PitchPivot must lie directly above the mounted yaw axis.")
        if nodes["Recoil"].location.length > 0.0001:
            raise ValueError("Save mounted Recoil at its rest position (location zero).")
        animation_spec(scene)
        return nodes
    if role in {"character", "weapon"}:
        names = (("AssetFacing", "AimPivot", "LocomotionPivot", "WeaponMount", "WeaponHands")
                 if role == "character" else ("WeaponRoot", "Recoil", "Muzzle", "PrimaryGrip", "SupportGrip"))
        nodes = {}
        for name in names:
            obj = scene.objects.get(name)
            if obj is None or obj.type != "EMPTY":
                raise ValueError(f"{role.title()} model requires an Empty named {name}.")
            nodes[name] = obj
        if role == "character":
            from model_animation import animation_spec

            animation_spec(scene)
            if nodes["AimPivot"].parent != nodes["AssetFacing"] or nodes["LocomotionPivot"].parent != nodes["AssetFacing"]:
                raise ValueError("Character aim and locomotion pivots must be separate children of AssetFacing.")
            if nodes["WeaponHands"].parent != nodes["WeaponMount"]:
                raise ValueError("WeaponHands must be parented to WeaponMount.")
        else:
            if nodes["Recoil"].parent != nodes["WeaponRoot"]:
                raise ValueError("Weapon Recoil must be under WeaponRoot.")
            if any(nodes[name].parent != nodes["Recoil"] for name in ("Muzzle", "PrimaryGrip", "SupportGrip")):
                raise ValueError("Weapon muzzle and grips must follow Recoil.")
            if scene.get("weapon_forward_axis") != "+X" or nodes["Muzzle"].location.x <= 0:
                raise ValueError("Weapon muzzle must be forward along local +X.")
            for name in ("WeaponRoot", "Recoil"):
                node = nodes[name]
                if node.location.length > 0.0001 or node.rotation_euler.to_matrix() != Matrix.Identity(3):
                    raise ValueError(f"Save {name} at zero location/rotation; the character controls its firing pose.")
                if max(abs(component - 1) for component in node.scale) > 0.0001:
                    raise ValueError(f"Apply scale on {name} before weapon export.")
        return nodes
    nodes = {}
    for name in ("AimPivot", "Recoil", "Muzzle"):
        node = scene.objects.get(name)
        if node is None or node.type != "EMPTY":
            raise ValueError(f"Model requires an Empty named {name}; run rig-gun for the original gun source.")
        nodes[name] = node
    pitch = scene.objects.get("PitchPivot")
    if pitch is not None:
        if pitch.type != "EMPTY" or pitch.parent != nodes["AimPivot"]:
            raise ValueError("PitchPivot must be an Empty below AimPivot.")
        if abs(pitch.location.x) > 0.0001 or abs(pitch.location.y) > 0.0001:
            raise ValueError("PitchPivot must lie directly above the turret yaw axis.")
        if abs(nodes["Muzzle"].location.z) > 0.0001:
            raise ValueError("Tilting muzzle must lie on the local +X pitch axis.")
        nodes["PitchPivot"] = pitch
    if nodes["Recoil"].parent != (pitch or nodes["AimPivot"]) or nodes["Muzzle"].parent != nodes["Recoil"]:
        raise ValueError("Weapon hierarchy must be AimPivot > optional PitchPivot > Recoil > Muzzle.")
    if scene.get("weapon_forward_axis") != "+X":
        raise ValueError("Weapon model must use local +X for barrel forward and recoil.")
    for node in nodes.values():
        if max(abs(component - 1) for component in node.scale) > 0.0001:
            raise ValueError(f"Apply scale on weapon control {node.name} before export.")
        if node.rotation_euler.to_matrix() != Matrix.Identity(3):
            raise ValueError(f"Save {node.name} at zero rotation; runtime controls weapon direction.")
    if nodes["AimPivot"].parent is not None:
        raise ValueError("AimPivot must be a top-level object so its yaw axis stays vertical.")
    if nodes["Recoil"].location.length > 0.0001:
        raise ValueError("Save Recoil at its rest position (location zero).")
    muzzle = nodes["Muzzle"].location
    if muzzle.x <= 0 or abs(muzzle.y) > 0.0001:
        raise ValueError("Muzzle must be on the forward +X barrel axis (positive X, zero Y).")
    return nodes


def _transform(obj):
    matrix = BLENDER_TO_GODOT @ obj.matrix_world.to_3x3()
    origin = BLENDER_TO_GODOT @ obj.matrix_world.translation
    # Native .tscn Transform3D text serializes basis rows (the GDScript constructor
    # takes basis columns). Keep this checked against Camera3D.unproject_position.
    values = [matrix[row][column] for row in range(3) for column in range(3)] + list(origin)
    return "Transform3D(" + ", ".join(f"{value:.9g}" for value in values) + ")"


def _scene_text(asset, scene, settings):
    role = scene.get("asset_model")
    if role == "weapon":
        return ('[gd_scene format=3]\n\n'
                f'[ext_resource type="PackedScene" path="res://assets/generated/{asset}.glb" id="1"]\n\n'
                f'[node name="{asset}" instance=ExtResource("1")]\n'
                f'metadata/weapon_id = "{scene["weapon_id"]}"\n'
                f'metadata/recoil_distance = {scene["recoil_distance"]:g}\n'
                f'metadata/recoil_duration = {scene["recoil_duration"]:g}\n')
    light = scene.objects["Pipeline_Sun"]
    return (
        '[gd_scene format=3]\n\n'
        f'[ext_resource type="PackedScene" path="res://assets/generated/{asset}.glb" id="1"]\n\n'
        '[sub_resource type="Environment" id="Environment_shared"]\n'
        'ambient_light_source = 2\n'
        'ambient_light_color = Color(1, 1, 1, 1)\n'
        f'ambient_light_energy = {settings["world_strength"]:g}\n'
        'reflected_light_source = 1\n'
        'tonemap_mode = 0\n\n'
        f'[node name="{asset.title().replace("_", "") + "Model"}" type="Node3D"]\n'
        f'metadata/logical_canvas = Vector2i({settings["canvas"][0]}, {settings["canvas"][1]})\n'
        f'metadata/logical_ground_anchor = Vector2({settings["anchor"][0]}, {settings["anchor"][1]})\n'
        f'metadata/max_pixel_density = {settings["render_density"]}.0\n'
        'metadata/world_points_per_unit = 32\n'
        + ('metadata/model_role = "mounted_character"\n' if role == "mounted_character" else '')
        + (f'metadata/body_aim = "{scene.get("model_body_aim", "movement")}"\n' if role == "mounted_character" else '')
        + '\n'
        '[node name="Geometry" parent="." instance=ExtResource("1")]\n\n'
        '[node name="Camera3D" type="Camera3D" parent="."]\n'
        f'transform = {_transform(scene.camera)}\n'
        'projection = 1\n'
        'current = true\n'
        f'size = {settings["canvas"][1] / (32 * math.sqrt(2)):.9g}\n'
        'near = 0.01\n'
        'far = 100.0\n\n'
        '[node name="Sun" type="DirectionalLight3D" parent="."]\n'
        f'transform = {_transform(light)}\n'
        f'light_energy = {settings["sun_energy"] * settings["model_sun_energy_scale"]:g}\n'
        f'light_angular_distance = {settings["sun_angle_degrees"]:g}\n'
        'shadow_enabled = true\n'
        'directional_shadow_mode = 0\n'
        'directional_shadow_max_distance = 24.0\n\n'
        '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\n'
        'environment = SubResource("Environment_shared")\n'
    )


def glb_document(data):
    if data[:4] != b"glTF":
        raise ValueError("Blender did not produce a GLB model.")
    length, kind = struct.unpack_from("<II", data, 12)
    if kind != 0x4E4F534A:
        raise ValueError("GLB is missing its JSON document.")
    return json.loads(data[20:20 + length])


def stable_glb(data):
    """Remove sub-micropoint float noise from parallel evaluated mesh export.

    Blender's bevel evaluation can differ by one float ULP between processes.
    Six decimal places is below 0.001 output pixel at the maximum density.
    """
    document = glb_document(data)
    json_length = struct.unpack_from("<I", data, 12)[0]
    binary = bytearray(data[28 + json_length:])
    components = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}
    for accessor in document.get("accessors", []):
        if accessor["componentType"] != 5126:
            continue
        view = document["bufferViews"][accessor["bufferView"]]
        count = components[accessor["type"]]
        stride = view.get("byteStride", count * 4)
        offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        minimum, maximum = [math.inf] * count, [-math.inf] * count
        for index in range(accessor["count"]):
            start = offset + index * stride
            values = struct.unpack_from("<" + "f" * count, binary, start)
            values = [round(value, 6) or 0.0 for value in values]
            struct.pack_into("<" + "f" * count, binary, start, *values)
            for axis, value in enumerate(struct.unpack_from("<" + "f" * count, binary, start)):
                minimum[axis] = min(minimum[axis], value)
                maximum[axis] = max(maximum[axis], value)
        if "min" in accessor:
            accessor["min"] = minimum
        if "max" in accessor:
            accessor["max"] = maximum
    return pack_glb(document, binary)


def pack_glb(document, binary):
    encoded = json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode()
    encoded += b" " * (-len(encoded) % 4)
    binary += b"\x00" * (-len(binary) % 4)
    return (struct.pack("<4sII", b"glTF", 2, 28 + len(encoded) + len(binary))
            + struct.pack("<II", len(encoded), 0x4E4F534A) + encoded
            + struct.pack("<II", len(binary), 0x004E4942) + binary)


def export_model(pipeline, asset, scene, settings, source, before):
    rig = validate_rig(scene)
    role = scene.get("asset_model")
    scene.frame_set(1)
    if role in {"character", "mounted_character"}:
        # Source sprites face +Y; normalize the live model to the shared +X contract.
        scene.objects["AssetFacing"].rotation_euler.z = -math.pi / 2
        bpy.context.view_layer.update()
    # Validate before selecting or exporting. Lights and the camera belong in the
    # generated native scene, so the GLB contains only the authored model.
    rendered_objects = set()

    def sprite_only(obj):
        while obj is not None:
            if obj.get("sprite_only"):
                return True
            obj = obj.parent
        return False

    def collect(collection):
        if collection.hide_render:
            return
        rendered_objects.update(obj for obj in collection.objects if not obj.hide_render and not sprite_only(obj))
        for child in collection.children:
            collect(child)

    collect(scene.collection)
    objects = [obj for obj in scene.objects if obj in rendered_objects and obj.type in {"MESH", "EMPTY"}]
    if not any(obj.type == "MESH" for obj in objects):
        raise ValueError("Model has no visible mesh geometry.")
    for name, node in rig.items():
        if node not in objects:
            raise ValueError(f"Required weapon control {name} is hidden from export.")
    for obj in rendered_objects:
        if obj.type not in {"MESH", "EMPTY", "CAMERA", "LIGHT"}:
            raise ValueError(f"Convert {obj.name} ({obj.type}) to a local mesh before model export.")
    for obj in objects:
        obj.hide_set(False)
        obj.hide_viewport = False
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.update()
    with tempfile.TemporaryDirectory(prefix="nathaniel-model-") as temporary:
        output = Path(temporary) / f"{asset}.glb"
        try:
            bpy.ops.export_scene.gltf(
                filepath=str(output), export_format="GLB", use_selection=True,
                export_apply=True, export_animations=False, export_cameras=False,
                export_lights=False, export_extras=False, export_yup=True,
                export_materials="EXPORT", export_texcoords=True, export_normals=True,
                export_draco_mesh_compression_enable=False,
            )
        except (AttributeError, RuntimeError) as error:
            raise ValueError("Blender's bundled glTF exporter is unavailable or failed; use the pinned Blender build.") from error
        data = output.read_bytes()
        if role in {"character", "mounted_character"}:
            from model_animation import add_animations

            data = add_animations(data, scene)
        data = stable_glb(data)
    document = glb_document(data)
    exported_names = {node.get("name") for node in document["nodes"]}
    if not set(rig).issubset(exported_names):
        raise ValueError("GLB lost a weapon control; export cancelled.")
    if document.get("cameras") or any("uri" in buffer for buffer in document.get("buffers", [])):
        raise ValueError("GLB must be self-contained model geometry without cameras.")
    if pipeline.digest(source) != before:
        raise ValueError("Source changed during model export. Export cancelled.")
    pipeline.IMAGES.mkdir(parents=True, exist_ok=True)
    (pipeline.IMAGES / f"{asset}.glb").write_bytes(data)
    scenes = pipeline.ROOT / "scenes/actors/generated"
    scenes.mkdir(parents=True, exist_ok=True)
    (scenes / f"{asset}_model.tscn").write_text(_scene_text(asset, scene, settings))
    print(f"Exported {asset}.glb: {len(data)} bytes; source SHA256 unchanged")
    return {
        "model": {
            "path": f"assets/generated/{asset}.glb",
            "scene": f"scenes/actors/generated/{asset}_model.tscn",
            "sha256": pipeline.digest(pipeline.IMAGES / f"{asset}.glb"),
            "blender_to_godot": ["X", "Z", "-Y"],
            "logical_xy_from_godot": ["-32 * Z", "32 * X"],
            "forward_axis": "+X", "rig_nodes": list(rig),
            "role": role if isinstance(role, str) else "tower",
            "muzzle_blender": list(rig["Muzzle"].matrix_world.translation) if "Muzzle" in rig else None,
            "animations": [animation["name"] for animation in document.get("animations", [])],
            "exporter": document["asset"]["generator"],
            "mesh_float_decimal_places": 6,
            "dependencies": ["Blender bundled glTF 2.0 exporter"],
        },
    }
