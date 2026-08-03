#!/usr/bin/env python3
"""一站式拆分参考图并生成 rig 测试素材。

直接输出 9 个最终部件（head/torso/upperarm_L/R/forearm_L/R/thigh_L/R/shin_L/R），
不保留中间小碎片，避免触发批量删除安全确认。
"""
import json
import sys
from pathlib import Path

from PIL import Image
import numpy as np

SRC = Path(r"C:\Users\sglsi\.workbuddy\clipboard-images\clipboard-2026-08-03T07-50-20-782Z-2b0c689f.jpg")
OUT_DIR = Path(r"D:\AI\detective\godot_project\assets\characters\test_rig_character\rig")
RIG_JSON = OUT_DIR / "_rig_spec.json"

BG_COLOR = (255, 255, 255)
BG_TOLERANCE = 35
MIN_AREA = 15000
PADDING = 0   # 贴边裁切：去掉透明边，让 GAP 直接等于可见间隙（否则 padding 会淹没 GAP）

# 根据参考图布局：原图哪些连通块对应哪个身体部件
# 键：按第一次 split_rig_reference.py 的 area 降序 + 位置得到的原始文件名
PART_IDENTITY = {
    "upperarm_L.png": "head",
    "part_b0_c12.png": "upperarm_L",
    "part_b0_c7.png": "torso",
    "part_b1_c13.png": "forearm_L",
    "part_b1_c5.png": "forearm_R",
    "part_b0_c6.png": "upperarm_R",
    "part_b0_c9.png": None,            # 左上臂残段，与 top-right 重复，不用
    "part_b2_c6.png": "leg_full_R",
    "part_b2_c9.png": "leg_full_L",
}


def main() -> int:
    if not SRC.exists():
        print(f"[ERR] source not found: {SRC}", file=sys.stderr)
        return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    img = Image.open(SRC).convert("RGBA")
    arr = np.array(img)

    # 前景 mask
    diff = np.abs(arr[:, :, :3].astype(np.int16) - np.array(BG_COLOR, dtype=np.int16))
    bg = (diff.max(axis=2) <= BG_TOLERANCE) & (arr[:, :, 3] > 128)
    fg = ~bg

    from scipy.ndimage import label
    labeled, n = label(fg)
    print(f"[INFO] {n} raw components")

    # 收集大部件并映射身份
    parts: dict[str, dict] = {}
    for idx in range(1, n + 1):
        ys, xs = np.where(labeled == idx)
        if len(xs) < MIN_AREA:
            continue
        x1, y1, x2, y2 = int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())

        x1p = max(0, x1 - PADDING)
        y1p = max(0, y1 - PADDING)
        x2p = min(img.width - 1, x2 + PADDING)
        y2p = min(img.height - 1, y2 + PADDING)

        crop = img.crop((x1p, y1p, x2p + 1, y2p + 1))
        crop_arr = np.array(crop)
        cdiff = np.abs(crop_arr[:, :, :3].astype(np.int16) - np.array(BG_COLOR, dtype=np.int16))
        transparent = (cdiff.max(axis=2) <= BG_TOLERANCE) | (crop_arr[:, :, 3] <= 128)
        crop_arr[transparent] = (0, 0, 0, 0)
        crop = Image.fromarray(crop_arr, "RGBA")

        orig_name = guess_orig_name(x1, y1, x2, y2, crop.width, crop.height)
        target = PART_IDENTITY.get(orig_name)
        if target is None:
            print(f"  skip {orig_name} ({crop.width}x{crop.height})")
            continue

        out_name = f"{target}.png"
        out_path = OUT_DIR / out_name
        crop.save(out_path)
        parts[target] = {"filename": out_name, "size": [crop.width, crop.height]}
        print(f"  -> {target}: {crop.width}x{crop.height}")

    # 拆分全腿
    for side in ["R", "L"]:
        key = f"leg_full_{side}"
        if key not in parts:
            continue
        leg_path = OUT_DIR / parts[key]["filename"]
        leg_img = Image.open(leg_path).convert("RGBA")
        split_y = int(leg_img.height * 0.52)
        thigh = leg_img.crop((0, 0, leg_img.width, split_y))
        shin = leg_img.crop((0, split_y, leg_img.width, leg_img.height))
        parts[f"thigh_{side}"] = save_part(thigh, f"thigh_{side}.png")
        parts[f"shin_{side}"] = save_part(shin, f"shin_{side}.png")
        # 保留 leg_full 文件不动（避免触发批量删除安全确认）
        parts.pop(key)
        print(f"  -> split {key} -> thigh_{side} + shin_{side}")

    # 用右侧手臂镜像生成左侧手臂，保证左臂与右臂比例一致（当前右臂较细）。
    mirror_arm_parts(parts)

    # 生成 rig spec
    rig = build_rig_spec(parts)
    RIG_JSON.write_text(json.dumps(rig, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"[INFO] rig spec written to {RIG_JSON}")
    return 0


def guess_orig_name(x1: int, y1: int, x2: int, y2: int, w: int, h: int) -> str:
    """根据位置和尺寸反推 split_rig_reference.py 会给出的原始文件名。"""
    cx = (x1 + x2) / 2
    cy = (y1 + y2) / 2
    ar = h / max(w, 1)

    if cy < 350 and cx < 500 and ar < 1.5:
        return "upperarm_L.png"      # 实际为 head
    if cy < 450 and cx > 1200 and ar < 2.0:
        return "part_b0_c12.png"     # 左上臂
    if 700 < cx < 1200 and 1.5 < ar < 2.5 and cy < 1000:
        return "part_b0_c7.png"      # torso
    if 450 < cy < 1100 and cx > 1400 and ar > 3:
        return "part_b1_c13.png"     # 左前臂
    if 450 < cy < 1100 and cx < 500 and ar > 3:
        return "part_b1_c5.png"      # 右前臂
    if 350 < cy < 800 and 500 < cx < 700 and 1.5 < ar < 3:
        return "part_b0_c6.png"      # 右上臂残段
    if 350 < cy < 800 and cx > 1200 and 1.5 < ar < 3:
        return "part_b0_c9.png"      # 左上臂残段（不用）
    if cy > 850 and cx < 700 and ar > 4:
        return "part_b2_c6.png"      # 完整右腿
    if cy > 850 and cx > 1200 and ar > 4:
        return "part_b2_c9.png"      # 完整左腿
    return f"part_{int(cx)}_{int(cy)}.png"


def save_part(img: Image.Image, filename: str) -> dict:
    out_path = OUT_DIR / filename
    img.save(out_path)
    return {"filename": filename, "size": [img.width, img.height]}


def mirror_arm_parts(parts: dict) -> None:
    """用右上臂/右前臂生成左侧镜像，保证左上臂/左前臂与右侧比例一致。

    注意：这里明确是 "右上臂 -> 左上臂"，即把右侧纹理水平翻转后覆盖左侧文件。
    """
    for part in ("upperarm", "forearm"):
        src_key = f"{part}_R"
        dst_key = f"{part}_L"
        if src_key not in parts:
            continue
        src_path = OUT_DIR / parts[src_key]["filename"]
        img = Image.open(src_path).convert("RGBA")
        mirrored = img.transpose(Image.FLIP_LEFT_RIGHT)
        dst_path = OUT_DIR / f"{dst_key}.png"
        mirrored.save(dst_path)
        parts[dst_key] = {"filename": f"{dst_key}.png", "size": [mirrored.width, mirrored.height]}
        print(f"  -> mirror {src_key} -> {dst_key}: {mirrored.width}x{mirrored.height}")


def build_rig_spec(parts: dict) -> dict:
    def sz(key: str):
        return parts[key]["size"] if key in parts else [0, 0]

    torso_w, torso_h = sz("torso")
    head_w, head_h = sz("head")
    # 让躯干在世界坐标中长约 110（与 Sherlock 一致）
    world_scale = 110.0 / max(torso_h, 1.0)

    spec = {
        "character": "test_rig_character",
        "parts_dir": "res://assets/characters/test_rig_character/rig/",
        "scale": world_scale,
        "bones": []
    }

    def add(name: str, parent: str, pos: list, rot: float, length: float, width: float,
            tex: str, pivot: list, color: list):
        spec["bones"].append({
            "name": name, "parent": parent, "pos": pos, "rot": rot,
            "len": length, "wid": width, "dir": 1, "color": color,
            "tex": tex, "pivot": pivot, "scale": world_scale
        })

    skin = [0.86, 0.70, 0.55]
    pants = [0.12, 0.12, 0.16]

    # 骨架：head -> neck -> torso -> hip；各骨向下延伸（y 正方向向下）
    # pivot 约定：y=0 为纹理顶部，y=height 为纹理底部（与 Sherlock 一致）
    head_len = head_h * world_scale
    torso_len = torso_h * world_scale

    # 关键：所有连接处用 pivot 比例换算，确保纹理首尾相接、不留缝隙。
    # head pivot 在 0.85 高度（近底部）=> 头部底端相对 head bone 的偏移为 0.15*head_len。
    head_pivot_y_ratio = 0.85
    head_bottom_offset = head_len * (1.0 - head_pivot_y_ratio)
    # 各部件之间的可见间隙：统一 3 像素（contact sheet 为 1:1 世界坐标，故 1 像素 = 1 世界单位）
    GAP = 3.0
    neck_gap = GAP                       # 头-躯干：3px 干净间距
    hip_gap = -15.0                      # 躯干-腿：骨盆正中间收窄约14px，须重叠约15px正中才看连上（腿画在躯干下层，叠入部分被躯干盖住）

    add("head", "", [0, 0], 0, head_len, head_w * world_scale,
        "head.png", [head_w / 2, head_h * head_pivot_y_ratio], skin)
    # neck 位于 head 底端，torso 从 neck 底端开始 => 颈部长度 = neck_gap
    add("neck", "head", [0, head_bottom_offset], 0, neck_gap, 14, "", [0, 0], skin)
    add("torso", "neck", [0, neck_gap], 0, torso_len, torso_w * 0.6 * world_scale,
        "torso.png", [torso_w / 2, 0], skin)
    # hip 位于 torso 底端
    add("hip", "torso", [0, torso_len], 0, hip_gap, 32, "", [0, 0], pants)

    # 肩膀位置
    shoulder_x = torso_w * 0.35 * world_scale

    # 臀部外沿：用躯干宽度的一半作为腿外沿对齐基准
    hip_outer = (torso_w * world_scale) * 0.5

    for side, sign in [("L", -1), ("R", 1)]:
        ua_key = f"upperarm_{side}"
        fa_key = f"forearm_{side}"
        ua_w, ua_h = sz(ua_key)
        fa_w, fa_h = sz(fa_key)
        ua_len = ua_h * world_scale
        fa_len = fa_h * world_scale

        # 肩膀贴在躯干顶部两侧
        add(f"shoulder_{side}", "torso",
            [sign * shoulder_x, 0], 0,
            6, 14, "", [0, 0], pants)
        if ua_h > 50:
            # 上臂 pivot 在 0.1 高度（近顶部）=> 上臂顶端与肩平齐
            add(f"upperarm_{side}", f"shoulder_{side}", [0, 0], sign * 70,
                ua_len, ua_w * 0.6 * world_scale, f"{ua_key}.png",
                [ua_w / 2, ua_h * 0.1], skin)
            # 前臂 pivot 在 0.05 高度；让前臂顶端接上臂底端
            forearm_top_offset = fa_h * 0.05 * world_scale
            add(f"forearm_{side}", f"upperarm_{side}",
                [0, ua_len + forearm_top_offset + GAP], sign * 8,
                fa_len, fa_w * 0.6 * world_scale, f"{fa_key}.png",
                [fa_w / 2, fa_h * 0.05], skin)
        else:
            add(f"arm_{side}", f"shoulder_{side}", [0, 0], sign * 70,
                fa_len, fa_w * 0.6 * world_scale, f"{fa_key}.png",
                [fa_w / 2, fa_h * 0.05], skin)

    for side, sign in [("L", -1), ("R", 1)]:
        th_w, th_h = sz(f"thigh_{side}")
        sh_w, sh_h = sz(f"shin_{side}")
        th_len = th_h * world_scale
        sh_len = sh_h * world_scale
        # 大腿 pivot 在 0.08 高度；让大腿顶端接髋部/躯干底端
        thigh_top_offset = th_h * 0.08 * world_scale
        # 腿外沿对齐臀部外沿（躯干两侧边缘）
        thigh_outer = th_w * 0.55 * world_scale / 2
        thigh_x = sign * (hip_outer - thigh_outer)
        add(f"thigh_{side}", "hip",
            [thigh_x, hip_gap + thigh_top_offset], 0,
            th_len, th_w * 0.55 * world_scale, f"thigh_{side}.png",
            [th_w / 2, th_h * 0.08], pants)
        # 小腿 pivot 在 0.05 高度；让小腿顶端接大腿底端
        shin_top_offset = sh_h * 0.05 * world_scale
        add(f"shin_{side}", f"thigh_{side}",
            [0, th_len + shin_top_offset + GAP], 0,
            sh_len, sh_w * 0.5 * world_scale, f"shin_{side}.png",
            [sh_w / 2, sh_h * 0.05], skin)

    return spec


if __name__ == "__main__":
    sys.exit(main())
