"""Require the exact Godot release used by this project, including vendor builds."""

import pathlib
import subprocess
import sys


def main():
    expected = (pathlib.Path(__file__).resolve().parents[1] / ".godot-version").read_text().strip()
    executable = sys.argv[1] if len(sys.argv) > 1 else "godot"
    try:
        actual = subprocess.check_output([executable, "--version"], text=True).strip()
    except (OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"Cannot run Godot: {error}") from error
    if not actual.startswith(expected + ".stable"):
        raise SystemExit(f"Godot {expected}-stable required; found {actual}")
    print(f"Godot {actual}")


if __name__ == "__main__":
    main()
