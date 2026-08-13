from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
img_path = ROOT / "assets/characters/messenger/messenger_portrait.png"
out_path = ROOT / "tools/anchor_calib_messenger_v2.png"

img = Image.open(img_path).convert("RGBA")
w, h = img.size
# 放在浅灰底上，避免透明格子干扰判断
bg = Image.new("RGBA", img.size, (220, 220, 220, 255))
bg.paste(img, (0, 0), img)

def circle(draw, cx, cy, r, color, width=4):
    x = cx * w
    y = cy * h
    draw.ellipse([x-r, y-r, x+r, y+r], outline=color, width=width)
    draw.line([x-r, y, x+r, y], fill=color, width=2)
    draw.line([x, y-r, x, y+r], fill=color, width=2)

current = {
    "tattoo":  (0.25,  0.19),
    "beard":   (0.49,  0.09),
    "manner":  (0.49,  0.07),
}
proposed = {
    "tattoo":  (0.13,  0.18),   # 右手背锚形文身
    "beard":   (0.49,  0.105),  # 络腮胡（下巴/下颌）
    "manner":  (0.49,  0.055),  # 发号施令神态（眉眼）
}

# 左右对比：左=当前值（红），右=建议值（绿）
W = w * 2
H = h
out = Image.new("RGBA", (W, H), (240, 240, 240, 255))
out.paste(bg, (0, 0))
out.paste(bg, (w, 0))

draw = ImageDraw.Draw(out)

try:
    font = ImageFont.truetype("C:/Windows/Fonts/simhei.ttf", 22)
    font_small = ImageFont.truetype("C:/Windows/Fonts/simhei.ttf", 16)
except Exception:
    font = ImageFont.load_default()
    font_small = font

for name, (cx, cy) in current.items():
    circle(draw, cx, cy, 30, (255, 0, 0, 255))
    draw.text((cx*w+35, cy*h-12), f"{name} current", fill=(255, 0, 0, 255), font=font_small)

for name, (cx, cy) in proposed.items():
    circle(draw, cx+w/w, cy, 30, (0, 160, 0, 255))  # 右侧，x偏移1.0
    draw.text((w+cx*w+35, cy*h-12), f"{name} proposed", fill=(0, 160, 0, 255), font=font_small)

draw.text((20, 20), "LEFT = current anchors (red)", fill=(255, 0, 0, 255), font=font)
draw.text((w+20, 20), "RIGHT = proposed anchors (green)", fill=(0, 160, 0, 255), font=font)

out.save(out_path)
print("saved:", out_path)
