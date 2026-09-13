"""One-time, opt-in TMX -> editable Godot content conversion (Python stdlib).

Run with --force only when intentionally replacing edited Godot levels.
No invocation is made by the game, editor import, or normal build commands.
"""

from __future__ import annotations

import argparse
import base64
import gzip
import json
import shutil
import struct
import xml.etree.ElementTree as ET
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Nathaniel Shared/Assets"
DEST = ROOT / "godot"
LEVELS = {
    0: ("survivalmap", 0, 30, False, True, -1),
    1: ("levelone", 3, 30, True, False, 2),
    2: ("leveltwo", 3, 30, True, False, 3),
    3: ("levelthree", 3, 30, True, False, 4),
    4: ("survivalmap", 3, 0, True, True, 5),
    5: ("survivalmap", 3, 0, True, True, -1),
}
KINDS = {"Gr": "grunt", "So": "soldier", "Sp": "spawner", "Bo": "boss"}


def parse_map(path: Path) -> dict:
    root = ET.parse(path).getroot()
    if root.get("orientation") != "orthogonal" or root.get("infinite", "0") != "0":
        raise ValueError(f"Unsupported map orientation/infinite map: {path}")
    width, height = int(root.get("width")), int(root.get("height"))
    tile = int(root.get("tilewidth"))
    if tile != 32 or int(root.get("tileheight")) != tile:
        raise ValueError("Original migration expects square 32px tiles")
    allowed = {"tileset", "layer", "objectgroup"}
    if any(node.tag not in allowed for node in root):
        raise ValueError("Unsupported top-level TMX feature; review before conversion")
    tilesets = []
    for ts in root.findall("tileset"):
        if ts.get("source") or len(ts) != 1 or next(iter(ts)).tag != "image":
            raise ValueError("External tilesets or tile properties are not supported")
        image = ts.find("image")
        tilesets.append(
            {
                "first_gid": int(ts.get("firstgid")),
                "name": ts.get("name"),
                "image": image.get("source"),
                "trans": image.get("trans"),
                "columns": int(image.get("width")) // tile,
                "rows": int(image.get("height")) // tile,
            }
        )
    layers = []
    for layer in root.findall("layer"):
        data = layer.find("data")
        if data.attrib != {"encoding": "base64", "compression": "gzip"}:
            raise ValueError("Only the original base64+gzip TMX encoding is supported")
        raw = gzip.decompress(base64.b64decode(data.text))
        if len(raw) != width * height * 4:
            raise ValueError("Layer dimensions or tile data length mismatch")
        gids = list(struct.unpack(f"<{width * height}I", raw))
        if any(gid & 0xF0000000 for gid in gids):
            raise ValueError("TMX tile flip/rotation flags need an explicit conversion")
        layers.append({"name": layer.get("name"), "gids": gids})
    objects = []
    for group in root.findall("objectgroup"):
        if group.get("name") != "Objects":
            raise ValueError("Unexpected object group")
        for obj in group:
            if obj.tag != "object" or len(obj) or obj.get("rotation", "0") != "0":
                raise ValueError("Only unrotated rectangle objects are supported")
            name = obj.get("name")
            kind = (
                name.lower() if name in ("Nathaniel", "Hermes") else KINDS.get(name[:2])
            )
            if kind is None:
                raise ValueError(
                    f"Unknown original object {name!r}; do not silently omit it"
                )
            # Match GameScene/EnemyManager: x,y is used, NOT rectangle center.
            objects.append(
                {
                    "name": name,
                    "kind": kind,
                    "position": [
                        float(obj.get("x")),
                        height * tile - float(obj.get("y")),
                    ],
                }
            )
    return {
        "width": width,
        "height": height,
        "tile_size": tile,
        "tilesets": tilesets,
        "layers": layers,
        "objects": objects,
    }


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    return a if pa <= pb and pa <= pc else b if pb <= pc else c


def read_rgb_png(path: Path) -> tuple[int, int, list[bytes]]:
    """Decode only the original terrain's non-interlaced 8-bit RGB/RGBA PNGs."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("Not a PNG")
    compressed = bytearray()
    cursor = 8
    while cursor < len(data):
        count = struct.unpack_from(">I", data, cursor)[0]
        kind = data[cursor + 4 : cursor + 8]
        body = data[cursor + 8 : cursor + 8 + count]
        if kind == b"IHDR":
            width, height, depth, color, compression, filtering, interlace = (
                struct.unpack(">IIBBBBB", body)
            )
            if (
                depth != 8
                or color not in (2, 6)
                or compression
                or filtering
                or interlace
            ):
                raise ValueError(
                    "Unsupported PNG format; terrain must be 8-bit RGB/RGBA"
                )
        elif kind == b"IDAT":
            compressed.extend(body)
        cursor += count + 12
    channels = 3 if color == 2 else 4
    stride = width * channels
    raw = zlib.decompress(compressed)
    rows = []
    previous = bytearray(stride)
    for y in range(height):
        offset = y * (stride + 1)
        mode = raw[offset]
        row = bytearray(raw[offset + 1 : offset + 1 + stride])
        for x in range(stride):
            left = row[x - channels] if x >= channels else 0
            up = previous[x]
            upper_left = previous[x - channels] if x >= channels else 0
            if mode == 1:
                predictor = left
            elif mode == 2:
                predictor = up
            elif mode == 3:
                predictor = (left + up) // 2
            elif mode == 4:
                predictor = _paeth(left, up, upper_left)
            elif mode == 0:
                predictor = 0
            else:
                raise ValueError("Unknown PNG filter")
            row[x] = (row[x] + predictor) & 255
        previous = row
        if channels == 3:
            rgba = bytearray(width * 4)
            for x in range(width):
                rgba[x * 4 : x * 4 + 4] = row[x * 3 : x * 3 + 3] + b"\xff"
            rows.append(bytes(rgba))
        else:
            rows.append(bytes(row))
    return width, height, rows


def write_rgba_png(path: Path, width: int, height: int, rows: list[bytes]) -> None:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + kind
            + data
            + struct.pack(">I", zlib.crc32(kind + data))
        )

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    pixels = zlib.compress(b"".join(b"\0" + row for row in rows), 9)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", pixels)
        + chunk(b"IEND", b"")
    )


def project_atlas(source: Path, target: Path, transparent: str | None) -> None:
    width, height, original = read_rgb_png(source)
    out = [bytearray(width * 2 * 4) for _ in range(height)]
    key = bytes.fromhex(transparent) if transparent else None
    # Original texture y points down, logical world y points up. Inverse sample
    # each 64x32 diamond so adjacent source tiles join with the same projection.
    samples = []
    for y in range(32):
        for x in range(64):
            u = (x + 0.5) * 0.5 + (y + 0.5) - 16
            v = (x + 0.5) * 0.5 - (y + 0.5) + 16
            if 0 <= u < 32 and 0 <= v < 32:
                samples.append((x, y, int(u), int(v)))
    for tile_y in range(height // 32):
        for tile_x in range(width // 32):
            for x, y, u, v in samples:
                sx = (tile_x * 32 + u) * 4
                pixel = original[tile_y * 32 + v][sx : sx + 4]
                if key is not None and pixel[:3] == key:
                    continue
                dx = (tile_x * 64 + x) * 4
                out[tile_y * 32 + y][dx : dx + 4] = pixel
    write_rgba_png(target, width * 2, height, out)


def vec(point: list[float] | tuple[float, float]) -> str:
    return f"Vector2({point[0]:g}, {point[1]:g})"


def projection(point: list[float]) -> tuple[float, float]:
    x, y = point
    return x - y, (x + y) / 2


def tile_bytes(entries: list[tuple[int, ...]]) -> str:
    # Native TileMapLayer format 0: uint16 version followed by six uint16 fields
    # (cell x, cell y, source, atlas x, atlas y, alternative) per cell.
    data = b"\0\0" + b"".join(
        struct.pack("<hhHHHH", *entry, *([0] if len(entry) == 5 else []))
        for entry in entries
    )
    return "PackedByteArray(" + ", ".join(str(value) for value in data) + ")"


def write_tileset(data: dict, name: str, dest: Path) -> None:
    lines = ['[gd_resource type="TileSet" format=3]', ""]
    for i, ts in enumerate(data["tilesets"]):
        lines.append(
            f'[ext_resource type="Texture2D" path="res://assets/terrain/{ts["name"]}_iso.png" id="{i + 1}"]'
        )
    lines.append("")
    for i, ts in enumerate(data["tilesets"]):
        lines.extend(
            [
                f'[sub_resource type="TileSetAtlasSource" id="Atlas_{i}"]',
                f'texture = ExtResource("{i + 1}")',
                "texture_region_size = Vector2i(64, 32)",
            ]
        )
        for y in range(ts["rows"]):
            for x in range(ts["columns"]):
                lines.append(f"{x}:{y}/0 = 0")
                if scenery_region(ts["name"], x, y) is not None:
                    lines.extend(
                        [f"{x}:{y}/1 = 1", f"{x}:{y}/1/modulate = Color(1, 1, 1, 0)"]
                    )
        lines.append("")
    lines.extend(
        [
            "[resource]",
            "tile_shape = 1",
            "tile_layout = 5",
            "tile_size = Vector2i(64, 32)",
        ]
    )
    for i in range(len(data["tilesets"])):
        lines.append(f'sources/{i} = SubResource("Atlas_{i}")')
    (dest / "resources" / f"{name}_tileset.tres").write_text("\n".join(lines) + "\n")


def scenery_region(name: str, x: int, y: int) -> tuple[int, int, int, int] | None:
    """Hand-verified object rectangles in the original tree/windmill atlases."""
    if name == "treestileset":
        if y < 24:
            return x // 4 * 4, y // 4 * 4, 4, 4
        if y < 30 and x < 9:
            return x // 3 * 3, 24 + (y - 24) // 3 * 3, 3, 3
    if name == "windmilltileset":
        if y < 12 and x < 12:
            return x // 6 * 6, y // 6 * 6, 6, 6
        if 19 <= y < 25 and x < 14:
            return x // 7 * 7, 19, 7, 6
    return None


def extract_scenery(data: dict, name: str, dest: Path) -> list[dict]:
    groups = {}
    for layer in data["layers"]:
        for index, gid in enumerate(layer["gids"]):
            if not gid:
                continue
            source = max(
                i for i, ts in enumerate(data["tilesets"]) if ts["first_gid"] <= gid
            )
            ts = data["tilesets"][source]
            local = gid - ts["first_gid"]
            ax, ay = local % ts["columns"], local // ts["columns"]
            region = scenery_region(ts["name"], ax, ay)
            if region is None:
                continue
            rx, ry, rw, rh = region
            mx, my = index % data["width"], index // data["width"]
            key = (source, mx - (ax - rx), my - (ay - ry), *region)
            groups.setdefault(key, set()).add((ax - rx, ay - ry))
    result = []
    image_cache = {}
    for index, (key, cells) in enumerate(sorted(groups.items())):
        source, mx, my, rx, ry, rw, rh = key
        ts = data["tilesets"][source]
        if source not in image_cache:
            image_cache[source] = read_rgb_png(SOURCE / "Maps" / ts["image"])[2]
        original = image_cache[source]
        transparent = bytes.fromhex(ts["trans"])
        width, height = rw * 32, rh * 32
        rows = [bytearray(width * 4) for _ in range(height)]
        for cx, cy in sorted(cells):
            for y in range(32):
                for x in range(32):
                    sx = ((rx + cx) * 32 + x) * 4
                    pixel = original[(ry + cy) * 32 + y][sx : sx + 4]
                    if pixel[:3] == transparent:
                        continue
                    dx = (cx * 32 + x) * 4
                    rows[cy * 32 + y][dx : dx + 4] = pixel
        filename = f"{name}_{index:03d}.png"
        write_rgba_png(dest / "assets/scenery" / filename, width, height, rows)
        # Original trees have a short transparent margin below the trunk.
        foot_y = height - (12 if ts["name"] == "treestileset" else 20)
        logical = [mx * 32 + width / 2, data["height"] * 32 - (my * 32 + foot_y)]
        result.append(
            {
                "texture": filename,
                "position": projection(logical),
                "offset": (-width / 2, -foot_y),
                "source": ts["name"],
            }
        )
    return result


def write_level(
    data: dict, number: int, dest: Path, scenery: list[dict] | None = None
) -> None:
    map_name, lives, resources, boss, wave, next_level = LEVELS[number]
    lines = [
        "[gd_scene format=3]",
        "",
        '[ext_resource type="Script" path="res://scripts/content/level.gd" id="1"]',
        '[ext_resource type="Script" path="res://scripts/content/level_definition.gd" id="2"]',
        f'[ext_resource type="TileSet" path="res://resources/{map_name}_tileset.tres" id="3"]',
        '[ext_resource type="Script" path="res://scripts/content/spawn_marker.gd" id="4"]',
        "",
        '[sub_resource type="Resource" id="LevelDefinition"]',
        'script = ExtResource("2")',
        f"number = {number}",
        f'title = "{"Survival" if number == 0 else f"Campaign {number}"}"',
        f"width = {data['width']}",
        f"height = {data['height']}",
        "tile_size = 32",
        f"starting_lives = {lives}",
        f"starting_resources = {resources}",
        f"has_boss = {str(boss).lower()}",
        f"wave_based = {str(wave).lower()}",
        f"next_level = {next_level}",
        f'source_map = "{map_name}.tmx"',
        "",
        f'[node name="Level{number}" type="Node2D"]',
        "texture_filter = 1",
        'script = ExtResource("1")',
        'definition = SubResource("LevelDefinition")',
        "",
    ]
    # Add texture resources before subresources, preserving native scene structure.
    scenery = scenery or []
    resource_lines = [
        f'[ext_resource type="Texture2D" path="res://assets/scenery/{prop["texture"]}" id="Prop_{i}"]'
        for i, prop in enumerate(scenery)
    ]
    lines[6:6] = resource_lines
    for layer in data["layers"]:
        entries = []
        for index, gid in enumerate(layer["gids"]):
            if not gid:
                continue
            source = max(
                i for i, ts in enumerate(data["tilesets"]) if ts["first_gid"] <= gid
            )
            ts = data["tilesets"][source]
            local = gid - ts["first_gid"]
            if local >= ts["columns"] * ts["rows"]:
                raise ValueError("Tile GID outside tileset")
            entries.append(
                (
                    index % data["width"],
                    data["height"] - 1 - index // data["width"],
                    source,
                    local % ts["columns"],
                    local // ts["columns"],
                    1
                    if scenery_region(
                        ts["name"], local % ts["columns"], local // ts["columns"]
                    )
                    else 0,
                )
            )
        lines.extend(
            [
                f'[node name="{layer["name"]}" type="TileMapLayer" parent="."]',
                "position = Vector2(-32, 0)",
                "z_index = -20",
                'tile_set = ExtResource("3")',
                "collision_enabled = false",
                "navigation_enabled = false",
                f"tile_map_data = {tile_bytes(entries)}",
                "",
            ]
        )
    lines.extend(
        ['[node name="Scenery" type="Node2D" parent="."]', "y_sort_enabled = true", ""]
    )
    for i, prop in enumerate(scenery):
        lines.extend(
            [
                f'[node name="Scenery{i}" type="Sprite2D" parent="Scenery"]',
                f"position = {vec(prop['position'])}",
                f'texture = ExtResource("Prop_{i}")',
                "centered = false",
                f"offset = {vec(prop['offset'])}",
                "",
            ]
        )
    lines.extend(['[node name="Spawns" type="Node2D" parent="."]', ""])
    for i, obj in enumerate(data["objects"]):
        lines.extend(
            [
                f'[node name="{obj["name"]}{i}" type="Marker2D" parent="Spawns"]',
                f"position = {vec(projection(obj['position']))}",
                'script = ExtResource("4")',
                f'kind = "{obj["kind"]}"',
                f'label = "{obj["name"]}"',
                "",
            ]
        )
    lines.extend(
        [
            '[node name="Objectives" type="Node2D" parent="."]',
            "",
            '[node name="VictoryRule" type="Marker2D" parent="Objectives"]',
            "position = Vector2(0, -64)",
            'script = ExtResource("4")',
            'kind = "objective"',
            f'label = "{"Defeat the boss" if boss else "Survive endless waves"}"',
            "",
        ]
    )
    (dest / "levels" / f"level_{number}.tscn").write_text("\n".join(lines))


def convert(dest: Path, force: bool = False) -> dict:
    if list((dest / "levels").glob("level_*.tscn")) and not force:
        raise FileExistsError(
            "Godot levels already exist and are authoritative. Use --force only to discard their edits."
        )
    for directory in (
        "assets/terrain",
        "assets/scenery",
        "assets/Sprites",
        "assets/Audio",
        "resources",
        "levels",
    ):
        (dest / directory).mkdir(parents=True, exist_ok=True)
    for directory in ("Sprites", "Audio"):
        shutil.copytree(
            SOURCE / directory, dest / "assets" / directory, dirs_exist_ok=True
        )
    maps = {
        name: parse_map(SOURCE / "Maps" / f"{name}.tmx")
        for name in sorted({c[0] for c in LEVELS.values()})
    }
    atlases = {ts["name"]: ts for data in maps.values() for ts in data["tilesets"]}
    for ts in atlases.values():
        project_atlas(
            SOURCE / "Maps" / ts["image"],
            dest / "assets/terrain" / f"{ts['name']}_iso.png",
            ts["trans"],
        )
    for name, data in maps.items():
        write_tileset(data, name, dest)
    scenery = {name: extract_scenery(data, name, dest) for name, data in maps.items()}
    for number, config in LEVELS.items():
        write_level(maps[config[0]], number, dest, scenery[config[0]])
    report = {
        name: {
            "width": m["width"],
            "height": m["height"],
            "blocked": sum(
                bool(gid)
                for layer in m["layers"]
                if layer["name"] == "Collision"
                for gid in layer["gids"]
            ),
            "objects": m["objects"],
            "layers": [layer["name"] for layer in m["layers"]],
        }
        for name, m in maps.items()
    }
    (dest / "tools/conversion_inventory.json").parent.mkdir(parents=True, exist_ok=True)
    (dest / "tools/conversion_inventory.json").write_text(
        json.dumps(report, indent=2) + "\n"
    )
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--force",
        action="store_true",
        help="Explicitly discard all Godot level/tileset edits",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEST,
        help="Alternative output directory for conversion checks",
    )
    args = parser.parse_args()
    try:
        report = convert(args.output.resolve(), args.force)
    except (ValueError, FileExistsError) as error:
        parser.error(str(error))
    print(
        f"Converted {len(report)} original maps to six editable Godot level scenes in {args.output}."
    )


if __name__ == "__main__":
    main()
