"""Godot may exit zero after a script error. Make such failures fail the check."""

import subprocess
import sys


def main():
    process = subprocess.Popen(sys.argv[1:], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    errors = False
    for line in process.stdout:
        print(line, end="", flush=True)
        if "SCRIPT ERROR:" in line or line.startswith("ERROR:"):
            errors = True
    result = process.wait()
    return result or (1 if errors else 0)


if __name__ == "__main__":
    raise SystemExit(main())
