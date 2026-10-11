"""Create a low eroded rock rib for the flat survival riverbed."""

from iron_ink_environment import Environment, _rock


def build():
    e = Environment("rock_shelf", (6, 3))
    e.mesh("Eroded shelf", [(-3, -1.5, 0), (3, -1.5, 0), (3, 1.5, 0), (-3, 1.5, 0),
                           (-2.6, -0.85, 0.75), (2.35, -1.10, 0.58),
                           (2.70, 0.65, 1.02), (-2.80, 0.95, 0.88)],
           [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5),
            (2, 3, 7, 6), (3, 0, 4, 7)], "stone_light", "Nature", 0.02)
    for index, (x, y, scale) in enumerate(((-2.4, 0.2, 0.6), (-0.9, 0.1, 0.8),
                                         (1.0, -0.1, 0.65), (2.2, 0.0, 0.55))):
        _rock(e, f"Shelf crown {index}", (x, y, 0.7), (scale, scale * 0.7, 0.3), seed=index + 80)
