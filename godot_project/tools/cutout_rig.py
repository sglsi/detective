#!/usr/bin/env python3
"""绿幕抠图 v6：Alpha Gamma 校正（非线性提升中间调）。

v2-v5 失败总结：
  这些 AI 柔光风格素材的角色像素 alpha 分布在 [4,255] 全范围，
  但大部分集中在低-中区域（mean 60-95）。线性拉伸/硬阈值都无效。

v6 策略：
  1. v2 的背景检测（颜色+alpha+暗色）保留
  2. mask × orig_alpha 合成 + despill
  3. **Alpha Gamma 校正**（核心）：new_a = 255 * (a/255)^(1/gamma)
     gamma=2.5 → 把中间调 alpha 从 ~80 提升到 ~160
  4. 轻度硬阈值截断（ALPHA_CUT=40，去噪）
  5. 紧裁
"""
import os, glob, math
from PIL import Image, ImageFilter

RIG_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "characters", "sherlock", "rig")
GAMMA = 2.5        # >1 提升中间调（值越大提升越激进）
ALPHA_CUT = 40     # gamma 后截断噪点
FEATHER = 3


def is_green(r, g, b):
    return g > 100 and (g - r) > 20 and (g - b) > 20


def is_dark(r, g, b):
    return r < 25 and g < 35 and b < 25


def key_and_crop(src, dst):
    name = os.path.basename(src)
    im = Image.open(src).convert("RGBA")
    px = im.load()
    w, h = im.size

    # ── Step 1: 背景 mask ──
    mask = Image.new("L", (w, h), 0)
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            mp[x, y] = 0 if (is_green(r, g, b) or a < 40 or is_dark(r, g, b)) else 255

    if FEATHER > 0:
        mask = mask.filter(ImageFilter.GaussianBlur(FEATHER))

    # ── Step 2: 合成 + despill ──
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    opx = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, orig_a = px[x, y]
            m = mask.getpixel((x, y))
            final_a = int(m * orig_a / 255.0)
            if final_a < 4:
                continue
            if final_a < 220 and is_green(r, g, b):
                g = min(g, (r + b + 10) // 2)
            opx[x, y] = (r, g, b, final_a)

    # ── Step 3: Alpha Gamma 校正（核心！）──
    inv_gamma = 1.0 / GAMMA
    for y in range(h):
        for x in range(w):
            r, g, b, a = opx[x, y]
            if a > 0:
                new_a = int(255.0 * math.pow(a / 255.0, inv_gamma))
                new_a = max(0, min(255, new_a))
                opx[x, y] = (r, g, b, new_a)

    # ── Step 4: 轻度硬阈值截断 ──
    cut = keep = 0
    for y in range(h):
        for x in range(w):
            _, _, _, a = opx[x, y]
            if 0 < a < ALPHA_CUT:
                opx[x, y] = (0, 0, 0, 0)
                cut += 1
            elif a > 0:
                keep += 1

    # ── Step 5: 紧裁 ──
    bbox = out.getbbox()
    if bbox is None:
        print(f"  SKIP (empty): {name}")
        return

    out = out.crop(bbox)
    bw, bh = out.size

    # 统计
    out_alpha = out.split()[3]
    a_data = list(out_alpha.getdata())
    total = len(a_data)
    opaque_n = sum(1 for v in a_data if v > 200)
    a_mean = sum(a_data) / total if total else 0

    out.save(dst)
    print(f"  {name:24s} {w}x{h}->{bw}x{bh}  "
          f"gamma={GAMMA}  cut={cut} keep={keep}  "
          f"α_mean={a_mean:.0f}  opaque={100*opaque_n/total:.0f}%")


def main():
    files = sorted(glob.glob(os.path.join(RIG_DIR, "sherlock_*.png")))
    print(f"=== cutout_rig v6 (gamma={GAMMA}): {len(files)} files ===")
    for f in files:
        key_and_crop(f, f)
    print("=== done ===")


if __name__ == "__main__":
    main()
