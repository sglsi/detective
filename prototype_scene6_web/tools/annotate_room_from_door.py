from PIL import Image, ImageDraw, ImageFont
import os

src = r"C:\Users\sglsi\.workbuddy\clipboard-images\clipboard-2026-08-14T05-12-40-423Z-9556dc9f.jpg"
dst = r"D:\AI\detective\prototype_scene6_web\assets\room_door_view_annotated.jpg"

im = Image.open(src).convert("RGBA")
W, H = im.size
print("image size", W, H)

# 创建可叠加层
overlay = Image.new("RGBA", im.size, (0, 0, 0, 0))
draw = ImageDraw.Draw(overlay)

# 字体：用系统默认，中文环境找 simhei/msyh；否则用默认
try:
    font = ImageFont.truetype("C:/Windows/Fonts/simhei.ttf", 22)
    font_small = ImageFont.truetype("C:/Windows/Fonts/simhei.ttf", 16)
except Exception:
    font = ImageFont.load_default()
    font_small = ImageFont.load_default()

def box(xywh, color, label, sub=None):
    x, y, w, h = xywh
    draw.rectangle([x, y, x+w, y+h], outline=color, width=3)
    # 标签背景
    txt = label
    tw, th = draw.textbbox((0,0), txt, font=font)[2:4]
    pad = 4
    draw.rectangle([x, y-th-2*pad, x+tw+2*pad, y], fill=color+(200,))
    draw.text((x+pad, y-th-pad), txt, fill=(255,255,255,255), font=font)
    if sub:
        tw2, th2 = draw.textbbox((0,0), sub, font=font_small)[2:4]
        draw.rectangle([x, y+h, x+tw2+2*pad, y+h+th2+2*pad], fill=(0,0,0,180))
        draw.text((x+pad, y+h+pad), sub, fill=(255,255,255,255), font=font_small)

# 方位坐标：主视角=门（站在门口朝室内望）
# 前景/下=门（南），上=北墙，左=西墙，右=东墙
annotations = [
    ((18, 18, 272, 650), (200, 60, 60), "壁炉 Fireplace", "西墙"),
    ((35, 20, 200, 260), (220, 140, 40), "壁炉镜 Mirror", "镜中反射"),
    ((15, 285, 278, 60), (180, 80, 180), "壁炉台 Mantel", "烛台/座钟/瓶"),
    ((300, 140, 145, 360), (60, 120, 200), "书架 Bookshelf", "北墙偏左"),
    ((490, 120, 140, 110), (80, 160, 80), "挂画 Painting", "北墙正中"),
    ((440, 415, 330, 235), (80, 80, 180), "餐桌 Table", "房间中央"),
    ((775, 18, 80, 335), (40, 140, 220), "窗户 Window", "东墙"),
    ((730, 18, 120, 525), (160, 60, 160), "窗帘 Curtains", "窗户两侧"),
    ((450, 360, 118, 140), (60, 180, 120), "绿色台灯 Lamp", "正面(后墙前)·台灯下三层置物架"),
    ((578, 405, 72, 92), (90, 200, 140), "两层置物架", "三层架旁"),
    ((115, 495, 630, 260), (180, 100, 40), "地毯 Rug", "地面中央"),
]

for xywh, color, label, sub in annotations:
    box(xywh, color, label, sub)

# 画方位指示箭头/文字（画面四角）
corners = [
    (W//2, 14, "北 North（后墙）", (255,255,255)),
    (W//2, H-28, "南 South（门/主视角所在墙）", (255,255,255)),
    (14, H//2, "西 West", (255,255,255)),
    (W-90, H//2, "东 East", (255,255,255)),
]
for x, y, txt, col in corners:
    tw, th = draw.textbbox((0,0), txt, font=font_small)[2:4]
    draw.rectangle([x-tw//2-6, y-3, x+tw//2+6, y+th+3], fill=(0,0,0,160))
    draw.text((x-tw//2, y), txt, fill=col, font=font_small)

# 合并
canvas = Image.alpha_composite(im, overlay)
canvas.convert("RGB").save(dst, quality=95)
print("saved", dst)
