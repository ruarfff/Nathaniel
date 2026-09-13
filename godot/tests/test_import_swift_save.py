"""Run with python3 -m unittest discover -s godot/tests -p 'test_import*.py'."""

import importlib.util
import json
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "tools" / "import_swift_save.py"
SPEC = importlib.util.spec_from_file_location("import_swift_save", SCRIPT)
IMPORTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(IMPORTER)


class SwiftSaveExtractionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="nathaniel-swift-save-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.saved = {"saveVersion": 2, "levelNumber": 1, "displayName": "Synthetic save"}

    def test_explicit_json_preserves_source(self):
        source = self.directory / "source.json"
        payload = json.dumps(self.saved).encode()
        source.write_bytes(payload)
        self.assertEqual(IMPORTER.extract(source), self.saved)
        self.assertEqual(source.read_bytes(), payload)

    def test_exported_plist_extracts_only_requested_slot(self):
        source = self.directory / "export.plist"
        payload = plistlib.dumps({"save_slot_2": json.dumps(self.saved).encode(), "save_slot_metadata": b"ignored"})
        source.write_bytes(payload)
        self.assertEqual(IMPORTER.extract(source, 2), self.saved)
        with self.assertRaisesRegex(ValueError, "no NSData save_slot_1"):
            IMPORTER.extract(source, 1)
        self.assertEqual(source.read_bytes(), payload)

    def test_cli_refuses_existing_output_and_source(self):
        source = self.directory / "source.json"
        source.write_text(json.dumps(self.saved))
        output = self.directory / "output.json"
        command = [sys.executable, str(SCRIPT), str(source), str(output)]
        first = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(first.returncode, 0, first.stderr)
        saved_bytes = output.read_bytes()
        self.assertEqual(subprocess.run(command, capture_output=True).returncode, 1)
        self.assertEqual(output.read_bytes(), saved_bytes)
        source_bytes = source.read_bytes()
        same_source = subprocess.run([sys.executable, str(SCRIPT), str(source), str(source)], capture_output=True)
        self.assertEqual(same_source.returncode, 1)
        self.assertEqual(source.read_bytes(), source_bytes)

    def test_unknown_version_and_non_json_fail_without_output(self):
        source = self.directory / "source.json"
        output = self.directory / "output.json"
        for payload in [b"bad", b'{"saveVersion":99,"levelNumber":1}']:
            source.write_bytes(payload)
            result = subprocess.run([sys.executable, str(SCRIPT), str(source), str(output)], capture_output=True)
            self.assertEqual(result.returncode, 1)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
