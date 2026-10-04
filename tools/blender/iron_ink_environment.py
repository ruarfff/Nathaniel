"""Editable Earth scenery from the Iron & Ink building and street concepts."""

import math
import random

import bpy
from mathutils import Vector

from iron_ink_towers import _beam, _box, _collection, _finish, _material


COLORS = {
    "plaster": (0.57, 0.49, 0.37), "pale": (0.70, 0.63, 0.49),
    "worn": (0.38, 0.29, 0.18), "brick": (0.32, 0.145, 0.072),
    "terracotta": (0.43, 0.195, 0.092), "roof_light": (0.51, 0.245, 0.12),
    "rust": (0.24, 0.105, 0.055), "ink": (0.018, 0.021, 0.021),
    "metal": (0.12, 0.145, 0.14), "teal": (0.095, 0.185, 0.195),
    "glass": (0.055, 0.095, 0.105), "glass_light": (0.13, 0.19, 0.20),
    "tar": (0.09, 0.095, 0.09), "wood": (0.18, 0.11, 0.05),
    "wood_light": (0.32, 0.225, 0.12), "stone": (0.30, 0.29, 0.25),
    "stone_light": (0.43, 0.405, 0.34), "olive": (0.18, 0.205, 0.075),
    "olive_light": (0.25, 0.275, 0.10), "olive_dark": (0.095, 0.12, 0.043),
    "bark": (0.115, 0.078, 0.035), "ochre": (0.47, 0.30, 0.085),
}


class Environment:
    """Small mesh kit; each part remains separate for manual source edits."""

    def __init__(self, kind, footprint):
        self.p = {key: _material(f"Earth | {key}", color) for key, color in COLORS.items()}
        for material in self.p.values():
            shader = material.node_tree.nodes.get("Principled BSDF")
            shader.inputs["Metallic"].default_value = 0
            shader.inputs["Roughness"].default_value = 0.9
        self.groups = {key: _collection(key) for key in (
            "Foundation", "Walls", "Openings", "Roof", "Details", "Rubble", "Nature")}
        self.root = bpy.data.objects.new("AssetFacing", None)
        self.groups["Foundation"].objects.link(self.root)
        self.root.empty_display_size = 0.3
        scene = bpy.context.scene
        scene["art_direction"] = "Iron & Ink | abandoned Earth"
        scene["ground_anchor"] = "World origin; Blender XY ground, Z height"
        scene["asset_footprint_units"] = list(footprint)
        scene["asset_kind"] = kind
        scene["concept_reference"] = "concept-art/iron-and-ink/07-earth-homes-shops.png; 08-earth-garages-warehouses.png; 09-sandy-street.png"

    def box(self, name, position, size, material, group="Details", bevel=0.012, yaw=0):
        obj = _box(name, position, size, self.groups[group], self.p[material],
                   self.p["ink"] if bevel > 0.02 else None, bevel, yaw)
        obj.parent = self.root
        return obj

    def beam(self, name, start, end, width, material="wood", group="Details", depth=None):
        obj = _beam(name, start, end, width, depth or width, self.groups[group],
                    self.p[material], self.p["ink"])
        obj.parent = self.root
        return obj

    def mesh(self, name, vertices, faces, material, group="Details", bevel=0):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        self.groups[group].objects.link(obj)
        _finish(obj, name, self.groups[group], self.p[material], self.p["ink"], bevel)
        obj.parent = self.root
        return obj

    def face_box(self, name, side, at, tangent, z, width, height, depth, material,
                 group="Openings", bevel=0.008):
        pos = (tangent, at, z) if side == "Y" else (at, tangent, z)
        size = (width, depth, height) if side == "Y" else (depth, width, height)
        return self.box(name, pos, size, material, group, bevel)

    def wall(self, name, side, at, width, height=2.35, openings=()):
        """An opening is (center, width, sill, height), cut into the wall mesh."""
        start = -width / 2
        for index, (center, span, sill, opening_height) in enumerate(sorted(openings)):
            left, right = center - span / 2, center + span / 2
            if left > start:
                self.face_box(f"{name} pier {index}", side, at, (start + left) / 2,
                              height / 2, left - start, height, 0.20, "plaster", "Walls")
            if sill:
                self.face_box(f"{name} sill wall {index}", side, at, center,
                              sill / 2, span, sill, 0.20, "plaster", "Walls")
            top = sill + opening_height
            if top < height:
                self.face_box(f"{name} lintel {index}", side, at, center,
                              (height + top) / 2, span, height - top, 0.20,
                              "plaster", "Walls")
            start = right
        if start < width / 2:
            self.face_box(f"{name} end pier", side, at, (start + width / 2) / 2,
                          height / 2, width / 2 - start, height, 0.20, "plaster", "Walls")

    def window(self, name, side, at, tangent, sill=0.95, width=0.75, height=0.94,
               boarded=False, broken=False):
        z = sill + height / 2
        self.face_box(f"{name} dark recess", side, at - 0.045, tangent, z,
                      width, height, 0.065, "ink")
        self.face_box(f"{name} glass", side, at + 0.012, tangent, z,
                      width - 0.09, height - 0.09, 0.02, "glass")
        for offset in (-1, 1):
            self.face_box(f"{name} upright {offset}", side, at + 0.06,
                          tangent + offset * width / 2, z, 0.055, height + 0.09,
                          0.09, "metal")
            self.face_box(f"{name} crossbar {offset}", side, at + 0.06, tangent,
                          z + offset * height / 2, width + 0.08, 0.055, 0.09, "metal")
        self.face_box(f"{name} mullion", side, at + 0.067, tangent, z,
                      0.034, height, 0.07, "metal")
        self.face_box(f"{name} stone sill", side, at + 0.08, tangent, sill - 0.06,
                      width + 0.17, 0.105, 0.22, "pale")
        if boarded:
            for index, dz in enumerate((-0.27, 0.04, 0.30)):
                obj = self.face_box(f"{name} nailed board {index}", side, at + 0.13,
                                    tangent, z + dz, width + 0.15, 0.14, 0.07, "wood_light")
                obj.rotation_euler.y = (-0.05, 0.04, -0.025)[index] if side == "Y" else 0
                obj.rotation_euler.x = 0 if side == "Y" else (-0.05, 0.04, -0.025)[index]
        elif broken:
            self.patch(f"{name} broken pane", side, at + 0.03,
                       [(tangent - width * 0.38, sill + 0.06),
                        (tangent - width * 0.20, sill + height * 0.42),
                        (tangent - width * 0.02, sill + height * 0.26),
                        (tangent + width * 0.19, sill + height * 0.68),
                        (tangent + width * 0.39, sill + height * 0.10)], "glass_light")

    def door(self, name, side, at, tangent, width=0.85, height=1.95):
        self.face_box(f"{name} recess", side, at - 0.05, tangent, height / 2,
                      width, height, 0.05, "ink")
        self.face_box(f"{name} leaf", side, at + 0.006, tangent, height / 2,
                      width - 0.10, height - 0.06, 0.06, "wood")
        for offset in (-1, 1):
            self.face_box(f"{name} frame {offset}", side, at + 0.055,
                          tangent + offset * width / 2, (height - 0.05) / 2,
                          0.09, height - 0.05, 0.13, "worn")
        self.face_box(f"{name} lintel", side, at + 0.055, tangent, height,
                      width + 0.10, 0.10, 0.13, "worn")
        self.face_box(f"{name} handle", side, at + 0.052, tangent + width * 0.26,
                      0.99, 0.06, 0.09, 0.05, "metal")

    def patch(self, name, side, at, points, material="worn"):
        vertices = [(x, at, z) if side == "Y" else (at, x, z) for x, z in points]
        return self.mesh(name, vertices, [tuple(range(len(vertices)))], material)

    def weather(self, width, depth, wall_height=2.35, ruin=False):
        for side, at, span in (("Y", depth / 2 + 0.102, width),
                               ("X", width / 2 + 0.102, depth)):
            for index, (fraction, z, scale) in enumerate((
                    (-0.43, 0.26, 0.34), (0.41, 0.46, 0.41),
                    (-0.28, wall_height - 0.20, 0.34),
                    (0.17, wall_height - 0.12, 0.23))):
                if ruin and side == "X" and index >= 2:
                    continue
                t = span * fraction
                points = [(t - scale, z - 0.13), (t - scale * 0.8, z + 0.10),
                          (t - scale * 0.4, z + 0.12), (t - scale * 0.1, z + 0.27),
                          (t + scale * 0.45, z + 0.17), (t + scale, z + 0.04),
                          (t + scale * 0.5, max(0.02, z - 0.19))]
                self.patch(f"{side} broad plaster loss {index}", side, at, points)
            for corner in (-1, 1):
                for course in range(5):
                    if ruin and side == "X" and corner == -1 and course >= 3:
                        continue
                    self.face_box(f"{side} exposed corner brick {corner} {course}", side,
                                  at + 0.01, corner * (span / 2 - 0.13),
                                  0.12 + course * 0.19, 0.34 if course % 2 else 0.22,
                                  0.15, 0.025, "brick", bevel=0.005)

    def broken_wall(self, name, side, at, points, material="plaster"):
        vertices = []
        for offset in (-0.10, 0.10):
            vertices.extend([(t, at + offset, z) if side == "Y" else (at + offset, t, z)
                             for t, z in points])
        count = len(points)
        faces = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
        faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count)
                  for i in range(count)]
        return self.mesh(name, vertices, faces, material, "Walls", 0.014)

    def roof_panel(self, name, x1, x2, y1, y2, z1, z2, material="terracotta"):
        vertices = [(x1, y1, z1), (x2, y1, z2), (x2, y2, z2), (x1, y2, z1)]
        vertices += [(x, y, z - 0.095) for x, y, z in vertices]
        return self.mesh(name, vertices, [(0, 1, 2, 3), (7, 6, 5, 4),
                         (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)],
                         material, "Roof", 0.012)

    def pitched_roof(self, width, depth, eave=2.37, rise=0.80, ruin=False, metal=False):
        half, edge = width / 2 + 0.18, depth / 2 + 0.18
        for sign in (-1, 1):
            for row in range(3):
                x1, x2 = sign * half * row / 3, sign * half * (row + 1) / 3
                z1, z2 = eave + rise * (1 - row / 3), eave + rise * (1 - (row + 1) / 3)
                for column in range(7):
                    if ruin and (column < 3 or (sign == 1 and (row > 0 or column < 5))):
                        continue
                    if not ruin and sign == 1 and row == 2 and column == 1:
                        continue
                    y1 = -edge + 2 * edge * column / 7
                    y2 = -edge + 2 * edge * (column + 1) / 7 - 0.024
                    palette = ("rust", "terracotta") if metal else ("terracotta", "roof_light")
                    self.roof_panel(f"Roof slope {sign} row {row} panel {column}",
                                    x1, x2, y1, y2, z1, z2, palette[(row + column) % 3 == 0])
            for index, y in enumerate((-edge + 0.15, -edge / 2, 0, edge / 2, edge - 0.15)):
                self.beam(f"Roof rafter {sign} {index}", (0, y, eave + rise - 0.13),
                          (sign * half, y, eave - 0.12), 0.105, group="Roof")
        self.beam("Roof ridge timber", (0, -edge, eave + rise - 0.15),
                  (0, edge, eave + rise - 0.15), 0.14, group="Roof")
        if not ruin:
            self.box("Terracotta ridge cap", (0, 0, eave + rise + 0.035),
                     (0.15, depth + 0.39, 0.12), "rust", "Roof", 0.016)

    def rubble(self, width, depth, seed, roof=False):
        rng = random.Random(seed)
        for index in range(15):
            x, y = rng.uniform(-width * 0.40, width * 0.40), rng.uniform(-depth * 0.40, depth * 0.32)
            sx, sy, sz = rng.uniform(0.32, 0.80), rng.uniform(0.28, 0.65), rng.uniform(0.15, 0.34)
            obj = self.box(f"Broken masonry slab {index}", (x, y, 0.18 + sz / 2),
                           (sx, sy, sz), "pale" if index % 3 else "brick", "Rubble", 0.035,
                           rng.uniform(-1.5, 1.5))
            obj.rotation_euler.x = rng.uniform(-0.2, 0.2)
            obj.rotation_euler.y = rng.uniform(-0.2, 0.2)
        for index in range(4):
            self.beam(f"Fallen structural beam {index}",
                      (-width * 0.32 + index * 0.35, -depth * 0.28, 0.24),
                      (width * 0.30, depth * 0.12 + index * 0.30, 0.33 + index * 0.12),
                      0.14, "wood" if roof else "metal", "Rubble")
        if roof:
            obj = self.roof_panel("Fallen broad roof slab", 0.1, width * 0.44,
                                  -depth * 0.28, depth * 0.14, 0.35, 0.74)
            obj.rotation_euler.z = -0.16


def _foundation(e, width, depth):
    e.box("Interior concrete floor", (0, 0, 0.055), (width, depth, 0.11),
          "stone", "Foundation", 0.006)
    for x in (-width / 2, width / 2):
        e.box(f"Foundation side {x}", (x, 0, 0.13), (0.24, depth, 0.26),
              "worn", "Foundation")
    for y in (-depth / 2, depth / 2):
        e.box(f"Foundation end {y}", (0, y, 0.13), (width, 0.24, 0.26),
              "worn", "Foundation")


def _ruined_sides(e, width, depth, height=2.35):
    e.broken_wall("Broken right wall", "X", width / 2,
                  [(-depth / 2, 0.1), (depth / 2, 0.1), (depth / 2, height),
                   (depth / 2 - 0.55, height), (depth / 2 - 0.60, 1.62),
                   (0.20, 1.62), (0.04, 0.98), (-0.44, 0.85),
                   (-0.66, 0.58), (-depth / 2, 0.73)])
    e.broken_wall("Broken rear wall", "Y", -depth / 2,
                  [(-width / 2, 0.1), (width / 2, 0.1), (width / 2, 0.72),
                   (width * 0.18, 0.65), (width * 0.12, 1.08),
                   (-width * 0.16, 1.10), (-width * 0.25, height - 0.30),
                   (-width / 2, height - 0.30)])
    e.wall("Surviving left wall", "X", -width / 2, depth, height)


def _awning(e, name, x, y, width, depth, height, material="terracotta", posts=False):
    roof = e.box(name, (x, y, height), (width, depth, 0.09), material, "Roof", 0.016)
    roof.rotation_euler.x = -0.18
    for offset in (-width / 2 + 0.06, width / 2 - 0.06):
        e.beam(f"{name} brace {offset}", (x + offset, y - depth / 2, height - 0.08),
               (x + offset, y + depth / 2, height - 0.26), 0.07, "wood", "Roof")
        if posts:
            e.box(f"{name} post {offset}", (x + offset, y + depth * 0.30, (height - 0.18) / 2),
                  (0.09, 0.09, height - 0.18), "wood", "Roof")


def _house(ruin):
    width, depth = 4, 5
    e = Environment("house_ruin" if ruin else "house", (width, depth))
    _foundation(e, width, depth)
    front = depth / 2
    e.wall("Front wall", "Y", front, width,
           openings=((-1.27, 0.76, 0.89, 0.95), (0, 0.86, 0, 1.95), (1.26, 0.76, 0.89, 0.95)))
    e.window("Front left window", "Y", front + 0.10, -1.27, 0.89, boarded=not ruin, broken=ruin)
    e.window("Front right window", "Y", front + 0.10, 1.26, 0.89, broken=ruin)
    e.door("House front door", "Y", front + 0.10, 0)
    if ruin:
        _ruined_sides(e, width, depth)
    else:
        e.wall("Right wall", "X", width / 2, depth,
               openings=((-1.0, 0.75, 0.95, 0.94), (1.0, 0.75, 0.95, 0.94)))
        for t in (-1.0, 1.0):
            e.window(f"Side window {t}", "X", width / 2 + 0.10, t)
        e.wall("Left wall", "X", -width / 2, depth)
        e.wall("Rear wall", "Y", -front, width)
    for sign in (-1, 1):
        if ruin and sign == -1:
            continue
        e.broken_wall(f"Gable end {sign}", "Y", sign * front,
                      [(-2, 2.35), (2, 2.35), (0, 3.17)])
    e.pitched_roof(width, depth, ruin=ruin)
    _awning(e, "Front porch tiled canopy", 0, front + 0.38, 1.24, 0.85, 2.10, posts=True)
    e.box("Doorstep lower", (0, front + 0.38, 0.07), (1.17, 0.77, 0.14), "stone_light", "Foundation")
    e.box("Doorstep upper", (0, front + 0.18, 0.17), (1.04, 0.36, 0.12), "pale", "Foundation")
    e.box("Brick chimney", (-1.15, -1.25, 2.72), (0.43, 0.50, 1.40), "plaster", "Roof", 0.022)
    e.box("Chimney stone cap", (-1.15, -1.25, 3.44), (0.56, 0.63, 0.12), "pale", "Roof")
    e.box("Chimney dark opening", (-1.15, -1.25, 3.505), (0.36, 0.43, 0.014), "ink", "Roof", 0)
    e.weather(width, depth, ruin=ruin)
    if ruin:
        e.rubble(width, depth, 17, roof=True)


def _flat_roof(e, width, depth, height, ruin=False):
    if not ruin:
        e.box("Flat concrete roof slab", (0, 0, height), (width + 0.18, depth + 0.18, 0.15),
              "tar", "Roof", 0.024)
    for side, at, span in (("Y", depth / 2, width), ("Y", -depth / 2, width),
                           ("X", width / 2, depth), ("X", -width / 2, depth)):
        if ruin and at < 0:
            continue
        actual_span = 0.45 if ruin and side == "X" else span
        tangent = span / 2 - 0.225 if ruin and side == "X" else 0
        if side == "Y":
            base_span, cap_span = actual_span + 0.22, actual_span + 0.28
            base_tangent = cap_tangent = tangent
        elif ruin:
            base_span, cap_span = actual_span - 0.11, actual_span - 0.14
            base_tangent, cap_tangent = span / 2 - 0.28, span / 2 - 0.295
        else:
            base_span, cap_span = actual_span - 0.22, actual_span - 0.28
            base_tangent = cap_tangent = tangent
        e.face_box(f"Roof parapet {side} {at}", side, at, base_tangent, height + 0.15,
                   base_span, 0.24, 0.22, "plaster", "Roof")
        e.face_box(f"Parapet stone cap {side} {at}", side, at, cap_tangent, height + 0.29,
                   cap_span, 0.07, 0.28, "pale", "Roof")


def _shop(ruin):
    width, depth = 5, 4
    e = Environment("shop_ruin" if ruin else "shop", (width, depth))
    _foundation(e, width, depth)
    front = depth / 2
    e.wall("Shop front", "Y", front, width, 2.7,
           openings=((-0.75, 2.55, 0.50, 1.47), (1.50, 0.94, 0.5, 1.47)))
    e.window("Shop display", "Y", front + 0.10, -0.75, 0.50, 2.55, 1.47, broken=True)
    e.window("Shop boarded display", "Y", front + 0.10, 1.50, 0.50, 0.94, 1.47, boarded=True)
    if ruin:
        _ruined_sides(e, width, depth, 2.70)
    else:
        e.wall("Shop right wall", "X", width / 2, depth, 2.70,
               openings=((0.8, 0.88, 0, 1.98),))
        e.door("Shop side entrance", "X", width / 2 + 0.10, 0.8, 0.88, 1.98)
        e.wall("Shop left wall", "X", -width / 2, depth, 2.70)
        e.wall("Shop rear wall", "Y", -front, width, 2.70)
    _flat_roof(e, width, depth, 2.70, ruin)
    _awning(e, "Faded teal shop awning", -0.72 if ruin else 0, front + 0.25,
             2.90 if ruin else 4.90, 0.74, 2.24, "teal")
    for index, x in enumerate((-1.95, -0.9, 0.15, 1.2, 2.05)):
        if ruin and x > 0.9:
            continue
        e.beam(f"Shop awning seam {index}", (x, front - 0.08, 2.35),
               (x, front + 0.61, 2.20), 0.026, "metal", "Roof")
    e.box("Shop side electrical cabinet", (width / 2 + 0.18, -0.72, 0.73),
          (0.31, 0.54, 1.15), "metal", bevel=0.022)
    e.face_box("Cabinet service inset", "X", width / 2 + 0.35, -0.72, 0.97,
               0.29, 0.25, 0.02, "ink")
    e.weather(width, depth, 2.70, ruin)
    if ruin:
        e.rubble(width, depth, 29)
        obj = e.box("Collapsed shop roof slab", (0.35, -0.20, 0.85),
                    (2.50, 1.30, 0.23), "stone_light", "Rubble", 0.035, -0.22)
        obj.rotation_euler.y = 0.43


def _shutter(e, name, at, tangent, width, height, ruin=False):
    e.face_box(f"{name} black interior", "Y", at - 0.08, tangent, height / 2,
               width, height, 0.03, "ink")
    shutter = e.face_box(f"{name} roller door", "Y", at + 0.015, tangent,
                         height / 2 + (0.20 if ruin else 0), width - 0.1,
                         height * (0.72 if ruin else 1), 0.08, "metal")
    if ruin:
        shutter.rotation_euler.y = 0.10
    for index in range(10):
        z = 0.12 + index * height / 10
        if ruin and index > 6:
            continue
        e.face_box(f"{name} horizontal slat {index}", "Y", at + 0.065, tangent,
                   z + (0.30 if ruin else 0), width - 0.16, 0.027, 0.025, "ink")
    for sign in (-1, 1):
        e.face_box(f"{name} jamb {sign}", "Y", at + 0.08,
                   tangent + sign * width / 2, (height + 0.01) / 2, 0.13, height + 0.01,
                   0.16, "rust")
    e.face_box(f"{name} header", "Y", at + 0.09, tangent, height + 0.10,
               width + 0.18, 0.18, 0.19, "rust")


def _garage(ruin):
    width, depth = 4, 7
    e = Environment("garage_ruin" if ruin else "garage", (width, depth))
    _foundation(e, width, depth)
    front = depth / 2
    e.wall("Garage front", "Y", front, width, 2.50, openings=((0, 2.9, 0, 2.10),))
    _shutter(e, "Garage", front + 0.10, 0, 2.90, 2.10, ruin)
    if ruin:
        _ruined_sides(e, width, depth, 2.50)
    else:
        e.wall("Garage right wall", "X", width / 2, depth, 2.50,
               openings=((1.10, 0.84, 0, 1.95), (-1.8, 1.25, 1.31, 0.70)))
        e.door("Garage side entrance", "X", width / 2 + 0.10, 1.10, 0.84)
        e.window("Garage side window", "X", width / 2 + 0.10, -1.8, 1.31, 1.25, 0.70, broken=True)
        e.wall("Garage left wall", "X", -width / 2, depth, 2.50)
        e.wall("Garage rear wall", "Y", -front, width, 2.50)
    for sign in (-1, 1):
        if not ruin or sign == 1:
            e.broken_wall(f"Garage gable {sign}", "Y", sign * front,
                          [(-2, 2.50), (2, 2.50), (0, 3.17)])
    e.pitched_roof(width, depth, 2.50, 0.67, ruin, metal=True)
    e.face_box("Garage faded ochre number plate", "Y", front + 0.14, 1.76, 1.75,
               0.24, 0.30, 0.03, "ochre")
    e.weather(width, depth, 2.50, ruin)
    if ruin:
        e.rubble(width, depth, 41, roof=True)


def _warehouse(ruin):
    width, depth = 6, 5
    e = Environment("warehouse_ruin" if ruin else "warehouse", (width, depth))
    _foundation(e, width, depth)
    front = depth / 2
    e.wall("Warehouse front", "Y", front, width, 2.96,
           openings=((-2.12, 0.88, 0, 1.95), (0.80, 2.86, 0, 2.34)))
    e.door("Warehouse office entrance", "Y", front + 0.10, -2.12, 0.88)
    _shutter(e, "Warehouse loading door", front + 0.10, 0.80, 2.86, 2.34, ruin)
    if ruin:
        _ruined_sides(e, width, depth, 2.96)
    else:
        e.wall("Warehouse right wall", "X", width / 2, depth, 2.96,
               openings=((0, 3.80, 1.90, 0.65),))
        e.window("Warehouse clerestory", "X", width / 2 + 0.10, 0, 1.90, 3.80, 0.65, broken=True)
        for index in range(5):
            e.face_box(f"Clerestory mullion {index}", "X", width / 2 + 0.18,
                       -1.58 + index * 0.79, 2.225, 0.045, 0.65, 0.05, "metal")
        e.wall("Warehouse left wall", "X", -width / 2, depth, 2.96)
        e.wall("Warehouse rear wall", "Y", -front, width, 2.96)
    _flat_roof(e, width, depth, 2.98, ruin)
    for side, at, span in (("Y", front + 0.115, width), ("X", width / 2 + 0.115, depth)):
        e.face_box(f"Warehouse rust fascia {side}", side, at,
                   depth / 2 - 0.225 if ruin and side == "X" else 0, 2.84,
                   0.45 if ruin and side == "X" else span, 0.20, 0.035, "rust")
        for course in range(7):
            z = 0.34 + course * 0.32
            if ruin and side == "X" and z > 0.6:
                continue
            e.face_box(f"Masonry joint {side} {course}", side, at - 0.01, 0,
                       z, span, 0.015, 0.009, "worn", bevel=0)
    e.face_box("Office upper window recess", "Y", front + 0.13, -2.10, 2.48,
               1.12, 0.48, 0.04, "ink")
    e.face_box("Office upper glazing", "Y", front + 0.16, -2.10, 2.48,
               1.02, 0.38, 0.03, "glass")
    e.box("Office raised coping", (-2.04, front, 3.34), (1.83, 0.35, 0.16),
          "pale", "Roof", 0.015)
    e.box("Office raised front", (-2.04, front, 3.15), (1.70, 0.25, 0.32),
          "plaster", "Roof")
    e.weather(width, depth, 2.96, ruin)
    if ruin:
        e.rubble(width, depth, 73)
        for y in (-1.35, 0, 1.30):
            e.beam(f"Exposed warehouse steel truss {y}", (-3.02, y, 2.75),
                   (2.2, y, 1.60 if y == 0 else 2.75), 0.16, "metal", "Roof")
        slab = e.box("Collapsed warehouse roof panel", (0.8, -0.5, 0.86),
                     (2.85, 2.05, 0.23), "stone_light", "Rubble", 0.045, 0.16)
        slab.rotation_euler.y = -0.34


def _rock(e, name, position, size, material="stone", seed=0):
    rng = random.Random(seed)
    sx, sy, sz = size
    x, y, z = position
    count = 6
    angles = [math.tau * i / count + 0.18 for i in range(count)]
    vertices = [(x + math.cos(a) * sx * 0.5, y + math.sin(a) * sy * 0.5, z) for a in angles]
    vertices += [(x + math.cos(a) * sx * rng.uniform(0.25, 0.40),
                  y + math.sin(a) * sy * rng.uniform(0.25, 0.40),
                  z + sz * rng.uniform(0.72, 1)) for a in angles]
    faces = [tuple(reversed(range(count))), tuple(range(count, 2 * count))]
    faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count)]
    obj = e.mesh(name, vertices, faces, material, "Nature")
    obj.data.materials.append(e.p["stone_light"])
    obj.data.polygons[1].material_index = 2
    return obj


def _tree(dead=False):
    e = Environment("dead_tree" if dead else "tree", (2.5, 2.1))
    segments = [((0, 0, 0), (0.05, 0.02, 0.95), 0.18),
                ((0.05, 0.02, 0.85), (-0.13, 0.01, 1.82), 0.13),
                ((-0.13, 0.01, 1.75), (-0.07, 0.1, 2.75), 0.08),
                ((0.03, 0.02, 0.83), (0.60, -0.20, 1.54), 0.12),
                ((0.60, -0.20, 1.54), (0.89, -0.29, 2.21), 0.08),
                ((-0.10, 0.0, 1.26), (-0.75, 0.32, 1.90), 0.12),
                ((-0.75, 0.32, 1.90), (-1.00, 0.37, 2.46), 0.07),
                ((-0.08, 0.02, 1.85), (0.36, 0.63, 2.41), 0.08),
                ((0.36, 0.63, 2.41), (0.55, 0.81, 2.79), 0.05),
                ((-0.20, 0.05, 1.69), (-0.48, -0.55, 2.26), 0.07)]
    for index, (start, end, width) in enumerate(segments):
        e.beam(f"Angular tree branch {index}", start, end, width,
               "bark", "Nature", width * 0.82)
    for index, (x, y) in enumerate(((-0.28, -0.16), (0.32, 0.11), (0.05, 0.30))):
        e.beam(f"Ground root {index}", (0.02, 0.02, 0.18), (x, y, 0.045),
               0.085, "bark", "Nature")
    if dead:
        for index, (start, end, _) in enumerate(segments[2:]):
            x, y, z = end
            attachment = Vector(start).lerp(Vector(end), 0.72)
            e.beam(f"Bare fork twig {index}", attachment,
                   (x + (-0.19 if index % 2 else 0.20), y - 0.11, z + 0.17),
                   0.032, "bark", "Nature")
    else:
        for index, (position, size) in enumerate((
                ((-0.15, 0.0, 2.43), (1.18, 0.93, 0.60)),
                ((-0.85, 0.32, 2.12), (0.90, 0.89, 0.55)),
                ((0.79, -0.25, 1.95), (1.02, 0.83, 0.60)),
                ((0.41, 0.63, 2.45), (0.91, 0.79, 0.50)),
                ((-0.49, -0.48, 2.14), (0.86, 0.70, 0.53)))):
            crown = _rock(e, f"Sparse angular olive crown {index}", position, size,
                          "olive_dark" if index % 2 else "olive", index + 13)
            crown.data.materials[2] = e.p["olive_light"]


def _rocks():
    e = Environment("rocks", (2.75, 1.85))
    for index, (position, size) in enumerate((
            ((-0.38, -0.1, 0), (1.36, 1.16, 0.86)),
            ((0.56, 0.16, 0), (1.03, 1.00, 0.60)),
            ((-1.00, 0.42, 0), (0.57, 0.50, 0.35)),
            ((0.06, 0.76, 0), (0.62, 0.46, 0.34)),
            ((0.99, -0.28, 0), (0.58, 0.59, 0.32)))):
        _rock(e, f"Angular stone {index}", position, size, seed=index + 31)


def _windmill():
    e = Environment("windmill", (2.25, 2.25))
    for x in (-1, 1):
        for y in (-1, 1):
            e.box(f"Windmill footing {x} {y}", (x * 0.84, y * 0.84, 0.10),
                  (0.35, 0.35, 0.20), "stone_light", "Foundation")
            e.beam(f"Windmill tower leg {x} {y}", (x * 0.84, y * 0.84, 0.16),
                   (x * 0.25, y * 0.25, 3.33), 0.10, "rust")
    for sign in (-1, 1):
        for z1, z2, s1, s2 in ((0.32, 1.55, 0.80, 0.55), (1.55, 2.75, 0.55, 0.34)):
            e.beam(f"Tower cross brace X {sign} {z1}", (-s1, sign * s1, z1),
                   (s2, sign * s2, z2), 0.055, "metal")
            e.beam(f"Tower cross brace Y {sign} {z1}", (sign * s1, -s1, z1),
                   (sign * s2, s2, z2), 0.055, "metal")
    e.box("Windmill gearbox", (0, 0, 3.34), (0.34, 0.42, 0.34), "rust", bevel=0.035)
    center = Vector((0, 0.38, 3.34))
    for index in range(10):
        angle = index * math.tau / 10
        dx, dz = math.sin(angle), math.cos(angle)
        e.beam(f"Windmill rotor spoke {index}", center,
               center + Vector((dx * 1.03, 0, dz * 1.03)), 0.033, "metal")
        tx, tz = math.cos(angle), -math.sin(angle)
        vertices = []
        for radius, tangent in ((0.46, -0.10), (1.14, -0.21), (1.14, 0.20), (0.46, 0.07)):
            vertices.append(tuple(center + Vector((dx * radius + tx * tangent,
                                                    0.02 + tangent * 0.4,
                                                    dz * radius + tz * tangent))))
        e.mesh(f"Windmill broad rotor blade {index}", vertices, [(0, 1, 2, 3)],
               "pale" if index % 3 else "rust")
    e.box("Rotor axle", center, (0.20, 0.18, 0.20), "ochre", bevel=0.025)
    e.beam("Tail boom", (0, -0.16, 3.32), (0, -1.12, 3.32), 0.085, "metal")
    e.box("Tail vane", (0, -1.00, 3.48), (0.055, 0.70, 0.45), "teal", bevel=0.012)


def build_environment(kind):
    """Generate once. Later exports use the saved source without rebuilding."""
    if kind in ("tree", "dead_tree"):
        _tree(kind == "dead_tree")
    elif kind == "rocks":
        _rocks()
    elif kind == "windmill":
        _windmill()
    else:
        ruin = kind.endswith("_ruin")
        family = kind.removesuffix("_ruin")
        {"house": _house, "shop": _shop, "garage": _garage, "warehouse": _warehouse}[family](ruin)
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    lowest = min((obj.matrix_world @ vertex.co).z
                 for obj in bpy.context.scene.objects if obj.type == "MESH"
                 for vertex in obj.evaluated_get(depsgraph).data.vertices)
    if abs(lowest) > 0.00001:
        for obj in bpy.context.scene.objects:
            if obj.type == "MESH":
                obj.location.z -= lowest
    bpy.context.scene["ground_contact_revision"] = 1
