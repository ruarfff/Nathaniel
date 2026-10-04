"""Verify saved live-character animation and independent editable weapon sources."""

import hashlib
import json
import struct

import bpy

from iron_ink_characters import build_character
from model_export import glb_document
from rig_nathaniel import extract_weapon, rig_character


def _animation_bytes(data):
    document = glb_document(data)
    offset = 28 + struct.unpack_from("<I", data, 12)[0]
    chunks = []
    for animation in document.get("animations", []):
        for sampler in animation["samplers"]:
            for kind in ("input", "output"):
                accessor = document["accessors"][sampler[kind]]
                view = document["bufferViews"][accessor["bufferView"]]
                start = offset + view.get("byteOffset", 0)
                chunks.append(data[start:start + view["byteLength"]])
    return hashlib.sha256(b"".join(chunks)).hexdigest()


def verify_character_model(pipeline, settings):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_character("nathaniel")
    scene = bpy.context.scene
    before = {obj.name: obj.matrix_world.copy() for obj in scene.objects if obj.type == "MESH"}
    assert rig_character()
    for name, transform in before.items():
        assert max(abs(scene.objects[name].matrix_world[row][column] - transform[row][column])
                   for row in range(4) for column in range(4)) < 0.000001, name
    assert not rig_character()
    scene["asset_profile"] = "default"
    source = pipeline.source_path("character_probe")
    pipeline.configure(settings)
    bpy.ops.wm.save_as_mainfile(filepath=str(source), check_existing=False)
    pipeline.render("character_probe", settings)
    glb = pipeline.IMAGES / "character_probe.glb"
    original = glb.read_bytes()
    document = glb_document(original)
    assert {animation["name"] for animation in document["animations"]} == {"idle", "walk"}
    assert not any(node.get("name", "").startswith("Rifle") for node in document["nodes"])
    animated = {document["nodes"][channel["target"]["node"]]["name"]
                for animation in document["animations"] for channel in animation["channels"]}
    assert "LeftHip" in animated and "BodyMotion" in animated
    assert not animated.intersection({"AimPivot", "Spine", "WeaponMount", "WeaponHands"})
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    chest = bpy.data.objects["Chest armour"]
    chest["artist_note"] = "Keep my live-character edit"
    chest.data.vertices[0].co.z += 0.012
    scene = bpy.context.scene
    scene.frame_set(12)
    hip = scene.objects["LeftHip"]
    hip.rotation_euler.x += 0.06
    hip.keyframe_insert(data_path="rotation_euler", frame=12)
    scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    saved_hash = pipeline.digest(source)
    pipeline.render("character_probe", settings)
    edited = glb.read_bytes()
    assert edited != original
    assert _animation_bytes(edited) != _animation_bytes(original), "Saved authored walk edit did not reach GLB"
    pngs = {path.name: path.read_bytes() for path in pipeline.IMAGES.glob("character_probe*.png")}
    pipeline.render("character_probe", settings)
    assert glb.read_bytes() == edited
    assert pipeline.digest(source) == saved_hash
    assert all((pipeline.IMAGES / name).read_bytes() == data for name, data in pngs.items())
    metadata = json.loads((pipeline.IMAGES / "character_probe.json").read_text())
    assert metadata["model"]["role"] == "character" and metadata["model"]["animations"] == ["idle", "walk"]

    grips, muzzle_x = {}, {}
    for kind in ("rifle", "heavy_rifle"):
        bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
        extract_weapon(kind)
        scene = bpy.context.scene
        scene["asset_profile"] = "default"
        grips[kind] = [tuple(scene.objects[name].location) for name in ("PrimaryGrip", "SupportGrip")]
        muzzle_x[kind] = scene.objects["Muzzle"].location.x
        path = pipeline.source_path(f"weapon_{kind}_probe")
        pipeline.configure(settings)
        bpy.ops.wm.save_as_mainfile(filepath=str(path), check_existing=False)
        before_hash = pipeline.digest(path)
        pipeline.render(path.stem, settings)
        weapon_glb = pipeline.IMAGES / f"{path.stem}.glb"
        first = weapon_glb.read_bytes()
        pipeline.render(path.stem, settings)
        assert weapon_glb.read_bytes() == first and pipeline.digest(path) == before_hash
        assert not glb_document(first).get("animations")
        assert bpy.context.scene.objects["Muzzle"].parent.name == "Recoil"
    assert grips["rifle"] == grips["heavy_rifle"], "Weapons no longer share the authored hand grips"
    assert muzzle_x["heavy_rifle"] > muzzle_x["rifle"]
    assert pipeline.digest(source) == saved_hash, "Weapon extraction changed the character source"
    scene = bpy.context.scene
    scene.objects["Recoil"].location.x = -0.02
    invalid_weapon = pipeline.source_path("invalid_weapon_probe")
    bpy.ops.wm.save_as_mainfile(filepath=str(invalid_weapon), check_existing=False)
    try:
        pipeline.render(invalid_weapon.stem, settings)
    except ValueError as error:
        assert "zero location/rotation" in str(error)
    else:
        raise AssertionError("Weapon exported with a non-rest firing pose")
    assert not (pipeline.IMAGES / "invalid_weapon_probe.glb").exists()
    bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
    spec = json.loads(bpy.context.scene["model_clips"])
    spec["controls"].append("Spine")
    bpy.context.scene["model_clips"] = json.dumps(spec)
    invalid_character = pipeline.source_path("invalid_character_probe")
    bpy.ops.wm.save_as_mainfile(filepath=str(invalid_character), check_existing=False)
    try:
        pipeline.render(invalid_character.stem, settings)
    except ValueError as error:
        assert "upper-body aim stays stable" in str(error)
    else:
        raise AssertionError("Character exported an upper-body animation that changes the launch pose")
    assert not (pipeline.IMAGES / "invalid_character_probe.glb").exists()
    print("PASS: character migration preserves meshes; saved walk edit exports; upper body stable; two weapons share grips; repeat exports retain sources")
