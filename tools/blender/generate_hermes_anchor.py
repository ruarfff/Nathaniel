"""Create Hermes's folded base using the existing armour and joint parts."""

import bpy

from iron_ink_characters import Character, _hermes, _parent, _pose_leg
from iron_ink_towers import _box


def build():
    c = Character("Hermes anchor")
    _hermes(c)
    c.body.name = "DeployBody"
    c.body.location.z = -0.52
    for leg in c.legs:
        side, hip, knee, ankle = leg[:4]
        suffix = "Left" if side < 0 else "Right"
        hip.name, knee.name, ankle.name = ("Deploy" + part + suffix for part in ("Hip", "Knee", "Ankle"))
        _pose_leg(leg, -0.12, 0, -0.52)
    for side, shoulder in c.shoulders:
        shoulder.name = "DeployShoulder" + ("Left" if side < 0 else "Right")
        shoulder.rotation_euler.x = -0.65
        shoulder.rotation_euler.y = side * 0.24
    for x in (-1, 1):
        for y in (-1, 1):
            name = "Anchor%s%s" % ("L" if x < 0 else "R", "F" if y > 0 else "B")
            control = c.pivot(name, (0, 0, 0), c.root)
            c.beam(name + " folding strut", (x * 0.39, y * 0.24, 0.38),
                   (x * 0.86, y * 0.58, 0.13), 0.19, 0.21, "ink", control)
            c.beam(name + " ochre guard", (x * 0.48, y * 0.32, 0.38),
                   (x * 0.80, y * 0.54, 0.20), 0.18, 0.18, "ochre", control)
            c.box(name + " planted foot", (x * 0.91, y * 0.61, 0.065),
                  (0.43, 0.36, 0.13), "ink", control, edge="steel")
            c.box(name + " foot armour", (x * 0.91, y * 0.61, 0.16),
                  (0.33, 0.30, 0.16), "blue", control, bevel=0.035)
            c.box(name + " foot latch", (x * 0.91, y * 0.61, 0.245),
                  (0.10, 0.23, 0.02), "ochre", control, bevel=0.004)
    for x in (-1, 1):
        c.box("Conduit socket rim %d" % x, (x * 0.53, 0.13, 0.20),
              (0.18, 0.28, 0.26), "ochre", c.root, edge="steel")
        c.box("Conduit socket %d" % x, (x * 0.63, 0.13, 0.20),
              (0.035, 0.18, 0.14), "ink", c.root, edge=None)
    c.box("Cannon support", (0, -0.22, 1.14), (0.31, 0.29, 0.34),
          "ink", c.root, edge="steel")
    pivot = c.pivot("AimPivot", (0, -0.22, 1.34))
    c.axle("Cannon yaw bearing", (0, -0.22, 1.34), 0.22, 0.10, pivot, axis="Z")
    c.box("Cannon rear armour", (-0.05, -0.22, 1.53), (0.49, 0.40, 0.30),
          "blue", pivot, bevel=0.04)
    for side in (-1, 1):
        c.box("Cannon ochre cheek %d" % side, (0.09, -0.22 + side * 0.205, 1.53),
              (0.16, 0.065, 0.31), "ochre", pivot, edge="steel")
    recoil = c.pivot("Recoil", (0, 0, 0))
    recoil.parent = pivot
    barrel = _box("Cannon sliding barrel", (0.51, -0.22, 1.53), (0.67, 0.17, 0.17),
                  c.parts, c.p["ink"], c.p["steel"], 0.018)
    _parent(barrel, recoil)
    muzzle_shell = _box("Cannon muzzle shroud", (0.87, -0.22, 1.53), (0.17, 0.25, 0.24),
                        c.parts, c.p["blue_light"], c.p["steel"], 0.022)
    _parent(muzzle_shell, recoil)
    bore = _box("Cannon black bore", (0.961, -0.22, 1.53), (0.012, 0.13, 0.12),
                c.parts, c.p["bore"], None, 0.008)
    _parent(bore, recoil)
    muzzle = c.pivot("Muzzle", (0.974, 0, 0.19))
    muzzle.parent = recoil
    scene = bpy.context.scene
    scene["asset_model"] = True
    scene["weapon_forward_axis"] = "+X"
    scene["art_direction"] = "Iron & Ink"
    scene["concept_reference"] = "concept-art/iron-and-ink/05-hermes-anchor-base.png"
    scene["ground_anchor"] = "World origin; folded feet and four stabilizers meet Z=0"
