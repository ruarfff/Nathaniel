#!/usr/bin/env python3
"""Extract one explicitly supplied Swift save; never access live preferences."""

import argparse
import json
import os
import plistlib
from pathlib import Path

MAX_BYTES = 16 * 1024 * 1024


def extract(source: Path, slot: int | None = None) -> dict:
    """Read an exported JSON save or an exported plist's NSData save slot."""
    if source.stat().st_size > MAX_BYTES:
        raise ValueError("Source exceeds 16 MiB")
    payload = source.read_bytes()
    if slot is not None:
        preferences = plistlib.loads(payload)
        if not isinstance(preferences, dict):
            raise ValueError("Expected an exported preferences dictionary")
        payload = preferences.get(f"save_slot_{slot}")
        if not isinstance(payload, bytes):
            raise ValueError(f"Exported plist has no NSData save_slot_{slot}")
    state = json.loads(payload)
    if not isinstance(state, dict) or state.get("saveVersion") not in (1, 2):
        raise ValueError("Expected a Swift SavedGameState, version 1 or 2")
    if state.get("levelNumber") not in range(6):
        raise ValueError("Invalid Swift levelNumber")
    return state


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Explicit exported JSON or plist path")
    parser.add_argument("output", type=Path, help="New standalone JSON file; must not exist")
    parser.add_argument("--plist-slot", type=int, choices=(1, 2, 3))
    args = parser.parse_args()
    try:
        state = extract(args.source, args.plist_slot)
        serialized = json.dumps(state, indent=2, allow_nan=False) + "\n"
        # O_EXCL also rejects symlinks. Source and existing output are never replaced.
        with args.output.open("x", encoding="utf-8") as output:
            output.write(serialized)
            output.flush()
            os.fsync(output.fileno())
    except (OSError, ValueError, TypeError, plistlib.InvalidFileException) as error:
        parser.exit(1, f"Save extraction failed: {error}\n")
    print(f"Extracted Swift level {state['levelNumber']} save to {args.output}")


if __name__ == "__main__":
    main()
