"""Editable rigid-part character rigs with saved walk and recoil keyframes."""

import json
import math

import bpy
from mathutils import Vector

from iron_ink_towers import _beam, _box, _collection, _finish, _material, _palette


def _parent(obj, parent):
    bpy.context.view_layer.update()
    obj.parent = parent
    obj.matrix_parent_inverse = parent.matrix_world.inverted()
    return obj


class Character:
    def __init__(self, name):
        self.parts = _collection(f"{name} | editable armour and joints")
        self.rig = _collection(f"{name} | animation controls")
        self.p = _palette()
        self.p["skin"] = _material("Nathaniel | warm skin", (0.52, 0.29, 0.17))
        self.p["hair"] = _material("Nathaniel | hair and beard", (0.032, 0.021, 0.016))
        self.root = self.pivot("AssetFacing", (0, 0, 0))
        self.body = self.pivot("BodyMotion", (0, 0, 0), self.root)
        self.spine = self.pivot("Spine", (0, 0, 0.96), self.body)
        self.legs = []
        self.shoulders = []
        self.recoil = None

    def pivot(self, name, position, parent=None):
        obj = bpy.data.objects.new(name, None)
        self.rig.objects.link(obj)
        obj.location = position
        obj.empty_display_type = "PLAIN_AXES"
        obj.empty_display_size = 0.09
        if parent:
            _parent(obj, parent)
        return obj

    def box(self, name, position, size, material, parent, bevel=0.018, edge="blue_light"):
        obj = _box(name, position, size, self.parts, self.p[material],
                   self.p[edge] if edge else None, bevel)
        return _parent(obj, parent)

    def beam(self, name, start, end, width, depth, material, parent, edge="blue_light"):
        obj = _beam(name, start, end, width, depth, self.parts,
                    self.p[material], self.p[edge] if edge else None)
        return _parent(obj, parent)

    def axle(self, name, position, radius, length, parent, axis="X"):
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=radius,
                                            depth=length, location=position)
        obj = bpy.context.object
        if axis == "X":
            obj.rotation_euler.y = math.pi / 2
        elif axis == "Y":
            obj.rotation_euler.x = math.pi / 2
        _finish(obj, name, self.parts, self.p["ink"], self.p["steel"], 0.008)
        return _parent(obj, parent)

    def leg(self, side, x, height, upper, lower, ankle_height, heavy=False):
        name = "Left" if side < 0 else "Right"
        knee_z, ankle_z = height - upper, height - upper - lower
        hip = self.pivot(f"{name} hip", (x, 0, height), self.body)
        knee = self.pivot(f"{name} knee", (x, 0, knee_z), hip)
        ankle = self.pivot(f"{name} ankle", (x, 0, ankle_z), knee)
        width = 0.245 if heavy else 0.165
        self.axle(f"{name} hip joint", (x, 0, height), width * 0.55, width, hip)
        self.box(f"{name} thigh undersuit", (x, 0, height - upper / 2),
                 (width * 0.80, 0.155, upper * 0.88), "ink", hip, edge=None)
        self.box(f"{name} thigh armour", (x, 0.037, height - upper * 0.44),
                 (width, 0.205 if heavy else 0.185, upper * 0.70), "blue", hip)
        self.axle(f"{name} knee joint", (x, 0, knee_z), width * 0.48, width, knee)
        self.box(f"{name} knee guard", (x, 0.105, knee_z),
                 (width * 1.08, 0.085, 0.13), "blue_light", knee, bevel=0.025)
        self.box(f"{name} shin joint", (x, 0, knee_z - lower / 2),
                 (width * 0.69, 0.12, lower * 0.88), "ink", knee, edge=None)
        self.box(f"{name} shin armour", (x, 0.015, knee_z - lower * 0.49),
                 (width * 1.08, 0.23 if heavy else 0.17, lower * 0.70),
                 "blue", knee, bevel=0.025)
        self.box(f"{name} shin ochre tab", (x + side * width * 0.28, 0.14 if heavy else 0.105,
                                          knee_z - lower * 0.35),
                 (0.055, 0.015, 0.095), "ochre", knee, bevel=0.006, edge=None)
        foot_width, foot_length = (0.29, 0.40) if heavy else (0.19, 0.30)
        sole_height = 0.055 if heavy else 0.04
        self.box(f"{name} boot sole", (x, 0.075, ankle_z - ankle_height + sole_height / 2),
                 (foot_width, foot_length, sole_height), "ink", ankle, bevel=0.01)
        self.box(f"{name} boot armour", (x, 0.065, ankle_z - ankle_height + 0.095),
                 (foot_width * 0.96, foot_length * 0.93, 0.13), "blue", ankle, bevel=0.025)
        self.box(f"{name} boot toe cap", (x, 0.075 + foot_length * 0.31,
                                        ankle_z - ankle_height + 0.087),
                 (foot_width * 0.89, 0.095, 0.11), "blue_light", ankle, bevel=0.02)
        if heavy:
            self.box(f"{name} boot toe groove", (x, 0.18, ankle_z - ankle_height + 0.16),
                     (0.018, 0.13, 0.016), "ink", ankle, bevel=0.002, edge=None)
        self.legs.append((side, hip, knee, ankle, upper, lower, ankle_height, height))

    def arm(self, side, shoulder_position, elbow_position, hand_position, heavy=False):
        name = "Left" if side < 0 else "Right"
        shoulder = self.pivot(f"{name} shoulder", shoulder_position, self.spine)
        elbow = self.pivot(f"{name} elbow", elbow_position, shoulder)
        wrist = self.pivot(f"{name} wrist", hand_position, elbow)
        width = 0.235 if heavy else 0.14
        self.axle(f"{name} shoulder joint", shoulder_position,
                  0.13 if heavy else 0.085, width, shoulder)
        self.beam(f"{name} upper arm", shoulder_position, elbow_position,
                  width * 0.8, width * 0.82, "ink", shoulder)
        center = Vector(shoulder_position).lerp(Vector(elbow_position), 0.17)
        self.box(f"{name} shoulder shell", center,
                 (0.32, 0.34, 0.29) if heavy else (0.21, 0.25, 0.22),
                 "ochre" if side > 0 or heavy else "blue", shoulder,
                 bevel=0.04, edge="ochre" if side > 0 or heavy else "blue_light")
        self.axle(f"{name} elbow joint", elbow_position, width * 0.45, width, elbow)
        self.beam(f"{name} forearm shell", elbow_position, hand_position,
                  width, width * 1.02, "blue", elbow)
        self.box(f"{name} palm", hand_position,
                 (0.20, 0.19, 0.15) if heavy else (0.105, 0.11, 0.105),
                 "ink", wrist, bevel=0.018)
        if heavy:
            for finger in (-1, 1):
                finger_position = Vector(hand_position) + Vector((finger * 0.069, 0.052, -0.11))
                self.box(f"{name} claw {finger}", finger_position, (0.074, 0.16, 0.17),
                         "blue", wrist, bevel=0.018)
        self.shoulders.append((side, shoulder))
        return shoulder, elbow, wrist


def _nathaniel(c):
    c.leg(-1, -0.13, 0.83, 0.37, 0.385, 0.10)
    c.leg(1, 0.13, 0.83, 0.37, 0.385, 0.10)
    c.box("Pelvis flexible undersuit", (0, 0, 0.915), (0.34, 0.23, 0.23), "ink", c.body)
    c.box("Belt front armour", (0, 0.137, 0.96), (0.33, 0.065, 0.12), "blue", c.body)
    c.box("Ochre belt buckle", (0, 0.177, 0.97), (0.08, 0.027, 0.07), "ochre", c.body,
          bevel=0.008, edge=None)
    c.box("Torso undersuit", (0, 0, 1.195), (0.39, 0.235, 0.40), "ink", c.spine, bevel=0.045)
    c.box("Chest armour", (0, 0.04, 1.235), (0.43, 0.255, 0.29), "blue", c.spine, bevel=0.055)
    c.box("Chest raised center", (0, 0.178, 1.235), (0.27, 0.05, 0.17), "blue_light", c.spine)
    c.box("Chest ochre stripe", (0, 0.208, 1.195), (0.25, 0.02, 0.026), "ochre", c.spine,
          bevel=0.005, edge=None)
    for side in (-1, 1):
        c.box(f"Belt pouch {side}", (side * 0.16, 0.17, 1.02), (0.10, 0.09, 0.12),
              "blue_light", c.spine, bevel=0.01)
        c.beam(f"Shoulder strap {side}", (side * 0.155, 0.155, 1.12),
               (side * 0.155, 0.08, 1.41), 0.048, 0.04, "ink", c.spine, edge=None)
    c.box("Backpack frame", (0, -0.20, 1.23), (0.30, 0.18, 0.37), "ink", c.spine)
    c.box("Backpack blue cover", (0, -0.29, 1.25), (0.27, 0.06, 0.29), "blue", c.spine)
    head = c.pivot("Head", (0, 0, 1.43), c.spine)
    c.box("Neck", (0, 0, 1.425), (0.115, 0.12, 0.12), "skin", head, edge=None)
    c.box("Human head", (0, 0.015, 1.56), (0.235, 0.225, 0.255), "skin", head,
          bevel=0.047, edge=None)
    c.box("Short dark hair", (0, -0.018, 1.68), (0.253, 0.225, 0.075), "hair", head,
          bevel=0.025, edge=None)
    c.box("Hair back", (0, -0.085, 1.59), (0.23, 0.088, 0.16), "hair", head,
          bevel=0.02, edge=None)
    c.box("Beard jaw", (0, 0.100, 1.485), (0.203, 0.08, 0.085), "hair", head,
          bevel=0.025, edge=None)
    c.box("Nose", (0, 0.14, 1.56), (0.042, 0.066, 0.065), "skin", head,
          bevel=0.009, edge=None)
    for side in (-1, 1):
        c.box(f"Ear {side}", (side * 0.12, 0.012, 1.55), (0.043, 0.065, 0.087),
              "skin", head, bevel=0.015, edge=None)
        c.box(f"Eye and brow {side}", (side * 0.06, 0.128, 1.594),
              (0.05, 0.014, 0.018), "hair", head, bevel=0.004, edge=None)
        c.box(f"Beard side {side}", (side * 0.093, 0.087, 1.522),
              (0.03, 0.07, 0.105), "hair", head, bevel=0.008, edge=None)
    c.arm(-1, (-0.275, 0, 1.33), (-0.31, 0.16, 1.105), (-0.015, 0.44, 1.10))
    c.arm(1, (0.275, 0, 1.33), (0.30, 0.095, 1.09), (0.09, 0.25, 1.095))
    weapon = c.pivot("Rifle grip", (0.085, 0.28, 1.12), c.spine)
    c.box("Rifle receiver", (0.085, 0.36, 1.145), (0.105, 0.34, 0.13), "ink", weapon)
    c.box("Rifle top housing", (0.085, 0.36, 1.204), (0.095, 0.22, 0.055), "blue", weapon)
    c.box("Rifle stock", (0.085, 0.135, 1.143), (0.105, 0.17, 0.095), "blue", weapon)
    c.box("Rifle magazine", (0.085, 0.34, 1.038), (0.082, 0.083, 0.17), "ink", weapon)
    c.box("Rifle ochre mark", (0.143, 0.39, 1.157), (0.011, 0.09, 0.04), "ochre", weapon,
          bevel=0.003, edge=None)
    c.recoil = c.pivot("Rifle recoil", (0.085, 0.5, 1.145), weapon)
    c.axle("Rifle barrel", (0.085, 0.64, 1.145), 0.035, 0.28, c.recoil, axis="Y")
    c.box("Rifle muzzle", (0.085, 0.795, 1.145), (0.088, 0.09, 0.08), "steel", c.recoil,
          bevel=0.015, edge="ink")
    c.box("Rifle dark bore", (0.085, 0.843, 1.145), (0.041, 0.01, 0.038), "bore", c.recoil,
          bevel=0.007, edge=None)


def _hermes(c):
    c.leg(-1, -0.225, 0.77, 0.32, 0.36, 0.13, heavy=True)
    c.leg(1, 0.225, 0.77, 0.32, 0.36, 0.13, heavy=True)
    c.box("Pelvis bearing", (0, 0, 0.84), (0.49, 0.34, 0.20), "ink", c.body, bevel=0.035)
    c.box("Pelvis front armour", (0, 0.205, 0.86), (0.39, 0.105, 0.18), "blue", c.body)
    c.box("Pelvis ochre lock", (0, 0.263, 0.86), (0.15, 0.023, 0.10), "ochre", c.body,
          bevel=0.01, edge=None)
    c.axle("Waist bearing", (0, 0, 1.00), 0.18, 0.20, c.spine, axis="Z")
    c.box("Intake torso armour", (0, 0, 1.305), (0.74, 0.52, 0.575), "blue", c.spine,
          bevel=0.075)
    c.box("Rear power housing", (0, -0.29, 1.31), (0.49, 0.16, 0.44), "ink", c.spine,
          bevel=0.025)
    c.box("Rear power cover", (0, -0.379, 1.32), (0.39, 0.033, 0.32), "blue_light", c.spine)
    c.box("Deep chest intake", (0, 0.266, 1.30), (0.52, 0.025, 0.395), "bore", c.spine,
          bevel=0.025, edge=None)
    for side in (-1, 1):
        c.box(f"Intake ochre jamb {side}", (side * 0.284, 0.307, 1.30),
              (0.074, 0.115, 0.44), "ochre", c.spine, bevel=0.025, edge="steel")
    for z in (1.085, 1.515):
        c.box(f"Intake sill {z}", (0, 0.307, z), (0.585, 0.115, 0.063),
              "ochre", c.spine, bevel=0.017, edge="steel")
    for z in (1.185, 1.285):
        c.box(f"Intake recessed vane {z}", (0, 0.29, z), (0.45, 0.028, 0.035),
              "ink", c.spine, bevel=0.005, edge="blue_light")
    c.box("Intake amber upper bar", (0, 0.292, 1.423), (0.32, 0.023, 0.026),
          "amber", c.spine, bevel=0.004, edge=None)
    for side in (-1, 1):
        c.box(f"Chest ochre top tab {side}", (side * 0.25, 0.115, 1.598),
              (0.12, 0.14, 0.018), "ochre", c.spine, bevel=0.005, edge=None)
    head = c.pivot("Sensor head", (0, 0, 1.655), c.spine)
    c.box("Head swivel", (0, 0, 1.642), (0.17, 0.17, 0.09), "ink", head)
    c.box("Square sensor head", (0, 0.01, 1.77), (0.34, 0.295, 0.235), "blue", head,
          bevel=0.035)
    c.box("Sensor face", (0, 0.166, 1.77), (0.268, 0.029, 0.155), "ink", head,
          bevel=0.016, edge=None)
    for side in (-1, 1):
        c.box(f"Amber sensor {side}", (side * 0.076, 0.185, 1.784), (0.055, 0.017, 0.055),
              "amber", head, bevel=0.005, edge=None)
    c.box("Sensor ochre top plate", (0, -0.018, 1.89), (0.13, 0.12, 0.017),
          "ochre", head, bevel=0.007, edge=None)
    for side in (-1, 1):
        c.arm(side, (side * 0.48, 0, 1.45), (side * 0.56, 0.02, 1.075),
              (side * 0.56, 0.06, 0.74), heavy=True)


def _pose_leg(leg, forward, lift, body_z):
    _, hip, knee, ankle, upper, lower, ankle_height, height = leg
    drop = height + body_z - ankle_height - lift
    distance = min(math.hypot(forward, drop), upper + lower - 0.0001)
    hip_angle = math.atan2(forward, drop) + math.acos(
        max(-1, min(1, (upper * upper + distance * distance - lower * lower) / (2 * upper * distance))))
    knee_angle = -math.acos(
        max(-1, min(1, (distance * distance - upper * upper - lower * lower) / (2 * upper * lower))))
    hip.rotation_euler.x = hip_angle
    knee.rotation_euler.x = knee_angle
    ankle.rotation_euler.x = -hip_angle - knee_angle


def _animate(c, heavy):
    controls = [c.body, c.spine] + [obj for leg in c.legs for obj in leg[1:4]]
    controls += [shoulder for _, shoulder in c.shoulders]
    if c.recoil:
        controls.append(c.recoil)
    rest = {obj: (obj.location.copy(), obj.rotation_euler.copy()) for obj in controls}
    stride = 0.16 if heavy else 0.18
    poses = ((1, 0), (10, 1), (12, 2), (14, 3), (16, 4), (18, 1), (30, 5), (32, 0))
    for frame, pose in poses:
        bpy.context.scene.frame_set(frame)
        for obj, (location, rotation) in rest.items():
            obj.location, obj.rotation_euler = location.copy(), rotation.copy()
        bob = -0.015 if pose in (1, 3) else 0
        c.body.location.z = bob
        for leg in c.legs:
            side = leg[0]
            forward = stride * side * (1 if pose == 1 else -1) if pose in (1, 3) else 0
            lift = 0.105 if (pose == 2 and side < 0) or (pose == 4 and side > 0) else 0
            _pose_leg(leg, forward, lift, bob)
        if pose in (1, 3):
            c.spine.rotation_euler.y = 0.025 * (1 if pose == 1 else -1)
        if heavy:
            for side, shoulder in c.shoulders:
                shoulder.rotation_euler.x = -side * (0.19 if pose == 1 else -0.19 if pose == 3 else 0)
        if pose == 5:
            c.spine.rotation_euler.x = 0.065 if heavy else 0.085
            if c.recoil:
                c.recoil.location.y -= 0.055
            if heavy:
                for _, shoulder in c.shoulders:
                    shoulder.rotation_euler.x = -0.12
        for obj in controls:
            obj.keyframe_insert(data_path="location", frame=frame, group="Authored poses")
            obj.keyframe_insert(data_path="rotation_euler", frame=frame, group="Authored poses")
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = 1, 32
    scene.frame_set(1)
    scene["asset_animation"] = json.dumps({
        "directions": 8,
        "clips": [
            {"name": "idle", "frames": [1], "fps": 1, "loop": True},
            {"name": "walk", "frames": [10, 12, 14, 16], "fps": 8, "loop": True},
            {"name": "fire", "frames": [30, 32], "fps": 10, "loop": False},
        ],
    })


def build_character(kind):
    c = Character(kind.title())
    {"nathaniel": _nathaniel, "hermes": _hermes}[kind](c)
    _animate(c, heavy=kind == "hermes")
    bpy.context.scene["art_direction"] = "Iron & Ink"
    bpy.context.scene["concept_reference"] = "concept-art/iron-and-ink/01-scene.png"
    bpy.context.scene["ground_anchor"] = "World origin; Blender +Y forward, Z height"
    bpy.context.scene["animation_notes"] = "Rigid hip, knee, ankle, shoulder and spine controls; frame 18 closes walk loop"
