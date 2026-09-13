"""Normalize whitespace without installing or updating a managed developer tool.

Godot's own parser validates GDScript. Keep tab indentation, remove trailing
whitespace and preserve a single final newline in project text files.
"""

import os
import pathlib
import sys


def format_project(root: pathlib.Path, check: bool = False) -> list[str]:
    """Normalize owned source files without traversing dependencies or outputs."""
    paths = [root / "project.godot", root / "export_presets.cfg"]
    excluded = {
        ".git",
        ".godot",
        ".venv",
        "venv",
        "node_modules",
        "__pycache__",
        "test-artifacts",
        "exports",
        "build",
        "dist",
    }
    for directory in (
        "assets",
        "levels",
        "resources",
        "scenes",
        "scripts",
        "tests",
        "tools",
    ):
        for current, directories, files in os.walk(root / directory):
            directories[:] = [name for name in directories if name not in excluded]
            paths.extend(pathlib.Path(current) / name for name in files)
    changed = []
    for path in sorted(paths):
        if (
            not path.is_file()
            or path.is_symlink()
            or path.suffix not in {".gd", ".tscn", ".tres", ".godot", ".cfg", ".py"}
        ):
            continue
        original = path.read_text()
        formatted = (
            "\n".join(line.rstrip() for line in original.rstrip().splitlines()) + "\n"
        )
        if original != formatted:
            changed.append(str(path.relative_to(root)))
            if not check:
                path.write_text(formatted)
    return changed


def main():
    check = "--check" in sys.argv
    changed = format_project(pathlib.Path(__file__).resolve().parents[1], check)
    if changed:
        print(
            ("Requires formatting: " if check else "Formatted: ") + ", ".join(changed)
        )
    return 1 if check and changed else 0


if __name__ == "__main__":
    raise SystemExit(main())
