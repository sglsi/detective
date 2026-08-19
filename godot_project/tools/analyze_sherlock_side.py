#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""分析福尔摩斯侧面拆分图位置，生成关节 rig 元数据，并导出紧凑裁切图。"""
import os, json, shutil
from PIL import Image

SRC_DIR = "C:/Users/sglsi/Desktop/项目/我是大侦探/图片/person/拆分/福尔摩斯/侧视图拆分"
DST_DIR = "D:/AI/detective/godot_project/assets/sherlock_side_parts"
CROP_DIR = os.path.join(DST_DIR, "cropped")

NAME_MAP = {
    "福尔摩斯 侧面 拆分图 躯干.png": "torso.png",
    "福尔摩斯 侧面 拆分图 头.png": "head.png",
    "福尔摩斯 侧面 拆分图 右上臂.png": "upper_arm_R.png",
    "福尔摩斯 侧面 拆分图 右小臂.png": "fore_arm_R.png",
    "福尔摩斯 侧面 拆分图 右大腿.png": "thigh_R.png",
    "福尔摩斯 侧面 拆分图 右小腿.png": "shin_R.png",
    "福尔摩斯 侧面 拆分图 右脚.png": "foot_R.png",
    "福尔摩斯 侧面 拆分图 左上臂.png": "upper_arm_L.png",
    "福尔摩斯 侧面 拆分图 左小臂.png": "fore_arm_L.png",
    "福尔摩斯 侧面 拆分图 左大腿.png": "thigh_L.png",
    "福尔摩斯 侧面 拆分图 左小腿.png": "shin_L.png",
    "福尔摩斯 侧面 拆分图 左脚.png": "foot_L.png",
}

# 1. 复制并重命名
os.makedirs(DST_DIR, exist_ok=True)
os.makedirs(CROP_DIR, exist_ok=True)
for src_name, dst_name in NAME_MAP.items():
    src = os.path.join(SRC_DIR, src_name)
    dst = os.path.join(DST_DIR, dst_name)
    if os.path.exists(src):
        shutil.copy2(src, dst)
        print(f"copy {src_name} -> {dst_name}")
    else:
        print(f"MISSING {src_name}")

# 2. 分析 bbox（基于原始全图，保留部件间相对位置）
def bbox_info(path):
    im = Image.open(path)
    if im.mode != "RGBA":
        im = im.convert("RGBA")
    alpha = im.getchannel("A")
    bbox = alpha.getbbox()
    if not bbox:
        return None
    x1, y1, x2, y2 = bbox
    cx = (x1 + x2) / 2
    cy = (y1 + y2) / 2
    return {
        "size": im.size,
        "bbox": bbox,
        "top": (cx, y1),
        "bottom": (cx, y2),
        "left": (x1, cy),
        "right": (x2, cy),
        "center": (cx, cy),
        "width": x2 - x1,
        "height": y2 - y1,
    }

infos = {}
for dst_name in sorted(NAME_MAP.values()):
    key = dst_name.replace(".png", "")
    path = os.path.join(DST_DIR, dst_name)
    infos[key] = bbox_info(path)
    info = infos[key]
    print(f"{key}: size={info['size']} bbox={info['bbox']} h={info['height']:.1f} w={info['width']:.1f}")

# 3. 导出紧凑裁切图：去掉 2048 画布的大片透明，只保留内容
#    脚在侧视图中是水平前后伸展，需先旋转 90° 使其与骨骼方向一致（上=脚踝，下=脚尖）。
def crop_part(key):
    src_path = os.path.join(DST_DIR, key + ".png")
    im = Image.open(src_path)
    if im.mode != "RGBA":
        im = im.convert("RGBA")
    alpha = im.getchannel("A")
    bbox = alpha.getbbox()
    if not bbox:
        return None
    cropped = im.crop(bbox)
    # 脚旋转：使脚踝在上、脚尖在下
    if key.startswith("foot_"):
        # 原图脚尖朝左（x 小），脚踝朝右（x 大）。逆时针 90° 后：上=右=脚踝，下=左=脚尖
        cropped = cropped.rotate(90, expand=True, resample=Image.Resampling.BICUBIC)
    return cropped

cropped_infos = {}
for key in infos:
    cropped = crop_part(key)
    if cropped is None:
        continue
    out_path = os.path.join(CROP_DIR, key + ".png")
    cropped.save(out_path)
    # 记录裁剪后尺寸
    cropped_infos[key] = {"size": cropped.size}
    print(f"crop {key} -> {cropped.size}")

# 4. 推导关节点（以 torso 顶端/neck 为原点）
neck = infos["torso"]["top"]
hip = infos["torso"]["bottom"]

head_bottom = infos["head"]["bottom"]
head_top = infos["head"]["top"]

shoulder_L = infos["upper_arm_L"]["top"]
shoulder_R = infos["upper_arm_R"]["top"]
elbow_L = infos["upper_arm_L"]["bottom"]
elbow_R = infos["upper_arm_R"]["bottom"]
wrist_L = infos["fore_arm_L"]["bottom"]
wrist_R = infos["fore_arm_R"]["bottom"]

hip_L = infos["thigh_L"]["top"]
hip_R = infos["thigh_R"]["top"]
knee_L = infos["thigh_L"]["bottom"]
knee_R = infos["thigh_R"]["bottom"]
ankle_L = infos["shin_L"]["bottom"]
ankle_R = infos["shin_R"]["bottom"]

# 脚：侧视水平，用左右宽度作为长度，脚踝=右侧，脚尖=左侧
foot_top_L = infos["foot_L"]["right"]   # 脚踝
foot_top_R = infos["foot_R"]["right"]
toe_L = infos["foot_L"]["left"]        # 脚尖
toe_R = infos["foot_R"]["left"]

def dist(a, b):
    return ((a[0]-b[0])**2 + (a[1]-b[1])**2) ** 0.5

PX = dist(neck, head_top)
print(f"\nneck={neck}, hip={hip}, head_bottom={head_bottom}, PX(head_height)={PX:.2f}")

def u(p):
    dx = p[0] - neck[0]
    dy = p[1] - neck[1]
    return (dx / PX, dy / PX)

meta = {
    "px_per_unit": PX,
    "origin": "neck (torso top center)",
    "joints": {
        "neck": u(neck), "hip": u(hip), "head_top": u(head_top),
        "shoulder_L": u(shoulder_L), "shoulder_R": u(shoulder_R),
        "elbow_L": u(elbow_L), "elbow_R": u(elbow_R),
        "wrist_L": u(wrist_L), "wrist_R": u(wrist_R),
        "hip_L": u(hip_L), "hip_R": u(hip_R),
        "knee_L": u(knee_L), "knee_R": u(knee_R),
        "ankle_L": u(ankle_L), "ankle_R": u(ankle_R),
        "toe_L": u(toe_L), "toe_R": u(toe_R),
    },
    "lengths_u": {
        "head": u(head_top)[1] * -1,
        "torso": u(hip)[1],
        "upper_arm_L": dist(shoulder_L, elbow_L) / PX,
        "upper_arm_R": dist(shoulder_R, elbow_R) / PX,
        "fore_arm_L": dist(elbow_L, wrist_L) / PX,
        "fore_arm_R": dist(elbow_R, wrist_R) / PX,
        "thigh_L": dist(hip_L, knee_L) / PX,
        "thigh_R": dist(hip_R, knee_R) / PX,
        "shin_L": dist(knee_L, ankle_L) / PX,
        "shin_R": dist(knee_R, ankle_R) / PX,
        "foot_L": dist(foot_top_L, toe_L) / PX,
        "foot_R": dist(foot_top_R, toe_R) / PX,
    },
    "anchors_u": {
        "torso": [0, 0],
        "head": u(head_bottom),
        "upper_arm_L": u(shoulder_L), "upper_arm_R": u(shoulder_R),
        "fore_arm_L": [0, u(elbow_L)[1] - u(shoulder_L)[1]],
        "fore_arm_R": [0, u(elbow_R)[1] - u(shoulder_R)[1]],
        "thigh_L": u(hip_L), "thigh_R": u(hip_R),
        "shin_L": [0, u(knee_L)[1] - u(hip_L)[1]],
        "shin_R": [0, u(knee_R)[1] - u(hip_R)[1]],
        "foot_L": [0, u(ankle_L)[1] - u(knee_L)[1]],
        "foot_R": [0, u(ankle_R)[1] - u(knee_R)[1]],
    },
    "pad_ratio": {},
}

# 5. 计算 pad_ratio：用裁切后的尺寸 vs 骨骼长度
for key in infos:
    bone_len_px = meta["lengths_u"][key] * PX
    cw, ch = cropped_infos[key]["size"]
    # 脚已旋转，方向与骨骼一致，用高度；其余竖直部件也用高度
    img_len = ch
    if bone_len_px > 0:
        meta["pad_ratio"][key] = max(0.0, (img_len / bone_len_px - 1.0) / 2.0)
        print(f"{key}: bone_len={bone_len_px:.1f}px crop_len={img_len}px pad_ratio={meta['pad_ratio'][key]:.3f}")

# 保存元数据
meta_path = os.path.join(DST_DIR, "side_parts_meta.json")
with open(meta_path, "w", encoding="utf-8") as f:
    json.dump(meta, f, ensure_ascii=False, indent=2)
print(f"\nmeta saved -> {meta_path}")

# 6. 输出 JS 配置片段
print("\n--- JS BONES 配置 ---")
print(f"const PX = {PX:.1f};")
print("const L = {", end="")
for k in ["head","torso","upper_arm","fore_arm","thigh","shin","foot"]:
    if k == "head":
        v = meta["lengths_u"]["head"]
    elif k == "torso":
        v = meta["lengths_u"]["torso"]
    else:
        v = (meta["lengths_u"][f"{k}_L"] + meta["lengths_u"][f"{k}_R"]) / 2
    print(f" {k}:{v:.3f},", end="")
print(" };")

print("const ANCHORS = {")
print(f'  torso:[0,0],\n  head:[{meta["anchors_u"]["head"][0]:.3f},{meta["anchors_u"]["head"][1]:.3f}],')
for side in ["L","R"]:
    print(f'  upper_arm_{side}:[{meta["anchors_u"][f"upper_arm_{side}"][0]:.3f},{meta["anchors_u"][f"upper_arm_{side}"][1]:.3f}],')
    print(f'  fore_arm_{side}:[0,{meta["anchors_u"][f"fore_arm_{side}"][1]:.3f}],')
    print(f'  thigh_{side}:[{meta["anchors_u"][f"thigh_{side}"][0]:.3f},{meta["anchors_u"][f"thigh_{side}"][1]:.3f}],')
    print(f'  shin_{side}:[0,{meta["anchors_u"][f"shin_{side}"][1]:.3f}],')
    print(f'  foot_{side}:[0,{meta["anchors_u"][f"foot_{side}"][1]:.3f}],')
print("};")

print("const PARTS_META = {")
for key in infos:
    print(f'  "{key}":{{"pad_ratio":{meta["pad_ratio"][key]:.3f}}},')
print("};")
