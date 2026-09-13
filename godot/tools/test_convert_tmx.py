"""Run with: python3 -m unittest discover -s godot/tools -p 'test_*.py'."""

import re
import struct
import tempfile
import unittest
from pathlib import Path

import convert_tmx as converter


class ConversionTests(unittest.TestCase):
    def test_original_content_matches_native_collision_cells(self):
        for number, config in converter.LEVELS.items():
            data = converter.parse_map(converter.SOURCE / "Maps" / f"{config[0]}.tmx")
            scene = (converter.DEST / "levels" / f"level_{number}.tscn").read_text()
            collision = scene.split('[node name="Collision"', 1)[1].split("[node", 1)[0]
            encoded = re.search(
                r"tile_map_data = PackedByteArray\((.*?)\)", collision
            ).group(1)
            raw = bytes(int(n) for n in encoded.split(", "))
            self.assertEqual(raw[:2], b"\0\0")
            actual = {(x, y) for x, y, *_ in struct.iter_unpack("<hhHHHH", raw[2:])}
            original = next(
                layer for layer in data["layers"] if layer["name"] == "Collision"
            )
            expected = {
                (i % data["width"], data["height"] - 1 - i // data["width"])
                for i, gid in enumerate(original["gids"])
                if gid
            }
            self.assertEqual(actual, expected, config[0])

    def test_preserve_original_rectangle_corner_and_hermes_start(self):
        data = converter.parse_map(converter.SOURCE / "Maps/levelone.tmx")
        self.assertEqual(data["objects"][0]["position"], [84.0, 242.0])
        self.assertEqual(data["objects"][1]["position"], [166.0, 196.0])

    def test_refuses_to_overwrite_godot_authoring(self):
        with tempfile.TemporaryDirectory() as directory:
            dest = Path(directory)
            (dest / "levels").mkdir()
            scene = dest / "levels/level_1.tscn"
            scene.write_text("edited by designer")
            with self.assertRaises(FileExistsError):
                converter.convert(dest)
            self.assertEqual(scene.read_text(), "edited by designer")

    def test_rejects_unknown_tmx_features(self):
        original = (converter.SOURCE / "Maps/levelone.tmx").read_text()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "map.tmx"
            for unsupported in ("<group/>", "<imagelayer/>"):
                path.write_text(original.replace("</map>", unsupported + "</map>"))
                with self.assertRaises(ValueError):
                    converter.parse_map(path)

    def test_projected_atlas_png_transparency_and_size(self):
        atlas = converter.DEST / "assets/terrain/treestileset_iso.png"
        width, height, rows = converter.read_rgb_png(atlas)
        self.assertEqual((width, height), (1024, 1024))
        self.assertEqual(rows[0][3], 0)  # Outside the first diamond.
        self.assertTrue(any(row[3::4].count(255) > 0 for row in rows))
        self.assertFalse(any(b"\xbf\x7b\xc7\xff" in row for row in rows))

    def test_serialization_is_native_version_zero(self):
        encoded = converter.tile_bytes([(1, 2, 3, 4, 5)])
        self.assertEqual(
            encoded, "PackedByteArray(0, 0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 0, 0)"
        )


if __name__ == "__main__":
    unittest.main()
