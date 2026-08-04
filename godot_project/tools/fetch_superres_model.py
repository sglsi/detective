#!/usr/bin/env python3
"""Fetch an OpenCV dnn_superres model (.pb) via api.github.com (base64), decode locally.

Only used when the model file is missing. Uses the api.github.com contents API which
is reachable in this environment (unlike raw.githubusercontent.com which resets).
"""
import base64
import json
import os
import sys
import urllib.request

REPO = "opencv/opencv_contrib"
PATH = "modules/dnn_superres/data/testdata/FSRCNN_x4.pb"
OUT = os.path.join(os.path.dirname(__file__), "models", "FSRCNN_x4.pb")


def main() -> int:
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    if os.path.exists(OUT) and os.path.getsize(OUT) > 100_000:
        print(f"model already present: {OUT} ({os.path.getsize(OUT)} bytes)")
        return 0
    api = f"https://api.github.com/repos/{REPO}/contents/{PATH}"
    print(f"GET {api}")
    req = urllib.request.Request(api, headers={"User-Agent": "workbuddy"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = json.load(r)
    b64 = data["content"].replace("\n", "").replace("\r", "")
    raw = base64.b64decode(b64)
    with open(OUT, "wb") as f:
        f.write(raw)
    print(f"saved {OUT} ({len(raw)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
