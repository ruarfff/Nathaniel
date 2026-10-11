"""Rigid batching keeps authored surfaces, animation controls and sprite provenance."""

from copy import deepcopy
import math
import struct
import unittest

from tools.blender.model_metadata import replace_model_metadata, validate_model_only_metadata
from tools.blender.rigid_mesh_export import batch_rigid_meshes, read_accessor


def fixture():
    document = {"asset": {"version": "2.0"}, "scene": 0, "scenes": [{"nodes": [0]}],
                "nodes": [{"name": "Body", "children": [1, 2, 3]},
                          {"name": "First", "mesh": 0, "translation": [1, 2, 3],
                           "rotation": [0, 0, math.sqrt(0.5), math.sqrt(0.5)], "scale": [2, 3, 4]},
                          {"name": "Second", "mesh": 0, "translation": [-2, 0, 0]},
                          {"name": "Animated", "mesh": 1}],
                "materials": [{"name": "Paint"}, {"name": "Metal"}],
                "meshes": [], "accessors": [], "bufferViews": [], "buffers": [{"byteLength": 0}]}
    binary = bytearray()

    def accessor(values, kind, fmt="f"):
        binary.extend(b"\0" * (-len(binary) % 4))
        offset = len(binary)
        for value in values:
            binary.extend(struct.pack("<" + fmt * len(value), *value))
        document["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(binary) - offset})
        document["accessors"].append({"bufferView": len(document["bufferViews"]) - 1,
                                      "componentType": 5126 if fmt == "f" else 5123,
                                      "type": kind, "count": len(values)})
        return len(document["accessors"]) - 1

    position = accessor([(0, 0, 0), (1, 0, 0), (0, 1, 0)], "VEC3")
    normal = accessor([(math.sqrt(0.5), math.sqrt(0.5), 0)] * 3, "VEC3")
    uv = accessor([(0, 0), (1, 0), (0, 1)], "VEC2")
    indices = accessor([(0,), (1,), (2,)], "SCALAR", "H")
    primitive = {"attributes": {"POSITION": position, "NORMAL": normal, "TEXCOORD_0": uv},
                 "indices": indices, "material": 0}
    document["meshes"] = [{"name": "Piece", "primitives": [primitive]},
                           {"name": "Moving piece", "primitives": [{**deepcopy(primitive), "material": 1}]}]
    time = accessor([(0,), (1,)], "SCALAR")
    motion = accessor([(0, 0, 0), (0, 0, 1)], "VEC3")
    document["animations"] = [{"name": "walk", "samplers": [{"input": time, "output": motion, "interpolation": "LINEAR"}],
                               "channels": [{"sampler": 0, "target": {"node": 3, "path": "translation"}}]}]
    document["buffers"][0]["byteLength"] = len(binary)
    return document, binary


def animation_bytes(document, binary):
    records = []
    for animation in document["animations"]:
        for sampler in animation["samplers"]:
            for field in ("input", "output"):
                accessor = document["accessors"][sampler[field]]
                view = document["bufferViews"][accessor["bufferView"]]
                start = view.get("byteOffset", 0)
                records.append(bytes(binary[start:start + view["byteLength"]]))
    return records


class RigidMeshExportTests(unittest.TestCase):
    def test_rigid_triangles_normals_uvs_materials_and_animation_survive(self):
        source, binary = fixture()
        snapshot = deepcopy(source)
        result, merged = batch_rigid_meshes(source, binary)
        self.assertEqual(source, snapshot, "Batching must not mutate its input document")
        self.assertEqual(result["materials"], source["materials"])
        self.assertEqual(len(result["nodes"]), 3)
        self.assertEqual(len(result["meshes"]), 2)
        self.assertEqual(result["nodes"][0], {"name": "Body", "children": [1, 2]})
        self.assertEqual(result["nodes"][2]["name"], "Animated")
        target = result["animations"][0]["channels"][0]["target"]
        self.assertEqual(target, {"node": 2, "path": "translation"})
        self.assertEqual(animation_bytes(result, merged), animation_bytes(source, binary))
        primitive = result["meshes"][result["nodes"][1]["mesh"]]["primitives"][0]
        self.assertEqual(primitive["material"], 0)
        points = read_accessor(result, merged, primitive["attributes"]["POSITION"])
        expected = [(1, 2, 3), (1, 4, 3), (-2, 2, 3), (-2, 0, 0), (-1, 0, 0), (-2, 1, 0)]
        for actual, wanted in zip(points, expected):
            for left, right in zip(actual, wanted):
                self.assertAlmostEqual(left, right, places=6)
        normals = read_accessor(result, merged, primitive["attributes"]["NORMAL"])
        expected_normal = (-2 / math.sqrt(13), 3 / math.sqrt(13), 0)
        for actual in normals[:3]:
            for left, right in zip(actual, expected_normal):
                self.assertAlmostEqual(left, right, places=6)
        for actual in normals[3:]:
            self.assertAlmostEqual(actual[0], math.sqrt(0.5), places=6)
            self.assertAlmostEqual(actual[1], math.sqrt(0.5), places=6)
        self.assertEqual(read_accessor(result, merged, primitive["attributes"]["TEXCOORD_0"]),
                         [(0, 0), (1, 0), (0, 1)] * 2)
        self.assertEqual(read_accessor(result, merged, primitive["indices"]), [(value,) for value in range(6)])
        self.assertEqual(result["buffers"][0]["byteLength"], len(merged))
        referenced_views = {accessor["bufferView"] for accessor in result["accessors"]}
        self.assertEqual(referenced_views, set(range(len(result["bufferViews"]))))
        second, second_binary = batch_rigid_meshes(result, merged)
        self.assertEqual(second, result)
        self.assertEqual(second_binary, merged)

    def test_material_and_attribute_boundaries_remain_separate_surfaces(self):
        source, binary = fixture()
        second = deepcopy(source["meshes"][0])
        second["primitives"][0]["material"] = 1
        source["meshes"].append(second)
        source["nodes"][2]["mesh"] = 2
        result, _ = batch_rigid_meshes(source, binary)
        merged = result["meshes"][result["nodes"][1]["mesh"]]
        self.assertEqual([item["material"] for item in merged["primitives"]], [0, 1])
        second["primitives"][0]["material"] = 0
        del second["primitives"][0]["attributes"]["TEXCOORD_0"]
        result, _ = batch_rigid_meshes(source, binary)
        merged = result["meshes"][result["nodes"][1]["mesh"]]
        self.assertEqual(len(merged["primitives"]), 2)

    def test_unknown_node_references_and_unsupported_documents_are_untouched(self):
        mutations = [
            lambda d: d.update(skins=[{"joints": [1]}]),
            lambda d: d.update(extensionsUsed=["UNKNOWN_node_reference"]),
            lambda d: d["materials"][0].update(extensions={"UNKNOWN": {"node": 1}}),
            lambda d: d["nodes"][1].update(skin=0),
            lambda d: d["nodes"][1].update(matrix=[1] * 16),
            lambda d: d["nodes"][1].update(scale=[-1, 1, 1]),
            lambda d: d["accessors"][0].update(sparse={"count": 1}),
            lambda d: d["accessors"][0].pop("bufferView"),
        ]
        for mutate in mutations:
            with self.subTest(mutation=mutate):
                source, binary = fixture()
                mutate(source)
                result, result_binary = batch_rigid_meshes(source, binary)
                self.assertIs(result, source)
                self.assertIs(result_binary, binary)

    def test_animated_nonleaf_morph_transparent_and_unknown_attributes_are_not_batched(self):
        mutations = [
            lambda d: d["animations"][0]["channels"].append({"sampler": 0, "target": {"node": 1, "path": "translation"}}),
            lambda d: d["nodes"][1].update(children=[3]),
            lambda d: d["meshes"][0]["primitives"][0].update(targets=[{"POSITION": 0}]),
            lambda d: d["materials"][0].update(alphaMode="BLEND"),
            lambda d: d["meshes"][0]["primitives"][0]["attributes"].update(TANGENT=1),
        ]
        for index, mutate in enumerate(mutations):
            with self.subTest(index=index):
                source, binary = fixture()
                if index == 1:
                    source["nodes"][0]["children"].remove(3)
                mutate(source)
                result, result_binary = batch_rigid_meshes(source, binary)
                self.assertEqual(result, source)
                self.assertEqual(result_binary, binary)


class ModelOnlyMetadataTests(unittest.TestCase):
    def setUp(self):
        self.settings = {"render_density": 8, "world_points_per_unit": 32,
                         "canvas": [128, 160], "anchor": [64, 128]}
        self.metadata = {"source": "art/blender/sources/soldier.blend", "source_sha256": "source",
                         "settings_sha256": "old sprite settings", "profile": "iron_ink_mounted", "render_density": 8,
                         "world_points_per_unit": 32, "blender_xy_basis_pixels": [[-256, 128], [256, 128]],
                         "logical_xy_from_blender": ["32 * Y", "32 * X"], "canvas": [640, 800], "anchor": [320, 640],
                         "logical_canvas": [80, 100], "logical_anchor": [40, 80],
                         "uncropped_canvas": [1024, 1280], "uncropped_anchor": [512, 1024],
                         "model": {"sha256": "old model"}, "animation": {"frames": [1, 2]}}

    def validate(self, source_hash="source"):
        validate_model_only_metadata(self.metadata, "art/blender/sources/soldier.blend", source_hash,
                                     self.settings, "iron_ink_mounted")

    def test_matching_source_and_projection_allow_independent_model_provenance(self):
        self.validate()
        model = {"sha256": "new model", "source_sha256": "source", "settings_sha256": "current model settings"}
        original = deepcopy(self.metadata)
        result = replace_model_metadata(self.metadata, model)
        self.assertEqual(self.metadata, original)
        self.assertEqual(result["model"], model)
        self.assertEqual({key: value for key, value in result.items() if key != "model"},
                         {key: value for key, value in original.items() if key != "model"})

    def test_source_edit_refuses_model_only_export(self):
        with self.assertRaisesRegex(ValueError, "full art-render"):
            self.validate("edited source")

    def test_projection_density_profile_and_crop_mismatches_refuse_export(self):
        for field, value in (("canvas", [160, 160]), ("anchor", [65, 128]),
                             ("render_density", 4), ("world_points_per_unit", 16)):
            with self.subTest(field=field):
                original = deepcopy(self.settings)
                self.settings[field] = value
                with self.assertRaisesRegex(ValueError, "full art-render"):
                    self.validate()
                self.settings = original
        for field in ("profile", "logical_canvas", "logical_anchor", "blender_xy_basis_pixels"):
            with self.subTest(field=field):
                original = deepcopy(self.metadata)
                self.metadata[field] = "incompatible"
                with self.assertRaisesRegex(ValueError, "full art-render"):
                    self.validate()
                self.metadata = original


if __name__ == "__main__":
    unittest.main()
