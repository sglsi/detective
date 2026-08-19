# 复用旧版 split_parts.py 的成熟切分逻辑，适配新「福尔摩斯正面拆分图」。
# 关键修正：
#  - 新图为正面图（脸朝我们）：图片左半 = 角色右半身，故输出文件名对 L/R 做镜像
#    （J 坐标仍用旧约定 shoulder_L=CX-dx 取图片左，但存盘时 _L<->_R 互换）
#  - 去掉独立 hand 段（新图前臂含手），fore_arm 从肘切到指尖（含手）
#  - foot 不旋转（旧版 axis box 从踝向下，REST=90 在 HTML 处理），head flip_y=True
import os, math
from PIL import Image, ImageDraw, ImageChops
import numpy as np

SRC = r"C:\Users\sglsi\Desktop\项目\我是大侦探\图片\person\拆分\福尔摩斯正面拆分图 透明.png"
OUT_DIR = r"D:\AI\detective\godot_project\assets\sherlock_front_parts"
os.makedirs(OUT_DIR, exist_ok=True)

IMG = Image.open(SRC).convert("RGBA")
W, H = IMG.size
a = np.array(IMG)[:, :, 3]
ys, xs = np.where(a > 10)
content_top = min(ys) if len(ys) else 0
content_bottom = max(ys) if len(ys) else H
content_h = content_bottom - content_top + 1 if len(ys) else H

TARGET_U_PX = 72.0
scale = (8.0 * TARGET_U_PX) / content_h
if abs(scale - 1.0) > 0.001:
    IMG = IMG.resize((max(1, int(round(W * scale))), max(1, int(round(H * scale)))),
                     Image.Resampling.LANCZOS)
    W, H = IMG.size
    a = np.array(IMG)[:, :, 3]
    ys, xs = np.where(a > 10)
    content_top = min(ys); content_bottom = max(ys)
    content_h = content_bottom - content_top + 1
u_px = TARGET_U_PX
CX = W / 2.0
print(f"scaled content_top={content_top}, content_h={content_h}, u_px={u_px:.2f}, scale={scale:.3f}")

L = {"head":1.0, "torso":2.5, "upper_arm":1.3, "fore_arm":1.1, "hand":0.8,
     "thigh":1.9, "shin":1.7, "foot":0.45}
# 切分时 fore_arm 含手：合计长度
FORE_WITH_HAND = L["fore_arm"] + L["hand"]
Wdt = {"head":1.00, "torso":1.45, "upper_arm":0.34, "fore_arm":0.28, "hand":0.26,
       "thigh":0.46, "shin":0.34, "foot":0.40}

neck_y = content_top + 1.0 * u_px
shoulder_y = neck_y + 0.22 * u_px
shoulder_dx = 0.65 * u_px
hip_y = neck_y + L["torso"] * u_px
hip_dx = 0.26 * u_px

ANG = {
    "upper_arm_L": -2, "upper_arm_R": 2,
    "thigh_L": -2, "thigh_R": 2,
}
def pt_from(p, deg, dist):
    rad = math.radians(deg)
    return (p[0] + math.sin(rad) * dist, p[1] + math.cos(rad) * dist)

def capsule_mask(size, length, width):
    w, h = size
    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    r = width / 2.0
    if length < 1: length = 1
    draw.rectangle([w/2 - r, 0, w/2 + r, length], fill=255)
    draw.ellipse([w/2 - r, -r, w/2 + r, r], fill=255)
    draw.ellipse([w/2 - r, length - r, w/2 + r, length + r], fill=255)
    return mask

def extract_straight(p1, p2, width, pad_ratio=0.12):
    dx = p2[0] - p1[0]; dy = p2[1] - p1[1]
    bone_len = math.hypot(dx, dy)
    angle = math.degrees(math.atan2(dx, dy))
    rotated = IMG.rotate(-angle, resample=Image.Resampling.BICUBIC,
                         expand=False, center=p1, fillcolor=(0,0,0,0))
    pad = bone_len * pad_ratio
    x1 = int(p1[0] - width/2 - 4); y1 = int(p1[1] - pad)
    x2 = int(p1[0] + width/2 + 4); y2 = int(p1[1] + bone_len + pad)
    crop = rotated.crop((max(0,x1), max(0,y1), min(W,x2), min(H,y2)))
    # 不再切成胶囊圆头：保留自然矩形+小重叠，避免关节处鼓包
    return crop

def extract_axis_box(center_top, w, h, flip_y=False, top_w=None, bottom_w=None):
    x1 = int(center_top[0] - w/2); y1 = int(center_top[1])
    x2 = int(center_top[0] + w/2); y2 = int(center_top[1] + h)
    crop = IMG.crop((max(0,x1), max(0,y1), min(W,x2), min(H,y2)))
    cw, ch = crop.size
    if top_w is not None and bottom_w is not None:
        mask = Image.new("L", (cw, ch), 0)
        draw = ImageDraw.Draw(mask)
        poly = [(cw/2 - top_w/2, 0), (cw/2 + top_w/2, 0),
                (cw/2 + bottom_w/2, ch), (cw/2 - bottom_w/2, ch)]
        draw.polygon(poly, fill=255)
        old_alpha = crop.split()[3] if crop.mode == 'RGBA' else Image.new('L', crop.size, 255)
        crop.putalpha(ImageChops.multiply(old_alpha, mask))
    if flip_y:
        crop = crop.transpose(Image.FLIP_TOP_BOTTOM)
    return crop

J = {
    "head_top": (CX, content_top),
    "neck":     (CX, neck_y),
    "shoulder_L": (CX - shoulder_dx, shoulder_y),
    "shoulder_R": (CX + shoulder_dx, shoulder_y),
    "hip_L":    (CX - hip_dx, hip_y),
    "hip_R":    (CX + hip_dx, hip_y),
}
J["elbow_L"] = pt_from(J["shoulder_L"], ANG["upper_arm_L"], L["upper_arm"]*u_px)
J["elbow_R"] = pt_from(J["shoulder_R"], ANG["upper_arm_R"], L["upper_arm"]*u_px)
J["wrist_L"] = pt_from(J["elbow_L"], 0, L["fore_arm"]*u_px)
J["wrist_R"] = pt_from(J["elbow_R"], 0, L["fore_arm"]*u_px)
J["finger_L"] = pt_from(J["wrist_L"], 0, L["hand"]*u_px)
J["finger_R"] = pt_from(J["wrist_R"], 0, L["hand"]*u_px)
J["knee_L"]  = pt_from(J["hip_L"], ANG["thigh_L"], L["thigh"]*u_px)
J["knee_R"]  = pt_from(J["hip_R"], ANG["thigh_R"], L["thigh"]*u_px)
J["ankle_L"] = pt_from(J["knee_L"], 0, L["shin"]*u_px)
J["ankle_R"] = pt_from(J["knee_R"], 0, L["shin"]*u_px)
J["toe_L"]   = pt_from(J["ankle_L"], 0, L["foot"]*u_px)
J["toe_R"]   = pt_from(J["ankle_R"], 0, L["foot"]*u_px)

NECK_OVERLAP = 0.10 * u_px   # head/torso 覆盖脖子
HIP_OVERLAP  = 0.30 * u_px   # torso 覆盖臀部与大腿根
LIMB_OVERLAP = 0.10 * u_px   # 四肢关节处小重叠

# name(规范, 取图片左肢体用 _L) -> (strategy, pad_ratio, params)
parts = {
    "head":      ("axis", 0.0, (CX, content_top), Wdt["head"]*u_px*1.15, (neck_y - content_top) + NECK_OVERLAP, True),
    # torso 用宽矩形：覆盖躯干+肩+胯，保留自然形状，避免手臂/腿根露缝
    "torso":     ("axis", 0.0, (J["neck"][0], J["neck"][1] - NECK_OVERLAP), 1.65*u_px, L["torso"]*u_px + NECK_OVERLAP + HIP_OVERLAP, False),
    "upper_arm_L": ("straight", 0.10, J["shoulder_L"], J["elbow_L"], Wdt["upper_arm"]*u_px),
    "upper_arm_R": ("straight", 0.10, J["shoulder_R"], J["elbow_R"], Wdt["upper_arm"]*u_px),
    # fore_arm 含手：从肘切到指尖
    "fore_arm_L":  ("straight", 0.10, J["elbow_L"], J["finger_L"], Wdt["fore_arm"]*u_px*1.25),
    "fore_arm_R":  ("straight", 0.10, J["elbow_R"], J["finger_R"], Wdt["fore_arm"]*u_px*1.25),
    "thigh_L":   ("straight", 0.10, J["hip_L"], J["knee_L"], Wdt["thigh"]*u_px),
    "thigh_R":   ("straight", 0.10, J["hip_R"], J["knee_R"], Wdt["thigh"]*u_px),
    "shin_L":    ("straight", 0.10, J["knee_L"], J["ankle_L"], Wdt["shin"]*u_px),
    "shin_R":    ("straight", 0.10, J["knee_R"], J["ankle_R"], Wdt["shin"]*u_px),
    "foot_L":    ("axis", 0.0, (J["ankle_L"][0], J["ankle_L"][1] - LIMB_OVERLAP), Wdt["foot"]*u_px*1.8, L["foot"]*u_px*2.0 + LIMB_OVERLAP, False),
    "foot_R":    ("axis", 0.0, (J["ankle_R"][0], J["ankle_R"][1] - LIMB_OVERLAP), Wdt["foot"]*u_px*1.8, L["foot"]*u_px*2.0 + LIMB_OVERLAP, False),
}

def mirror_name(name):
    # 正面图：图片左肢体(规范 _L)镜像存为 _R，图片右(_R)存为 _L
    if name.endswith("_L"):
        return name[:-2] + "_R"
    if name.endswith("_R"):
        return name[:-2] + "_L"
    return name

preview = IMG.copy()
draw = ImageDraw.Draw(preview, "RGBA")
for k, v in J.items():
    draw.ellipse([v[0]-3, v[1]-3, v[0]+3, v[1]+3], fill="red")

import json
meta = {}
for name, spec in parts.items():
    strategy = spec[0]; pad_ratio = spec[1]
    if strategy == "axis":
        _, _, top, pw, ph, flip_y = spec
        img = extract_axis_box(top, pw, ph, flip_y=flip_y)
    elif strategy == "trapezoid":
        _, _, top, pw, ph, top_w, bottom_w = spec
        img = extract_axis_box(top, pw, ph, top_w=top_w, bottom_w=bottom_w)
    else:
        _, _, p1, p2, width = spec
        img = extract_straight(p1, p2, width, pad_ratio=pad_ratio)
    out_name = mirror_name(name)
    img.save(os.path.join(OUT_DIR, f"{out_name}.png"))
    meta[out_name] = {"pad_ratio": pad_ratio}
    print(f"saved {out_name}.png size={img.size} (from {name})")

with open(os.path.join(OUT_DIR, "parts_meta.json"), "w", encoding="utf-8") as f:
    json.dump(meta, f, indent=2)
preview.save(os.path.join(OUT_DIR, "_parts_overlay.png"))
print("done")
