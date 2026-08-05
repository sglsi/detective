#!/usr/bin/env python3
"""分析福尔摩斯全身像的连通块，评估绑骨拆分的可行性。"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SRC = Path(r"D:\AI\detective\godot_project\assets\characters\sherlock\sherlock_full_body.png")
OUT_DIR = Path(r"D:\AI\detective\godot_project\assets\characters\sherlock\rig_analysis")

# 背景色用四角+边缘均值估算（浅灰）
BG_COLOR = (247, 248, 246)
BG_TOLERANCE = 30
MIN_AREA = 100


def main() -> int:
    if not SRC.exists():
        print(f"[ERR] {SRC} not found", file=sys.stderr)
        return 1
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    img = Image.open(SRC).convert("RGBA")
    arr = np.array(img)

    # 背景 mask：颜色接近浅灰 或 alpha 低
    diff = np.abs(arr[:, :, :3].astype(np.int16) - np.array(BG_COLOR, dtype=np.int16))
    bg = (diff.max(axis=2) <= BG_TOLERANCE) | (arr[:, :, 3] <= 128)
    fg = ~bg

    # 透明化背景后保存，方便人工检查
    out = arr.copy()
    out[bg] = (0, 0, 0, 0)
    Image.fromarray(out, "RGBA").save(OUT_DIR / "sherlock_transparent.png")
    print(f"[INFO] transparent preview: {OUT_DIR / 'sherlock_transparent.png'}")

    # 连通块分析
    from scipy.ndimage import label
    labeled, n = label(fg)
    print(f"[INFO] {n} raw components (min_area={MIN_AREA})")

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

    # 按面积降序
    components.sort(key=lambda c: c["area"], reverse=True)
    for c in components[:20]:
        print(f"  comp {c['idx']:2d}: area={c['area']:6d}  bbox=({c['x1']},{c['y1']})-({c['x2']},{c['y2']})  center=({c['cx']:.0f},{c['cy']:.0f})  ar={c['ar']}")

    # 可视化编号
    vis = Image.new("RGBA", img.size, (0, 0, 0, 0))
    from PIL import ImageDraw, ImageFont
    draw = ImageDraw.Draw(vis)
    for c in components:
        draw.rectangle([c["x1"], c["y1"], c["x2"], c["y2"]], outline=(255, 0, 0, 160), width=2)
        draw.text((c["x1"], c["y1"] - 14), f"{c['idx']}", fill=(255, 0, 0, 255))
    vis.save(OUT_DIR / "components_overlay.png")
    print(f"[INFO] overlay: {OUT_DIR / 'components_overlay.png'}")

    # 写出JSON
    (OUT_DIR / "components.json").write_text(json.dumps(components, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
