from PIL import Image, ImageDraw
import os, math

SRC = "D:\\AI\\detective\\godot_project\\assets\\sherlock_parts\\sherlock_clean.png"
OUT_DIR = "D:\\AI\\detective\\godot_project\\assets\\sherlock_parts"
IMG = Image.open(SRC).convert("RGBA")
W, H = IMG.size

import numpy as np

# 用非透明内容的实际高度计算 1 头身像素；并记录内容顶部偏移
a = np.array(IMG)[:, :, 3]
ys, xs = np.where(a > 10)
content_top = min(ys) if len(ys) else 0
content_bottom = max(ys) if len(ys) else H
content_h = content_bottom - content_top + 1 if len(ys) else H
u_px = content_h / 8.0
CX = W / 2.0
print(f"content_top={content_top}, content_h={content_h}, u_px={u_px:.2f}")

L = {"head":1.0, "torso":2.5, "upper_arm":1.3, "fore_arm":1.1, "hand":0.8,
     "thigh":1.9, "shin":1.7, "foot":0.45}
# 部件宽度：比规范更宽，确保切到完整肢体并留重叠
Wdt = {"head":1.00, "torso":1.30, "upper_arm":0.38, "fore_arm":0.30, "hand":0.28,
       "thigh":0.44, "shin":0.34, "foot":0.45}

# 全局关节坐标（像素）：以 content_top 为基准
neck_y = content_top + 1.0 * u_px
shoulder_y = neck_y + 0.20*u_px
shoulder_dx = 0.55*u_px
hip_y = neck_y + L["torso"]*u_px

ANG = {
    "upper_arm_L": -26, "upper_arm_R": 26,
    "fore_arm_L": -18,  "fore_arm_R": 18,
    "hand_L": -12,      "hand_R": 12,
    "thigh_L": -6,      "thigh_R": 6,
    "shin_L": -2,       "shin_R": 2,
    "foot_L": -85,      "foot_R": 85,
}

def pt_from(p, deg, dist):
    rad = math.radians(deg)
    return (p[0] + math.sin(rad)*dist, p[1] + math.cos(rad)*dist)

def capsule_mask(size, length, width):
    """创建胶囊形蒙版：沿 Y 轴，顶部圆心在 (w/2,0)，底部圆心在 (w/2,length)，
       两端半圆，中间矩形。"""
    w, h = size
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    r = width / 2.0
    if length < 1:
        length = 1
    # 矩形主体
    draw.rectangle([w/2 - r, 0, w/2 + r, length], fill=255)
    # 顶部半圆
    draw.ellipse([w/2 - r, -r, w/2 + r, r], fill=255)
    # 底部半圆
    draw.ellipse([w/2 - r, length - r, w/2 + r, length + r], fill=255)
    return mask

def extract_straight(p1, p2, width, pad_ratio=0.35):
    """以 p1 为顶部中心，沿 p1->p2 方向切出拉直贴图。
       两端各留 pad_ratio*length 的 overlap padding，并用胶囊形蒙版柔化边缘。"""
    dx = p2[0] - p1[0]
    dy = p2[1] - p1[1]
    bone_len = math.hypot(dx, dy)
    angle = math.degrees(math.atan2(dx, dy))  # 正=顺时针偏离垂直
    # 旋转原图使肢体垂直（以 p1 为中心）
    rotated = IMG.rotate(-angle, resample=Image.Resampling.BICUBIC,
                         expand=False, center=p1, fillcolor=(0,0,0,0))
    pad = bone_len * pad_ratio
    length = bone_len + 2 * pad
    x1 = int(p1[0] - width/2 - 4)
    y1 = int(p1[1] - pad)
    x2 = int(p1[0] + width/2 + 4)
    y2 = int(p1[1] + bone_len + pad)
    crop = rotated.crop((max(0,x1), max(0,y1), min(W,x2), min(H,y2)))
    # 应用胶囊蒙版：让贴图两端圆润并保留重叠区肉感
    mask = capsule_mask(crop.size, length, width)
    if crop.mode == 'RGBA':
        old_alpha = crop.split()[3]
    else:
        old_alpha = Image.new('L', crop.size, 255)
    crop.putalpha(ImageChops.multiply(old_alpha, mask))
    return crop

def extract_axis_box(center_top, w, h, flip_y=False, top_w=None, bottom_w=None):
    """切轴向包围盒/梯形，以 center_top 为上边中心，向下 h。
       用于 head/torso/hand/foot 等不必拉直的部位。
       若给定 top_w/bottom_w，则用上窄下宽梯形蒙版（适合躯干）。"""
    x1 = int(center_top[0] - w/2)
    y1 = int(center_top[1])
    x2 = int(center_top[0] + w/2)
    y2 = int(center_top[1] + h)
    crop = IMG.crop((max(0,x1), max(0,y1), min(W,x2), min(H,y2)))
    cw, ch = crop.size
    if top_w is not None and bottom_w is not None:
        # 梯形蒙版：上底 top_w，下底 bottom_w，居中
        mask = Image.new("L", (cw, ch), 0)
        draw = ImageDraw.Draw(mask)
        tw, bw = top_w, bottom_w
        poly = [(cw/2 - tw/2, 0), (cw/2 + tw/2, 0),
                (cw/2 + bw/2, ch), (cw/2 - bw/2, ch)]
        draw.polygon(poly, fill=255)
        if crop.mode == 'RGBA':
            old_alpha = crop.split()[3]
        else:
            old_alpha = Image.new('L', crop.size, 255)
        crop.putalpha(ImageChops.multiply(old_alpha, mask))
    if flip_y:
        crop = crop.transpose(Image.FLIP_TOP_BOTTOM)
    return crop

from PIL import ImageChops

# 关节点
J = {
    "head_top": (CX, 0),
    "neck":     (CX, neck_y),
    "shoulder_L": (CX - shoulder_dx, shoulder_y),
    "shoulder_R": (CX + shoulder_dx, shoulder_y),
    "hip_L":    (CX - 0.20*u_px, hip_y),
    "hip_R":    (CX + 0.20*u_px, hip_y),
}
J["elbow_L"] = pt_from(J["shoulder_L"], ANG["upper_arm_L"], L["upper_arm"]*u_px)
J["elbow_R"] = pt_from(J["shoulder_R"], ANG["upper_arm_R"], L["upper_arm"]*u_px)
J["wrist_L"] = pt_from(J["elbow_L"], ANG["fore_arm_L"], L["fore_arm"]*u_px)
J["wrist_R"] = pt_from(J["elbow_R"], ANG["fore_arm_R"], L["fore_arm"]*u_px)
J["finger_L"] = pt_from(J["wrist_L"], ANG["hand_L"], L["hand"]*u_px)
J["finger_R"] = pt_from(J["wrist_R"], ANG["hand_R"], L["hand"]*u_px)
J["knee_L"]  = pt_from(J["hip_L"], ANG["thigh_L"], L["thigh"]*u_px)
J["knee_R"]  = pt_from(J["hip_R"], ANG["thigh_R"], L["thigh"]*u_px)
J["ankle_L"] = pt_from(J["knee_L"], ANG["shin_L"], L["shin"]*u_px)
J["ankle_R"] = pt_from(J["knee_R"], ANG["shin_R"], L["shin"]*u_px)
J["toe_L"]   = pt_from(J["ankle_L"], ANG["foot_L"], L["foot"]*u_px)
J["toe_R"]   = pt_from(J["ankle_R"], ANG["foot_R"], L["foot"]*u_px)

# 各部位切分策略
parts = {
    # name: (strategy, pad_ratio, params...)
    # head：从图像顶部切到颈根，确保包含完整头发
    "head":      ("axis", 0.0, (CX, 0), Wdt["head"]*u_px*1.3, neck_y * 1.05, True),  # flip_y so neck at top
    # torso：上窄下宽梯形，避开脸部同时覆盖躯干与胯部
    "torso":     ("trapezoid", 0.0, J["neck"], Wdt["torso"]*u_px, L["torso"]*u_px, 0.65*u_px, 1.1*u_px),
    "upper_arm_L": ("straight", 0.35, J["shoulder_L"], J["elbow_L"], Wdt["upper_arm"]*u_px),
    "upper_arm_R": ("straight", 0.35, J["shoulder_R"], J["elbow_R"], Wdt["upper_arm"]*u_px),
    "fore_arm_L":  ("straight", 0.35, J["elbow_L"], J["wrist_L"], Wdt["fore_arm"]*u_px),
    "fore_arm_R":  ("straight", 0.35, J["elbow_R"], J["wrist_R"], Wdt["fore_arm"]*u_px),
    "hand_L":    ("axis", 0.0, J["wrist_L"], Wdt["hand"]*u_px*1.6, L["hand"]*u_px*1.5, False),
    "hand_R":    ("axis", 0.0, J["wrist_R"], Wdt["hand"]*u_px*1.6, L["hand"]*u_px*1.5, False),
    "thigh_L":   ("straight", 0.35, J["hip_L"], J["knee_L"], Wdt["thigh"]*u_px),
    "thigh_R":   ("straight", 0.35, J["hip_R"], J["knee_R"], Wdt["thigh"]*u_px),
    "shin_L":    ("straight", 0.35, J["knee_L"], J["ankle_L"], Wdt["shin"]*u_px),
    "shin_R":    ("straight", 0.35, J["knee_R"], J["ankle_R"], Wdt["shin"]*u_px),
    "foot_L":    ("axis", 0.0, J["ankle_L"], Wdt["foot"]*u_px*2.2, L["foot"]*u_px*2.5, False),
    "foot_R":    ("axis", 0.0, J["ankle_R"], Wdt["foot"]*u_px*2.2, L["foot"]*u_px*2.5, False),
}

preview = IMG.copy()
draw = ImageDraw.Draw(preview, "RGBA")
for k, v in J.items():
    draw.ellipse([v[0]-3, v[1]-3, v[0]+3, v[1]+3], fill="red")

import json
meta = {}
for name, spec in parts.items():
    strategy = spec[0]
    pad_ratio = spec[1]
    if strategy == "axis":
        _, _, top, pw, ph, flip_y = spec
        img = extract_axis_box(top, pw, ph, flip_y=flip_y)
        # 画切分框
        x1, y1 = top[0] - pw/2, top[1]
        x2, y2 = top[0] + pw/2, top[1] + ph
        draw.rectangle([x1, y1, x2, y2], outline="cyan", width=2)
    elif strategy == "trapezoid":
        _, _, top, pw, ph, top_w, bottom_w = spec
        img = extract_axis_box(top, pw, ph, top_w=top_w, bottom_w=bottom_w)
        x1, y1 = top[0] - pw/2, top[1]
        x2, y2 = top[0] + pw/2, top[1] + ph
        draw.rectangle([x1, y1, x2, y2], outline="cyan", width=2)
    else:
        _, _, p1, p2, width = spec
        img = extract_straight(p1, p2, width, pad_ratio=pad_ratio)
        draw.line([p1, p2], fill="cyan", width=2)
        r = width/2
        draw.ellipse([p1[0]-r, p1[1]-r, p1[0]+r, p1[1]+r], outline="cyan", width=1)
        draw.ellipse([p2[0]-r, p2[1]-r, p2[0]+r, p2[1]+r], outline="cyan", width=1)
    img.save(os.path.join(OUT_DIR, f"{name}.png"))
    meta[name] = {"pad_ratio": pad_ratio}
    print(f"saved {name}.png size={img.size}")

with open(os.path.join(OUT_DIR, "parts_meta.json"), "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=2)
print("saved parts_meta.json")

preview.save(os.path.join(OUT_DIR, "_joints_preview.png"))
print("saved _joints_preview.png")
