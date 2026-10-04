"""Sample saved rigid-node animation into standard glTF animation channels."""

import json
import struct

from model_export import glb_document, pack_glb


def animation_spec(scene):
    spec = json.loads(scene["model_clips"])
    if {clip["name"] for clip in spec["clips"]} != {"idle", "walk"}:
        raise ValueError("Live character requires authored idle and walk clips.")
    if not spec["controls"] or len(spec["controls"]) != len(set(spec["controls"])):
        raise ValueError("Live animation requires unique lower-body controls.")
    locomotion = scene.objects.get("LocomotionPivot")
    descendants = set(locomotion.children_recursive) if locomotion else set()
    for name in spec["controls"]:
        if scene.objects.get(name) not in descendants:
            raise ValueError(f"Live animation control {name} must be below LocomotionPivot; upper-body aim stays stable.")
    for clip in spec["clips"]:
        if not 1 <= clip["fps"] <= 60 or clip["start"] > clip["end"] or clip["end"] - clip["start"] > 240:
            raise ValueError("Live animation needs ordered frames and 1–60 samples per second.")
    return spec


def add_animations(data, scene):
    """Read authored poses; never change saved actions or create a second rig."""
    spec = animation_spec(scene)
    document = glb_document(data)
    json_length = struct.unpack_from("<I", data, 12)[0]
    binary = bytearray(data[28 + json_length:])
    node_ids = {node.get("name"): index for index, node in enumerate(document["nodes"])}

    def accessor(values, kind):
        count = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[kind]
        offset = len(binary)
        for value in values:
            binary.extend(struct.pack("<" + "f" * count, *value))
        view_id = len(document["bufferViews"])
        document["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(binary) - offset})
        record = {"bufferView": view_id, "componentType": 5126, "count": len(values), "type": kind}
        if kind == "SCALAR":
            record.update(min=[values[0][0]], max=[values[-1][0]])
        document["accessors"].append(record)
        return len(document["accessors"]) - 1

    animations = []
    for clip in spec["clips"]:
        frames = list(range(clip["start"], clip["end"] + 1))
        if len(frames) == 1:
            frames *= 2
        times = accessor([(index / clip["fps"],) for index in range(len(frames))], "SCALAR")
        transforms = {name: {"translation": [], "rotation": [], "scale": []} for name in spec["controls"]}
        for frame in frames:
            scene.frame_set(frame)
            for name, channels in transforms.items():
                position, rotation, scale = scene.objects[name].matrix_local.decompose()
                channels["translation"].append((position.x, position.z, -position.y))
                channels["rotation"].append((rotation.x, rotation.z, -rotation.y, rotation.w))
                channels["scale"].append((scale.x, scale.z, scale.y))
        animation = {"name": clip["name"], "samplers": [], "channels": []}
        for name, channels in transforms.items():
            if name not in node_ids:
                raise ValueError(f"GLB lost animation control {name}")
            for channel, values in channels.items():
                output = accessor(values, "VEC4" if channel == "rotation" else "VEC3")
                sampler_id = len(animation["samplers"])
                animation["samplers"].append({"input": times, "output": output, "interpolation": "LINEAR"})
                animation["channels"].append({"sampler": sampler_id, "target": {"node": node_ids[name], "path": channel}})
        animations.append(animation)
    document["animations"] = animations
    document["buffers"][0]["byteLength"] = len(binary)
    scene.frame_set(1)
    return pack_glb(document, binary)
