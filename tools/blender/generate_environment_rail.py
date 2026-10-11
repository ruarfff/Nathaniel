"""Create a partly buried, walkable rail section for the freight apron."""

from iron_ink_environment import Environment


def build():
    e = Environment("rail", (1.6, 8))
    for index in range(8):
        e.box(f"Buried sleeper {index}", (0, -3.5 + index, 0.025),
              (1.6, 0.21, 0.05), "wood_light", "Foundation", 0.006)
    for side in (-1, 1):
        e.box(f"Worn rail {side}", (side * 0.52, 0, 0.08),
              (0.10, 8, 0.12), "rust", "Details", 0.009)
