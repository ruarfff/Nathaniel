#!/usr/bin/env python3
"""Test build commands with temporary stubs; never run Xcode or control an app."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent.parent


class BuildCommandTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nathaniel-build-tests-")
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.bin = self.directory / "bin"
        self.bin.mkdir()
        self.log = self.directory / "commands.jsonl"
        self.derived = self.directory / "Derived Data"
        self.env = dict(os.environ)
        self.env.update(
            PATH=str(self.bin) + os.pathsep + self.env["PATH"],
            STUB_LOG=str(self.log),
            STUB_STALE_APP=str(self.directory / "stale/Nathaniel.app"),
        )
        stub = self.bin / "stub"
        stub.write_text(
            f"#!{sys.executable}\n"
            "import json, os, pathlib, sys\n"
            "name = pathlib.Path(sys.argv[0]).name\n"
            "args = sys.argv[1:]\n"
            "with open(os.environ['STUB_LOG'], 'a') as log:\n"
            "    log.write(json.dumps([name, *args]) + '\\n')\n"
            "if name == os.environ.get('STUB_FAIL'):\n"
            "    sys.exit(42)\n"
            "if name == 'find':\n"
            "    print(os.environ['STUB_STALE_APP'])\n"
            "if name == 'xcodebuild' and '-derivedDataPath' in args:\n"
            "    root = pathlib.Path(args[args.index('-derivedDataPath') + 1])\n"
            "    config = args[args.index('-configuration') + 1]\n"
            "    if any('iOS Simulator' in arg for arg in args):\n"
            "        config += '-iphonesimulator'\n"
            "    (root / 'Build/Products' / config / 'Nathaniel.app').mkdir(parents=True, exist_ok=True)\n"
            "if name == 'curl':\n"
            "    print('{\"status\":\"ok\",\"scene\":\"MainMenuScene\"}')\n"
        )
        stub.chmod(0o755)
        for name in ["xcodebuild", "xcrun", "open", "swiftlint", "swiftformat", "find", "pkill", "sleep", "curl"]:
            (self.bin / name).symlink_to(stub)

    def run_make(self, target, failed_tool=None):
        if failed_tool:
            self.env["STUB_FAIL"] = failed_tool
        return subprocess.run(
            ["make", "--file", str(ROOT / "Makefile"), target, f"DERIVED_DATA_PATH={self.derived}"],
            cwd=ROOT, env=self.env, capture_output=True, text=True, timeout=20,
        )

    def commands(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_ios_run_preserves_saved_data_and_installs_its_build(self):
        result = self.run_make("ios")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        commands = self.commands()
        self.assertFalse(any(command[:3] == ["xcrun", "simctl", "uninstall"] for command in commands))
        installed = next(command for command in commands if command[:3] == ["xcrun", "simctl", "install"])
        self.assertEqual(installed[-1], str(self.derived / "Build/Products/Debug-iphonesimulator/Nathaniel.app"))

    def test_ios_build_failure_prevents_install_and_launch(self):
        result = self.run_make("ios", "xcodebuild")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(command[:3] == ["xcrun", "simctl", action]
                             for command in self.commands() for action in ["install", "launch", "uninstall"]))

    def test_macos_run_uses_its_own_build(self):
        result = self.run_make("macos")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        opened = next(command for command in self.commands() if command[0] == "open")
        self.assertEqual(opened[-1], str(self.derived / "Build/Products/Debug/Nathaniel.app"))

    def test_quality_failures_fail_make(self):
        for target, tool in [("lint", "swiftlint"), ("format", "swiftformat")]:
            with self.subTest(target=target):
                result = self.run_make(target, tool)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_lint_uses_current_cli_paths_and_includes_tests(self):
        result = self.run_make("lint")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        command = next(command for command in self.commands() if command[0] == "swiftlint")
        self.assertNotIn("--path", command)
        self.assertIn("NathanielTests", command)

    def test_unit_target_runs_xctest(self):
        result = self.run_make("test-unit")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        command = next(command for command in self.commands() if command[0] == "xcodebuild")
        self.assertIn("test", command)
        self.assertEqual(command[command.index("-derivedDataPath") + 1], str(self.derived))

    def test_macos_smoke_build_failure_does_not_launch_an_old_app(self):
        self.env["STUB_FAIL"] = "xcodebuild"
        self.env["DERIVED_DATA_PATH"] = str(self.derived)
        result = subprocess.run(
            ["bash", str(ROOT / "scripts/test-macos.sh"), "--screenshots-dir", str(self.directory / "screenshots")],
            cwd=ROOT, env=self.env, capture_output=True, text=True, timeout=20,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(command[0] == "open" for command in self.commands()))


if __name__ == "__main__":
    unittest.main()
