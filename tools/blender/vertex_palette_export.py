"""Fold compatible opaque paint into spec-linear vertex colors at export time."""

from copy import deepcopy
import json
import math
import struct

try:
    from .rigid_mesh_export import _compact, _eligible, _write_accessor, read_accessor, supported_document
except ImportError:
    from rigid_mesh_export import _compact, _eligible, _write_accessor, read_accessor, supported_document


PALETTE_KEY = "rigid_vertex_palette"


def packed_color_key(color):
    # stable_glb rounds float accessors before Godot truncates them to RGBA8.
    written = struct.unpack("<4f", struct.pack("<4f", *color))
    values = struct.unpack("<4f", struct.pack("<4f", *(round(value, 6) for value in written)))
    return ",".join(str(int(value * 255)) for value in values)


def _paint(material):
    if set(material) - {"name", "doubleSided", "alphaMode", "pbrMetallicRoughness"}:
        return None
    if material.get("alphaMode", "OPAQUE") != "OPAQUE":
        return None
    pbr = material.get("pbrMetallicRoughness", {})
    if set(pbr) - {"baseColorFactor", "metallicFactor", "roughnessFactor"}:
        return None
    color = pbr.get("baseColorFactor", [1, 1, 1, 1])
    if len(color) != 4 or color[3] != 1 or any(not math.isfinite(value) or not 0 <= value <= 1 for value in color):
        return None
    shared = deepcopy(material)
    shared["name"] = "Rigid vertex palette"
    shared.setdefault("pbrMetallicRoughness", {})["baseColorFactor"] = [1, 1, 1, 1]
    return json.dumps(shared, sort_keys=True), shared, color


def fold_vertex_palette(document, binary):
    """Keep unknown geometry and materials untouched; reject ambiguous palettes."""
    if not supported_document(document):
        return document, binary
    paints = {index: paint for index, material in enumerate(document.get("materials", []))
              if (paint := _paint(material)) is not None}
    palette = {}
    for _, _, color in paints.values():
        key = packed_color_key(color)
        if key in palette and palette[key] != color:
            return document, binary
        palette[key] = color
    animated = {id(document["nodes"][channel["target"]["node"]]) for animation in document.get("animations", [])
                for channel in animation["channels"]}
    eligible = [index for index, node in enumerate(document["nodes"]) if _eligible(document, node, animated)
                and any(p.get("material") in paints for p in document["meshes"][node["mesh"]]["primitives"])]
    if not eligible:
        return document, binary
    result, output = deepcopy(document), bytearray(binary)
    shared_materials = {}
    converted_meshes = {}
    for index in eligible:
        node = result["nodes"][index]
        original_mesh = node["mesh"]
        if original_mesh in converted_meshes:
            node["mesh"] = converted_meshes[original_mesh]
            node["extras"] = {PALETTE_KEY: palette}
            continue
        mesh = result["meshes"][original_mesh]
        retained, groups = [], {}
        for primitive in mesh["primitives"]:
            paint = paints.get(primitive.get("material"))
            if paint is None:
                retained.append(deepcopy(primitive))
                continue
            signature, shared, color = paint
            if signature not in shared_materials:
                shared_materials[signature] = len(result["materials"])
                result["materials"].append(shared)
            attributes, indices = groups.setdefault(signature, ({name: [] for name in ("POSITION", "NORMAL", "TEXCOORD_0", "COLOR_0")}, []))
            start = len(attributes["POSITION"])
            count = result["accessors"][primitive["attributes"]["POSITION"]]["count"]
            for name in ("POSITION", "NORMAL", "TEXCOORD_0"):
                values = (read_accessor(result, output, primitive["attributes"][name])
                          if name in primitive["attributes"] else [(0, 0)] * count)
                if len(values) != count:
                    raise ValueError("Palette geometry has mismatched vertex attributes.")
                attributes[name].extend(values)
            attributes["COLOR_0"].extend([color] * count)
            source_indices = read_accessor(result, output, primitive["indices"])
            if any(value[0] >= count for value in source_indices):
                raise ValueError("Palette geometry has an out-of-range triangle index.")
            indices.extend((value[0] + start,) for value in source_indices)
        for signature, (attributes, indices) in groups.items():
            kinds = {"POSITION": "VEC3", "NORMAL": "VEC3", "TEXCOORD_0": "VEC2", "COLOR_0": "VEC4"}
            retained.append({"material": shared_materials[signature],
                             "attributes": {name: _write_accessor(result, output, values, kinds[name]) for name, values in attributes.items()},
                             "indices": _write_accessor(result, output, indices, "SCALAR", 5123 if max(value[0] for value in indices) < 65535 else 5125)})
        node["mesh"] = len(result["meshes"])
        converted_meshes[original_mesh] = node["mesh"]
        result["meshes"].append({**mesh, "primitives": retained})
        node["extras"] = {PALETTE_KEY: palette}
    return _compact(result, output)
