"""Run the MCP adapter against an isolated Godot process."""

import pathlib
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request


def main():
    project = pathlib.Path(__file__).resolve().parents[1]
    executable = sys.argv[1] if len(sys.argv) > 1 else "godot"
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    endpoint = f"http://127.0.0.1:{port}"
    with tempfile.TemporaryDirectory(prefix="nathaniel-mcp-") as directory:
        log_path = pathlib.Path(directory) / "game.log"
        with log_path.open("w") as log:
            process = subprocess.Popen([
                executable, "--headless", "--path", str(project), "--",
                f"--debug-port={port}", f"--storage-dir={directory}/saves",
            ], stdout=log, stderr=subprocess.STDOUT)
            result = 1
            try:
                deadline = time.monotonic() + 20
                while time.monotonic() < deadline and process.poll() is None:
                    try:
                        with urllib.request.urlopen(endpoint + "/health", timeout=0.5):
                            break
                    except (OSError, urllib.error.URLError):
                        time.sleep(0.1)
                else:
                    raise RuntimeError("Isolated Godot debug server did not start")
                result = subprocess.run([
                    "node", str(project / "tests/test_live_mcp.mjs"), endpoint,
                ], check=False, timeout=60).returncode
            finally:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        output = log_path.read_text()
        if "SCRIPT ERROR:" in output or "\nERROR:" in output:
            print(output)
            return 1
        return result


if __name__ == "__main__":
    raise SystemExit(main())
