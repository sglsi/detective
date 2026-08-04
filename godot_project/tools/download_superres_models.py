#!/usr/bin/env python3
"""Download OpenCV dnn_superres models.

FSRCNN_x4 (41KB) is fetched via api.github.com (always reliable in this env).
EDSR_x4 (38MB, best quality) is attempted via GitHub raw mirrors with retries.
The upscaler prefers EDSR if present, else falls back to FSRCNN.
"""
import base64
import os
import ssl
import sys
import time
import urllib.request

HERE = os.path.dirname(__file__)
MODELS = os.path.join(HERE, "models")
os.makedirs(MODELS, exist_ok=True)

CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE


def fetch_api_github(repo: str, path: str, out: str) -> bool:
    api = f"https://api.github.com/repos/{repo}/contents/{path}"
    try:
        req = urllib.request.Request(api, headers={"User-Agent": "workbuddy"})
        with urllib.request.urlopen(req, timeout=60, context=CTX) as r:
            d = __import__("json").loads(r.read().decode())
        raw = base64.b64decode(d["content"].replace("\n", "").replace("\r", ""))
        with open(out, "wb") as f:
            f.write(raw)
        print(f"[api] saved {out} ({len(raw)} bytes)")
        return True
    except Exception as e:
        print(f"[api] FAILED {repo}/{path}: {e}")
        return False


def fetch_url(url: str, out: str, retries: int = 4) -> bool:
    for i in range(1, retries + 1):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "workbuddy"})
            with urllib.request.urlopen(req, timeout=120, context=CTX) as r:
                data = r.read()
            if len(data) < 100_000:
                raise IOError(f"too small ({len(data)} bytes), likely error page")
            with open(out, "wb") as f:
                f.write(data)
            print(f"[url] saved {out} ({len(data)} bytes) via {url}")
            return True
        except Exception as e:
            print(f"[url] attempt {i}/{retries} FAILED {url}: {e}")
            time.sleep(1)
    return False


def main() -> int:
    # FSRCNN (reliable fallback)
    fs = os.path.join(MODELS, "FSRCNN_x4.pb")
    if not (os.path.exists(fs) and os.path.getsize(fs) > 30_000):
        fetch_api_github("Saafke/FSRCNN_Tensorflow", "models/FSRCNN_x4.pb", fs)

    # EDSR (best quality, attempt mirrors)
    es = os.path.join(MODELS, "ESDR_x4.pb")
    if not (os.path.exists(es) and os.path.getsize(es) > 30_000_000):
        base = "https://raw.githubusercontent.com/Saafke/EDSR_Tensorflow/master/models/ESDR_x4.pb"
        mirrors = [
            f"https://mirror.ghproxy.com/{base}",
            f"https://ghproxy.net/{base}",
            f"https://raw.gitmirror.com/Saafke/EDSR_Tensorflow/master/models/ESDR_x4.pb",
            base,
        ]
        for u in mirrors:
            if fetch_url(u, es):
                break
    else:
        print("[skip] EDSR already present")

    print("DONE. models:", sorted(os.listdir(MODELS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
