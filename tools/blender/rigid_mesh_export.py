"""Batch rigid GLB leaf geometry without changing controls or triangle streams."""

from collections import defaultdict
from copy import deepcopy
import math
import struct


COMPONENTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
FORMATS = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}
ATTRIBUTES = {"POSITION": "VEC3", "NORMAL": "VEC3", "TEXCOORD_0": "VEC2"}


def read_accessor(document, binary, index):
    accessor = document["accessors"][index]
    view = document["bufferViews"][accessor["bufferView"]]
    count = COMPONENTS[accessor["type"]]
    fmt = "<" + FORMATS[accessor["componentType"]] * count
    size = struct.calcsize(fmt)
    stride = view.get("byteStride", size)
    offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    return [struct.unpack_from(fmt, binary, offset + row * stride) for row in range(accessor["count"])]


def _write_accessor(document, binary, values, kind, component_type=5126):
    binary.extend(b"\0" * (-len(binary) % 4))
    offset = len(binary)
    fmt = "<" + FORMATS[component_type] * COMPONENTS[kind]
    for value in values:
        binary.extend(struct.pack(fmt, *value))
    document["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(binary) - offset})
    accessor = {"bufferView": len(document["bufferViews"]) - 1, "componentType": component_type,
                "count": len(values), "type": kind}
    if kind == "VEC3":
        accessor["min"] = [min(value[axis] for value in values) for axis in range(3)]
        accessor["max"] = [max(value[axis] for value in values) for axis in range(3)]
    document["accessors"].append(accessor)
    return len(document["accessors"]) - 1


def _has_extensions(value):
    if isinstance(value, dict):
        return bool(value.get("extensions")) or any(_has_extensions(item) for item in value.values())
    return isinstance(value, list) and any(_has_extensions(item) for item in value)


def _rotation(node):
    x, y, z, w = node.get("rotation", (0, 0, 0, 1))
    return ((1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)),
            (2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)),
            (2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)))


def _transform(node, value, normal=False):
    scale = node.get("scale", (1, 1, 1))
    vector = [value[axis] / scale[axis] if normal else value[axis] * scale[axis] for axis in range(3)]
    result = [sum(component * vector[axis] for axis, component in enumerate(row)) for row in _rotation(node)]
    if normal:
        length = math.sqrt(sum(component * component for component in result))
        if length <= 0.0:
            raise ValueError("Rigid geometry has a zero normal.")
        return tuple(component / length for component in result)
    return tuple(result[axis] + node.get("translation", (0, 0, 0))[axis] for axis in range(3))


def _eligible(document, node, animated):
    if node.get("children") or "mesh" not in node or id(node) in animated:
        return False
    if set(node) - {"name", "mesh", "translation", "rotation", "scale"}:
        return False
    if any(component <= 0 for component in node.get("scale", (1, 1, 1))):
        return False
    mesh = document["meshes"][node["mesh"]]
    if set(mesh) - {"name", "primitives"}:
        return False
    for primitive in mesh["primitives"]:
        if set(primitive) - {"attributes", "indices", "material", "mode"} or primitive.get("mode", 4) != 4:
            return False
        if "material" in primitive and document.get("materials", [])[primitive["material"]].get("alphaMode", "OPAQUE") == "BLEND":
            return False
        attributes = primitive["attributes"]
        if not {"POSITION", "NORMAL"} <= attributes.keys() or attributes.keys() - ATTRIBUTES.keys():
            return False
        for name, index in attributes.items():
            accessor = document["accessors"][index]
            if accessor["type"] != ATTRIBUTES[name] or accessor["componentType"] != 5126 or accessor.get("normalized", False):
                return False
        if "indices" not in primitive:
            return False
        indices = document["accessors"][primitive["indices"]]
        if indices["type"] != "SCALAR" or indices["componentType"] not in {5121, 5123, 5125} or indices["count"] % 3:
            return False
    return bool(mesh["primitives"])


def _compact(document, binary):
    """Discard replaced geometry, while copying animation accessor bytes verbatim."""
    used_meshes = sorted({node["mesh"] for node in document["nodes"] if "mesh" in node})
    mesh_ids = {old: new for new, old in enumerate(used_meshes)}
    document["meshes"] = [document["meshes"][index] for index in used_meshes]
    for node in document["nodes"]:
        if "mesh" in node:
            node["mesh"] = mesh_ids[node["mesh"]]
    references = []
    for mesh in document["meshes"]:
        for primitive in mesh["primitives"]:
            references.extend((primitive["attributes"], name) for name in primitive["attributes"])
            if "indices" in primitive:
                references.append((primitive, "indices"))
            for target in primitive.get("targets", []):
                references.extend((target, name) for name in target)
    for animation in document.get("animations", []):
        for sampler in animation["samplers"]:
            references.extend((sampler, field) for field in ("input", "output"))
    used_accessors = sorted({owner[field] for owner, field in references})
    accessor_ids = {old: new for new, old in enumerate(used_accessors)}
    document["accessors"] = [document["accessors"][index] for index in used_accessors]
    for owner, field in references:
        owner[field] = accessor_ids[owner[field]]
    view_references = [(accessor, "bufferView") for accessor in document["accessors"]]
    view_references.extend((image, "bufferView") for image in document.get("images", []) if "bufferView" in image)
    used_views = sorted({owner[field] for owner, field in view_references})
    view_ids = {old: new for new, old in enumerate(used_views)}
    compact = bytearray()
    views = []
    for index in used_views:
        view = document["bufferViews"][index].copy()
        compact.extend(b"\0" * (-len(compact) % 4))
        start = view.get("byteOffset", 0)
        view["byteOffset"] = len(compact)
        compact.extend(binary[start:start + view["byteLength"]])
        views.append(view)
    for owner, field in view_references:
        owner[field] = view_ids[owner[field]]
    document["bufferViews"] = views
    document["buffers"][0]["byteLength"] = len(compact)
    return document, compact


def supported_document(document):
    """Restrict processing to the self-contained rigid format written by Blender."""
    return not (document.get("skins") or document.get("extensionsUsed") or document.get("extensionsRequired")
            or _has_extensions(document) or len(document.get("buffers", [])) != 1
            or any("uri" in buffer for buffer in document.get("buffers", []))
            or any("sparse" in accessor or "bufferView" not in accessor for accessor in document.get("accessors", []))
            or any(view.get("buffer", 0) != 0 for view in document.get("bufferViews", []))
            or any("skin" in node or "matrix" in node or any(value <= 0 for value in node.get("scale", (1, 1, 1)))
                   for node in document["nodes"]))


def batch_rigid_meshes(document, binary):
    """Leave unsupported documents unchanged; never remap unknown node references."""
    if not supported_document(document):
        return document, binary
    result = deepcopy(document)
    output = bytearray(binary)
    nodes = result["nodes"]
    animated = {id(nodes[channel["target"]["node"]]) for animation in result.get("animations", [])
                for channel in animation["channels"]}
    groups = defaultdict(list)
    parents = {}
    for parent, node in enumerate(nodes):
        for child in node.get("children", []):
            if child in parents:
                raise ValueError("Rigid geometry requires a single parent per node.")
            parents[child] = parent
    for index, node in enumerate(nodes):
        if index in parents and _eligible(result, node, animated):
            groups[parents[index]].append(index)
    removed = set()
    for parent, children in groups.items():
        if len(children) < 2:
            continue
        surfaces = {}
        for index in children:
            node = nodes[index]
            for primitive in result["meshes"][node["mesh"]]["primitives"]:
                names = tuple(sorted(primitive["attributes"]))
                key = (primitive.get("material"), names)
                attributes, indices = surfaces.setdefault(key, ({name: [] for name in names}, []))
                start = len(attributes["POSITION"])
                count = result["accessors"][primitive["attributes"]["POSITION"]]["count"]
                for name in names:
                    values = read_accessor(result, output, primitive["attributes"][name])
                    if len(values) != count:
                        raise ValueError("Rigid geometry has mismatched vertex attributes.")
                    if name in {"POSITION", "NORMAL"}:
                        values = [_transform(node, value, name == "NORMAL") for value in values]
                    attributes[name].extend(values)
                source_indices = read_accessor(result, output, primitive["indices"])
                if any(value[0] >= count for value in source_indices):
                    raise ValueError("Rigid geometry has an out-of-range triangle index.")
                indices.extend((value[0] + start,) for value in source_indices)
        primitives = []
        for (material, names), (attributes, indices) in surfaces.items():
            primitive = {"attributes": {name: _write_accessor(result, output, attributes[name], ATTRIBUTES[name]) for name in names},
                         "indices": _write_accessor(result, output, indices, "SCALAR", 5123 if max(value[0] for value in indices) < 65535 else 5125)}
            if material is not None:
                primitive["material"] = material
            primitives.append(primitive)
        name = nodes[children[0]].get("name", "RigidGeometry")
        nodes[children[0]] = {"name": name, "mesh": len(result["meshes"])}
        result["meshes"].append({"name": name, "primitives": primitives})
        removed.update(children[1:])
    if not removed:
        return document, binary
    node_ids = {old: new for new, old in enumerate(index for index in range(len(nodes)) if index not in removed)}
    result["nodes"] = [node for index, node in enumerate(nodes) if index not in removed]
    for node in result["nodes"]:
        if "children" in node:
            node["children"] = [node_ids[index] for index in node["children"] if index not in removed]
    for scene in result.get("scenes", []):
        scene["nodes"] = [node_ids[index] for index in scene["nodes"] if index not in removed]
    for animation in result.get("animations", []):
        for channel in animation["channels"]:
            channel["target"]["node"] = node_ids[channel["target"]["node"]]
    return _compact(result, output)
