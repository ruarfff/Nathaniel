"""Verify saved resource gathering controls and their exports."""

import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))

from model_export import glb_document, validate_rig


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ("nathaniel", "hermes", "hermes_anchor")


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
    if asset == "hermes_anchor":
        for name in ("WinchRoot", "WinchYoke", "WinchDrum", "WinchOutlet", "WinchGuidePivot", "WinchGuideArm", "WinchGuide", "WinchClamp", "WinchJawLeft", "WinchJawRight"):
            if name not in scene.objects:
                raise ValueError(f"Deployed Hermes is missing side winch control {name}")
        if scene.objects["WinchRoot"].parent != scene.objects["AssetFacing"]:
            raise ValueError("Side winch must stay independent of cannon yaw and recoil")
        if scene["winch_guide_radius_points"] != 72:
            raise ValueError("Side winch guide must match the authored 72-point route")
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
                if obj.users_collection and obj.users_collection[0].name.endswith(("resource backpack", "resource furnace", "side winch"))}
    if expected - names:
        raise ValueError(f"{asset}: GLB lost gathering parts: {sorted(expected - names)}")
    source_animation = bpy.context.scene.get("asset_animation")
    if source_animation and not document.get("animations"):
        raise ValueError(f"{asset}: GLB lost the original locomotion clips")
    print(f"{asset}: all {len(expected)} gathering parts exported; source and GLB hashes match")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("verify",))
    parser.add_argument("asset", choices=(*ASSETS, "all"), default="all", nargs="?")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    expected = tuple(json.loads((ROOT / "art/blender/settings.json").read_text())["blender_version"])
    if bpy.app.version != expected:
        raise ValueError(f"Resource gathering checks require pinned Blender {expected}; found {bpy.app.version}")
    for asset in ASSETS if args.asset == "all" else (args.asset,):
        bpy.ops.wm.open_mainfile(filepath=str(ROOT / "art/blender/sources" / (asset + ".blend")), use_scripts=False)
        bpy.context.scene.frame_set(1)
        _assert_contract(asset)
        _assert_export(asset)


if __name__ == "__main__":
    main()
