#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
线索-图片锚点可视化校准工具
================================
把 data/clue_image_anchors.gd 里的锚点画到对应角色/物证图上，
输出 anchor_calib/<basename>.png，供肉眼核对："金框是否落在正确的解剖位置"。

用法：
    python tools/gen_anchor_calibration.py
输出：
    D:/AI/detective/godot_project/anchor_calib/*.png

核对后，若某框偏了，只改 data/clue_image_anchors.gd 里对应 {cx,cy,w,h}，
再跑本脚本重新生成即可（无需改任何代码）。

⚠️ 本文件的 ANCHORS 是 data/clue_image_anchors.gd 的镜像，改了 .gd 请同步改这里。
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "anchor_calib")
os.makedirs(OUT, exist_ok=True)

# ---- 镜像 data/clue_image_anchors.gd（改 .gd 请同步）----
ANCHORS = {
    "res://assets/characters/watson/watson_teaching.png": {
        "face":    {"cx": 0.512, "cy": 0.183, "w": 0.24, "h": 0.286},
        "wrist":   {"cx": 0.360, "cy": 0.665, "w": 0.277, "h": 0.209},
        "shoulder":{"cx": 0.671, "cy": 0.390, "w": 0.173, "h": 0.135},
        "pose":    {"cx": 0.50, "cy": 0.50, "w": 1.00, "h": 1.00},
    },
    "res://assets/characters/messenger/messenger_spritesheet.png": {
        "tattoo":  {"cx": 0.26, "cy": 0.49, "w": 0.20, "h": 0.20},
        "beard":   {"cx": 0.48427, "cy": 0.2488, "w": 0.23086, "h": 0.184},
        "posture": {"cx": 0.50, "cy": 0.50, "w": 1.00, "h": 1.00},
        "manner":  {"cx": 0.48347, "cy": 0.21775, "w": 0.25299, "h": 0.2645},
        "sleeve":  {"cx": 0.7506, "cy": 0.62, "w": 0.18, "h": 0.20},
        "limp":    {"cx": 0.5955, "cy": 0.88384, "w": 0.21, "h": 0.20768},
    },
    "res://assets/props/ring.png": {
        "ring_inner": {"cx": 0.50, "cy": 0.50, "w": 0.42, "h": 0.42},
    },
    "res://assets/clues/photo_watch.png": {
        "watch_portrait": {"cx": 0.50, "cy": 0.50, "w": 0.50, "h": 0.50},
    },
    "res://assets/clues/photo_drebber_body.png": {
        "face": {"cx": 0.50, "cy": 0.30, "w": 0.50, "h": 0.40},
    },
}

MAX_W = 720
GOLD = (242, 200, 90)
FONT_SIZE = 22


def _font(size):
    for p in [
        "C:/Windows/Fonts/msyh.ttc",
        "C:/Windows/Fonts/simhei.ttf",
        "C:/Windows/Fonts/arial.ttf",
    ]:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()


def main():
    font = _font(FONT_SIZE)
    for res_path, anchors in ANCHORS.items():
        img_path = os.path.join(ROOT, res_path.replace("res://", ""))
        if not os.path.exists(img_path):
            print("SKIP (missing):", img_path)
            continue
        im = Image.open(img_path).convert("RGBA")
        # 统一缩放到 MAX_W 宽以便查看
        scale = MAX_W / im.width
        disp = im.resize((MAX_W, max(1, int(im.height * scale))))
        draw = ImageDraw.Draw(disp)
        W, H = disp.size
        for name, a in anchors.items():
            cx, cy = a["cx"] * W, a["cy"] * H
            bw, bh = a["w"] * W, a["h"] * H
            x0, y0 = cx - bw / 2, cy - bh / 2
            x1, y1 = cx + bw / 2, cy + bh / 2
            draw.rectangle([x0, y0, x1, y1], outline=GOLD, width=4)
            # 中心点
            draw.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=GOLD)
            # 标签（贴框上方）
            label = name
            bbox = draw.textbbox((0, 0), label, font=font)
            tw = bbox[2] - bbox[0]
            tx = min(max(x0, 0), W - tw - 4)
            ty = max(y0 - FONT_SIZE - 8, 2)
            draw.rectangle([tx - 3, ty - 3, tx + tw + 3, ty + FONT_SIZE + 3],
                           fill=(0, 0, 0, 180))
            draw.text((tx, ty), label, fill=GOLD, font=font)
        out_name = os.path.splitext(os.path.basename(img_path))[0] + "_calib.png"
        disp.convert("RGB").save(os.path.join(OUT, out_name))
        print("OK  ->", os.path.join(OUT, out_name),
              "(%dx%d, %d anchors)" % (W, H, len(anchors)))


if __name__ == "__main__":
    main()
