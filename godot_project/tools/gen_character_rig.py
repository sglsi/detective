#!/usr/bin/env python3
"""参数化角色绑骨定义生成器（华生 / 任意新角色通用）。

用法：
  python tools/gen_character_rig.py watson
  python tools/gen_character_rig.py sherlock        # 复刻旧 gen_sherlock_rig.py

行为：
  读取 assets/characters/<character>/rig/<character>_<part>.png（紧裁透明 PNG），
  按固定骨架拓扑（与 SkeletonCharacter2D.apply_pose 兼容）计算每个有贴图骨的
  pivot / scale，输出：
    - scripts/rig/<character>_rig.gd            (Godot 可用 const DEF，供 build_from_def)
    - skeleton_frames/rig_<character>_spec.json (供 draw_skeleton.py 离屏合成预览)

约定（与 cutout/绑定管线一致，见 docs/watson_rig_asset_spec.md §3）：
  - 每个部件竖直绘制，近端关节在顶边水平正中，内容顶满画布高度。
  - pivot_x = 顶部 6% 行不透明像素水平质心；pivot_y = 0（帽子取底部 H，flip=True）。
  - scale = 骨长 / 整图高度。
"""
import os
import sys
import json
import argparse
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---- 调色板（与 skeleton_character._demo_def 对齐）----
PALETTES = {
    "sherlock": {
        "skin": (0.86, 0.70, 0.55),
        "coat": (0.16, 0.18, 0.26),
        "coat_l": (0.24, 0.26, 0.36),
        "hat": (0.55, 0.42, 0.28),
        "pants": (0.12, 0.12, 0.16),
    },
    "watson": {
        "skin": (0.86, 0.70, 0.55),
        "coat": (0.30, 0.26, 0.22),
        "coat_l": (0.40, 0.34, 0.28),
        "hat": (0.45, 0.36, 0.26),
        "pants": (0.12, 0.12, 0.16),
    },
}


def load_part(rig_png_dir, character, part):
    p = os.path.join(rig_png_dir, "%s_%s.png" % (character, part))
    if not os.path.exists(p):
        return None, 0
    im = Image.open(p).convert("RGBA")
    return im, im.size[1]


def proximal_pivot_x(im, bottom=False, frac=0.06):
    """近端关节水平中心：默认取顶部若干行质心；hat 取底部。"""
    w, h = im.size
    a = im.split()[3]
    px = a.load()
    band = int(h * frac) + 1
    if bottom:
        y0, y1 = h - band, h
    else:
        y0, y1 = 0, band
    xs = []
    for y in range(y0, y1):
        for x in range(w):
            if px[x, y] > 30:
                xs.append(x)
    if not xs:
        return w / 2
    return sum(xs) / len(xs)


# 固定骨拓扑：(name, parent, pos(x,y), rot_deg, len, wid, dir, color_key, tex_suffix or "", is_hat)
# 与 apply_pose 的摆动幅度强耦合，华生/福尔摩斯必须一致。
BONES = [
    ("head",       "",        (0, 0),    0,   80, 46, -1, "skin",  "head",       False),
    ("neck",       "head",    (0, 80),   0,   18, 14, -1, "skin",  "",           False),
    ("torso",      "neck",    (0, 18),   0,  110, 42, -1, "coat",  "torso",      False),
    ("hip",        "torso",   (0, 110),  0,   16, 30, -1, "pants", "",           False),
    ("shoulder_L", "torso",   (-22, 10), 0,    6, 14, -1, "coat",  "",           False),
    ("upperarm_L", "shoulder_L", (0, 0), 70,  60, 16,  1, "coat_l","upperarm_L", False),
    ("forearm_L",  "upperarm_L", (0, 60), 8,  55, 13,  1, "skin",  "forearm_L",  False),
    ("shoulder_R", "torso",   (22, 10),  0,    6, 14, -1, "coat",  "",           False),
    ("upperarm_R", "shoulder_R", (0, 0), -70, 60, 16,  1, "coat_l","upperarm_R", False),
    ("forearm_R",  "upperarm_R", (0, 60), -8, 55, 13,  1, "skin",  "forearm_R",  False),
    ("thigh_L",    "hip",     (-16, 6),  0,   80, 22,  1, "pants", "thigh_L",    False),
    ("shin_L",     "thigh_L", (0, 80),   0,   80, 17,  1, "coat_l","shin_L",     False),
    ("thigh_R",    "hip",     (16, 6),   0,   80, 22,  1, "pants", "thigh_R",    False),
    ("shin_R",     "thigh_R", (0, 80),   0,   80, 17,  1, "coat_l","shin_R",     False),
    ("hat",        "head",    (0, 0),    180, 34, 64, -1, "hat",   "hat",        True),
]


def color_str(c):
    return "Color(%.2f,%.2f,%.2f)" % c


def class_name_of(character):
    # sherlock -> SherlockRig ; watson -> WatsonRig
    return character[0].upper() + character[1:] + "Rig"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("character", help="角色名，如 watson / sherlock")
    ap.add_argument("--palette", default=None, help="调色板名；默认=character")
    ap.add_argument("--rig-dir", default=None, help="部件 PNG 目录，默认 assets/characters/<character>/rig")
    args = ap.parse_args()

    character = args.character
    palette_name = args.palette or character
    if palette_name not in PALETTES:
        print("未知 palette: %s（可选: %s）" % (palette_name, ", ".join(PALETTES)), file=sys.stderr)
        sys.exit(2)
    pal = PALETTES[palette_name]

    rig_png_dir = args.rig_dir or os.path.join(ROOT, "assets", "characters", character, "rig")
    if not os.path.isdir(rig_png_dir):
        print("部件目录不存在: %s" % rig_png_dir, file=sys.stderr)
        sys.exit(2)

    gd_out = os.path.join(ROOT, "scripts", "rig", "%s_rig.gd" % character)
    spec_out = os.path.join(ROOT, "skeleton_frames", "rig_%s_spec.json" % character)

    spec = {"bones": []}
    gd_bones = []
    missing = []
    for (name, parent, pos, rot, length, wid, d, ckey, tex, is_hat) in BONES:
        if tex:
            im, H = load_part(rig_png_dir, character, tex)
            if im is None:
                missing.append("%s_%s.png" % (character, tex))
                tex_path = ""
                pivot = (0.0, 0.0)
                scale = 1.0
            else:
                piv_x = proximal_pivot_x(im, bottom=is_hat)
                scale = float(length) / H
                pivot = (piv_x, H if is_hat else 0.0)
                tex_path = "res://assets/characters/%s/rig/%s_%s.png" % (character, character, tex)
                spec["bones"].append({
                    "name": name,
                    "tex": os.path.join(rig_png_dir, "%s_%s.png" % (character, tex)),
                    "pivot": [piv_x, H if is_hat else 0.0],
                    "flip": is_hat,
                    "scale": scale,
                })
        else:
            tex_path = ""
            pivot = (0.0, 0.0)
            scale = 1.0
        gd = ('\t\t{"name":"%s","parent":"%s","pos":Vector2(%g,%g),"rot":%g,"len":%g,'
              '"wid":%g,"dir":%g,"color":%s,"tex":"%s","pivot":Vector2(%g,%g),"scale":%g}'
              % (name, parent, pos[0], pos[1], rot, length, wid, d, color_str(pal[ckey]),
                 tex_path, pivot[0], pivot[1], scale))
        gd_bones.append(gd)

    bones_str = ",\n".join(gd_bones)
    gd_text = (
        "# 自动生成：tools/gen_character_rig.py %s —— %s 绑骨定义\n" % (character, character)
        + "class_name " + class_name_of(character) + "\n"
        + "const DEF := {\n"
        + '\t"bones": [\n'
        + bones_str + "\n"
        + "\t]\n"
        + "}\n"
        + "static func rig_def() -> Dictionary:\n"
        + "\treturn DEF\n"
    )
    os.makedirs(os.path.dirname(gd_out), exist_ok=True)
    with open(gd_out, "w", encoding="utf-8") as f:
        f.write(gd_text)
    with open(spec_out, "w", encoding="utf-8") as f:
        json.dump(spec, f, ensure_ascii=False, indent=2)

    print("wrote", gd_out)
    print("wrote", spec_out, "textured bones:", len(spec["bones"]))
    for b in spec["bones"]:
        print("  %-12s pivot=%s scale=%.4f flip=%s" % (b["name"], [round(v, 1) for v in b["pivot"]], b["scale"], b["flip"]))
    if missing:
        print("WARNING 缺失部件图（对应骨将无贴图）:", ", ".join(missing), file=sys.stderr)


if __name__ == "__main__":
    main()
