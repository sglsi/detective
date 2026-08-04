#!/usr/bin/env python3
"""Build a side-by-side comparison: bicubic (LANCZOS) vs AI (FSRCNN x4).

Reads the already-applied AI result from assets/scenes/sc_02_garden.png and
regenerates a bicubic upscale from the git-recovered original for a fair compare.
"""
import os
import subprocess
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(__file__)
ROOT = os.path.abspath(os.path.join(HERE, ".."))
SRC = os.path.join(ROOT, "assets", "scenes", "sc_02_garden.png")
MODELS = os.path.join(HERE, "models")
ORIG_REF = "36a4f9a:godot_project/assets/scenes/sc_02_garden.png"
OUT = os.path.join(MODELS, "_compare.png")
TARGET = (1920, 1080)


def get_original() -> str:
    tmp = os.path.join(MODELS, "_orig_sc02.png")
    if not (os.path.exists(tmp) and os.path.getsize(tmp) > 10000):
        subprocess.run(["git", "show", ORIG_REF],
                       cwd=os.path.abspath(os.path.join(ROOT, "..")),
                       stdout=open(tmp, "wb"), check=True)
    return tmp


def main() -> int:
    ai = Image.open(SRC).convert("RGB")
    orig = cv2.imread(get_original(), cv2.IMREAD_COLOR)
    bic = cv2.resize(orig, TARGET, interpolation=cv2.INTER_CUBIC)
    bic = Image.fromarray(cv2.cvtColor(bic, cv2.COLOR_BGR2RGB))

    # downscale panels for a compact composite
    pw, ph = 960, 540
    ai_s = ai.resize((pw, ph), Image.LANCZOS)
    bic_s = bic.resize((pw, ph), Image.LANCZOS)

    comp = Image.new("RGB", (pw * 2 + 20, ph + 40), (20, 18, 14))
    comp.paste(bic_s, (10, 40))
    comp.paste(ai_s, (pw + 10, 40))
    d = ImageDraw.Draw(comp)
    d.text((10, 12), "LEFT: BICUBIC (LANCZOS)", fill=(220, 200, 150))
    d.text((pw + 10, 12), "RIGHT: AI FSRCNN x4", fill=(150, 220, 150))
    comp.save(OUT)
    print("saved", OUT, comp.size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
