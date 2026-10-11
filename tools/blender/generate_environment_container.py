"""Create a short freight container; later exports read the saved Blender source."""

from iron_ink_environment import Environment


def build():
    e = Environment("container", (2, 6))
    e.box("Freight container shell", (0, 0, 0.94), (2, 6, 1.88), "teal", "Walls", 0.035)
    for side in (-1, 1):
        for index in range(13):
            e.box(f"Corrugated side {side} {index}", (side * 1.01, -2.76 + index * 0.46, 0.98),
                  (0.08, 0.075, 1.68), "metal", "Walls")
        for z in (0.08, 1.80):
            e.box(f"Container side rail {side} {z}", (side * 1.02, 0, z),
                  (0.10, 6.07, 0.12), "rust")
        e.box(f"Large rear door {side}", (side * 0.49, 3.025, 0.94),
              (0.94, 0.075, 1.70), "metal", "Openings", 0.018)
        e.box(f"Door locking bar {side}", (side * 0.34, 3.08, 0.94),
              (0.055, 0.045, 1.60), "pale")
    e.box("Door number plate", (-0.65, 3.08, 1.37), (0.30, 0.035, 0.20), "ochre")
    e.box("Rust roof patch", (-0.27, -1.16, 1.89), (1.10, 1.24, 0.018), "rust", "Roof", 0)
