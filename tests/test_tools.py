"""Filesystem regressions for project formatting and isolated export staging."""

import contextlib
import io
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools import export_project, format_sources


class ProjectToolTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="nathaniel-tools-test-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.source = self.directory / "source"
        self.source.mkdir()
        self.write("project.godot", "config_version=5\n")
        self.write(
            "export_presets.cfg",
            '[preset.0]\nplatform="iOS"\n[preset.0.options]\napplication/app_store_team_id=""\napplication/export_project_only=false\napplication/bundle_identifier="dev.ruarfff.nathaniel.godot"\n',
        )
        for name in ("assets", "levels", "resources", "scenes", "scripts"):
            (self.source / name).mkdir()

    def write(self, relative, content):
        path = self.source / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def test_export_stages_only_runtime_content(self):
        self.write("assets/sprites/actor.png", "image fixture")
        self.write("assets/sprites/actor.png.import", "native import settings")
        self.write("scripts/domain/game.gd", "extends RefCounted\n")
        self.write("scenes/main.tscn", "native scene fixture")
        excluded = (
            "docs/example.gd",
            "game-mcp-server/node_modules/dependency.gd",
            "tests/fixture.tscn",
            "tools/helper.py",
            "test-artifacts/capture.png",
            "exports/release/game.pck",
            ".godot/imported/texture.ctex",
            "scripts/vendor/node_modules/dependency.gd",
            "assets/test-artifacts/capture.png",
            "scripts/__pycache__/helper.pyc",
            "assets/build/output.png",
        )
        for relative in excluded:
            self.write(relative, "must stay outside the staged project")
        destination = self.directory / "staged"
        export_project.stage_project(self.source, destination)
        files = {
            str(path.relative_to(destination))
            for path in destination.rglob("*")
            if path.is_file()
        }
        self.assertEqual(
            files,
            {
                "project.godot",
                "export_presets.cfg",
                "assets/sprites/actor.png",
                "assets/sprites/actor.png.import",
                "scripts/domain/game.gd",
                "scenes/main.tscn",
            },
        )
        self.assertTrue(
            all((self.source / relative).is_file() for relative in excluded)
        )

    def test_unsigned_export_changes_only_staged_preset(self):
        original = (self.source / "export_presets.cfg").read_bytes()
        destination = self.directory / "staged"
        export_project.stage_project(self.source, destination)
        export_project.configure_unsigned_ios(destination / "export_presets.cfg")
        self.assertEqual((self.source / "export_presets.cfg").read_bytes(), original)
        staged = (destination / "export_presets.cfg").read_text()
        self.assertIn('application/app_store_team_id = "0000000000"', staged)
        self.assertIn("application/export_project_only = true", staged)
        self.assertIn(
            'application/bundle_identifier = "dev.ruarfff.nathaniel.godot"', staged
        )

    def test_formatter_limits_scope_and_check_does_not_write(self):
        owned = self.write("scripts/domain/game.gd", "extends RefCounted  \n\n")
        tool = self.write("tools/example.py", "value = 1  \n\n")
        excluded = (
            "docs/example.gd",
            "game-mcp-server/node_modules/example.py",
            "test-artifacts/example.gd",
            "exports/example.cfg",
            "scripts/vendor/node_modules/example.py",
            "scripts/build/example.gd",
        )
        for relative in excluded:
            self.write(relative, "untouched  \n\n")
        expected = ["scripts/domain/game.gd", "tools/example.py"]
        self.assertEqual(
            format_sources.format_project(self.source, check=True), expected
        )
        self.assertEqual(owned.read_text(), "extends RefCounted  \n\n")
        self.assertEqual(tool.read_text(), "value = 1  \n\n")
        self.assertEqual(format_sources.format_project(self.source), expected)
        self.assertEqual(owned.read_text(), "extends RefCounted\n")
        self.assertEqual(tool.read_text(), "value = 1\n")
        self.assertEqual(format_sources.format_project(self.source, check=True), [])
        for relative in excluded:
            self.assertEqual((self.source / relative).read_text(), "untouched  \n\n")

    def test_export_rejects_engine_error_even_with_zero_exit_status(self):
        engine = self.directory / "godot"
        engine.write_text("local engine stand-in")
        templates = self.directory / "templates"
        templates.mkdir()
        (templates / "ios.zip").write_bytes(b"template stand-in")
        original = (self.source / "export_presets.cfg").read_bytes()

        def failed_export(command, stdout, **_kwargs):
            staged = Path(command[command.index("--path") + 1])
            self.assertTrue((staged / "scenes").is_dir())
            self.assertNotEqual((staged / "export_presets.cfg").read_bytes(), original)
            stdout.write("ERROR: test export failure\n")
            return subprocess.CompletedProcess(command, 0)

        with (
            mock.patch.object(export_project, "PROJECT", self.source),
            mock.patch.object(export_project.shutil, "which", return_value=str(engine)),
            mock.patch.object(
                export_project.subprocess,
                "check_output",
                return_value=export_project.VERSION,
            ),
            mock.patch.object(
                export_project.subprocess, "run", side_effect=failed_export
            ),
            contextlib.redirect_stdout(io.StringIO()),
            contextlib.redirect_stderr(io.StringIO()),
        ):
            status = export_project.export(
                "iOS",
                self.directory / "output/Nathaniel.zip",
                str(engine),
                templates,
                unsigned_ios=True,
            )
        self.assertEqual(status, 1)
        self.assertEqual((self.source / "export_presets.cfg").read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
