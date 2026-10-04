"""Editable tower meshes based on concept-art/iron-and-ink/03-human-structures.png."""

import math

import bpy
from mathutils import Vector


def _material(name, color, emission=0):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1)
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = material.diffuse_color
    shader.inputs["Roughness"].default_value = 0.78
    shader.inputs["Metallic"].default_value = 0.12
    if emission:
        shader.inputs["Emission Color"].default_value = material.diffuse_color
        shader.inputs["Emission Strength"].default_value = emission
    return material


def _palette():
    return {
        "ink": _material("Iron Ink | dark joints", (0.012, 0.018, 0.022)),
        "blue": _material("Iron Ink | petrol armour", (0.08, 0.145, 0.18)),
        "blue_light": _material("Iron Ink | top armour", (0.095, 0.160, 0.185)),
        "ochre": _material("Iron Ink | ochre", (0.56, 0.305, 0.055)),
        "steel": _material("Iron Ink | worn steel", (0.27, 0.305, 0.295)),
        "bore": _material("Iron Ink | bore", (0.003, 0.004, 0.005)),
        "amber": _material("Iron Ink | amber emitter", (1, 0.43, 0.035), 1.5),
        "cyan": _material("Iron Ink | healing strip", (0.22, 0.7, 0.63), 0.65),
    }


def _collection(name):
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
    return collection


def _finish(obj, name, collection, material, edge=None, bevel=0.012):
    obj.name = name
    for owner in list(obj.users_collection):
        owner.objects.unlink(obj)
    collection.objects.link(obj)
    obj.data.materials.append(material)
    if edge:
        obj.data.materials.append(edge)
    if bevel:
        modifier = obj.modifiers.new("Broad machined edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 1
        modifier.affect = "EDGES"
        modifier.material = 1 if edge else 0
    return obj


def _box(name, location, size, collection, material, edge=None, bevel=0.012, yaw=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler.z = yaw
    return _finish(obj, name, collection, material, edge, bevel)


def _taper(name, location, bottom, top, height, collection, material, edge=None):
    vertices = [
        (x * size / 2, y * size / 2, z)
        for size, z in ((bottom, -height / 2), (top, height / 2))
        for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))
    ]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7)]
    faces += [(i, (i + 1) % 4, (i + 1) % 4 + 4, i + 4) for i in range(4)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    obj.location = location
    return _finish(obj, name, collection, material, edge, 0.022)


def _beam(name, start, end, width, depth, collection, material, edge=None):
    start, end = Vector(start), Vector(end)
    obj = _box(name, (start + end) / 2, (width, depth, (end - start).length),
               collection, material, edge)
    obj.rotation_euler = (end - start).to_track_quat("Z", "Y").to_euler()
    return obj


def _base(collection, p):
    _box("Ground plinth", (0, 0, 0.105), (0.79, 0.79, 0.14),
         collection, p["ink"], p["steel"], 0.018)
    _taper("Pedestal dark seams", (0, 0, 0.385), 0.77, 0.65, 0.44,
           collection, p["ink"])
    _taper("Tapered petrol armour", (0, 0, 0.39), 0.78, 0.66, 0.405,
           collection, p["blue"], p["blue_light"])
    _box("Top rim", (0, 0, 0.61), (0.62, 0.62, 0.055),
         collection, p["blue_light"], p["steel"], 0.015)
    for x in (-1, 1):
        for y in (-1, 1):
            corner = f"{x:+d} {y:+d}"
            _beam(f"Corner ochre rail {corner}", (x * 0.365, y * 0.365, 0.20),
                  (x * 0.305, y * 0.305, 0.59), 0.085, 0.085,
                  collection, p["ochre"], p["ochre"])
            yaw = math.atan2(y, x)
            _box(f"Foot sole {corner}", (x * 0.385, y * 0.385, 0.032),
                 (0.245, 0.205, 0.064), collection, p["ink"], p["steel"],
                 0.014, yaw)
            _beam(f"Folding leg {corner}", (x * 0.32, y * 0.32, 0.19),
                  (x * 0.415, y * 0.415, 0.08), 0.16, 0.17,
                  collection, p["ochre"], p["blue_light"])
            _box(f"Foot toe {corner}", (x * 0.44, y * 0.44, 0.067),
                 (0.075, 0.14, 0.065), collection, p["blue"], p["steel"],
                 0.007, yaw)
    _box("Pedestal front service panel", (0.365, 0.055, 0.39),
         (0.018, 0.20, 0.18), collection, p["ink"], bevel=0.008)
    _box("Pedestal service panel face", (0.378, 0.055, 0.39),
         (0.016, 0.165, 0.145), collection, p["blue_light"], bevel=0.005)
    _box("Yaw bearing lower", (0, 0, 0.67), (0.40, 0.40, 0.08),
         collection, p["ink"], p["steel"], 0.025)
    _paint_wear(collection, p)


def _paint_wear(collection, p):
    patches = (
        ("X lower", False, [(-0.22, 0.25), (-0.18, 0.295), (-0.16, 0.285),
                            (-0.155, 0.263), (-0.13, 0.245), (-0.18, 0.25)]),
        ("Y lower", True, [(0.16, 0.24), (0.18, 0.30), (0.19, 0.295),
                           (0.195, 0.255), (0.22, 0.235)]),
        ("Y upper", True, [(-0.20, 0.51), (-0.14, 0.525), (-0.15, 0.51),
                           (-0.185, 0.495)]),
    )
    for name, swap, points in patches:
        vertices = []
        for tangent, z in points:
            outward = 0.39 - (z - 0.1875) * (0.06 / 0.405) + 0.0015
            vertices.append((tangent, outward, z) if swap else (outward, tangent, z))
        mesh = bpy.data.meshes.new(f"Broad paint wear | {name}")
        mesh.from_pydata(vertices, [], [tuple(range(len(vertices)))])
        mesh.update()
        obj = bpy.data.objects.new(mesh.name, mesh)
        collection.objects.link(obj)
        _finish(obj, mesh.name, collection, p["blue_light"], bevel=0)


def _muzzle(collection, p):
    # The bore is open mesh with a recessed back, not a painted black end cap.
    count = 8
    vertices = []
    for x, radius in ((0.43, 0.12), (0.96, 0.12), (0.96, 0.076), (0.73, 0.076)):
        vertices += [(x, math.cos(math.tau * i / count + math.pi / 8) * radius,
                      1.09 + math.sin(math.tau * i / count + math.pi / 8) * radius)
                     for i in range(count)]
    faces = []
    for ring in range(3):
        for i in range(count):
            a, b = ring * count + i, ring * count + (i + 1) % count
            faces.append((a, b, b + count, a + count))
    faces.append(tuple(range(3 * count, 4 * count)))
    mesh = bpy.data.meshes.new("Hollow octagonal cannon")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("Hollow octagonal cannon", mesh)
    collection.objects.link(obj)
    for material in (p["steel"], p["ink"], p["bore"]):
        mesh.materials.append(material)
    for face in mesh.polygons:
        face.material_index = 0 if face.index < 16 else 2
    _box("Barrel jacket", (0.42, 0, 1.09), (0.22, 0.275, 0.265),
         collection, p["blue"], p["ink"], 0.04)
    for x in (0.64, 0.82):
        _box(f"Barrel top band {x}", (x, 0, 1.206), (0.035, 0.13, 0.015),
             collection, p["ink"], bevel=0.003)


def _gun(collection, p):
    _box("Gun yaw bearing", (0, 0, 0.765), (0.34, 0.34, 0.11),
         collection, p["ink"], p["steel"], 0.02)
    _box("Gun breech underbody", (0, 0, 1.025), (0.48, 0.47, 0.38),
         collection, p["ink"], bevel=0.045)
    _box("Gun breech armour", (-0.015, 0, 1.055), (0.49, 0.49, 0.34),
         collection, p["blue"], p["blue_light"], 0.035)
    for y in (-0.238, 0.238):
        _box(f"Gun cheek plate {y}", (0.075, y, 1.05), (0.14, 0.055, 0.34),
             collection, p["ochre"], p["steel"], 0.018)
        _box(f"Gun cheek inset {y}", (-0.07, y * 1.04, 1.045),
             (0.12, 0.022, 0.15), collection, p["blue_light"], p["ink"], 0.012)
    _box("Breech top cover", (-0.045, 0, 1.25), (0.25, 0.29, 0.045),
         collection, p["blue_light"], p["ink"], 0.012)
    _muzzle(collection, p)


def _laser(collection, p):
    _box("Laser yaw bearing", (0, 0, 0.765), (0.34, 0.34, 0.11),
         collection, p["ink"], p["steel"], 0.02)
    _box("Laser rear bridge", (-0.24, 0, 1.075), (0.19, 0.68, 0.36),
         collection, p["blue"], p["ink"], 0.025)
    for y in (-0.235, 0.235):
        _box(f"Emitter rail seam {y}", (0.11, y, 1.10), (0.78, 0.24, 0.37),
             collection, p["ink"], bevel=0.026)
        _box(f"Emitter rail armour {y}", (0.10, y, 1.115), (0.78, 0.26, 0.335),
             collection, p["blue"], p["blue_light"], 0.018)
        _box(f"Emitter ochre nose {y}", (0.445, y, 1.12), (0.14, 0.28, 0.365),
             collection, p["ochre"], p["steel"], 0.012)
        _box(f"Emitter top stripe {y}", (0.05, y, 1.287), (0.48, 0.055, 0.014),
             collection, p["ochre"], bevel=0.002)
        _box(f"Emitter nose insert {y}", (0.525, y, 1.1), (0.018, 0.115, 0.19),
             collection, p["ink"], bevel=0.007)
    _box("Amber chamber surround", (0.405, 0, 1.06), (0.29, 0.16, 0.23),
         collection, p["ink"], p["steel"], 0.022)
    _box("Amber chamber window", (0.556, 0, 1.06), (0.022, 0.108, 0.154),
         collection, p["amber"], bevel=0.01)


def _healing_panel(name, position, width, yaw, collection, p):
    normal = Vector((math.cos(yaw), math.sin(yaw), 0))
    tangent = Vector((-math.sin(yaw), math.cos(yaw), 0))
    center = Vector(position)
    _box(f"{name} dark rim", center, (0.09, width, 0.39),
         collection, p["ink"], p["steel"], 0.013, yaw)
    _box(f"{name} ochre face", center + normal * 0.051,
         (0.032, width - 0.055, 0.342), collection, p["ochre"],
         p["ochre"], 0.01, yaw)
    inset = center + normal * 0.073 + tangent * (width * 0.22)
    _box(f"{name} strip socket", inset, (0.024, 0.062, 0.255),
         collection, p["ink"], bevel=0.006, yaw=yaw)
    _box(f"{name} cyan strip", inset + normal * 0.014, (0.014, 0.024, 0.217),
         collection, p["cyan"], bevel=0.003, yaw=yaw)


def _heal(collection, p):
    _box("Healing mast foot", (0, 0, 0.755), (0.34, 0.34, 0.11),
         collection, p["ink"], p["steel"], 0.025)
    _box("Healing mast", (0, 0, 1.045), (0.20, 0.20, 0.49),
         collection, p["blue"], p["steel"], 0.018)
    _box("Healing mast crown", (0, 0, 1.34), (0.24, 0.24, 0.10),
         collection, p["ochre"], p["ink"], 0.018)
    for sign in (-1, 1):
        center = (sign * 0.245 - 0.04, -sign * 0.245 - 0.04, 1.265)
        _beam(f"Healing wing arm {sign}", (0, 0, 1.10), center, 0.10, 0.10,
              collection, p["ink"], p["steel"])
        _healing_panel(f"Healing wing {sign}", center, 0.43,
                       math.pi / 4 + sign * 0.28, collection, p)
    _healing_panel("Healing front panel", (0.105, 0.105, 1.025), 0.155,
                   math.pi / 4, collection, p)


def build_tower(kind):
    """Build once; subsequent exports render the saved, possibly edited source."""
    p = _palette()
    base = _collection("Base | shared folding pedestal")
    turret = _collection(f"Turret | {kind}")
    _base(base, p)
    {"gun": _gun, "laser": _laser, "heal": _heal}[kind](turret, p)
    pivot = bpy.data.objects.new("Turret pivot | future animation", None)
    turret.objects.link(pivot)
    pivot.location = (0, 0, 0.71)
    pivot.empty_display_type = "PLAIN_AXES"
    pivot.empty_display_size = 0.15
    bpy.context.view_layer.update()
    for obj in list(turret.objects):
        if obj != pivot:
            obj.parent = pivot
            obj.matrix_parent_inverse = pivot.matrix_world.inverted()
    bpy.context.scene["art_direction"] = "Iron & Ink"
    bpy.context.scene["armour_layer_revision"] = 1
    if kind == "laser":
        bpy.context.scene["laser_window_revision"] = 1
    bpy.context.scene["concept_reference"] = "concept-art/iron-and-ink/03-human-structures.png"
    bpy.context.scene["ground_anchor"] = "World origin; Blender XY ground, Z height"
