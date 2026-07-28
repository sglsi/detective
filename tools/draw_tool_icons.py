# -*- coding: utf-8 -*-
"""
绘制侦探游戏工具图标（透明底 PNG，统一美术风格）。
ImageGen 在本环境不可用，故用 PIL 程序化绘制——离线可靠、不烧额度、游戏可直接用。

输出目录: godot_project/assets/tools/
图标清单(与 ToolSystem.TOOLS 一致):
  magnifier 放大镜 / tape 卷尺 / chemistry 化学试剂盒 / directory 黄页
  handcuffs 手铐 / rope 绳索 / newspaper 报纸 / plaster 石膏粉
"""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "godot_project", "assets", "tools")
OUT = os.path.abspath(OUT)
os.makedirs(OUT, exist_ok=True)

S = 256
# 调色板（侦探游戏：黄铜 + 深色金属 + 点缀红）
BRASS   = (200, 160, 74)
BRASS_D = (150, 116, 50)
DARK    = (54, 56, 64)
DARK2   = (38, 40, 48)
WOOD    = (120, 82, 44)
RED     = (196, 64, 52)
GLASS   = (150, 200, 230)
PAPER   = (232, 226, 206)
STEEL   = (170, 176, 188)
TAN     = (196, 158, 104)


def new_canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def save(img, name):
    path = os.path.join(OUT, name + ".png")
    img.save(path)
    print("saved:", path, img.size)


def _ring(d, cx, cy, r, fill, outline, w):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline, width=w)


# ---------- 放大镜 ----------
def draw_magnifier():
    img = new_canvas(); d = ImageDraw.Draw(img)
    # 手柄（右下 45°）
    d.line([(150, 150), (216, 216)], fill=WOOD, width=26)
    d.line([(150, 150), (216, 216)], fill=BRASS, width=6)
    d.ellipse([206, 206, 226, 226], fill=BRASS, outline=BRASS_D, width=3)
    # 镜片外环
    _ring(d, 104, 104, 64, None, BRASS, 12)
    _ring(d, 104, 104, 64, None, BRASS_D, 3)
    # 玻璃
    _ring(d, 104, 104, 52, (GLASS[0], GLASS[1], GLASS[2], 95), None, 0)
    # 高光
    d.arc([78, 78, 130, 130], 200, 250, fill=(255, 255, 255, 200), width=8)
    d.arc([84, 84, 124, 124], 205, 245, fill=(255, 255, 255, 120), width=4)
    save(img, "magnifier")


# ---------- 卷尺 ----------
def draw_tape():
    img = new_canvas(); d = ImageDraw.Draw(img)
    # 外壳（黄）
    d.rounded_rectangle([40, 92, 122, 178], radius=22, fill=(236, 200, 64), outline=DARK, width=4)
    d.ellipse([72, 118, 92, 138], fill=DARK2, outline=BRASS, width=3)
    d.ellipse([80, 126, 84, 130], fill=BRASS)
    # 拉出的尺带
    d.rectangle([120, 122, 224, 150], fill=(225, 228, 232), outline=DARK, width=3)
    # 刻度
    for i, x in enumerate(range(126, 220, 12)):
        h = 14 if i % 5 == 0 else 7
        d.line([(x, 122), (x, 122 + h)], fill=DARK, width=2)
    # 端点卡扣
    d.rounded_rectangle([218, 116, 234, 156], radius=8, fill=RED, outline=DARK2, width=3)
    save(img, "tape")


# ---------- 化学试剂盒 ----------
def draw_chemistry():
    img = new_canvas(); d = ImageDraw.Draw(img)
    # 锥形瓶
    flask = [(112, 70), (144, 70), (176, 200), (80, 200)]
    d.polygon(flask, fill=(GLASS[0], GLASS[1], GLASS[2], 70), outline=DARK, width=4)
    d.rectangle([112, 52, 144, 74], fill=(GLASS[0], GLASS[1], GLASS[2], 70), outline=DARK, width=4)
    # 液体（绿）
    d.polygon([(100, 150), (156, 150), (172, 198), (84, 198)], fill=(90, 170, 120, 200))
    # 气泡
    for cx, cy, r in [(120, 170, 5), (138, 182, 4), (110, 188, 3)]:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(220, 255, 230, 200))
    # 滴管
    d.rectangle([120, 18, 136, 44], fill=(220, 220, 225, 230), outline=DARK, width=3)
    d.polygon([(118, 44), (138, 44), (128, 60)], fill=STEEL, outline=DARK, width=2)
    d.ellipse([124, 60, 132, 70], fill=RED)  # 液滴
    save(img, "chemistry")


# ---------- 黄页（目录） ----------
def draw_directory():
    img = new_canvas(); d = ImageDraw.Draw(img)
    # 书封
    d.rounded_rectangle([58, 66, 198, 196], radius=10, fill=(150, 50, 46), outline=DARK2, width=4)
    # 书脊高光
    d.line([(72, 72), (72, 190)], fill=(200, 90, 84), width=4)
    # 书页
    d.rectangle([188, 74, 196, 188], fill=PAPER, outline=DARK, width=2)
    # 黄页标志（黄块 + 横线）
    d.rounded_rectangle([92, 92, 168, 110], radius=4, fill=(236, 200, 64))
    for y in (128, 142, 156, 170):
        d.line([(96, y), (164, y)], fill=PAPER, width=4)
    save(img, "directory")


# ---------- 手铐 ----------
def draw_handcuffs():
    img = new_canvas(); d = ImageDraw.Draw(img)
    # 链
    for cx in range(108, 150, 14):
        d.ellipse([cx - 6, 124, cx + 6, 136], fill=None, outline=STEEL, width=4)
    # 左铐
    d.arc([70, 92, 130, 152], 35, 325, fill=STEEL, width=12)
    d.arc([70, 92, 130, 152], 35, 325, fill=None, width=0)
    # 右铐
    d.arc([126, 92, 186, 152], 215, 505, fill=STEEL, width=12)
    # 锁芯
    d.ellipse([92, 110, 108, 126], fill=DARK2, outline=BRASS, width=3)
    d.ellipse([148, 110, 164, 126], fill=DARK2, outline=BRASS, width=3)
    save(img, "handcuffs")


# ---------- 绳索 ----------
def draw_rope():
    img = new_canvas(); d = ImageDraw.Draw(img)
    cx, cy = 118, 120
    for r in range(40, 14, -12):
        d.arc([cx - r, cy - r, cx + r, cy + r], 20, 380, fill=TAN, width=9)
    # 松散端
    d.line([(156, 150), (196, 196)], fill=TAN, width=9)
    d.line([(156, 150), (196, 196)], fill=(150, 116, 70), width=3)
    save(img, "rope")


# ---------- 报纸 ----------
def draw_newspaper():
    img = new_canvas(); d = ImageDraw.Draw(img)
    d.rounded_rectangle([46, 56, 210, 200], radius=6, fill=PAPER, outline=DARK, width=4)
    # 报头
    d.rectangle([46, 56, 210, 86], fill=(70, 74, 84))
    d.rectangle([60, 66, 196, 78], fill=PAPER)
    # 分栏文字线
    for col in (60, 130):
        for y in range(98, 196, 12):
            d.line([(col, y), (col + 56, y)], fill=(120, 116, 110), width=3)
    d.line([(118, 92), (118, 196)], fill=DARK, width=3)
    save(img, "newspaper")


# ---------- 石膏粉 ----------
def draw_plaster():
    img = new_canvas(); d = ImageDraw.Draw(img)
    # 石膏绷带 cast 形状（ limb cast ）
    d.rounded_rectangle([78, 70, 178, 190], radius=40, fill=(238, 236, 228), outline=(200, 196, 184), width=4)
    # 绷带缝线
    d.line([(128, 76), (128, 184)], fill=(205, 200, 188), width=4)
    for y in (96, 120, 144, 168):
        d.line([(92, y), (118, y)], fill=(210, 205, 193), width=3)
        d.line([(138, y), (164, y)], fill=(210, 205, 193), width=3)
    # 粉袋点缀
    d.rounded_rectangle([150, 150, 196, 196], radius=10, fill=(236, 200, 64), outline=DARK2, width=3)
    save(img, "plaster")


if __name__ == "__main__":
    draw_magnifier()
    draw_tape()
    draw_chemistry()
    draw_directory()
    draw_handcuffs()
    draw_rope()
    draw_newspaper()
    draw_plaster()
    print("ALL DONE ->", OUT)
