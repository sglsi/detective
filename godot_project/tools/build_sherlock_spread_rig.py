#!/usr/bin/env python3
"""读取 split_sherlock_spread.py 切好的部件，用 PCA 主轴算出真实关节角度，
生成标准 15 骨 rig spec（head/neck/torso/hip/shoulder_L/R/upperarm_L/R/
forearm_L/R/thigh_L/R/shin_L/R），覆盖 _rig_spec.json。

关键约定（与 SkeletonCharacter2D 一致）：
- rotation 0 = 骨本地 +y 朝下（直向下）。
- rot = atan2(dx, dy)（从竖直向下逆时针为正/顺时针为负）。
- 肢体部件 pivot 在纹理顶端 10%（关节端），dir=1 向下延伸。
- 头部 pivot 在纹理底端 85%（颈端），dir=-1 向上延伸。
"""
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

RIG_JSON = Path(r"D:\AI\detective\godot_project\assets\characters\sherlock_spread\rig\_rig_spec.json")


def limb_axis_from_path(path: Path):
    """返回部件的 (top_joint, bottom_joint, length_px, rot_deg)。"""
    im = Image.open(path).convert("RGBA")
    a = np.array(im)
    fg = a[:, :, 3] > 128
    ys, xs = np.where(fg)
    if len(xs) < 10:
        return None
    pts = np.column_stack([xs, ys]).astype(float)
    c = pts.mean(axis=0)
    cov = np.cov(pts.T)
    vals, vecs = np.linalg.eigh(cov)
    vec = vecs[:, np.argmax(vals)]
    # 投影到主轴，取两端
    proj = (pts - c) @ vec
    i_top = int(np.argmin(proj))
    i_bot = int(np.argmax(proj))
    top = pts[i_top]
    bot = pts[i_bot]
    # 确保 top 在 y 上更高（y 更小）
    if bot[1] < top[1]:
        top, bot = bot, top
    dx = bot[0] - top[0]
    dy = bot[1] - top[1]
    length_px = math.hypot(dx, dy)
    rot_deg = math.degrees(math.atan2(dx, dy))  # 0=向下
    return {
        "top": [float(top[0]), float(top[1])],
        "bottom": [float(bot[0]), float(bot[1])],
        "len_px": length_px,
        "rot_deg": rot_deg,
        "size": [im.width, im.height],
    }


def main() -> int:
    if not RIG_JSON.exists():
        print(f"[ERR] {RIG_JSON} not found; run split_sherlock_spread.py first", file=sys.stderr)
        return 1

    spec = json.loads(RIG_JSON.read_text(encoding="utf-8"))
    parts_dir = Path(str(RIG_JSON).replace("_rig_spec.json", ""))
    parts = {b["name"]: b for b in spec["bones"]}

    # 重新测量各部件角度/长度（忽略原粗略估算）
    axes: dict = {}
    for name in ["head", "torso", "upperarm_L", "upperarm_R", "forearm_L", "forearm_R",
                 "thigh_L", "thigh_R", "shin_L", "shin_R"]:
        path = parts_dir / f"{name}.png"
        if not path.exists():
            print(f"[WARN] missing {path}", file=sys.stderr)
            continue
        axes[name] = limb_axis_from_path(path)
        ax = axes[name]
        print(f"  {name}: len={ax['len_px']:.1f}px rot={ax['rot_deg']:.1f}° top=({ax['top'][0]:.0f},{ax['top'][1]:.0f}) bottom=({ax['bottom'][0]:.0f},{ax['bottom'][1]:.0f})")

    # 用 src_bbox 计算各关节在原图中的绝对坐标
    def src_center(name):
        bb = parts[name]["src_bbox"]
        return ((bb[0] + bb[2]) / 2.0, (bb[1] + bb[3]) / 2.0)

    def src_top(name):
        bb = parts[name]["src_bbox"]
        return axes[name]["top"][0] + bb[0], axes[name]["top"][1] + bb[1]

    def src_bottom(name):
        bb = parts[name]["src_bbox"]
        return axes[name]["bottom"][0] + bb[0], axes[name]["bottom"][1] + bb[1]

    # 比例：躯干在世界坐标中长约 110
    torso_h = axes["torso"]["len_px"]
    scale = 110.0 / torso_h
    print(f"\nscale = {scale:.6f} (torso_h={torso_h:.1f}px -> 110 world)")

    # 坐标原点在 torso 顶端中心（颈根）
    torso_top = src_top("torso")
    origin = torso_top

    def to_world(px, py):
        return [(px - origin[0]) * scale, (py - origin[1]) * scale]

    # ---- 部件尺寸从实际 PNG 取（原 spec 可能没有 size） ----
    sizes: dict = {}
    for name in axes:
        sizes[name] = axes[name]["size"]

    # ---- 计算关节位置 ----
    neck_root = src_bottom("head")   # 颈 = 头底
    torso_top_w = to_world(*origin)   # (0,0)
    torso_bottom = src_bottom("torso")
    hip_root = torso_bottom

    shoulder = {
        "L": src_top("upperarm_L"),
        "R": src_top("upperarm_R"),
    }
    elbow = {
        "L": src_top("forearm_L"),
        "R": src_top("forearm_R"),
    }
    # 前臂底部 = 手腕，仅用于长度校验
    wrist = {
        "L": src_bottom("forearm_L"),
        "R": src_bottom("forearm_R"),
    }
    hip_joint = {
        "L": src_top("thigh_L"),
        "R": src_top("thigh_R"),
    }
    knee = {
        "L": src_top("shin_L"),
        "R": src_top("shin_R"),
    }
    ankle = {
        "L": src_bottom("shin_L"),
        "R": src_bottom("shin_R"),
    }

    # 坐标原点在躯干顶端中心（颈根），胯根在躯干底端中心
    torso_bbox = parts["torso"]["src_bbox"]
    origin = ((torso_bbox[0] + torso_bbox[2]) / 2.0, torso_bbox[1])
    hip_root = ((torso_bbox[0] + torso_bbox[2]) / 2.0, torso_bbox[3])

    # 颈根 = 头底中心
    head_bbox = parts["head"]["src_bbox"]
    neck_root = ((head_bbox[0] + head_bbox[2]) / 2.0, head_bbox[3])

    # 重新计算世界坐标（因 origin/hip_root 已修正）
    neck_root_w = to_world(*neck_root)
    hip_root_w = to_world(*hip_root)

    def add(spec_bones, name, parent, pos, rot, length, width, tex, pivot, color, scale_v):
        spec_bones.append({
            "name": name, "parent": parent, "pos": [round(pos[0], 3), round(pos[1], 3)],
            "rot": round(rot, 3), "len": round(length, 3), "wid": round(width, 3),
            "dir": 1, "color": color, "tex": tex,
            "pivot": [round(pivot[0], 3), round(pivot[1], 3)],
            "scale": scale_v,
            "src_bbox": parts.get(name, {}).get("src_bbox"),
        })

    bones = []
    skin = [0.86, 0.70, 0.55]
    coat = [0.16, 0.18, 0.26]
    coat_l = [0.24, 0.26, 0.36]
    pants = [0.12, 0.12, 0.16]

    # head 为根：pivot 在底端（颈），dir=-1 向上
    head_len = axes["head"]["len_px"] * scale
    head_wid = sizes["head"][0] * scale
    head_pivot_y = sizes["head"][1] * 0.85
    add(bones, "head", "", [0.0, 0.0], 0.0, head_len, head_wid, "head.png",
        [sizes["head"][0] / 2, head_pivot_y], skin, scale)

    # neck：从 head 底端连到 torso 顶端（若 neck_root 略偏离原点）
    neck_len = neck_root_w[1]  # head底相对 torso顶 的 y 偏移（应略正，head 在原点上方）
    if neck_len < 1:
        neck_len = 3.0
    add(bones, "neck", "head", [round(neck_root_w[0], 3), round(neck_root_w[1], 3)],
        0.0, neck_len, 14.0, "", [0, 0], skin, scale)

    # torso：顶端与 neck 底重合
    torso_len = torso_h * scale
    torso_wid = sizes["torso"][0] * scale
    add(bones, "torso", "neck", [0.0, neck_len], 0.0, torso_len, torso_wid * 0.6,
        "torso.png", [sizes["torso"][0] / 2, 0], coat, scale)

    # hip：在躯干底端；负长度让腿叠入躯干
    hip_len = -15.0
    add(bones, "hip", "torso", [0.0, torso_len], 0.0, hip_len, 32.0, "",
        [0, 0], pants, scale)

    # shoulder：在 torso 上端两侧，实际测量
    for side, sign in [("L", -1), ("R", 1)]:
        sx, sy = shoulder[side]
        # 肩膀位置 = 上臂顶端相对 torso 顶端原点的偏移（torso 本地 rot=0）
        shoulder_w = [round((sx - origin[0]) * scale, 3),
                      round((sy - origin[1]) * scale, 3)]
        add(bones, f"shoulder_{side}", "torso", shoulder_w, 0.0, 6.0, 14.0, "",
              [0, 0], coat, scale)

    # upperarm / forearm
    for side in ("L", "R"):
        ua = axes[f"upperarm_{side}"]
        fa = axes[f"forearm_{side}"]
        ua_len = ua["len_px"] * scale
        fa_len = fa["len_px"] * scale
        ua_wid = sizes[f"upperarm_{side}"][0] * scale
        fa_wid = sizes[f"forearm_{side}"][0] * scale
        ua_rot = ua["rot_deg"]
        # 前臂相对上臂的角度差（父骨 local）
        fa_rot = fa["rot_deg"] - ua_rot
        add(bones, f"upperarm_{side}", f"shoulder_{side}", [0, 0],
            ua_rot, ua_len, ua_wid * 0.6, f"upperarm_{side}.png",
            [sizes[f"upperarm_{side}"][0] / 2,
             sizes[f"upperarm_{side}"][1] * 0.1], coat_l, scale)
        add(bones, f"forearm_{side}", f"upperarm_{side}", [0, ua_len],
            fa_rot, fa_len, fa_wid * 0.6, f"forearm_{side}.png",
            [sizes[f"forearm_{side}"][0] / 2,
             sizes[f"forearm_{side}"][1] * 0.1], skin, scale)

    # thigh / shin
    for side, sign in [("L", -1), ("R", 1)]:
        th = axes[f"thigh_{side}"]
        sh = axes[f"shin_{side}"]
        th_len = th["len_px"] * scale
        sh_len = sh["len_px"] * scale
        th_wid = sizes[f"thigh_{side}"][0] * scale
        sh_wid = sizes[f"shin_{side}"][0] * scale
        th_rot = th["rot_deg"]
        sh_rot = sh["rot_deg"] - th_rot
        # 大腿顶端相对 hip 底端（torso 底 + hip_len）的偏移
        hx, hy = hip_joint[side]
        hip_bottom_world = [hip_root_w[0], hip_root_w[1] + hip_len]
        thigh_pos = [round((hx - origin[0]) * scale - hip_bottom_world[0], 3),
                     round((hy - origin[1]) * scale - hip_bottom_world[1], 3)]
        add(bones, f"thigh_{side}", "hip", thigh_pos, th_rot,
            th_len, th_wid * 0.55, f"thigh_{side}.png",
            [sizes[f"thigh_{side}"][0] / 2,
             sizes[f"thigh_{side}"][1] * 0.08], pants, scale)
        add(bones, f"shin_{side}", f"thigh_{side}", [0, th_len], sh_rot,
            sh_len, sh_wid * 0.5, f"shin_{side}.png",
            [sizes[f"shin_{side}"][0] / 2,
             sizes[f"shin_{side}"][1] * 0.05], skin, scale)

    new_spec = {
        "character": "sherlock_spread",
        "parts_dir": "res://assets/characters/sherlock_spread/rig/",
        "scale": scale,
        "bones": bones,
    }
    RIG_JSON.write_text(json.dumps(new_spec, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\n[INFO] updated {RIG_JSON} ({len(bones)} bones)")

    # 写一份关节坐标 debug
    debug = {
        "origin": origin, "scale": scale,
        "joints": {
            "neck_root": neck_root,
            "torso_top": list(origin),
            "torso_bottom": list(torso_bottom),
            "hip_root": list(hip_root),
            "shoulder": {k: list(v) for k, v in shoulder.items()},
            "elbow": {k: list(v) for k, v in elbow.items()},
            "wrist": {k: list(v) for k, v in wrist.items()},
            "hip_joint": {k: list(v) for k, v in hip_joint.items()},
            "knee": {k: list(v) for k, v in knee.items()},
            "ankle": {k: list(v) for k, v in ankle.items()},
        }
    }
    (parts_dir / "_joints_debug.json").write_text(json.dumps(debug, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"[INFO] joints debug -> {parts_dir / '_joints_debug.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
