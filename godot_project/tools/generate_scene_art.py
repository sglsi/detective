#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
P5-3 场景背景美术生成器
============================
为 8 个侦探场景创作「维多利亚伦敦 · 煤气灯黑色电影」风格的氛围插画，
作为真实提交的美术资源（替代 scene_controller.gd 中 emoji 占位的 ColorRect）。

输出： godot_project/assets/scenes/sc_<n>_*.png  (1920x1080, 16:9)
依赖： Pillow + numpy（已预装）
特性： 幂等——重复运行覆盖同名文件；固定随机种子保证可复现。

设计语言：
  - 抑制饱和度的暖色高光 + 冷调阴影（gaslight noir）
  - 多层建筑/结构剪影构建纵深
  - 径向煤气灯光晕提供视觉焦点
  - 暗角 + 颗粒营造年代胶片质感
"""

import os
import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1920, 1080
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, "..", "assets", "scenes"))
os.makedirs(OUT, exist_ok=True)

FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

random.seed(1887)  # 福尔摩斯住址梗，保证可复现


# ---------------- 基础画布原语 ----------------

def gradient(top, bottom):
    """竖直渐变天空/地面。"""
    t = np.linspace(0, 1, H)[:, None]
    top = np.array(top, dtype=float)
    bottom = np.array(bottom, dtype=float)
    rows = top[None, :] * (1 - t) + bottom[None, :] * t
    img = np.zeros((H, W, 3), dtype=np.uint8)
    img[:] = rows[:, None, :]
    return img


def vignette(img, strength=0.55):
    ys, xs = np.mgrid[0:H, 0:W]
    cx, cy = W / 2.0, H / 2.0
    dx = (xs - cx) / cx
    dy = (ys - cy) / cy
    d = np.sqrt(dx * dx + dy * dy)
    d = np.clip(d, 0, 1)
    mask = (1 - strength * d * d)[:, :, None]
    return np.clip(img * mask, 0, 255).astype(np.uint8)


def grain(img, amount=7):
    noise = np.random.normal(0, amount, (H, W, 1)).astype(np.int16)
    return np.clip(img.astype(np.int16) + noise, 0, 255).astype(np.uint8)


def glow(img, cx, cy, radius, color, intensity=0.55):
    ys, xs = np.mgrid[0:H, 0:W]
    d = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2)
    g = np.clip(1 - d / radius, 0, 1) ** 2
    g = g[:, :, None]
    add = np.array(color, dtype=float)[None, None, :] * (g * intensity)
    return np.clip(img.astype(np.float32) + add, 0, 255).astype(np.uint8)


def to_pil(arr):
    return Image.fromarray(arr, "RGB")


def skyline(draw, base_y, color, min_h=120, max_h=420, step=70):
    """沿地平线画一排高低错落的建筑剪影。"""
    x = -40
    while x < W + 40:
        bw = random.randint(step - 20, step + 40)
        bh = random.randint(min_h, max_h)
        top = base_y - bh
        draw.rectangle([x, top, x + bw, base_y], fill=color)
        # 偶尔加屋顶三角/烟囱
        if random.random() < 0.4:
            draw.polygon([(x, top), (x + bw / 2, top - 40), (x + bw, top)], fill=color)
        # 窗户微光
        if random.random() < 0.7:
            wy = top + random.randint(20, max(25, bh - 40))
            draw.rectangle([x + bw // 2 - 6, wy, x + bw // 2 + 6, wy + 12],
                           fill=(255, 214, 140))
        x += bw + random.randint(6, 26)


def person(draw, cx, base_y, h, color):
    """简洁人物剪影：头 + 梯形躯干 + 双腿。"""
    head_r = h * 0.085
    head_cy = base_y - h + head_r
    draw.ellipse([cx - head_r, head_cy - head_r, cx + head_r, head_cy + head_r], fill=color)
    shoulder_w = h * 0.22
    hip_w = h * 0.15
    body_top = head_cy + head_r
    draw.polygon([
        (cx - shoulder_w / 2, body_top), (cx + shoulder_w / 2, body_top),
        (cx + hip_w / 2, base_y), (cx - hip_w / 2, base_y),
    ], fill=color)
    leg_w = h * 0.06
    draw.rectangle([cx - hip_w / 2, base_y - h * 0.05, cx - leg_w / 2, base_y], fill=color)
    draw.rectangle([cx + leg_w / 2, base_y - h * 0.05, cx + hip_w / 2, base_y], fill=color)


def lamp_post(draw, x, base_y, h, glow_color=(255, 210, 130)):
    """煤气路灯：杆 + 顶灯发光。"""
    draw.rectangle([x - 4, base_y - h, x + 4, base_y], fill=(40, 38, 36))
    draw.ellipse([x - 16, base_y - h - 22, x + 16, base_y - h + 10], fill=glow_color)
    draw.ellipse([x - 10, base_y - h - 16, x + 10, base_y - h + 4], fill=(255, 240, 190))


def soft_text(img, text, pos, size, color, font_path=FONT_BOLD, rotate=0, jitter=0):
    """在独立图层上绘制文字后合成（支持轻微旋转/抖动，模拟手写血字）。"""
    fnt = ImageFont.truetype(font_path, size)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text(pos, text, font=fnt, fill=color)
    if jitter:
        ox = random.randint(-jitter, jitter)
        oy = random.randint(-jitter, jitter)
        layer = layer.transform((W, H), Image.AFFINE, (1, 0, ox, 0, 1, oy))
    if rotate:
        layer = layer.rotate(rotate, resample=Image.BICUBIC, center=pos, expand=False)
    return Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")


# ---------------- 各场景构图 ----------------

def scene_01_lab():
    """贝克街221B — 福尔摩斯私人实验室（暖色室内）。"""
    img = gradient((58, 44, 30), (20, 15, 12))
    img = glow(img, 1480, 360, 520, (255, 200, 120), 0.45)
    p = to_pil(img)
    d = ImageDraw.Draw(p)
    # 木地板
    d.rectangle([0, 820, W, H], fill=(46, 33, 22))
    # 墙面与书架
    d.rectangle([0, 0, W, 200], fill=(40, 30, 22))
    for sx in range(80, W - 80, 150):
        d.rectangle([sx, 210, sx + 120, 800], fill=(52, 38, 26))
        for ry in range(240, 790, 56):
            d.rectangle([sx + 10, ry, sx + 110, ry + 40], fill=(30, 22, 16))
            # 试剂瓶微光
            d.rectangle([sx + 30, ry + 8, sx + 45, ry + 34], fill=(90, 150, 120))
            d.rectangle([sx + 70, ry + 10, sx + 82, ry + 32], fill=(150, 110, 70))
    # 中央实验台
    d.rectangle([760, 640, 1300, 820], fill=(60, 44, 30))
    d.rectangle([760, 620, 1300, 648], fill=(80, 60, 42))
    # 烧瓶（发光）
    d.ellipse([980, 560, 1040, 640], fill=(70, 130, 120))
    d.rectangle([1002, 510, 1018, 565], fill=(70, 130, 120))
    d.ellipse([1120, 580, 1180, 650], fill=(150, 90, 70))
    # 小提琴靠墙
    d.line([1640, 300, 1700, 700], fill=(90, 66, 44), width=14)
    img = np.array(p)
    img = glow(img, 1010, 600, 220, (120, 200, 170), 0.30)
    img = vignette(img, 0.5)
    return grain(img, 6)


def scene_02_garden():
    """劳瑞斯顿花园街三号 — 室外花园（夜雨、车辙与脚印）。"""
    img = gradient((34, 46, 52), (12, 18, 20))
    img = glow(img, 360, 300, 460, (210, 200, 150), 0.5)
    p = to_pil(img)
    d = ImageDraw.Draw(p)
    # 湿地面倒影
    d.rectangle([0, 720, W, H], fill=(18, 26, 28))
    # 远景围栏与宅邸剪影
    skyline(d, 560, (16, 24, 26), min_h=180, max_h=360, step=120)
    d.rectangle([1180, 300, 1560, 560], fill=(14, 20, 22))
    d.polygon([(1180, 300), (1370, 220), (1560, 300)], fill=(14, 20, 22))
    # 花园栅栏
    for fx in range(120, 1120, 60):
        d.rectangle([fx, 540, fx + 10, 720], fill=(26, 34, 30))
    # 车辙（两道平行曲线）
    for off in (-60, 60):
        pts = []
        for t in range(0, 101, 4):
            x = 600 + off + t * 4
            y = 740 + 120 * math.sin(t / 40.0)
            pts.append((x, y))
        if len(pts) > 1:
            d.line(pts, fill=(60, 70, 66), width=10)
    # 脚印（两组点）
    for bx, by in [(760, 880), (800, 940), (840, 1000)]:
        d.ellipse([bx - 14, by - 26, bx + 14, by], fill=(48, 56, 52))
    for bx, by in [(900, 860), (940, 920), (980, 980)]:
        d.ellipse([bx - 12, by - 24, bx + 12, by], fill=(48, 56, 52))
    lamp_post(d, 360, 720, 360)
    img = np.array(p)
    img = vignette(img, 0.55)
    return grain(img, 8)


def scene_03_indoor():
    """劳瑞斯顿花园街三号 — 室内前室（尸体 + 墙上血字 RACHE）。"""
    img = gradient((46, 34, 34), (14, 10, 12))
    img = glow(img, 300, 420, 420, (200, 150, 130), 0.35)
    p = to_pil(img)
    d = ImageDraw.Draw(p)
    # 地板
    d.rectangle([0, 760, W, H], fill=(34, 24, 22))
    # 墙裙
    d.rectangle([0, 720, W, 770], fill=(28, 20, 18))
    # 尸体剪影（躺地）
    person(d, 820, 800, 360, (18, 14, 14))
    d.ellipse([760, 760, 900, 840], fill=(120, 30, 30))  # 身下血泊
    # 空屋门
    d.rectangle([120, 360, 260, 760], fill=(30, 22, 20))
    # 桌上物品
    d.rectangle([520, 600, 760, 640], fill=(50, 38, 30))
    d.ellipse([560, 580, 600, 620], fill=(200, 170, 90))  # 金表
    d.ellipse([640, 588, 672, 620], fill=(200, 170, 90))  # 戒指
    p = soft_text(p, "RACHE", (1180, 200), 120, (170, 24, 24), jitter=3, rotate=-2)
    p = soft_text(p, "RACHE", (1183, 203), 120, (90, 12, 12), jitter=0)  # 暗红阴影
    img = np.array(p)
    img = glow(img, 1240, 280, 260, (180, 40, 40), 0.25)
    img = vignette(img, 0.58)
    return grain(img, 7)


def scene_04_police():
    """布瑞克斯顿路 — 巡警兰斯问询（空屋窗口灯光 + 巡警剪影）。"""
    img = gradient((30, 38, 50), (10, 14, 20))
    img = glow(img, 520, 320, 360, (255, 220, 150), 0.6)
    p = to_pil(img)
    d = ImageDraw.Draw(p)
    # 街面
    d.rectangle([0, 780, W, H], fill=(20, 24, 28))
    # 成排房屋
    x = -20
    while x < W + 20:
        bw = random.randint(150, 230)
        bh = random.randint(260, 420)
        top = 780 - bh
        d.rectangle([x, top, x + bw, 780], fill=(22, 28, 34))
        # 窗
        for wx in range(x + 20, x + bw - 30, 60):
            lit = random.random() < 0.35
            col = (255, 220, 150) if lit else (30, 36, 42)
            d.rectangle([wx, top + 40, wx + 34, top + 90], fill=col)
        x += bw + random.randint(8, 20)
    # 空屋窗口（关键发光点）
    d.rectangle([460, 300, 560, 420], fill=(255, 230, 160))
    d.rectangle([470, 310, 550, 410], fill=(255, 245, 200))
    # 巡警剪影 + 提灯
    person(d, 1100, 800, 380, (12, 14, 18))
    d.ellipse([1180, 560, 1210, 600], fill=(255, 220, 150))
    img = np.array(p)
    img = glow(img, 510, 360, 220, (255, 220, 150), 0.5)
    img = glow(img, 1195, 580, 160, (255, 220, 150), 0.5)
    img = vignette(img, 0.5)
    return grain(img, 7)


def scene_05_parlor():
    """贝克街221B — 会客厅（伪装识破：老太婆 + 晚报）。"""
    img = gradient((52, 40, 30), (18, 14, 12))
    img = glow(img, 1340, 380, 460, (255, 200, 130), 0.42)
    p = to_pil(img)
    d = ImageDraw.Draw(p)
    # 壁炉与火光
    d.rectangle([0, 760, W, H], fill=(40, 30, 24))
    d.rectangle([240, 560, 520, 760], fill=(30, 22, 18))
    d.rectangle([280, 620, 480, 740], fill=(200, 110, 50))
    d.rectangle([300, 650, 460, 720], fill=(255, 180, 80))
    # 地毯
    d.ellipse([600, 820, 1320, 1060], fill=(70, 40, 36))
    # 老太婆剪影（佝偻伪装）
    person(d, 900, 820, 320, (22, 18, 16))
    d.ellipse([880, 500, 930, 545], fill=(22, 18, 16))  # 头巾包覆
    # 茶几 + 晚报
    d.rectangle([560, 700, 760, 740], fill=(58, 42, 30))
    d.rectangle([580, 680, 740, 716], fill=(210, 205, 195))
    d.line([600, 696, 720, 696], fill=(120, 116, 110), width=3)
    d.line([600, 706, 720, 706], fill=(120, 116, 110), width=3)
    img = np.array(p)
    img = glow(img, 380, 680, 260, (255, 160, 70), 0.4)
    img = vignette(img, 0.52)
    return grain(img, 6)


def scene_06_apartment():
    """陶尔魁里卡彭蒂耶公寓（礼帽 + 墙上合影）。"""
    img = gradient((44, 46, 38), (16, 18, 14))
    img = glow(img, 900, 360, 480, (230, 210, 160), 0.4)
    p = to_pil(img)
    d = ImageDraw.Draw(p)
    d.rectangle([0, 800, W, H], fill=(34, 30, 24))
    # 墙与相框
    d.rectangle([820, 240, 1080, 460], fill=(58, 48, 38))
    d.rectangle([840, 260, 1060, 440], fill=(150, 140, 130))  # 照片
    person(d, 970, 440, 150, (60, 52, 44))  # 合影中人物
    # 礼帽（桌上）
    d.rectangle([500, 640, 720, 680], fill=(20, 18, 16))  # 帽檐
    d.ellipse([520, 600, 700, 660], fill=(24, 20, 18))     # 帽冠
    # 椅子
    d.rectangle([540, 680, 700, 800], fill=(46, 36, 28))
    img = np.array(p)
    img = vignette(img, 0.5)
    return grain(img, 7)


def scene_07_hotel():
    """郝黎代旅馆 — 第二被害人（门缝血迹 + 药丸木匣）。"""
    img = gradient((40, 24, 26), (12, 8, 10))
    img = glow(img, 420, 380, 400, (200, 120, 120), 0.4)
    p = to_pil(img)
    d = ImageDraw.Draw(p)
    # 走廊地面
    d.rectangle([0, 780, W, H], fill=(30, 20, 20))
    # 门
    d.rectangle([360, 240, 560, 780], fill=(46, 30, 30))
    d.rectangle([380, 260, 540, 760], fill=(58, 38, 38))
    # 门缝渗出的曲血
    d.rectangle([362, 700, 558, 712], fill=(140, 20, 20))
    d.polygon([(420, 712), (470, 780), (500, 780), (480, 712)], fill=(120, 18, 18))
    d.polygon([(500, 712), (540, 770), (560, 770), (540, 712)], fill=(120, 18, 18))
    # 药丸木匣（桌上）
    d.rectangle([900, 600, 1060, 660], fill=(70, 48, 30))
    d.rectangle([920, 580, 1040, 610], fill=(90, 62, 40))
    d.ellipse([950, 600, 980, 640], fill=(200, 200, 200))  # 药丸
    d.ellipse([1000, 600, 1030, 640], fill=(190, 190, 200))
    img = np.array(p)
    img = glow(img, 460, 740, 200, (170, 30, 30), 0.4)
    img = vignette(img, 0.56)
    return grain(img, 7)


def scene_08_finale():
    """贝克街221B — 起居室（最终对决：马车 + 手铐 + 霍普）。"""
    img = gradient((48, 40, 26), (14, 12, 8))
    img = glow(img, 1280, 420, 520, (255, 205, 120), 0.45)
    p = to_pil(img)
    d = ImageDraw.Draw(p)
    d.rectangle([0, 820, W, H], fill=(38, 30, 20))
    # 背对镜头的马车 + 马
    d.rectangle([1180, 560, 1560, 800], fill=(40, 30, 22))  # 车厢
    d.ellipse([1300, 800, 1360, 860], fill=(20, 16, 12))    # 轮
    d.ellipse([1430, 800, 1490, 860], fill=(20, 16, 12))
    d.rectangle([1560, 520, 1640, 700], fill=(34, 26, 20))  # 马身
    d.ellipse([1640, 500, 1700, 560], fill=(34, 26, 20))    # 马头
    # 高个红脸马车夫剪影（霍普）
    person(d, 740, 820, 420, (26, 16, 12))
    # 钢手铐微光
    d.ellipse([880, 600, 920, 640], fill=(180, 185, 190))
    d.ellipse([930, 600, 970, 640], fill=(180, 185, 190))
    d.rectangle([912, 612, 932, 628], fill=(150, 155, 160))
    img = np.array(p)
    img = glow(img, 900, 620, 160, (190, 195, 200), 0.35)
    img = vignette(img, 0.52)
    return grain(img, 6)


SCENES = [
    ("sc_01_lab", scene_01_lab),
    ("sc_02_garden", scene_02_garden),
    ("sc_03_indoor", scene_03_indoor),
    ("sc_04_police", scene_04_police),
    ("sc_05_parlor", scene_05_parlor),
    ("sc_06_apartment", scene_06_apartment),
    ("sc_07_hotel", scene_07_hotel),
    ("sc_08_finale", scene_08_finale),
]


def main():
    print("生成 P5-3 场景背景美术（%d 张, %dx%d）..." % (len(SCENES), W, H))
    for sid, fn in SCENES:
        arr = fn()
        im = to_pil(arr)
        # 轻微锐化提升质感
        im = im.filter(ImageFilter.SMOOTH_MORE)
        path = os.path.join(OUT, "%s.png" % sid)
        im.save(path, "PNG")
        print("  ✔ %s.png" % sid)
    print("输出目录: %s" % OUT)


if __name__ == "__main__":
    main()
