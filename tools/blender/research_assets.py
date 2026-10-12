"""Create the saved tech modules, auxiliary collector and folding research bench."""

import math

import bpy

from iron_ink_towers import _base, _beam, _box, _collection, _material, _palette


def _parent(obj, parent):
    bpy.context.view_layer.update()
    matrix = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = matrix
    return obj


def _empty(name, collection, position=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.location = position
    if parent:
        _parent(obj, parent)
    return obj


def _colors():
    p = _palette()
    p["ivory"] = _material("Research | ivory edge", (0.69, 0.64, 0.49))
    p["plum"] = _material("Tech | plum casing", (0.105, 0.062, 0.105))
    p["cyan"] = _material("Tech | contained cyan inset", (0.12, 0.72, 0.77), 0.45)
    return p


def _module(collection, p, name="Module", offset=(0, 0, 0), scale=1.0):
    before = set(collection.objects)

    def box(part, position, size, color, bevel=0.014):
        point = tuple(offset[i] + position[i] * scale for i in range(3))
        return _box(name + " " + part, point, tuple(value * scale for value in size),
                    collection, p[color], p["ink"], bevel * scale)

    box("notched casing", (0, 0, 0.15), (0.46, 0.28, 0.26), "plum", 0.022)
    for sign in (-1, 1):
        box(f"end brace {sign}", (sign * 0.24, 0, 0.15), (0.085, 0.31, 0.29), "ivory")
        for side in (-1, 1):
            box(f"notch lug {sign} {side}", (sign * 0.19, side * 0.155, 0.15),
                (0.10, 0.055, 0.29), "ivory", 0.008)
    box("top slot", (0, 0, 0.289), (0.25, 0.105, 0.025), "ink", 0.007)
    box("top cyan inset", (0, 0, 0.305), (0.21, 0.048, 0.012), "cyan", 0.003)
    box("front slot", (0, 0.145, 0.17), (0.24, 0.018, 0.073), "ink", 0.003)
    box("front cyan inset", (0, 0.157, 0.17), (0.20, 0.008, 0.035), "cyan", 0.002)
    return set(collection.objects) - before


def build_pickup(core=False):
    p = _colors()
    collection = _collection("Tech | intact manufactured salvage")
    root = _empty("TechRoot", collection)
    if core:
        _box("Carrier lower frame", (0, 0, 0.08), (0.76, 0.68, 0.12), collection, p["ink"], p["steel"])
        for y in (-0.21, 0, 0.21):
            _module(collection, p, f"Carrier module {y}", (0, y, 0.13), 0.65)
        for x in (-0.35, 0.35):
            _box(f"Carrier ivory rail {x}", (x, 0, 0.17), (0.10, 0.65, 0.25), collection, p["ivory"], p["ink"], 0.022)
    else:
        _module(collection, p)
    for obj in list(collection.objects):
        if obj != root:
            _parent(obj, root)
    bpy.context.scene["asset_model"] = "tech"
    bpy.context.scene["concept_reference"] = "concept-art/iron-and-ink/30-tech-collection.png"


def build_center():
    p = _colors()
    collection = _collection("Research | folding analysis bench")
    root = _empty("ResearchRoot", collection)
    _base(collection, p)
    for obj in list(collection.objects):
        if obj.type == "MESH":
            obj.location.x *= 1.45
            obj.location.y *= 1.18
            obj.location.z *= 0.62
            obj.scale = (1.45, 1.18, 0.62)
            if obj.name == "Yaw bearing lower":
                bpy.data.objects.remove(obj, do_unlink=True)
    for index, (x, y) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1)), 1):
        foot = _empty(f"ResearchFoot{index}", collection, (x * 0.45, y * 0.36, 0.13), root)
        for obj in list(collection.objects):
            if obj.name.endswith(f"{x:+d} {y:+d}") and obj.name.startswith(("Foot", "Folding")):
                _parent(obj, foot)
    _box("Tray ivory rim", (0, 0, 0.43), (0.81, 0.63, 0.09), collection, p["ivory"], p["ink"], 0.025)
    _box("Recessed analysis tray", (0, 0, 0.48), (0.68, 0.50, 0.045), collection, p["ink"], bevel=0.008)
    _module(collection, p, "Specimen", (0, 0, 0.49), 0.60)
    for sign, side in ((-1, "Left"), (1, "Right")):
        arch = _empty("ResearchArch" + side, collection, (sign * 0.48, 0, 0.45), root)
        before = set(collection.objects)
        _beam(side + " arch outer", (sign * 0.48, 0, 0.49), (sign * 0.48, 0, 0.97), 0.20, 0.24, collection, p["ivory"], p["ink"])
        _beam(side + " arch shoulder", (sign * 0.48, 0, 0.94), (sign * 0.31, 0, 1.24), 0.20, 0.24, collection, p["ivory"], p["ink"])
        _box(side + " arch slot", (sign * 0.48, 0.127, 0.73), (0.06, 0.020, 0.24), collection, p["ink"], bevel=0.004)
        _box(side + " steady cyan lamp", (sign * 0.48, 0.139, 0.73), (0.025, 0.008, 0.19), collection, p["cyan"], bevel=0.003)
        for obj in set(collection.objects) - before:
            _parent(obj, arch)
    cross = _empty("ResearchCrosspiece", collection, (0, 0, 1.24), root)
    _parent(_box("Scanner crosspiece", (0, 0, 1.24), (0.53, 0.21, 0.14), collection, p["blue_light"], p["ivory"], 0.018), cross)
    _parent(_box("Scanner underside", (0, 0, 1.16), (0.35, 0.14, 0.024), collection, p["cyan"], bevel=0.003), cross)
    screen = _box("Sloped screen housing", (0, 0.48, 0.32), (0.37, 0.09, 0.32), collection, p["ochre"], p["ink"], 0.024)
    screen.rotation_euler.x = math.radians(25)
    for name, size, color, position in (("Dark screen", (0.28, 0.014, 0.21), "ink", (0, 0.531, 0.345)),
                                        ("Screen cyan data", (0.17, 0.010, 0.12), "cyan", (0, 0.54, 0.35))):
        panel = _box(name, position, size, collection, p[color], bevel=0.005)
        panel.rotation_euler.x = math.radians(25)
    lamp = _empty("ResearchScan", collection, (0, 0, 0.51), root)
    _parent(_box("Contained tray scanner", (0, 0, 0.52), (0.035, 0.46, 0.014), collection, p["cyan"], bevel=0.002), lamp)
    for obj in list(collection.objects):
        if obj != root and obj.parent is None:
            _parent(obj, root)
    bpy.context.scene["asset_model"] = "structure"
    bpy.context.scene["concept_reference"] = "concept-art/iron-and-ink/31-research-center.png"


def build_collector():
    p = _colors()
    collection = _collection("Tech | auxiliary collector and cassette")
    root = _empty("TechCollectorRoot", collection)
    _box("Tech cassette dark shell", (0, 0, 0.19), (0.28, 0.21, 0.36), collection, p["ink"], p["steel"])
    _box("Tech cassette armour", (0, 0.025, 0.19), (0.27, 0.18, 0.32), collection, p["blue"], p["ochre"], 0.020)
    _box("Tech cassette inset", (0, 0.121, 0.22), (0.15, 0.012, 0.055), collection, p["cyan"], bevel=0.004)
    lid = _empty("TechCassetteLid", collection, (0, -0.10, 0.37), root)
    _parent(_box("Cassette hinged cover", (0, 0, 0.38), (0.29, 0.23, 0.045), collection, p["ochre"], p["ink"], 0.010), lid)
    shoulder = _empty("TechShoulder", collection, (0.14, 0, 0.32), root)
    upper = _empty("TechUpper", collection, (0.14, 0, 0.32), shoulder)
    _parent(_beam("Short upper link", (0.14, 0, 0.32), (0.31, 0, 0.53), 0.09, 0.10, collection, p["ochre"], p["ink"]), upper)
    elbow = _empty("TechElbow", collection, (0.31, 0, 0.53), root)
    forearm = _empty("TechForearm", collection, (0.31, 0, 0.53), elbow)
    _parent(_beam("Short outer link", (0.31, 0, 0.53), (0.20, 0, 0.32), 0.07, 0.08, collection, p["steel"], p["ink"]), forearm)
    wrist = _empty("TechWrist", collection, (0.20, 0, 0.32), root)
    for sign in (-1, 1):
        _parent(_box(f"Broad collector jaw {sign}", (0.20, sign * 0.08, 0.28), (0.12, 0.045, 0.12), collection, p["ink"], p["ivory"], 0.007), wrist)
    held = _empty("TechHeld", collection, (0.20, 0, 0.21), wrist)
    for obj in _module(collection, p, "Held intact tech", (0.20, 0, 0.21), 0.42):
        _parent(obj, held)
    held["model_only"] = True
    for obj in list(collection.objects):
        if obj != root and obj.parent is None:
            _parent(obj, root)
    bpy.context.scene["asset_model"] = "attachment"
    bpy.context.scene["concept_reference"] = "concept-art/iron-and-ink/30-tech-collection.png"
