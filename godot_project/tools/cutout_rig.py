#!/usr/bin/env python3
"""绿幕抠图 + 紧裁：将 rig 部件 PNG 的绿底抠净并裁到内容包围盒。
纯 PIL 实现（无需 numpy/scipy）。用于福尔摩斯绑骨素材预处理。
"""
import os, glob
from PIL import Image, ImageFilter

RIG_DIR = "assets/characters/sherlock/rig"

def is_green(r, g, b):
    # 绿幕判定：绿色通道明显高于红、蓝，且整体偏绿
    return g > 110 and (g - r) > 25 and (g - b) > 25

def key_and_crop(src, dst, feather=2):
    im = Image.open(src).convert("RGBA")
    px = im.load()
    w, h = im.size
    alpha = Image.new("L", (w, h), 0)
    apx = alpha.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            # 已透明或绿幕 -> 去掉
            if a < 20 or is_green(r, g, b):
                apx[x, y] = 0
            else:
                apx[x, y] = 255
    # 羽化边缘，避免硬切锯齿
    alpha = alpha.filter(ImageFilter.GaussianBlur(feather))
    # 合成：在绿边半透明处降低绿色溢出（把绿通道压到与红/蓝接近）
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    opx = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            av = alpha.getpixel((x, y))
            if av < 8:
                continue
            # 边缘处若仍偏绿，压低绿色以减少绿边
            if av < 230 and is_green(r, g, b):
                g = (r + b) // 2
            opx[x, y] = (r, g, b, av)
    # 紧裁到内容包围盒
    bbox = out.getbbox()
    if bbox is None:
        print(f"  SKIP (empty): {os.path.basename(src)}")
        return
    out = out.crop(bbox)
    out.save(dst)
    print(f"  {os.path.basename(src):24s} -> {out.size}  (bbox {bbox})")

def main():
    files = sorted(glob.glob(os.path.join(RIG_DIR, "sherlock_*.png")))
    for f in files:
        key_and_crop(f, f)  # 覆盖原文件（保留文件名，Godot 会按 mtime 重新导入）

if __name__ == "__main__":
    main()
