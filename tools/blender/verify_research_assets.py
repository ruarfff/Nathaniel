"""Check saved research geometry, rig controls and export provenance."""

import hashlib
import json
from pathlib import Path
import sys

import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))

from model_export import glb_document, validate_rig


ROOT = Path(__file__).resolve().parents[2]


def verify():
    for asset in ("tech_module", "tech_core", "tech_collector", "research_center"):
        source = ROOT / "art/blender/sources" / f"{asset}.blend"
        bpy.ops.wm.open_mainfile(filepath=str(source), use_scripts=False)
        scene = bpy.context.scene
        controls = validate_rig(scene)
        manifest = json.loads((ROOT / "assets/generated" / f"{asset}.json").read_text())
        model_path = ROOT / manifest["model"]["path"]
        assert manifest["source_sha256"] == hashlib.sha256(source.read_bytes()).hexdigest()
        assert manifest["model"]["sha256"] == hashlib.sha256(model_path.read_bytes()).hexdigest()
        document = glb_document(model_path.read_bytes())
        names = {node.get("name") for node in document["nodes"]}
        assert set(controls).issubset(names), f"{asset}: missing rig controls"
        assert not document.get("cameras"), f"{asset}: model embeds a camera"
        meshes = [obj for obj in scene.objects if obj.type == "MESH"]
        assert 0 < len(meshes) < 100, f"{asset}: unbounded geometry"
        image = bpy.data.images.load(str(ROOT / "assets/generated" / f"{asset}.png"))
        width, height = image.size
        alpha = list(image.pixels)[3::4]
        occupied = [index for index, value in enumerate(alpha) if value > 0.01]
        assert occupied, f"{asset}: empty sprite"
        bounds = (min(index % width for index in occupied), height - max(index // width for index in occupied) - 1,
                  max(index % width for index in occupied) + 1, height - min(index // width for index in occupied))
        assert all(0 < value < max(width, height) for value in bounds), f"{asset}: edge-clipped sprite"
        if asset == "tech_module":
            assert bounds[0] >= 392 and bounds[1] >= 612 and bounds[2] <= 632 and bounds[3] <= 828, "Tech icon clips its module"
        if asset == "research_center":
            assert all(f"ResearchFoot{index}" in names for index in range(1, 5))
            assert "AimPivot" not in names and "Muzzle" not in names, "Research is noncombatant"
        print(f"{asset}: {len(meshes)} meshes, {len(controls)} controls, alpha bounds {bounds}; source and model hashes match")


if __name__ == "__main__":
    verify()
