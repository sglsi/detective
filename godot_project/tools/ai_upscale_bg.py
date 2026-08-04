#!/usr/bin/env python3
"""AI super-resolution upscale of the scene-2 background using OpenCV dnn_superres.

Recovers the ORIGINAL low-res source from git (so we upscale real detail, not
already-interpolated pixels), runs the CNN model (EDSR if present, else FSRCNN),
then cover-crops to exactly 1920x1080 and applies a mild sharpen.

Usage: python3 tools/ai_upscale_bg.py
"""
import os
import subprocess
import sys

import cv2
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(__file__)
ROOT = os.path.abspath(os.path.join(HERE, ".."))
SRC_PNG = os.path.join(ROOT, "assets", "scenes", "sc_02_garden.png")
MODELS = os.path.join(HERE, "models")
ORIG_REF = "36a4f9a:godot_project/assets/scenes/sc_02_garden.png"  # original 688x380
TARGET = (1920, 1080)

# model (alg, scale, path) — prefer EDSR (best) else FSRCNN
CANDIDATES = [
    ("esrgan", 4, os.path.join(MODELS, "ESDR_x4.pb")),
    ("fsrcnn", 4, os.path.join(MODELS, "FSRCNN_x4.pb")),
]


def get_original() -> str:
    """Recover the original 688x380 png from git into a temp file."""
    tmp = os.path.join(MODELS, "_orig_sc02.png")
    if os.path.exists(tmp) and os.path.getsize(tmp) > 10_000:
        return tmp
    subprocess.run(
        ["git", "show", ORIG_REF],
        cwd=os.path.abspath(os.path.join(ROOT, "..")),
        stdout=open(tmp, "wb"),
        check=True,
    )
    print(f"[git] recovered original -> {tmp} ({os.path.getsize(tmp)} bytes)")
    return tmp


def main() -> int:
    orig = get_original()
    img = cv2.imread(orig, cv2.IMREAD_COLOR)
    if img is None:
        print("ERROR: cannot read original", orig)
        return 1
    print(f"[cv] original {img.shape[1]}x{img.shape[0]}")

    sr = cv2.dnn_superres.DnnSuperResImpl_create()
    chosen = None
    for alg, scale, path in CANDIDATES:
        if os.path.exists(path) and os.path.getsize(path) > 1000:
            try:
                sr.readModel(path)
                sr.setModel(alg, scale)
                chosen = (alg, scale, path)
                break
            except Exception as e:
                print(f"[warn] {alg} model load failed: {e}")
    if not chosen:
        print("ERROR: no super-res model available")
        return 1
    print(f"[sr] using {chosen[0]} x{chosen[1]} ({os.path.basename(chosen[2])})")

    up = sr.upsample(img)
    print(f"[sr] upscaled -> {up.shape[1]}x{up.shape[0]}")

    # cover-crop to exactly TARGET (avoid aspect distortion)
    uh, uw = up.shape[:2]
    tw, th = TARGET
    s = max(tw / uw, th / uh)
    nw, nh = int(round(uw * s)), int(round(uh * s))
    up = cv2.resize(up, (nw, nh), interpolation=cv2.INTER_LINEAR)
    left, top = (nw - tw) // 2, (nh - th) // 2
    up = up[top:top + th, left:left + tw]
    print(f"[crop] -> {up.shape[1]}x{up.shape[0]}")

    # mild sharpen to counter FSRCNN softness
    pil = Image.fromarray(cv2.cvtColor(up, cv2.COLOR_BGR2RGB))
    pil = pil.filter(ImageFilter.UnsharpMask(radius=1.0, percent=115, threshold=2))
    pil.save(SRC_PNG, "PNG", optimize=True)
    print(f"[save] {SRC_PNG} {pil.size}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
