"""A one-cell prop. Replace or copy this generator when creating new source art."""

import bpy


def build():
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.5))
    prop = bpy.context.object
    prop.name = "PlaceholderProp"
    material = bpy.data.materials.new("Placeholder clay")
    material.diffuse_color = (0.55, 0.32, 0.16, 1)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = material.diffuse_color
    shader.inputs["Roughness"].default_value = 0.8
    prop.data.materials.append(material)
