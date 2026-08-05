#!/usr/bin/env python3
"""观察福尔摩斯 A-pose 图的 mask 投影，找出脖子/腋下/胯部/膝盖等切分点。"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

SRC = Path(r"D:\AI\detective\godot_project\assets\characters\sherlock\rig_analysis\sherlock_spread_transparent.png")
OUT_DIR = Path(r"D:\AI\detective\godot_project\assets\characters\sherlock\rig_analysis")


def local_extrema(series, order=8):
    """返回序列的局部极大/极小索引。"""
    from scipy.signal import argrelextrema
    maxima = argrelextrema(series, np.greater, order=order)[0]
    minima = argrelextrema(series, np.less, order=order)[0]
    return maxima, minima


def main() -> int:
    im = Image.open(SRC).convert("RGBA")
    a = np.array(im)
    H, W = a.shape[:2]
    mask = a[:, :, 3] > 128

    # 每行 mask 的左右跨度（宽度）
    widths = np.zeros(H, dtype=int)
    lefts = np.full(H, -1, dtype=int)
    rights = np.full(H, -1, dtype=int)
    for y in range(H):
        xs = np.where(mask[y])[0]
        if len(xs):
            widths[y] = xs.max() - xs.min() + 1
            lefts[y] = xs.min()
            rights[y] = xs.max()

    # 每列 mask 的前景像素数（比 span 更能区分躯干/手臂/腿）
    heights = np.zeros(W, dtype=int)
    for x in range(W):
        heights[x] = int(mask[:, x].sum())

    maxima_y, minima_y = local_extrema(widths, order=10)
    maxima_x, minima_x = local_extrema(heights, order=10)

    print("=== horizontal width (per row) local extrema ===")
    print("maxima y:", list(maxima_y[:15]))
    for y in maxima_y[:15]:
        print(f"  y={y:4d} width={widths[y]:4d} left={lefts[y]} right={rights[y]}")
    print("minima y:", list(minima_y[:15]))
    for y in minima_y[:15]:
        print(f"  y={y:4d} width={widths[y]:4d} left={lefts[y]} right={rights[y]}")

    print("\n=== vertical height (per col) local extrema ===")
    print("maxima x:", list(maxima_x[:15]))
    for x in maxima_x[:15]:
        print(f"  x={x:4d} height={heights[x]:4d}")
    print("minima x:", list(minima_x[:15]))
    for x in minima_x[:15]:
        print(f"  x={x:4d} height={heights[x]:4d}")

    # 可视化投影曲线
    vis_w = 600
    vis_h = 400
    proj = Image.new("RGB", (vis_w, vis_h), (255, 255, 255))
    draw = ImageDraw.Draw(proj)
    max_w = int(widths.max())
    for y in range(H):
        x = int(widths[y] / max_w * (vis_w - 40)) + 20
        yy = int(y / H * (vis_h - 40)) + 20
        draw.ellipse([x - 1, yy - 1, x + 1, yy + 1], fill=(0, 0, 255))
    for y in minima_y[:10]:
        yy = int(y / H * (vis_h - 40)) + 20
        draw.line([(20, yy), (vis_w - 20, yy)], fill=(255, 0, 0), width=1)
    proj.save(OUT_DIR / "projection_horizontal.png")
    print(f"\n[INFO] saved horizontal projection: {OUT_DIR / 'projection_horizontal.png'}")

    proj2 = Image.new("RGB", (vis_w, vis_h), (255, 255, 255))
    draw2 = ImageDraw.Draw(proj2)
    max_hh = int(heights.max())
    for x in range(W):
        xx = int(x / W * (vis_w - 40)) + 20
        y = int(heights[x] / max_hh * (vis_h - 40)) + 20
        draw2.ellipse([xx - 1, y - 1, xx + 1, y + 1], fill=(0, 128, 0))
    for x in minima_x[:10]:
        xx = int(x / W * (vis_w - 40)) + 20
        draw2.line([(xx, 20), (xx, vis_h - 20)], fill=(255, 0, 0), width=1)
    proj2.save(OUT_DIR / "projection_vertical.png")
    print(f"[INFO] saved vertical projection: {OUT_DIR / 'projection_vertical.png'}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
