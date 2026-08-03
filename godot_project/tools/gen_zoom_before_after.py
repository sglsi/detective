"""生成「修复前 vs 修复后」放大取景对比图。

背景：clue_observer._make_zoom 历史上用 factor=2.4 以锚点为中心扩大取景，
导致玩家看到的放大图 != 校准好的锚点框（校准框仅占放大图面积 17.4%），
且 w/h=1.0 的全图锚点会算出负起点，AtlasTexture 采样异常。

本脚本把两种取景规则同时应用到教学图上，输出对比 contact sheet，
供肉眼确认修复效果。输出：anchor_calib/zoom_before_after.png
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TEACHING = {
    "watson_teaching.png": (
        "assets/characters/watson/watson_teaching.png",
        {
            "face":     (0.512, 0.183, 0.240, 0.286),
            "wrist":    (0.360, 0.665, 0.277, 0.209),
            "shoulder": (0.671, 0.390, 0.173, 0.135),
            "pose":     (0.50, 0.50, 1.00, 1.00),
        },
    ),
    "messenger_spritesheet.png": (
        "assets/characters/messenger/messenger_spritesheet.png",
        {
            "tattoo":  (0.26, 0.49, 0.20, 0.20),
            "beard":   (0.48427, 0.2488, 0.23086, 0.184),
            "posture": (0.50, 0.50, 1.00, 1.00),
            "manner":  (0.48347, 0.21775, 0.25299, 0.2645),
            "sleeve":  (0.7506, 0.62, 0.18, 0.20),
            "limp":    (0.5955, 0.88384, 0.21, 0.20768),
        },
    ),
}

CELL = 260
PAD = 14
FONT_SIZE = 18


def _font(size):
    for p in [r"C:\Windows\Fonts\msyh.ttc", r"C:\Windows\Fonts\simhei.ttf",
              r"C:\Windows\Fonts\msyhbd.ttc"]:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()


def region_old(tw, th, cx, cy, w, h, factor=2.4):
    """修复前：以锚点为中心扩大 factor 倍取景（可能产生负起点）。"""
    rw, rh = w * tw, h * th
    gw, gh = rw * factor, rh * factor
    gx = (tw - gw) / 2 if gw >= tw else min(max(cx * tw - gw / 2, 0), tw - gw)
    gy = (th - gh) / 2 if gh >= th else min(max(cy * th - gh / 2, 0), th - gh)
    return gx, gy, min(gw, tw), min(gh, th)


def region_new(tw, th, cx, cy, w, h, factor=1.0):
    """修复后：严格等于校准框，并夹到图内。"""
    gw = min(max(w * tw * factor, 1.0), tw)
    gh = min(max(h * th * factor, 1.0), th)
    gx = min(max(cx * tw - gw / 2, 0.0), tw - gw)
    gy = min(max(cy * th - gh / 2, 0.0), th - gh)
    return gx, gy, gw, gh


def crop_cell(im, box, cell):
    """按 region 裁图（负坐标区域填充深灰，模拟采样异常），缩放进 cell。"""
    gx, gy, gw, gh = box
    canvas = Image.new("RGBA", (int(round(gw)), int(round(gh))), (40, 20, 20, 255))
    sx, sy = int(round(gx)), int(round(gy))
    src_box = (max(sx, 0), max(sy, 0),
               min(sx + int(round(gw)), im.width), min(sy + int(round(gh)), im.height))
    if src_box[2] > src_box[0] and src_box[3] > src_box[1]:
        piece = im.crop(src_box)
        canvas.paste(piece, (max(-sx, 0), max(-sy, 0)))
    canvas.thumbnail((cell, cell), Image.LANCZOS)
    out = Image.new("RGBA", (cell, cell), (28, 26, 24, 255))
    out.paste(canvas, ((cell - canvas.width) // 2, (cell - canvas.height) // 2), canvas)
    return out


def main():
    font = _font(FONT_SIZE)
    font_s = _font(15)
    rows = []
    for img_name, (rel, anchors) in TEACHING.items():
        path = os.path.join(ROOT, rel)
        im = Image.open(path).convert("RGBA")
        # 透明底铺深色，避免看不清
        bg = Image.new("RGBA", im.size, (30, 28, 26, 255))
        bg.alpha_composite(im)
        for cid, (cx, cy, w, h) in anchors.items():
            ob = region_old(im.width, im.height, cx, cy, w, h)
            nb = region_new(im.width, im.height, cx, cy, w, h)
            rows.append((img_name, cid, bg, ob, nb, im.size))

    header = 56
    row_h = CELL + 34
    W = PAD * 4 + CELL * 2 + 300
    H = header + row_h * len(rows) + PAD
    sheet = Image.new("RGBA", (W, H), (20, 19, 18, 255))
    d = ImageDraw.Draw(sheet)
    d.text((PAD, 14), "线索放大取景：修复前(factor=2.4) vs 修复后(严格=校准框)",
           font=_font(24), fill=(240, 210, 130))

    for i, (img_name, cid, bg, ob, nb, size) in enumerate(rows):
        y = header + i * row_h
        x_old = PAD
        x_new = PAD * 2 + CELL
        sheet.paste(crop_cell(bg, ob, CELL), (x_old, y))
        sheet.paste(crop_cell(bg, nb, CELL), (x_new, y))
        d.rectangle([x_old, y, x_old + CELL, y + CELL], outline=(180, 70, 60), width=2)
        d.rectangle([x_new, y, x_new + CELL, y + CELL], outline=(240, 205, 90), width=3)
        d.text((x_old, y + CELL + 6), "修复前", font=font_s, fill=(200, 110, 100))
        d.text((x_new, y + CELL + 6), "修复后", font=font_s, fill=(240, 205, 90))

        tx = x_new + CELL + PAD * 2
        d.text((tx, y + 6), f"{cid}", font=font, fill=(245, 235, 210))
        d.text((tx, y + 32), f"{img_name}", font=font_s, fill=(150, 145, 138))
        tw_, th_ = size
        d.text((tx, y + 58),
               f"校准框 {ob and ''}{nb[2]:.0f}x{nb[3]:.0f}px", font=font_s, fill=(200, 195, 185))
        d.text((tx, y + 80),
               f"旧取景 {ob[2]:.0f}x{ob[3]:.0f} @({ob[0]:.0f},{ob[1]:.0f})",
               font=font_s, fill=(205, 120, 110))
        cover = (nb[2] * nb[3]) / (ob[2] * ob[3]) * 100
        d.text((tx, y + 102), f"校准框在旧图中仅占 {cover:.1f}%",
               font=font_s, fill=(205, 120, 110))
        if ob[0] < -0.01 or ob[1] < -0.01:
            d.text((tx, y + 124), "⚠ 旧取景起点为负 → 采样异常",
                   font=font_s, fill=(255, 120, 100))

    out = os.path.join(ROOT, "anchor_calib", "zoom_before_after.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.convert("RGB").save(out, quality=95)
    print("WROTE", out, sheet.size, f"{len(rows)} anchors")


if __name__ == "__main__":
    main()
