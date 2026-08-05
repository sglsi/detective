#!/usr/bin/env python3
"""读取 split_sherlock_spread.py 切好的部件，用实测关节坐标重建标准 15 骨 rig spec。

约定（与 SkeletonCharacter2D 一致）：
- 角度 0 = 骨本地 +y 朝下（竖直向下），正方向 = 逆时针。
- 坐标系：世界 +y 向下（Godot 2D 坐标）。
- 所有关节位置从原图绝对像素坐标测得，原点在颈根（head 底端中心）。
- 子骨的本地 pos = R(-父骨角度) * (子骨关节世界位置 - 父骨关节世界位置)。
- 子骨的本地 rot = 子骨角度 - 父骨角度。
- 纹理 pivot 为该部件中对应关节的像素坐标（由 PCA 主轴端点给出）。
"""
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

RIG_JSON = Path(r"D:\AI\detective\godot_project\assets\characters\sherlock_spread\rig\_rig_spec.json")


def limb_axis_from_path(path: Path):
    """返回部件的 (joint_top, joint_bottom, length_px, rot_deg)。"""
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
    proj = (pts - c) @ vec
    i_top = int(np.argmin(proj))
    i_bot = int(np.argmax(proj))
    top = pts[i_top]
    bot = pts[i_bot]
    # top 是关节端（y 更高）
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


def rotate(v, deg):
    th = math.radians(deg)
    c, s = math.cos(th), math.sin(th)
    return [v[0] * c - v[1] * s, v[0] * s + v[1] * c]


def sub(a, b):
    return [a[0] - b[0], a[1] - b[1]]


def main() -> int:
    if not RIG_JSON.exists():
        print(f"[ERR] {RIG_JSON} not found; run split_sherlock_spread.py first", file=sys.stderr)
        return 1

    spec = json.loads(RIG_JSON.read_text(encoding="utf-8"))
    parts_dir = Path(str(RIG_JSON).replace("_rig_spec.json", ""))
    parts = {b["name"]: b for b in spec["bones"]}

    axes: dict = {}
    for name in ["head", "torso", "upperarm_L", "upperarm_R", "forearm_L", "forearm_R",
                 "thigh_L", "thigh_R", "shin_L", "shin_R"]:
        path = parts_dir / f"{name}.png"
        if not path.exists():
            print(f"[WARN] missing {path}", file=sys.stderr)
            continue
        axes[name] = limb_axis_from_path(path)
        ax = axes[name]
        print(f"  {name}: len={ax['len_px']:.1f}px rot={ax['rot_deg']:.1f} top=({ax['top'][0]:.0f},{ax['top'][1]:.0f}) bottom=({ax['bottom'][0]:.0f},{ax['bottom'][1]:.0f})")

    def src_point(name, rel):
        """把部件局部点转回原图绝对坐标。"""
        bb = parts[name]["src_bbox"]
        return [rel[0] + bb[0], rel[1] + bb[1]]

    # ---- 关节绝对坐标（像素） ----
    neck_root = src_point("head", [axes["head"]["size"][0] / 2.0, axes["head"]["bottom"][1]])
    torso_top = src_point("torso", axes["torso"]["top"])
    torso_bottom = src_point("torso", axes["torso"]["bottom"])
    hip_root = [(torso_top[0] + torso_bottom[0]) / 2.0, torso_bottom[1]]

    shoulder = {
        "L": src_point("upperarm_L", axes["upperarm_L"]["top"]),
        "R": src_point("upperarm_R", axes["upperarm_R"]["top"]),
    }
    elbow = {
        "L": src_point("forearm_L", axes["forearm_L"]["top"]),
        "R": src_point("forearm_R", axes["forearm_R"]["top"]),
    }
    wrist = {
        "L": src_point("forearm_L", axes["forearm_L"]["bottom"]),
        "R": src_point("forearm_R", axes["forearm_R"]["bottom"]),
    }
    hip_joint = {
        "L": src_point("thigh_L", axes["thigh_L"]["top"]),
        "R": src_point("thigh_R", axes["thigh_R"]["top"]),
    }
    knee = {
        "L": src_point("shin_L", axes["shin_L"]["top"]),
        "R": src_point("shin_R", axes["shin_R"]["top"]),
    }
    ankle = {
        "L": src_point("shin_L", axes["shin_L"]["bottom"]),
        "R": src_point("shin_R", axes["shin_R"]["bottom"]),
    }

    # 缩放：让躯干在世界中高约 110（与动画脚本匹配）
    torso_pixel_h = abs(torso_bottom[1] - torso_top[1])
    scale = 110.0 / torso_pixel_h
    print(f"\nscale = {scale:.6f} (torso pixel h={torso_pixel_h:.1f} -> 110 world)")

    origin = neck_root  # 世界原点 = 颈根

    def to_world(px, py):
        return [(px - origin[0]) * scale, (py - origin[1]) * scale]

    # 世界坐标
    P = {
        "head": to_world(*neck_root),
        "torso_top": to_world(*torso_top),
        "torso_bottom": to_world(*torso_bottom),
        "hip": to_world(*hip_root),
        "shoulder_L": to_world(*shoulder["L"]),
        "shoulder_R": to_world(*shoulder["R"]),
        "elbow_L": to_world(*elbow["L"]),
        "elbow_R": to_world(*elbow["R"]),
        "wrist_L": to_world(*wrist["L"]),
        "wrist_R": to_world(*wrist["R"]),
        "hip_L": to_world(*hip_joint["L"]),
        "hip_R": to_world(*hip_joint["R"]),
        "knee_L": to_world(*knee["L"]),
        "knee_R": to_world(*knee["R"]),
        "ankle_L": to_world(*ankle["L"]),
        "ankle_R": to_world(*ankle["R"]),
    }

    # 各骨角度（世界）
    Theta = {
        "head": 0.0,
        "neck": 0.0,
        "torso": 0.0,
        "hip": 0.0,
        "shoulder_L": 0.0,
        "shoulder_R": 0.0,
        "upperarm_L": axes["upperarm_L"]["rot_deg"],
        "upperarm_R": axes["upperarm_R"]["rot_deg"],
        "forearm_L": axes["forearm_L"]["rot_deg"],
        "forearm_R": axes["forearm_R"]["rot_deg"],
        "thigh_L": axes["thigh_L"]["rot_deg"],
        "thigh_R": axes["thigh_R"]["rot_deg"],
        "shin_L": axes["shin_L"]["rot_deg"],
        "shin_R": axes["shin_R"]["rot_deg"],
    }

    def bone(name, parent, joint, theta, length, width, tex, pivot, color):
        """根据父骨计算本地 pos/rot。"""
        if parent == "":
            local_pos = P[joint]
            local_rot = theta
        else:
            # 父骨基关节名：即父骨在父的父上的附着点
            parent_joint = {
                "neck": "head",
                "torso": "torso_top",
                "hip": "torso_top",
                "shoulder_L": "torso_top",
                "shoulder_R": "torso_top",
                "upperarm_L": "shoulder_L",
                "upperarm_R": "shoulder_R",
                "forearm_L": "shoulder_L",
                "forearm_R": "shoulder_R",
                "thigh_L": "torso_bottom",
                "thigh_R": "torso_bottom",
                "shin_L": "hip_L",
                "shin_R": "hip_R",
            }[name]
            local_pos = rotate(sub(P[joint], P[parent_joint]), -Theta[parent])
            local_rot = theta - Theta[parent]
        return {
            "name": name, "parent": parent,
            "pos": [round(local_pos[0], 3), round(local_pos[1], 3)],
            "rot": round(local_rot, 3),
            "len": round(length, 3), "wid": round(width, 3),
            "dir": 1, "color": color, "tex": tex,
            "pivot": [round(pivot[0], 3), round(pivot[1], 3)],
            "scale": scale,
            "src_bbox": parts.get(name, {}).get("src_bbox"),
        }

    skin = [0.86, 0.70, 0.55]
    coat = [0.16, 0.18, 0.26]
    coat_l = [0.24, 0.26, 0.36]
    pants = [0.12, 0.12, 0.16]

    # pivot 取部件中对应关节的实测点（局部坐标）
    head_piv = [axes["head"]["size"][0] / 2.0, axes["head"]["bottom"][1]]
    torso_piv = axes["torso"]["top"]

    bones = []
    bones.append(bone("head", "", "head", Theta["head"],
                      axes["head"]["len_px"] * scale, axes["head"]["size"][0] * scale,
                      "head.png", head_piv, skin))
    neck_len = math.hypot(P["torso_top"][0] - P["head"][0], P["torso_top"][1] - P["head"][1])
    bones.append(bone("neck", "head", "torso_top", Theta["neck"],
                      neck_len, 14.0, "", [0, 0], skin))
    torso_len = math.hypot(P["torso_bottom"][0] - P["torso_top"][0], P["torso_bottom"][1] - P["torso_top"][1])
    bones.append(bone("torso", "neck", "torso_top", Theta["torso"],
                      torso_len, axes["torso"]["size"][0] * scale * 0.6,
                      "torso.png", torso_piv, coat))
    # hip：胯根处的零长骨；负长度让腿叠入躯干底
    bones.append(bone("hip", "torso", "torso_bottom", Theta["hip"],
                      -15.0, 32.0, "", [0, 0], pants))

    for side in ("L", "R"):
        # shoulder 由真实肩点决定
        bones.append(bone(f"shoulder_{side}", "torso", f"shoulder_{side}", Theta[f"shoulder_{side}"],
                          6.0, 14.0, "", [0, 0], coat))
        ua_len = math.hypot(P[f"elbow_{side}"][0] - P[f"shoulder_{side}"][0],
                           P[f"elbow_{side}"][1] - P[f"shoulder_{side}"][1])
        bones.append(bone(f"upperarm_{side}", f"shoulder_{side}", f"shoulder_{side}", Theta[f"upperarm_{side}"],
                          ua_len, axes[f"upperarm_{side}"]["size"][0] * scale * 0.6,
                          f"upperarm_{side}.png", axes[f"upperarm_{side}"]["top"], coat_l))
        fa_len = math.hypot(P[f"wrist_{side}"][0] - P[f"elbow_{side}"][0],
                           P[f"wrist_{side}"][1] - P[f"elbow_{side}"][1])
        bones.append(bone(f"forearm_{side}", f"upperarm_{side}", f"elbow_{side}", Theta[f"forearm_{side}"],
                          fa_len, axes[f"forearm_{side}"]["size"][0] * scale * 0.6,
                          f"forearm_{side}.png", axes[f"forearm_{side}"]["top"], skin))

    for side in ("L", "R"):
        th_len = math.hypot(P[f"knee_{side}"][0] - P[f"hip_{side}"][0],
                          P[f"knee_{side}"][1] - P[f"hip_{side}"][1])
        bones.append(bone(f"thigh_{side}", "hip", f"hip_{side}", Theta[f"thigh_{side}"],
                          th_len, axes[f"thigh_{side}"]["size"][0] * scale * 0.55,
                          f"thigh_{side}.png", axes[f"thigh_{side}"]["top"], pants))
        sh_len = math.hypot(P[f"ankle_{side}"][0] - P[f"knee_{side}"][0],
                          P[f"ankle_{side}"][1] - P[f"knee_{side}"][1])
        bones.append(bone(f"shin_{side}", f"thigh_{side}", f"knee_{side}", Theta[f"shin_{side}"],
                          sh_len, axes[f"shin_{side}"]["size"][0] * scale * 0.5,
                          f"shin_{side}.png", axes[f"shin_{side}"]["top"], skin))

    new_spec = {
        "character": "sherlock_spread",
        "parts_dir": "res://assets/characters/sherlock_spread/rig/",
        "scale": scale,
        "bones": bones,
    }
    RIG_JSON.write_text(json.dumps(new_spec, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\n[INFO] updated {RIG_JSON} ({len(bones)} bones)")

    debug = {
        "origin_pixel": origin, "scale": scale,
        "joints_world": {k: [round(x, 3), round(y, 3)] for k, (x, y) in P.items()},
        "angles": {k: round(v, 3) for k, v in Theta.items()},
    }
    (parts_dir / "_joints_debug.json").write_text(json.dumps(debug, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"[INFO] joints debug -> {parts_dir / '_joints_debug.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
