"""Palette folding preserves rigid geometry and rejects unsupported paint."""

from copy import deepcopy
import struct
import unittest

from test_rigid_mesh_export import fixture, animation_bytes
from tools.blender.rigid_mesh_export import _write_accessor, batch_rigid_meshes, read_accessor
from tools.blender.vertex_palette_export import fold_vertex_palette, packed_color_key


def painted_fixture():
    document, binary = fixture()
    for material, color in zip(document["materials"], ([0.17, 0.08, 0.12, 1], [0.015, 0.018, 0.018, 1])):
        material.update(doubleSided=True, pbrMetallicRoughness={"metallicFactor": 0.12, "roughnessFactor": 0.78, "baseColorFactor": color})
    second = deepcopy(document["meshes"][0]["primitives"][0])
    second["material"] = 1
    del second["attributes"]["TEXCOORD_0"]
    document["meshes"][0]["primitives"].append(second)
    return document, binary


class VertexPaletteExportTests(unittest.TestCase):
    def test_linear_palette_geometry_uvs_controls_and_animation_survive(self):
        source, binary = painted_fixture()
        snapshot = deepcopy(source)
        result, output = fold_vertex_palette(source, binary)
        self.assertEqual(source, snapshot)
        self.assertEqual(len(result["nodes"]), len(source["nodes"]))
        self.assertEqual(animation_bytes(result, output), animation_bytes(source, binary))
        for node in (1, 2):
            self.assertEqual(result["nodes"][node]["translation"], source["nodes"][node]["translation"])
        self.assertEqual(result["nodes"][1]["mesh"], result["nodes"][2]["mesh"])
        mesh = result["meshes"][result["nodes"][1]["mesh"]]
        self.assertEqual(len(mesh["primitives"]), 1)
        primitive = mesh["primitives"][0]
        for name in ("POSITION", "NORMAL"):
            expected = read_accessor(source, binary, source["meshes"][0]["primitives"][0]["attributes"][name]) * 2
            self.assertEqual(read_accessor(result, output, primitive["attributes"][name]), expected)
        self.assertEqual(read_accessor(result, output, primitive["attributes"]["TEXCOORD_0"]), [(0, 0), (1, 0), (0, 1)] + [(0, 0)] * 3)
        colors = read_accessor(result, output, primitive["attributes"]["COLOR_0"])
        for expected, actual in zip([source["materials"][0]["pbrMetallicRoughness"]["baseColorFactor"]] * 3 + [source["materials"][1]["pbrMetallicRoughness"]["baseColorFactor"]] * 3, colors):
            self.assertEqual(actual, struct.unpack("<4f", struct.pack("<4f", *expected)))
        shared = result["materials"][primitive["material"]]
        self.assertEqual(shared["pbrMetallicRoughness"], {"metallicFactor": 0.12, "roughnessFactor": 0.78, "baseColorFactor": [1, 1, 1, 1]})
        self.assertTrue(shared["doubleSided"])
        palette = result["nodes"][1]["extras"]["rigid_vertex_palette"]
        self.assertEqual(palette[packed_color_key([0.015, 0.018, 0.018, 1])], [0.015, 0.018, 0.018, 1])
        repeated, repeated_binary = fold_vertex_palette(result, output)
        self.assertEqual((repeated, repeated_binary), (result, output))

    def test_material_settings_stay_separate(self):
        for field, value in (("metallicFactor", 0.5), ("roughnessFactor", 0.5)):
            source, binary = painted_fixture()
            source["materials"][1]["pbrMetallicRoughness"][field] = value
            result, _ = fold_vertex_palette(source, binary)
            self.assertEqual(len(result["meshes"][result["nodes"][1]["mesh"]]["primitives"]), 2)
        source, binary = painted_fixture()
        source["materials"][1]["doubleSided"] = False
        result, _ = fold_vertex_palette(source, binary)
        self.assertEqual(len(result["meshes"][result["nodes"][1]["mesh"]]["primitives"]), 2)

    def test_unsupported_paint_keeps_its_original_primitive(self):
        mutations = [lambda m: m.update(emissiveFactor=[1, 0, 0]),
                     lambda m: m["pbrMetallicRoughness"].update(baseColorTexture={"index": 0}),
                     lambda m: m.update(alphaMode="MASK"),
                     lambda m: m.update(extras={"keep": True})]
        for mutate in mutations:
            source, binary = painted_fixture()
            mutate(source["materials"][1])
            result, output = fold_vertex_palette(source, binary)
            mesh = result["meshes"][result["nodes"][1]["mesh"]]
            retained = mesh["primitives"][0]
            self.assertEqual(retained["material"], 1)
            self.assertNotIn("COLOR_0", retained["attributes"])
            self.assertNotIn("TEXCOORD_0", retained["attributes"])
            self.assertEqual(read_accessor(result, output, retained["attributes"]["POSITION"]), read_accessor(source, binary, source["meshes"][0]["primitives"][1]["attributes"]["POSITION"]))

    def test_unknown_geometry_and_palette_collisions_leave_document_unchanged(self):
        mutations = [lambda d: d.update(skins=[{"joints": [1]}]),
                     lambda d: d["meshes"][0]["primitives"][0].update(targets=[{"POSITION": 0}]),
                     lambda d: d["meshes"][0]["primitives"][0]["attributes"].update(COLOR_0=0),
                     lambda d: d["materials"][0].update(alphaMode="BLEND"),
                     lambda d: d["materials"][1]["pbrMetallicRoughness"].update(baseColorFactor=[0.17001, 0.08, 0.12, 1])]
        for mutate in mutations:
            source, binary = painted_fixture()
            mutate(source)
            result, output = fold_vertex_palette(source, binary)
            self.assertIs(result, source)
            self.assertIs(output, binary)

    def test_shared_animated_mesh_retains_emissive_accessors(self):
        source, binary = painted_fixture()
        source["materials"][1]["emissiveFactor"] = [1, 0, 0]
        source["nodes"][3]["mesh"] = 0
        source["accessors"].insert(0, deepcopy(source["accessors"][0]))
        for mesh in source["meshes"]:
            for primitive in mesh["primitives"]:
                primitive["indices"] += 1
                primitive["attributes"] = {name: index + 1 for name, index in primitive["attributes"].items()}
        for sampler in source["animations"][0]["samplers"]:
            sampler["input"] += 1
            sampler["output"] += 1
        result, output = fold_vertex_palette(source, binary)
        original = result["meshes"][result["nodes"][3]["mesh"]]
        self.assertEqual(len(original["primitives"]), 2)
        for before, after in zip(source["meshes"][0]["primitives"], original["primitives"]):
            for name in before["attributes"]:
                self.assertEqual(read_accessor(source, binary, before["attributes"][name]), read_accessor(result, output, after["attributes"][name]))
        self.assertNotIn("extras", result["nodes"][3])

    def test_key_matches_float32_then_stable_rounding(self):
        self.assertEqual(packed_color_key([0.01176449999, 0, 0, 1]), "3,0,0,255")

    def test_index_65535_uses_unsigned_int_in_both_passes(self):
        source, binary = painted_fixture()
        primitive = source["meshes"][0]["primitives"][0]
        primitive["attributes"] = {"POSITION": _write_accessor(source, binary, [(0, 0, 0)] * 32768, "VEC3"),
                                   "NORMAL": _write_accessor(source, binary, [(0, 0, 1)] * 32768, "VEC3")}
        primitive["indices"] = _write_accessor(source, binary, [(0,), (1,), (32767,)], "SCALAR", 5123)
        source["meshes"][0]["primitives"] = [primitive]
        result, _ = batch_rigid_meshes(source, binary)
        merged = result["meshes"][result["nodes"][1]["mesh"]]["primitives"][0]
        self.assertEqual(result["accessors"][merged["indices"]]["componentType"], 5125)
        source["meshes"][0]["primitives"].append({**deepcopy(primitive), "material": 1})
        result, _ = fold_vertex_palette(source, binary)
        merged = result["meshes"][result["nodes"][1]["mesh"]]["primitives"][0]
        self.assertEqual(result["accessors"][merged["indices"]]["componentType"], 5125)


if __name__ == "__main__":
    unittest.main()
