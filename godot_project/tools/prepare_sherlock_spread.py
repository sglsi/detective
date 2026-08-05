#!/usr/bin/env python3
"""把 jpg 棋盘格背景图处理成真透明底 PNG，并做连通块分析。"""
import json
import sys
from pathlib import Path
from collections import Counter

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import label

SRC = Path(r"C:\Users\sglsi\.workbuddy\clipboard-images\clipboard-2026-08-05T12-25-43-806Z-c24d04eb.jpg")
OUT_DIR = Path(r"D:\AI\detective\godot_project\assets\characters\sherlock\rig_analysis")
OUT_PNG = OUT_DIR / "sherlock_spread_transparent.png"
COMPONENTS_JSON = OUT_DIR / "sherlock_spread_components.json"
OVERLAY_PNG = OUT_DIR / "sherlock_spread_overlay.png"

# 棋盘格两种灰大约 245-255，取中灰 key；用 flood fill 只去掉连到四角的背景
KEY_GRAY = 250
BG_LO = 235
BG_TOL = 18  # 背景候选：RGB 三个通道都在 [BG_LO-BG_TOL, 255] 且互相接近
MIN_AREA = 500


def main() -> int:
    if not SRC.exists():
        print(f"[ERR] source not found: {SRC}", file=sys.stderr)
        return 1
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    im = Image.open(SRC).convert("RGB")
    a = np.array(im)
    H, W = a.shape[:2]

    # 背景候选 mask：亮灰且通道接近（覆盖棋盘格两种灰）
    bright = a.min(axis=2) >= BG_LO - BG_TOL
    flat = np.abs(a.astype(np.int16) - KEY_GRAY).max(axis=2) <= 35
    bg_candidate = bright & flat

    # 从四角 flood fill，只标记连通的背景
    visited = np.zeros((H, W), dtype=bool)
    stack = [(0, 0), (W - 1, 0), (0, H - 1), (W - 1, H - 1)]
    while stack:
        x, y = stack.pop()
        if x < 0 or x >= W or y < 0 or y >= H or visited[y, x] or not bg_candidate[y, x]:
            continue
        visited[y, x] = True
        stack.append((x + 1, y))
        stack.append((x - 1, y))
        stack.append((x, y + 1))
        stack.append((x, y - 1))

    # 生成 RGBA
    rgba = np.dstack([a, np.full((H, W), 255, dtype=np.uint8)])
    rgba[visited] = (0, 0, 0, 0)
    out_im = Image.fromarray(rgba, "RGBA")
    out_im.save(OUT_PNG)
    print(f"[INFO] saved transparent PNG: {OUT_PNG}")

    # 连通块分析
    fg = ~visited
    labeled, n = label(fg)
    print(f"[INFO] {n} raw components")

    components = []
    for idx in range(1, n + 1):
        ys, xs = np.where(labeled == idx)
        if len(xs) < MIN_AREA:
            continue
        x1, y1, x2, y2 = int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())
        cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
        ar = (y2 - y1 + 1) / max(x2 - x1 + 1, 1)
        components.append({
            "idx": idx, "area": int(len(xs)),
            "x1": x1, "y1": y1, "x2": x2, "y2": y2,
            "cx": cx, "cy": cy, "w": x2 - x1 + 1, "h": y2 - y1 + 1, "ar": round(ar, 2)
        })

    components.sort(key=lambda c: c["area"], reverse=True)
    for c in components[:20]:
        print(f"  comp {c['idx']:2d}: area={c['area']:6d}  bbox=({c['x1']},{c['y1']})-({c['x2']},{c['y2']})  center=({c['cx']:.0f},{c['cy']:.0f})  ar={c['ar']}")

    # 可视化编号
    vis = Image.new("RGBA", im.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(vis)
    for c in components:
        draw.rectangle([c["x1"], c["y1"], c["x2"], c["y2"]], outline=(255, 0, 0, 180), width=2)
        draw.text((c["x1"], c["y1"] - 12), f"{c['idx']}", fill=(255, 0, 0, 255))
    vis.save(OVERLAY_PNG)
    print(f"[INFO] overlay: {OVERLAY_PNG}")

    COMPONENTS_JSON.write_text(json.dumps(components, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
