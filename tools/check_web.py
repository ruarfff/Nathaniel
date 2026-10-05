"""Check the HTTP contract of the deployed Nathaniel demo or local image."""

import json
import re
import sys
import time
import urllib.error
import urllib.request


def check_web(base_url: str) -> None:
    base_url = base_url.rstrip("/")
    for attempt in range(20):
        try:
            with urllib.request.urlopen(base_url + "/healthz", timeout=5) as response:
                assert response.status == 200 and response.read() == b"ok"
            break
        except (urllib.error.URLError, ConnectionError, TimeoutError):
            if attempt == 19:
                raise
            time.sleep(1)

    with urllib.request.urlopen(base_url + "/", timeout=10) as response:
        html = response.read().decode()
        assert "<title>Nathaniel</title>" in html
        assert response.headers.get("Cache-Control") == "no-cache"
    start = html.index("const GODOT_CONFIG = ") + len("const GODOT_CONFIG = ")
    config, _ = json.JSONDecoder().raw_decode(html[start:])
    pack = config["mainPack"]
    assert re.fullmatch(r"index-[0-9a-f]{16}\.pck", pack), pack

    for path, content_type in (
        ("index.js", "text/javascript"),
        ("index.wasm", "application/wasm"),
        (pack, "application/octet-stream"),
    ):
        request = urllib.request.Request(base_url + "/" + path, method="HEAD")
        with urllib.request.urlopen(request, timeout=10) as response:
            assert response.status == 200
            assert response.headers.get_content_type() == content_type, path
            assert response.headers.get("Cache-Control") == "no-cache", path
        if path.endswith((".wasm", ".pck")):
            request = urllib.request.Request(
                base_url + "/" + path,
                method="HEAD",
                headers={"Accept-Encoding": "gzip"},
            )
            with urllib.request.urlopen(request, timeout=10) as response:
                assert response.headers.get("Content-Encoding") == "gzip", path

    for path in ("/missing.wasm", "/project.godot", "/Dockerfile"):
        try:
            urllib.request.urlopen(base_url + path, timeout=10)
        except urllib.error.HTTPError as error:
            assert error.code == 404, path
        else:
            raise AssertionError("Missing and source files must return 404: " + path)
    print("Web checks passed: health, HTML, fingerprinted pack, MIME types, cache, gzip, and 404.")


if __name__ == "__main__":
    check_web(sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:8080")
