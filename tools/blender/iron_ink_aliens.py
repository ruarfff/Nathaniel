"""Faceted alien shells and editable, keyed rigid-part animation rigs."""

import json
import math

import bpy
from mathutils import Vector

from iron_ink_characters import Character, _parent, _pose_leg
from iron_ink_towers import _finish, _material


class Alien(Character):
    def __init__(self, name):
        super().__init__(name)
        self.p.update({
            "plum": _material("Alien | dark plum shell", (0.17, 0.08, 0.12)),
            "pale": _material("Alien | pale shell edge", (0.47, 0.43, 0.34)),
            "joint": _material("Alien | exposed dark joint", (0.015, 0.018, 0.018)),
            "acid": _material("Alien | acid openings", (0.32, 0.70, 0.035), 0.55),
            "tissue": _material("Alien | spent matter", (0.17, 0.21, 0.08)),
        })
        self.p.update(blue=self.p["plum"], blue_light=self.p["pale"],
                      ink=self.p["joint"], ochre=self.p["pale"])
        self.quad_legs = []

    def shell(self, name, position, size, parent, rotation=(0, 0, 0), pale=True):
        outline = [(-0.5, 0.28), (-0.34, 0.5), (0.30, 0.5), (0.5, 0.23),
                   (0.35, -0.29), (0, -0.5), (-0.34, -0.29)]
        vertices = [(x * size[0], y, z * size[2])
                    for y in (-size[1] / 2, size[1] / 2) for x, z in outline]
        vertices.append((0, size[1] * 0.77, size[2] * 0.03))
        count = len(outline)
        faces = [tuple(reversed(range(count)))]
        faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count)
                  for i in range(count)]
        faces += [(2 * count, count + i, count + (i + 1) % count) for i in range(count)]
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        self.parts.objects.link(obj)
        obj.location = position
        obj.rotation_euler = rotation
        _finish(obj, name, self.parts, self.p["plum"], self.p["pale"], 0.009)
        if pale:
            for index in (count + 5, count + 6):
                mesh.polygons[index].material_index = 1
        return _parent(obj, parent)

    def core(self, name, position, size, parent, material="joint"):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=position)
        obj = bpy.context.object
        obj.scale = size
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        _finish(obj, name, self.parts, self.p[material], bevel=0)
        return _parent(obj, parent)

    def limb_shell(self, name, start, end, width, depth, parent, pale=True):
        obj = self.shell(name, (Vector(start) + Vector(end)) / 2,
                         (width, depth, (Vector(end) - Vector(start)).length * 1.02),
                         parent, pale=pale)
        obj.rotation_euler = (Vector(start) - Vector(end)).to_track_quat("Z", "Y").to_euler()
        return obj

    def quadruped_leg(self, side, row, hip_point, foot_point, upper, lower, width):
        prefix = f"{'Left' if side < 0 else 'Right'} {'front' if row > 0 else 'rear'}"
        hip_point, foot_point = Vector(hip_point), Vector(foot_point)
        knee_point = _knee_position(hip_point, foot_point, upper, lower, side)
        hip = self.pivot(f"{prefix} hip", hip_point, self.body)
        knee = self.pivot(f"{prefix} knee", knee_point, hip)
        ankle = self.pivot(f"{prefix} ankle", foot_point, knee)
        self.axle(f"{prefix} hip bearing", hip_point, width * 0.40, width * 0.80, hip)
        self.beam(f"{prefix} upper tendon", hip_point, knee_point, width * 0.50,
                  width * 0.50, "joint", hip, edge=None)
        self.limb_shell(f"{prefix} upper shell", hip_point, knee_point,
                        width * 1.10, width * 0.50, hip, pale=False)
        self.axle(f"{prefix} knee bearing", knee_point, width * 0.40, width * 0.85, knee)
        self.beam(f"{prefix} lower tendon", knee_point, foot_point, width * 0.45,
                  width * 0.45, "joint", knee, edge=None)
        self.limb_shell(f"{prefix} pointed lower shell", knee_point, foot_point,
                        width * 1.15, width * 0.52, knee)
        foot_width = width * 0.92
        self.box(f"{prefix} planted foot", (foot_point.x, foot_point.y + 0.035, 0.028),
                 (foot_width, width * 0.90, 0.056), "joint", ankle,
                 bevel=0.015, edge=None)
        for toe in (-1, 1):
            self.box(f"{prefix} toe {toe}",
                     (foot_point.x + toe * foot_width * 0.27, foot_point.y + width * 0.43, 0.033),
                     (foot_width * 0.40, width * 0.50, 0.065), "joint", ankle,
                     bevel=0.012, edge="pale")
        leg = (side, row, hip, knee, ankle, hip_point, knee_point, foot_point, upper, lower)
        self.quad_legs.append(leg)
        return knee


def _knee_position(hip, foot, upper, lower, side):
    axis = foot - hip
    distance = min(axis.length, upper + lower - 0.0001)
    direction = axis.normalized()
    along = (upper * upper - lower * lower + distance * distance) / (2 * distance)
    pole = Vector((side, 0, 0.18))
    pole = (pole - direction * pole.dot(direction)).normalized()
    return hip + direction * along + pole * math.sqrt(max(0, upper * upper - along * along))


def _face(c, position, width, parent):
    x, y, z = position
    c.shell("Pointed alien face", (x, y, z), (width, width * 0.43, width * 0.80),
            parent, rotation=(0.25, 0, 0))
    for side in (-1, 1):
        c.box(f"Acid eye {side}", (x + side * width * 0.28, y + width * 0.39, z + width * 0.04),
              (width * 0.15, 0.022, width * 0.09), "acid", parent, bevel=0.003, edge=None)
        c.beam(f"Mandible {side}", (x + side * width * 0.24, y + width * 0.22, z - width * 0.18),
               (x + side * width * 0.12, y + width * 0.49, z - width * 0.37),
               width * 0.13, width * 0.16, "joint", parent, edge="pale")


def _grunt(c):
    c.spine.location.z = 0.43
    c.core("Grunt joint body", (0, -0.04, 0.41), (0.38, 0.43, 0.22), c.spine)
    c.shell("Grunt broad dorsal shell", (0, -0.02, 0.555), (0.77, 0.16, 0.84),
            c.spine, rotation=(math.pi / 2, 0, 0))
    for side in (-1, 1):
        c.shell(f"Grunt side plate {side}", (side * 0.30, -0.09, 0.48), (0.30, 0.11, 0.58),
                c.spine, rotation=(math.pi / 2, side * 0.45, 0), pale=False)
        for row in (-1, 1):
            c.quadruped_leg(side, row, (side * 0.25, row * 0.21, 0.40),
                            (side * 0.58, row * 0.30, 0.04), 0.27, 0.34, 0.20)
        for vent in range(3):
            c.box(f"Grunt side vent {side} {vent}", (side * 0.351, 0.08 + vent * 0.065, 0.40),
                  (0.025, 0.031, 0.07), "acid", c.spine, bevel=0.005, edge=None)
    _face(c, (0, 0.40, 0.33), 0.34, c.spine)


def _soldier_leg(c, side):
    x, height, upper, lower, ankle_height = side * 0.18, 0.765, 0.32, 0.37, 0.09
    knee_z, ankle_z = height - upper, height - upper - lower
    prefix = "Left" if side < 0 else "Right"
    hip = c.pivot(f"{prefix} hip", (x, 0, height), c.body)
    knee = c.pivot(f"{prefix} knee", (x, 0, knee_z), hip)
    ankle = c.pivot(f"{prefix} ankle", (x, 0, ankle_z), knee)
    c.axle(f"{prefix} pelvis joint", (x, 0, height), 0.082, 0.16, hip)
    c.beam(f"{prefix} upper tendon", (x, 0, height), (x, 0, knee_z), 0.10, 0.10,
           "joint", hip, edge=None)
    c.shell(f"{prefix} tapered thigh", (x, 0.035, height - 0.15), (0.19, 0.135, 0.30), hip)
    c.axle(f"{prefix} knee bearing", (x, 0, knee_z), 0.075, 0.15, knee)
    c.beam(f"{prefix} lower tendon", (x, 0, knee_z), (x, 0, ankle_z), 0.085, 0.085,
           "joint", knee, edge=None)
    c.shell(f"{prefix} pointed shin", (x, 0.032, knee_z - 0.18), (0.185, 0.13, 0.34), knee,
            pale=False)
    c.box(f"{prefix} foot sole", (x, 0.07, ankle_z - ankle_height + 0.025),
          (0.17, 0.28, 0.05), "joint", ankle, bevel=0.015, edge=None)
    c.shell(f"{prefix} foot claw", (x, 0.07, ankle_z - ankle_height + 0.082),
            (0.18, 0.07, 0.28), ankle, rotation=(math.pi / 2, 0, 0))
    c.legs.append((side, hip, knee, ankle, upper, lower, ankle_height, height))


def _cannon(c, name, position, width, parent):
    x, y, z = position
    c.shell(f"{name} shell", (x, y, z), (width, width * 0.63, width * 1.35), parent,
            rotation=(0.6, 0, 0))
    c.box(f"{name} dark opening", (x, y + width * 0.75, z - width * 0.20),
          (width * 0.73, 0.055, width * 0.70), "bore", parent, bevel=0.025, edge="pale")
    for side in (-1, 1):
        c.box(f"{name} acid slot {side}", (x + side * width * 0.16, y + width * 0.85,
                                          z - width * 0.18),
              (width * 0.09, 0.023, width * 0.50), "acid", parent,
              bevel=0.003, edge=None)


def _soldier(c):
    c.spine.location.z = 0.92
    _soldier_leg(c, -1)
    _soldier_leg(c, 1)
    c.core("Soldier pelvis", (0, 0, 0.87), (0.25, 0.16, 0.16), c.body)
    c.core("Soldier chest tissue", (0, 0, 1.22), (0.25, 0.18, 0.31), c.spine)
    c.shell("Soldier chest carapace", (0, 0.13, 1.20), (0.50, 0.14, 0.53), c.spine)
    c.shell("Soldier raised back crest", (0, -0.14, 1.56), (0.56, 0.11, 0.53), c.spine,
            rotation=(-0.18, 0, 0), pale=False)
    for side in (-1, 1):
        c.shell(f"Soldier crest cheek {side}", (side * 0.25, -0.06, 1.47),
                (0.24, 0.15, 0.45), c.spine, rotation=(0, side * 0.33, 0))
        for vent in range(3):
            c.box(f"Soldier flank vent {side} {vent}",
                  (side * 0.246, 0.105 + vent * 0.035, 1.12 + vent * 0.026),
                  (0.025, 0.023, 0.08), "acid", c.spine, bevel=0.003, edge=None)
    _face(c, (0, 0.12, 1.545), 0.29, c.spine)
    for side in (-1, 1):
        shoulder_position = (side * 0.37, -0.015, 1.38)
        elbow_position = (side * 0.43, 0.025, 1.12)
        hand_position = (side * 0.43, 0.16, 0.88)
        shoulder = c.pivot(f"Soldier shoulder {side}", shoulder_position, c.spine)
        elbow = c.pivot(f"Soldier elbow {side}", elbow_position, shoulder)
        c.axle(f"Soldier shoulder joint {side}", shoulder_position, 0.10, 0.16, shoulder)
        c.limb_shell(f"Soldier upper arm {side}", shoulder_position, elbow_position,
                     0.23, 0.13, shoulder, pale=side < 0)
        c.axle(f"Soldier elbow joint {side}", elbow_position, 0.07, 0.15, elbow)
        c.beam(f"Soldier forearm tendon {side}", elbow_position, hand_position,
               0.10, 0.10, "joint", elbow, edge=None)
        if side > 0:
            c.recoil = c.pivot("Soldier cannon recoil", (0.43, 0.18, 0.99), elbow)
            _cannon(c, "Soldier arm cannon", (0.43, 0.18, 0.99), 0.32, c.recoil)
        else:
            c.limb_shell("Soldier claw forearm", elbow_position, hand_position, 0.18, 0.11, elbow)
            for finger in (-1, 0, 1):
                c.beam(f"Soldier claw finger {finger}", (-0.43 + finger * 0.055, 0.16, 0.89),
                       (-0.43 + finger * 0.063, 0.205, 0.75), 0.04, 0.047,
                       "joint", elbow, edge="pale")
        c.shoulders.append((side, shoulder))


def _boss(c):
    c.spine.location.z = 0.77
    c.core("Boss broad tissue body", (0, -0.13, 0.83), (0.68, 0.67, 0.43), c.spine)
    crest = c.shell("Boss dominant pale crest", (0, 0.055, 1.14), (1.17, 0.19, 1.33),
                    c.spine, rotation=(0.52, 0, 0))
    _crest_inset(crest, c.parts, c.p["pale"])
    for side in (-1, 1):
        c.shell(f"Boss dorsal shoulder plate {side}", (side * 0.50, -0.28, 1.12),
                (0.46, 0.18, 0.69), c.spine, rotation=(0.15, side * 0.35, 0), pale=False)
        c.shell(f"Boss rear carapace {side}", (side * 0.39, -0.57, 0.99),
                (0.60, 0.16, 0.64), c.spine, rotation=(math.pi / 2, side * 0.3, 0), pale=False)
        for row in (-1, 1):
            knee = c.quadruped_leg(side, row, (side * 0.46, row * 0.40, 0.66),
                                   (side * 0.86, row * 0.55, 0.04), 0.38, 0.46, 0.32)
            if row > 0:
                _cannon(c, f"Boss front cannon {side}", (side * 0.83, 0.63, 0.46), 0.34, knee)
        for vent in range(3):
            c.box(f"Boss cheek vent {side} {vent}", (side * 0.31, 0.625, 0.68 + vent * 0.07),
                  (0.027, 0.035, 0.042), "acid", c.spine, bevel=0.004, edge=None)
    _face(c, (0, 0.62, 0.55), 0.43, c.spine)


def _crest_inset(crest, collection, material):
    center = crest.data.vertices[14].co.copy()
    vertices = [center.lerp(crest.data.vertices[index].co, 0.76) + Vector((0, 0.004, 0))
                for index in range(7, 14)]
    vertices.append(center + Vector((0, 0.004, 0)))
    mesh = bpy.data.meshes.new("Boss crest pale inset")
    mesh.from_pydata(vertices, [], [(7, i, (i + 1) % 7) for i in range(7)])
    mesh.update()
    obj = bpy.data.objects.new(mesh.name, mesh)
    collection.objects.link(obj)
    _finish(obj, mesh.name, collection, material, bevel=0)
    obj.parent = crest


def _animate(c, kind):
    controls = [c.body, c.spine] + [obj for leg in c.legs for obj in leg[1:4]]
    controls += [obj for leg in c.quad_legs for obj in leg[2:5]]
    controls += [obj for _, obj in c.shoulders]
    if c.recoil:
        controls.append(c.recoil)
    for leg in c.quad_legs:
        for obj in leg[2:5]:
            obj.rotation_mode = "QUATERNION"
    rest = {obj: (obj.location.copy(), obj.rotation_euler.copy(), obj.rotation_quaternion.copy())
            for obj in controls}
    for frame, pose in ((1, 0), (10, 1), (12, 2), (14, 3), (16, 4), (18, 1), (30, 5), (32, 0)):
        bpy.context.scene.frame_set(frame)
        for obj, (position, rotation, quaternion) in rest.items():
            obj.location, obj.rotation_euler = position.copy(), rotation.copy()
            obj.rotation_quaternion = quaternion.copy()
        c.body.location.z = -0.012 if pose in (1, 3) else 0
        if pose == 5:
            c.spine.rotation_euler.x = -0.13 if kind == "grunt" else 0.075
            c.body.location.y = 0.055 if kind == "grunt" else 0
        for leg in c.legs:
            side = leg[0]
            forward = 0.16 * side * (1 if pose == 1 else -1) if pose in (1, 3) else 0
            lift = 0.09 if (pose == 2 and side < 0) or (pose == 4 and side > 0) else 0
            _pose_leg(leg, forward, lift, c.body.location.z)
        for leg in c.quad_legs:
            side, row, hip, knee, ankle, start, bend, end, upper, lower = leg
            pair = side * row
            target = end.copy()
            target.y += 0.10 * pair * (1 if pose == 1 else -1) if pose in (1, 3) else 0
            target.z += 0.075 if (pose == 2 and pair < 0) or (pose == 4 and pair > 0) else 0
            origin = start + c.body.location
            new_bend = _knee_position(origin, target, upper, lower, side)
            upper_rotation = (bend - start).rotation_difference(new_bend - origin)
            lower_rotation = (end - bend).rotation_difference(target - new_bend)
            hip.rotation_quaternion = upper_rotation
            knee.rotation_quaternion = upper_rotation.inverted() @ lower_rotation
            ankle.rotation_quaternion = lower_rotation.inverted()
        for side, shoulder in c.shoulders:
            shoulder.rotation_euler.x = side * (0.13 if pose == 1 else -0.13 if pose == 3 else 0)
        if c.recoil and pose == 5:
            c.recoil.location.y -= 0.07
        for obj in controls:
            obj.keyframe_insert(data_path="location", frame=frame, group="Authored poses")
            channel = "rotation_quaternion" if obj.rotation_mode == "QUATERNION" else "rotation_euler"
            obj.keyframe_insert(data_path=channel, frame=frame, group="Authored poses")
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = 1, 32
    scene.frame_set(1)
    scene["asset_animation"] = json.dumps({"directions": 8, "clips": [
        {"name": "idle", "frames": [1], "fps": 1, "loop": True},
        {"name": "walk", "frames": [10, 12, 14, 16], "fps": 8, "loop": True},
        {"name": "fire", "frames": [30, 32], "fps": 10, "loop": False},
    ]})


def build_alien(kind):
    c = Alien(kind.title())
    {"grunt": _grunt, "soldier": _soldier, "boss": _boss}[kind](c)
    _animate(c, kind)
    if kind in ("soldier", "boss"):
        bpy.context.scene["cannon_opening_revision"] = 1
    if kind == "boss":
        bpy.context.scene["crest_inset_revision"] = 1
    bpy.context.scene["art_direction"] = "Iron & Ink"
    bpy.context.scene["concept_reference"] = "concept-art/iron-and-ink/02-alien-enemies.png"
    bpy.context.scene["ground_anchor"] = "World origin; Blender +Y forward, Z height"


def build_soldier_corpse():
    c = Alien("Soldier spent matter")
    _soldier(c)
    for leg in c.legs:
        _pose_leg(leg, 0.06 * leg[0], 0, 0)
        leg[1].rotation_euler.z = leg[0] * 0.23
        leg[2].rotation_euler.x -= 0.26
    for side, shoulder in c.shoulders:
        shoulder.rotation_euler.z = side * 0.38
        shoulder.rotation_euler.x = 0.22
    c.spine.rotation_euler.x = 0.16
    bpy.data.objects["Soldier chest carapace"].hide_render = True
    c.core("Exposed spent matter", (0, 0.19, 1.19), (0.24, 0.16, 0.30),
           c.spine, material="tissue")
    for side in (-1, 1):
        c.shell(f"Broken breastplate fragment {side}", (side * 0.22, 0.19, 1.17),
                (0.19, 0.06, 0.28), c.spine, rotation=(0.15, side * 0.42, side * 0.4))
    shader = c.p["acid"].node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (0.055, 0.08, 0.018, 1)
    shader.inputs["Emission Strength"].default_value = 0
    c.body.rotation_euler = (1.45, 0, 0.25)
    c.body.location = (0, 0.75, 0)
    _seat_corpse(c.body, c.parts.objects)
    bpy.context.scene["art_direction"] = "Iron & Ink"
    bpy.context.scene["cannon_opening_revision"] = 1
    bpy.context.scene["ground_contact_revision"] = 1
    bpy.context.scene["concept_reference"] = "concept-art/iron-and-ink/02-alien-enemies.png"
    bpy.context.scene["ground_anchor"] = "World origin; collapsed soldier rests on Z=0"


def _seat_corpse(body, objects):
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    minimum = math.inf
    for obj in objects:
        if obj.type != "MESH" or obj.hide_render:
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        minimum = min(minimum, min((evaluated.matrix_world @ vertex.co).z for vertex in mesh.vertices))
        evaluated.to_mesh_clear()
    body.location.z -= minimum


def _trim_ground_meshes(objects):
    bpy.context.view_layer.update()
    for obj in objects:
        if obj.type != "MESH" or obj.hide_render:
            continue
        inverse = obj.matrix_world.inverted()
        for vertex in obj.data.vertices:
            world = obj.matrix_world @ vertex.co
            if world.z < 0:
                world.z = 0
                vertex.co = inverse @ world
        obj.data.update()


def _spawn_arch(c, side):
    outline = [(-1.45, 0.10), (-1.12, 1.72), (-0.30, 2.42), (0, 2.52),
               (0, 1.98), (-0.58, 1.02), (-0.77, 0.10)]
    if side > 0:
        outline = [(-x, z) for x, z in reversed(outline)]
    vertices = [(x, 1.16 - z * 0.10 + back, z)
                for back in (-0.42, 0) for x, z in outline]
    count = len(outline)
    faces = [tuple(reversed(range(count))), tuple(range(count, 2 * count))]
    faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count)]
    mesh = bpy.data.meshes.new(f"Spawner entry shell {side}")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(mesh.name, mesh)
    c.parts.objects.link(obj)
    _finish(obj, mesh.name, c.parts, c.p["plum"], c.p["pale"], 0.04)
    _parent(obj, c.body)
    c.beam(f"Entry pale inner edge {side}", (side * 0.76, 1.165, 0.15),
           (side * 0.55, 1.07, 1.03), 0.085, 0.065, "pale", c.body, edge=None)
    c.beam(f"Entry upper pale edge {side}", (side * 0.55, 1.07, 1.03),
           (0, 0.973, 1.98), 0.085, 0.065, "pale", c.body, edge=None)


def build_spawner():
    c = Alien("Spawner")
    c.spine.location.z = 0.8
    c.core("Spawner dark inner chamber", (0, -0.34, 1.03), (1.50, 1.30, 1.05), c.body)
    for side in (-1, 1):
        _spawn_arch(c, side)
        for row in (-1, 1):
            c.quadruped_leg(side, row, (side * 1.03, row * 0.80, 0.79),
                            (side * 1.72, row * 1.45, 0.04), 0.67, 0.79, 0.67)
        c.shell(f"Spawner flank carapace {side}", (side * 0.98, -0.08, 1.33),
                (1.14, 0.32, 1.85), c.body,
                rotation=(math.pi / 2, side * 0.47, 0), pale=False)
        c.shell(f"Spawner rear shell {side}", (side * 0.58, -1.12, 0.90),
                (1.23, 0.30, 1.55), c.body,
                rotation=(math.pi / 2, side * 0.35, 0), pale=False)
        c.beam(f"Emergence acid seam {side}", (side * 0.63, 0.89, 0.15),
               (side * 0.12, 0.70, 1.59), 0.035, 0.05, "acid", c.body, edge=None)
    mesh = bpy.data.meshes.new("Dark emergence opening")
    mesh.from_pydata([(-0.77, 0.81, 0.05), (0.77, 0.81, 0.05), (0, 0.70, 1.98)], [], [(0, 2, 1)])
    mesh.update()
    obj = bpy.data.objects.new(mesh.name, mesh)
    c.parts.objects.link(obj)
    _finish(obj, mesh.name, c.parts, c.p["bore"], bevel=0)
    _parent(obj, c.body)
    for side in (-1, 1):
        c.shell(f"Spawn spire shell {side}", (side * 0.28, -0.58, 2.56),
                (0.42, 0.30, 1.15), c.body, rotation=(0, -side * 0.11, 0), pale=True)
    c.core("Spawn acid heart", (0, -0.49, 2.69), (0.24, 0.24, 0.41), c.body, material="acid")
    c.box("Spire dark crown", (0, -0.63, 3.05), (0.40, 0.32, 0.13),
          "joint", c.body, bevel=0.025, edge="pale")
    _trim_ground_meshes(c.parts.objects)
    bpy.context.scene["ground_contact_revision"] = 1
    bpy.context.scene["art_direction"] = "Iron & Ink"
    bpy.context.scene["concept_reference"] = "concept-art/iron-and-ink/04-alien-structures.png"
    bpy.context.scene["ground_anchor"] = "World origin; emergence opening faces Blender +Y"
