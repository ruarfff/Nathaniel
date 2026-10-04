"""Create editable, periodic ground materials and broad path transition masks."""

import json
import math
from pathlib import Path
import random

import bpy


def math_node(nodes, links, operation, left, right=None):
    node = nodes.new("ShaderNodeMath")
    node.operation = operation
    for index, value in enumerate((left, right)):
        if value is None:
            continue
        if isinstance(value, (int, float)):
            node.inputs[index].default_value = value
        else:
            links.new(value, node.inputs[index])
    return node.outputs[0]


def ground_material(name, low, high, paving=False, asphalt=False):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    material.diffuse_color = (*high, 1)
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value = 0.94
    uv = nodes.new("ShaderNodeTexCoord")
    separate = nodes.new("ShaderNodeSeparateXYZ")
    links.new(uv.outputs["UV"], separate.inputs[0])
    angles = [math_node(nodes, links, "MULTIPLY", separate.outputs[axis], math.tau) for axis in ("X", "Y")]
    # A torus makes the material repeat continuously at all four tile edges.
    vector = nodes.new("ShaderNodeCombineXYZ")
    for index, value in enumerate((math_node(nodes, links, "COSINE", angles[0]),
                                   math_node(nodes, links, "SINE", angles[0]),
                                   math_node(nodes, links, "COSINE", angles[1]))):
        links.new(value, vector.inputs[index])
    noise = nodes.new("ShaderNodeTexNoise")
    noise.noise_dimensions = "4D"
    links.new(vector.outputs[0], noise.inputs["Vector"])
    links.new(math_node(nodes, links, "SINE", angles[1]), noise.inputs["W"])
    noise.inputs["Scale"].default_value = 3.2
    noise.inputs["Detail"].default_value = 2
    noise.inputs["Roughness"].default_value = 0.7
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.25
    ramp.color_ramp.elements[0].color = (*low, 1)
    ramp.color_ramp.elements[1].position = 0.75
    ramp.color_ramp.elements[1].color = (*high, 1)
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    color = ramp.outputs["Color"]
    if paving or asphalt:
        cracks = nodes.new("ShaderNodeTexVoronoi")
        cracks.voronoi_dimensions = "4D"
        cracks.feature = "DISTANCE_TO_EDGE"
        links.new(vector.outputs[0], cracks.inputs["Vector"])
        links.new(math_node(nodes, links, "SINE", angles[1]), cracks.inputs["W"])
        cracks.inputs["Scale"].default_value = 0.8 if paving else 1.7
        edge = math_node(nodes, links, "LESS_THAN", cracks.outputs["Distance"], 0.012)
        mix = nodes.new("ShaderNodeMixRGB")
        links.new(edge, mix.inputs[0])
        links.new(color, mix.inputs[1])
        mix.inputs[2].default_value = (0.07, 0.065, 0.05, 1) if paving else (0.10, 0.088, 0.065, 1)
        color = mix.outputs[0]
    links.new(color, shader.inputs["Base Color"])
    return material


def path_material(base, name, coverage):
    material = base.copy()
    material.name = name
    nodes, links = material.node_tree.nodes, material.node_tree.links
    image = bpy.data.images.new(name + " | authored path shape", width=4, height=4, alpha=False, float_buffer=False)
    image.colorspace_settings.name = "Non-Color"
    values = []
    for digit in coverage:
        value = int(digit, 16) / 15
        values.extend((value, value, value, 1))
    image.pixels = values
    image.pack()
    mask = nodes.new("ShaderNodeTexImage")
    mask.name = "Editable path coverage"
    mask.image = image
    mask.interpolation = "Cubic"
    mask.extension = "EXTEND"
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.20
    ramp.color_ramp.elements[1].position = 0.62
    links.new(mask.outputs["Color"], ramp.inputs[0])
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(ramp.outputs[0], mix.inputs[0])
    links.new(transparent.outputs[0], mix.inputs[1])
    links.new(nodes.get("Principled BSDF").outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], nodes.get("Material Output").inputs[0])
    return material


def plane(collection, material):
    mesh = bpy.data.meshes.new(collection.name + " surface")
    half = 0.55
    vertices = [(-half, -half, 0), (half, -half, 0), (half, half, 0), (-half, half, 0)]
    mesh.from_pydata(vertices, [], [(0, 1, 2, 3)])
    mesh.update()
    uv = mesh.uv_layers.new(name="Logical XY")
    for polygon in mesh.polygons:
        for loop in polygon.loop_indices:
            x, y, _ = vertices[mesh.loops[loop].vertex_index]
            uv.data[loop].uv = (y + 0.5, x + 0.5)
    obj = bpy.data.objects.new(collection.name + " | ground", mesh)
    collection.objects.link(obj)
    mesh.materials.append(material)


def detail(collection, variant, material):
    rng = random.Random(1701 + variant)
    for index in range(3):
        x, y = rng.uniform(-0.32, 0.32), rng.uniform(-0.32, 0.32)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=(x, y, 0.008))
        obj = bpy.context.object
        obj.name = f"{collection.name} | low pebble {index}"
        obj.scale = (rng.uniform(0.025, 0.045), rng.uniform(0.018, 0.035), 0.013)
        obj.data.materials.append(material)
        for owner in list(obj.users_collection):
            owner.objects.unlink(obj)
        collection.objects.link(obj)


def build():
    root = Path(__file__).resolve().parents[2]
    layout = json.loads((root / "art/blender/environment_layout.json").read_text())
    palette = {
        "scrub": ground_material("Dry olive earth", (0.21, 0.20, 0.12), (0.285, 0.275, 0.17)),
        "sand": ground_material("Sun bleached sand", (0.34, 0.265, 0.175), (0.44, 0.355, 0.235)),
        "gravel": ground_material("Quiet grey gravel", (0.205, 0.205, 0.18), (0.29, 0.285, 0.25)),
        "paving": ground_material("Cracked concrete paving", (0.34, 0.325, 0.265), (0.44, 0.42, 0.34), paving=True),
        "asphalt": ground_material("Sand worn asphalt", (0.09, 0.095, 0.09), (0.145, 0.15, 0.135), asphalt=True),
    }
    entries = []

    def add(name, material, variant=0, empty=False, **metadata):
        collection = bpy.data.collections.new("Tile | " + name)
        bpy.context.scene.collection.children.link(collection)
        if not empty:
            plane(collection, material)
            if variant:
                detail(collection, variant, palette["gravel"])
        entries.append(dict(name=name, collection=collection.name, empty=empty, **metadata))

    add("scrub", palette["scrub"])
    add("sand", palette["sand"])
    for name in ("scrub", "sand"):
        for variant in range(1, 4):
            add(f"{name}_{variant}", palette[name], variant)
    for name in ("gravel", "paving", "asphalt"):
        add(name, palette[name])
    add("empty", None, empty=True)
    for coordinate, coverage in layout["ground"]["path_coverage_4x4"].items():
        x, y = coordinate.split(",")
        name = f"path_{x}_{y}"
        empty = max(int(value, 16) for value in coverage) <= 1
        add(name, None if empty else path_material(palette["sand"], name, coverage),
            empty=empty, old_atlas_coordinate=[int(x), int(y)], coverage=coverage)
    bpy.context.scene["asset_terrain"] = json.dumps({"tiles": entries})
    bpy.context.scene["asset_profile"] = "iron_ink_terrain"
    bpy.context.scene["terrain_overlap_revision"] = 1
    bpy.context.scene["concept_reference"] = "concept-art/iron-and-ink/01-scene.png; 09-sandy-street.png"
    bpy.context.scene["authoring_note"] = "One collection per tile; edit materials or packed coverage images. Export hides other collections in memory only."
    for collection in bpy.data.collections:
        if collection.name.startswith("Tile | "):
            collection.hide_render = collection.name != "Tile | scrub"
            collection.hide_viewport = collection.name != "Tile | scrub"
