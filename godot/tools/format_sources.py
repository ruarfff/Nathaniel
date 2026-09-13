"""Normalize whitespace without installing or updating a managed developer tool.

Godot's own parser validates GDScript. Keep tab indentation, remove trailing
whitespace and preserve a single final newline in project text files.
"""

import pathlib
import sys


def main():
    root = pathlib.Path(__file__).resolve().parents[1]
    check = "--check" in sys.argv
    changed = []
    for path in sorted(root.rglob("*")):
        if ".godot" in path.parts or "exports" in path.parts or path.suffix not in {".gd", ".tscn", ".tres", ".godot", ".cfg", ".py"}:
            continue
        original = path.read_text()
        formatted = "\n".join(line.rstrip() for line in original.rstrip().splitlines()) + "\n"
        if original != formatted:
            changed.append(str(path.relative_to(root)))
            if not check:
                path.write_text(formatted)
    if changed:
        print(("Requires formatting: " if check else "Formatted: ") + ", ".join(changed))
    return 1 if check and changed else 0


if __name__ == "__main__":
    raise SystemExit(main())
