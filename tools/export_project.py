"""Export from a private staged project and self-contained Godot editor.

No tracked preset, installed engine, global editor settings, or user save is
changed. Supply downloaded templates explicitly, or use the standard Godot
export-template directory. The helper never downloads or installs tools.
"""

from __future__ import annotations

import argparse
import configparser
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
VERSION = (PROJECT / ".godot-version").read_text().strip() + ".stable"
LOCAL_TEMPLATES = PROJECT / "test-artifacts/export-templates"


def stage_project(source: Path, destination: Path) -> None:
    """Copy game content only; repository tools and local outputs stay outside."""
    destination.mkdir()
    for filename in ("project.godot", "export_presets.cfg"):
        shutil.copy2(source / filename, destination / filename)
    for directory in ("assets", "levels", "resources", "scenes", "scripts"):
        shutil.copytree(
            source / directory,
            destination / directory,
            ignore=shutil.ignore_patterns(
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
                "*.pyc",
                ".DS_Store",
            ),
        )


def template_candidates(explicit: Path | None) -> list[Path]:
    if explicit is not None:
        return [explicit]
    candidates = [LOCAL_TEMPLATES]
    if sys.platform == "darwin":
        candidates.append(
            Path.home() / "Library/Application Support/Godot/export_templates" / VERSION
        )
    elif sys.platform == "win32":
        candidates.append(
            Path(os.environ.get("APPDATA", "")) / "Godot/export_templates" / VERSION
        )
    else:
        candidates.append(
            Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
            / "godot/export_templates"
            / VERSION
        )
    return candidates


def configure_unsigned_ios(path: Path) -> None:
    preset = configparser.RawConfigParser()
    preset.optionxform = str
    preset.read(path)
    for section in preset.sections():
        if section.endswith(".options"):
            continue
        if preset.get(section, "platform", fallback="") == '"iOS"':
            # This fake value satisfies project-only validation. It grants no
            # signing capability. Device provisioning remains a separate step.
            preset.set(
                section + ".options", "application/app_store_team_id", '"0000000000"'
            )
            preset.set(section + ".options", "application/export_project_only", "true")
    with path.open("w") as stream:
        preset.write(stream)


def export(
    platform: str,
    output: Path,
    godot: str,
    templates: Path | None,
    unsigned_ios: bool = False,
    release: bool = False,
) -> int:
    executable = shutil.which(godot)
    if executable is None:
        raise ValueError(f"Godot executable not found: {godot}")
    version = subprocess.check_output([executable, "--version"], text=True).strip()
    if not version.startswith(VERSION):
        raise ValueError(f"Expected Godot {VERSION}, found {version}")
    filename = {
        "macOS": "macos.zip",
        "iOS": "ios.zip",
        "Web": f"web_nothreads_{'release' if release else 'debug'}.zip",
    }[platform]
    template = next(
        (
            directory / filename
            for directory in template_candidates(templates)
            if (directory / filename).is_file()
        ),
        None,
    )
    if template is None:
        raise ValueError(
            f"Missing {VERSION}/{filename}. Use --templates DIRECTORY with the matching official templates."
        )
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="nathaniel-export-") as directory:
        staging = Path(directory)
        engine_dir = staging / "engine"
        engine_dir.mkdir()
        engine = engine_dir / ("godot.exe" if sys.platform == "win32" else "godot")
        shutil.copy2(Path(executable).resolve(), engine)
        (engine_dir / "_sc_").write_text("")
        template_dir = engine_dir / "editor_data/export_templates" / VERSION
        template_dir.mkdir(parents=True)
        (template_dir / filename).symlink_to(template.resolve())
        project = staging / "project"
        stage_project(PROJECT, project)
        if platform == "iOS" and unsigned_ios:
            configure_unsigned_ios(project / "export_presets.cfg")
        log_directory = output.parent.parent if platform == "Web" else output.parent
        log = log_directory / f"{platform.lower()}-export.log"
        print(
            f"Exporting {platform} with Godot {version}; isolated project and editor cache.",
            flush=True,
        )
        command = [
            str(engine),
            "--headless",
            "--path",
            str(project),
            "--export-release" if release else "--export-debug",
            platform,
            str(output),
            "--log-file",
            str(log),
        ]
        with log.with_suffix(".stdout.log").open("w") as stream:
            result = subprocess.run(
                command, stdout=stream, stderr=subprocess.STDOUT, check=False
            )
        error_output = log.with_suffix(".stdout.log").read_text(errors="replace")
        has_engine_error = "SCRIPT ERROR:" in error_output or "ERROR:" in error_output
        status = result.returncode or (1 if has_engine_error else 0)
        if status:
            print(f"Export failed ({status}). See {log}.", file=sys.stderr)
        else:
            artifact = output.with_suffix(".xcodeproj") if platform == "iOS" else output
            print(f"Export complete: {artifact}", flush=True)
        return status


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=("macOS", "iOS", "Web"))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument(
        "--templates",
        type=Path,
        default=Path(os.environ["GODOT_TEMPLATE_DIR"])
        if os.environ.get("GODOT_TEMPLATE_DIR")
        else None,
    )
    parser.add_argument(
        "--unsigned-ios",
        action="store_true",
        help="Export a local test Xcode project with a fake team; never sign",
    )
    parser.add_argument("--release", action="store_true")
    args = parser.parse_args()
    filename = {"macOS": "Nathaniel.app", "iOS": "Nathaniel.zip", "Web": "index.html"}[
        args.platform
    ]
    output = args.output or PROJECT / "exports" / args.platform.lower() / filename
    try:
        status = export(
            args.platform,
            output,
            args.godot,
            args.templates,
            args.unsigned_ios,
            args.release,
        )
    except (ValueError, OSError) as error:
        parser.error(str(error))
    raise SystemExit(status)


if __name__ == "__main__":
    main()
